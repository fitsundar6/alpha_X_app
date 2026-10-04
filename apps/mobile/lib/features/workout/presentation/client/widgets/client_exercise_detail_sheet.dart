import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'exercise_media.dart';
import 'exercise_header.dart';
import 'exercise_stats.dart';
import 'exercise_instructions.dart';
import 'trainer_note_card.dart';
import 'previous_performance_card.dart';
import 'exercise_bottom_action.dart';

/// Premium Exercise Detail modal sheet for client workout experience.
/// Follows the structured client flow:
/// Exercise Animation/Video -> Exercise Name -> Stats -> How to Perform -> Trainer Note -> Previous Performance -> Action
class ClientExerciseDetailSheet extends StatelessWidget {
  final WorkoutExercise workoutExercise;
  final Exercise? catalogExercise;
  final WorkoutRepository workoutRepository;
  final String? clientId;
  final String actionButtonLabel;
  final VoidCallback? onPrimaryAction;

  const ClientExerciseDetailSheet({
    super.key,
    required this.workoutExercise,
    this.catalogExercise,
    required this.workoutRepository,
    this.clientId,
    this.actionButtonLabel = 'START SET',
    this.onPrimaryAction,
  });

  /// Opens the premium exercise detail bottom sheet.
  static void show(
    BuildContext context, {
    required WorkoutExercise workoutExercise,
    Exercise? catalogExercise,
    required WorkoutRepository workoutRepository,
    String? clientId,
    String actionButtonLabel = 'START SET',
    VoidCallback? onPrimaryAction,
  }) {
    // If catalogExercise is not passed, resolve from ExerciseRepository
    final resolvedCatalog = catalogExercise ??
        ExerciseRepository().getExerciseById(workoutExercise.exerciseId);
    final colors = ClientThemeColors.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.90,
        maxChildSize: 0.96,
        minChildSize: 0.50,
        expand: false,
        builder: (_, scrollController) => ClientExerciseDetailSheet(
          workoutExercise: workoutExercise,
          catalogExercise: resolvedCatalog,
          workoutRepository: workoutRepository,
          clientId: clientId,
          actionButtonLabel: actionButtonLabel,
          onPrimaryAction: onPrimaryAction,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final effectiveClientId = clientId ?? AuthService().currentUserId;

    // Retrieve previous performance history using Client ID + Exercise ID
    final history = workoutRepository.getClientExerciseHistory(
      clientId: effectiveClientId,
      exerciseId: workoutExercise.exerciseId,
    );

    // Resolve actual catalog exercise strictly using exerciseId from Admin Exercise Database
    final resolvedCatalog = catalogExercise ??
        ExerciseRepository().getExerciseById(workoutExercise.exerciseId);

    // Resolve actual media & instructions from database record
    final videoUrl = resolvedCatalog?.videoUrl ?? '';
    final thumbnailUrl = resolvedCatalog?.thumbnailUrl ?? '';
    final imageUrl = resolvedCatalog?.imageUrl ?? '';
    final animationUrl = resolvedCatalog?.animationUrl ?? '';
    final setupSteps = resolvedCatalog?.setupInstructions ?? const <String>[];
    final executionSteps = resolvedCatalog?.executionSteps ?? const <String>[];
    final cues = resolvedCatalog?.coachingCues ?? const <String>[];
    final equipment = resolvedCatalog?.equipment ?? '';
    final movementPattern = resolvedCatalog?.movementPattern ?? '';

    // Trainer note: prefer workoutExercise note, then fallback to catalog default note
    final effectiveTrainerNote = workoutExercise.trainerNote.trim().isNotEmpty
        ? workoutExercise.trainerNote
        : (resolvedCatalog?.defaultTrainerNote ?? '');

    // Target Reps Display
    final targetReps = workoutExercise.sets.firstOrNull?.targetRepsDisplay ?? '';

    double? dragStartX;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isLeftEdge = dragStartX != null && dragStartX! <= 60.0 && (details.primaryVelocity ?? 0) > 150;
        final isRightEdge = dragStartX != null && dragStartX! >= (screenWidth - 60.0) && (details.primaryVelocity ?? 0) < -150;
        if (isLeftEdge || isRightEdge) {
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

            // Scrollable Content Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // 1. EXERCISE NAME (Clean, strong heading)
                  ExerciseHeader(
                    exerciseName: workoutExercise.exerciseName,
                    category: workoutExercise.category,
                    equipment: equipment,
                    supersetTag: workoutExercise.supersetTag,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 16),

                  // 2. [ ANIMATED GIF ] (Continuous exercise demonstration)
                  ExerciseMedia(
                    exerciseId: workoutExercise.exerciseId,
                    gifUrl: resolvedCatalog?.gifDemonstrationUrl ?? '',
                    videoUrl: videoUrl,
                    thumbnailUrl: thumbnailUrl,
                    imageUrl: imageUrl,
                    animationUrl: animationUrl,
                    exerciseName: workoutExercise.exerciseName,
                    category: workoutExercise.category,
                    movementPattern: movementPattern,
                  ),
                  const SizedBox(height: 16),

                  // 3. EXERCISE INFORMATION (Target Muscle, Sets, Target Reps, Rest)
                  ExerciseStats(
                    targetMuscle: workoutExercise.primaryMusclesDisplay.isNotEmpty
                        ? workoutExercise.primaryMusclesDisplay
                        : catalogExercise?.primaryMusclesDisplay,
                    setsCount: workoutExercise.sets.length,
                    targetReps: targetReps,
                    restSeconds: workoutExercise.restSeconds > 0
                        ? workoutExercise.restSeconds
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // 4. PREVIOUS PERFORMANCE (Last workout & View History)
                  PreviousPerformanceCard(
                    exerciseName: workoutExercise.exerciseName,
                    history: history,
                  ),
                  const SizedBox(height: 16),

                  // 5. TRAINER NOTE (Noticeable, non-distracting; hidden if empty)
                  if (effectiveTrainerNote.isNotEmpty) ...[
                    TrainerNoteCard(note: effectiveTrainerNote),
                    const SizedBox(height: 16),
                  ],

                  // 6. INSTRUCTIONS (Setup, execution steps, coaching cues)
                  if (setupSteps.isNotEmpty || executionSteps.isNotEmpty) ...[
                    ExerciseInstructions(
                      setupInstructions: setupSteps,
                      executionSteps: executionSteps,
                      coachingCues: cues,
                      initialExpanded: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 9. STICKY BOTTOM ACTION AREA (START SET / START WORKOUT)
            ExerciseBottomAction(
              label: actionButtonLabel,
              onPressed: () {
                Navigator.of(context).pop();
                if (onPrimaryAction != null) {
                  onPrimaryAction!();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
