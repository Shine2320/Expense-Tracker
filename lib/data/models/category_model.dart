import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2)
class CategoryModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String emoji;

  @HiveField(3)
  bool isCustom;

  CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'isCustom': isCustom,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      isCustom: map['isCustom'] as bool? ?? false,
    );
  }

  static List<CategoryModel> defaultCategories() {
    return [
      CategoryModel(id: 'food', name: 'Food & Dining', emoji: '\ud83c\udf54'),
      CategoryModel(id: 'transport', name: 'Transportation', emoji: '\ud83d\ude97'),
      CategoryModel(id: 'shopping', name: 'Shopping', emoji: '\ud83d\uded2'),
      CategoryModel(id: 'entertainment', name: 'Entertainment', emoji: '\ud83c\udfac'),
      CategoryModel(id: 'housing', name: 'Housing', emoji: '\ud83c\udfe0'),
      CategoryModel(id: 'healthcare', name: 'Healthcare', emoji: '\ud83d\udc8a'),
      CategoryModel(id: 'bills', name: 'Bills & Utilities', emoji: '\ud83d\udcf1'),
      CategoryModel(id: 'education', name: 'Education', emoji: '\ud83c\udf93'),
      CategoryModel(id: 'travel', name: 'Travel', emoji: '\u2708\ufe0f'),
      CategoryModel(id: 'other', name: 'Other', emoji: '\ud83d\udce6'),
    ];
  }
}
