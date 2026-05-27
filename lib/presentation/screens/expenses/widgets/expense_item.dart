import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_utils.dart' as utils;
import '../../../../data/models/expense_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/models/currency_config.dart';
import '../../../../presentation/providers/split_provider.dart';

class ExpenseItem extends ConsumerWidget {
  final ExpenseModel expense;
  final CategoryModel category;
  final CurrencyConfig currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentDelete;

  const ExpenseItem({
    super.key,
    required this.expense,
    required this.category,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    this.onRestore,
    this.onPermanentDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleted = expense.isDeleted;
    final colorScheme = Theme.of(context).colorScheme;
    final hasSplit = ref.watch(splitProvider.notifier).getSplitByExpenseId(expense.id) != null;

    return Dismissible(
      key: Key(expense.id),
      direction: isDeleted ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        color: isDeleted ? colorScheme.surfaceVariant.withOpacity(0.3) : null,
        child: ListTile(
          leading: Opacity(
            opacity: isDeleted ? 0.4 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          title: Text(
            expense.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
              color: isDeleted ? colorScheme.onSurface.withOpacity(0.4) : colorScheme.onSurface,
            ),
          ),
          subtitle: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              if (isDeleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Deleted',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              if (hasSplit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Split',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              Text(
                '${category.name} • ${utils.DateUtils.formatTime(expense.date)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDeleted
                      ? colorScheme.onSurface.withOpacity(0.3)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          trailing: Text(
            CurrencyFormatter.format(expense.amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDeleted
                  ? colorScheme.onSurface.withOpacity(0.3)
                  : colorScheme.error,
              fontSize: 16,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
            ),
          ),
          onTap: isDeleted ? onRestore : onEdit,
        ),
      ),
    );
  }
}
