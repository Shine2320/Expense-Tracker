import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart' as utils;
import '../../../providers/category_provider.dart';
import '../../../providers/currency_provider.dart';
import 'category_selector.dart';

class ExpenseForm extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final DateTime selectedDate;
  final String selectedCategoryId;
  final bool isEditing;
  final VoidCallback onDateSelected;
  final Function(String) onCategoryChanged;
  final VoidCallback onSave;

  const ExpenseForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.amountController,
    required this.selectedDate,
    required this.selectedCategoryId,
    required this.isEditing,
    required this.onDateSelected,
    required this.onCategoryChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(categoryProvider);
    final categories = categoryState.categories;
    final currency = ref.watch(currencyProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? AppStrings.editExpense : AppStrings.addExpense,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.expenseName,
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppStrings.enterName;
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: AppStrings.amount,
                prefixIcon: Icon(currency.icon),
                prefixText: '${currency.symbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppStrings.enterAmount;
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return AppStrings.enterAmount;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: onDateSelected,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      utils.DateUtils.formatDisplayDate(selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.category,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CategorySelector(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onCategoryChanged: onCategoryChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEditing ? 'Update Expense' : 'Add Expense',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
