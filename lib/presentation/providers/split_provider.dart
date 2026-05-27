import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/split_repository.dart';
import '../../data/models/expense_split_model.dart';
import '../../data/models/split_participant_model.dart';

final splitRepositoryProvider = Provider<SplitRepository>((ref) {
  return SplitRepository();
});

final splitProvider = StateNotifierProvider<SplitNotifier, SplitState>((ref) {
  return SplitNotifier(ref.watch(splitRepositoryProvider));
});

class SplitState {
  final List<ExpenseSplitModel> splits;
  final List<SplitParticipantModel> pendingPayments;
  final bool isLoading;

  SplitState({
    this.splits = const [],
    this.pendingPayments = const [],
    this.isLoading = false,
  });

  SplitState copyWith({
    List<ExpenseSplitModel>? splits,
    List<SplitParticipantModel>? pendingPayments,
    bool? isLoading,
  }) {
    return SplitState(
      splits: splits ?? this.splits,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SplitNotifier extends StateNotifier<SplitState> {
  final SplitRepository _repository;

  SplitNotifier(this._repository) : super(SplitState()) {
    loadSplits();
  }

  void loadSplits() {
    state = state.copyWith(isLoading: true);
    final splits = _repository.getAllSplits();
    final pending = _repository.getPendingPayments();
    state = state.copyWith(
      splits: splits,
      pendingPayments: pending,
      isLoading: false,
    );
  }

  Future<void> createSplit({
    required String expenseId,
    required double totalAmount,
    required List<SplitParticipantModel> participants,
    String splitMethod = 'equal',
  }) async {
    await _repository.createSplit(
      expenseId: expenseId,
      totalAmount: totalAmount,
      participants: participants,
      splitMethod: splitMethod,
    );
    loadSplits();
  }

  Future<void> markParticipantAsPaid(String participantId) async {
    await _repository.markParticipantAsPaid(participantId);
    loadSplits();
  }

  Future<void> unmarkParticipantAsPaid(String participantId) async {
    await _repository.unmarkParticipantAsPaid(participantId);
    loadSplits();
  }

  Future<void> deleteSplitByExpenseId(String expenseId) async {
    await _repository.deleteSplitByExpenseId(expenseId);
    loadSplits();
  }

  List<SplitParticipantModel> getParticipantsBySplitId(String splitId) {
    return _repository.getParticipantsBySplitId(splitId);
  }

  ExpenseSplitModel? getSplitByExpenseId(String expenseId) {
    return _repository.getSplitByExpenseId(expenseId);
  }

  SplitParticipantModel? getParticipantById(String participantId) {
    return _repository.getParticipantById(participantId);
  }

  ExpenseSplitModel? getSplitById(String splitId) {
    return _repository.getSplitById(splitId);
  }

  // ── Slip person helpers ──
  double getSlipPersonNetOutstanding(String slipPersonId) {
    return _repository.getSlipPersonNetOutstanding(slipPersonId);
  }

  List<SplitParticipantModel> getAllPendingForSlipPerson(String slipPersonId) {
    return _repository.getAllPendingForSlipPerson(slipPersonId);
  }
}