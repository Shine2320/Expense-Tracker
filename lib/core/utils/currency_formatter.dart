import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount) {
    return NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN').format(amount);
  }

  static String formatWithoutSymbol(double amount) {
    return NumberFormat.decimalPatternDigits(decimalDigits: 2).format(amount);
  }
}
