import 'package:flutter/material.dart';

class ParticipantEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;

  /// Identity of an already-stored participant, so editing the expense doesn't
  /// regenerate it. Empty for a participant added in this session.
  final String id;
  double amount;
  bool isSlipPayer;
  bool isPaid;

  /// When this participant settled up. Carried through the edit round-trip so
  /// the settled-split label keeps its date.
  DateTime? paidAt;
  int remainderCents;

  ParticipantEntry({
    required this.nameController,
    TextEditingController? amountController,
    this.id = '',
    this.amount = 0,
    this.isSlipPayer = false,
    this.isPaid = false,
    this.paidAt,
    this.remainderCents = 0,
  }) : amountController = amountController ?? TextEditingController();
}
