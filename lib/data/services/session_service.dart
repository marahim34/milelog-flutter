import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user is logged in across app/process restarts.
/// Local-only flag — there is no real backend auth yet (see CLAUDE.md).
class SessionService {
  SessionService._();

  static const _isLoggedInKey = 'is_logged_in';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }
}
