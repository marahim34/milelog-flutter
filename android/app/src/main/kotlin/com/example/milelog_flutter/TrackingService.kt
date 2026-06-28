package com.example.milelog_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * Native Android foreground service for GPS trip tracking.
 *
 * Uses LocationManager.GPS_PROVIDER directly (not FusedLocationProviderClient)
 * so OEM battery managers (OPPO/Xiaomi/Samsung) cannot throttle or kill GPS
 * through Play Services.
 *
 * Survives the app being swiped from recents (stopWithTask=false) and acquires
 * a PARTIAL_WAKE_LOCK to prevent the CPU from sleeping between GPS fixes.
 *
 * When the Flutter engine is alive, GPS points are written by the Dart side
 * to avoid duplicate rows. When the engine is dead this service writes points
 * directly to SQLite every 5 seconds so no data is lost on process kill.
 */
class TrackingService : Service() {

    private var tripId: Int = -1
    private var startTimeMs: Long = 0L
    private var odometerStart: Double = 0.0
    private var stoppedIntentionally = false
    private var initialized = false

    private lateinit var locationManager: LocationManager
    private lateinit var locationListener: LocationListener
    private var wakeLock: PowerManager.WakeLock? = null
    private var db: SQLiteDatabase? = null

    private var totalDistanceKm = 0.0
    private var firstLocation: Location? = null
    private var lastLocation: Location? = null
    private val pointBuffer = mutableListOf<Location>()
    private val bufferLock = Any()
    private var lastFlushMs = 0L

    // Inactivity auto-stop
    private var lastMovementTimeMs = System.currentTimeMillis()
    private var lastKnownLat = 0.0
    private var lastKnownLng = 0.0
    private var inactivityRunnable: Runnable? = null

    private lateinit var dbThread: HandlerThread
    private lateinit var dbHandler: Handler
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        const val CHANNEL_ID = "milelog_tracking"
        const val NOTIFICATION_ID = 1001
        const val INACTIVITY_NOTIFICATION_ID = 1002
        const val AUTO_STOP_NOTIFICATION_ID = 1003
        const val ACTION_STOP = "com.example.milelog_flutter.STOP_TRACKING"
        const val ACTION_PAUSE = "com.example.milelog_flutter.PAUSE_TRACKING"
        const val ACTION_RESUME = "com.example.milelog_flutter.RESUME_TRACKING"
        const val ACTION_KEEP_ACTIVE = "com.example.milelog_flutter.KEEP_ACTIVE"
        const val ACTION_STATE_CHANGED = "com.example.milelog_flutter.TRACKING_STATE_CHANGED"
        const val ACTION_AUTO_STOPPED = "com.example.milelog_flutter.AUTO_STOPPED"
        const val EXTRA_TRIP_ID = "trip_id"
        const val EXTRA_START_TIME = "start_time"
        const val EXTRA_ODOMETER_START = "odometer_start"
        const val EXTRA_OPEN_TRACKING = "open_tracking"

        private const val INACTIVITY_CHANNEL_ID = "milelog_alerts"
        private const val INACTIVITY_IDLE_MS = 60L * 60_000L  // 60 minutes
        private const val INACTIVITY_WARN_MS  = 50L * 60_000L  // 50 minutes

        /** True while the service has started and not yet destroyed. */
        var isRunning = false
        /** True while GPS is intentionally stopped via the Pause notification action. */
        var isPaused = false

