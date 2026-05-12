import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart' as utils;
import '../../providers/expense_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/category_provider.dart';
import 'widgets/summary_chart.dart';
import 'widgets/monthly_expense_list.dart';

class MonthSummaryScreen extends ConsumerStatefulWidget {
  final DateTime month;

  const MonthSummaryScreen({super.key, required this.month});

  @override
  ConsumerState<MonthSummaryScreen> createState() => _MonthSummaryScreenState();
}

class _MonthSummaryScreenState extends ConsumerState<MonthSummaryScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.month;
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(balanceProvider.notifier).getMonthBalance(_selectedMonth);
    final expenses = ref.watch(expensesProvider);

    ref.read(expensesProvider.notifier).loadExpensesForMonth(_selectedMonth);

    final categoryExpenses = <String, double>{};
    for (final expense in expenses.expenses) {
      categoryExpenses[expense.categoryId] =
          (categoryExpenses[expense.categoryId] ?? 0) + expense.amount;
    }

    final categories = ref.watch(categoryProvider).categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.monthSummary),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                    });
                    ref.read(expensesProvider.notifier).loadExpensesForMonth(_selectedMonth);
                  },
                ),
                Expanded(
                  child: Text(
                    utils.DateUtils.formatMonthYear(_selectedMonth),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    });
                    ref.read(expensesProvider.notifier).loadExpensesForMonth(_selectedMonth);
                  },
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Salary',
                    value: CurrencyFormatter.format(balance.salary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Carry-over',
                    value: CurrencyFormatter.format(balance.carryOver),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Total Expenses',
                    value: CurrencyFormatter.format(balance.totalExpenses),
                    valueColor: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Remaining',
                    value: CurrencyFormatter.format(balance.remainingBalance),
                    valueColor: balance.remainingBalance >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                SummaryChart(categoryExpenses: categoryExpenses, categories: categories),
                const SizedBox(height: AppSpacing.md),
                MonthlyExpenseList(
                  expenses: expenses.expenses,
                  categories: categories,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
