import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Persists the global default mileage rate (€/km).
///
/// Per CLAUDE.md precedence: a vehicle's `defaultMileageRate` (when > 0)
/// always overrides this — this is only the fallback used when a trip's
/// vehicle has no rate of its own.
class MileageRateService {
  MileageRateService._();

  static const _rateKey = 'default_mileage_rate';

  static Future<double> getRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rateKey) ?? AppConstants.defaultMileageRate;
  }

  static Future<void> setRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, rate);
  }
}
