import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/balance_provider.dart';
import '../../providers/currency_provider.dart';

void showEditSalaryDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController(
    text: ref.read(balanceProvider).currentMonth.salary.toStringAsFixed(2),
  );

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Monthly Salary'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Salary',
          prefixText: '${ref.read(currencyProvider).symbol} ',
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
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid number'), behavior: SnackBarBehavior.floating),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showEditCarryOverDialog(BuildContext context, WidgetRef ref) {
  final balance = ref.read(balanceProvider).currentMonth;
  final controller = TextEditingController(
    text: balance.carryOver.toStringAsFixed(2),
  );
  final currency = ref.read(currencyProvider);
  final calculated = ref.read(balanceProvider.notifier).calculatedCarryOver();
  final isAdjusted = balance.carryOverAdjustment != 0;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Previous Month Balance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Carry-over Balance',
              prefixText: '${currency.symbol} ',
              // Naming the calculated value makes an override read as a
              // deliberate deviation rather than a mystery number.
              helperText:
                  'Calculated from last month: ${CurrencyFormatter.format(calculated, currency)}',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your edit is kept as an adjustment, so later changes to last month '
            '(a settled split, a credit card paid) still reach this month.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        if (isAdjusted)
          TextButton(
            onPressed: () {
              ref.read(balanceProvider.notifier).clearCarryOverAdjustment();
              Navigator.pop(context);
            },
            child: const Text('Use calculated'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final carryOver = double.tryParse(controller.text);
            if (carryOver != null) {
              ref.read(balanceProvider.notifier).updateCarryOver(carryOver);
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid number'), behavior: SnackBarBehavior.floating),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
