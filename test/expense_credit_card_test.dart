import 'dart:io';

import 'package:expense_tracker/data/datasources/hive_storage.dart';
import 'package:expense_tracker/data/models/category_model.dart';
import 'package:expense_tracker/data/models/expense_model.dart';
import 'package:expense_tracker/data/models/expense_split_model.dart';
import 'package:expense_tracker/data/models/monthly_balance_model.dart';
import 'package:expense_tracker/data/models/split_participant_model.dart';
import 'package:expense_tracker/data/repositories/balance_repository.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/split_repository.dart';
import 'package:expense_tracker/presentation/providers/expense_provider.dart';
import 'package:expense_tracker/presentation/providers/split_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_tracker_test_');
    Hive.init(tempDir.path);
    _registerAdapters();
    await _openBoxes();
    await _seedCategories();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('month summary does not call month-scoped provider loader', () {
    final source = File(
      'lib/presentation/screens/month_summary/month_summary_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('loadExpensesForMonth')));
  });

  test('month summary display uses counted split amounts', () {
    final summarySource = File(
      'lib/presentation/screens/month_summary/month_summary_screen.dart',
    ).readAsStringSync();
    final listSource = File(
      'lib/presentation/screens/month_summary/widgets/monthly_expense_list.dart',
    ).readAsStringSync();

    expect(summarySource, contains('getCountedAmount(expense)'));
    expect(summarySource, isNot(contains('+ expense.amount')));
    expect(listSource, contains('getCountedAmount(e)'));
    expect(listSource, contains('amountOverride'));
  });

  test('month summary labels credit payments from previous months', () {
    final listSource = File(
      'lib/presentation/screens/month_summary/widgets/monthly_expense_list.dart',
    ).readAsStringSync();

    expect(listSource, contains('Credit paid this month'));
    expect(listSource, contains('Original expense:'));
    expect(listSource, contains('formatDisplayDate(expense.date)'));
  });

  test('bulk card payment marks only pending expenses for that card', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;
    final alreadyPaidAt = DateTime(2026, 5, 20);
    final paidAt = DateTime(2026, 6, 2, 10, 30);

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(id: '2026-05', totalExpenses: 25),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(id: '2026-06', totalExpenses: 10),
    );
    await expenses.put(
      'visa-pending-1',
      _expense(
        id: 'visa-pending-1',
        name: 'Groceries',
        amount: 100,
        date: DateTime(2026, 5, 1),
        cardName: 'Visa',
      ),
    );
    await expenses.put(
      'visa-pending-2',
      _expense(
        id: 'visa-pending-2',
        name: 'Fuel',
        amount: 50,
        date: DateTime(2026, 5, 2),
        cardName: ' visa ',
      ),
    );
    await expenses.put(
      'visa-paid',
      _expense(
        id: 'visa-paid',
        name: 'Already paid',
        amount: 25,
        date: DateTime(2026, 5, 3),
        cardName: 'Visa',
        repaymentStatus: 'paid',
        repaymentDate: alreadyPaidAt,
      ),
    );
    await expenses.put(
      'master-pending',
      _expense(
        id: 'master-pending',
        name: 'Other card',
        amount: 75,
        date: DateTime(2026, 5, 4),
        cardName: 'Mastercard',
      ),
    );

    var balanceRefreshes = 0;
    final notifier = ExpenseNotifier(
      ExpenseRepository(),
      SplitRepository(),
      () => balanceRefreshes++,
    );

    await notifier.markCardAsPaid('VISA', paidAt: paidAt);

    expect(expenses.get('visa-pending-1')!.isPaid, isTrue);
    expect(expenses.get('visa-pending-2')!.isPaid, isTrue);
    expect(expenses.get('visa-pending-1')!.repaymentDate, paidAt);
    expect(expenses.get('visa-pending-2')!.repaymentDate, paidAt);
    expect(expenses.get('master-pending')!.isPending, isTrue);
    expect(expenses.get('visa-paid')!.repaymentDate, alreadyPaidAt);
    expect(balances.get('2026-05')!.totalExpenses, 25);
    expect(balances.get('2026-06')!.totalExpenses, 160);
    expect(balanceRefreshes, 1);
    expect(notifier.state.expenses, hasLength(4));
  });

  test('single card payment counts in repayment month', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;
    final paidAt = DateTime(2026, 6, 5, 9);

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(id: '2026-05', totalExpenses: 0),
    );
    await expenses.put(
      'visa-pending',
      _expense(
        id: 'visa-pending',
        name: 'Groceries',
        amount: 100,
        date: DateTime(2026, 5, 30),
      ),
    );

    final notifier = ExpenseNotifier(
      ExpenseRepository(),
      SplitRepository(),
      () {},
    );

    await notifier.markAsPaid('visa-pending', paidAt: paidAt);

    expect(expenses.get('visa-pending')!.repaymentDate, paidAt);
    expect(balances.get('2026-05')!.totalExpenses, 0);
    expect(balances.get('2026-06')!.totalExpenses, 100);
  });

  test('undo card payment removes amount from repayment month', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-06',
      MonthlyBalanceModel(id: '2026-06', totalExpenses: 120),
    );
    await expenses.put(
      'visa-paid',
      _expense(
        id: 'visa-paid',
        name: 'Fuel',
        amount: 120,
        date: DateTime(2026, 5, 25),
        repaymentStatus: 'paid',
        repaymentDate: DateTime(2026, 6, 3),
      ),
    );

    final notifier = ExpenseNotifier(
      ExpenseRepository(),
      SplitRepository(),
      () {},
    );

    await notifier.markAsUnpaid('visa-paid');

    expect(expenses.get('visa-paid')!.isPending, isTrue);
    expect(expenses.get('visa-paid')!.repaymentDate, isNull);
    expect(balances.get('2026-06')!.totalExpenses, 0);
  });

  test('reconcile moves existing paid card expenses to repayment month',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(
        id: '2026-05',
        salary: 1000,
        // Earliest month: its carry-over is an opening balance, expressed as an
        // adjustment. Migration seeds this from legacy stored carryOver values.
        carryOverAdjustment: 50,
        totalExpenses: 999,
      ),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(
        id: '2026-06',
        salary: 2000,
        carryOver: 75,
        totalExpenses: 1,
      ),
    );
    await expenses.put(
      'cash-may',
      ExpenseModel(
        id: 'cash-may',
        name: 'Cash',
        amount: 40,
        date: DateTime(2026, 5, 1),
        categoryId: 'other',
        createdAt: DateTime(2026, 5, 1),
      ),
    );
    await expenses.put(
      'visa-paid-june',
      _expense(
        id: 'visa-paid-june',
        name: 'Paid in June',
        amount: 100,
        date: DateTime(2026, 5, 28),
        repaymentStatus: 'paid',
        repaymentDate: DateTime(2026, 6, 1),
      ),
    );
    await expenses.put(
      'visa-paid-missing-date',
      _expense(
        id: 'visa-paid-missing-date',
        name: 'Old paid',
        amount: 25,
        date: DateTime(2026, 5, 10),
        repaymentStatus: 'paid',
      ),
    );
    await expenses.put(
      'visa-pending',
      _expense(
        id: 'visa-pending',
        name: 'Pending',
        amount: 60,
        date: DateTime(2026, 5, 15),
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();

    expect(balances.get('2026-05')!.salary, 1000);
    expect(balances.get('2026-05')!.carryOver, 50);
    expect(balances.get('2026-05')!.totalExpenses, 65);
    expect(balances.get('2026-06')!.salary, 2000);
    // Chained from May: 1000 + 50 - 65 = 985.
    expect(balances.get('2026-06')!.carryOver, 985);
    expect(balances.get('2026-06')!.totalExpenses, 100);
  });

  test('accounting month query includes paid cards by repayment date',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final repository = ExpenseRepository();

    await expenses.put(
      'cash-june',
      ExpenseModel(
        id: 'cash-june',
        name: 'Cash',
        amount: 40,
        date: DateTime(2026, 6, 2),
        categoryId: 'other',
        createdAt: DateTime(2026, 6, 2),
      ),
    );
    await expenses.put(
      'visa-paid-june',
      _expense(
        id: 'visa-paid-june',
        name: 'Paid in June',
        amount: 100,
        date: DateTime(2026, 5, 28),
        repaymentStatus: 'paid',
        repaymentDate: DateTime(2026, 6, 1),
      ),
    );
    await expenses.put(
      'visa-pending-june',
      _expense(
        id: 'visa-pending-june',
        name: 'Pending',
        amount: 60,
        date: DateTime(2026, 6, 3),
      ),
    );
    await expenses.put(
      'visa-paid-may',
      _expense(
        id: 'visa-paid-may',
        name: 'Paid in May',
        amount: 30,
        date: DateTime(2026, 5, 15),
        repaymentStatus: 'paid',
        repaymentDate: DateTime(2026, 5, 20),
      ),
    );

    final juneExpenseIds = repository
        .getAccountingExpensesByMonth(DateTime(2026, 6))
        .map((expense) => expense.id)
        .toList();
    final mayExpenseIds = repository
        .getAccountingExpensesByMonth(DateTime(2026, 5))
        .map((expense) => expense.id)
        .toList();

    expect(juneExpenseIds, containsAll(['cash-june', 'visa-paid-june']));
    expect(juneExpenseIds, isNot(contains('visa-pending-june')));
    expect(juneExpenseIds, isNot(contains('visa-paid-may')));
    expect(mayExpenseIds, contains('visa-paid-may'));
    expect(mayExpenseIds, isNot(contains('visa-paid-june')));
  });

  test('striking out previous month expense updates previous month balance',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(id: '2026-05', totalExpenses: 150),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(id: '2026-06', totalExpenses: 40),
    );
    await expenses.put(
      'cash-may',
      _cashExpense(
        id: 'cash-may',
        name: 'May cash',
        amount: 150,
        date: DateTime(2026, 5, 28),
      ),
    );
    await expenses.put(
      'cash-june',
      _cashExpense(
        id: 'cash-june',
        name: 'June cash',
        amount: 40,
        date: DateTime(2026, 6, 2),
      ),
    );

    final notifier = ExpenseNotifier(
      ExpenseRepository(),
      SplitRepository(),
      () {},
    );

    await notifier.deleteExpense('cash-may');

    expect(expenses.get('cash-may')!.isDeleted, isTrue);
    expect(balances.get('2026-05')!.totalExpenses, 0);
    expect(balances.get('2026-06')!.totalExpenses, 40);
  });

  test('reconcile excludes existing struck out expense from original month',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(
        id: '2026-05',
        salary: 1000,
        // Earliest month: its carry-over is an opening balance, expressed as an
        // adjustment. Migration seeds this from legacy stored carryOver values.
        carryOverAdjustment: 50,
        totalExpenses: 999,
      ),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(
        id: '2026-06',
        salary: 2000,
        carryOver: 75,
        totalExpenses: 1,
      ),
    );
    await expenses.put(
      'deleted-may',
      _cashExpense(
        id: 'deleted-may',
        name: 'Deleted May',
        amount: 150,
        date: DateTime(2026, 5, 28),
      ).copyWith(isDeleted: true),
    );
    await expenses.put(
      'cash-may',
      _cashExpense(
        id: 'cash-may',
        name: 'May cash',
        amount: 30,
        date: DateTime(2026, 5, 29),
      ),
    );
    await expenses.put(
      'cash-june',
      _cashExpense(
        id: 'cash-june',
        name: 'June cash',
        amount: 40,
        date: DateTime(2026, 6, 2),
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();

    expect(balances.get('2026-05')!.salary, 1000);
    expect(balances.get('2026-05')!.carryOver, 50);
    expect(balances.get('2026-05')!.totalExpenses, 30);
    expect(balances.get('2026-06')!.salary, 2000);
    // Chained from May: 1000 + 50 - 30 = 1020.
    expect(balances.get('2026-06')!.carryOver, 1020);
    expect(balances.get('2026-06')!.totalExpenses, 40);
  });

  test('split paid in later month reduces original expense month only',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(id: '2026-05', totalExpenses: 999),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(id: '2026-06', totalExpenses: 1),
    );
    await expenses.put(
      'cash-split-may',
      _cashExpense(
        id: 'cash-split-may',
        name: 'May dinner',
        amount: 120,
        date: DateTime(2026, 5, 30),
      ),
    );
    await expenses.put(
      'cash-june',
      _cashExpense(
        id: 'cash-june',
        name: 'June cash',
        amount: 25,
        date: DateTime(2026, 6, 2),
      ),
    );

    final notifier = SplitNotifier(
      SplitRepository(),
      ExpenseRepository(),
      () {},
    );

    await notifier.createSplit(
      expenseId: 'cash-split-may',
      totalAmount: 120,
      participants: [
        SplitParticipantModel(
          id: 'payer',
          splitId: '',
          name: 'Me',
          amount: 60,
          isSlipPayer: true,
        ),
        SplitParticipantModel(
          id: 'friend',
          splitId: '',
          name: 'Friend',
          amount: 60,
        ),
      ],
    );

    await notifier.markParticipantAsPaid(
      'friend',
      paidAt: DateTime(2026, 6, 2),
    );

    expect(balances.get('2026-05')!.totalExpenses, 60);
    expect(balances.get('2026-06')!.totalExpenses, 25);
    expect(HiveStorage.splitParticipantsBoxRef.get('friend')!.paidAt,
        DateTime(2026, 6, 2));
  });

  test('undo split payment restores original expense month', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await expenses.put(
      'cash-split-may',
      _cashExpense(
        id: 'cash-split-may',
        name: 'May dinner',
        amount: 120,
        date: DateTime(2026, 5, 30),
      ),
    );
    await expenses.put(
      'cash-june',
      _cashExpense(
        id: 'cash-june',
        name: 'June cash',
        amount: 25,
        date: DateTime(2026, 6, 2),
      ),
    );

    final notifier = SplitNotifier(
      SplitRepository(),
      ExpenseRepository(),
      () {},
    );

    await notifier.createSplit(
      expenseId: 'cash-split-may',
      totalAmount: 120,
      participants: [
        SplitParticipantModel(
          id: 'payer',
          splitId: '',
          name: 'Me',
          amount: 60,
          isSlipPayer: true,
        ),
        SplitParticipantModel(
          id: 'friend',
          splitId: '',
          name: 'Friend',
          amount: 60,
        ),
      ],
    );
    await notifier.markParticipantAsPaid(
      'friend',
      paidAt: DateTime(2026, 6, 2),
    );
    await notifier.unmarkParticipantAsPaid('friend');

    expect(balances.get('2026-05')!.totalExpenses, 120);
    expect(balances.get('2026-06')!.totalExpenses, 25);
    expect(HiveStorage.splitParticipantsBoxRef.get('friend')!.paidAt, isNull);
  });

  test('reconcile includes existing paid split data from later month',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final splits = HiveStorage.expenseSplitsBoxRef;
    final participants = HiveStorage.splitParticipantsBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(
        id: '2026-05',
        salary: 1000,
        // Earliest month: its carry-over is an opening balance, expressed as an
        // adjustment. Migration seeds this from legacy stored carryOver values.
        carryOverAdjustment: 50,
        totalExpenses: 999,
      ),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(
        id: '2026-06',
        salary: 2000,
        carryOver: 75,
        totalExpenses: 1,
      ),
    );
    await expenses.put(
      'cash-split-may',
      _cashExpense(
        id: 'cash-split-may',
        name: 'May dinner',
        amount: 120,
        date: DateTime(2026, 5, 30),
      ),
    );
    await expenses.put(
      'cash-june',
      _cashExpense(
        id: 'cash-june',
        name: 'June cash',
        amount: 25,
        date: DateTime(2026, 6, 2),
      ),
    );
    await splits.put(
      'split-may',
      ExpenseSplitModel(
        id: 'split-may',
        expenseId: 'cash-split-may',
        totalAmount: 120,
        createdAt: DateTime(2026, 5, 30),
        slipPersonId: 'payer',
      ),
    );
    await participants.put(
      'payer',
      SplitParticipantModel(
        id: 'payer',
        splitId: 'split-may',
        name: 'Me',
        amount: 60,
        isSlipPayer: true,
      ),
    );
    await participants.put(
      'friend',
      SplitParticipantModel(
        id: 'friend',
        splitId: 'split-may',
        name: 'Friend',
        amount: 60,
        isPaid: true,
        paidAt: DateTime(2026, 6, 2),
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();

    expect(balances.get('2026-05')!.salary, 1000);
    expect(balances.get('2026-05')!.carryOver, 50);
    expect(balances.get('2026-05')!.totalExpenses, 60);
    expect(balances.get('2026-06')!.salary, 2000);
    // Chained from May: 1000 + 50 - 60 = 990. Before the carry-over chain this
    // stayed frozen at whatever was stored when June was first opened, so
    // settling the May split never reached June.
    expect(balances.get('2026-06')!.carryOver, 990);
    expect(balances.get('2026-06')!.totalExpenses, 25);
  });

  test('settling a previous month split raises this month remaining', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(id: '2026-05', salary: 1000),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(id: '2026-06', salary: 1000),
    );
    await expenses.put(
      'may-dinner',
      _cashExpense(
        id: 'may-dinner',
        name: 'May dinner',
        amount: 120,
        date: DateTime(2026, 5, 30),
      ),
    );

    final splitRepository = SplitRepository();
    await splitRepository.createSplit(
      expenseId: 'may-dinner',
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

    // Before settlement: the full 120 sits in May, June carries May's remainder.
    expect(balances.get('2026-05')!.totalExpenses, 120);
    expect(balances.get('2026-05')!.remainingBalance, 880);
    expect(balances.get('2026-06')!.carryOver, 880);
    expect(balances.get('2026-06')!.remainingBalance, 1880);

    final friend = HiveStorage.splitParticipantsBoxRef.values
        .firstWhere((p) => p.name == 'Friend');
    await splitRepository.markParticipantAsPaid(
      friend.id,
      paidAt: DateTime(2026, 6, 2),
    );
    await ExpenseRepository().reconcileMonthlyExpenses();

    // Retroactive: May's counted expense drops to the user's own 60...
    expect(balances.get('2026-05')!.totalExpenses, 60);
    expect(balances.get('2026-05')!.remainingBalance, 940);
    // ...and the correction propagates forward. This is the reported bug.
    expect(balances.get('2026-06')!.carryOver, 940);
    expect(balances.get('2026-06')!.remainingBalance, 1940);
  });

  test('manual carry-over adjustment survives a later split settlement',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(id: '2026-05', salary: 1000),
    );
    await balances.put(
      '2026-06',
      MonthlyBalanceModel(id: '2026-06', salary: 1000),
    );
    await expenses.put(
      'may-dinner',
      _cashExpense(
        id: 'may-dinner',
        name: 'May dinner',
        amount: 120,
        date: DateTime(2026, 5, 30),
      ),
    );

    final splitRepository = SplitRepository();
    await splitRepository.createSplit(
      expenseId: 'may-dinner',
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

    // Calculated carry-over is 880; the user types 900 instead (+20 adjustment).
    await BalanceRepository().setCarryOverForMonth('2026-06', 900);
    expect(balances.get('2026-06')!.carryOver, 900);
    expect(balances.get('2026-06')!.carryOverAdjustment, 20);

    final friend = HiveStorage.splitParticipantsBoxRef.values
        .firstWhere((p) => p.name == 'Friend');
    await splitRepository.markParticipantAsPaid(
      friend.id,
      paidAt: DateTime(2026, 6, 2),
    );
    await ExpenseRepository().reconcileMonthlyExpenses();

    // The repaid 60 lands on top of the manual +20: 940 calculated + 20 = 960.
    expect(balances.get('2026-06')!.carryOver, 960);
    expect(balances.get('2026-06')!.carryOverAdjustment, 20);

    // Clearing the override returns the month to the calculated value.
    await BalanceRepository().clearCarryOverAdjustment('2026-06');
    expect(balances.get('2026-06')!.carryOver, 940);
  });

  test('overspend rolls forward as negative carry-over', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put('2026-05', MonthlyBalanceModel(id: '2026-05', salary: 100));
    await balances.put('2026-06', MonthlyBalanceModel(id: '2026-06', salary: 100));
    await expenses.put(
      'overspend',
      _cashExpense(
        id: 'overspend',
        name: 'Overspend',
        amount: 150,
        date: DateTime(2026, 5, 4),
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();

    expect(balances.get('2026-05')!.remainingBalance, -50);
    expect(balances.get('2026-06')!.carryOver, -50);
    expect(balances.get('2026-06')!.remainingBalance, 50);
  });

  test('carry-over passes through a month with no balance row', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put('2026-05', MonthlyBalanceModel(id: '2026-05', salary: 500));
    await balances.put('2026-07', MonthlyBalanceModel(id: '2026-07', salary: 500));
    await expenses.put(
      'may',
      _cashExpense(
        id: 'may',
        name: 'May',
        amount: 100,
        date: DateTime(2026, 5, 4),
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();

    // June never existed and must not be synthesised.
    expect(balances.get('2026-06'), isNull);
    expect(balances.get('2026-07')!.carryOver, 400);
  });

  test('the earliest month keeps its carry-over as an opening balance',
      () async {
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put(
      '2026-05',
      MonthlyBalanceModel(
        id: '2026-05',
        salary: 1000,
        carryOverAdjustment: 250,
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();

    expect(balances.get('2026-05')!.carryOver, 250);
  });

  test('reconcile is idempotent', () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put('2026-05', MonthlyBalanceModel(id: '2026-05', salary: 1000));
    await balances.put('2026-06', MonthlyBalanceModel(id: '2026-06', salary: 1000));
    await expenses.put(
      'visa-may-paid-june',
      _expense(
        id: 'visa-may-paid-june',
        name: 'Card',
        amount: 200,
        date: DateTime(2026, 5, 20),
        repaymentStatus: 'paid',
        repaymentDate: DateTime(2026, 6, 3),
      ),
    );

    await ExpenseRepository().reconcileMonthlyExpenses();
    final first = balances.values.map((b) => b.toMap()).toList();
    await ExpenseRepository().reconcileMonthlyExpenses();
    final second = balances.values.map((b) => b.toMap()).toList();

    expect(second, equals(first));
  });

  test('adding an expense rebuilds the carry-over chain without a reconcile',
      () async {
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put('2026-05', MonthlyBalanceModel(id: '2026-05', salary: 1000));
    await balances.put('2026-06', MonthlyBalanceModel(id: '2026-06', salary: 1000));
    await ExpenseRepository().reconcileMonthlyExpenses();
    expect(balances.get('2026-06')!.carryOver, 1000);

    await ExpenseRepository().addExpense(
      _cashExpense(
        id: 'ignored',
        name: 'May cash',
        amount: 50,
        date: DateTime(2026, 5, 9),
      ),
    );

    // The incremental path must chain too, not wait for the next restart.
    expect(balances.get('2026-05')!.totalExpenses, 50);
    expect(balances.get('2026-06')!.carryOver, 950);
  });

  test('recreating a split preserves participant identity and settlement',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;
    final participants = HiveStorage.splitParticipantsBoxRef;

    await balances.put('2026-05', MonthlyBalanceModel(id: '2026-05', salary: 1000));
    await expenses.put(
      'may-dinner',
      _cashExpense(
        id: 'may-dinner',
        name: 'May dinner',
        amount: 120,
        date: DateTime(2026, 5, 30),
      ),
    );

    final splitRepository = SplitRepository();
    await splitRepository.createSplit(
      expenseId: 'may-dinner',
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
    final friend =
        participants.values.firstWhere((p) => p.name == 'Friend');
    await splitRepository.markParticipantAsPaid(
      friend.id,
      paidAt: DateTime(2026, 6, 2),
    );
    await ExpenseRepository().reconcileMonthlyExpenses();
    expect(balances.get('2026-05')!.totalExpenses, 60);

    // The edit flow deletes and recreates the split, passing the stored
    // participants back in.
    final stored = participants.values
        .map((p) => SplitParticipantModel(
              id: p.id,
              splitId: '',
              name: p.name,
              amount: p.amount,
              isSlipPayer: p.isSlipPayer,
              isPaid: p.isPaid,
              paidAt: p.paidAt,
            ))
        .toList();
    await splitRepository.deleteSplitByExpenseId('may-dinner');
    await splitRepository.createSplit(
      expenseId: 'may-dinner',
      totalAmount: 120,
      participants: stored,
    );
    await ExpenseRepository().reconcileMonthlyExpenses();

    final rebuiltFriend =
        participants.values.firstWhere((p) => p.name == 'Friend');
    expect(rebuiltFriend.id, friend.id);
    expect(rebuiltFriend.paidAt, DateTime(2026, 6, 2));
    // The settlement must survive: without it May jumps back to the full 120.
    expect(balances.get('2026-05')!.totalExpenses, 60);
  });

  test('editing a paid credit expense keeps it paid in its repayment month',
      () async {
    final expenses = HiveStorage.expensesBoxRef;
    final balances = HiveStorage.monthlyBalanceBoxRef;

    await balances.put('2026-06', MonthlyBalanceModel(id: '2026-06', salary: 1000));
    await expenses.put(
      'visa-paid',
      _expense(
        id: 'visa-paid',
        name: 'Card',
        amount: 100,
        date: DateTime(2026, 5, 20),
        repaymentStatus: 'paid',
        repaymentDate: DateTime(2026, 6, 3),
      ),
    );
    await ExpenseRepository().reconcileMonthlyExpenses();
    expect(balances.get('2026-06')!.totalExpenses, 100);

    final renamed = expenses.get('visa-paid')!.copyWith(name: 'Card renamed');
    await ExpenseRepository().updateExpense(renamed);

    expect(expenses.get('visa-paid')!.repaymentStatus, 'paid');
    expect(expenses.get('visa-paid')!.repaymentDate, DateTime(2026, 6, 3));
    expect(balances.get('2026-06')!.totalExpenses, 100);
  });
}

void _registerAdapters() {
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

Future<void> _openBoxes() async {
  await Hive.openBox<ExpenseModel>(HiveStorage.expensesBox);
  await Hive.openBox<CategoryModel>(HiveStorage.categoriesBox);
  await Hive.openBox<MonthlyBalanceModel>(HiveStorage.monthlyBalanceBox);
  await Hive.openBox<ExpenseSplitModel>(HiveStorage.expenseSplitsBox);
  await Hive.openBox<SplitParticipantModel>(HiveStorage.splitParticipantsBox);
}

Future<void> _seedCategories() async {
  final box = HiveStorage.categoriesBoxRef;
  for (final category in CategoryModel.defaultCategories()) {
    await box.put(category.id, category);
  }
}

ExpenseModel _expense({
  required String id,
  required String name,
  required double amount,
  required DateTime date,
  String cardName = 'Visa',
  String repaymentStatus = 'pending',
  DateTime? repaymentDate,
}) {
  return ExpenseModel(
    id: id,
    name: name,
    amount: amount,
    date: date,
    categoryId: 'other',
    createdAt: date,
    paymentMethod: 'credit_card',
    creditCardName: cardName,
    repaymentStatus: repaymentStatus,
    repaymentDate: repaymentDate,
  );
}

ExpenseModel _cashExpense({
  required String id,
  required String name,
  required double amount,
  required DateTime date,
}) {
  return ExpenseModel(
    id: id,
    name: name,
    amount: amount,
    date: date,
    categoryId: 'other',
    createdAt: date,
  );
}
