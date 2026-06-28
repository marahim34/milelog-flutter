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

/// A disconnect's snapshot, held in memory while its 3-minute merge window
/// is open — see [BluetoothAutoTrackingController._handleDisconnected].
class _PendingStop {
  _PendingStop({required this.timer});
  final Timer timer;
  bool committed = false;
}

/// App-lifetime listener that maps native Bluetooth ACL events to trip
/// start/pause/waypoint recording, mirroring the Kotlin reference app's
/// `BluetoothReceiver` (MAC-keyed vehicle lookup, gated on
/// `bluetoothAutoStart`) plus a 3-minute short-stop merge window so a
/// parking-lot shuffle or a brief signal drop doesn't get recorded as two
/// separate stops.
///
/// Scope (disclosed, not a bug): the in-memory merge timer here only
/// survives while this process is alive — i.e. for the whole drive, since
/// the active foreground service keeps the process alive even when
/// backgrounded. It does not survive the process being killed outright;
/// that case is handled separately by the native static receiver +
/// WorkManager-backed durable timer (see `BluetoothAclReceiver.kt` and
/// `background_tracking_service.dart`), which drives the very same
/// [handleAclAction] entry point from a headless wake.
class BluetoothAutoTrackingController {
  BluetoothAutoTrackingController(this._ref) {
    _subscription = BluetoothService.aclEvents.listen(
      (event) => handleAclAction(action: event.action, mac: event.address),
      onError: (_) {},
    );
  }

  final Ref _ref;
  late final StreamSubscription<BluetoothAclEvent> _subscription;

  static const mergeWindow = Duration(minutes: 3);

  /// Keyed by Bluetooth MAC — at most one pending stop per vehicle.
  final Map<String, _PendingStop> _pendingStops = {};

  /// Core BT-event handling, callable directly (not just from the live ACL
  /// stream) so a headless wake driven by the native receiver can reuse the
  /// exact same vehicle-matching/merge/waypoint logic.
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
      // Native BluetoothAutoStartReceiver already created the trip and
      // started TrackingService on ACL_CONNECTED. Attempting AppRouter.push()
      // here is blocked by Android 12+ background-activity-launch restrictions
      // — it silently fails for all non-foreground states, which was the root
      // cause of "auto-start works once then stops". The user opens the app
      // via the TrackingService persistent notification; crash recovery then
      // surfaces the active trip automatically.
      return;
    }

    final notifier = _ref.read(trackingNotifierProvider.notifier);
    final status = _ref.read(trackingNotifierProvider).status;
    final pending = _pendingStops.remove(mac);

    if (pending != null) {
      pending.timer.cancel();
      if (pending.committed) {
        // The merge window had already elapsed and the stop was written —
        // this reconnect is a real resume, so record the matching waypoint.
        final snapshot = notifier.currentSnapshot;
        if (snapshot != null) {
          await _ref.read(tripRepositoryProvider).recordResumeWaypoint(
                tripId: snapshot.tripId,
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                distanceKmAtStop: snapshot.distanceKm,
              );
        }
      }
      // else: reconnected within the merge window — parking-lot shuffle,
      // nothing was ever committed, so there's nothing to undo.
    }

    if (status == TrackingStatus.paused) notifier.resume();
  }

  Future<void> _handleDisconnected(String mac, Vehicle vehicle) async {
    if (!_ref.exists(trackingNotifierProvider)) return;
    final notifier = _ref.read(trackingNotifierProvider.notifier);
    final status = _ref.read(trackingNotifierProvider).status;
    if (status != TrackingStatus.active) return;

    final snapshot = notifier.currentSnapshot;
    notifier.pause();
    if (snapshot == null) return;

    final pending = _PendingStop(
      timer: Timer(mergeWindow, () async {
        final stillPending = _pendingStops[mac];
        if (stillPending == null) return; // cancelled by a reconnect
        // If the trip ended in the meantime (notifier disposed), don't
        // attach a stray waypoint to a trip that already finished.
        if (!_ref.exists(trackingNotifierProvider)) return;
        await _ref.read(tripRepositoryProvider).recordPauseWaypoint(
              tripId: snapshot.tripId,
              latitude: snapshot.latitude,
              longitude: snapshot.longitude,
              distanceKmAtStop: snapshot.distanceKm,
            );
        stillPending.committed = true;
      }),
    );
    _pendingStops[mac] = pending;
  }

  void dispose() {
    _subscription.cancel();
    for (final pending in _pendingStops.values) {
      pending.timer.cancel();
    }
  }
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
