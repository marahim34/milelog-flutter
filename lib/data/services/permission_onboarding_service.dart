import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has been through the first-launch permission
/// onboarding (location explanation + request, then an optional Bluetooth
/// explanation + request) — shown once, before login, then never again.
class PermissionOnboardingService {
  PermissionOnboardingService._();

  static const _completedKey = 'permission_onboarding_completed';

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> setCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, value);
  }
}
