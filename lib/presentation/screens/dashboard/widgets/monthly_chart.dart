import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as utils;
import '../../../providers/expense_provider.dart';
import '../../../providers/balance_provider.dart';
import '../../../providers/currency_provider.dart';

class MonthlyChart extends ConsumerWidget {
  final DateTime month;

  const MonthlyChart({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);
    final balance = ref.watch(balanceProvider);
    final totalSalary = balance.currentMonth.salary;
    // Accounting date + counted amount, so the bars sum to the month total
    // shown on the balance card rather than contradicting it.
    final expenseNotifier = ref.read(expensesProvider.notifier);
    final expenses = expenseNotifier.getAccountingExpensesByMonth(month);
    final groupedByDay = <int, double>{};

    for (final expense in expenses) {
      final day = expenseNotifier.getAccountingDate(expense)!.day;
      groupedByDay[day] =
          (groupedByDay[day] ?? 0) + expenseNotifier.getCountedAmount(expense);
    }

    final daysInMonth = utils.DateUtils.endOfMonth(month).day;
    final maxDailyExpense = groupedByDay.values.isEmpty ? 0.0 : groupedByDay.values.reduce((a, b) => a > b ? a : b);
    final maxY = [maxDailyExpense * 1.2, totalSalary * 1.1].reduce((a, b) => a > b ? a : b).clamp(100, double.infinity).toDouble();

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              utils.DateUtils.formatMonthYear(month),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = group.x.toInt() + 1;
                        final amount = groupedByDay[day] ?? 0;
                        return BarTooltipItem(
                          'Day $day\n${CurrencyFormatter.format(amount, currency)}',
                          TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt() + 1;
                          if (day % 5 == 0 || day == 1) {
                            return Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 20,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            '${currency.symbol}${value.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: totalSalary > 0
                        ? [
                            HorizontalLine(
                              y: (totalSalary / daysInMonth).toDouble(),
                              color: colorScheme.tertiary.withValues(alpha: 0.6),
                              strokeWidth: 1.5,
                              dashArray: [6, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                style: TextStyle(
                                  color: colorScheme.tertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                labelResolver: (_) => 'Daily budget: ${currency.symbol}${(totalSalary / daysInMonth).toStringAsFixed(0)}',
                              ),
                            ),
                          ]
                        : [],
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(daysInMonth, (index) {
                    final amount = groupedByDay[index + 1] ?? 0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: amount,
                          color: amount > 0
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.3),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
