import 'package:hive/hive.dart';

part 'monthly_balance_model.g.dart';

@HiveType(typeId: 1)
class MonthlyBalanceModel extends HiveObject {
  @HiveField(0)
  String id; // Format: "YYYY-MM"

  @HiveField(1)
  double salary;

  @HiveField(2)
  double carryOver;

  @HiveField(3)
  double totalExpenses;

  /// User's manual correction to [carryOver], stored as the difference from the
  /// calculated value. The chain rebuilds `carryOver = previousRemaining +
  /// carryOverAdjustment`, so later corrections to earlier months still reach
  /// this month instead of being frozen out by the override.
  @HiveField(4, defaultValue: 0.0)
  double carryOverAdjustment;

  MonthlyBalanceModel({
    required this.id,
    this.salary = 0.0,
    this.carryOver = 0.0,
    this.totalExpenses = 0.0,
    this.carryOverAdjustment = 0.0,
  });

  double get availableBalance => salary + carryOver;

  double get remainingBalance => availableBalance - totalExpenses;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'salary': salary,
      'carryOver': carryOver,
      'totalExpenses': totalExpenses,
      'carryOverAdjustment': carryOverAdjustment,
    };
  }

  factory MonthlyBalanceModel.fromMap(Map<String, dynamic> map) {
    return MonthlyBalanceModel(
      id: map['id'] as String,
      salary: map['salary'] as double? ?? 0.0,
      carryOver: map['carryOver'] as double? ?? 0.0,
      totalExpenses: map['totalExpenses'] as double? ?? 0.0,
      carryOverAdjustment: map['carryOverAdjustment'] as double? ?? 0.0,
    );
  }

  MonthlyBalanceModel copyWith({
    double? salary,
    double? carryOver,
    double? totalExpenses,
    double? carryOverAdjustment,
  }) {
    return MonthlyBalanceModel(
      id: id,
      salary: salary ?? this.salary,
      carryOver: carryOver ?? this.carryOver,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      carryOverAdjustment: carryOverAdjustment ?? this.carryOverAdjustment,
    );
  }
}
