import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart' as utils;
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../add_expense/add_expense_sheet.dart';
import 'widgets/expense_item.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseState = ref.watch(expensesProvider);
    final categories = ref.watch(categoryProvider).categories;
    final groupedExpenses = expenseState.groupedExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.expenses),
      ),
      body: expenseState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppStrings.noExpenses,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: groupedExpenses.length,
                  itemBuilder: (context, index) {
                    final dateKey = groupedExpenses.keys.elementAt(index);
                    final expenses = groupedExpenses[dateKey]!;
                    final date = DateTime.parse(dateKey);
                    final dayTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                utils.DateUtils.formatDisplayDate(date),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Total: ${CurrencyFormatter.format(dayTotal)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...expenses.map((expense) {
                          final category = categories.firstWhere(
                            (c) => c.id == expense.categoryId,
                            orElse: () => categories.firstWhere((c) => c.id == 'other'),
                          );
                          return ExpenseItem(
                            expense: expense,
                            category: category,
                            onEdit: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) => AddExpenseSheet(expense: expense),
                              );
                            },
                            onDelete: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Expense'),
                                  content: const Text('Are you sure you want to delete this expense?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        ref.read(expensesProvider.notifier).deleteExpense(expense.id);
                                        Navigator.pop(context);
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    );
                  },
                ),
    );
  }
}
