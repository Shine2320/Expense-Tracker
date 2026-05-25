import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as utils;
import '../../../providers/expense_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../add_expense/add_expense_sheet.dart';

class RecentExpensesList extends ConsumerWidget {
  const RecentExpensesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseState = ref.watch(expensesProvider);
    final categories = ref.watch(categoryProvider).categories;
    final currency = ref.watch(currencyProvider);
    final recentExpenses = expenseState.expenses.take(5).toList();

    if (recentExpenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No expenses yet',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          ...recentExpenses.asMap().entries.map((entry) {
            final index = entry.key;
            final expense = entry.value;
            final category = categories.firstWhere(
              (c) => c.id == expense.categoryId,
              orElse: () => categories.firstWhere((c) => c.id == 'other'),
            );

            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    expense.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    utils.DateUtils.formatDisplayDate(expense.date),
                  ),
                  trailing: Text(
                    CurrencyFormatter.format(expense.amount, currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) => AddExpenseSheet(expense: expense),
                    );
                  },
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
