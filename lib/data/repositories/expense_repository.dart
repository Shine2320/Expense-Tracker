import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../datasources/hive_storage.dart';
import '../models/expense_model.dart';
import '../models/monthly_balance_model.dart';
import '../../core/utils/date_utils.dart' as utils;

class ExpenseRepository {
  static const _uuid = Uuid();

  Box<ExpenseModel> get _box => HiveStorage.expensesBoxRef;
  Box<MonthlyBalanceModel> get _balanceBox => HiveStorage.monthlyBalanceBoxRef;

  List<ExpenseModel> getAllExpenses({bool includeDeleted = false}) {
    final expenses =
        _box.values.where((e) => includeDeleted || !e.isDeleted).toList();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  ExpenseModel? getExpenseById(String id) {
    return _box.get(id);
  }

  List<ExpenseModel> getExpensesByDate(
    DateTime date, {
    bool includeDeleted = false,
  }) {
    return _box.values
        .where((e) =>
            utils.DateUtils.isSameDay(e.date, date) &&
            (includeDeleted || !e.isDeleted))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ExpenseModel> getExpensesByMonth(
    DateTime date, {
    bool includeDeleted = false,
  }) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    return _box.values
        .where((e) =>
            utils.DateUtils.formatMonthKey(e.date) == monthKey &&
            (includeDeleted || !e.isDeleted))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Map<String, List<ExpenseModel>> getExpensesGroupedByDate(
    DateTime? month, {
    bool includeDeleted = false,
    bool deletedOnly = false,
  }) {
    final expenses = deletedOnly
        ? getDeletedExpenses()
        : month != null
            ? getExpensesByMonth(month, includeDeleted: includeDeleted)
            : getAllExpenses(includeDeleted: includeDeleted);
    final grouped = <String, List<ExpenseModel>>{};

    for (final expense in expenses) {
      if (month != null &&
          utils.DateUtils.formatMonthKey(expense.date) !=
              utils.DateUtils.formatMonthKey(month)) {
        continue;
      }
      final dateKey = utils.DateUtils.formatDate(expense.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(expense);
    }

    return grouped;
  }

  Future<ExpenseModel> addExpense(ExpenseModel expense) async {
    final newExpense = ExpenseModel(
      id: _uuid.v4(),
      name: expense.name,
      amount: expense.amount,
      date: expense.date,
      categoryId: expense.categoryId,
      createdAt: DateTime.now(),
      paymentMethod: expense.paymentMethod,
      creditCardName: expense.creditCardName,
      repaymentStatus: expense.repaymentStatus,
      repaymentDate: expense.repaymentDate,
      isDeleted: expense.isDeleted,
    );
    await _box.put(newExpense.id, newExpense);
    if (!newExpense.isCreditCard) {
      _updateMonthlyExpenses(newExpense.date, newExpense.amount);
    }
    return newExpense;
  }

  Future<void> updateExpense(
    ExpenseModel expense, {
    double? oldCountedAmount,
    double? newCountedAmount,
  }) async {
    final existing = _box.get(expense.id);
    if (existing == null) return;

    final amountToRemove = oldCountedAmount ??
        (_isCountedInMonthlyExpenses(existing) ? existing.amount : 0.0);
    final amountToAdd = newCountedAmount ??
        (_isCountedInMonthlyExpenses(expense) ? expense.amount : 0.0);

    if (amountToRemove != 0) {
      _updateMonthlyExpenses(existing.date, -amountToRemove);
    }
    await _box.put(expense.id, expense);
    if (amountToAdd != 0) {
      _updateMonthlyExpenses(expense.date, amountToAdd);
    }
  }

  Future<void> deleteExpense(String id, {double? countedAmount}) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final amountToRemove = countedAmount ??
        (_isCountedInMonthlyExpenses(expense) ? expense.amount : 0.0);
    expense.isDeleted = true;
    await expense.save();
    if (amountToRemove != 0) {
      _updateMonthlyExpenses(expense.date, -amountToRemove);
    }
  }

  Future<void> permanentlyDeleteExpense(String id,
      {double? countedAmount}) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final amountToRemove = countedAmount ??
        (_isCountedInMonthlyExpenses(expense) ? expense.amount : 0.0);
    await _box.delete(id);
    if (amountToRemove != 0) {
      _updateMonthlyExpenses(expense.date, -amountToRemove);
    }
  }

  Future<void> markAsPaid(String id) async {
    final expense = _box.get(id);
    if (expense == null) return;

    expense.repaymentStatus = 'paid';
    expense.repaymentDate = DateTime.now();
    await expense.save();
    _updateMonthlyExpenses(expense.date, expense.amount);
  }

  Future<void> markAsPaidWithAmount(String id, double netAmount) async {
    final expense = _box.get(id);
    if (expense == null) return;

    expense.repaymentStatus = 'paid';
    expense.repaymentDate = DateTime.now();
    await expense.save();
    _updateMonthlyExpenses(expense.date, netAmount);
  }

  Future<void> markAsUnpaid(String id) async {
    final expense = _box.get(id);
    if (expense == null) return;

    expense.repaymentStatus = 'pending';
    expense.repaymentDate = null;
    await expense.save();
    _updateMonthlyExpenses(expense.date, -expense.amount);
  }

  Future<void> markAsUnpaidWithAmount(String id, double netAmount) async {
    final expense = _box.get(id);
    if (expense == null) return;

    expense.repaymentStatus = 'pending';
    expense.repaymentDate = null;
    await expense.save();
    _updateMonthlyExpenses(expense.date, -netAmount);
  }

  List<ExpenseModel> getActiveExpenses() {
    return _box.values.where((e) => !e.isDeleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<ExpenseModel> getDeletedExpenses() {
    return _box.values.where((e) => e.isDeleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _updateMonthlyExpenses(DateTime date, double amountChange) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    final balance =
        _balanceBox.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);

    balance.totalExpenses =
        (balance.totalExpenses + amountChange).clamp(0, double.infinity);
    _balanceBox.put(monthKey, balance);
  }

  void adjustMonthlyExpenses(DateTime date, double amountChange) {
    _updateMonthlyExpenses(date, amountChange);
  }

  bool _isCountedInMonthlyExpenses(ExpenseModel expense) {
    return !expense.isDeleted && (!expense.isCreditCard || expense.isPaid);
  }

  double getTotalForMonth(DateTime date) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    final balance = _balanceBox.get(monthKey);
    return balance?.totalExpenses ?? 0.0;
  }

  Map<DateTime, List<ExpenseModel>> getDaysWithExpenses(
    DateTime month, {
    bool includeDeleted = false,
  }) {
    final expenses = getExpensesByMonth(month, includeDeleted: includeDeleted);
    final days = <DateTime, List<ExpenseModel>>{};

    for (final expense in expenses) {
      final day =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (!days.containsKey(day)) {
        days[day] = [];
      }
      days[day]!.add(expense);
    }

    return days;
  }
}
