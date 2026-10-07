import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';

/// Clean stats overview displaying only assigned exercise parameters:
/// Target Muscle, Sets, Target Reps, Rest.
class ExerciseStats extends StatelessWidget {
  final String? targetMuscle;
  final int? setsCount;
  final String? targetReps;
  final int? restSeconds;

  const ExerciseStats({
    super.key,
    this.targetMuscle,
    this.setsCount,
    this.targetReps,
    this.restSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> statItems = [];

    // 1. Target Muscle
    if (targetMuscle != null && targetMuscle!.trim().isNotEmpty) {
      statItems.add(
        _buildStatCard(
          label: 'TARGET MUSCLE',
          value: targetMuscle!.trim(),
          icon: Icons.adjust_rounded,
        ),
      );
    }

    // 2. Sets
    if (setsCount != null) {
      statItems.add(
        _buildStatCard(
          label: 'SETS',
          value: '$setsCount',
          icon: Icons.repeat_rounded,
        ),
      );
    }

    // 3. Target Reps
    if (targetReps != null && targetReps!.trim().isNotEmpty) {
      statItems.add(
        _buildStatCard(
          label: 'TARGET REPS',
          value: targetReps!.trim(),
          icon: Icons.fitness_center_rounded,
        ),
      );
    }

    // 4. Rest
    if (restSeconds != null && restSeconds! > 0) {
      statItems.add(
        _buildStatCard(
          label: 'REST',
          value: '$restSeconds sec',
          icon: Icons.timer_outlined,
        ),
      );
    }

    if (statItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // If there are 4 items, render 2x2 grid or horizontal row
        final isNarrow = constraints.maxWidth < 360;
        final columns = isNarrow ? 2 : (statItems.length <= 4 ? statItems.length : 2);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: statItems.length <= 4 && !isNarrow
              ? Row(
                  children: statItems.asMap().entries.map((entry) {
                    final isLast = entry.key == statItems.length - 1;
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(child: entry.value),
                          if (!isLast)
                            Container(
                              height: 36,
                              width: 1,
                              color: AppColors.border,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isNarrow ? 2.2 : 2.6,
                  children: statItems,
                ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primaryRed),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
