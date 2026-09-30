import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/macro_enums.dart';

/// Clean selectable cards for nutrition goals with educational descriptions
class GoalSelector extends StatelessWidget {
  final NutritionGoal selectedGoal;
  final ValueChanged<NutritionGoal> onSelected;

  const GoalSelector({
    super.key,
    required this.selectedGoal,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: NutritionGoal.values.map((goal) {
        final isSelected = goal == selectedGoal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => onSelected(goal),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primaryRed : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primaryRed : AppColors.textTertiary,
                        width: 2,
                      ),
                      color: isSelected ? AppColors.primaryRed : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              goal.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _GoalBadge(goal: goal),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          goal.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  final NutritionGoal goal;

  const _GoalBadge({required this.goal});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;

    switch (goal) {
      case NutritionGoal.weightLoss:
        text = '−15%';
        color = AppColors.warning;
        break;
      case NutritionGoal.fatLoss:
        text = '−18%';
        color = AppColors.primaryRed;
        break;
      case NutritionGoal.maintenance:
        text = '0%';
        color = AppColors.info;
        break;
      case NutritionGoal.leanBulk:
        text = '+8%';
        color = AppColors.success;
        break;
      case NutritionGoal.weightGain:
        text = '+12%';
        color = AppColors.gold;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
