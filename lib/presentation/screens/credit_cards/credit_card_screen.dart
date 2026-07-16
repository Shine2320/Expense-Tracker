import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/money_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/currency_config.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/common/empty_state.dart';

class CreditCardScreen extends ConsumerStatefulWidget {
  const CreditCardScreen({super.key});

  @override
  ConsumerState<CreditCardScreen> createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends ConsumerState<CreditCardScreen> {
  String _selectedStatus = 'pending';

  @override
  Widget build(BuildContext context) {
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
    final selectedExpenses = _selectedStatus == 'paid' ? paid : pending;

    // Net of split repayments — what you actually owe / paid on the card.
    // Indexed once rather than rescanning the split boxes per expense.
    final expenseNotifier = ref.read(expensesProvider.notifier);
    final splitIndex = expenseNotifier.buildSplitIndex();
    final netByExpenseId = <String, double>{
      for (final e in creditExpenses)
        e.id: expenseNotifier.netSplitAmountWith(e, splitIndex),
    };
    final grouped = _groupByCard(selectedExpenses, netByExpenseId);
    final pendingTotal =
        pending.fold<double>(0, (sum, e) => sum + (netByExpenseId[e.id] ?? 0));
    final paidTotal =
        paid.fold<double>(0, (sum, e) => sum + (netByExpenseId[e.id] ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Cards'),
      ),
      body: creditExpenses.isEmpty
          ? const EmptyState(
              icon: Icons.credit_card_outlined,
              message: 'No credit card expenses',
              hint: 'Add an expense and pick "Credit card" as the payment '
                  'method. It counts against the month you pay the card off.',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _SummaryCard(
                  pendingTotal: pendingTotal,
                  paidTotal: paidTotal,
                  currency: currency,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'pending',
                      label: Text('Pending (${pending.length})'),
                    ),
                    ButtonSegment(
                      value: 'paid',
                      label: Text('Paid (${paid.length})'),
                    ),
                  ],
                  selected: {_selectedStatus},
                  onSelectionChanged: (selected) {
                    setState(() => _selectedStatus = selected.first);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (grouped.isEmpty)
                  EmptyState(
                    icon: _selectedStatus == 'paid'
                        ? Icons.task_alt_outlined
                        : Icons.inbox_outlined,
                    message: _selectedStatus == 'paid'
                        ? 'Nothing paid off yet'
                        : 'Nothing outstanding',
                    hint: _selectedStatus == 'paid'
                        ? 'Cards you mark as paid will appear here.'
                        : 'Every card expense is settled.',
                  )
                else
                  ...grouped.map(
                    (group) => _CreditCardGroup(
                      group: group,
                      categories: categories,
                      currency: currency,
                      colorScheme: colorScheme,
                      isPending: _selectedStatus == 'pending',
                      onMarkCardPaid: () => ref
                          .read(expensesProvider.notifier)
                          .markCardAsPaid(group.cardName),
                      onMarkPaid: (expense) => ref
                          .read(expensesProvider.notifier)
                          .markAsPaid(expense.id),
                      onMarkUnpaid: (expense) => ref
                          .read(expensesProvider.notifier)
                          .markAsUnpaid(expense.id),
                    ),
                  ),
              ],
            ),
    );
  }

  List<_CardExpenseGroup> _groupByCard(
    List<ExpenseModel> expenses,
    Map<String, double> netByExpenseId,
  ) {
    final groups = <String, _CardExpenseGroup>{};

    for (final expense in expenses) {
      final cardName = _displayCardName(expense.creditCardName);
      final key = cardName.toLowerCase();
      groups.putIfAbsent(
        key,
        () => _CardExpenseGroup(
          cardName: cardName,
          netByExpenseId: netByExpenseId,
        ),
      );
      groups[key]!.expenses.add(expense);
    }

    final result = groups.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  String _displayCardName(String? cardName) {
    final trimmed = cardName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Unknown Card';
    }
    return trimmed;
  }
}

class _CardExpenseGroup {
  final String cardName;
  final List<ExpenseModel> expenses = [];

