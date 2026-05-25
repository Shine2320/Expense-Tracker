import 'package:flutter/material.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/expense_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/models/currency_config.dart';

class ExpenseItem extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryModel category;
  final CurrencyConfig currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseItem({
    super.key,
    required this.expense,
    required this.category,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      confirmDismiss: (direction) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              category.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          title: Text(
            expense.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(category.name),
          trailing: Text(
            CurrencyFormatter.format(expense.amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
              fontSize: 16,
            ),
          ),
          onTap: onEdit,
        ),
      ),
    );
  }
}
