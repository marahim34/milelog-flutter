package com.example.milelog_flutter

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
            BluetoothDevice.ACTION_ACL_CONNECTED, BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                val mac = device?.address ?: return
                val vehicleId = lookupVehicleId(context, mac) ?: return
                val connected = intent.action == BluetoothDevice.ACTION_ACL_CONNECTED
                BluetoothAutoTrackPrefs.handleAclEvent(context, mac, vehicleId, connected)
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
}