  /// Net-of-split amounts, keyed by expense id. This class has no `ref`, so the
  /// screen resolves the amounts once and passes them in.
  final Map<String, double> netByExpenseId;

  _CardExpenseGroup({required this.cardName, required this.netByExpenseId});

  double get total =>
      expenses.fold<double>(0, (sum, e) => sum + (netByExpenseId[e.id] ?? 0));
}

class _SummaryCard extends StatelessWidget {
  final double pendingTotal;
  final double paidTotal;
  final CurrencyConfig currency;
  final ColorScheme colorScheme;

  const _SummaryCard({
    required this.pendingTotal,
    required this.paidTotal,
    required this.currency,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Still owed',
                    amount: pendingTotal,
                    currency: currency,
                    container: context.money.pendingContainer,
                    onContainer: context.money.onPendingContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryTile(
                    label: 'Paid off',
                    amount: paidTotal,
                    currency: currency,
                    container: context.money.positiveContainer,
                    onContainer: context.money.onPositiveContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final CurrencyConfig currency;
  final Color container;
  final Color onContainer;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.currency,
    required this.container,
    required this.onContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: onContainer),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount, currency),
              style: MoneyText.large(context).copyWith(color: onContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardGroup extends StatelessWidget {
  final _CardExpenseGroup group;
  final List<CategoryModel> categories;
  final CurrencyConfig currency;
  final ColorScheme colorScheme;
  final bool isPending;
  final VoidCallback onMarkCardPaid;
  final ValueChanged<ExpenseModel> onMarkPaid;
  final ValueChanged<ExpenseModel> onMarkUnpaid;

  const _CreditCardGroup({
    required this.group,
    required this.categories,
    required this.currency,
    required this.colorScheme,
    required this.isPending,
    required this.onMarkCardPaid,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        leading: Icon(
          Icons.credit_card_outlined,
          color: colorScheme.primary,
        ),
        title: Text(
          group.cardName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${group.expenses.length} expense'
          '${group.expenses.length == 1 ? '' : 's'}',
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  CurrencyFormatter.format(group.total, currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPending ? colorScheme.error : colorScheme.primary,
                  ),
                ),
              ),
              if (isPending)
                TextButton(
                  onPressed: onMarkCardPaid,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('Mark Card Paid'),
                ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          ...group.expenses.map(
            (expense) => _CreditCardTile(
              expense: expense,
              netAmount: group.netByExpenseId[expense.id] ?? expense.amount,
              category: _categoryFor(expense.categoryId),
              currency: currency,
              colorScheme: colorScheme,
              onMarkPaid: isPending ? () => onMarkPaid(expense) : null,
              onMarkUnpaid: isPending ? null : () => onMarkUnpaid(expense),
            ),
          ),
        ],
      ),
    );
  }

  CategoryModel _categoryFor(String categoryId) {
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

class _CreditCardTile extends StatelessWidget {
  final ExpenseModel expense;

  /// What this expense actually costs you after any split repayments.
  final double netAmount;
  final CategoryModel category;
  final CurrencyConfig currency;
  final ColorScheme colorScheme;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onMarkUnpaid;

  const _CreditCardTile({
    required this.expense,
    required this.netAmount,
    required this.category,
    required this.currency,
    required this.colorScheme,
    this.onMarkPaid,
    this.onMarkUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = expense.isPaid;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(category.emoji, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(
        expense.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: isPaid ? TextDecoration.lineThrough : null,
          color: isPaid ? colorScheme.onSurface.withValues(alpha: 0.4) : null,
        ),
      ),
      subtitle: Text(
        category.name,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              CurrencyFormatter.format(netAmount, currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid
                    ? colorScheme.onSurface.withValues(alpha: 0.3)
                    : colorScheme.error,
                decoration: isPaid ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: Icon(
              isPaid ? Icons.undo : Icons.check_circle_outline,
              color:
                  isPaid ? colorScheme.onSurfaceVariant : colorScheme.primary,
            ),
            onPressed: isPaid ? onMarkUnpaid : onMarkPaid,
            tooltip: isPaid ? 'Undo Paid' : 'Mark as Paid',
          ),
        ],
      ),
    );
  }
}
