import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/money_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/balance_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/split_provider.dart';
import '../month_summary/month_summary_screen.dart';
import '../settings/settings_screen.dart';
import '../credit_cards/credit_card_screen.dart';
import '../splits/split_summary_screen.dart';
import 'widgets/balance_card.dart';
import 'widgets/monthly_chart.dart';
import 'widgets/recent_expenses_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceState = ref.watch(balanceProvider);
    final splitState = ref.watch(splitProvider);
    final expenseState = ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);
    final currentMonth = DateTime.now();
    final pendingCount = splitState.pendingPayments.length;

    // Net of any split repayments: what you still owe, not the sticker price.
    // Deliberately getNetSplitAmount and not getCountedAmount — the latter is 0
    // for a pending card expense, which would render this as always zero.
    final expenseNotifier = ref.read(expensesProvider.notifier);
    final creditPending = expenseState.expenses
        .where((e) => e.isCreditCard && e.isPending && !e.isDeleted)
        .fold<double>(0, (sum, e) => sum + expenseNotifier.getNetSplitAmount(e));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(balanceProvider.notifier).loadBalance();
          ref.read(expensesProvider.notifier).loadExpenses();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            BalanceCard(balanceState: balanceState, creditPending: creditPending),
            const SizedBox(height: AppSpacing.md),
            MonthlyChart(month: currentMonth),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _NavTile(
                    icon: Icons.credit_card_outlined,
                    label: 'Credit cards',
                    // Surface the number that matters instead of a static blurb.
                    badge: creditPending > 0
                        ? CurrencyFormatter.format(creditPending, currency)
                        : 'All paid',
                    highlight: creditPending > 0,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreditCardScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _NavTile(
                    icon: Icons.people_outline,
                    label: 'Splits',
                    badge: pendingCount > 0
                        ? '$pendingCount pending'
                        : 'All settled',
                    highlight: pendingCount > 0,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SplitSummaryScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.recentExpenses,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonthSummaryScreen(month: currentMonth),
                      ),
                    );
                  },
                  child: const Text(AppStrings.viewDetails),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const RecentExpensesList(),
            // Clears the extended FAB, which now shows on every tab.
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

/// Compact entry point to a sub-screen, showing the live figure that decides
/// whether you need to go there.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String badge;
  final bool highlight;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.badge,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = context.money;
    final accent = highlight ? money.pending : theme.colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: accent),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  badge,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: highlight ? accent : theme.colorScheme.onSurfaceVariant,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
