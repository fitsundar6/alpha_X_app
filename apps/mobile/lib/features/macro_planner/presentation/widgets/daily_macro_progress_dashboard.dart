import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/alpha_x_progress.dart';
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
                fontFamily: 'Poppins',
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
                    ? AppColors.danger.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: summary.isCaloriesOver ? AppColors.danger : AppColors.primary,
                ),
              ),
              child: Text(
                summary.remainingCaloriesStatus,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: summary.isCaloriesOver ? AppColors.danger : AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // --- ATHLETIC PREMIUM: HERO MACRO RINGS & CALORIE BAR CARD ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Calorie Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CALORIE TARGET',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${summary.consumedCalories.round()}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ ${summary.targetCalories.round()} kcal',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: summary.isCaloriesOver
                          ? AppColors.danger.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: summary.isCaloriesOver ? AppColors.danger : AppColors.primary.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '${summary.caloriePercentage}% COMPLETE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: summary.isCaloriesOver ? AppColors.danger : AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Animated Calorie Linear Bar with Electric Lime Accent
              AlphaXLinearProgress(
                progress: summary.calorieProgress,
                height: 8,
                progressColor: summary.isCaloriesOver ? AppColors.danger : AppColors.primary,
                trackColor: AppColors.surfaceElevated,
              ),

              const SizedBox(height: 18),
              Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),

              // 3 MACRO RINGS ROW (Protein, Carbs, Fat)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Protein Ring
                  _buildMacroRingItem(
                    label: 'PROTEIN',
                    consumed: summary.consumedProtein,
                    target: summary.targetProtein,
                    progress: summary.proteinProgress,
                    percentage: summary.proteinPercentage,
                    color: AppColors.primary,
                    unit: 'g',
                  ),
                  Container(height: 60, width: 1, color: AppColors.border),
                  // Carbs Ring
                  _buildMacroRingItem(
                    label: 'CARBS',
                    consumed: summary.consumedCarbs,
                    target: summary.targetCarbs,
                    progress: summary.carbProgress,
                    percentage: summary.carbPercentage,
                    color: AppColors.secondary,
                    unit: 'g',
                  ),
                  Container(height: 60, width: 1, color: AppColors.border),
                  // Fat Ring
                  _buildMacroRingItem(
                    label: 'FAT',
                    consumed: summary.consumedFat,
                    target: summary.targetFat,
                    progress: summary.fatProgress,
                    percentage: summary.fatPercentage,
                    color: AppColors.warning,
                    unit: 'g',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

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
          accentColor: AppColors.primary,
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
          accentColor: AppColors.primary,
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
          accentColor: AppColors.secondary,
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
          accentColor: AppColors.warning,
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

  Widget _buildMacroRingItem({
    required String label,
    required double consumed,
    required double target,
    required double progress,
    required int percentage,
    required Color color,
    required String unit,
  }) {
    return Column(
      children: [
        AlphaXArcProgress(
          progress: progress,
          size: 64,
          strokeWidth: 6,
          progressColor: color,
          trackColor: AppColors.surfaceElevated,
          centerChild: Text(
            '$percentage%',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${consumed.round()} / ${target.round()}$unit',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver ? AppColors.danger.withOpacity(0.6) : AppColors.border,
          width: isOver ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isOver ? AppColors.danger.withOpacity(0.14) : Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isOver
                      ? AppColors.danger.withOpacity(0.18)
                      : accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isOver ? AppColors.danger : accentColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  isOver ? '$percentage% • EXCEEDED' : '$percentage% complete',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isOver ? AppColors.danger : accentColor,
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
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '/ ${target.round()} $unit',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Status Pill: "X g remaining" or "X g over target" (Section 10: Never negative)
              Flexible(
                child: Text(
                  isOver
                      ? '${FoodLogEntry.formatMacro(over)} $unit over target'
                      : '${FoodLogEntry.formatMacro(remaining)} $unit remaining',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isOver ? AppColors.danger : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Smooth Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, _) {
                return LinearProgressIndicator(
                  value: animValue,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOver ? AppColors.danger : accentColor,
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
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
              ),
              Text(
                'Consumed: ${consumed.round()} $unit',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
