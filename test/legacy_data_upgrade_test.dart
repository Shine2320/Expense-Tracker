import 'dart:io';

import 'package:expense_tracker/data/datasources/hive_storage.dart';
import 'package:expense_tracker/data/models/category_model.dart';
import 'package:expense_tracker/data/models/expense_model.dart';
import 'package:expense_tracker/data/models/expense_split_model.dart';
import 'package:expense_tracker/data/models/monthly_balance_model.dart';
import 'package:expense_tracker/data/models/split_participant_model.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/services/balance_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Upgrade safety net.
///
/// The riskiest thing about the carry-over chain is that it runs against real,
/// existing installs on first launch and rewrites stored history. These tests
/// stand in for "the user already has months of data and installs the new
/// build": nothing may be lost, and the numbers must end up right.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('expense_tracker_legacy_');
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

  /// Reproduces what the old build left on disk: `carryOver` written as a
  /// frozen snapshot, and no `carryOverAdjustment` (it decodes to 0.0 via the
  /// adapter's defaultValue, which is what a record written before the field
  /// existed does).
  Future<void> seedLegacyInstall() async {
    final balances = HiveStorage.monthlyBalanceBoxRef;
    final expenses = HiveStorage.expensesBoxRef;

    // The user's oldest month, carrying an opening balance they typed in.
    await balances.put(
      '2026-04',
      MonthlyBalanceModel(
        id: '2026-04',
        salary: 50000,
        carryOver: 8000,
        totalExpenses: 20000,
      ),
    );
    // Later months: carryOver frozen at whatever it was when first opened.
    await balances.put(
      '2026-05',
      MonthlyBalanceModel(
        id: '2026-05',
        salary: 50000,
        carryOver: 38000,
        totalExpenses: 30000,
      ),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(
        id: '2026-06',
        salary: 50000,
        carryOver: 58000,
        totalExpenses: 10000,
      ),
    );

    await expenses.put(
      'apr-rent',
      ExpenseModel(
        id: 'apr-rent',
        name: 'Rent',
        amount: 20000,
        date: DateTime(2026, 4, 3),
        categoryId: 'housing',
        createdAt: DateTime(2026, 4, 3),
      ),
    );
    await expenses.put(
      'may-food',
      ExpenseModel(
        id: 'may-food',
        name: 'Groceries',
        amount: 30000,
        date: DateTime(2026, 5, 8),
        categoryId: 'food',
        createdAt: DateTime(2026, 5, 8),
      ),
    );
    await expenses.put(
      'jun-fuel',
      ExpenseModel(
        id: 'jun-fuel',
        name: 'Fuel',
        amount: 10000,
        date: DateTime(2026, 6, 2),
        categoryId: 'transport',
        createdAt: DateTime(2026, 6, 2),
      ),
    );
  }

  test('records written before carryOverAdjustment existed read back as 0',
      () async {
    final balances = HiveStorage.monthlyBalanceBoxRef;
    await balances.put(
      '2026-04',
      MonthlyBalanceModel(id: '2026-04', salary: 100, carryOver: 25),
    );

    // Round-trip through the adapter, the way a reinstall would.
    await balances.close();
    final reopened =
        await Hive.openBox<MonthlyBalanceModel>(HiveStorage.monthlyBalanceBox);

    final stored = reopened.get('2026-04')!;
    expect(stored.carryOverAdjustment, 0.0);
    expect(stored.salary, 100);
    expect(stored.carryOver, 25);
  });

  test('upgrading an existing install keeps the opening balance', () async {
    await seedLegacyInstall();

    await BalanceMigration.runIfNeeded();
    await ExpenseRepository().reconcileMonthlyExpenses();

    final balances = HiveStorage.monthlyBalanceBoxRef;

    // April is the earliest month: its 8000 opening balance is the user's, and
    // has nothing to derive from. It must survive, now expressed as an
    // adjustment so the chain reproduces it.
    expect(balances.get('2026-04')!.carryOverAdjustment, 8000);
    expect(balances.get('2026-04')!.carryOver, 8000);
    expect(balances.get('2026-04')!.remainingBalance, 38000);

    // Salaries and expenses are untouched — only the derived fields move.
    expect(balances.get('2026-05')!.salary, 50000);
    expect(balances.get('2026-06')!.salary, 50000);
    expect(balances.get('2026-04')!.totalExpenses, 20000);
    expect(balances.get('2026-05')!.totalExpenses, 30000);
    expect(balances.get('2026-06')!.totalExpenses, 10000);

    // The chain reproduces exactly what the old frozen snapshots held, because
    // this data was internally consistent to begin with.
    expect(balances.get('2026-05')!.carryOver, 38000);
    expect(balances.get('2026-06')!.carryOver, 58000);
    expect(balances.get('2026-06')!.remainingBalance, 98000);
  });

  test('upgrading repairs months whose stored carry-over had gone stale',
      () async {
    await seedLegacyInstall();
    // Simulate the reported bug's residue: June's stored carry-over is wrong
    // because a May correction never propagated. The old app would show this
    // number forever.
    final balances = HiveStorage.monthlyBalanceBoxRef;
    final june = balances.get('2026-06')!;
    june.carryOver = 12345;
    await june.save();

    await BalanceMigration.runIfNeeded();
    await ExpenseRepository().reconcileMonthlyExpenses();

    // Recomputed from May, not trusted.
    expect(balances.get('2026-06')!.carryOver, 58000);
  });

  test('the migration runs once and is not repeated on later launches',
      () async {
    await seedLegacyInstall();

    final first = await BalanceMigration.runIfNeeded();
    expect(first.migrated, isTrue);
    await ExpenseRepository().reconcileMonthlyExpenses();

    final second = await BalanceMigration.runIfNeeded();
    expect(second.migrated, isFalse);

    // Re-seeding would double-count the opening balance into the adjustment.
    expect(
      HiveStorage.monthlyBalanceBoxRef.get('2026-04')!.carryOverAdjustment,
      8000,
    );
  });

  test('a fresh install migrates silently and shows no notice', () async {
    final result = await BalanceMigration.runIfNeeded();

    expect(result.migrated, isFalse);
    expect(result.backupPath, isNull);
  });

  test('a failed backup still seeds, rather than losing the opening balance',
      () async {
    await seedLegacyInstall();

    // exportToJson needs a platform channel, which is absent here — so this
    // exercises the real failure path rather than a simulated one.
    final result = await BalanceMigration.runIfNeeded();

    expect(result.migrated, isTrue);
    expect(result.backupError, isNotNull);
    // The seed is what protects the data, so it must not be skipped.
    expect(
      HiveStorage.monthlyBalanceBoxRef.get('2026-04')!.carryOverAdjustment,
      8000,
    );
  });

  test('no money is lost across the upgrade', () async {
    await seedLegacyInstall();

    await BalanceMigration.runIfNeeded();
    await ExpenseRepository().reconcileMonthlyExpenses();

    final balances = HiveStorage.monthlyBalanceBoxRef;
    // Opening balance + every salary - every expense == the final remainder.
    const expectedFinal = 8000 + (50000 * 3) - (20000 + 30000 + 10000);
    expect(balances.get('2026-06')!.remainingBalance, expectedFinal);
  });

  test('an existing split that was already settled stays settled', () async {
    await seedLegacyInstall();

    final expenses = HiveStorage.expensesBoxRef;
    await expenses.put(
      'may-dinner',
      ExpenseModel(
        id: 'may-dinner',
        name: 'Dinner',
        amount: 2000,
        date: DateTime(2026, 5, 20),
        categoryId: 'food',
        createdAt: DateTime(2026, 5, 20),
      ),
    );
    await HiveStorage.expenseSplitsBoxRef.put(
      'split-1',
      ExpenseSplitModel(
        id: 'split-1',
        expenseId: 'may-dinner',
        totalAmount: 2000,
        createdAt: DateTime(2026, 5, 20),
        slipPersonId: 'me',
      ),
    );
    await HiveStorage.splitParticipantsBoxRef.put(
      'me',
      SplitParticipantModel(
        id: 'me',
        splitId: 'split-1',
        name: 'Me',
        amount: 1000,
        isSlipPayer: true,
      ),
    );
    await HiveStorage.splitParticipantsBoxRef.put(
      'friend',
      SplitParticipantModel(
        id: 'friend',
        splitId: 'split-1',
        name: 'Friend',
        amount: 1000,
        isPaid: true,
        paidAt: DateTime(2026, 6, 4),
      ),
    );

    await BalanceMigration.runIfNeeded();
    await ExpenseRepository().reconcileMonthlyExpenses();

    final balances = HiveStorage.monthlyBalanceBoxRef;
    // May's groceries plus only the user's own half of the dinner.
    expect(balances.get('2026-05')!.totalExpenses, 31000);
    // ...and the correction reaches June, which the old build never did.
    expect(balances.get('2026-05')!.remainingBalance, 57000);
    expect(balances.get('2026-06')!.carryOver, 57000);
  });

  test('an existing paid card expense with no repayment date is healed',
      () async {
    await seedLegacyInstall();

    await HiveStorage.expensesBoxRef.put(
      'legacy-card',
      ExpenseModel(
        id: 'legacy-card',
        name: 'Old card expense',
        amount: 5000,
        date: DateTime(2026, 5, 12),
        categoryId: 'shopping',
        createdAt: DateTime(2026, 5, 12),
        paymentMethod: 'credit_card',
        creditCardName: 'Visa',
        repaymentStatus: 'paid',
        // Written by a build that predates repaymentDate.
        repaymentDate: null,
      ),
    );

    await BalanceMigration.runIfNeeded();
    await ExpenseRepository().reconcileMonthlyExpenses();

    // The fallback is persisted rather than re-guessed on every read, and the
    // amount stays in its original month rather than vanishing.
    expect(
      HiveStorage.expensesBoxRef.get('legacy-card')!.repaymentDate,
      DateTime(2026, 5, 12),
    );
    expect(HiveStorage.monthlyBalanceBoxRef.get('2026-05')!.totalExpenses, 35000);
  });
}
