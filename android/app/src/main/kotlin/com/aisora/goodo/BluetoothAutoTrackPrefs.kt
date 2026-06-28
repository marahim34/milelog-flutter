package com.aisora.goodo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Durable (survives process death) bookkeeping for the killed-app side of
 * Bluetooth-driven tracking — the counterpart to
 * `BluetoothAutoTrackingController`'s in-memory 3-minute merge timer, which
 * only works while this process stays alive.
 *
 * Two SharedPreferences files are involved, deliberately kept separate:
 *  - `bt_pending_state` (native-only) — which mac currently has a stop
 *    pending/committed. Never read from Dart.
 *  - `FlutterSharedPreferences` (the `shared_preferences` plugin's own
 *    file, keys prefixed `flutter.`) — the one-shot "do this when you next
 *    wake up" instruction for the headless Dart isolate. Every value
 *    written here is a String, deliberately avoiding `putInt`/`putBoolean`:
 *    the plugin's internal encoding for non-string types has changed
 *    across versions, but String round-trips identically in all of them.
 */
object BluetoothAutoTrackPrefs {
    private const val NATIVE_PREFS = "bt_pending_state"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val MERGE_WINDOW_MINUTES = 3L
    private const val NOTIFICATION_CHANNEL_ID = "bt_auto_track"
    private const val NOTIFICATION_ID = 2001

    /** Returns an EncryptedSharedPreferences for native-only BT state. Falls back to plain prefs on error. */
    private fun nativePrefs(context: Context) = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            NATIVE_PREFS,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (_: Exception) {
        // Keystore unavailable on this device — fall back to plain prefs.
        context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
    }

    /** Called by [BluetoothAclReceiver] for a connect/disconnect that matched a cached vehicle. */
    fun handleAclEvent(context: Context, mac: String, vehicleId: Int, connected: Boolean) {
        // The in-process path (BluetoothAutoTrackingController, via MainActivity's
        // dynamic EventChannel) already handles this with live GPS data when the
        // engine is alive — acting here too would double-write waypoints.
        if (AppProcessState.isEngineAlive) return

        val nativePrefs = nativePrefs(context)
        val pendingKey = "stop_pending_$mac"
        val committedKey = "stop_committed_$mac"

        val action = if (connected) {
            when {
                nativePrefs.getBoolean(committedKey, false) -> {
                    nativePrefs.edit().remove(pendingKey).remove(committedKey).apply()
                    WorkManager.getInstance(context).cancelUniqueWork(mergeWorkName(mac))
                    "connected_after_stop"
                }
                nativePrefs.getBoolean(pendingKey, false) -> {
                    nativePrefs.edit().remove(pendingKey).apply()
                    WorkManager.getInstance(context).cancelUniqueWork(mergeWorkName(mac))
                    "connected_merge"
                }
                else -> "connected_cold"
            }
        } else {
            nativePrefs.edit().putBoolean(pendingKey, true).apply()
            scheduleMergeCheck(context, mac, vehicleId)
            "disconnected"
        }

        if (action == "connected_cold") {
            // No trip can plausibly be active (nothing was ever marked
            // pending/committed for this mac), and silently launching the UI
            // from a killed app's BroadcastReceiver is unreliable on modern
            // Android (background-activity-launch restrictions) — a tapped
            // notification is the policy-compliant way to bring the app
            // forward. The in-app start flow then proceeds exactly as if the
            // user had picked this vehicle from the start sheet themselves.
            showColdStartNotification(context, vehicleId)
            return
        }

        writePendingActionForDart(context, action, vehicleId, mac)
        wakeService(context)
    }

    /** Called by [BluetoothMergeWorker] when the 3-minute window elapses with no reconnect. */
    fun commitStop(context: Context, mac: String, vehicleId: Int) {
        // If the Flutter engine is alive the Dart-side merge timer already handled
        // the stop — committing here would duplicate the waypoint / stop the service
        // while the driver is still using the app.
        if (AppProcessState.isEngineAlive) return

        val nativePrefs = nativePrefs(context)
        val pendingKey = "stop_pending_$mac"
        if (!nativePrefs.getBoolean(pendingKey, false)) return // a reconnect already cancelled this
        nativePrefs.edit().putBoolean("stop_committed_$mac", true).remove(pendingKey).apply()
        // Stop GPS immediately — merge window elapsed with no reconnect.
        context.stopService(Intent(context, TrackingService::class.java))
        writePendingActionForDart(context, "disconnected_commit", vehicleId, mac)
        wakeService(context)
    }

    private fun scheduleMergeCheck(context: Context, mac: String, vehicleId: Int) {
        val data = Data.Builder()
            .putString("mac", mac)
            .putInt("vehicleId", vehicleId)
            .build()
        val request = OneTimeWorkRequestBuilder<BluetoothMergeWorker>()
            .setInitialDelay(MERGE_WINDOW_MINUTES, TimeUnit.MINUTES)
            .setInputData(data)
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(mergeWorkName(mac), ExistingWorkPolicy.REPLACE, request)
    }

    private fun mergeWorkName(mac: String) = "bt_merge_$mac"

    private fun writePendingActionForDart(context: Context, action: String, vehicleId: Int, mac: String) {
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).edit()
            .putString("flutter.bt_pending_action", action)
            .putString("flutter.bt_pending_vehicle_id", vehicleId.toString())
            .putString("flutter.bt_pending_mac", mac)
            .apply()
    }

    private fun wakeService(context: Context) {
        // flutter_background_service's own Android service — starting it
        // boots a separate, headless FlutterEngine that runs the Dart
        // entrypoint configured in BackgroundTrackingService.initialize,
        // which checks the pending-action flag written above.
        val intent = Intent()
        intent.setClassName(context, "id.flutter.flutter_background_service.BackgroundService")
        ContextCompat.startForegroundService(context, intent)
    }

    private fun showColdStartNotification(context: Context, vehicleId: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Bluetooth auto-tracking",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_AUTO_START_VEHICLE_ID, vehicleId)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            vehicleId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("GoOdo")
            .setContentText("Your vehicle's Bluetooth connected — tap to start tracking")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }
}
