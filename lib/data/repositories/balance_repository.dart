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

      // Reconciliation only creates rows for months that have expenses, so a
      // brand-new month gets its row here and needs the chain run to pick up
      // the previous month's remainder.
      rebuildCarryOverChain();
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
    await setCarryOverForMonth(
      utils.DateUtils.formatMonthKey(DateTime.now()),
      carryOver,
    );
  }

  Future<void> setMonthSalary(String monthKey, double salary) async {
    final balance = _box.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);
    balance.salary = salary;
    await _box.put(monthKey, balance);
    rebuildCarryOverChain();
  }

  /// Recomputes every month's [MonthlyBalanceModel.carryOver] from the month
  /// before it, so a correction to an old month (a settled split, a credit card
  /// paid later) propagates forward instead of leaving later months frozen at
  /// the value they happened to be created with.
  ///
  /// Must run *after* `totalExpenses` is up to date, since each month's
  /// remainder feeds the next.
  void rebuildCarryOverChain() {
    // "YYYY-MM" is zero-padded, so lexicographic order is chronological order.
    final balances = _box.values.toList()..sort((a, b) => a.id.compareTo(b.id));

    var previousRemaining = 0.0;
    for (final balance in balances) {
      // The earliest month has no predecessor, so its carry-over is purely its
      // adjustment — i.e. whatever opening balance the user entered.
      balance.carryOver = previousRemaining + balance.carryOverAdjustment;
      _box.put(balance.id, balance);
      // Read after assigning: remainingBalance depends on carryOver.
      previousRemaining = balance.remainingBalance;
    }
  }

  /// Records a user-entered carry-over as an *adjustment* from the calculated
  /// value, so later corrections to earlier months still reach this month.
  Future<void> setCarryOverForMonth(String monthKey, double carryOver) async {
    final balance = _box.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);
    await _box.put(monthKey, balance);
    rebuildCarryOverChain();

    final calculated = balance.carryOver - balance.carryOverAdjustment;
    balance.carryOverAdjustment = carryOver - calculated;
    await _box.put(monthKey, balance);
    rebuildCarryOverChain();
  }

  /// Drops a manual override, returning the month to its calculated carry-over.
  Future<void> clearCarryOverAdjustment(String monthKey) async {
    final balance = _box.get(monthKey);
    if (balance == null) return;
    balance.carryOverAdjustment = 0;
    await _box.put(monthKey, balance);
    rebuildCarryOverChain();
  }

  /// The carry-over this month would have without any manual adjustment.
  double calculatedCarryOverFor(String monthKey) {
    final balance = _box.get(monthKey);
    if (balance == null) return 0;
    return balance.carryOver - balance.carryOverAdjustment;
  }
}
