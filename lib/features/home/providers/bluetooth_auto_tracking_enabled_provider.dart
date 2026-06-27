import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/bluetooth_tracking_preferences.dart';

/// Master on/off switch for Bluetooth-triggered auto-tracking — checked by
/// `BluetoothAutoTrackingController` before acting on any ACL event, ahead
/// of (and independent from) each vehicle's own `bluetoothAutoStart` flag.
/// Backs Settings' "Bluetooth Auto-Tracking" toggle.
class BluetoothAutoTrackingEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => BluetoothTrackingPreferences.isEnabled();

  Future<void> setEnabled(bool value) async {
    await BluetoothTrackingPreferences.setEnabled(value);
    state = AsyncData(value);
  }
}

final bluetoothAutoTrackingEnabledProvider =
    AsyncNotifierProvider<BluetoothAutoTrackingEnabledNotifier, bool>(
  BluetoothAutoTrackingEnabledNotifier.new,
);
