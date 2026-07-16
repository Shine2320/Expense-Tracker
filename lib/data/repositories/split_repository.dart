import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../datasources/hive_storage.dart';
import '../models/expense_split_model.dart';
import '../models/split_participant_model.dart';

class SplitRepository {
  static const _uuid = Uuid();

  Box<ExpenseSplitModel> get _splitBox => HiveStorage.expenseSplitsBoxRef;
  Box<SplitParticipantModel> get _participantBox =>
      HiveStorage.splitParticipantsBoxRef;

  List<ExpenseSplitModel> getAllSplits() {
    return _splitBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  ExpenseSplitModel? getSplitByExpenseId(String expenseId) {
    try {
      return _splitBox.values.firstWhere((s) => s.expenseId == expenseId);
    } catch (_) {
      return null;
    }
  }

  /// Every split's participants, grouped in a single pass.
  ///
  /// [getParticipantsBySplitId] filters the whole box per call, which is O(n·p)
  /// when a list needs it for every row. Build this once instead.
  Map<String, List<SplitParticipantModel>> participantsBySplitId() {
    final grouped = <String, List<SplitParticipantModel>>{};
    for (final participant in _participantBox.values) {
      (grouped[participant.splitId] ??= []).add(participant);
    }
    return grouped;
  }

  List<SplitParticipantModel> getParticipantsBySplitId(String splitId) {
    return _participantBox.values.where((p) => p.splitId == splitId).toList()
      ..sort((a, b) {
        if (a.isSlipPayer && !b.isSlipPayer) return -1;
        if (!a.isSlipPayer && b.isSlipPayer) return 1;
        return a.name.compareTo(b.name);
      });
  }

  SplitParticipantModel? getParticipantById(String participantId) {
    return _participantBox.get(participantId);
  }

  ExpenseSplitModel? getSplitById(String splitId) {
    return _splitBox.get(splitId);
  }

  List<SplitParticipantModel> getPendingPayments() {
    return _participantBox.values
        .where((p) => !p.isPaid && !p.isSlipPayer)
        .toList();
  }

  Future<ExpenseSplitModel> createSplit({
    required String expenseId,
    required double totalAmount,
    required List<SplitParticipantModel> participants,
    String splitMethod = 'equal',
  }) async {
    final split = ExpenseSplitModel(
      id: _uuid.v4(),
      expenseId: expenseId,
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
      splitMethod: splitMethod,
      slipPersonId: null, // will be set below
    );
    await _splitBox.put(split.id, split);

    String? actualSlipPersonId;
    for (final participant in participants) {
      final p = SplitParticipantModel(
        id: participant.id.isNotEmpty ? participant.id : _uuid.v4(),
        splitId: split.id,
        name: participant.name,
        amount: participant.amount,
        isSlipPayer: participant.isSlipPayer,
        isPaid: participant.isPaid,
        paidAt: participant.paidAt,
      );
      await _participantBox.put(p.id, p);
      if (participant.isSlipPayer) {
        actualSlipPersonId = p.id;
      }
    }

    // Update split with actual slip person participant ID
    if (actualSlipPersonId != null) {
      split.slipPersonId = actualSlipPersonId;
      await split.save();
    }

    return split;
  }

  Future<void> markParticipantAsPaid(
    String participantId, {
    DateTime? paidAt,
  }) async {
    final participant = _participantBox.get(participantId);
    if (participant == null) return;

    participant.isPaid = true;
    participant.paidAt = paidAt ?? DateTime.now();
    await participant.save();
  }

  Future<void> unmarkParticipantAsPaid(String participantId) async {
    final participant = _participantBox.get(participantId);
    if (participant == null) return;

    participant.isPaid = false;
    participant.paidAt = null;
    await participant.save();
  }

  Future<void> deleteSplit(String splitId) async {
    final participants = getParticipantsBySplitId(splitId);
    for (final p in participants) {
      await _participantBox.delete(p.id);
    }
    await _splitBox.delete(splitId);
  }

  Future<void> deleteSplitByExpenseId(String expenseId) async {
    final split = getSplitByExpenseId(expenseId);
    if (split == null) return;
    await deleteSplit(split.id);
  }

  // ── Slip person helpers ──
  double getSlipPersonNetOutstanding(String slipPersonId) {
    final allParticipants = _participantBox.values
        .where((p) => p.isSlipPayer && p.id == slipPersonId)
        .toList();
    if (allParticipants.isEmpty) return 0;

    double totalFronted = 0;
    double totalCollected = 0;

    for (final slipParticipant in allParticipants) {
      totalFronted += slipParticipant.amount;
      final split = _splitBox.get(slipParticipant.splitId);
      if (split == null) continue;

      final others = _participantBox.values
          .where((p) => p.splitId == slipParticipant.splitId && !p.isSlipPayer);
      for (final other in others) {
        if (other.isPaid) totalCollected += other.amount;
      }
    }
    return totalFronted - totalCollected;
  }

  List<SplitParticipantModel> getAllPendingForSlipPerson(String slipPersonId) {
    final result = <SplitParticipantModel>[];
    final allSplits =
        _splitBox.values.where((s) => s.slipPersonId == slipPersonId);
    for (final split in allSplits) {
      final participants = _participantBox.values
          .where((p) => p.splitId == split.id && !p.isSlipPayer && !p.isPaid);
      result.addAll(participants);
    }
    return result;
  }
}
