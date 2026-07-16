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
  static const List<Duration> _openRetryDelays = [
    Duration.zero,
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
    Duration(milliseconds: 1600),
  ];

  static Future<void> init() async {
    await Hive.initFlutter();

    _registerAdapters();

    await _openBoxesWithRetry();

    await _initializeDefaultCategories();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExpenseModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MonthlyBalanceModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ExpenseSplitModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(SplitParticipantModelAdapter());
    }
  }

  static Future<void> _openBoxesWithRetry() async {
    for (var attempt = 0; attempt < _openRetryDelays.length; attempt++) {
      final delay = _openRetryDelays[attempt];
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      try {
        await _openBox<ExpenseModel>(expensesBox);
        await _openBox<CategoryModel>(categoriesBox);
        await _openBox<MonthlyBalanceModel>(monthlyBalanceBox);
        await _openBox<ExpenseSplitModel>(expenseSplitsBox);
        await _openBox<SplitParticipantModel>(splitParticipantsBox);
        return;
      } catch (error) {
        await _closeOpenBoxesQuietly();
        final isFinalAttempt = attempt == _openRetryDelays.length - 1;
        if (!_isLockError(error) || isFinalAttempt) {
          rethrow;
        }
      }
    }
  }

  static Future<Box<T>> _openBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  static bool _isLockError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('lock failed') ||
        (message.contains('.lock') && message.contains('errno = 11'));
  }

  static Future<void> _closeOpenBoxesQuietly() async {
    for (final name in [
      expensesBox,
      categoriesBox,
      monthlyBalanceBox,
      expenseSplitsBox,
      splitParticipantsBox,
    ]) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        await Hive.box(name).close();
      } catch (_) {
        // Best-effort cleanup before retrying a temporary file-lock failure.
      }
    }
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

  static Box<ExpenseModel> get expensesBoxRef =>
      Hive.box<ExpenseModel>(expensesBox);

  static Box<CategoryModel> get categoriesBoxRef =>
      Hive.box<CategoryModel>(categoriesBox);

  static Box<MonthlyBalanceModel> get monthlyBalanceBoxRef =>
      Hive.box<MonthlyBalanceModel>(monthlyBalanceBox);

  static Box<ExpenseSplitModel> get expenseSplitsBoxRef =>
      Hive.box<ExpenseSplitModel>(expenseSplitsBox);

  static Box<SplitParticipantModel> get splitParticipantsBoxRef =>
      Hive.box<SplitParticipantModel>(splitParticipantsBox);

  static Future<void> close() async {
    await Hive.close();
  }
}
