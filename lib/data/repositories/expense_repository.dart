import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../datasources/hive_storage.dart';
import '../models/expense_model.dart';
import '../models/expense_split_model.dart';
import '../models/monthly_balance_model.dart';
import '../models/split_participant_model.dart';
import '../../core/utils/date_utils.dart' as utils;

class ExpenseRepository {
  static const _uuid = Uuid();

  Box<ExpenseModel> get _box => HiveStorage.expensesBoxRef;
  Box<MonthlyBalanceModel> get _balanceBox => HiveStorage.monthlyBalanceBoxRef;
  Box<ExpenseSplitModel> get _splitBox => HiveStorage.expenseSplitsBoxRef;
  Box<SplitParticipantModel> get _participantBox =>
      HiveStorage.splitParticipantsBoxRef;

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

  List<ExpenseModel> getAccountingExpensesByMonth(DateTime date) {
    final monthKey = utils.DateUtils.formatMonthKey(date);
    final expenses = _box.values.where((expense) {
      final accountingDate = getAccountingDate(expense);
      return accountingDate != null &&
          utils.DateUtils.formatMonthKey(accountingDate) == monthKey;
    }).toList();

    expenses.sort((a, b) {
      final aDate = getAccountingDate(a) ?? a.date;
      final bDate = getAccountingDate(b) ?? b.date;
      return bDate.compareTo(aDate);
    });
    return expenses;
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
    final accountingDate = getAccountingDate(newExpense);
    if (accountingDate != null) {
      _updateMonthlyExpenses(accountingDate, newExpense.amount);
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

    final amountToRemove = oldCountedAmount ?? getCountedAmount(existing);
    final amountToAdd = newCountedAmount ?? getCountedAmount(expense);

    if (amountToRemove != 0) {
      final oldAccountingDate = getAccountingDate(existing);
      if (oldAccountingDate != null) {
        _updateMonthlyExpenses(oldAccountingDate, -amountToRemove);
      }
    }
    await _box.put(expense.id, expense);
    if (amountToAdd != 0) {
      final newAccountingDate = getAccountingDate(expense);
      if (newAccountingDate != null) {
        _updateMonthlyExpenses(newAccountingDate, amountToAdd);
      }
    }
  }

  Future<void> deleteExpense(String id, {double? countedAmount}) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final amountToRemove = countedAmount ?? getCountedAmount(expense);
    final accountingDate = getAccountingDate(expense);
    expense.isDeleted = true;
    await expense.save();
    if (amountToRemove != 0 && accountingDate != null) {
      _updateMonthlyExpenses(accountingDate, -amountToRemove);
    }
  }

  Future<void> permanentlyDeleteExpense(String id,
      {double? countedAmount}) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final amountToRemove = countedAmount ?? getCountedAmount(expense);
    final accountingDate = getAccountingDate(expense);
    await _box.delete(id);
    if (amountToRemove != 0 && accountingDate != null) {
      _updateMonthlyExpenses(accountingDate, -amountToRemove);
    }
  }

  Future<void> markAsPaid(String id, {DateTime? paidAt}) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final paymentDate = paidAt ?? DateTime.now();
    expense.repaymentStatus = 'paid';
    expense.repaymentDate = paymentDate;
    await expense.save();
    _updateMonthlyExpenses(paymentDate, expense.amount);
  }

  Future<void> markAsPaidWithAmount(
    String id,
    double netAmount, {
    DateTime? paidAt,
  }) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final paymentDate = paidAt ?? DateTime.now();
    expense.repaymentStatus = 'paid';
    expense.repaymentDate = paymentDate;
    await expense.save();
    _updateMonthlyExpenses(paymentDate, netAmount);
  }

  Future<void> markAsUnpaid(String id) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final accountingDate = getAccountingDate(expense);
    expense.repaymentStatus = 'pending';
    expense.repaymentDate = null;
    await expense.save();
    if (accountingDate != null) {
      _updateMonthlyExpenses(accountingDate, -expense.amount);
    }
  }

  Future<void> markAsUnpaidWithAmount(String id, double netAmount) async {
    final expense = _box.get(id);
    if (expense == null) return;

    final accountingDate = getAccountingDate(expense);
    expense.repaymentStatus = 'pending';
    expense.repaymentDate = null;
    await expense.save();
    if (accountingDate != null) {
      _updateMonthlyExpenses(accountingDate, -netAmount);
    }
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

  double getCountedAmount(ExpenseModel expense) {
    if (getAccountingDate(expense) == null) return 0;
    return getNetSplitAmount(expense);
  }

  DateTime? getAccountingDate(ExpenseModel expense) {
    if (expense.isDeleted) return null;
    if (!expense.isCreditCard) return expense.date;
    if (!expense.isPaid) return null;
    return expense.repaymentDate ?? expense.date;
  }

  Future<void> reconcileMonthlyExpenses() async {
    final totalsByMonth = <String, double>{};

    for (final expense in _box.values) {
      final accountingDate = getAccountingDate(expense);
      if (accountingDate == null) continue;

      final monthKey = utils.DateUtils.formatMonthKey(accountingDate);
      totalsByMonth[monthKey] =
          (totalsByMonth[monthKey] ?? 0) + getNetSplitAmount(expense);
    }

    for (final balance in _balanceBox.values) {
      balance.totalExpenses = totalsByMonth.remove(balance.id) ?? 0;
      await balance.save();
    }

    for (final entry in totalsByMonth.entries) {
      final balance =
          _balanceBox.get(entry.key) ?? MonthlyBalanceModel(id: entry.key);
      balance.totalExpenses = entry.value;
      await _balanceBox.put(entry.key, balance);
    }
  }

  double getNetSplitAmount(ExpenseModel expense) {
    ExpenseSplitModel? split;
    try {
      split = _splitBox.values.firstWhere((s) => s.expenseId == expense.id);
    } catch (_) {
      split = null;
    }

    if (split == null || split.slipPersonId == null) {
      return expense.amount;
    }

    final splitModel = split;
    final collectedFromOthers = _participantBox.values.fold<double>(0, (
      sum,
      participant,
    ) {
      if (participant.splitId == splitModel.id &&
          !participant.isSlipPayer &&
          participant.isPaid) {
        return sum + participant.amount;
      }
      return sum;
    });

    return (expense.amount - collectedFromOthers)
        .clamp(0, double.infinity)
        .toDouble();
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
