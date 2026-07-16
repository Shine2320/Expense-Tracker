import 'dart:io';

import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/data/datasources/hive_storage.dart';
import 'package:expense_tracker/data/models/category_model.dart';
import 'package:expense_tracker/data/models/expense_model.dart';
import 'package:expense_tracker/data/models/expense_split_model.dart';
import 'package:expense_tracker/data/models/monthly_balance_model.dart';
import 'package:expense_tracker/data/models/split_participant_model.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/split_repository.dart';
import 'package:expense_tracker/presentation/providers/balance_provider.dart';
import 'package:expense_tracker/presentation/providers/split_provider.dart';
import 'package:expense_tracker/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Advances a bounded number of frames.
///
/// Deliberately not `pumpAndSettle()`: the dashboard never reaches a quiescent
/// frame under the test binding, so settling spins until it times out. These
/// assertions are about the numbers, not about animation end-states.
Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

/// Drives the reported bug through the real widget tree. The dashboard is where
/// the user saw a settled split fail to move their remaining balance, so the
/// repository-level test isn't enough on its own — this covers the
/// provider-notify-and-rebuild path too.
void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('expense_tracker_ui_test_');
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
    for (final category in CategoryModel.defaultCategories()) {
      await HiveStorage.categoriesBoxRef.put(category.id, category);
    }
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  /// Seeds "last month I fronted a 120 dinner, splitting it 60/60".
  Future<SplitParticipantModel> seedPreviousMonthSplit(DateTime previous) async {
    await HiveStorage.expensesBoxRef.put(
      'dinner',
      ExpenseModel(
        id: 'dinner',
        name: 'Dinner',
        amount: 120,
        date: previous,
        categoryId: 'other',
        createdAt: previous,
      ),
    );
    final splitRepository = SplitRepository();
    await splitRepository.createSplit(
      expenseId: 'dinner',
      totalAmount: 120,
      participants: [
        SplitParticipantModel(
          id: '',
          splitId: '',
          name: 'Me',
          amount: 60,
          isSlipPayer: true,
        ),
        SplitParticipantModel(id: '', splitId: '', name: 'Friend', amount: 60),
      ],
    );
    await ExpenseRepository().reconcileMonthlyExpenses();
    return HiveStorage.splitParticipantsBoxRef.values
        .firstWhere((p) => p.name == 'Friend');
  }

  testWidgets('dashboard remaining rises when a previous month split settles',
      (tester) async {
    // The dashboard always renders the wall-clock current month, so anchor the
    // fixture to it rather than to fixed dates.
    final now = DateTime.now();
    final currentKey = DateFormat('yyyy-MM').format(now);
    final previous = DateTime(now.year, now.month - 1, 15);

    final balances = HiveStorage.monthlyBalanceBoxRef;
    await tester.runAsync(() async {
      await balances.put(
        DateFormat('yyyy-MM').format(previous),
        MonthlyBalanceModel(
            id: DateFormat('yyyy-MM').format(previous), salary: 1000),
      );
      await balances.put(
        currentKey,
        MonthlyBalanceModel(id: currentKey, salary: 1000),
      );
    });
    final friend = (await tester.runAsync(
      () => seedPreviousMonthSplit(previous),
    ))!;

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // Use the real theme: the app never renders these screens without it.
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DashboardScreen(),
        ),
      ),
    );
    await _advance(tester);

    // Last month: 1000 - 120 = 880 carried in. This month: 1000 + 880 = 1880.
    expect(container.read(balanceProvider).currentMonth.carryOver, 880);
    expect(container.read(balanceProvider).remainingBalance, 1880);
    expect(find.textContaining('1,880'), findsWidgets);

    await tester.runAsync(
      () => container
          .read(splitProvider.notifier)
          .markParticipantAsPaid(friend.id, paidAt: now),
    );
    await _advance(tester);

    // The friend repaid 60, so last month really cost 60 — and that correction
    // must reach this month's dashboard with no restart.
    expect(container.read(balanceProvider).currentMonth.carryOver, 940);
    expect(container.read(balanceProvider).remainingBalance, 1940);
    expect(find.textContaining('1,940'), findsWidgets);
    expect(find.textContaining('1,880'), findsNothing);
  });

  testWidgets('a manual carry-over adjustment still receives the repayment',
      (tester) async {
    final now = DateTime.now();
    final currentKey = DateFormat('yyyy-MM').format(now);
    final previous = DateTime(now.year, now.month - 1, 15);

    final balances = HiveStorage.monthlyBalanceBoxRef;
    await tester.runAsync(() async {
      await balances.put(
        DateFormat('yyyy-MM').format(previous),
        MonthlyBalanceModel(
            id: DateFormat('yyyy-MM').format(previous), salary: 1000),
      );
      await balances.put(
        currentKey,
        MonthlyBalanceModel(id: currentKey, salary: 1000),
      );
    });
    final friend = (await tester.runAsync(
      () => seedPreviousMonthSplit(previous),
    ))!;

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // Use the real theme: the app never renders these screens without it.
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DashboardScreen(),
        ),
      ),
    );
    await _advance(tester);

    // Calculated carry-over is 880; the user overrides it to 900 (+20).
    await tester.runAsync(
      () => container.read(balanceProvider.notifier).updateCarryOver(900),
    );
    await _advance(tester);
    expect(container.read(balanceProvider).currentMonth.carryOver, 900);

    await tester.runAsync(
      () => container
          .read(splitProvider.notifier)
          .markParticipantAsPaid(friend.id, paidAt: now),
    );
    await _advance(tester);

    // 940 calculated + the user's 20 = 960. The override must not swallow the
    // repayment, and the repayment must not discard the override.
    expect(container.read(balanceProvider).currentMonth.carryOver, 960);
    expect(container.read(balanceProvider).currentMonth.carryOverAdjustment, 20);
  });
}
