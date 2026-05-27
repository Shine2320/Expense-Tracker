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

  List<ExpenseModel> getAllExpenses() {
    final expenses = _box.values.toList();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  ExpenseModel? getExpenseById(String id) {
    return _box.get(id);
  }

  List<ExpenseModel> getExpensesByDate(DateTime date) {
    return _box.values.where((e) => utils.DateUtils.isSameDay(e.date, date)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ExpenseModel> getExpensesByMonth(DateTime date) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    return _box.values
        .where((e) => utils.DateUtils.formatMonthKey(e.date) == monthKey)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Map<String, List<ExpenseModel>> getExpensesGroupedByDate(DateTime? month) {
    final expenses = month != null ? getExpensesByMonth(month) : getAllExpenses();
    final grouped = <String, List<ExpenseModel>>{};

    for (final expense in expenses) {
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

  Future<void> updateExpense(ExpenseModel expense) {
    final existing = _box.get(expense.id);
    if (existing == null) return Future.value();

    final oldWasCounted = !existing.isCreditCard && !existing.isDeleted;
    final newIsCounted = !expense.isCreditCard && !expense.isDeleted;

    if (oldWasCounted) {
      _updateMonthlyExpenses(existing.date, -existing.amount);
    }
    _box.put(expense.id, expense);
    if (newIsCounted) {
      _updateMonthlyExpenses(expense.date, expense.amount);
    }
    return Future.value();
  }

  Future<void> deleteExpense(String id) async {
    final expense = _box.get(id);
    if (expense == null) return;

    expense.isDeleted = true;
    await expense.save();
    if (!expense.isCreditCard || expense.isPaid) {
      _updateMonthlyExpenses(expense.date, -expense.amount);
    }
  }

  Future<void> permanentlyDeleteExpense(String id) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final wasPaidCredit = expense.isCreditCard && expense.isPaid;
    _box.delete(id);
    if (!expense.isCreditCard || wasPaidCredit) {
      _updateMonthlyExpenses(expense.date, -expense.amount);
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
    final balance = _balanceBox.get(monthKey) ?? MonthlyBalanceModel(id: monthKey);

    balance.totalExpenses = (balance.totalExpenses + amountChange).clamp(0, double.infinity);
    _balanceBox.put(monthKey, balance);
  }

  void adjustMonthlyExpenses(DateTime date, double amountChange) {
    _updateMonthlyExpenses(date, amountChange);
  }

  double getTotalForMonth(DateTime date) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    final balance = _balanceBox.get(monthKey);
    return balance?.totalExpenses ?? 0.0;
  }

  Map<DateTime, List<ExpenseModel>> getDaysWithExpenses(DateTime month) {
    final expenses = getExpensesByMonth(month);
    final days = <DateTime, List<ExpenseModel>>{};

    for (final expense in expenses) {
      final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (!days.containsKey(day)) {
        days[day] = [];
      }
      days[day]!.add(expense);
    }

    return days;
  }
}
