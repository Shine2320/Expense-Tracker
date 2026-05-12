import 'package:flutter/material.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../data/models/category_model.dart';

class CategorySelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final Function(String) onCategoryChanged;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: categories.map((category) {
        final isSelected = category.id == selectedCategoryId;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.emoji),
              const SizedBox(width: AppSpacing.xs),
              Text(category.name),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onCategoryChanged(category.id);
            }
          },
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}
