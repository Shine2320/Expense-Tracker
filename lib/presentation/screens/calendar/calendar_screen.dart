import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart' as utils;
import '../../providers/calendar_provider.dart';
import '../../providers/expense_provider.dart';
import 'widgets/day_expense_sheet.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedDay = ref.watch(calendarProvider);
    final expenseState = ref.watch(expensesProvider);
    final expensesForMonth = expenseState.expenses
        .where((e) =>
            e.date.year == focusedDay.year && e.date.month == focusedDay.month)
        .toList();

    final daysWithExpenses = <DateTime, List<dynamic>>{};
    for (final expense in expensesForMonth) {
      final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (!daysWithExpenses.containsKey(day)) {
        daysWithExpenses[day] = [];
      }
      daysWithExpenses[day]!.add(expense);
    }

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
                _showDayExpenses(context, ref, selectedDay);
              },
              onPageChanged: (focusedDay) {
                ref.read(calendarProvider.notifier).setFocusedDay(focusedDay);
              },
              eventLoader: (day) {
                return daysWithExpenses[DateTime(day.year, day.month, day.day)] ?? [];
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
            ),
          ),
        ],
      ),
    );
  }

  void _showDayExpenses(BuildContext context, WidgetRef ref, DateTime day) {
    final expenses = ref.read(expensesProvider.notifier).getExpensesByDate(day);
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
  final Map<DateTime, List<dynamic>> daysWithExpenses;

  const _MonthSummary({
    required this.month,
    required this.daysWithExpenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double totalMonthExpenses = 0;
    for (final expenses in daysWithExpenses.values) {
      for (final expense in expenses) {
        totalMonthExpenses += expense.amount;
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Total Expenses',
                  value: CurrencyFormatter.format(totalMonthExpenses),
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryItem(
                  label: 'Days with Expenses',
                  value: '$daysWithExpenseCount',
                  color: Theme.of(context).colorScheme.primary,
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
  final Color color;

  const _SummaryItem({
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
