import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/split_repository.dart';
import '../../data/models/expense_model.dart';
import 'split_provider.dart';
import 'balance_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesProvider =
    StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  return ExpenseNotifier(
    ref.watch(expenseRepositoryProvider),
    ref.watch(splitRepositoryProvider),
    () => ref.read(balanceProvider.notifier).loadBalance(),
  );
});

class ExpenseState {
  final List<ExpenseModel> expenses;
  final Map<String, List<ExpenseModel>> groupedExpenses;
  final bool isLoading;

  ExpenseState({
    this.expenses = const [],
    this.groupedExpenses = const {},
    this.isLoading = false,
  });

  ExpenseState copyWith({
    List<ExpenseModel>? expenses,
    Map<String, List<ExpenseModel>>? groupedExpenses,
    bool? isLoading,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      groupedExpenses: groupedExpenses ?? this.groupedExpenses,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseRepository _repository;
  final SplitRepository _splitRepository;
  final Function _onBalanceChanged;

  ExpenseNotifier(
      this._repository, this._splitRepository, this._onBalanceChanged)
      : super(ExpenseState()) {
    loadExpenses();
  }

  void loadExpenses() {
    state = state.copyWith(isLoading: true);
    final expenses = _repository.getAllExpenses();
    final grouped = _repository.getExpensesGroupedByDate(null);
    state = state.copyWith(
      expenses: expenses,
      groupedExpenses: grouped,
      isLoading: false,
    );
  }

  void loadDeletedExpenses() {
    state = state.copyWith(isLoading: true);
    final expenses = _repository.getDeletedExpenses();
    final deletedGrouped =
        _repository.getExpensesGroupedByDate(null, deletedOnly: true);
    state = state.copyWith(
      expenses: expenses,
      groupedExpenses: deletedGrouped,
      isLoading: false,
    );
  }

  void loadExpensesForMonth(DateTime month) {
    state = state.copyWith(isLoading: true);
    final expenses = _repository.getExpensesByMonth(month);
    final grouped = _repository.getExpensesGroupedByDate(month);
    state = state.copyWith(
      expenses: expenses,
      groupedExpenses: grouped,
      isLoading: false,
    );
  }

  Future<String> addExpense(ExpenseModel expense) async {
    final result = await _repository.addExpense(expense);
    loadExpenses();
    _onBalanceChanged();
    return result.id;
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    final existing = _repository.getExpenseById(expense.id);
    await _repository.updateExpense(
      expense,
      oldCountedAmount:
          existing == null ? null : _countedMonthlyAmount(existing),
      newCountedAmount: _countedMonthlyAmount(expense),
    );
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> deleteExpense(String id) async {
    final expense = _repository.getExpenseById(id);
    await _repository.deleteExpense(
      id,
      countedAmount: expense == null ? null : _countedMonthlyAmount(expense),
    );
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> permanentlyDeleteExpense(String id) async {
    final expense = _repository.getExpenseById(id);
    await _repository.permanentlyDeleteExpense(
      id,
      countedAmount: expense == null ? null : _countedMonthlyAmount(expense),
    );
    await _splitRepository.deleteSplitByExpenseId(id);
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> markAsPaid(String id, {DateTime? paidAt}) async {
    final expense = _repository.getExpenseById(id);
    if (expense == null ||
        expense.isDeleted ||
        !expense.isCreditCard ||
        expense.isPaid) {
      return;
    }
    await _repository.markAsPaidWithAmount(
      id,
      _repository.getNetSplitAmount(expense),
      paidAt: paidAt,
    );
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> markCardAsPaid(String cardName, {DateTime? paidAt}) async {
    final normalizedCardName = _normalizeCardName(cardName);
    final expenses = _repository.getAllExpenses().where((expense) {
      return expense.isCreditCard &&
          expense.isPending &&
          !expense.isDeleted &&
          _normalizeCardName(expense.creditCardName) == normalizedCardName;
    }).toList();

    if (expenses.isEmpty) {
      return;
    }

    final paymentDate = paidAt ?? DateTime.now();
    for (final expense in expenses) {
      await _repository.markAsPaidWithAmount(
        expense.id,
        _repository.getNetSplitAmount(expense),
        paidAt: paymentDate,
      );
    }
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> markAsUnpaid(String id) async {
    final expense = _repository.getExpenseById(id);
    if (expense == null ||
        expense.isDeleted ||
        !expense.isCreditCard ||
        !expense.isPaid) {
      return;
    }
    await _repository.markAsUnpaidWithAmount(
      id,
      _countedMonthlyAmount(expense),
    );
    loadExpenses();
    _onBalanceChanged();
  }

  double _countedMonthlyAmount(ExpenseModel expense) {
    return _repository.getCountedAmount(expense);
  }

  String _normalizeCardName(String? cardName) {
    final trimmed = cardName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'unknown card';
    }
    return trimmed.toLowerCase();
  }

  double getTotalForDate(DateTime date) {
    return _repository
        .getExpensesByDate(date)
        .fold(0, (sum, e) => sum + e.amount);
  }

  List<ExpenseModel> getAllExpenses({bool includeDeleted = false}) {
    return _repository.getAllExpenses(includeDeleted: includeDeleted);
  }

  List<ExpenseModel> getExpensesByDate(
    DateTime date, {
    bool includeDeleted = false,
  }) {
    return _repository.getExpensesByDate(
      date,
      includeDeleted: includeDeleted,
    );
  }

  List<ExpenseModel> getExpensesByMonth(
    DateTime month, {
    bool includeDeleted = false,
  }) {
    return _repository.getExpensesByMonth(
      month,
      includeDeleted: includeDeleted,
    );
  }

  Map<String, List<ExpenseModel>> getExpensesGroupedByDate(
    DateTime? month, {
    bool includeDeleted = false,
    bool deletedOnly = false,
  }) {
    return _repository.getExpensesGroupedByDate(
      month,
      includeDeleted: includeDeleted,
      deletedOnly: deletedOnly,
    );
  }

  Map<DateTime, List<ExpenseModel>> getDaysWithExpenses(
    DateTime month, {
    bool includeDeleted = false,
  }) {
    return _repository.getDaysWithExpenses(
      month,
      includeDeleted: includeDeleted,
    );
  }

  double getTotalForMonth(DateTime date) {
    return _repository.getTotalForMonth(date);
  }

  List<ExpenseModel> getAccountingExpensesByMonth(DateTime month) {
    return _repository.getAccountingExpensesByMonth(month);
  }

  DateTime? getAccountingDate(ExpenseModel expense) {
    return _repository.getAccountingDate(expense);
  }

  double getCountedAmount(ExpenseModel expense) {
    return _repository.getCountedAmount(expense);
  }

  double getNetSplitAmount(ExpenseModel expense) {
    return _repository.getNetSplitAmount(expense);
  }
}
