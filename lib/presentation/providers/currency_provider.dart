import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/currency_config.dart';

final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyConfig>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<CurrencyConfig> {
  static const _key = 'selected_currency';

  CurrencyNotifier() : super(CurrencyConfig.supported[0]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'USD';
    state = CurrencyConfig.fromCode(code);
  }

  Future<void> setCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    state = CurrencyConfig.fromCode(code);
  }
}
