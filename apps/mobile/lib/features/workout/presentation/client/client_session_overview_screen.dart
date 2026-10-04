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

  Future<void> _startWorkout(BuildContext context) async {
    final colors = ClientThemeColors.of(context);
    if (workoutRepository.hasActiveSavedSession) {
      final active = workoutRepository.activeSession;
      final isSameSession = active.id == session.id;

      if (isSameSession) {
        // Direct resume without losing any sets
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ClientWorkoutExecutionScreen(
              workoutRepository: workoutRepository,
            ),
          ),
        );
        return;
      }

      // If active session belongs to another workout, ask client whether to resume or start new
      final bool? choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.primaryRed.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.primaryRed, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Active Workout Found',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'You already have an active workout in progress: "${active.title}" with ${active.totalCompletedSets} sets logged.\n\nDo you want to resume it or discard it to start ${session.title}?',
            style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Discard & Start New', style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.primaryRed),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('RESUME PREVIOUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

      if (choice == true && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ClientWorkoutExecutionScreen(
              workoutRepository: workoutRepository,
            ),
          ),
        );
        return;
      } else if (choice == null) {
        return;
      }
      await workoutRepository.discardActiveSession();
    }

    // Starts a new workout execution record
    workoutRepository.startSession(session);

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ClientWorkoutExecutionScreen(
            workoutRepository: workoutRepository,
          ),
        ),
      );
    }
  }

  Future<void> _syncPending(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Syncing offline workouts to cloud...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    await workoutRepository.syncPendingRecordsWithBackend();

    if (context.mounted) {
      if (workoutRepository.pendingSyncCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ All offline workouts synced successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline: ${workoutRepository.pendingSyncCount} workout(s) safely preserved on device.'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    }
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

    final hasActive = workoutRepository.hasActiveSavedSession;
    final isSameActiveSession = hasActive && workoutRepository.activeSession.id == session.id;

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
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending Offline Sync Queue Banner (Basement-Safe)
          if (workoutRepository.pendingSyncCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: AlphaXPressable(
                onTap: () => _syncPending(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: AppColors.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${workoutRepository.pendingSyncCount} WORKOUT(S) SAVED OFFLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const Text(
                              'Preserved on device • Tap to sync to cloud',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SYNC',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Active Workout Resume Banner
          if (hasActive)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primaryRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primaryRed.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACTIVE WORKOUT IN PROGRESS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${workoutRepository.activeSession.title} • ${workoutRepository.activeSession.totalCompletedSets}/${workoutRepository.activeSession.totalSets} sets completed',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primaryRed,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'RESUME WORKOUT',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => ClientWorkoutExecutionScreen(
                                  workoutRepository: workoutRepository,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await workoutRepository.discardActiveSession();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Active session discarded.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text('Discard', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Hero Image Header
          AlphaXHero(
            imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1200&auto=format&fit=crop',
            tag: session.workoutType.toUpperCase(),
            title: session.title,
            subtitle: '${session.targetMuscleGroup.toUpperCase()} • ~${session.estimatedDurationMinutes} MIN',
            height: 220,
            action: AlphaXButton(
              label: isSameActiveSession ? 'RESUME WORKOUT' : 'START WORKOUT',
              icon: isSameActiveSession ? Icons.restore_rounded : Icons.play_arrow_rounded,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSameActiveSession ? Icons.restore_rounded : Icons.play_arrow, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  isSameActiveSession ? 'RESUME WORKOUT' : 'START WORKOUT',
                  style: const TextStyle(
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
