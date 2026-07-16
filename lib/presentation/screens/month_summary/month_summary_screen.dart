import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart' as utils;
import '../../../data/models/category_model.dart';
import '../../../data/models/currency_config.dart';
import '../../providers/expense_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
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
    ref.watch(balanceProvider);
    final balance =
        ref.watch(balanceProvider.notifier).getMonthBalance(_selectedMonth);
    ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);
    final expenseNotifier = ref.read(expensesProvider.notifier);

    final monthExpenses =
        expenseNotifier.getAccountingExpensesByMonth(_selectedMonth);

    final categoryExpenses = <String, double>{};
    for (final expense in monthExpenses) {
      final countedAmount = expenseNotifier.getCountedAmount(expense);
      if (countedAmount <= 0) continue;
      categoryExpenses[expense.categoryId] =
          (categoryExpenses[expense.categoryId] ?? 0) + countedAmount;
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
                    value: CurrencyFormatter.format(balance.salary, currency),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Carry-over',
                    value:
                        CurrencyFormatter.format(balance.carryOver, currency),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Total Expenses',
                    value: CurrencyFormatter.format(
                        balance.totalExpenses, currency),
                    valueColor: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryRow(
                    label: 'Remaining',
                    value: CurrencyFormatter.format(
                        balance.remainingBalance, currency),
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
                SummaryChart(
                  categoryExpenses: categoryExpenses,
                  categories: categories,
                  onTap: () => _showCategoryBreakdown(
                    context,
                    categoryExpenses,
                    categories,
                    currency,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MonthlyExpenseList(
                  expenses: monthExpenses,
                  categories: categories,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryBreakdown(
    BuildContext context,
    Map<String, double> categoryExpenses,
    List<CategoryModel> categories,
    CurrencyConfig currency,
  ) {
    if (categoryExpenses.isEmpty) return;

    final entries = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Spend by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        CurrencyFormatter.format(total, currency),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final category = _categoryFor(entry.key, categories);
                      final percentage =
                          total == 0 ? 0 : (entry.value / total * 100);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        title: Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(entry.value, currency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  CategoryModel _categoryFor(
      String categoryId, List<CategoryModel> categories) {
    return categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => categories.firstWhere(
        (c) => c.id == 'other',
        orElse: () => CategoryModel(
          id: 'other',
          name: 'Other',
          emoji: '?',
        ),
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
