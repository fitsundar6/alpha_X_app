import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/daily_macro_summary.dart';
import '../../domain/models/food_log_entry.dart';
import 'animated_macro_counter.dart';

/// Premium macro progress dashboard & cards for Alpha X Gym athletes
/// Accurately displays Target, Consumed, Remaining, % complete, and Over-target status
class DailyMacroProgressDashboard extends StatelessWidget {
  final DailyMacroSummary summary;

  const DailyMacroProgressDashboard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TODAY\'S NUTRITION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: summary.isCaloriesOver
                    ? AppColors.primaryRed.withOpacity(0.15)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: summary.isCaloriesOver ? AppColors.primaryRed : AppColors.border,
                ),
              ),
              child: Text(
                summary.remainingCaloriesStatus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: summary.isCaloriesOver ? AppColors.primaryRed : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 1. CALORIES PROGRESS CARD
        MacroProgressCard(
          title: 'CALORIES',
          iconEmoji: '🔥',
          consumed: summary.consumedCalories,
          target: summary.targetCalories,
          remaining: summary.safeRemainingCalories,
          over: summary.overCalories,
          isOver: summary.isCaloriesOver,
          progress: summary.calorieProgress,
          percentage: summary.caloriePercentage,
          unit: 'kcal',
          accentColor: AppColors.primaryRed,
          decimals: 0,
        ),

        const SizedBox(height: 12),

        // 2. PROTEIN PROGRESS CARD
        MacroProgressCard(
          title: 'PROTEIN',
          iconEmoji: '💪',
          consumed: summary.consumedProtein,
          target: summary.targetProtein,
          remaining: summary.safeRemainingProtein,
          over: summary.overProtein,
          isOver: summary.isProteinOver,
          progress: summary.proteinProgress,
          percentage: summary.proteinPercentage,
          unit: 'g',
          accentColor: AppColors.accentRed,
          decimals: 0,
        ),

        const SizedBox(height: 12),

        // 3. CARBS PROGRESS CARD
        MacroProgressCard(
          title: 'CARBS',
          iconEmoji: '🍚',
          consumed: summary.consumedCarbs,
          target: summary.targetCarbs,
          remaining: summary.safeRemainingCarbs,
          over: summary.overCarbs,
          isOver: summary.isCarbsOver,
          progress: summary.carbProgress,
          percentage: summary.carbPercentage,
          unit: 'g',
          accentColor: AppColors.info,
          decimals: 0,
        ),

        const SizedBox(height: 12),

        // 4. FAT PROGRESS CARD
        MacroProgressCard(
          title: 'FAT',
          iconEmoji: '🥑',
          consumed: summary.consumedFat,
          target: summary.targetFat,
          remaining: summary.safeRemainingFat,
          over: summary.overFat,
          isOver: summary.isFatOver,
          progress: summary.fatProgress,
          percentage: summary.fatPercentage,
          unit: 'g',
          accentColor: AppColors.gold,
          decimals: 0,
        ),

        // 5. FIBER (Optional tracking row)
        if (summary.targetFiber > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                const Text(
                  'Daily Fiber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${FoodLogEntry.formatMacro(summary.consumedFiber)} / ${summary.targetFiber.toInt()} g',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  summary.remainingFiber <= 0
                      ? '✓ Target met'
                      : '${FoodLogEntry.formatMacro(summary.safeRemainingFiber)} g remaining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: summary.remainingFiber <= 0 ? AppColors.success : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Standalone Macro Progress Card with smooth progress bar and over-target handling
class MacroProgressCard extends StatelessWidget {
  final String title;
  final String iconEmoji;
  final double consumed;
  final double target;
  final double remaining;
  final double over;
  final bool isOver;
  final double progress;
  final int percentage;
  final String unit;
  final Color accentColor;
  final int decimals;

  const MacroProgressCard({
    super.key,
    required this.title,
    required this.iconEmoji,
    required this.consumed,
    required this.target,
    required this.remaining,
    required this.over,
    required this.isOver,
    required this.progress,
    required this.percentage,
    required this.unit,
    required this.accentColor,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver ? AppColors.primaryRed.withOpacity(0.6) : AppColors.border,
          width: isOver ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOver ? AppColors.primaryRed.withOpacity(0.12) : Colors.black.withOpacity(0.2),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Macro Title + % Complete Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(iconEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOver
                      ? AppColors.primaryRed.withOpacity(0.2)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOver ? AppColors.primaryRed : AppColors.border,
                  ),
                ),
                child: Text(
                  isOver ? '$percentage% • EXCEEDED' : '$percentage% complete',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isOver ? AppColors.primaryRed : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Row: Consumed / Target with Animated Counter
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedMacroCounter(
                value: consumed,
                decimals: decimals,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${target.round()} $unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Status Pill: "X g remaining" or "X g over target" (Section 10: Never negative)
              Text(
                isOver
                    ? '${FoodLogEntry.formatMacro(over)} $unit over target'
                    : '${FoodLogEntry.formatMacro(remaining)} $unit remaining',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isOver ? AppColors.primaryRed : AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Smooth Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, _) {
                return LinearProgressIndicator(
                  value: animValue,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOver ? AppColors.primaryRed : accentColor,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Target vs Consumed Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${target.round()} $unit',
                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
              ),
              Text(
                'Consumed: ${consumed.round()} $unit',
                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
