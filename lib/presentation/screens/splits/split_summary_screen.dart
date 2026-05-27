import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/expense_split_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/split_participant_model.dart';
import '../../providers/split_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/constants/app_spacing.dart';

class SplitSummaryScreen extends ConsumerWidget {
  const SplitSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitState = ref.watch(splitProvider);
    final expenseState = ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Group all splits by ID for display
    final splitGroups = <ExpenseSplitModel, List<SplitParticipantModel>>{};
    for (final split in splitState.splits) {
      final participants = ref.read(splitProvider.notifier)
          .getParticipantsBySplitId(split.id);
      if (participants.isNotEmpty) {
        splitGroups[split] = participants;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Payments'),
      ),
      body: splitGroups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: colorScheme.outline),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No split payments',
                    style: TextStyle(color: colorScheme.outline, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: splitGroups.length,
              itemBuilder: (context, index) {
                final split = splitGroups.keys.elementAt(index);
                final participants = splitGroups[split]!;
                final expense = expenseState.expenses.firstWhere(
                  (e) => e.id == split.expenseId,
                  orElse: () => ExpenseModel(
                    id: '', name: 'Deleted expense', amount: 0,
                    date: DateTime.now(), categoryId: '', createdAt: DateTime.now(),
                  ),
                );
                final slipParticipant = participants.firstWhere(
                  (p) => p.isSlipPayer,
                  orElse: () => SplitParticipantModel(id: '', splitId: '', name: '', amount: 0),
                );
                final nonSlipParticipants = participants.where((p) => !p.isSlipPayer).toList();
                final pendingParticipants = nonSlipParticipants.where((p) => !p.isPaid).toList();
                final paidParticipants = nonSlipParticipants.where((p) => p.isPaid).toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header: expense name + slip person info ──
                        Text(
                          expense.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (slipParticipant.name.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${slipParticipant.name} paid upfront',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        const Divider(height: AppSpacing.md),
                        // ── Pending participants ──
                        if (pendingParticipants.isNotEmpty) ...[
                          Text(
                            'Pending (${pendingParticipants.length})',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...pendingParticipants.map((participant) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(participant.name),
                              subtitle: slipParticipant.name.isNotEmpty
                                  ? Text('Owes ${slipParticipant.name}')
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(participant.amount, currency),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  IconButton(
                                    icon: Icon(Icons.check_circle_outline, color: colorScheme.primary),
                                    onPressed: () async {
                                      await ref.read(splitProvider.notifier)
                                          .markParticipantAsPaid(participant.id);
                                      if (expense.isCreditCard && expense.isPaid) {
                                        ref.read(expenseRepositoryProvider)
                                            .adjustMonthlyExpenses(expense.date, -participant.amount);
                                      }
                                      ref.read(balanceProvider.notifier).loadBalance();
                                    },
                                    tooltip: 'Mark as Paid',
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        // ── Paid participants ──
                        if (paidParticipants.isNotEmpty) ...[
                          if (pendingParticipants.isNotEmpty)
                            const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Paid (${paidParticipants.length})',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...paidParticipants.map((participant) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.secondaryContainer,
                                child: Icon(Icons.check, color: colorScheme.onSecondaryContainer),
                              ),
                              title: Text(
                                participant.name,
                                style: const TextStyle(decoration: TextDecoration.lineThrough),
                              ),
                              subtitle: slipParticipant.name.isNotEmpty
                                  ? Text('Paid back ${slipParticipant.name}')
                                  : const Text('Paid'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(participant.amount, currency),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface.withOpacity(0.3),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  IconButton(
                                    icon: Icon(Icons.undo, color: colorScheme.onSurfaceVariant),
                                    onPressed: () async {
                                      await ref.read(splitProvider.notifier)
                                          .unmarkParticipantAsPaid(participant.id);
                                      if (expense.isCreditCard && expense.isPaid) {
                                        ref.read(expenseRepositoryProvider)
                                            .adjustMonthlyExpenses(expense.date, participant.amount);
                                      }
                                      ref.read(balanceProvider.notifier).loadBalance();
                                    },
                                    tooltip: 'Undo Paid',
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
