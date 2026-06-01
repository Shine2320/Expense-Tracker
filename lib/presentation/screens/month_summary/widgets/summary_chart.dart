import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../data/models/category_model.dart';

class SummaryChart extends StatelessWidget {
  final Map<String, double> categoryExpenses;
  final List<CategoryModel> categories;
  final VoidCallback? onTap;

  const SummaryChart({
    super.key,
    required this.categoryExpenses,
    required this.categories,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = categoryExpenses.values.fold<double>(0, (sum, e) => sum + e);
    final sections = <PieChartSectionData>[];
    final colors = _generateColors(categoryExpenses.length);

    int index = 0;
    categoryExpenses.forEach((categoryId, amount) {
      final percentage = (amount / total * 100);

      sections.add(
        PieChartSectionData(
          value: amount,
          title: '${percentage.toStringAsFixed(0)}%',
          color: colors[index % colors.length],
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      index++;
    });

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const Text(
            'Expenses by Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    // Tooltip handling can be added here
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: categoryExpenses.entries.map((entry) {
              final category = categories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => categories.firstWhere((c) => c.id == 'other'),
              );
              final idx = categoryExpenses.keys.toList().indexOf(entry.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[idx % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('${category.emoji} ${category.name}'),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: content,
            ),
    );
  }

  List<Color> _generateColors(int count) {
    return [
      const Color(0xFF6750A4),
      const Color(0xFF625B71),
      const Color(0xFF7D5260),
      const Color(0xFF4CAF50),
      const Color(0xFFFFC107),
      const Color(0xFFF44336),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFF00BCD4),
    ];
  }
}
