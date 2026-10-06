import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/client_theme_service.dart';
import '../../../../core/widgets/alpha_x_progress.dart';
import '../../domain/models/daily_macro_summary.dart';
import '../../domain/models/food_log_entry.dart';
import 'animated_macro_counter.dart';

/// Premium unified macro progress dashboard for Alpha X Gym athletes
/// Accurately displays Calories, Protein, Carbs, Fat, and Fiber in one compact, zero-scroll card.
class DailyMacroProgressDashboard extends StatelessWidget {
  final DailyMacroSummary summary;
  final VoidCallback? onEditTargets;
  final String? coachPlanName;
  final String? coachNotes;
  final String? goalName;
  final VoidCallback? onViewCoachPlan;

  const DailyMacroProgressDashboard({
    super.key,
    required this.summary,
    this.onEditTargets,
    this.coachPlanName,
    this.coachNotes,
    this.goalName,
    this.onViewCoachPlan,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final isCalOver = summary.isCaloriesOver;
    final calStatusText = isCalOver
        ? '${summary.overCalories.round()} kcal over'
        : '${summary.safeRemainingCalories.round()} kcal left';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCalOver ? colors.danger.withOpacity(0.5) : colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colors.isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER: Title / Coach Badge & Remaining Calories Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: coachPlanName != null && coachPlanName!.isNotEmpty
                    ? InkWell(
                        onTap: onViewCoachPlan,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.primary.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: colors.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Coach: $coachPlanName',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: colors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 12, color: colors.primary),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              goalName != null && goalName!.isNotEmpty
                                  ? "NUTRITION • ${goalName!.toUpperCase()}"
                                  : "TODAY'S NUTRITION",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: colors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCalOver
                          ? colors.danger.withOpacity(0.15)
                          : colors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isCalOver ? colors.danger : colors.primary.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      calStatusText,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCalOver ? colors.danger : colors.primary,
                      ),
                    ),
                  ),
                  if (onEditTargets != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onEditTargets,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. CALORIES MAIN PROGRESS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CALORIES',
                      style: GoogleFonts.poppins(
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${summary.consumedCalories.round()}',
                            style: GoogleFonts.poppins(
                              color: colors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ' / ${summary.targetCalories.round()} kcal',
                            style: GoogleFonts.poppins(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCalOver
                      ? colors.danger.withOpacity(0.15)
                      : colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${summary.caloriePercentage}%',
                  style: GoogleFonts.poppins(
                    color: isCalOver ? colors.danger : colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Calorie Linear Bar
          AlphaXLinearProgress(
            progress: summary.calorieProgress,
            height: 7,
            progressColor: isCalOver ? colors.danger : colors.primary,
            trackColor: colors.surfaceElevated,
          ),

          const SizedBox(height: 16),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 14),

          // 3. MACRONUTRIENTS 4-COLUMN COMPACT STATS GRID
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCompactMacroTile(
                  context: context,
                  label: 'PROTEIN',
                  dotColor: colors.primary,
                  consumed: summary.consumedProtein,
                  target: summary.targetProtein,
                  progress: summary.proteinProgress,
                  isOver: summary.isProteinOver,
                  overAmount: summary.overProtein,
                  remainingAmount: summary.safeRemainingProtein,
                  unit: 'g',
                  colors: colors,
                ),
              ),
              Container(width: 1, height: 48, color: colors.border.withOpacity(0.5)),
              Expanded(
                child: _buildCompactMacroTile(
                  context: context,
                  label: 'CARBS',
                  dotColor: colors.info,
                  consumed: summary.consumedCarbs,
                  target: summary.targetCarbs,
                  progress: summary.carbProgress,
                  isOver: summary.isCarbsOver,
                  overAmount: summary.overCarbs,
                  remainingAmount: summary.safeRemainingCarbs,
                  unit: 'g',
                  colors: colors,
                ),
              ),
              Container(width: 1, height: 48, color: colors.border.withOpacity(0.5)),
              Expanded(
                child: _buildCompactMacroTile(
                  context: context,
                  label: 'FAT',
                  dotColor: colors.warning,
                  consumed: summary.consumedFat,
                  target: summary.targetFat,
                  progress: summary.fatProgress,
                  isOver: summary.isFatOver,
                  overAmount: summary.overFat,
                  remainingAmount: summary.safeRemainingFat,
                  unit: 'g',
                  colors: colors,
                ),
              ),
              Container(width: 1, height: 48, color: colors.border.withOpacity(0.5)),
              Expanded(
                child: _buildCompactMacroTile(
                  context: context,
                  label: 'FIBER',
                  dotColor: colors.success,
                  consumed: summary.consumedFiber,
                  target: summary.targetFiber,
                  progress: summary.targetFiber > 0 ? (summary.consumedFiber / summary.targetFiber).clamp(0.0, 1.0) : 0.0,
                  isOver: false,
                  overAmount: 0.0,
                  remainingAmount: summary.safeRemainingFiber,
                  unit: 'g',
                  colors: colors,
                ),
              ),
            ],
          ),
          if (coachNotes != null && coachNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      coachNotes!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildCompactMacroTile({
    required BuildContext context,
    required String label,
    required Color dotColor,
    required double consumed,
    required double target,
    required double progress,
    required bool isOver,
    required double overAmount,
    required double remainingAmount,
    required String unit,
    required ClientThemeColors colors,
  }) {
    final subtext = isOver
        ? '${overAmount.round()}$unit over'
        : (remainingAmount <= 0 && target > 0
            ? 'Met'
            : '${remainingAmount.round()}$unit left');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${consumed.round()}/${target.round()}$unit',
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AlphaXLinearProgress(
            progress: progress,
            height: 3,
            progressColor: isOver ? colors.danger : dotColor,
            trackColor: colors.surfaceElevated,
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: GoogleFonts.poppins(
              color: isOver ? colors.danger : colors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
