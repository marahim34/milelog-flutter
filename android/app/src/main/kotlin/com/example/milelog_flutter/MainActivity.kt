package com.example.milelog_flutter

import android.Manifest
import android.app.AlertDialog
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.concurrent.thread

/**
 * Classic-Bluetooth glue with no pub.dev equivalent: bonded-device lookup and
 * ACL connect/disconnect observation. Mirrors the MAC-keyed vehicle lookup
 * done in the Kotlin reference app's `BluetoothReceiver` — this layer only
 * forwards raw events; vehicle matching and trip start/pause stay in Dart.
 *
 * The ACL receiver registered here is dynamic, so it only fires while this
 * process is alive — see [AppProcessState]. [BluetoothAclReceiver] is the
 * static (manifest-declared) counterpart that covers the killed-app case.
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.milelog_flutter/bluetooth"
    private val downloadChannelName = "com.example.milelog_flutter/downloads"
    private val trackingChannelName = "com.example.milelog_flutter/tracking"
    private val eventChannelName = "com.example.milelog_flutter/bluetooth_acl"

    private var eventSink: EventChannel.EventSink? = null
    private var aclReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Stored so onResume can push navigateToTracking calls into Dart. */
    private var trackingMethodChannel: MethodChannel? = null

    /** Skip the very first onResume — DriveTab.initState handles cold-start navigation. */
    private var firstResumeDone = false

    /**
     * Set to true when [configureFlutterEngine] schedules a navigateToTracking
     * call (1000ms delay) for a cold-start that finds an active trip. Prevents
     * [onResume] from queuing a duplicate navigate with its shorter 500ms delay.
     */
    private var navigationAttempted = false

    /** Receives tracking broadcasts from TrackingService and forwards to Dart. */
    private val trackingStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                TrackingService.ACTION_STATE_CHANGED -> {
                    val paused = intent.getBooleanExtra("isPaused", false)
                    mainHandler.post {
                        trackingMethodChannel?.invokeMethod(
                            "trackingStateChanged",
                            mapOf("isPaused" to paused)
                        )
                    }
                }
                TrackingService.ACTION_AUTO_STOPPED -> {
                    mainHandler.post {
                        trackingMethodChannel?.invokeMethod("navigateToHome", null)
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppProcessState.isEngineAlive = true

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBondedDevices" -> result.success(getBondedDevices())
                    "hasBluetoothPermission" -> result.success(hasConnectPermission())
                    "consumePendingAutoStartVehicleId" -> {
                        val vehicleId = intent.getIntExtra(EXTRA_AUTO_START_VEHICLE_ID, -1)
                        intent.removeExtra(EXTRA_AUTO_START_VEHICLE_ID)
                        result.success(if (vehicleId >= 0) vehicleId else null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val filename = call.argument<String>("filename")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (filename == null || bytes == null) {
                        result.error("INVALID_ARG", "filename and bytes are required", null)
                        return@setMethodCallHandler
                    }
                    thread {
                        try {
                            saveToDownloads(filename, bytes)
                            mainHandler.post { result.success(filename) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("DOWNLOAD_FAILED", e.message, null)
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }

        trackingMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, trackingChannelName)
        trackingMethodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val tripId = call.argument<Int>("tripId") ?: -1
                    val startTimeMs = call.argument<Long>("startTimeMs")
                        ?: System.currentTimeMillis()
                    val odometerStart = call.argument<Double>("odometerStart") ?: 0.0
                    val intent = TrackingService.startIntent(
                        this, tripId, startTimeMs, odometerStart)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                // Called by DriveTab on startup to pick up a notification-tap navigation
                // request that arrived before or while the Flutter engine was initialising.
                "consumePendingNavigateToTracking" -> {
                    val fromOnNewIntent = pendingNavigateToTrackingId
                    pendingNavigateToTrackingId = -1
                    val fromLaunchIntent =
                        if (intent?.getBooleanExtra(TrackingService.EXTRA_OPEN_TRACKING, false) == true)
                            intent.getIntExtra(TrackingService.EXTRA_TRIP_ID, -1)
                                .also { intent.removeExtra(TrackingService.EXTRA_OPEN_TRACKING) }
                        else -1
                    val tripId = if (fromOnNewIntent >= 0) fromOnNewIntent else fromLaunchIntent
                    result.success(if (tripId >= 0) tripId else null)
                }
                "stopTracking" -> {
                    stopService(Intent(this, TrackingService::class.java))
                    result.success(null)
                }
                "requestBatteryOptimization" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "isBatteryOptimizationIgnored" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "getTrackingState" -> {
                    result.success(mapOf(
                        "isRunning" to TrackingService.isRunning,
                        "isPaused" to TrackingService.isPaused,
                    ))
                }
                else -> result.notImplemented()
            }
        }

        // Cold-start active-trip check: if TrackingService is already running
        // when the engine is first created, schedule navigateToTracking with a
        // 1000ms delay — longer than onResume's 500ms so the Dart MethodChannel
        // handler has time to be registered before we invoke it.
        if (TrackingService.isRunning) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val tripId = prefs.getLong("flutter.active_trip_state_trip_id", -1L).toInt()
            if (tripId >= 0) {
                navigationAttempted = true
                mainHandler.postDelayed({
                    trackingMethodChannel?.invokeMethod(
                        "navigateToTracking",
                        mapOf("tripId" to tripId)
                    )
                }, 1000L)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    registerAclReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterAclReceiver()
                    eventSink = null
                }
            })
    }

    private fun saveToDownloads(filename: String, bytes: ByteArray) {
        val mimeType = when {
            filename.endsWith(".pdf") -> "application/pdf"
            filename.endsWith(".csv") -> "text/csv"
            else -> "application/octet-stream"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
            ) ?: throw Exception("Failed to create MediaStore entry")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw Exception("Failed to open output stream")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            if (!dir.exists()) dir.mkdirs()
            FileOutputStream(File(dir, filename)).use { it.write(bytes) }
        }
    }

    private fun hasConnectPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun getBondedDevices(): List<Map<String, String>> {
        if (!hasConnectPermission()) return emptyList()
        val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            ?: return emptyList()
        return try {
            adapter.bondedDevices.map { device ->
                mapOf("name" to (device.name ?: "Unknown device"), "address" to device.address)
            }
        } catch (_: SecurityException) {
            emptyList()
        }
    }

    private fun registerAclReceiver() {
        if (aclReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val device: BluetoothDevice? =
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                val address = device?.address ?: return
                val name = try {
                    if (hasConnectPermission()) device.name ?: "Unknown device" else "Unknown device"
                } catch (_: SecurityException) {
                    "Unknown device"
                }
                val action = when (intent.action) {
                    BluetoothDevice.ACTION_ACL_CONNECTED -> "connected"
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> "disconnected"
                    else -> return
                }
                eventSink?.success(mapOf("action" to action, "address" to address, "name" to name))
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        aclReceiver = receiver
    }

    private fun unregisterAclReceiver() {
        aclReceiver?.let { unregisterReceiver(it) }
        aclReceiver = null
    }

    override fun onStart() {
        super.onStart()
        requestMissingPermissions()
        maybeRequestBatteryOptimizationExemption()
        val filter = IntentFilter(TrackingService.ACTION_STATE_CHANGED).apply {
            addAction(TrackingService.ACTION_AUTO_STOPPED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(trackingStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(trackingStateReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        try { unregisterReceiver(trackingStateReceiver) } catch (_: Exception) {}
    }

    override fun onResume() {
        super.onResume()
        // Notification tap from BluetoothAclReceiver requesting the vehicles screen.
        if (intent?.getBooleanExtra(BluetoothAclReceiver.EXTRA_OPEN_VEHICLES, false) == true) {
            intent.removeExtra(BluetoothAclReceiver.EXTRA_OPEN_VEHICLES)
            mainHandler.post {
                trackingMethodChannel?.invokeMethod("navigateToVehicles", null)
            }
            return
        }

        // configureFlutterEngine already scheduled a 1000ms-delayed
        // navigateToTracking for this cold start — don't send a duplicate.
        if (navigationAttempted) {
            navigationAttempted = false
            firstResumeDone = true
            return
        }

        // On every resume: if a trip is active, bring the tracking screen to
        // the front. Works for warm resumes, recent-apps, and home-button taps.
        // (Cold start is handled above via configureFlutterEngine's 1000ms path.)
        if (!TrackingService.isRunning) {
            firstResumeDone = true
            return
        }
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val tripId = prefs.getLong("flutter.active_trip_state_trip_id", -1L).toInt()
        if (tripId < 0) {
            firstResumeDone = true
            return
        }

        firstResumeDone = true
        mainHandler.post {
            trackingMethodChannel?.invokeMethod(
                "navigateToTracking",
                mapOf("tripId" to tripId)
            )
        }
    }

    private fun requestMissingPermissions() {
        if (permissionsAskedThisSession) return
        permissionsAskedThisSession = true

        val needed = mutableListOf<String>()

        // Android 13+: POST_NOTIFICATIONS is a runtime permission.
        // Without it foreground service notifications are silently dropped.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        // Android 10+: ACCESS_BACKGROUND_LOCATION must be requested separately,
        // after ACCESS_FINE_LOCATION is already granted, for GPS to fire when
        // the app is backgrounded or killed.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        if (needed.isNotEmpty()) {
            requestPermissions(needed.toTypedArray(), REQ_PERMISSIONS)
        }
    }

    // Show explanation dialog once per session, then open the system battery
    // optimization screen. The Drive tab also shows a persistent banner via Dart.
    private fun maybeRequestBatteryOptimizationExemption() {
        if (batteryOptAskedThisSession) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        batteryOptAskedThisSession = true

        val manufacturer = Build.MANUFACTURER.lowercase()
        val oemNote = when {
            manufacturer.contains("oppo") || manufacturer.contains("oneplus") ||
            manufacturer.contains("realme") ->
                "\n\nOn your ${Build.MANUFACTURER} device you may also need to go to:\nSettings > Battery > Power Saving > App Quick Freeze\nand disable it for MileLog."
            manufacturer.contains("samsung") ->
                "\n\nOn Samsung devices you may also need to go to:\nDevice Care > Battery > Background usage limits\nand add MileLog to Never sleeping apps."
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ||
            manufacturer.contains("poco") ->
                "\n\nOn Xiaomi/MIUI devices you may also need to go to:\nSettings > Apps > MileLog > Battery saver\nand set to No restrictions."
            manufacturer.contains("huawei") || manufacturer.contains("honor") ->
                "\n\nOn Huawei devices you may also need to go to:\nSettings > Apps > MileLog > Battery\nand enable Run in background."
            else -> ""
        }

        AlertDialog.Builder(this)
            .setTitle("Background Tracking Required")
            .setMessage(
                "MileLog needs to run in the background to track your trips.\n\n" +
                "Please tap Allow on the next screen.$oemNote"
            )
            .setPositiveButton("Continue") { _, _ ->
                openBatteryOptimizationSettings()
            }
            .setNegativeButton("Later", null)
            .show()
    }

    private fun openBatteryOptimizationSettings() {
        try {
            startActivity(Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            ))
        } catch (_: Exception) {
            // Fallback: open app details where the user can find Battery manually
            try {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                })
            } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        unregisterAclReceiver()
        AppProcessState.isEngineAlive = false
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(TrackingService.EXTRA_OPEN_TRACKING, false)) {
            pendingNavigateToTrackingId =
                intent.getIntExtra(TrackingService.EXTRA_TRIP_ID, -1)
        }
    }

    companion object {
        /** Set by [BluetoothAutoTrackPrefs] on the "connected_cold" notification's tap intent. */
        const val EXTRA_AUTO_START_VEHICLE_ID = "auto_start_vehicle_id"

        // Stores the tripId from a notification tap so Dart can pick it up via
        // consumePendingNavigateToTracking even if the engine wasn't alive when
        // onNewIntent fired.
        var pendingNavigateToTrackingId: Int = -1

        private var batteryOptAskedThisSession = false
        private var permissionsAskedThisSession = false
        private const val REQ_PERMISSIONS = 1002
    }
}
