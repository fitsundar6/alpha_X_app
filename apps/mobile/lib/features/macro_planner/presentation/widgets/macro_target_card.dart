import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/macro_result.dart';

/// Premium dark-card widget displaying a primary macronutrient or calorie target
class MacroTargetCard extends StatelessWidget {
  final String label;
  final String emoji;
  final int value;
  final String unit;
  final TargetRange? range;
  final double? caloriePercent;
  final Color accentColor;
  final bool isPrimaryHighlight;

  const MacroTargetCard({
    super.key,
    required this.label,
    required this.emoji,
    required this.value,
    required this.unit,
    this.range,
    this.caloriePercent,
    this.accentColor = AppColors.primaryRed,
    this.isPrimaryHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isPrimaryHighlight ? 20.0 : 16.0),
      decoration: BoxDecoration(
        color: isPrimaryHighlight ? AppColors.surfaceElevated : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPrimaryHighlight ? accentColor.withAlpha(140) : AppColors.border,
          width: isPrimaryHighlight ? 1.5 : 1.0,
        ),
        boxShadow: isPrimaryHighlight
            ? [
                BoxShadow(
                  color: accentColor.withAlpha(35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(emoji, style: TextStyle(fontSize: isPrimaryHighlight ? 20 : 18)),
                  const SizedBox(width: 8),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: isPrimaryHighlight ? 12 : 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isPrimaryHighlight ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (caloriePercent != null && caloriePercent! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    '${caloriePercent!.toStringAsFixed(0)}% cal',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                ),
                style: isPrimaryHighlight
                    ? AppTypography.displayLarge.copyWith(color: AppColors.textPrimary)
                    : AppTypography.displayMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (range != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    'Target range: ${range!.display}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
