import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/bluetooth_service.dart';
import 'tracking_notifier.dart';

/// App-lifetime listener that maps native Bluetooth ACL events to trip
/// start/pause, mirroring the Kotlin reference app's `BluetoothReceiver`
/// (MAC-keyed vehicle lookup, gated on `bluetoothAutoStart`).
///
/// Scope limitation (disclosed, not a bug): the native ACL receiver is
/// registered dynamically rather than via the manifest, so this only reacts
/// while the Flutter process is alive — it will not start a trip from a
/// fully-killed app. See `MainActivity.kt` and `BluetoothService`.
class BluetoothAutoTrackingController {
  BluetoothAutoTrackingController(this._ref) {
    _subscription = BluetoothService.aclEvents.listen(
      _handleEvent,
      onError: (_) {},
    );
  }

  final Ref _ref;
  late final StreamSubscription<BluetoothAclEvent> _subscription;

  Future<void> _handleEvent(BluetoothAclEvent event) async {
    final vehicleRepository = _ref.read(vehicleRepositoryProvider);
    final vehicle = await vehicleRepository.getByBluetoothMac(event.address);
    if (vehicle == null || !vehicle.bluetoothAutoStart) return;

    switch (event.action) {
      case BluetoothAclAction.connected:
        if (!_ref.exists(trackingNotifierProvider)) {
          AppRouter.router.push(AppRoutes.tracking);
          return;
        }
        final status = _ref.read(trackingNotifierProvider).status;
        if (status == TrackingStatus.paused) {
          _ref.read(trackingNotifierProvider.notifier).resume();
        }
      case BluetoothAclAction.disconnected:
        if (!_ref.exists(trackingNotifierProvider)) return;
        final status = _ref.read(trackingNotifierProvider).status;
        if (status == TrackingStatus.active) {
          _ref.read(trackingNotifierProvider.notifier).pause();
        }
    }
  }

  void dispose() => _subscription.cancel();
}

/// Kept alive for the app's lifetime by being watched once from [MileLogApp]
/// — not autoDispose, since it must keep listening even when no tracking
/// screen is open.
final bluetoothAutoTrackingProvider =
    Provider<BluetoothAutoTrackingController>((ref) {
  final controller = BluetoothAutoTrackingController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
