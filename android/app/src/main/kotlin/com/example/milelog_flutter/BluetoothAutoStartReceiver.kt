package com.example.milelog_flutter

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Static (manifest-declared) receiver for Bluetooth ACL events and BOOT_COMPLETED.
 *
 * Replaces the old [BluetoothAclReceiver] + dynamic `MainActivity` registration
 * pattern. This receiver fires for every Bluetooth connect/disconnect regardless
 * of whether the Flutter engine is alive, which is the core fix for the
 * "auto-start only works once" bug:
 *
 *   Old flow (broken on Android 12+):
 *     connect → if(isEngineAlive) return → Dart tries AppRouter.push() → BLOCKED
 *
 *   New flow:
 *     connect → query DB directly → create trip if needed → start TrackingService
 *     (TrackingService shows its own persistent "Tracking active" notification)
 *
 * ACL_DISCONNECTED delegates to [BluetoothAutoTrackPrefs] for the 3-minute
 * merge window, then stops [TrackingService] once the window commits.
 *
 * BOOT_COMPLETED is a no-op — the registration alone lifts Android's
 * "stopped state" restriction so ACL events are delivered after reboot.
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
        // When the engine is alive the dynamic EventChannel in MainActivity
        // already forwards this connect to Dart's BluetoothAutoTrackingController.
        // Acting here too would open a second DB write path and potentially
        // create duplicate trips alongside an already-active Dart session.
        if (AppProcessState.isEngineAlive) return

        val vehicle = queryVehicle(context, mac) ?: return
        if (!vehicle.autoStart) return

        // Re-use an already-active trip for this vehicle so a brief signal drop
        // or reconnect within the 3-min merge window doesn't create a duplicate.
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
        // In-app case: Dart's BluetoothAutoTrackingController listens to the
        // dynamic EventChannel in MainActivity and handles the pause + merge
        // window in memory. Let it run — acting here too would double-write.
        if (AppProcessState.isEngineAlive) return

        // Killed-app case: look up vehicleId from DB (same logic, no stale cache).
        val vehicle = queryVehicle(context, mac) ?: return

        // Stop GPS immediately on disconnect; TrackingService will flush its
        // point buffer. The 3-min WorkManager job (scheduled below via
        // BluetoothAutoTrackPrefs) may restart it on reconnect.
        context.stopService(Intent(context, TrackingService::class.java))

        BluetoothAutoTrackPrefs.handleAclEvent(context, mac, vehicle.id, connected = false)
    }

    // ── Database helpers ──────────────────────────────────────────────────────

    private data class VehicleRow(val id: Int, val plateNumber: String, val autoStart: Boolean)

    /** Opens the Drift SQLite file for a read/write cursor. Returns null on failure. */
    private fun openDb(context: Context): SQLiteDatabase? = try {
        // drift_flutter places the DB in getApplicationDocumentsDirectory(),
        // which path_provider_android resolves to <dataDir>/app_flutter/.
        // dataDir = filesDir.parentFile (i.e. /data/user/0/<pkg>/, NOT .../files/).
        val path = context.filesDir.parentFile!!.absolutePath + "/app_flutter/milelog.sqlite"
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
}
