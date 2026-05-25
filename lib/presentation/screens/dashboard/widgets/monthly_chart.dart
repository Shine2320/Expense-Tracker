import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart' as utils;
import '../../../providers/expense_provider.dart';
import '../../../providers/currency_provider.dart';

class MonthlyChart extends ConsumerWidget {
  final DateTime month;

  const MonthlyChart({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);
    final expenses = ref.read(expensesProvider.notifier).getExpensesByMonth(month);
    final groupedByDay = <int, double>{};

    for (final expense in expenses) {
      final day = expense.date.day;
      groupedByDay[day] = (groupedByDay[day] ?? 0) + expense.amount;
    }

    final daysInMonth = utils.DateUtils.endOfMonth(month).day;
    final maxAmount = groupedByDay.values.isEmpty
        ? 100.0
        : groupedByDay.values.reduce((a, b) => a > b ? a : b);

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
                  maxY: maxAmount * 1.2,
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
                    horizontalInterval: maxAmount / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.outlineVariant.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
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
                              : colorScheme.outlineVariant.withOpacity(0.3),
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
