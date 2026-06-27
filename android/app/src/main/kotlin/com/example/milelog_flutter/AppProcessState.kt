package com.example.milelog_flutter

/**
 * Whether the Flutter engine behind `MainActivity` is currently alive in
 * this process. Set true in `MainActivity.configureFlutterEngine`, false in
 * `onDestroy`.
 *
 * [BluetoothAclReceiver] checks this before acting: when the engine is
 * alive, the dynamic ACL EventChannel registered by `MainActivity` already
 * delivers the same connect/disconnect event in-process to
 * `BluetoothAutoTrackingController`, which has live GPS data and handles
 * the 3-minute merge window itself (see tracking_notifier.dart). Acting
 * again here would double-write waypoints. Only when the engine is *not*
 * alive does the receiver take over via the durable WorkManager-backed
 * path — see `BluetoothAutoTrackPrefs`.
 */
object AppProcessState {
    @Volatile
    var isEngineAlive: Boolean = false
}
