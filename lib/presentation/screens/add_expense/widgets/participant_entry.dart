import 'package:flutter/material.dart';

class ParticipantEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;
  double amount;
  bool isSlipPayer;
  bool isPaid;
  int remainderCents;

  ParticipantEntry({
    required this.nameController,
    TextEditingController? amountController,
    this.amount = 0,
    this.isSlipPayer = false,
    this.isPaid = false,
    this.remainderCents = 0,
  }) : amountController = amountController ?? TextEditingController();
}
