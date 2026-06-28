import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_providers.dart';
import 'data/models/trip_type.dart';
import 'data/services/background_tracking_service.dart';
import 'data/services/permission_onboarding_service.dart';
import 'data/services/session_service.dart';
import 'data/services/theme_preference_service.dart';
import 'features/tracking/providers/tracking_notifier.dart';
import 'features/tracking/start_trip_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be set before AppRouter.router is first accessed (in app.dart).
  AppRouter.session = SessionListenable(
    await SessionService.isLoggedIn(),
    await PermissionOnboardingService.isCompleted(),
  );

  final initialPalette = await ThemePreferenceService.getPalette();
  final initialThemeMode = await ThemePreferenceService.getThemeMode();

  // Portrait lock and the background tracking service only apply on mobile.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await BackgroundTrackingService.initialize();

    // Request battery optimisation exemption so GPS is not suspended when the
    // screen is off. Shown once — Android suppresses the dialog if already granted.
    unawaited(
      Future.microtask(() async {
        final ignored =
            await BackgroundTrackingService.isBatteryOptimizationIgnored();
        if (!ignored) {
          await BackgroundTrackingService.requestBatteryOptimization();
        }
      }),
    );

    // Listen for push calls from Kotlin:
    // - "navigateToTracking": fired by MainActivity.onResume when a trip is
    //   active and the app comes back to the foreground (any subsequent resume,
    //   not just cold-start — which DriveTab.initState already handles).
    // - "trackingStateChanged": fired by MainActivity when TrackingService
    //   broadcasts a pause/resume action from the notification buttons.
    if (Platform.isAndroid) {
      const nativeTrackingChannel =
          MethodChannel('com.aisora.goodo/tracking');
      nativeTrackingChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'navigateToTracking':
            final args = call.arguments as Map?;
            final tripId = args?['tripId'] as int?;
            if (tripId != null) {
              void doNavigate() {
                try {
                  final path = AppRouter.router.routerDelegate
                      .currentConfiguration.uri.path;
                  if (path.startsWith('/tracking')) return;
                } catch (_) {
                  return;
                }
                PendingTrackingArgs.value = TrackingScreenArgs(
                  tripType: TripType.business,
                  resumeTripId: tripId,
                );
                AppRouter.router.go(
                  AppRoutes.tracking,
                  extra: TrackingScreenArgs(
                    tripType: TripType.business,
                    resumeTripId: tripId,
                  ),
                );
              }

              // On cold start this call arrives ~1000ms after engine creation
              // (scheduled in configureFlutterEngine) — the router is already
              // mounted, so navigate immediately. On warm resume the call
              // also arrives with 0ms delay; a single post-frame callback
              // is enough to ensure the widget tree is settled.
              WidgetsBinding.instance.addPostFrameCallback((_) => doNavigate());
            }
          case 'trackingStateChanged':
            final args = call.arguments as Map?;
            final isPaused = args?['isPaused'] as bool? ?? false;
            TrackingStateBridge.pauseChanged.add(isPaused);
          case 'navigateToVehicles':
            try {
              final path = AppRouter.router.routerDelegate
                  .currentConfiguration.uri.path;
              if (!path.startsWith('/vehicles')) {
                AppRouter.router.push(AppRoutes.vehicles);
              }
            } catch (_) {}
          case 'navigateToHome':
            try {
              AppRouter.router.go(AppRoutes.home);
            } catch (_) {}
        }
        return null;
      });
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        paletteProvider.overrideWith((ref) => initialPalette),
        themeModeProvider.overrideWith((ref) => initialThemeMode),
      ],
      child: const GoOdoApp(),
    ),
  );
}
