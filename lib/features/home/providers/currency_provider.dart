import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCurrencyKey = 'currency_code';

const supportedCurrencies = [
  ('EUR', 'Euro'),
  ('USD', 'US Dollar'),
  ('GBP', 'British Pound'),
  ('BDT', 'Bangladeshi Taka'),
  ('INR', 'Indian Rupee'),
  ('CHF', 'Swiss Franc'),
  ('SEK', 'Swedish Krona'),
  ('NOK', 'Norwegian Krone'),
  ('DKK', 'Danish Krone'),
  ('AUD', 'Australian Dollar'),
  ('CAD', 'Canadian Dollar'),
  ('JPY', 'Japanese Yen'),
];

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('EUR') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kCurrencyKey) ?? 'EUR';
  }

  Future<void> setCurrency(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencyKey, code);
  }
}

final currencyCodeProvider =
    StateNotifierProvider<CurrencyNotifier, String>((ref) => CurrencyNotifier());
