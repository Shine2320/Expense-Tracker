import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final payerNameProvider = StateNotifierProvider<PayerNameNotifier, String>((ref) {
  return PayerNameNotifier();
});

class PayerNameNotifier extends StateNotifier<String> {
  static const _key = 'payer_name';

  PayerNameNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? '';
  }

  Future<void> setPayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
    state = name;
  }
}
