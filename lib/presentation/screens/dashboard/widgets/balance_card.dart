import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/balance_provider.dart';

class BalanceCard extends ConsumerWidget {
  final BalanceState balanceState;

  const BalanceCard({super.key, required this.balanceState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BalanceRow(
              label: 'Monthly Salary',
              value: CurrencyFormatter.format(balanceState.currentMonth.salary),
              icon: Icons.account_balance_wallet_outlined,
              color: colorScheme.primary,
              onTap: () => _editSalary(context, ref),
            ),
            const Divider(height: 24),
            _BalanceRow(
              label: 'Previous Balance',
              value: CurrencyFormatter.format(balanceState.currentMonth.carryOver),
              icon: Icons.history_outlined,
              color: colorScheme.secondary,
              onTap: () => _editCarryOver(context, ref),
            ),
            const Divider(height: 24),
            _BalanceRow(
              label: 'Available Balance',
              value: CurrencyFormatter.format(balanceState.availableBalance),
              icon: Icons.savings_outlined,
              color: colorScheme.tertiary,
              isBold: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Expenses',
                    value: CurrencyFormatter.format(balanceState.totalExpenses),
                    color: const Color(AppColors.error),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SummaryCard(
                    label: 'Remaining',
                    value: CurrencyFormatter.format(balanceState.remainingBalance),
                    color: balanceState.remainingBalance >= 0
                        ? const Color(AppColors.success)
                        : const Color(AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editSalary(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: balanceState.currentMonth.salary.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Monthly Salary'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Salary',
            prefixText: '₹',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final salary = double.tryParse(controller.text);
              if (salary != null) {
                ref.read(balanceProvider.notifier).updateSalary(salary);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editCarryOver(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: balanceState.currentMonth.carryOver.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Previous Balance'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Carry-over Balance',
            prefixText: '₹',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final carryOver = double.tryParse(controller.text);
              if (carryOver != null) {
                ref.read(balanceProvider.notifier).updateCarryOver(carryOver);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isBold;

  const _BalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 18 : 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
