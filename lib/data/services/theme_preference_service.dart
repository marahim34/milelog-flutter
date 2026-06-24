import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// Persists the user's palette and dark/light/system mode choice across
/// app restarts.
class ThemePreferenceService {
  ThemePreferenceService._();

  static const _paletteKey = 'app_palette';
  static const _themeModeKey = 'app_theme_mode';

  static Future<AppPalette> getPalette() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_paletteKey);
    return AppPalette.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AppPalette.rose,
    );
  }

  static Future<void> setPalette(AppPalette palette) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.dark,
    );
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}
