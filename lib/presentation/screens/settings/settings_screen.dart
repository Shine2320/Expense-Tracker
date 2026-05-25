import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/currency_config.dart';
import '../../providers/theme_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/common/income_dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isSystemDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = themeMode == ThemeMode.system ? isSystemDark : themeMode == ThemeMode.dark;
    final categories = ref.watch(categoryProvider).categories;
    final balanceState = ref.watch(balanceProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildSection(
            context,
            'Income',
            [
              _buildIncomeTile(
                context,
                'Monthly Salary',
                '${currency.symbol}${balanceState.currentMonth.salary.toStringAsFixed(2)}',
                Icons.account_balance_wallet_outlined,
                () => showEditSalaryDialog(context, ref),
              ),
              _buildIncomeTile(
                context,
                'Previous Month Balance',
                '${currency.symbol}${balanceState.currentMonth.carryOver.toStringAsFixed(2)}',
                Icons.history_outlined,
                () => showEditCarryOverDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            context,
            'Categories',
            [
              ...categories.map((category) => _buildCategoryTile(category, ref)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                ),
                title: const Text('Add Custom Category'),
                onTap: () => _showAddCategoryDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            context,
            'Currency',
            [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(currency.icon, color: Theme.of(context).colorScheme.primary),
                ),
                title: const Text('Currency'),
                subtitle: Text('${currency.name} (${currency.symbol})'),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showCurrencyPicker(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            context,
            'Appearance',
            [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Theme'),
                subtitle: Text(
                  isDark ? AppStrings.darkMode : AppStrings.lightMode,
                ),
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_outlined),
      onTap: onTap,
    );
  }

  Widget _buildCategoryTile(dynamic category, WidgetRef ref) {
    return ListTile(
      leading: Text(
        category.emoji,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(category.name),
      subtitle: category.isCustom ? const Text('Custom') : const Text('Default'),
      trailing: category.isCustom
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditCategoryDialog(context, ref, category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    ref.read(categoryProvider.notifier).deleteCategory(category.id);
                  },
                ),
              ],
            )
          : null,
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, dynamic category) {
    final nameController = TextEditingController(text: category.name);
    final emojiController = TextEditingController(text: category.emoji);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.categoryName,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: AppStrings.categoryEmoji,
                hintText: 'Type or paste any emoji here',
                prefixIcon: Icon(Icons.emoji_emotions_outlined),
              ),
              maxLength: 2,
              maxLines: 1,
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emoji = emojiController.text.trim().isNotEmpty
                  ? emojiController.text.trim()
                  : category.emoji;
              if (name.isNotEmpty) {
                ref.read(categoryProvider.notifier).updateCategory(
                      category.id,
                      name: name,
                      emoji: emoji,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: CurrencyConfig.supported.map((currency) {
              return ListTile(
                leading: Icon(currency.icon),
                title: Text('${currency.name} (${currency.symbol})'),
                subtitle: Text(currency.code),
                trailing: ref.read(currencyProvider).code == currency.code
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  ref.read(currencyProvider.notifier).setCurrency(currency.code);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '\ud83d\udce6');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.addCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.categoryName,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: AppStrings.categoryEmoji,
                hintText: 'Type or paste any emoji here',
                prefixIcon: Icon(Icons.emoji_emotions_outlined),
              ),
              maxLength: 2,
              maxLines: 1,
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emoji = emojiController.text.trim().isNotEmpty
                  ? emojiController.text.trim()
                  : '\ud83d\udce6';
              if (name.isNotEmpty) {
                ref
                    .read(categoryProvider.notifier)
                    .addCustomCategory(name, emoji);
                Navigator.pop(context);
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }
}
