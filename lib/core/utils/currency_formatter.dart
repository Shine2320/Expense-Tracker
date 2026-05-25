import 'package:intl/intl.dart';
import '../../data/models/currency_config.dart';

class CurrencyFormatter {
  static String format(double amount, CurrencyConfig currency) {
    return NumberFormat.currency(symbol: currency.symbol, decimalDigits: 2, locale: currency.locale).format(amount);
  }

  static String formatWithoutSymbol(double amount) {
    return NumberFormat.decimalPatternDigits(decimalDigits: 2).format(amount);
  }
}
