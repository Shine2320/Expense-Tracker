import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/data/datasources/hive_storage.dart';
import 'package:expense_tracker/data/models/category_model.dart';
import 'package:expense_tracker/data/models/expense_model.dart';
import 'package:expense_tracker/data/models/expense_split_model.dart';
import 'package:expense_tracker/data/models/monthly_balance_model.dart';
import 'package:expense_tracker/data/models/split_participant_model.dart';
import 'package:expense_tracker/data/services/data_export_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Import must be all-or-nothing.
///
/// Committing a section prunes whatever keys the payload omits, and several
/// models cast required fields with no default — so a payload that parses far
/// enough to prune one box and then throws used to destroy data while the
/// caller reported "import failed". The user sees a failure message, the stale
/// in-memory list still shows their expenses, and the loss only surfaces on the
/// next launch. These tests pin the ordering that prevents that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_tracker_import_');
    Hive.init(tempDir.path);
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
    await Hive.openBox<ExpenseModel>(HiveStorage.expensesBox);
    await Hive.openBox<CategoryModel>(HiveStorage.categoriesBox);
    await Hive.openBox<MonthlyBalanceModel>(HiveStorage.monthlyBalanceBox);
    await Hive.openBox<ExpenseSplitModel>(HiveStorage.expenseSplitsBox);
    await Hive.openBox<SplitParticipantModel>(HiveStorage.splitParticipantsBox);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> seedOneExpense() async {
    await HiveStorage.expensesBoxRef.put(
      'e1',
      ExpenseModel(
        id: 'e1',
        name: 'Groceries',
        amount: 1200,
        categoryId: 'food',
        date: DateTime(2026, 5, 4),
        createdAt: DateTime(2026, 5, 4),
      ),
    );
  }

  /// Writes [payload] to a temp file and imports it, returning the thrown error.
  Future<Object?> importPayload(Map<String, dynamic> payload) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}import.json');
    await file.writeAsString(jsonEncode(payload));
    try {
      await ExportImportData.importFromJson(file.path);
      return null;
    } catch (e) {
      return e;
    }
  }

  test('a payload that throws after the expense section leaves expenses intact',
      () async {
    await seedOneExpense();

    // `categories` is missing the non-nullable `name`/`emoji`, so CategoryModel
    // .fromMap throws. `expenses` is an empty list, which on its own would
    // legitimately prune the box — the point is that the throw must prevent the
    // prune from ever being committed.
    final error = await importPayload({
      'expenses': <dynamic>[],
      'categories': [
        {'id': 'food'},
      ],
    });

    expect(error, isNotNull, reason: 'the malformed category must still throw');
    expect(
      HiveStorage.expensesBoxRef.get('e1'),
      isNotNull,
      reason: 'a failed import must not delete the expenses it never replaced',
    );
  });

  test('a valid payload still replaces and prunes', () async {
    await seedOneExpense();

    final error = await importPayload({
      'expenses': [
        {
          'id': 'e2',
          'name': 'Rent',
          'amount': 18000,
          'categoryId': 'home',
          'date': DateTime(2026, 6, 1).toIso8601String(),
          'createdAt': DateTime(2026, 6, 1).toIso8601String(),
        },
      ],
      'categories': [
        {'id': 'home', 'name': 'Home', 'emoji': '🏠'},
      ],
    });

    expect(error, isNull);
    expect(HiveStorage.expensesBoxRef.get('e2')?.name, 'Rent');
    expect(
      HiveStorage.expensesBoxRef.get('e1'),
      isNull,
      reason: 'a row the payload omits is still pruned on a successful import',
    );
    expect(HiveStorage.categoriesBoxRef.get('home')?.name, 'Home');
  });

  test('a section the payload omits leaves that box untouched', () async {
    await seedOneExpense();

    final error = await importPayload({
      'categories': [
        {'id': 'home', 'name': 'Home', 'emoji': '🏠'},
      ],
    });

    expect(error, isNull);
    expect(
      HiveStorage.expensesBoxRef.get('e1'),
      isNotNull,
      reason: 'an absent section is not an empty one',
    );
  });
}
