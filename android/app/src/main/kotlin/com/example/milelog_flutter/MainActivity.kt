package com.example.milelog_flutter

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Classic-Bluetooth glue with no pub.dev equivalent: bonded-device lookup and
 * ACL connect/disconnect observation. Mirrors the MAC-keyed vehicle lookup
 * done in the Kotlin reference app's `BluetoothReceiver` — this layer only
 * forwards raw events; vehicle matching and trip start/pause stay in Dart.
 *
 * The ACL receiver is registered dynamically (not via the manifest), so it
 * only fires while this process is alive — it will not wake the app from a
 * fully-killed state. That's a deliberate, disclosed scope limitation.
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.milelog_flutter/bluetooth"
    private val eventChannelName = "com.example.milelog_flutter/bluetooth_acl"

    private var eventSink: EventChannel.EventSink? = null
    private var aclReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBondedDevices" -> result.success(getBondedDevices())
                    "hasBluetoothPermission" -> result.success(hasConnectPermission())
                    else -> result.notImplemented()
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
        super.onDestroy()
    }
}
