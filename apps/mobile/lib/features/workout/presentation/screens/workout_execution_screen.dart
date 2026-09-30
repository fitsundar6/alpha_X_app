import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/app_typography.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const WorkoutExecutionScreen({
    super.key,
    required this.workoutRepository,
  });

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  Timer? _elapsedWorkoutTimer;
  int _workoutDurationSeconds = 42 * 60 + 18; // Started 42:18 ago

  // Rest Timer State
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isRestActive = false;
  bool _isRestPaused = false;
  String _restExerciseName = '';

  @override
  void initState() {
    super.initState();
    _startElapsedTimer();
    widget.workoutRepository.addListener(_onRepositoryUpdated);
  }

  void _onRepositoryUpdated() {
    if (mounted) setState(() {});
  }

  void _startElapsedTimer() {
    _elapsedWorkoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !widget.workoutRepository.activeSession.isCompleted) {
        setState(() => _workoutDurationSeconds++);
      }
    });
  }

  void _startRestTimer({required int seconds, required String exerciseName}) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = seconds;
      _isRestActive = true;
      _isRestPaused = false;
      _restExerciseName = exerciseName;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isRestPaused) {
        if (_restSecondsRemaining > 1) {
          setState(() => _restSecondsRemaining--);
        } else {
          _stopRestTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rest finished for $exerciseName. Next set ready!'),
              backgroundColor: AppColors.primaryRed,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isRestActive = false;
      _isRestPaused = false;
      _restSecondsRemaining = 0;
    });
  }

  void _adjustRestTime(int secondsDelta) {
    setState(() {
      _restSecondsRemaining = (_restSecondsRemaining + secondsDelta).clamp(0, 600);
    });
  }

  void _toggleRestPause() {
    setState(() {
      _isRestPaused = !_isRestPaused;
    });
  }

  String _formatSeconds(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onCompleteSet(int exIndex, int setIndex) {
    final ex = widget.workoutRepository.activeSession.exercises[exIndex];
    final set = ex.sets[setIndex];

    if (set.isCompleted) return;

    final pr = widget.workoutRepository.completeSet(
      exerciseIndex: exIndex,
      setIndex: setIndex,
    );

    // Auto-trigger Rest Timer as prescribed
    _startRestTimer(seconds: ex.restSeconds, exerciseName: ex.exerciseName);

    // If PR detected, celebrate with animated dialog
    if (pr != null) {
      _showPRDialog(pr);
    }
  }

  void _showPRDialog(PersonalRecord pr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.gold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(40),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'NEW PERSONAL RECORD!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pr.exerciseName,
                style: AppTypography.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      pr.type.badgeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pr.formattedValue,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Previous: ${pr.formattedPrevious}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('KEEP DOMINATING', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwapExerciseModal(int exIndex) {
    final currentEx = widget.workoutRepository.activeSession.exercises[exIndex];
    final alternatives = ExerciseRepository.getApprovedAlternatives(currentEx.exerciseId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SWAP EXERCISE', style: AppTypography.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select from trainer-approved biomechanical alternatives. Your target sets will be preserved.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            if (alternatives.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No approved alternatives prescribed by trainer for this movement.', style: TextStyle(color: AppColors.textTertiary)),
              )
            else
              ...alternatives.map((alt) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  title: Text(alt.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    alt.primaryMuscles.map((m) => m.displayName).join(', '),
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.workoutRepository.swapExercise(exIndex, alt.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Swapped to ${alt.name}. Targets preserved.'),
                          backgroundColor: AppColors.primaryRed,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('SWAP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  void _showPlateCalculatorModal(double defaultWeight) {
    double currentWeight = defaultWeight;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final calc = widget.workoutRepository.calculatePlates(targetWeightKg: currentWeight);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.calculate_outlined, color: AppColors.primaryRed),
                        SizedBox(width: 8),
                        Text('PLATE CALCULATOR', style: AppTypography.headlineSmall),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Olympic Bar: 20 kg • Target: ${currentWeight.toStringAsFixed(1)} kg (${calc.weightPerSide.toStringAsFixed(1)} kg / side)',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: 16),

                // Quick weight adjustment chips
                Wrap(
                  spacing: 8,
                  children: [60.0, 70.0, 72.5, 80.0, 100.0, 140.0].map((w) {
                    final isSel = currentWeight == w;
                    return ChoiceChip(
                      label: Text('${w.toInt()} kg'),
                      selected: isSel,
                      selectedColor: AppColors.primaryRed,
                      backgroundColor: AppColors.surfaceCard,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSel ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (val) {
                        setModalState(() => currentWeight = w);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Plates per side graphic display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EACH SIDE REQUIRES:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (calc.platesPerSide.isEmpty)
                        const Text('Bare barbell only (20 kg). No extra plates needed.', style: TextStyle(color: AppColors.textSecondary))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: calc.platesPerSide.entries.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryRed),
                              ),
                              child: Text(
                                '${entry.value} × ${entry.key % 1 == 0 ? entry.key.toInt() : entry.key} kg',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteSet(int exIndex, int setIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Uncompleted Set?', style: AppTypography.titleMedium),
        content: Text(
          'Remove Set ${setIndex + 1} from this workout session?',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.workoutRepository.deleteSet(exIndex, setIndex);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _finishWorkout() {
    widget.workoutRepository.completeWorkout();
    final session = widget.workoutRepository.activeSession;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.primaryRed, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: AppColors.gold, size: 54),
              const SizedBox(height: 12),
              const Text(
                'WORKOUT COMPLETE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(session.focus, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 20),

              // Summary Stats Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Duration', value: _formatSeconds(_workoutDurationSeconds)),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _SummaryRow(label: 'Exercises', value: '${session.exercises.length} movements'),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _SummaryRow(label: 'Sets Completed', value: '${session.totalCompletedSets} of ${session.totalSets} sets'),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _SummaryRow(
                      label: 'Total Volume',
                      value: '${session.totalVolume.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} kg',
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('FINISH WORKOUT', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _elapsedWorkoutTimer?.cancel();
    _restTimer?.cancel();
    widget.workoutRepository.removeListener(_onRepositoryUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.workoutRepository.activeSession;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // Header: Focus & Workout Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTIVE SESSION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.focus,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryRed, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: AppColors.primaryRed, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatSeconds(_workoutDurationSeconds),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Exercises Loop
            ...session.exercises.asMap().entries.map((entry) {
              final exIndex = entry.key;
              final ex = entry.value;
              return _buildExerciseCard(exIndex, ex);
            }),

            const SizedBox(height: 16),

            // Workout Complete Action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _finishWorkout,
                icon: const Icon(Icons.flag, size: 20),
                label: const Text('FINISH WORKOUT SESSION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),

        // Floating / Docked Rest Timer Bar
        if (_isRestActive)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildRestTimerDock(),
          ),
      ],
    );
  }

  Widget _buildExerciseCard(int exIndex, WorkoutExercise ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Superset badge if present
          if (ex.supersetTag != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.glowRed,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SUPERSET ${ex.supersetTag}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Execute paired movements back-to-back', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise Name & Action Buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.exerciseName.toUpperCase(),
                            style: AppTypography.headlineSmall.copyWith(letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('Primary: ${ex.primaryMusclesDisplay}', style: const TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('• ${ex.secondaryMusclesDisplay}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined, color: AppColors.textSecondary, size: 22),
                      tooltip: 'Plate Calculator',
                      onPressed: () => _showPlateCalculatorModal(ex.sets.isNotEmpty ? ex.sets.first.targetWeight : 70.0),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Video Demonstration Thumbnail Bar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.play_circle_fill, color: AppColors.primaryRed, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Video Demonstration: 30° Clavicular Angle & Elbow Flare',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // TRAINING NOTE INSIDE EXERCISE SCREEN
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1A12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.warning.withAlpha(120), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tips_and_updates_outlined, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text(
                            'TRAINING NOTE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.warning,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ex.trainerNote,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE8DAC2),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Exercise Prescriptions Metadata Bar
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _BadgePill(icon: Icons.speed, label: 'Tempo: ${ex.tempo}', color: AppColors.info),
                    _BadgePill(icon: Icons.timer_outlined, label: 'Rest: ${ex.restSeconds}s', color: AppColors.textSecondary),
                    _BadgePill(icon: Icons.fitness_center, label: 'RPE 8.0 • RIR 2', color: AppColors.warning),
                  ],
                ),

                const SizedBox(height: 16),

                // PREVIOUS → TARGET → ACTUAL TABLE (CORE ARCHITECTURE)
                const Text(
                  'PREVIOUS → TARGET → ACTUAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 38, child: Text('SET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary))),
                      Expanded(flex: 3, child: Text('PREVIOUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary))),
                      Expanded(flex: 3, child: Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary))),
                      Expanded(flex: 4, child: Text('ACTUAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary))),
                      SizedBox(width: 44, child: Text('ACTION', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Sets List
                ...ex.sets.asMap().entries.map((sEntry) {
                  final setIndex = sEntry.key;
                  final set = sEntry.value;
                  return _buildSetRow(exIndex, setIndex, ex, set);
                }),

                const SizedBox(height: 14),

                // Exercise Action Bar (Add Set, Swap Exercise)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => widget.workoutRepository.addSet(exIndex),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+ ADD SET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showSwapExerciseModal(exIndex),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('SWAP EXERCISE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exIndex, int setIndex, WorkoutExercise ex, ExerciseSet set) {
    final isDone = set.isCompleted;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFF142416) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone ? AppColors.success.withAlpha(120) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          // Set number & type badge (Tap to delete uncompleted set)
          SizedBox(
            width: 38,
            child: InkWell(
              onTap: isDone ? null : () => _confirmDeleteSet(exIndex, setIndex),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Text(
                    '${set.setNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDone ? AppColors.success : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      set.setType.shortTag,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PREVIOUS: e.g. 70 × 10
          Expanded(
            flex: 3,
            child: Text(
              set.previousDisplay,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),

          // TARGET: e.g. 8–12 @ 72.5
          Expanded(
            flex: 3,
            child: Text(
              '${set.targetRepsDisplay} @ ${set.targetWeight % 1 == 0 ? set.targetWeight.toInt() : set.targetWeight}',
              style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w700),
            ),
          ),

          // ACTUAL: Editable Weight x Reps
          Expanded(
            flex: 4,
            child: isDone
                ? Text(
                    '${set.actualDisplay} kg',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success),
                  )
                : Row(
                    children: [
                      // Weight Decimal Input Field
                      SizedBox(
                        width: 44,
                        height: 32,
                        child: TextFormField(
                          initialValue: (set.actualWeight ?? set.targetWeight).toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final w = double.tryParse(val);
                            if (w != null) {
                              widget.workoutRepository.updateSetActual(
                                exerciseIndex: exIndex,
                                setIndex: setIndex,
                                weight: w,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('×', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(width: 4),
                      // Reps Input Field
                      SizedBox(
                        width: 36,
                        height: 32,
                        child: TextFormField(
                          initialValue: (set.actualReps ?? set.targetRepsMin).toString(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final r = int.tryParse(val);
                            if (r != null) {
                              widget.workoutRepository.updateSetActual(
                                exerciseIndex: exIndex,
                                setIndex: setIndex,
                                reps: r,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // Action / Complete button
          SizedBox(
            width: 44,
            child: isDone
                ? const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.check_circle_outline, color: AppColors.primaryRed, size: 26),
                        tooltip: 'Complete Set',
                        onPressed: () => _onCompleteSet(exIndex, setIndex),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryRed, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom, color: AppColors.primaryRed, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'REST TIMER • ${_restExerciseName.toUpperCase()}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatSeconds(_restSecondsRemaining),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _adjustRestTime(-15),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('-15s', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _adjustRestTime(15),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('+15s', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(_isRestPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                onPressed: _toggleRestPause,
              ),
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.skip_next, color: AppColors.textSecondary),
                onPressed: _stopRestTimer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgePill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _SummaryRow({required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isHighlight ? AppColors.primaryRed : Colors.white,
          ),
        ),
      ],
    );
  }
}
