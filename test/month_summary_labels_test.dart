import 'dart:io';

import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/data/datasources/hive_storage.dart';
import 'package:expense_tracker/data/models/category_model.dart';
import 'package:expense_tracker/data/models/expense_model.dart';
import 'package:expense_tracker/data/models/expense_split_model.dart';
import 'package:expense_tracker/data/models/monthly_balance_model.dart';
import 'package:expense_tracker/data/models/split_participant_model.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/screens/month_summary/widgets/monthly_expense_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behavioural cover for the month summary.
///
/// Replaces three tests that grepped these screens' source for substrings.
/// Those broke on renames that changed nothing a user sees, and would have
/// passed on a screen that rendered nothing at all. These assert what is
/// actually on screen instead.
Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('expense_tracker_summary_');
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

  /// Pumps the list that renders the labels, rather than the whole summary
  /// screen: the screen lazily builds its list below the fold and carries a
  /// chart, neither of which these assertions are about.
  Future<void> pumpSummary(WidgetTester tester, DateTime month) async {
    final expenses =
        ExpenseRepository().getAccountingExpensesByMonth(month);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyExpenseList(
                expenses: expenses,
                categories: CategoryModel.defaultCategories(),
              ),
            ),
          ),
        ),
      ),
    );
    await _advance(tester);
  }

  testWidgets('a card paid this month is labelled and dated to its origin',
      (tester) async {
    await tester.runAsync(() async {
      await HiveStorage.monthlyBalanceBoxRef.put(
        '2026-06',
        MonthlyBalanceModel(id: '2026-06', salary: 1000),
      );
      await HiveStorage.expensesBoxRef.put(
        'visa',
        ExpenseModel(
          id: 'visa',
          name: 'Headphones',
          amount: 200,
          date: DateTime(2026, 5, 20),
          categoryId: 'shopping',
          createdAt: DateTime(2026, 5, 20),
          paymentMethod: 'credit_card',
          creditCardName: 'Visa',
          repaymentStatus: 'paid',
          repaymentDate: DateTime(2026, 6, 3),
        ),
      );
      await ExpenseRepository().reconcileMonthlyExpenses();
    });

    await pumpSummary(tester, DateTime(2026, 6, 15));

    // It belongs to June even though it happened in May, and says why.
    expect(find.text('Headphones'), findsOneWidget);
    expect(find.text('Credit paid this month'), findsOneWidget);
    expect(find.textContaining('Original expense:'), findsOneWidget);
  });

  testWidgets('a settled split shows the net amount and explains the change',
      (tester) async {
    await tester.runAsync(() async {
      await HiveStorage.monthlyBalanceBoxRef.put(
        '2026-05',
        MonthlyBalanceModel(id: '2026-05', salary: 1000),
      );
      await HiveStorage.expensesBoxRef.put(
        'dinner',
        ExpenseModel(
          id: 'dinner',
          name: 'Dinner',
          amount: 120,
          date: DateTime(2026, 5, 20),
          categoryId: 'food',
          createdAt: DateTime(2026, 5, 20),
        ),
      );
      await HiveStorage.expenseSplitsBoxRef.put(
        'split-1',
        ExpenseSplitModel(
          id: 'split-1',
          expenseId: 'dinner',
          totalAmount: 120,
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
          amount: 60,
          isSlipPayer: true,
        ),
      );
      await HiveStorage.splitParticipantsBoxRef.put(
        'friend',
        SplitParticipantModel(
          id: 'friend',
          splitId: 'split-1',
          name: 'Friend',
          amount: 60,
          isPaid: true,
          paidAt: DateTime(2026, 6, 2),
        ),
      );
      await ExpenseRepository().reconcileMonthlyExpenses();
    });

    await pumpSummary(tester, DateTime(2026, 5, 15));

    // The row shows what the dinner actually cost the user (60), not the 120
    // they fronted — and says why, because that number changed retroactively.
    expect(find.text('Split settled'), findsOneWidget);
    // Twice: once on the row, once in the day total — which is the point. The
    // day total must agree with the counted amount, not the 120 gross.
    expect(find.text('\$60.00'), findsNWidgets(2));
    expect(
      find.textContaining('You paid \$120.00 - \$60.00 repaid'),
      findsOneWidget,
    );
  });

  testWidgets('an unpaid card expense is not counted against the month',
      (tester) async {
    await tester.runAsync(() async {
      await HiveStorage.monthlyBalanceBoxRef.put(
        '2026-05',
        MonthlyBalanceModel(id: '2026-05', salary: 1000),
      );
      await HiveStorage.expensesBoxRef.put(
        'pending-card',
        ExpenseModel(
          id: 'pending-card',
          name: 'Not yet paid',
          amount: 500,
          date: DateTime(2026, 5, 10),
          categoryId: 'shopping',
          createdAt: DateTime(2026, 5, 10),
          paymentMethod: 'credit_card',
          creditCardName: 'Visa',
          repaymentStatus: 'pending',
        ),
      );
      await ExpenseRepository().reconcileMonthlyExpenses();
    });

    await pumpSummary(tester, DateTime(2026, 5, 15));

    // A pending card expense has no accounting month, so the summary must not
    // show it as spent — the salary hasn't been touched yet.
    expect(find.text('Not yet paid'), findsNothing);
    expect(
      HiveStorage.monthlyBalanceBoxRef.get('2026-05')!.totalExpenses,
      0,
    );
  });
}
