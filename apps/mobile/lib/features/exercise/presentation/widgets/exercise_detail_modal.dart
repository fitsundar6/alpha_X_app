import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';

class ExerciseDetailModal extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleArchive;

  const ExerciseDetailModal({
    super.key,
    required this.exercise,
    this.onEdit,
    this.onDuplicate,
    this.onToggleArchive,
  });

  static void show(
    BuildContext context,
    Exercise exercise, {
    VoidCallback? onEdit,
    VoidCallback? onDuplicate,
    VoidCallback? onToggleArchive,
  }) {
    final colors = ClientThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ExerciseDetailModal(
          exercise: exercise,
          onEdit: onEdit,
          onDuplicate: onDuplicate,
          onToggleArchive: onToggleArchive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final alternatives = ExerciseRepository().getAlternatives(exercise.id);

    double? dragStartX;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (dragStartX != null && dragStartX! <= 60.0 && (details.primaryVelocity ?? 0) > 150) {
          Navigator.of(context).pop();
        }
        dragStartX = null;
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: exercise.isActive
                                  ? AppColors.primaryRed.withOpacity(0.18)
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.category.toUpperCase(),
                              style: TextStyle(
                                color: exercise.isActive
                                    ? AppColors.primaryRed
                                    : AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.difficulty.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!exercise.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exercise.displayName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Quick Spec Grid
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _specRow('Equipment', exercise.equipment, Icons.fitness_center),
                      const Divider(color: AppColors.border, height: 16),
                      _specRow('Movement', exercise.movementPattern, Icons.accessibility_new),
                      const Divider(color: AppColors.border, height: 16),
                      _specRow('Type', exercise.exerciseType, Icons.bolt),
                      const Divider(color: AppColors.border, height: 16),
                      _specRow('Primary Muscles', exercise.primaryMusclesDisplay, Icons.adjust),
                      if (exercise.secondaryMuscles.isNotEmpty) ...[
                        const Divider(color: AppColors.border, height: 16),
                        _specRow('Secondary Muscles', exercise.secondaryMusclesDisplay, Icons.blur_circular),
                      ],
                    ],
                  ),
                ),

                if (exercise.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('BIOMECHANICS & OVERVIEW'),
                  const SizedBox(height: 8),
                  Text(
                    exercise.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],

                if (exercise.defaultTrainerNote.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('DEFAULT TRAINER NOTE'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryRed.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primaryRed,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exercise.defaultTrainerNote,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Setup Instructions
                if (exercise.setupInstructions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('SETUP INSTRUCTIONS'),
                  const SizedBox(height: 10),
                  ...exercise.setupInstructions.asMap().entries.map(
                        (e) => _instructionStep(e.key + 1, e.value),
                      ),
                ],

                // Execution Steps
                if (exercise.executionSteps.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('EXECUTION STEPS'),
                  const SizedBox(height: 10),
                  ...exercise.executionSteps.asMap().entries.map(
                        (e) => _instructionStep(e.key + 1, e.value),
                      ),
                ],

                // Coaching Cues
                if (exercise.coachingCues.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('COACHING CUES'),
                  const SizedBox(height: 10),
                  ...exercise.coachingCues.map(
                    (cue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primaryRed,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cue,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Common Mistakes
                if (exercise.commonMistakes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('COMMON MISTAKES TO AVOID'),
                  const SizedBox(height: 10),
                  ...exercise.commonMistakes.map(
                    (mistake) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mistake,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Approved Alternatives
                if (alternatives.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('APPROVED BIOMECHANICAL ALTERNATIVES'),
                  const SizedBox(height: 10),
                  ...alternatives.map(
                    (alt) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.primaryRed,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alt.displayName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${alt.equipment} • ${alt.category}',
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Tags
                if (exercise.tags.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('TAGS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: exercise.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '#$t',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    if (onDuplicate != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onDuplicate!();
                          },
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('Duplicate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (onDuplicate != null) const SizedBox(width: 8),
                    if (onToggleArchive != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onToggleArchive!();
                          },
                          icon: Icon(
                            exercise.isActive
                                ? Icons.archive_outlined
                                : Icons.unarchive_outlined,
                            size: 16,
                            color: exercise.isActive
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          label: Text(
                            exercise.isActive ? 'Archive' : 'Restore',
                            style: TextStyle(
                              color: exercise.isActive
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: exercise.isActive
                                  ? AppColors.warning.withOpacity(0.5)
                                  : AppColors.success.withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onEdit!();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _specRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryRed, size: 16),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _instructionStep(int stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
