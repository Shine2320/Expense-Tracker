import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_utils.dart' as utils;
import '../../../../data/models/expense_model.dart';
import '../../../../presentation/providers/currency_provider.dart';

class DayExpenseSheet extends ConsumerWidget {
  final DateTime day;
  final List<ExpenseModel> expenses;

  const DayExpenseSheet({
    super.key,
    required this.day,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final visibleExpenses = expenses.where((e) => !e.isDeleted).toList();
    final total = visibleExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    utils.DateUtils.formatDisplayDate(day),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total: ${CurrencyFormatter.format(total, currency)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visibleExpenses.isEmpty
                  ? Center(
                      child: Text(
                        'No expenses for this day',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: visibleExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = visibleExpenses[index];
                        return ListTile(
                          title: Text(
                            expense.name,
                            style: TextStyle(
                              decoration: expense.isDeleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: expense.isDeleted
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4)
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            utils.DateUtils.formatTime(expense.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: Text(
                            CurrencyFormatter.format(expense.amount, currency),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: expense.isDeleted
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.3)
                                  : Theme.of(context).colorScheme.error,
                              decoration: expense.isDeleted
                                  ? TextDecoration.lineThrough
                                  : null,
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
  }
}
