import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/models/performance_metric.dart';

class PerformanceChartWidget extends StatelessWidget {
  final List<PerformanceMetric> metrics;
  final String title;
  final bool showScore;
  final bool showAccuracy;

  const PerformanceChartWidget({
    super.key,
    required this.metrics,
    required this.title,
    this.showScore = true,
    this.showAccuracy = false,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'No data available',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(height: 200, child: LineChart(_buildChartData())),
        ],
      ),
    );
  }

  LineChartData _buildChartData() {
    final spots = metrics.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final metric = entry.value;
      final value = showScore ? metric.score : metric.accuracy;
      return FlSpot(index, value);
    }).toList();

    final minY = spots.isEmpty
        ? 0.0
        : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.isEmpty
        ? 100.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 5,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.white.withValues(alpha: 0.1),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: metrics.length > 7
                ? (metrics.length / 7).ceilToDouble()
                : 1,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= metrics.length) return const Text('');
              final date = metrics[value.toInt()].date;
              return Text(
                '${date.month}/${date.day}',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: (maxY - minY) / 5,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      minX: 0,
      maxX: (metrics.length - 1).toDouble(),
      minY: minY < 0 ? 0 : minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: showScore
              ? const Color(0xFF00D9FF) // Cyan for score
              : const Color(0xFF00FF88), // Green for accuracy
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color:
                (showScore ? const Color(0xFF00D9FF) : const Color(0xFF00FF88))
                    .withValues(alpha: 0.1),
          ),
          shadow: Shadow(
            color:
                (showScore ? const Color(0xFF00D9FF) : const Color(0xFF00FF88))
                    .withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ),
      ],
    );
  }
}
