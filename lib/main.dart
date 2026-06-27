import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme_providers.dart';
import 'data/services/background_tracking_service.dart';
import 'data/services/permission_onboarding_service.dart';
import 'data/services/session_service.dart';
import 'data/services/theme_preference_service.dart';

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
  }

  runApp(
    ProviderScope(
      overrides: [
        paletteProvider.overrideWith((ref) => initialPalette),
        themeModeProvider.overrideWith((ref) => initialThemeMode),
      ],
      child: const MileLogApp(),
    ),
  );
}
