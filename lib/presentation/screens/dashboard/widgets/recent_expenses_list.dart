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
    ref.watch(expensesProvider);
    final categories = ref.watch(categoryProvider).categories;
    final currency = ref.watch(currencyProvider);
    final recentExpenses =
        ref.read(expensesProvider.notifier).getAllExpenses().take(5).toList();

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

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          ...recentExpenses.asMap().entries.map((entry) {
            final index = entry.key;
            final expense = entry.value;
            final isDeleted = expense.isDeleted;
            final category = categories.firstWhere(
              (c) => c.id == expense.categoryId,
              orElse: () => categories.firstWhere((c) => c.id == 'other'),
            );

            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                Opacity(
                  opacity: isDeleted ? 0.4 : 1.0,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
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
                      style: TextStyle(
                        decoration:
                            isDeleted ? TextDecoration.lineThrough : null,
                        color: isDeleted
                            ? colorScheme.onSurface.withValues(alpha: 0.4)
                            : null,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (isDeleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Deleted',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        Text(
                          '${utils.DateUtils.formatDisplayDate(expense.date)} • ${utils.DateUtils.formatTime(expense.date)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      CurrencyFormatter.format(expense.amount, currency),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDeleted
                            ? colorScheme.onSurface.withValues(alpha: 0.3)
                            : colorScheme.error,
                        decoration:
                            isDeleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    onTap: isDeleted
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24)),
                              ),
                              builder: (context) =>
                                  AddExpenseSheet(expense: expense),
                            );
                          },
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
