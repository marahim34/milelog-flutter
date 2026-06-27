import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../providers/repository_providers.dart';

/// Keeps the app process alive as an Android foreground service while a
/// trip is being tracked, so GPS collection in `LocationTrackingService`
/// (running on the main isolate) survives the screen locking or the app
/// being minimized.
///
/// Android grants a whole process the importance of its most active
/// component — a foreground service with a visible notification is enough
/// to keep the entire process (main UI isolate, the active geolocator
/// stream, Riverpod state, the open Drift connection) from being killed by
/// the low-memory killer while backgrounded. The actual GPS/distance logic
/// intentionally stays on the main isolate rather than being duplicated
/// into the service's own isolate — this isolate only hosts the
/// persistent notification and relays live distance/duration into it via
/// [updateNotification]. (iOS has no equivalent "foreground service"
/// concept; true iOS background continuation needs Always location
/// permission + the `location` UIBackgroundMode, which is a separate,
/// larger change not included here.)
class BackgroundTrackingService {
  BackgroundTrackingService._();

  static final _service = FlutterBackgroundService();

  /// Registers the background service handlers. Call once at app startup
  /// (see `main.dart`), before [start] is ever called.
  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        initialNotificationTitle: 'MileLog',
        initialNotificationContent: 'Preparing to track your trip…',
        foregroundServiceNotificationId: AppConstants.trackingNotificationId,
        foregroundServiceTypes: const [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Starts the foreground service and its persistent notification.
  /// Safe to call when already running — it no-ops.
  static Future<void> start() async {
    if (await _service.isRunning()) return;
    await _service.startService();
  }

  /// Stops the foreground service and dismisses its notification. Safe to
  /// call when not running.
  static Future<void> stop() async {
    if (!await _service.isRunning()) return;
    _service.invoke('stopService');
  }

  /// Pushes the latest distance/duration into the persistent notification.
  static Future<void> updateNotification({
    required double distanceKm,
    required int elapsedSeconds,
  }) async {
    if (!await _service.isRunning()) return;
    _service.invoke('updateNotification', {
      'distanceKm': distanceKm,
      'elapsedSeconds': elapsedSeconds,
    });
  }
}

/// Runs on a separate isolate hosted by the Android foreground service (or
/// briefly per background fetch on iOS). Must be a top-level function — see
/// the flutter_background_service requirements.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  service.on('updateNotification').listen((args) {
    if (service is! AndroidServiceInstance || args == null) return;

    final distanceKm = (args['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final elapsedSeconds = (args['elapsedSeconds'] as num?)?.toInt() ?? 0;

    service.setForegroundNotificationInfo(
      title: 'MileLog — Tracking',
      content:
          '${distanceKm.toStringAsFixed(1)} km • ${_formatDuration(elapsedSeconds)}',
    );
  });

  // This service can be started two ways: normally (a live trip's
  // foreground notification — _initialize in tracking_notifier.dart) or
  // woken by BluetoothAclReceiver.kt for a killed-app Bluetooth event,
  // which writes a one-shot instruction into SharedPreferences before
  // starting it. Check for that instruction every time this isolate boots.
  unawaited(_handlePendingBluetoothAction());
}

/// Reads and clears the pending Bluetooth action `BluetoothAutoTrackPrefs`
/// (native) leaves for this headless isolate — see its class doc for the
/// full action set. Only `disconnected_commit` (the 3-minute merge window
/// elapsed with no reconnect) and `connected_after_stop` (reconnect after
/// that commit) need a DB write here; `disconnected`/`connected_merge`
/// have nothing to do without a live `LocationTrackingService` to
/// pause/resume, and `connected_cold` is handled natively via a tap-to-
/// launch notification instead of reaching here at all.
///
/// Builds its own standalone [ProviderContainer] — this isolate has no
/// `ProviderScope` widget tree, but the repository/DAO providers don't need
/// one; they only need a container to be read from, same as in any test.
Future<void> _handlePendingBluetoothAction() async {
  final prefs = await SharedPreferences.getInstance();
  final action = prefs.getString('bt_pending_action');
  if (action == null) return;
  await prefs.remove('bt_pending_action');
  final vehicleIdRaw = prefs.getString('bt_pending_vehicle_id');
  await prefs.remove('bt_pending_vehicle_id');
  await prefs.remove('bt_pending_mac');

  if (action != 'disconnected_commit' && action != 'connected_after_stop') {
    return;
  }
  final vehicleId = int.tryParse(vehicleIdRaw ?? '');
  if (vehicleId == null) return;

  final container = ProviderContainer();
  try {
    final vehicleRepository = container.read(vehicleRepositoryProvider);
    final vehicle = await vehicleRepository.getById(vehicleId);
    if (vehicle == null) return;

    final tripRepository = container.read(tripRepositoryProvider);
    final trip =
        await tripRepository.getActiveTripForVehicle(vehicle.plateNumber);
    if (trip == null) return;

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      return; // Best-effort — no fix, no waypoint.
    }

    final distanceKm =
        await tripRepository.calculateDistanceFromPersistedPoints(trip.id);

    if (action == 'disconnected_commit') {
      await tripRepository.recordPauseWaypoint(
        tripId: trip.id,
        latitude: position.latitude,
        longitude: position.longitude,
        distanceKmAtStop: distanceKm,
      );
    } else {
      await tripRepository.recordResumeWaypoint(
        tripId: trip.id,
        latitude: position.latitude,
        longitude: position.longitude,
        distanceKmAtStop: distanceKm,
      );
    }
  } finally {
    container.dispose();
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${secs}s';
}
