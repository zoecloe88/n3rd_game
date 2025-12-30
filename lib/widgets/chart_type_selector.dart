import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/services/haptic_service.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';

/// Chart type options
enum ChartType {
  line,
  bar,
  area,
}

/// Widget for selecting chart type (Line, Bar, Area)
class ChartTypeSelector extends StatelessWidget {

  const ChartTypeSelector({
    super.key,
    required this.selectedChartType,
    required this.onChanged,
  });
  final String selectedChartType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final localizations = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.secondaryText.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChartTypeButton(
            context,
            type: ChartType.line,
            icon: Icons.show_chart,
            label: localizations?.lineChart ?? 'Line',
            isSelected: selectedChartType == 'line',
          ),
          _buildChartTypeButton(
            context,
            type: ChartType.bar,
            icon: Icons.bar_chart,
            label: localizations?.barChart ?? 'Bar',
            isSelected: selectedChartType == 'bar',
          ),
          _buildChartTypeButton(
            context,
            type: ChartType.area,
            icon: Icons.area_chart,
            label: localizations?.areaChart ?? 'Area',
            isSelected: selectedChartType == 'area',
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeButton(
    BuildContext context, {
    required ChartType type,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    final colors = AppColors.of(context);
    final typeString = type.name;

    return Semantics(
      label: '$label chart type',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticService().lightImpact();
            onChanged(typeString);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? colors.info : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : colors.secondaryText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : colors.secondaryText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
