import 'package:flutter/material.dart';

class CurrencyConfig {
  final String name;
  final String symbol;
  final String code;
  final String locale;
  final IconData icon;

  const CurrencyConfig({
    required this.name,
    required this.symbol,
    required this.code,
    required this.locale,
    required this.icon,
  });

  static const List<CurrencyConfig> supported = [
    CurrencyConfig(name: 'US Dollar', symbol: '\$', code: 'USD', locale: 'en_US', icon: Icons.attach_money),
    CurrencyConfig(name: 'Indian Rupee', symbol: '₹', code: 'INR', locale: 'en_IN', icon: Icons.currency_rupee),
    CurrencyConfig(name: 'Euro', symbol: '€', code: 'EUR', locale: 'de_DE', icon: Icons.euro),
    CurrencyConfig(name: 'British Pound', symbol: '£', code: 'GBP', locale: 'en_GB', icon: Icons.currency_pound),
    CurrencyConfig(name: 'Japanese Yen', symbol: '¥', code: 'JPY', locale: 'ja_JP', icon: Icons.currency_yen),
    CurrencyConfig(name: 'Canadian Dollar', symbol: 'CA\$', code: 'CAD', locale: 'en_CA', icon: Icons.attach_money),
    CurrencyConfig(name: 'Australian Dollar', symbol: 'AU\$', code: 'AUD', locale: 'en_AU', icon: Icons.attach_money),
    CurrencyConfig(name: 'Swiss Franc', symbol: 'CHF', code: 'CHF', locale: 'de_CH', icon: Icons.attach_money),
    CurrencyConfig(name: 'Chinese Yuan', symbol: '¥', code: 'CNY', locale: 'zh_CN', icon: Icons.currency_yuan),
    CurrencyConfig(name: 'South Korean Won', symbol: '₩', code: 'KRW', locale: 'ko_KR', icon: Icons.attach_money),
    CurrencyConfig(name: 'Swedish Krona', symbol: 'kr', code: 'SEK', locale: 'sv_SE', icon: Icons.attach_money),
    CurrencyConfig(name: 'Norwegian Krone', symbol: 'kr', code: 'NOK', locale: 'nb_NO', icon: Icons.attach_money),
    CurrencyConfig(name: 'Danish Krone', symbol: 'kr', code: 'DKK', locale: 'da_DK', icon: Icons.attach_money),
    CurrencyConfig(name: 'New Zealand Dollar', symbol: 'NZ\$', code: 'NZD', locale: 'en_NZ', icon: Icons.attach_money),
    CurrencyConfig(name: 'Mexican Peso', symbol: 'MX\$', code: 'MXN', locale: 'es_MX', icon: Icons.attach_money),
    CurrencyConfig(name: 'Singapore Dollar', symbol: 'S\$', code: 'SGD', locale: 'en_SG', icon: Icons.attach_money),
    CurrencyConfig(name: 'Hong Kong Dollar', symbol: 'HK\$', code: 'HKD', locale: 'en_HK', icon: Icons.attach_money),
    CurrencyConfig(name: 'Malaysian Ringgit', symbol: 'RM', code: 'MYR', locale: 'ms_MY', icon: Icons.attach_money),
    CurrencyConfig(name: 'Thai Baht', symbol: '฿', code: 'THB', locale: 'th_TH', icon: Icons.attach_money),
    CurrencyConfig(name: 'Philippine Peso', symbol: '₱', code: 'PHP', locale: 'en_PH', icon: Icons.attach_money),
    CurrencyConfig(name: 'South African Rand', symbol: 'R', code: 'ZAR', locale: 'en_ZA', icon: Icons.attach_money),
    CurrencyConfig(name: 'Brazilian Real', symbol: 'R\$', code: 'BRL', locale: 'pt_BR', icon: Icons.attach_money),
    CurrencyConfig(name: 'Taiwan Dollar', symbol: 'NT\$', code: 'TWD', locale: 'zh_TW', icon: Icons.attach_money),
    CurrencyConfig(name: 'UAE Dirham', symbol: 'د.إ', code: 'AED', locale: 'ar_AE', icon: Icons.attach_money),
    CurrencyConfig(name: 'Turkish Lira', symbol: '₺', code: 'TRY', locale: 'tr_TR', icon: Icons.attach_money),
    CurrencyConfig(name: 'Russian Ruble', symbol: '₽', code: 'RUB', locale: 'ru_RU', icon: Icons.attach_money),
    CurrencyConfig(name: 'Polish Zloty', symbol: 'zł', code: 'PLN', locale: 'pl_PL', icon: Icons.attach_money),
    CurrencyConfig(name: 'Indonesian Rupiah', symbol: 'Rp', code: 'IDR', locale: 'id_ID', icon: Icons.attach_money),
  ];

  static CurrencyConfig fromCode(String code) {
    return supported.firstWhere(
      (c) => c.code == code,
      orElse: () => supported[0],
    );
  }
}
