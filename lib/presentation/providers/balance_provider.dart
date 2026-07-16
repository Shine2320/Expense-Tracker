import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/balance_repository.dart';
import '../../data/models/monthly_balance_model.dart';
import '../../core/utils/date_utils.dart' as utils;

final balanceRepositoryProvider = Provider<BalanceRepository>((ref) {
  return BalanceRepository();
});

final balanceProvider = StateNotifierProvider<BalanceNotifier, BalanceState>((ref) {
  return BalanceNotifier(ref.watch(balanceRepositoryProvider));
});

class BalanceState {
  final MonthlyBalanceModel currentMonth;
  final List<MonthlyBalanceModel> allMonths;
  final bool isLoading;

  BalanceState({
    MonthlyBalanceModel? currentMonth,
    this.allMonths = const [],
    this.isLoading = false,
  }) : currentMonth = currentMonth ?? MonthlyBalanceModel(id: utils.DateUtils.formatMonthKey(DateTime.now()));

  double get availableBalance => currentMonth.availableBalance;
  double get remainingBalance => currentMonth.remainingBalance;
  double get totalExpenses => currentMonth.totalExpenses;

  BalanceState copyWith({
    MonthlyBalanceModel? currentMonth,
    List<MonthlyBalanceModel>? allMonths,
    bool? isLoading,
  }) {
    return BalanceState(
      currentMonth: currentMonth ?? this.currentMonth,
      allMonths: allMonths ?? this.allMonths,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BalanceNotifier extends StateNotifier<BalanceState> {
  final BalanceRepository _repository;

  BalanceNotifier(this._repository) : super(BalanceState()) {
    loadBalance();
  }

  void loadBalance() {
    state = state.copyWith(isLoading: true);
    final current = _repository.getCurrentMonthBalance();
    final allMonths = _repository.getAllMonthBalances();
    state = state.copyWith(
      currentMonth: current,
      allMonths: allMonths,
      isLoading: false,
    );
  }

  Future<void> updateSalary(double salary) async {
    await _repository.updateSalary(salary);
    loadBalance();
  }

  Future<void> updateCarryOver(double carryOver) async {
    await _repository.updateCarryOver(carryOver);
    loadBalance();
  }

  /// Drops the manual override so this month follows the calculated chain again.
  Future<void> clearCarryOverAdjustment() async {
    await _repository.clearCarryOverAdjustment(
      utils.DateUtils.formatMonthKey(DateTime.now()),
    );
    loadBalance();
  }

  /// What the carry-over would be with no manual adjustment.
  double calculatedCarryOver() {
    return _repository.calculatedCarryOverFor(
      utils.DateUtils.formatMonthKey(DateTime.now()),
    );
  }

  Future<void> setMonthSalary(String monthKey, double salary) async {
    await _repository.setMonthSalary(monthKey, salary);
    loadBalance();
  }

  MonthlyBalanceModel getMonthBalance(DateTime date) {
    return _repository.getMonthBalance(date);
  }
}
