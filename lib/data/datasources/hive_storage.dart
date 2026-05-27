import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';
import '../models/monthly_balance_model.dart';
import '../models/expense_split_model.dart';
import '../models/split_participant_model.dart';

class HiveStorage {
  static const String expensesBox = 'expenses';
  static const String categoriesBox = 'categories';
  static const String monthlyBalanceBox = 'monthly_balance';
  static const String expenseSplitsBox = 'expense_splits';
  static const String splitParticipantsBox = 'split_participants';

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(ExpenseModelAdapter());
    Hive.registerAdapter(MonthlyBalanceModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(ExpenseSplitModelAdapter());
    Hive.registerAdapter(SplitParticipantModelAdapter());

    await Hive.openBox<ExpenseModel>(expensesBox);
    await Hive.openBox<CategoryModel>(categoriesBox);
    await Hive.openBox<MonthlyBalanceModel>(monthlyBalanceBox);
    await Hive.openBox<ExpenseSplitModel>(expenseSplitsBox);
    await Hive.openBox<SplitParticipantModel>(splitParticipantsBox);

    await _initializeDefaultCategories();
  }

  static Future<void> _initializeDefaultCategories() async {
    final box = Hive.box<CategoryModel>(categoriesBox);
    if (box.isEmpty) {
      final defaults = CategoryModel.defaultCategories();
      for (final category in defaults) {
        await box.put(category.id, category);
      }
    }
  }

  static Box<ExpenseModel> get expensesBoxRef => Hive.box<ExpenseModel>(expensesBox);

  static Box<CategoryModel> get categoriesBoxRef => Hive.box<CategoryModel>(categoriesBox);

  static Box<MonthlyBalanceModel> get monthlyBalanceBoxRef => Hive.box<MonthlyBalanceModel>(monthlyBalanceBox);

  static Box<ExpenseSplitModel> get expenseSplitsBoxRef => Hive.box<ExpenseSplitModel>(expenseSplitsBox);

  static Box<SplitParticipantModel> get splitParticipantsBoxRef => Hive.box<SplitParticipantModel>(splitParticipantsBox);

  static Future<void> close() async {
    await Hive.close();
  }
}
