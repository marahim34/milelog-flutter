import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/theme_preference_service.dart';
import 'app_theme.dart';

/// Initial values are loaded in `main.dart` (before `runApp`) and supplied
/// as provider overrides, mirroring how `SessionListenable` is seeded — so
/// there's no flash of the wrong palette/mode on cold start.
final paletteProvider = StateProvider<AppPalette>((ref) => AppPalette.rose);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Updates both the persisted preference and the live provider state.
Future<void> setAppPalette(WidgetRef ref, AppPalette palette) async {
  await ThemePreferenceService.setPalette(palette);
  ref.read(paletteProvider.notifier).state = palette;
}

Future<void> setAppThemeMode(WidgetRef ref, ThemeMode mode) async {
  await ThemePreferenceService.setThemeMode(mode);
  ref.read(themeModeProvider.notifier).state = mode;
}
