import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../month_summary/month_summary_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/balance_card.dart';
import 'widgets/monthly_chart.dart';
import 'widgets/recent_expenses_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceState = ref.watch(balanceProvider);
    final currentMonth = DateTime.now();

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
            BalanceCard(balanceState: balanceState),
            const SizedBox(height: AppSpacing.md),
            MonthlyChart(month: currentMonth),
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
