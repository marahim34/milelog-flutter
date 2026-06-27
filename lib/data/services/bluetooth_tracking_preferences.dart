import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's global choice to enable/disable Bluetooth-triggered
/// auto-tracking — a master switch independent of the OS Bluetooth
/// permission (which the app can request but never revoke on the user's
/// behalf) and independent of each vehicle's own `bluetoothAutoStart`
/// toggle. See Settings → Preferences → "Bluetooth Auto-Tracking".
class BluetoothTrackingPreferences {
  BluetoothTrackingPreferences._();

  static const _enabledKey = 'bluetooth_auto_tracking_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
