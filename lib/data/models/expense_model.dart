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

  @HiveField(6, defaultValue: 'cash')
  String paymentMethod;

  @HiveField(7)
  String? creditCardName;

  @HiveField(8, defaultValue: 'none')
  String repaymentStatus;

  @HiveField(9)
  DateTime? repaymentDate;

  @HiveField(10, defaultValue: false)
  bool isDeleted;

  ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.createdAt,
    this.paymentMethod = 'cash',
    this.creditCardName,
    this.repaymentStatus = 'none',
    this.repaymentDate,
    this.isDeleted = false,
  });

  bool get isCreditCard => paymentMethod == 'credit_card';
  bool get isPending => repaymentStatus == 'pending';
  bool get isPaid => repaymentStatus == 'paid';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date,
      'categoryId': categoryId,
      'createdAt': createdAt,
      'paymentMethod': paymentMethod,
      'creditCardName': creditCardName,
      'repaymentStatus': repaymentStatus,
      'repaymentDate': repaymentDate,
      'isDeleted': isDeleted,
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
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      creditCardName: map['creditCardName'] as String?,
      repaymentStatus: map['repaymentStatus'] as String? ?? 'none',
      repaymentDate: map['repaymentDate'] as DateTime?,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  ExpenseModel copyWith({
    String? name,
    double? amount,
    DateTime? date,
    String? categoryId,
    String? paymentMethod,
    String? creditCardName,
    String? repaymentStatus,
    DateTime? repaymentDate,
    bool? isDeleted,
  }) {
    return ExpenseModel(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      creditCardName: creditCardName ?? this.creditCardName,
      repaymentStatus: repaymentStatus ?? this.repaymentStatus,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
