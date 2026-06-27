import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'features/tracking/providers/bluetooth_auto_tracking_provider.dart';
import 'features/tracking/providers/trip_recovery_provider.dart';
import 'features/tracking/providers/vehicle_bluetooth_cache_sync_provider.dart';

class MileLogApp extends ConsumerWidget {
  const MileLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched once here purely to instantiate them for the app's lifetime —
    // neither has UI, they just need to keep listening/syncing.
    ref.watch(bluetoothAutoTrackingProvider);
    ref.watch(vehicleBluetoothCacheSyncProvider);
    ref.watch(coldStartAutoTrackProvider);
    ref.watch(tripRecoveryProvider);
    final palette = ref.watch(paletteProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MileLog',
      theme: AppTheme.themeFor(palette, Brightness.light),
      darkTheme: AppTheme.themeFor(palette, Brightness.dark),
      themeMode: themeMode,
      // English locale forced — no language picker.
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
