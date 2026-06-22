import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

import '../../core/constants/app_constants.dart';

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
        notificationChannelId: AppConstants.trackingNotificationChannelId,
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
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${secs}s';
}
