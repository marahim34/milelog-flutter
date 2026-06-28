import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/bluetooth_service.dart';
import '../../home/providers/bluetooth_auto_tracking_enabled_provider.dart';
import 'tracking_notifier.dart';
import 'tracking_screen_args.dart';

/// Tracks a pending BT disconnect while its 20-second debounce window is open.
class _PendingDebounce {
  _PendingDebounce({required this.timer});
  final Timer timer;
}

/// App-lifetime listener that maps native Bluetooth ACL events to trip
/// pause/resume, with a 20-second debounce on disconnect to absorb brief
/// signal drops, engine restarts, and car startup delays without recording
/// a false pause waypoint.
///
/// Lifecycle:
///   ACL_DISCONNECTED   → start 20-second debounce timer
///   Reconnect < 20 s   → cancel timer; continue tracking as if nothing happened
///   No reconnect ≥ 20 s → [TrackingNotifier.pause] (which also writes the pause
///                         waypoint with a reverse-geocoded address)
///   ACL_CONNECTED (paused) → [TrackingNotifier.resume] (writes resume waypoint)
///
/// Scope: the in-memory debounce timer only survives while this process is alive
/// (i.e. for the whole drive, since TrackingService keeps the process alive even
/// when backgrounded). The killed-app path is handled by [BluetoothAutoStartReceiver]
/// in Kotlin, which runs the same 20-second debounce via a companion-object Handler.
class BluetoothAutoTrackingController {
  BluetoothAutoTrackingController(this._ref) {
    _subscription = BluetoothService.aclEvents.listen(
      (event) => handleAclAction(action: event.action, mac: event.address),
      onError: (_) {},
    );
  }

  final Ref _ref;
  late final StreamSubscription<BluetoothAclEvent> _subscription;

  /// Keyed by Bluetooth MAC — at most one pending debounce timer per vehicle.
  final Map<String, _PendingDebounce> _pendingDebounces = {};

  /// Core BT-event handling, callable directly (not just from the live ACL
  /// stream) so a headless wake driven by the native receiver can reuse the
  /// exact same vehicle-matching/debounce/waypoint logic.
  Future<void> handleAclAction({
    required BluetoothAclAction action,
    required String mac,
  }) async {
    final masterEnabled =
        await _ref.read(bluetoothAutoTrackingEnabledProvider.future);
    if (!masterEnabled) return;

    final vehicleRepository = _ref.read(vehicleRepositoryProvider);
    final vehicle = await vehicleRepository.getByBluetoothMac(mac);
    if (vehicle == null || !vehicle.bluetoothAutoStart) return;

    switch (action) {
      case BluetoothAclAction.connected:
        await _handleConnected(mac, vehicle);
      case BluetoothAclAction.disconnected:
        await _handleDisconnected(mac, vehicle);
    }
  }

  Future<void> _handleConnected(String mac, Vehicle vehicle) async {
    if (!_ref.exists(trackingNotifierProvider)) {
      // Native BluetoothAutoStartReceiver already handled this in the killed-app
      // path — the trip was started via TrackingService notification. Attempting
      // AppRouter.push() here is blocked by Android 12+ background-activity-launch
      // restrictions. The user opens the app via the persistent notification;
      // crash recovery surfaces the active trip automatically.
      return;
    }

    final notifier = _ref.read(trackingNotifierProvider.notifier);
    final status = _ref.read(trackingNotifierProvider).status;

    // Reconnected within the 20-second debounce window — cancel the pending
    // pause timer and continue tracking without any waypoints.
    final pending = _pendingDebounces.remove(mac);
    if (pending != null) {
      pending.timer.cancel();
      return;
    }

    // No pending debounce: either a fresh connect or a reconnect after the
    // trip was already paused (debounce fired).
    if (status == TrackingStatus.paused) {
      notifier.resume(); // also writes resume waypoint with geocoded address
    }
  }

  Future<void> _handleDisconnected(String mac, Vehicle vehicle) async {
    if (!_ref.exists(trackingNotifierProvider)) return;
    final status = _ref.read(trackingNotifierProvider).status;
    if (status != TrackingStatus.active) return;

    // Cancel any existing debounce (rapid multi-disconnect for the same vehicle).
    _pendingDebounces[mac]?.timer.cancel();
    _pendingDebounces.remove(mac);

    // Start the 20-second debounce. If BT reconnects within this window,
    // _handleConnected cancels the timer and tracking continues uninterrupted.
    // After 20 seconds with no reconnect, we pause the trip — notifier.pause()
    // stops GPS and writes the pause waypoint (with geocoded address).
    _pendingDebounces[mac] = _PendingDebounce(
      timer: Timer(const Duration(seconds: 20), () {
        _pendingDebounces.remove(mac);
        if (!_ref.exists(trackingNotifierProvider)) return;
        final currentStatus = _ref.read(trackingNotifierProvider).status;
        if (currentStatus != TrackingStatus.active) return;
        _ref.read(trackingNotifierProvider.notifier).pause();
      }),
    );
  }

  void dispose() {
    _subscription.cancel();
    for (final pending in _pendingDebounces.values) {
      pending.timer.cancel();
    }
    _pendingDebounces.clear();
  }
}

/// Kept alive for the app's lifetime by being watched once from [GoOdoApp]
/// — not autoDispose, since it must keep listening even when no tracking
/// screen is open.
final bluetoothAutoTrackingProvider =
    Provider<BluetoothAutoTrackingController>((ref) {
  final controller = BluetoothAutoTrackingController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// One-shot check, on every app launch, for whether this launch was caused
/// by tapping the native "Bluetooth connected — tap to start tracking"
/// notification (the cold/killed-app case where no trip was active to
/// attach a waypoint to — see `BluetoothAutoTrackPrefs.kt`). If so, opens
/// the tracking screen pre-filled for that vehicle, same as picking it from
/// the start sheet.
final coldStartAutoTrackProvider = Provider<void>((ref) {
  unawaited(BluetoothService.consumePendingAutoStartVehicleId().then((id) {
    if (id == null) return;
    AppRouter.router.push(
      AppRoutes.tracking,
      extra: TrackingScreenArgs(vehicleId: id, tripType: TripType.business),
    );
  }));
});
