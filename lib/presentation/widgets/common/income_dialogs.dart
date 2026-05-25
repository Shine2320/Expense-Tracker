import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final controller = TextEditingController(
    text: ref.read(balanceProvider).currentMonth.carryOver.toStringAsFixed(2),
  );

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Previous Month Balance'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Carry-over Balance',
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
