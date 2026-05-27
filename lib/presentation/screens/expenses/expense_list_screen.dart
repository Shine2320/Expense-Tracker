import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart' as utils;
import '../../../data/models/currency_config.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
import '../add_expense/add_expense_sheet.dart';
import 'widgets/expense_item.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  bool _showDeleted = false;

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expensesProvider);
    final categories = ref.watch(categoryProvider).categories;
    final currency = ref.watch(currencyProvider);
    final allGrouped = expenseState.groupedExpenses;

    final groupedExpenses = _showDeleted
        ? Map<String, List<ExpenseModel>>.fromEntries(
            allGrouped.entries.where((e) => e.value.any((x) => x.isDeleted)).map((e) =>
              MapEntry(e.key, e.value.where((x) => x.isDeleted).toList())))
        : allGrouped;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.expenses),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Active')),
              ButtonSegment(value: true, label: Text('Deleted')),
            ],
            selected: {_showDeleted},
            onSelectionChanged: (selected) {
              setState(() => _showDeleted = selected.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: expenseState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showDeleted ? Icons.delete_outline : Icons.receipt_long_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _showDeleted ? 'No deleted expenses' : AppStrings.noExpenses,
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
                        _DateHeader(
                          date: date,
                          dayTotal: dayTotal,
                          currency: currency,
                        ),
                        ...expenses.map((expense) {
                          final category = categories.firstWhere(
                            (c) => c.id == expense.categoryId,
                            orElse: () => categories.firstWhere((c) => c.id == 'other'),
                          );
                          return ExpenseItem(
                            expense: expense,
                            category: category,
                            currency: currency,
                            onEdit: () {
                              if (expense.isDeleted) return;
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
                              if (_showDeleted) {
                                _showPermanentDeleteDialog(context, ref, expense);
                              } else {
                                _showSoftDeleteWithUndo(context, ref, expense);
                              }
                            },
                            onRestore: expense.isDeleted
                                ? () => _showRestoreDialog(context, ref, expense)
                                : null,
                          );
                        }).toList(),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    );
                  },
                ),
    );
  }

  void _showSoftDeleteWithUndo(BuildContext context, WidgetRef ref, dynamic expense) {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(expensesProvider.notifier).deleteExpense(expense.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${expense.name}" struck through'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final restored = expense.copyWith(isDeleted: false);
            if (restored != null) {
              ref.read(expensesProvider.notifier).updateExpense(restored);
            }
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPermanentDeleteDialog(BuildContext context, WidgetRef ref, dynamic expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text(
          'This will permanently remove the expense from all records and totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(expensesProvider.notifier).permanentlyDeleteExpense(expense.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref, dynamic expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Expense'),
        content: const Text('Restore this expense to active status?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final restored = expense.copyWith(isDeleted: false);
              if (restored != null) {
                ref.read(expensesProvider.notifier).updateExpense(restored);
              }
              Navigator.pop(context);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final double dayTotal;
  final CurrencyConfig currency;

  const _DateHeader({
    required this.date,
    required this.dayTotal,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
            'Total: ${CurrencyFormatter.format(dayTotal, currency)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
