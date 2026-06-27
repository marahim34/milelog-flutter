package com.example.milelog_flutter

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
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
    private val eventChannelName = "com.example.milelog_flutter/bluetooth_acl"

    private var eventSink: EventChannel.EventSink? = null
    private var aclReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())

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

    override fun onDestroy() {
        unregisterAclReceiver()
        AppProcessState.isEngineAlive = false
        super.onDestroy()
    }

    companion object {
        /** Set by [BluetoothAutoTrackPrefs] on the "connected_cold" notification's tap intent. */
        const val EXTRA_AUTO_START_VEHICLE_ID = "auto_start_vehicle_id"
    }
}
