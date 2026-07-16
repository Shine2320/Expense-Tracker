import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_utils.dart' as utils;
import '../../../../data/models/expense_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/models/split_participant_model.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../presentation/providers/currency_provider.dart';
import '../../../../presentation/providers/expense_provider.dart';
import '../../../../presentation/providers/split_provider.dart';
import '../../expenses/widgets/expense_item.dart';

/// How much of a split expense has been repaid, and when it last happened.
class _Settlement {
  final double repaid;
  final DateTime? lastPaidAt;

  const _Settlement({required this.repaid, this.lastPaidAt});
}

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
    final expenseNotifier = ref.watch(expensesProvider.notifier);
    // One pass over the split boxes for the whole list, rather than one per row.
    final splitIndex = expenseNotifier.buildSplitIndex();
    final participantsBySplitId =
        ref.watch(splitProvider.notifier).participantsBySplitId();

    for (final expense in expenses) {
      final accountingDate =
          expenseNotifier.getAccountingDate(expense) ?? expense.date;
      final dateKey = utils.DateUtils.formatDate(accountingDate);
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
          final dayTotal = dateExpenses.fold<double>(
            0,
            (sum, e) => sum + expenseNotifier.countedAmountWith(e, splitIndex),
          );

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
                final accountingDate =
                    expenseNotifier.getAccountingDate(expense) ?? expense.date;
                final showCreditPaymentDetails =
                    expense.isCreditCard && expense.isPaid;
                final isPreviousMonthCredit = showCreditPaymentDetails &&
                    utils.DateUtils.formatMonthKey(accountingDate) !=
                        utils.DateUtils.formatMonthKey(expense.date);

                // A split settled later retroactively reduces this month's
                // counted amount, so say so rather than letting a historical
                // figure change unexplained.
                final settlement = _settlementFor(
                  expense,
                  splitIndex,
                  participantsBySplitId,
                );
                final countedAmount =
                    expenseNotifier.countedAmountWith(expense, splitIndex);

                final details = <String>[
                  if (isPreviousMonthCredit)
                    'Original expense: ${utils.DateUtils.formatDisplayDate(expense.date)}',
                  if (settlement != null)
                    'You paid ${CurrencyFormatter.format(expense.amount, currency)}'
                        ' - ${CurrencyFormatter.format(settlement.repaid, currency)} repaid'
                        '${settlement.lastPaidAt != null ? ' ${utils.DateUtils.formatDisplayDate(settlement.lastPaidAt!)}' : ''}',
                ];

                return ExpenseItem(
                  expense: expense,
                  category: category,
                  currency: currency,
                  amountOverride: countedAmount,
                  statusLabels: [
                    if (showCreditPaymentDetails) 'Credit paid this month',
                    if (settlement != null) 'Split settled',
                  ],
                  detailText: details.isEmpty ? null : details.join(' - '),
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

  /// Returns what others have repaid on this expense's split, or null when the
  /// expense isn't a split the user fronted or nobody has settled yet.
  ///
  /// Takes prebuilt lookups: resolving these per row rescans the split boxes
  /// for every expense on screen.
  _Settlement? _settlementFor(
    ExpenseModel expense,
    SplitAccountingIndex splitIndex,
    Map<String, List<SplitParticipantModel>> participantsBySplitId,
  ) {
    final split = splitIndex.splitsByExpenseId[expense.id];
    if (split == null || split.slipPersonId == null) return null;

    final settled = (participantsBySplitId[split.id] ?? const [])
        .where((p) => !p.isSlipPayer && p.isPaid);
    if (settled.isEmpty) return null;

    final repaid = settled.fold<double>(0, (sum, p) => sum + p.amount);
    final lastPaidAt = settled
        .map((p) => p.paidAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    return _Settlement(repaid: repaid, lastPaidAt: lastPaidAt);
  }
}
