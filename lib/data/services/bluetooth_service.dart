import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BluetoothAclAction { connected, disconnected }

class BluetoothAclEvent {
  const BluetoothAclEvent({
    required this.action,
    required this.address,
    required this.name,
  });

  final BluetoothAclAction action;
  final String address;
  final String name;
}

class BondedDevice {
  const BondedDevice({required this.name, required this.address});

  final String name;
  final String address;
}

/// Dart-side wrapper for the native classic-Bluetooth glue in `MainActivity`.
///
/// Scope limitation (by design): the ACL stream only fires while this
/// process is alive — the receiver is registered dynamically, not via the
/// manifest, so it cannot wake the app from a fully-killed state.
class BluetoothService {
  BluetoothService._();

  static const _methodChannel =
      MethodChannel('com.aisora.goodo/bluetooth');
  static const _eventChannel =
      EventChannel('com.aisora.goodo/bluetooth_acl');

  static Future<bool> hasPermission() async {
    final result =
        await _methodChannel.invokeMethod<bool>('hasBluetoothPermission');
    return result ?? false;
  }

  /// Checks whether `MainActivity` was just launched from the "Bluetooth
  /// connected — tap to start tracking" notification shown when no trip was
  /// active to attach a stop/resume waypoint to (see
  /// `BluetoothAutoTrackPrefs.showColdStartNotification` on the native
  /// side) — the policy-compliant alternative to a fully silent launch,
  /// since Android restricts starting activities from a killed app's
  /// BroadcastReceiver. Call once at app startup; returns null on every
  /// other launch.
  static Future<int?> consumePendingAutoStartVehicleId() {
    return _methodChannel
        .invokeMethod<int>('consumePendingAutoStartVehicleId');
  }

  /// Key the native `BluetoothAclReceiver.kt` reads — relies on the
  /// documented, stable `shared_preferences` plugin convention (Android
  /// SharedPreferences file `FlutterSharedPreferences`, each key prefixed
  /// `flutter.`) rather than a custom MethodChannel, since that file is
  /// readable by plain Android code with no Flutter engine running at all
  /// — exactly the killed-app case this cache exists for.
  static const vehicleCacheKey = 'bt_vehicle_mac_cache';

  /// Pushes the current mac->vehicleId map (already filtered to
  /// `bluetoothAutoStart`-enabled vehicles) into SharedPreferences, so
  /// `BluetoothAclReceiver` can match a connect/disconnect to a vehicle
  /// even when this process — and the Drift database connection with it —
  /// is dead. See `vehicleBluetoothCacheSyncProvider`.
  static Future<void> syncVehicleCache(Map<String, int> macToVehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(vehicleCacheKey, jsonEncode(macToVehicleId));
  }

  static Future<List<BondedDevice>> getBondedDevices() async {
    final result =
        await _methodChannel.invokeMethod<List<Object?>>('getBondedDevices');
    if (result == null) return [];
    return result
        .whereType<Map<Object?, Object?>>()
        .map((m) => BondedDevice(
              name: m['name'] as String? ?? 'Unknown device',
              address: m['address'] as String? ?? '',
            ))
        .where((d) => d.address.isNotEmpty)
        .toList();
  }

  static Stream<BluetoothAclEvent> get aclEvents {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = event as Map<Object?, Object?>;
      final action = map['action'] == 'connected'
          ? BluetoothAclAction.connected
          : BluetoothAclAction.disconnected;
      return BluetoothAclEvent(
        action: action,
        address: map['address'] as String? ?? '',
        name: map['name'] as String? ?? 'Unknown device',
      );
    });
  }
}
