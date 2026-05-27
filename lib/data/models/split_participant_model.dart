import 'package:hive/hive.dart';

part 'split_participant_model.g.dart';

@HiveType(typeId: 4)
class SplitParticipantModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String splitId;

  @HiveField(2)
  String name;

  @HiveField(3)
  double amount;

  @HiveField(4)
  bool isPaid;

  @HiveField(5)
  DateTime? paidAt;

  @HiveField(6, defaultValue: false)
  bool isSlipPayer;

  SplitParticipantModel({
    required this.id,
    required this.splitId,
    required this.name,
    required this.amount,
    this.isPaid = false,
    this.paidAt,
    this.isSlipPayer = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'splitId': splitId,
      'name': name,
      'amount': amount,
      'isPaid': isPaid,
      'paidAt': paidAt,
      'isSlipPayer': isSlipPayer,
    };
  }

  factory SplitParticipantModel.fromMap(Map<String, dynamic> map) {
    return SplitParticipantModel(
      id: map['id'] as String,
      splitId: map['splitId'] as String,
      name: map['name'] as String,
      amount: map['amount'] as double,
      isPaid: map['isPaid'] as bool? ?? false,
      paidAt: map['paidAt'] as DateTime?,
      isSlipPayer: map['isSlipPayer'] as bool? ?? false,
    );
  }
}
