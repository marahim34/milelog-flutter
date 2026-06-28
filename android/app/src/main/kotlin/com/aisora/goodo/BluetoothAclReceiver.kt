package com.aisora.goodo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * Static (manifest-declared) receiver for classic-Bluetooth ACL connect/
 * disconnect and `BOOT_COMPLETED`. Unlike the dynamic receiver registered
 * in `MainActivity.configureFlutterEngine`, this fires even when the app
 * process is fully killed — which is what lets a parked, never-opened-
 * since-boot phone still detect "got in the car" against a configured
 * vehicle. See `BluetoothAutoTrackPrefs` for what happens next.
 *
 * `BOOT_COMPLETED` itself is handled as a no-op: merely being registered
 * for it, and receiving it, is what lifts Android's "stopped state"
 * restriction so the ACL actions below actually get delivered after a
 * reboot, before the user has launched the app even once.
 */
class BluetoothAclReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> {
                val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                val mac = device?.address ?: return
                val vehicleId = lookupVehicleId(context, mac)

                if (vehicleId == null) {
                    // MAC not in paired-vehicle cache. Only alert if no vehicles exist at all.
                    if (queryVehicleCount(context) == 0) {
                        showAlertNotification(
                            context,
                            title = "GoOdo — Vehicle Required",
                            content = "Bluetooth connected but no vehicle registered. " +
                                "Open GoOdo to add your vehicle.",
                            openVehicles = true,
                        )
                    }
                    return
                }

                val odometer = queryInitialOdometer(context, vehicleId)
                if (odometer <= 0.0) {
                    showAlertNotification(
                        context,
                        title = "GoOdo — Odometer Required",
                        content = "Please set your vehicle's odometer reading before tracking can start.",
                        openVehicles = true,
                    )
                    return
                }

                BluetoothAutoTrackPrefs.handleAclEvent(context, mac, vehicleId, connected = true)
            }
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                val mac = device?.address ?: return
                val vehicleId = lookupVehicleId(context, mac) ?: return
                BluetoothAutoTrackPrefs.handleAclEvent(context, mac, vehicleId, connected = false)
            }
            else -> return // includes BOOT_COMPLETED — see class doc.
        }
    }

    /**
     * Reads the mac->vehicleId cache written by Dart's
     * `BluetoothService.syncVehicleCache` — relies on the `shared_preferences`
     * plugin's stable on-disk convention (file `FlutterSharedPreferences`,
     * keys prefixed `flutter.`) so this works with no Flutter engine running
     * at all, exactly the killed-app case this receiver exists for.
     */
    private fun lookupVehicleId(context: Context, mac: String): Int? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("flutter.bt_vehicle_mac_cache", null) ?: return null
        return try {
            val value = JSONObject(json).opt(mac) ?: return null
            (value as? Number)?.toInt()
        } catch (_: Exception) {
            null
        }
    }

    /** Returns total number of vehicles in the Drift SQLite database. */
    private fun queryVehicleCount(context: Context): Int {
        val dir = context.filesDir.parentFile ?: return 0
        val dbPath = dir.absolutePath + "/app_flutter/goodo.sqlite"
        return try {
            android.database.sqlite.SQLiteDatabase.openDatabase(
                dbPath, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY
            ).use { db ->
                db.rawQuery("SELECT COUNT(*) FROM vehicles", null).use { c ->
                    if (c.moveToFirst()) c.getInt(0) else 0
                }
            }
        } catch (_: Exception) {
            0
        }
    }

    /** Returns `initialOdometer` for the given vehicle id, or 0.0 on any error. */
    private fun queryInitialOdometer(context: Context, vehicleId: Int): Double {
        val dir = context.filesDir.parentFile ?: return 0.0
        val dbPath = dir.absolutePath + "/app_flutter/goodo.sqlite"
        return try {
            android.database.sqlite.SQLiteDatabase.openDatabase(
                dbPath, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY
            ).use { db ->
                db.rawQuery(
                    "SELECT initial_odometer FROM vehicles WHERE id = ?",
                    arrayOf(vehicleId.toString())
                ).use { c ->
                    if (c.moveToFirst()) c.getDouble(0) else 0.0
                }
            }
        } catch (_: Exception) {
            0.0
        }
    }

    private fun showAlertNotification(
        context: Context,
        title: String,
        content: String,
        openVehicles: Boolean,
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "GoOdo Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { enableVibration(true) }
            nm.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                if (openVehicles) putExtra(EXTRA_OPEN_VEHICLES, true)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(
            context, ALERT_NOTIFICATION_ID, launchIntent ?: Intent(), piFlags)

        val notification = NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        nm.notify(ALERT_NOTIFICATION_ID, notification)
    }

    companion object {
        private const val ALERT_CHANNEL_ID = "goodo_alerts"
        private const val ALERT_NOTIFICATION_ID = 9002
        const val EXTRA_OPEN_VEHICLES = "open_vehicles"
    }
}
