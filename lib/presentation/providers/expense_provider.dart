import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/models/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesProvider = StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  return ExpenseNotifier(ref.watch(expenseRepositoryProvider));
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

  ExpenseNotifier(this._repository) : super(ExpenseState()) {
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

  Future<void> addExpense(ExpenseModel expense) async {
    await _repository.addExpense(expense);
    loadExpenses();
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _repository.updateExpense(expense);
    loadExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await _repository.deleteExpense(id);
    loadExpenses();
  }

  List<ExpenseModel> getExpensesByDate(DateTime date) {
    return _repository.getExpensesByDate(date);
  }

  List<ExpenseModel> getExpensesByMonth(DateTime month) {
    return _repository.getExpensesByMonth(month);
  }

  Map<DateTime, List<ExpenseModel>> getDaysWithExpenses(DateTime month) {
    return _repository.getDaysWithExpenses(month);
  }

  double getTotalForDate(DateTime date) {
    return _repository.getExpensesByDate(date).fold(0, (sum, e) => sum + e.amount);
  }

  double getTotalForMonth(DateTime date) {
    return _repository.getTotalForMonth(date);
  }
}