        fun startIntent(
            context: Context,
            tripId: Int,
            startTimeMs: Long,
            odometerStart: Double = 0.0,
        ): Intent =
            Intent(context, TrackingService::class.java).apply {
                putExtra(EXTRA_TRIP_ID, tripId)
                putExtra(EXTRA_START_TIME, startTimeMs)
                putExtra(EXTRA_ODOMETER_START, odometerStart)
            }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        dbThread = HandlerThread("MileLog-DB").also { it.start() }
        dbHandler = Handler(dbThread.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stoppedIntentionally = true
                // When the Flutter engine is dead, finalize the trip in Kotlin so the
                // completed record appears in the Logs tab on next launch.
                if (!AppProcessState.isEngineAlive && tripId >= 0) {
                    dbHandler.post {
                        if (db == null) openDatabase()
                        flushPoints()
                        finalizeTrip()
                        mainHandler.post { stopSelf() }
                    }
                } else {
                    stopSelf()
                }
                return START_NOT_STICKY
            }
            ACTION_PAUSE -> {
                if (!isPaused) {
                    isPaused = true
                    stopInactivityChecker()
                    try { locationManager.removeUpdates(locationListener) } catch (_: Exception) {}
                    writePauseWaypoint()
                    updateNotification()
                    broadcastState()
                }
                return START_STICKY
            }
            ACTION_RESUME -> {
                if (isPaused) {
                    isPaused = false
                    lastMovementTimeMs = System.currentTimeMillis()
                    startLocationUpdates()
                    startInactivityChecker()
                    writeResumeWaypoint()
                    updateNotification()
                    broadcastState()
                }
                return START_STICKY
            }
            ACTION_KEEP_ACTIVE -> {
                lastMovementTimeMs = System.currentTimeMillis()
                getSystemService(NotificationManager::class.java).cancel(INACTIVITY_NOTIFICATION_ID)
                return START_STICKY
            }
        }

        isRunning = true
        tripId = intent?.getIntExtra(EXTRA_TRIP_ID, -1) ?: -1
        startTimeMs = intent?.getLongExtra(EXTRA_START_TIME, System.currentTimeMillis())
            ?: System.currentTimeMillis()
        odometerStart = intent?.getDoubleExtra(EXTRA_ODOMETER_START, 0.0) ?: 0.0

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        // Guard against double-initialisation: onTaskRemoved calls startForegroundService
        // while the service is still alive, which triggers a second onStartCommand. Without
        // this flag we'd register a duplicate GPS listener and a second WakeLock.
        if (!initialized) {
            initialized = true
            acquireWakeLock()
            dbHandler.post { openDatabase() }
            startLocationUpdates()
            scheduleNotificationUpdates()
            startInactivityChecker()
        }

        return START_REDELIVER_INTENT
    }

    // Called when the user swipes the app away from recents. On OEM devices
    // (OPPO/Xiaomi/Samsung) the OS can kill a foreground service despite
    // stopWithTask="false". We schedule an immediate restart here — the
    // service is still alive when this fires, so tripId/startTimeMs are intact.
    override fun onTaskRemoved(rootIntent: Intent?) {
        if (stoppedIntentionally || tripId < 0) return
        val restartIntent = startIntent(applicationContext, tripId, startTimeMs, odometerStart)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.startForegroundService(restartIntent)
        } else {
            applicationContext.startService(restartIntent)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)
            if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
            mgr.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "MileLog Tracking",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Active GPS trip tracking"
                    setShowBadge(false)
                }
            )
        }
    }

    private fun buildNotification() = run {
        val stopPi = PendingIntent.getService(
            this, 0,
            Intent(this, TrackingService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val pauseResumePi = PendingIntent.getService(
            this, 1,
            Intent(this, TrackingService::class.java).apply {
                action = if (isPaused) ACTION_RESUME else ACTION_PAUSE
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openPi = PendingIntent.getActivity(
            this, 2,
            (packageManager.getLaunchIntentForPackage(packageName) ?: Intent()).apply {
                putExtra(EXTRA_OPEN_TRACKING, true)
                putExtra(EXTRA_TRIP_ID, tripId)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val title = if (isPaused) "MileLog — Trip Paused" else "MileLog — Tracking Active"
        val pauseLabel = if (isPaused) "Resume" else "Pause"
        val pauseIcon = if (isPaused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("${"%.1f".format(totalDistanceKm)} km · ${formatElapsed()}")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(openPi)
            .setOngoing(true)
            .addAction(pauseIcon, pauseLabel, pauseResumePi)
            .addAction(android.R.drawable.ic_delete, "Stop Trip", stopPi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification())
    }

    private fun broadcastState() {
        sendBroadcast(Intent(ACTION_STATE_CHANGED).apply {
            putExtra("isPaused", isPaused)
            setPackage(packageName)
        })
    }

    private fun writePauseWaypoint() {
        val loc = lastLocation ?: return
        dbHandler.post {
            val localDb = db ?: run { openDatabase(); db } ?: return@post
            try {
                localDb.insertOrThrow("trip_waypoints", null, ContentValues().apply {
                    put("trip_id", tripId)
                    put("latitude", loc.latitude)
                    put("longitude", loc.longitude)
                    put("address", "")
                    put("distance_km_at_stop", totalDistanceKm)
                    put("timestamp", System.currentTimeMillis())
                    put("is_pause", 1)
                })
            } catch (_: Exception) {}
        }
    }

    private fun writeResumeWaypoint() {
        val loc = lastLocation ?: return
        dbHandler.post {
            val localDb = db ?: run { openDatabase(); db } ?: return@post
            try {
                localDb.insertOrThrow("trip_waypoints", null, ContentValues().apply {
                    put("trip_id", tripId)
                    put("latitude", loc.latitude)
                    put("longitude", loc.longitude)
                    put("address", "")
                    put("distance_km_at_stop", totalDistanceKm)
                    put("timestamp", System.currentTimeMillis())
                    put("is_pause", 0)
                })
            } catch (_: Exception) {}
        }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("WakelockTimeout")
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MileLog:TrackingWakeLock"
        ).also { it.acquire(12 * 60 * 60 * 1000L) }
    }

    private fun openDatabase() {
        try {
            // drift_flutter places the DB in getApplicationDocumentsDirectory(),
            // which path_provider_android resolves to <dataDir>/app_flutter/.
            // dataDir = filesDir.parentFile (i.e. /data/user/0/<pkg>/, NOT .../files/).
            val path = filesDir.parentFile!!.absolutePath + "/app_flutter/milelog.sqlite"
            db = SQLiteDatabase.openDatabase(
                path, null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.NO_LOCALIZED_COLLATORS
            )
        } catch (_: Exception) {
            // DB not yet initialised by Flutter — will retry on next flush.
        }
    }

    private fun startLocationUpdates() {
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        locationListener = LocationListener { loc ->
            // Filter out low-accuracy fixes (> 50m accuracy radius)
            if (loc.accuracy <= 50f) onNewLocation(loc)
        }
        try {
            // GPS_PROVIDER: direct hardware, not throttled by Play Services or OEM battery managers.
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    5_000L,  // minTimeMs — at most one update per 5 s
                    5f,      // minDistanceMeters — at least 5 m of movement
                    locationListener,
                    Looper.getMainLooper()
                )
            }
            // NETWORK_PROVIDER: lower accuracy but faster initial fix and useful indoors.
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    10_000L, // network updates less frequently
                    10f,
                    locationListener,
                    Looper.getMainLooper()
                )
            }
        } catch (_: SecurityException) {}
    }

    private fun onNewLocation(loc: Location) {
        if (firstLocation == null) {
            firstLocation = loc
            // Seed inactivity position from first real GPS fix
            lastKnownLat = loc.latitude
            lastKnownLng = loc.longitude
            lastMovementTimeMs = System.currentTimeMillis()
        }
        lastLocation?.let { prev ->
            val d = FloatArray(1)
            Location.distanceBetween(
                prev.latitude, prev.longitude,
                loc.latitude, loc.longitude, d
            )
            totalDistanceKm += d[0] / 1000.0
        }
        lastLocation = loc

        // Reset inactivity timer whenever the vehicle moves > 50 m
        if (lastKnownLat != 0.0 || lastKnownLng != 0.0) {
            val moved = FloatArray(1)
            Location.distanceBetween(lastKnownLat, lastKnownLng, loc.latitude, loc.longitude, moved)
            if (moved[0] > 50f) {
                lastMovementTimeMs = System.currentTimeMillis()
                lastKnownLat = loc.latitude
                lastKnownLng = loc.longitude
                // Dismiss stale warning if vehicle is moving again
                getSystemService(NotificationManager::class.java).cancel(INACTIVITY_NOTIFICATION_ID)
            }
        }

        // Only write to DB when the Flutter engine is dead — when alive the Dart side
        // writes location_points to avoid duplicate rows in the distance calculation.
        if (!AppProcessState.isEngineAlive) {
            synchronized(bufferLock) { pointBuffer.add(loc) }
            val now = System.currentTimeMillis()
            if (now - lastFlushMs >= 5_000L) {
                lastFlushMs = now
                dbHandler.post { flushPoints() }
            }
        }
    }

    private fun flushPoints() {
        val localDb = db ?: run { openDatabase(); db } ?: return
        val points = synchronized(bufferLock) {
            val copy = pointBuffer.toList()
            pointBuffer.clear()
            copy
        }
        if (points.isEmpty()) return
        try {
            localDb.beginTransaction()
            for (loc in points) {
                localDb.insertOrThrow("location_points", null, ContentValues().apply {
                    put("trip_id", tripId)
                    put("latitude", loc.latitude)
                    put("longitude", loc.longitude)
                    put("speed_kmh", loc.speed * 3.6)
                    put("accuracy_meters", loc.accuracy.toDouble())
                    put("altitude", loc.altitude)
                    put("timestamp", loc.time)
                    put("provider", loc.provider ?: "gps")
                })
            }
            localDb.setTransactionSuccessful()
        } catch (_: Exception) {
        } finally {
            try { localDb.endTransaction() } catch (_: Exception) {}
        }
    }

    // Calculates total distance from all saved location_points, geocodes start/end
    // addresses, and writes the completed trip row. Called on the DB thread when
    // ACTION_STOP arrives with engine dead (notification stop while app is swiped away).
    private fun finalizeTrip() {
        val localDb = db ?: return
        try {
            var totalKm = 0.0
            var prevLat: Double? = null
            var prevLon: Double? = null
            var firstLat: Double? = null
            var firstLon: Double? = null
            var lastLat: Double? = null
            var lastLon: Double? = null

            localDb.rawQuery(
                "SELECT latitude, longitude FROM location_points WHERE trip_id = ? ORDER BY timestamp ASC",
                arrayOf(tripId.toString())
            ).use { c ->
                while (c.moveToNext()) {
                    val lat = c.getDouble(0)
                    val lon = c.getDouble(1)
                    if (firstLat == null) { firstLat = lat; firstLon = lon }
                    lastLat = lat; lastLon = lon
                    if (prevLat != null) {
                        val d = FloatArray(1)
                        Location.distanceBetween(prevLat!!, prevLon!!, lat, lon, d)
                        totalKm += d[0] / 1000.0
                    }
                    prevLat = lat; prevLon = lon
                }
            }

            val startAddr = if (firstLat != null) geocode(firstLat!!, firstLon!!) else ""
            val endAddr   = if (lastLat  != null) geocode(lastLat!!,  lastLon!!)  else ""
            val odomEnd   = odometerStart + totalKm

            localDb.execSQL(
                "UPDATE trips SET is_active = 0, end_time = ?, distance_km = ?, " +
                "start_address = ?, end_address = ?, odometer_start = ?, odometer_end = ? " +
                "WHERE id = ?",
                arrayOf(System.currentTimeMillis(), totalKm, startAddr, endAddr,
                        odometerStart, odomEnd, tripId)
            )
        } catch (_: Exception) {
            // On failure the trip stays is_active=true; recovery dialog handles it on next launch.
        }
    }

    // Reverse-geocodes a lat/lon to a short address string.
    // Falls back to "lat, lon" coordinates if Geocoder is unavailable or returns no results.
    @Suppress("DEPRECATION")
    private fun geocode(lat: Double, lon: Double): String {
        return try {
            val addresses = Geocoder(this, Locale.getDefault()).getFromLocation(lat, lon, 1)
            if (!addresses.isNullOrEmpty()) {
                val addr = addresses[0]
                buildString {
                    addr.thoroughfare?.let { append(it) }
                    addr.locality?.let { if (isNotEmpty()) append(", "); append(it) }
                    if (isEmpty()) addr.adminArea?.let { append(it) }
                    if (isEmpty()) append("%.4f, %.4f".format(lat, lon))
                }
            } else {
                "%.4f, %.4f".format(lat, lon)
            }
        } catch (_: Exception) {
            "%.4f, %.4f".format(lat, lon)
        }
    }

    private fun scheduleNotificationUpdates() {
        mainHandler.postDelayed(object : Runnable {
            override fun run() {
                getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, buildNotification())
                mainHandler.postDelayed(this, 30_000L)
            }
        }, 30_000L)
    }

    override fun onDestroy() {
        isRunning = false
        isPaused = false
        stopInactivityChecker()
        mainHandler.removeCallbacksAndMessages(null)
        getSystemService(NotificationManager::class.java).cancel(INACTIVITY_NOTIFICATION_ID)
        try { locationManager.removeUpdates(locationListener) } catch (_: Exception) {}
        dbHandler.removeCallbacksAndMessages(null)
        if (!AppProcessState.isEngineAlive) flushPoints()
        try { db?.close() } catch (_: Exception) {}
        dbThread.quitSafely()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    private fun startInactivityChecker() {
        stopInactivityChecker()
        val runnable = object : Runnable {
            override fun run() {
                val idleMs = System.currentTimeMillis() - lastMovementTimeMs
                when {
                    idleMs >= INACTIVITY_IDLE_MS -> autoStopTrip()
                    idleMs >= INACTIVITY_WARN_MS -> {
                        showInactivityWarning()
                        mainHandler.postDelayed(this, 60_000L)
                    }
                    else -> mainHandler.postDelayed(this, 60_000L)
                }
            }
        }
        inactivityRunnable = runnable
        mainHandler.postDelayed(runnable, 60_000L)
    }

    private fun stopInactivityChecker() {
        inactivityRunnable?.let { mainHandler.removeCallbacks(it) }
        inactivityRunnable = null
    }

    private fun showInactivityWarning() {
        createInactivityChannel()
        val keepActivePi = PendingIntent.getService(
            this, 10,
            Intent(this, TrackingService::class.java).apply { action = ACTION_KEEP_ACTIVE },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, INACTIVITY_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("MileLog — Inactivity Warning")
            .setContentText("No movement for 50 min. Trip auto-stops in 10 min.")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("No movement detected for 50 minutes. Trip will auto-stop in 10 minutes."))
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(false)
            .addAction(android.R.drawable.ic_media_play, "Keep Active", keepActivePi)
            .build()
        getSystemService(NotificationManager::class.java).notify(INACTIVITY_NOTIFICATION_ID, notification)
    }

    private fun autoStopTrip() {
        stoppedIntentionally = true
        stopInactivityChecker()
        try { locationManager.removeUpdates(locationListener) } catch (_: Exception) {}
        getSystemService(NotificationManager::class.java).cancel(INACTIVITY_NOTIFICATION_ID)
        clearActiveTrip()
        sendBroadcast(Intent(ACTION_AUTO_STOPPED).apply { setPackage(packageName) })
        if (tripId >= 0) {
            dbHandler.post {
                if (db == null) openDatabase()
                flushPoints()
                finalizeTrip()
                mainHandler.post {
                    showAutoStoppedNotification()
                    stopSelf()
                }
            }
        } else {
            stopSelf()
        }
    }

    private fun showAutoStoppedNotification() {
        createInactivityChannel()
        val elapsed = (System.currentTimeMillis() - startTimeMs) / 1000
        val h = elapsed / 3600; val m = (elapsed % 3600) / 60
        val dur = if (h > 0) "${h}h ${m}m" else "${m}m"
        val body = "Trip saved: ${"%.1f".format(totalDistanceKm)} km in $dur. Stopped due to inactivity."
        val openPi = PendingIntent.getActivity(
            this, 20,
            (packageManager.getLaunchIntentForPackage(packageName) ?: Intent()).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, INACTIVITY_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("MileLog — Trip Auto-Stopped")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPi)
            .build()
        getSystemService(NotificationManager::class.java).notify(AUTO_STOP_NOTIFICATION_ID, notification)
    }

    private fun createInactivityChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(INACTIVITY_CHANNEL_ID) == null) {
                nm.createNotificationChannel(NotificationChannel(
                    INACTIVITY_CHANNEL_ID,
                    "MileLog Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { enableVibration(true) })
            }
        }
    }

    private fun clearActiveTrip() {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().apply {
            remove("flutter.active_trip_state_trip_id")
            remove("flutter.active_trip_state_start_time")
            remove("flutter.active_trip_state_distance")
            remove("flutter.active_trip_state_route_points")
            remove("flutter.active_trip_state_elapsed_seconds")
            apply()
        }
    }

    private fun formatElapsed(): String {
        val secs = (System.currentTimeMillis() - startTimeMs) / 1000
        val h = secs / 3600
        val m = (secs % 3600) / 60
        return if (h > 0) "${h}h ${m}m" else "${m}m"
    }
}
