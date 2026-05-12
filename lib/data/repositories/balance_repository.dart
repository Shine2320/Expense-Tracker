import 'package:hive/hive.dart';
import '../datasources/hive_storage.dart';
import '../models/monthly_balance_model.dart';
import '../../core/utils/date_utils.dart' as utils;

class BalanceRepository {
  Box<MonthlyBalanceModel> get _box => HiveStorage.monthlyBalanceBoxRef;

  MonthlyBalanceModel getCurrentMonthBalance() {
    final monthKey = utils.DateUtils.formatMonthKey(DateTime.now());
    var balance = _box.get(monthKey);

    if (balance == null) {
      balance = MonthlyBalanceModel(id: monthKey);
      _box.put(monthKey, balance);

      _carryOverFromPreviousMonth(balance);
    }

    return balance;
  }

  MonthlyBalanceModel getMonthBalance(DateTime date) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    return _box.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);
  }

  List<MonthlyBalanceModel> getAllMonthBalances() {
    return _box.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> updateSalary(double salary) async {
    final balance = getCurrentMonthBalance();
    balance.salary = salary;
    await balance.save();
  }

  Future<void> updateCarryOver(double carryOver) async {
    final balance = getCurrentMonthBalance();
    balance.carryOver = carryOver;
    await balance.save();
  }

  Future<void> setMonthSalary(String monthKey, double salary) async {
    final balance = _box.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);
    balance.salary = salary;
    await _box.put(monthKey, balance);
  }

  void _carryOverFromPreviousMonth(MonthlyBalanceModel currentBalance) {
    final parts = currentBalance.id.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    DateTime previousMonth;
    if (month == 1) {
      previousMonth = DateTime(year - 1, 12);
    } else {
      previousMonth = DateTime(year, month - 1);
    }

    final previousKey = utils.DateUtils.formatMonthKey(previousMonth);
    final previousBalance = _box.get(previousKey);

    if (previousBalance != null && previousBalance.remainingBalance > 0) {
      currentBalance.carryOver = previousBalance.remainingBalance;
      _box.put(currentBalance.id, currentBalance);
    }
  }

  Future<void> recalculateMonthlyExpenses(String monthKey, double totalExpenses) async {
    final balance = _box.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);
    balance.totalExpenses = totalExpenses;
    await _box.put(monthKey, balance);
  }
}
