import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/bluetooth_service.dart';

final _vehiclesForBtCacheProvider = StreamProvider<List<Vehicle>>(
  (ref) => ref.watch(vehicleRepositoryProvider).watchAll(),
);

/// Keeps the native mac->vehicleId cache (read by `BluetoothAclReceiver`,
/// a static manifest receiver that can fire while this process is dead)
/// in sync with the `vehicles` table.
///
/// This is what lets a killed-app Bluetooth connect/disconnect be matched
/// to a vehicle without the receiver touching the Drift database directly
/// — see `BluetoothAclReceiver.kt`. Only vehicles with `bluetoothAutoStart`
/// enabled are cached, since that's the same gate
/// `BluetoothAutoTrackingController` applies for the live-process path.
final vehicleBluetoothCacheSyncProvider = Provider<void>((ref) {
  ref.listen(_vehiclesForBtCacheProvider, (previous, next) {
    final vehicles = next.value;
    if (vehicles == null) return;
    final cache = <String, int>{};
    for (final vehicle in vehicles) {
      final mac = vehicle.bluetoothMac;
      if (mac != null && mac.isNotEmpty && vehicle.bluetoothAutoStart) {
        cache[mac] = vehicle.id;
      }
    }
    unawaited(BluetoothService.syncVehicleCache(cache));
  }, fireImmediately: true);
});
