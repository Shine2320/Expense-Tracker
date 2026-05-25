import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_utils.dart' as utils;
import '../../../../data/models/expense_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../../presentation/providers/currency_provider.dart';
import '../../expenses/widgets/expense_item.dart';

class MonthlyExpenseList extends ConsumerWidget {
  final List<ExpenseModel> expenses;
  final List<CategoryModel> categories;

  const MonthlyExpenseList({
    super.key,
    required this.expenses,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final groupedByDate = <String, List<ExpenseModel>>{};

    for (final expense in expenses) {
      final dateKey = utils.DateUtils.formatDate(expense.date);
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(expense);
    }

    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No expenses for this month',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Expenses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...groupedByDate.entries.map((entry) {
          final dateKey = entry.key;
          final dateExpenses = entry.value;
          final date = DateTime.parse(dateKey);
          final dayTotal = dateExpenses.fold<double>(0, (sum, e) => sum + e.amount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      utils.DateUtils.formatDisplayDate(date),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(dayTotal, currency),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ...dateExpenses.map((expense) {
                final category = categories.firstWhere(
                  (c) => c.id == expense.categoryId,
                  orElse: () => categories.firstWhere((c) => c.id == 'other'),
                );
                return ExpenseItem(
                  expense: expense,
                  category: category,
                  currency: currency,
                  onEdit: () {},
                  onDelete: () {},
                );
              }).toList(),
              const SizedBox(height: AppSpacing.md),
            ],
          );
        }).toList(),
      ],
    );
  }
}
