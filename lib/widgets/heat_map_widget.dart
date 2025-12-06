import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/models/performance_metric.dart';

class HeatMapWidget extends StatelessWidget {
  final List<TimeOfDayPerformance> timeOfDayData;

  const HeatMapWidget({super.key, required this.timeOfDayData});

  @override
  Widget build(BuildContext context) {
    if (timeOfDayData.isEmpty ||
        timeOfDayData.every((d) => d.totalGames == 0)) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(20),
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
            'No time-of-day data available',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Find max value for normalization
    final maxScore = timeOfDayData
        .map((d) => d.averageScore)
        .reduce((a, b) => a > b ? a : b);

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
            'Time-of-Day Performance',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Darker = Better Performance',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          // 24-hour grid (4 rows x 6 columns)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: 24,
            itemBuilder: (context, index) {
              final data = timeOfDayData[index];
              final intensity = maxScore > 0
                  ? (data.averageScore / maxScore)
                  : 0.0;
              final hasData = data.totalGames > 0;

              return Container(
                decoration: BoxDecoration(
                  color: hasData
                      ? Color.lerp(
                          const Color(0xFF1a1a2e),
                          const Color(0xFF00D9FF),
                          intensity,
                        )?.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: hasData && intensity > 0.5
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF00D9FF,
                            ).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index.toString().padLeft(2, '0')}:00',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasData
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    if (hasData) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.averageScore.toStringAsFixed(0),
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
