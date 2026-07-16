import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/money_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart' as utils;
import '../../providers/calendar_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../data/models/currency_config.dart';
import '../../../data/models/expense_model.dart';
import 'widgets/day_expense_sheet.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedDay = ref.watch(calendarProvider);
    ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);
    // Bucketed by accounting date so the calendar agrees with the balance card.
    final daysWithExpenses = ref
        .read(expensesProvider.notifier)
        .getAccountingDaysWithExpenses(focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calendar),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(AppSpacing.md),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: focusedDay,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) {
                return utils.DateUtils.isSameDay(focusedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(calendarProvider.notifier).setSelectedDay(selectedDay);
                ref.read(calendarProvider.notifier).setFocusedDay(focusedDay);
                _showDayExpenses(
                  context,
                  selectedDay,
                  daysWithExpenses[DateTime(
                        selectedDay.year,
                        selectedDay.month,
                        selectedDay.day,
                      )] ??
                      const [],
                );
              },
              onPageChanged: (focusedDay) {
                ref.read(calendarProvider.notifier).setFocusedDay(focusedDay);
              },
              eventLoader: (day) {
                return daysWithExpenses[
                        DateTime(day.year, day.month, day.day)] ??
                    [];
              },
              calendarStyle: CalendarStyle(
                markersMaxCount: 3,
                markerSize: 6,
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Expanded(
            child: _MonthSummary(
              month: focusedDay,
              daysWithExpenses: daysWithExpenses,
              currency: currency,
            ),
          ),
        ],
      ),
    );
  }

  /// Takes the already-bucketed list rather than re-querying by expense date,
  /// which would open a sheet that disagrees with the marker that was tapped.
  void _showDayExpenses(
    BuildContext context,
    DateTime day,
    List<ExpenseModel> expenses,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DayExpenseSheet(day: day, expenses: expenses),
    );
  }
}

class _MonthSummary extends ConsumerWidget {
  final DateTime month;
  final Map<DateTime, List<ExpenseModel>> daysWithExpenses;
  final CurrencyConfig currency;

  const _MonthSummary({
    required this.month,
    required this.daysWithExpenses,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseNotifier = ref.read(expensesProvider.notifier);
    double totalMonthExpenses = 0;
    for (final expenses in daysWithExpenses.values) {
      for (final expense in expenses) {
        // Counted, not gross: a split you were partly repaid for costs less.
        totalMonthExpenses += expenseNotifier.getCountedAmount(expense);
      }
    }

    final daysWithExpenseCount = daysWithExpenses.keys.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            utils.DateUtils.formatMonthYear(month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Counted this month',
                  value: CurrencyFormatter.format(totalMonthExpenses, currency),
                  container: context.money.negativeContainer,
                  onContainer: context.money.onNegativeContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryItem(
                  label: 'Days with expenses',
                  value: '$daysWithExpenseCount',
                  container:
                      Theme.of(context).colorScheme.secondaryContainer,
                  onContainer:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color container;
  final Color onContainer;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.container,
    required this.onContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: MoneyText.large(context).copyWith(color: onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
