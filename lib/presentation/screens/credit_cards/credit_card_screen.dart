import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/currency_config.dart';
import '../../providers/expense_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/category_provider.dart';

class CreditCardScreen extends ConsumerWidget {
  const CreditCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseState = ref.watch(expensesProvider);
    final categories = ref.watch(categoryProvider).categories;
    final currency = ref.watch(currencyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final creditExpenses = expenseState.expenses
        .where((e) => e.isCreditCard && !e.isDeleted)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final pending = creditExpenses.where((e) => e.isPending).toList();
    final paid = creditExpenses.where((e) => e.isPaid).toList();

    final pendingTotal = pending.fold<double>(0, (sum, e) => sum + e.amount);
    final paidTotal = paid.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Cards'),
      ),
      body: creditExpenses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.credit_card_outlined,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No credit card expenses',
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: 'Pending',
                                amount: pendingTotal,
                                currency: currency,
                                color: colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _SummaryTile(
                                label: 'Paid',
                                amount: paidTotal,
                                currency: currency,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (pending.isNotEmpty) ...[
                  Text(
                    'Pending (${pending.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...pending.map((expense) => _CreditCardTile(
                        expense: expense,
                        categories: categories,
                        currency: currency,
                        colorScheme: colorScheme,
                        onMarkPaid: () => ref.read(expensesProvider.notifier).markAsPaid(expense.id),
                      )),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (paid.isNotEmpty) ...[
                  Text(
                    'Paid (${paid.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...paid.map((expense) => _CreditCardTile(
                        expense: expense,
                        categories: categories,
                        currency: currency,
                        colorScheme: colorScheme,
                        onMarkUnpaid: () => ref.read(expensesProvider.notifier).markAsUnpaid(expense.id),
                      )),
                ],
              ],
            ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final CurrencyConfig currency;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(amount, currency),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  final ExpenseModel expense;
  final List<dynamic> categories;
  final CurrencyConfig currency;
  final ColorScheme colorScheme;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onMarkUnpaid;

  const _CreditCardTile({
    required this.expense,
    required this.categories,
    required this.currency,
    required this.colorScheme,
    this.onMarkPaid,
    this.onMarkUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    final category = categories.cast<dynamic>().firstWhere(
      (c) => c.id == expense.categoryId,
      orElse: () => categories.firstWhere((c) => c.id == 'other'),
    );

    final isPaid = expense.isPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(category.emoji, style: const TextStyle(fontSize: 18)),
        ),
        title: Text(
          expense.name,
          style: TextStyle(
            decoration: isPaid ? TextDecoration.lineThrough : null,
            color: isPaid ? colorScheme.onSurface.withOpacity(0.4) : null,
          ),
        ),
        subtitle: Text(
          expense.creditCardName ?? 'Unknown Card',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(expense.amount, currency),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid
                    ? colorScheme.onSurface.withOpacity(0.3)
                    : colorScheme.error,
                decoration: isPaid ? TextDecoration.lineThrough : null,
              ),
            ),
            if (!isPaid) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  color: colorScheme.primary,
                ),
                onPressed: onMarkPaid,
                tooltip: 'Mark as Paid',
              ),
            ] else ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(
                  Icons.undo,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: onMarkUnpaid,
                tooltip: 'Undo Paid',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
