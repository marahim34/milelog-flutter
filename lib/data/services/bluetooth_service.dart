import 'package:flutter/services.dart';

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
      MethodChannel('com.example.milelog_flutter/bluetooth');
  static const _eventChannel =
      EventChannel('com.example.milelog_flutter/bluetooth_acl');

  static Future<bool> hasPermission() async {
    final result =
        await _methodChannel.invokeMethod<bool>('hasBluetoothPermission');
    return result ?? false;
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
