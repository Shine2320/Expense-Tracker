import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/balance_provider.dart';
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
    final currentMonth = DateTime.now();
    final pendingCount = splitState.pendingPayments.length;

    final creditPending = expenseState.expenses
        .where((e) => e.isCreditCard && e.isPending && !e.isDeleted)
        .fold<double>(0, (sum, e) => sum + e.amount);

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
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.credit_card_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Credit Cards'),
                subtitle: const Text('Manage unpaid expenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreditCardScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.people_outline,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                title: const Text('Split Payments'),
                subtitle: Text(pendingCount > 0 ? '$pendingCount pending' : 'All settled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SplitSummaryScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  AppStrings.recentExpenses,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
