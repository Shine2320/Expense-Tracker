import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 0)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String categoryId;

  @HiveField(5)
  DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date,
      'categoryId': categoryId,
      'createdAt': createdAt,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: map['amount'] as double,
      date: map['date'] as DateTime,
      categoryId: map['categoryId'] as String,
      createdAt: map['createdAt'] as DateTime,
    );
  }

  ExpenseModel copyWith({
    String? name,
    double? amount,
    DateTime? date,
    String? categoryId,
  }) {
    return ExpenseModel(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt,
    );
  }
}
