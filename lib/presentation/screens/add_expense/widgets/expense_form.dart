import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart' as utils;
import '../../../providers/category_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/payer_name_provider.dart';
import 'category_selector.dart';
import 'participant_entry.dart';

class ExpenseForm extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController creditCardNameController;
  final String paymentMethod;
  final DateTime selectedDate;
  final String selectedCategoryId;
  final bool isEditing;
  final VoidCallback onDateSelected;
  final Function(String) onPaymentMethodChanged;
  final Function(String) onCategoryChanged;
  final VoidCallback onSave;
  final bool isSplit;
  final String splitMethod;
  final List<ParticipantEntry> participants;
  final void Function(bool) onSplitToggled;
  final void Function(String) onSplitMethodChanged;
  final VoidCallback onAddParticipant;
  final void Function(int) onRemoveParticipant;
  final VoidCallback onAmountChanged;
  final bool isSlipPerson;
  final void Function(bool) onSlipPersonToggled;
  final List<int> remainderAllocations;
  final void Function(int, int) onRemainderToggle;

  const ExpenseForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.amountController,
    required this.creditCardNameController,
    required this.paymentMethod,
    required this.selectedDate,
    required this.selectedCategoryId,
    required this.isEditing,
    required this.onDateSelected,
    required this.onPaymentMethodChanged,
    required this.onCategoryChanged,
    required this.onSave,
    this.isSplit = false,
    this.splitMethod = 'equal',
    this.participants = const [],
    required this.onSplitToggled,
    required this.onSplitMethodChanged,
    required this.onAddParticipant,
    required this.onRemoveParticipant,
    required this.onAmountChanged,
    this.isSlipPerson = true,
    required this.onSlipPersonToggled,
    this.remainderAllocations = const [],
    required this.onRemainderToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(categoryProvider);
    final categories = categoryState.categories;
    final currency = ref.watch(currencyProvider);
    final payerName = ref.watch(payerNameProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final amount = double.tryParse(amountController.text) ?? 0;
    final totalCents = amount > 0 ? (amount * 100).round() : 0;
    final count = participants.length;
    final remainder = count > 0 && amount > 0 ? totalCents % count : 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
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
                    color: colorScheme.onSurface,
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
              onChanged: (_) => onAmountChanged(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppStrings.enterAmount;
                }
                final amt = double.tryParse(value);
                if (amt == null || amt <= 0) {
                  return AppStrings.enterAmount;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash')),
                ButtonSegment(value: 'credit_card', label: Text('Credit Card')),
              ],
              selected: {paymentMethod},
              onSelectionChanged: (selected) {
                onPaymentMethodChanged(selected.first);
              },
            ),
            if (paymentMethod == 'credit_card') ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: creditCardNameController,
                decoration: const InputDecoration(
                  labelText: 'Card Name',
                  prefixIcon: Icon(Icons.credit_card_outlined),
                ),
                validator: (value) {
                  if (paymentMethod == 'credit_card' && (value == null || value.trim().isEmpty)) {
                    return 'Please enter card name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: onDateSelected,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: colorScheme.primary,
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CategorySelector(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onCategoryChanged: onCategoryChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: const Text('Split this expense'),
              subtitle: Text(isSplit ? 'Participants will share the cost' : ''),
              value: isSplit,
              onChanged: onSplitToggled,
              contentPadding: EdgeInsets.zero,
            ),
            if (isSplit) ...[
              RadioGroup<String>(
                groupValue: splitMethod,
                onChanged: (value) {
                  if (value != null) onSplitMethodChanged(value);
                },
                child: const Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Equal'),
                        value: 'equal',
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Custom'),
                        value: 'custom',
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Feature 3: Slip Person Toggle (default ON) ──
              SwitchListTile(
                title: Text(payerName.isNotEmpty ? '$payerName paid this expense' : 'I paid this expense'),
                subtitle: Text(payerName.isNotEmpty ? '$payerName paid the full amount and will collect from others' : 'I paid the full amount and will collect from others'),
                value: isSlipPerson,
                onChanged: onSlipPersonToggled,
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  isSlipPerson ? Icons.person_outline : Icons.people_outline,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // ── Feature 2: Remainder Distribution UI ──
              if (splitMethod == 'equal' && remainder > 0) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: colorScheme.secondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Distribute $remainder extra amount unit${remainder > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Base share: ${currency.symbol}${((totalCents ~/ count) / 100).toStringAsFixed(2)} each',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...participants.asMap().entries.map((entry) {
                        final index = entry.key;
                        final p = entry.value;
                        final hasExtra = remainderAllocations.length > index && remainderAllocations[index] > 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.nameController.text.isNotEmpty
                                      ? p.nameController.text
                                      : 'Person ${index + 1}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              IconButton(
                                iconSize: 18,
                                icon: Icon(Icons.remove_circle_outline, size: 16,
                                    color: hasExtra ? colorScheme.error : colorScheme.outline),
                                onPressed: remainderAllocations.length > index && remainderAllocations[index] > 0
                                    ? () => onRemainderToggle(index, -1)
                                    : null,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasExtra ? colorScheme.tertiaryContainer : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${remainderAllocations.length > index ? remainderAllocations[index] : 0}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: hasExtra ? colorScheme.onTertiaryContainer : colorScheme.outline,
                                  ),
                                ),
                              ),
                              IconButton(
                                iconSize: 18,
                                icon: Icon(Icons.add_circle_outline, size: 16,
                                    color: remainderAllocations.length > index && remainderAllocations[index] < remainder
                                        ? colorScheme.primary
                                        : colorScheme.outline),
                                onPressed: remainderAllocations.length > index && remainderAllocations[index] < remainder
                                    ? () => onRemainderToggle(index, 1)
                                    : null,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              // ── Participant list ──
              ...participants.asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: participant.nameController,
                          decoration: InputDecoration(
                            labelText: isSlipPerson && index == 0
                                ? '${payerName.isNotEmpty ? payerName : 'You'} (paid upfront)'
                                : 'Person ${index + 1}',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) { /**/ },
                        ),
                      ),
                      if (splitMethod == 'custom') ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: participant.amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixText: '\u20b9 ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                      if (splitMethod == 'equal')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\u20b9${participant.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              if (participant.remainderCents > 0)
                                Text(
                                  '(incl. +${participant.remainderCents})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => onRemoveParticipant(index),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Person'),
                onPressed: onAddParticipant,
              ),
            ],
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
      ),
    );
  }
}
