import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/money_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/currency_config.dart';
import '../../../providers/balance_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../widgets/common/income_dialogs.dart';

class BalanceCard extends ConsumerWidget {
  final BalanceState balanceState;
  final double creditPending;

  const BalanceCard({
    super.key,
    required this.balanceState,
    this.creditPending = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = context.money;
    final currency = ref.watch(currencyProvider);
    final balance = balanceState.currentMonth;

    final available = balanceState.availableBalance;
    final spent = balanceState.totalExpenses;
    final remaining = balanceState.remainingBalance;
    // Guard against a zero-income month, where "percent spent" is meaningless.
    final spentFraction =
        available > 0 ? (spent / available).clamp(0.0, 1.0).toDouble() : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining this month', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            // The one number the screen exists to answer.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: Text(
                CurrencyFormatter.format(remaining, currency),
                key: ValueKey(remaining),
                style: MoneyText.hero(context).copyWith(
                  color: money.forBalance(remaining),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SpendMeter(fraction: spentFraction, isOverspent: remaining < 0),
            const SizedBox(height: AppSpacing.sm),
            Text(
              available > 0
                  ? '${CurrencyFormatter.format(spent, currency)} spent of ${CurrencyFormatter.format(available, currency)}'
                  : '${CurrencyFormatter.format(spent, currency)} spent',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _BalanceRow(
              label: 'Salary',
              value: CurrencyFormatter.format(balance.salary, currency),
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => showEditSalaryDialog(context, ref),
            ),
            const Divider(height: AppSpacing.lg),
            _BalanceRow(
              label: 'Carried over',
              // Say where it came from: this figure now moves when an earlier
              // month is corrected, so an unexplained change looks like a bug.
              detail: balance.carryOverAdjustment != 0
                  ? 'From last month - adjusted by you'
                  : 'From last month',
              value: CurrencyFormatter.format(balance.carryOver, currency),
              icon: Icons.history_outlined,
              valueColor: balance.carryOver < 0 ? money.negative : null,
              onTap: () => showEditCarryOverDialog(context, ref),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Spent',
                    value: CurrencyFormatter.format(spent, currency),
                    color: money.negative,
                    container: money.negativeContainer,
                    onContainer: money.onNegativeContainer,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    label: creditPending > 0 ? 'Card due' : 'Available',
                    value: CurrencyFormatter.format(
                      creditPending > 0 ? creditPending : available,
                      currency,
                    ),
                    color:
                        creditPending > 0 ? money.pending : money.positive,
                    container: creditPending > 0
                        ? money.pendingContainer
                        : money.positiveContainer,
                    onContainer: creditPending > 0
                        ? money.onPendingContainer
                        : money.onPositiveContainer,
                    currency: currency,
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

/// How much of this month's money is already gone.
class _SpendMeter extends StatelessWidget {
  final double fraction;
  final bool isOverspent;

  const _SpendMeter({required this.fraction, required this.isOverspent});

  @override
  Widget build(BuildContext context) {
    final money = context.money;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: isOverspent ? 1.0 : fraction),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(
            isOverspent
                ? money.negative
                : fraction > 0.85
                    ? money.pending
                    : money.positive,
          ),
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String? detail;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _BalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  if (detail != null)
                    Text(detail!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              value,
              style: MoneyText.medium(context).copyWith(color: valueColor),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color container;
  final Color onContainer;
  final CurrencyConfig currency;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.container,
    required this.onContainer,
    required this.currency,
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
              value,
              style: MoneyText.medium(context).copyWith(color: onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
