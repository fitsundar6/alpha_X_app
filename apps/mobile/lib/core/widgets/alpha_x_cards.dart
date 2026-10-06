import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'alpha_x_card.dart';
import 'alpha_x_progress.dart';

/// Reusable Progress Card for Workouts, Nutrition, Steps, and Goals
class AlphaXProgressCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double progress; // 0.0 to 1.0
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const AlphaXProgressCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.progress,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = accentColor ?? (isDark ? AppColors.primary : AppColors.lightPrimary);
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return AlphaXCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: secTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: primaryColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: secTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AlphaXLinearProgress(
            progress: progress,
            progressColor: primaryColor,
            height: 6,
          ),
        ],
      ),
    );
  }
}

/// Reusable Exercise Card for Workout and Exercise Library views
class AlphaXExerciseCard extends StatelessWidget {
  final String name;
  final String category;
  final String? subtitle;
  final String? targetMuscle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isCompleted;

  const AlphaXExerciseCard({
    super.key,
    required this.name,
    required this.category,
    this.subtitle,
    this.targetMuscle,
    this.trailing,
    this.onTap,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primary : AppColors.lightPrimary;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return AlphaXCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.symmetric(vertical: 6),
      borderColor: isCompleted ? primaryColor.withOpacity(0.5) : null,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCompleted
                  ? primaryColor.withOpacity(0.15)
                  : (isDark ? AppColors.secondaryCard : AppColors.lightSecondaryCard),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
              color: isCompleted ? primaryColor : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.secondaryCard : AppColors.lightSecondaryCard),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        subtitle!,
                        style: TextStyle(color: secTextColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Reusable Meal Card for Nutrition and Food Logging views
class AlphaXMealCard extends StatelessWidget {
  final String mealName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final VoidCallback? onAddTap;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AlphaXMealCard({
    super.key,
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.onAddTap,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primary : AppColors.lightPrimary;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    return AlphaXCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    mealName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$calories kcal',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (onAddTap != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      color: primaryColor,
                      onPressed: onAddTap,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroPill('Protein', '${protein.toStringAsFixed(0)}g', isDark),
              _macroPill('Carbs', '${carbs.toStringAsFixed(0)}g', isDark),
              _macroPill('Fat', '${fat.toStringAsFixed(0)}g', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
