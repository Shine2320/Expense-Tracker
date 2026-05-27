import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/split_repository.dart';
import '../../data/models/expense_model.dart';
import 'split_provider.dart';
import 'balance_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesProvider = StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
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

  ExpenseNotifier(this._repository, this._splitRepository, this._onBalanceChanged)
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
    final grouped = _repository.getExpensesGroupedByDate(null);
    final deletedGrouped = <String, List<ExpenseModel>>{};
    for (final entry in grouped.entries) {
      final deleted = entry.value.where((e) => e.isDeleted).toList();
      if (deleted.isNotEmpty) {
        deletedGrouped[entry.key] = deleted;
      }
    }
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
    await _repository.updateExpense(expense);
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> deleteExpense(String id) async {
    await _repository.deleteExpense(id);
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> permanentlyDeleteExpense(String id) async {
    await _repository.permanentlyDeleteExpense(id);
    await _splitRepository.deleteSplitByExpenseId(id);
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> markAsPaid(String id) async {
    final expense = _repository.getExpenseById(id);
    if (expense != null && expense.isCreditCard) {
      // Check if this expense has a split with a slip person
      final split = _splitRepository.getSplitByExpenseId(id);
      if (split != null && split.slipPersonId != null) {
        // Calculate net amount: total minus what participants already paid
        final participants = _splitRepository.getParticipantsBySplitId(split.id);
        double collectedFromOthers = 0;
        for (final p in participants) {
          if (!p.isSlipPayer && p.isPaid) {
            collectedFromOthers += p.amount;
          }
        }
        final netAmount = expense.amount - collectedFromOthers;
        // Only add the net amount to monthly totals
        await _repository.markAsPaidWithAmount(id, netAmount);
        loadExpenses();
        _onBalanceChanged();
        return;
      }
    }
    await _repository.markAsPaid(id);
    loadExpenses();
    _onBalanceChanged();
  }

  Future<void> markAsUnpaid(String id) async {
    final expense = _repository.getExpenseById(id);
    if (expense != null && expense.isCreditCard) {
      final split = _splitRepository.getSplitByExpenseId(id);
      if (split != null && split.slipPersonId != null) {
        final participants = _splitRepository.getParticipantsBySplitId(split.id);
        double collectedFromOthers = 0;
        for (final p in participants) {
          if (!p.isSlipPayer && p.isPaid) {
            collectedFromOthers += p.amount;
          }
        }
        final netAmount = expense.amount - collectedFromOthers;
        await _repository.markAsUnpaidWithAmount(id, netAmount);
        loadExpenses();
        _onBalanceChanged();
        return;
      }
    }
    await _repository.markAsUnpaid(id);
    loadExpenses();
    _onBalanceChanged();
  }

  double getTotalForDate(DateTime date) {
    return _repository.getExpensesByDate(date).fold(0, (sum, e) => sum + e.amount);
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

  double getTotalForMonth(DateTime date) {
    return _repository.getTotalForMonth(date);
  }
}
