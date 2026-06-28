import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../providers/repository_providers.dart';

/// Broadcasts pause/resume events that originate from the native notification buttons.
/// [main.dart] feeds this from the MethodChannel; [TrackingScreen] consumes it.
class TrackingStateBridge {
  static final StreamController<bool> pauseChanged =
      StreamController<bool>.broadcast();
}

/// Manages the foreground tracking service lifecycle.
///
/// On Android: delegates to the native [TrackingService.kt] foreground service,
/// which runs independently of the Flutter engine (surviving process kill) and
/// acquires a PARTIAL_WAKE_LOCK so the CPU stays alive during tracking.
///
/// On iOS: delegates to [flutter_background_service] which registers the
/// background location mode declared in Info.plist.
class BackgroundTrackingService {
  BackgroundTrackingService._();

  static const _trackingChannel =
      MethodChannel('com.example.milelog_flutter/tracking');
  static final _service = FlutterBackgroundService();

  /// Registers the flutter_background_service handlers (iOS + Android Bluetooth).
  ///
  /// On Android the native [TrackingService] is started on demand via MethodChannel —
  /// no upfront flutter_background_service configuration is needed for tracking.
  /// We still configure the service here for the Bluetooth killed-app path
  /// (BluetoothAclReceiver.kt can wake flutter_background_service to write waypoints).
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

  /// Starts the foreground tracking service.
  ///
  /// On Android starts the native [TrackingService] with [tripId] and
  /// [startTimeMs] so it can write GPS points to the correct trip row even
  /// after the Flutter engine is killed. Safe to call when already running.
  static Future<void> start({
    int? tripId,
    int? startTimeMs,
    double? odometerStart,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _trackingChannel.invokeMethod<void>('startTracking', {
          'tripId': tripId ?? -1,
          'startTimeMs': startTimeMs ?? DateTime.now().millisecondsSinceEpoch,
          'odometerStart': odometerStart ?? 0.0,
        });
      } catch (_) {
        // Non-fatal — GPS still runs on the main isolate as fallback.
      }
      return;
    }
    if (await _service.isRunning()) return;
    await _service.startService();
  }

  /// Stops the foreground tracking service. Safe to call when not running.
  static Future<void> stop() async {
    if (Platform.isAndroid) {
      try {
        await _trackingChannel.invokeMethod<void>('stopTracking');
      } catch (_) {}
      return;
    }
    if (!await _service.isRunning()) return;
    _service.invoke('stopService');
  }

  /// Pushes the latest distance/duration into the persistent notification.
  ///
  /// On Android this is a no-op — [TrackingService.kt] updates the notification
  /// on its own 30-second timer so there is no need to call from Dart.
  static Future<void> updateNotification({
    required double distanceKm,
    required int elapsedSeconds,
  }) async {
    if (Platform.isAndroid) return;
    if (!await _service.isRunning()) return;
    _service.invoke('updateNotification', {
      'distanceKm': distanceKm,
      'elapsedSeconds': elapsedSeconds,
    });
  }

  /// Asks Android to exempt the app from battery optimisation so GPS is not
  /// suspended when the screen turns off. No-op if already granted or on iOS.
  static Future<void> requestBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    try {
      await _trackingChannel
          .invokeMethod<void>('requestBatteryOptimization');
    } catch (_) {}
  }

  /// Returns true if [TrackingService] is currently in a paused state
  /// (GPS stopped via the Pause notification button). Always false on iOS.
  static Future<bool> isNativePaused() async {
    if (!Platform.isAndroid) return false;
    try {
      final state = await _trackingChannel
          .invokeMethod<Map<Object?, Object?>>('getTrackingState');
      return state?['isPaused'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when Android has whitelisted the app from battery
  /// optimisation, or always true on iOS.
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _trackingChannel
              .invokeMethod<bool>('isBatteryOptimizationIgnored') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Runs in the flutter_background_service isolate (iOS foreground handler
/// and Android Bluetooth wake-up path). Must be a top-level function.
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

  // Handles Bluetooth-triggered waypoints when the app is killed.
  unawaited(_handlePendingBluetoothAction());
}

/// Reads and clears the pending Bluetooth action left by [BluetoothAutoTrackPrefs]
/// and writes the appropriate waypoint to the database.
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
      return;
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
