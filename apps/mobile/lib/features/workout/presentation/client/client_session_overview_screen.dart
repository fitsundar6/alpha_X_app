import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'client_workout_execution_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'widgets/client_exercise_detail_sheet.dart';

class ClientSessionOverviewScreen extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutRepository workoutRepository;

  const ClientSessionOverviewScreen({
    super.key,
    required this.session,
    required this.workoutRepository,
  });

  void _startWorkout(BuildContext context) {
    // Starts a new workout execution record
    workoutRepository.startSession(session);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ClientWorkoutExecutionScreen(
          workoutRepository: workoutRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final totalSets = session.exercises.fold(0, (acc, ex) => acc + ex.sets.length);

    // Group exercises by superset tag if applicable
    final List<Widget> exerciseWidgets = [];
    String? currentSupersetGroup;

    for (int i = 0; i < session.exercises.length; i++) {
      final ex = session.exercises[i];
      final group = ex.supersetGroupName;

      if (group != null && group != currentSupersetGroup) {
        currentSupersetGroup = group;
        exerciseWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.primaryRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    group,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Perform back-to-back, rest after superset',
                  style: TextStyle(color: colors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        );
      } else if (group == null) {
        currentSupersetGroup = null;
      }

      exerciseWidgets.add(
        AlphaXSubtleEntrance(
          delay: Duration(milliseconds: 30 * i),
          child: _buildExerciseCard(context, ex, i, colors),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          'SESSION OVERVIEW',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Image Header
          AlphaXHero(
            imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1200&auto=format&fit=crop',
            tag: session.workoutType.toUpperCase(),
            title: session.title,
            subtitle: '${session.targetMuscleGroup.toUpperCase()} • ~${session.estimatedDurationMinutes} MIN',
            height: 220,
            action: AlphaXButton(
              label: 'START WORKOUT',
              onPressed: () => _startWorkout(context),
            ),
          ),
          const SizedBox(height: 16),

          // Overview Details Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.difficulty.toUpperCase(),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.timer_outlined, size: 14, color: colors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '~${session.estimatedDurationMinutes} min',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (session.description != null && session.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: colors.border),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricItem('Exercises', '${session.exercises.length}', colors),
                    _metricItem('Total Sets', '$totalSets', colors),
                    _metricItem('Est. Duration', '${session.estimatedDurationMinutes}m', colors),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'PRESCRIBED EXERCISE ROUTINE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Structure is prescribed by gym administration. Enter actual sets during execution.',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 12),

          ...exerciseWidgets,

          const SizedBox(height: 24),

          // Primary CTA
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6,
            ),
            onPressed: () => _startWorkout(context),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'START WORKOUT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _metricItem(String label, String value, ClientThemeColors colors) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(BuildContext context, WorkoutExercise ex, int index, ClientThemeColors colors) {
    final firstSet = ex.sets.firstOrNull;
    return AlphaXPressable(
      onTap: () {
        final catalogExercise = ExerciseRepository().getExerciseById(ex.exerciseId);
        ClientExerciseDetailSheet.show(
          context,
          workoutExercise: ex,
          catalogExercise: catalogExercise,
          workoutRepository: workoutRepository,
          actionButtonLabel: 'START WORKOUT',
          onPrimaryAction: () => _startWorkout(context),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ex.isSuperset ? colors.accentRed.withOpacity(0.4) : colors.border,
          width: ex.isSuperset ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (ex.isSuperset) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: colors.primaryRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ex.supersetTag ?? 'SS',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ] else ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: colors.primaryRed, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  ex.exerciseName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ex.sets.length} × ${firstSet?.targetRepsDisplay ?? "8-12"}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (firstSet?.targetWeight != null && firstSet!.targetWeight > 0) ...[
                Icon(Icons.fitness_center, size: 12, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Target: ${firstSet.targetWeight} kg',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                Text(' • ', style: TextStyle(color: colors.textTertiary)),
              ],
              Icon(Icons.timer_outlined, size: 12, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Rest: ${ex.restSeconds}s',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              if (firstSet?.targetRir != null) ...[
                Text(' • ', style: TextStyle(color: colors.textTertiary)),
                Text(
                  'RIR: ${firstSet!.targetRir}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
          if (ex.trainerNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: colors.primaryRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin Instruction: ${ex.trainerNote}',
                      style: TextStyle(color: colors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
}
