import 'package:hive/hive.dart';

part 'expense_split_model.g.dart';

@HiveType(typeId: 3)
class ExpenseSplitModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String expenseId;

  @HiveField(2)
  double totalAmount;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String splitMethod;

  @HiveField(5)
  String? slipPersonId;

  ExpenseSplitModel({
    required this.id,
    required this.expenseId,
    required this.totalAmount,
    required this.createdAt,
    this.splitMethod = 'equal',
    this.slipPersonId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseId': expenseId,
      'totalAmount': totalAmount,
      'createdAt': createdAt,
      'splitMethod': splitMethod,
      'slipPersonId': slipPersonId,
    };
  }

  factory ExpenseSplitModel.fromMap(Map<String, dynamic> map) {
    return ExpenseSplitModel(
      id: map['id'] as String,
      expenseId: map['expenseId'] as String,
      totalAmount: map['totalAmount'] as double,
      createdAt: map['createdAt'] as DateTime,
      splitMethod: map['splitMethod'] as String? ?? 'equal',
      slipPersonId: map['slipPersonId'] as String?,
    );
  }
}
