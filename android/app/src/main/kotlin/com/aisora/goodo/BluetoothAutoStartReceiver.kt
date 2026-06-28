package com.aisora.goodo

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat

/**
 * Static (manifest-declared) receiver for Bluetooth ACL events and BOOT_COMPLETED.
 *
 * Trip lifecycle — killed-app / backgrounded path (engine dead):
 *
 *   ACL_DISCONNECTED → start a 20-second debounce timer (handles engine restarts,
 *                      brief signal drops, and car startup delay without recording
 *                      a false pause waypoint)
 *   Reconnect < 20 s  → cancel the timer; continue tracking as if nothing happened
 *   No reconnect ≥ 20 s → send ACTION_PAUSE to TrackingService; the service stops
 *                         GPS and writes the pause waypoint immediately
 *
 *   ACL_CONNECTED (service already paused) → send ACTION_RESUME
 *   ACL_CONNECTED (service not running)    → start new trip or re-use existing active one
 *
 * When the Flutter engine is alive ([AppProcessState.isEngineAlive] = true) all
 * handling is delegated to Dart's [BluetoothAutoTrackingController] which runs
 * its own 20-second debounce. This receiver is the killed-app fallback.
 *
 * BOOT_COMPLETED is a no-op — the registration alone lifts Android's "stopped
 * state" restriction so ACL events are delivered after a reboot.
 */
class BluetoothAutoStartReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> {
                if (!hasConnectPermission(context)) return
                val mac = deviceMac(intent) ?: return
                handleConnect(context, mac)
            }
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                if (!hasConnectPermission(context)) return
                val mac = deviceMac(intent) ?: return
                handleDisconnect(context, mac)
            }
            // BOOT_COMPLETED — intentional no-op; see class doc.
        }
    }

    // ── Connect ───────────────────────────────────────────────────────────────

    private fun handleConnect(context: Context, mac: String) {
        if (AppProcessState.isEngineAlive) return

        val vehicle = queryVehicle(context, mac) ?: return
        if (!vehicle.autoStart) return

        // Reconnected within the 20-second debounce window — cancel the pending
        // pause and continue tracking without recording any waypoint.
        if (pendingMac == mac) {
            cancelPendingPause()
            if (TrackingService.isRunning && !TrackingService.isPaused) return
        }

        if (TrackingService.isRunning) {
            // Service is alive — resume if paused, otherwise already tracking.
            if (TrackingService.isPaused) {
                sendActionToService(context, TrackingService.ACTION_RESUME)
            }
            return
        }

        // Service not running — re-use an existing active trip or create a new one.
        val existing = queryActiveTrip(context, vehicle.plateNumber)
        val tripId: Int
        val startMs: Long
        if (existing != null) {
            tripId = existing.first
            startMs = existing.second
        } else {
            startMs = System.currentTimeMillis()
            tripId = insertTrip(context, vehicle.plateNumber, startMs)
            if (tripId < 0) return
        }
        val svc = TrackingService.startIntent(context, tripId, startMs)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svc)
        } else {
            context.startService(svc)
        }
    }

    // ── Disconnect ────────────────────────────────────────────────────────────

    private fun handleDisconnect(context: Context, mac: String) {
        if (AppProcessState.isEngineAlive) return

        queryVehicle(context, mac) ?: return

        // Only act when the service is actively tracking (not already paused/stopped).
        if (!TrackingService.isRunning || TrackingService.isPaused) return

        // Cancel any existing debounce (rapid multi-disconnect for the same vehicle).
        cancelPendingPause()

        // Start the 20-second debounce. Reconnect within this window cancels the
        // timer — no pause, no waypoint. After 20 s with no reconnect the service
        // is paused and writes the pause waypoint immediately inside ACTION_PAUSE.
        val appContext = context.applicationContext
        val r = Runnable {
            pendingPause = null
            pendingMac = null
            if (TrackingService.isRunning && !TrackingService.isPaused) {
                sendActionToService(appContext, TrackingService.ACTION_PAUSE)
            }
        }
        pendingMac = mac
        pendingPause = r
        mainHandler.postDelayed(r, DEBOUNCE_MS)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Sends an action intent to TrackingService (guaranteed already running here). */
    private fun sendActionToService(context: Context, action: String) {
        // The service is already running — use startService so Android doesn't
        // enforce the 5-second startForeground() deadline for new services.
        context.startService(
            Intent(context, TrackingService::class.java).apply { this.action = action }
        )
    }

    private fun cancelPendingPause() {
        pendingPause?.let { mainHandler.removeCallbacks(it) }
        pendingPause = null
        pendingMac = null
    }

    // ── Database helpers ──────────────────────────────────────────────────────

    private data class VehicleRow(val id: Int, val plateNumber: String, val autoStart: Boolean)

    /** Opens the Drift SQLite file for a read/write cursor. Returns null on failure. */
    private fun openDb(context: Context): SQLiteDatabase? = try {
        // drift_flutter places the DB in getApplicationDocumentsDirectory(),
        // which path_provider_android resolves to <dataDir>/app_flutter/.
        // dataDir = filesDir.parentFile (i.e. /data/user/0/<pkg>/, NOT .../files/).
        val path = context.filesDir.parentFile!!.absolutePath + "/app_flutter/goodo.sqlite"
        SQLiteDatabase.openDatabase(
            path, null,
            SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.NO_LOCALIZED_COLLATORS
        )
    } catch (_: Exception) { null }

    private fun queryVehicle(context: Context, mac: String): VehicleRow? {
        val db = openDb(context) ?: return null
        return try {
            db.rawQuery(
                "SELECT id, plate_number, bluetooth_auto_start FROM vehicles WHERE bluetooth_mac = ? LIMIT 1",
                arrayOf(mac)
            ).use { c ->
                if (!c.moveToFirst()) return null
                VehicleRow(
                    id = c.getInt(0),
                    plateNumber = c.getString(1) ?: return null,
                    autoStart = c.getInt(2) != 0
                )
            }
        } catch (_: Exception) { null } finally { db.close() }
    }

    /** Returns (tripId, startTimeMs) for the most recent active trip for this vehicle. */
    private fun queryActiveTrip(context: Context, plateNumber: String): Pair<Int, Long>? {
        val db = openDb(context) ?: return null
        return try {
            db.rawQuery(
                "SELECT id, start_time FROM trips WHERE is_active = 1 AND vehicle_number = ? ORDER BY start_time DESC LIMIT 1",
                arrayOf(plateNumber)
            ).use { c ->
                if (!c.moveToFirst()) null
                else Pair(c.getInt(0), c.getLong(1))
            }
        } catch (_: Exception) { null } finally { db.close() }
    }

    /** Inserts a new active trip row and returns its row id, or -1 on failure. */
    private fun insertTrip(context: Context, plateNumber: String, startMs: Long): Int {
        val db = openDb(context) ?: return -1
        return try {
            db.insertOrThrow("trips", null, ContentValues().apply {
                put("start_time", startMs)
                put("is_active", 1)
                put("trip_type", "business")
                put("vehicle_number", plateNumber)
                put("auto_started", 1)
                put("distance_km", 0.0)
                put("company_name", "")
                put("notes", "")
                put("mileage_rate", 0.0)
                put("odometer_start", 0.0)
                put("odometer_end", 0.0)
                put("max_speed_kmh", 0.0)
                put("avg_speed_kmh", 0.0)
                put("start_address", "")
                put("end_address", "")
                put("is_synced", 0)
            }).toInt()
        } catch (_: Exception) { -1 } finally { db.close() }
    }

    // ── Permission helper ─────────────────────────────────────────────────────

    private fun hasConnectPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.BLUETOOTH_CONNECT
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun deviceMac(intent: Intent): String? =
        intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)?.address

    // ── Companion (20-second debounce state) ──────────────────────────────────

    companion object {
        private const val DEBOUNCE_MS = 20_000L

        private val mainHandler = Handler(Looper.getMainLooper())

        /** MAC address that currently has a pending 20-second pause timer, or null. */
        @Volatile private var pendingMac: String? = null

        /** The pending Runnable scheduled via [mainHandler], or null. */
        @Volatile private var pendingPause: Runnable? = null
    }
}
