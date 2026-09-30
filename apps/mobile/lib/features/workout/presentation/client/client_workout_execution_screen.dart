import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_picker_dialog.dart';
import 'client_workout_completion_screen.dart';
import 'widgets/client_exercise_detail_sheet.dart';

class ClientWorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const ClientWorkoutExecutionScreen({
    super.key,
    required this.workoutRepository,
  });

  @override
  State<ClientWorkoutExecutionScreen> createState() => _ClientWorkoutExecutionScreenState();
}

class _ClientWorkoutExecutionScreenState extends State<ClientWorkoutExecutionScreen> {
  int _currentExerciseIndex = 0;

  // Elapsed workout timer
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // Rest Timer State
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _totalRestSeconds = 90;
  bool _isRestActive = false;
  bool _isRestPaused = false;
  String _restExerciseName = '';
  bool _showNextSetBanner = false;

  // Controllers for set input
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};
  final Map<String, TextEditingController> _rirControllers = {};
  final Map<String, TextEditingController> _rpeControllers = {};
  final TextEditingController _clientNoteController = TextEditingController();

  final List<PersonalRecord> _achievedPRs = [];

  @override
  void initState() {
    super.initState();
    _startElapsedTimer();
    _initControllersForExercise(_currentExerciseIndex);
    widget.workoutRepository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    _disposeControllers();
    _clientNoteController.dispose();
    widget.workoutRepository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _disposeControllers() {
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    for (final c in _repsControllers.values) {
      c.dispose();
    }
    for (final c in _rirControllers.values) {
      c.dispose();
    }
    for (final c in _rpeControllers.values) {
      c.dispose();
    }
    _weightControllers.clear();
    _repsControllers.clear();
    _rirControllers.clear();
    _rpeControllers.clear();
  }

  void _initControllersForExercise(int exIndex) {
    _disposeControllers();
    final session = widget.workoutRepository.activeSession;
    if (exIndex >= session.exercises.length) return;
    final exercise = session.exercises[exIndex];

    _clientNoteController.text = exercise.clientNote ?? '';

    for (int i = 0; i < exercise.sets.length; i++) {
      final s = exercise.sets[i];
      final weightVal = s.actualWeight ?? (s.targetWeight > 0 ? s.targetWeight : (s.previousWeight ?? 0.0));
      final repsVal = s.actualReps ?? s.targetRepsMin;
      final rirVal = s.actualRir ?? s.targetRir ?? 2;
      final rpeVal = s.actualRpe ?? s.targetRpe ?? 8.0;

      _weightControllers[s.id] = TextEditingController(
        text: weightVal > 0 ? (weightVal % 1 == 0 ? weightVal.toInt().toString() : weightVal.toStringAsFixed(1)) : '0',
      );
      _repsControllers[s.id] = TextEditingController(text: repsVal.toString());
      _rirControllers[s.id] = TextEditingController(text: rirVal.toString());
      _rpeControllers[s.id] = TextEditingController(text: rpeVal.toString());
    }
  }

  // Steppers for Weight
  void _adjustWeight(String setId, double delta) {
    final ctrl = _weightControllers[setId];
    if (ctrl == null) return;
    final current = double.tryParse(ctrl.text.trim()) ?? 0.0;
    final updated = (current + delta).clamp(0.0, 999.0);
    setState(() {
      ctrl.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(1);
    });
  }

  // Steppers for Reps
  void _adjustReps(String setId, int delta) {
    final ctrl = _repsControllers[setId];
    if (ctrl == null) return;
    final current = int.tryParse(ctrl.text.trim()) ?? 10;
    final updated = (current + delta).clamp(1, 999);
    setState(() {
      ctrl.text = updated.toString();
    });
  }

  // RIR selection
  void _selectRir(String setId, int rir) {
    final ctrl = _rirControllers[setId];
    if (ctrl == null) return;
    setState(() {
      ctrl.text = rir.toString();
    });
  }

  // Load Previous Performance into current sets
  void _applyPreviousPerformance(WorkoutExercise exercise) {
    final previousSets = widget.workoutRepository.getPreviousPerformance(exercise.exerciseId);
    if (previousSets == null || previousSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No previous performance history found for this exercise.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
      return;
    }

    setState(() {
      for (int i = 0; i < exercise.sets.length; i++) {
        final s = exercise.sets[i];
        if (i < previousSets.length) {
          final prev = previousSets[i];
          final weight = prev.actualWeight ?? prev.targetWeight;
          final reps = prev.actualReps ?? prev.targetRepsMin;
          final rir = prev.actualRir ?? prev.targetRir ?? 2;

          _weightControllers[s.id]?.text = weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);
          _repsControllers[s.id]?.text = reps.toString();
          _rirControllers[s.id]?.text = rir.toString();
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Loaded previous weight & reps into sets'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Automatic Rest Timer
  void _startRestTimer(int seconds, String exerciseName) {
    _restTimer?.cancel();
    final initialSec = seconds > 0 ? seconds : 90;
    setState(() {
      _totalRestSeconds = initialSec;
      _restSecondsRemaining = initialSec;
      _isRestActive = true;
      _isRestPaused = false;
      _restExerciseName = exerciseName;
      _showNextSetBanner = false;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_isRestPaused) return;

      if (_restSecondsRemaining > 1) {
        setState(() => _restSecondsRemaining--);
        // Section 7: Final 5 seconds subtle cue
        if (_restSecondsRemaining <= 5) {
          HapticFeedback.selectionClick();
        }
      } else {
        _stopRestTimer();
        HapticFeedback.mediumImpact();
        setState(() => _showNextSetBanner = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('REST COMPLETE! Ready for next set on $exerciseName'),
              ],
            ),
            backgroundColor: AppColors.primaryRed,
            duration: const Duration(seconds: 3),
          ),
        );
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

  void _togglePauseRest() {
    HapticFeedback.lightImpact();
    setState(() {
      _isRestPaused = !_isRestPaused;
    });
  }

  void _adjustRestTimer(int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      _restSecondsRemaining = (_restSecondsRemaining + delta).clamp(0, 600);
      if (_restSecondsRemaining > _totalRestSeconds) {
        _totalRestSeconds = _restSecondsRemaining;
      }
    });
  }

  void _handleCompleteSet(int setIndex) {
    // Section 6 & 26: subtle satisfying haptic feedback on completing set
    HapticFeedback.mediumImpact();

    final session = widget.workoutRepository.activeSession;
    final exercise = session.exercises[_currentExerciseIndex];
    final s = exercise.sets[setIndex];

    final weight = double.tryParse(_weightControllers[s.id]?.text.trim() ?? '') ?? s.targetWeight;
    final reps = int.tryParse(_repsControllers[s.id]?.text.trim() ?? '') ?? s.targetRepsMin;
    final rir = int.tryParse(_rirControllers[s.id]?.text.trim() ?? '') ?? s.targetRir;
    final rpe = double.tryParse(_rpeControllers[s.id]?.text.trim() ?? '') ?? s.targetRpe;

    widget.workoutRepository.updateSetActual(
      exerciseIndex: _currentExerciseIndex,
      setIndex: setIndex,
      weight: weight,
      reps: reps,
      rir: rir,
      rpe: rpe,
    );

    final pr = widget.workoutRepository.completeSet(
      exerciseIndex: _currentExerciseIndex,
      setIndex: setIndex,
    );

    if (pr != null) {
      _achievedPRs.add(pr);
      _showPRCelebrationDialog(pr);
    }

    // Advanced Training Method: Superset Flow
    if (exercise.isSuperset) {
      final supersetGroup = exercise.supersetGroupName;
      // Find partner exercise in this superset
      final partnerIndices = <int>[];
      for (int i = 0; i < session.exercises.length; i++) {
        if (session.exercises[i].isSuperset && session.exercises[i].supersetGroupName == supersetGroup) {
          partnerIndices.add(i);
        }
      }

      final currentPosInGroup = partnerIndices.indexOf(_currentExerciseIndex);
      final isLastInSupersetRound = currentPosInGroup == partnerIndices.length - 1;

      if (!isLastInSupersetRound && partnerIndices.isNotEmpty) {
        // Guide to next exercise in superset without resting
        final nextExIndex = partnerIndices[currentPosInGroup + 1];
        final nextEx = session.exercises[nextExIndex];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SUPERSET: Transition to ${nextEx.exerciseName} now!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryRed,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _currentExerciseIndex = nextExIndex;
          _initControllersForExercise(nextExIndex);
        });
        return;
      }
    }

    // Automatically trigger rest timer from prescription
    _startRestTimer(exercise.restSeconds, exercise.exerciseName);
  }

  void _showPRCelebrationDialog(PersonalRecord pr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.gold, width: 2)),
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: AppColors.gold, size: 28),
            SizedBox(width: 10),
            Text(
              'NEW PR ACHIEVED!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pr.exerciseName,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Text(
                    pr.type.name.toUpperCase(),
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    pr.formattedValue,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Verified against historical athlete tonnage. Keep crushing your limits!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CONTINUE WORKOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Non-destructive Exercise Swap (Section 17 & 18)
  Future<void> _openSwapExerciseDialog(WorkoutExercise exercise) async {
    final permissions = widget.workoutRepository.activeSession.permissions;
    if (!permissions.allowExerciseSwap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise swapping is locked by trainer for this prescribed plan.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selected = await ExercisePickerDialog.show(
      context,
      initialCategory: exercise.category.isNotEmpty
          ? exercise.category
          : (exercise.primaryMusclesDisplay.isNotEmpty ? exercise.primaryMusclesDisplay : null),
      excludedExerciseId: exercise.exerciseId,
    );

    if (selected != null && mounted) {
      final success = widget.workoutRepository.swapExercise(_currentExerciseIndex, selected.id);
      if (success) {
        setState(() {
          _initControllersForExercise(_currentExerciseIndex);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Swapped "${exercise.exerciseName}" with "${selected.name}" for today\'s session.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // Request Exercise Change to Admin (Section 19)
  void _openRequestChangeDialog(WorkoutExercise exercise) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Request Exercise Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notify your trainer regarding "${exercise.exerciseName}". They will review your feedback and update your program.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. "Shoulder discomfort on flat bench press, would prefer incline dumbbell press."',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              widget.workoutRepository.submitChangeRequest(
                clientId: AuthService().currentUserId,
                clientName: AuthService().currentUserName,
                sessionId: widget.workoutRepository.activeSession.id,
                sessionTitle: widget.workoutRepository.activeSession.title,
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.exerciseName,
                reason: reason,
              );

              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Change request submitted to your trainer for review.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _skipExerciseDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Skip / Modify Exercise', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Equipment unavailable or need to skip? Enter a reason to notify your gym admin without changing the permanent program.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Machine busy, shoulder discomfort...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              widget.workoutRepository.skipExercise(_currentExerciseIndex, reason: reasonController.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exercise marked as skipped'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            child: const Text('Skip Exercise', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showExerciseInfo(WorkoutExercise exercise) {
    final repoExercise = ExerciseRepository().getExerciseById(exercise.exerciseId);
    ClientExerciseDetailSheet.show(
      context,
      workoutExercise: exercise,
      catalogExercise: repoExercise,
      workoutRepository: widget.workoutRepository,
      actionButtonLabel: 'START SET',
      onPrimaryAction: () {
        // Dismissed back into set logging
      },
    );
  }

  void _onFinishWorkout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => ClientWorkoutCompletionScreen(
          workoutRepository: widget.workoutRepository,
          durationSeconds: _elapsedSeconds,
          achievedPRs: _achievedPRs,
        ),
      ),
    );
  }

  String _formatSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.workoutRepository.activeSession;
    if (_currentExerciseIndex >= session.exercises.length) {
      _currentExerciseIndex = 0;
    }
    final exercise = session.exercises[_currentExerciseIndex];
    final previousSets = widget.workoutRepository.getPreviousPerformance(exercise.exerciseId);

    // Calculate Workout Progress (Section 21)
    final totalExercises = session.exercises.length;
    final completedExercises = session.exercises.where((e) => e.isAllSetsCompleted).length;
    final totalSets = session.exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length);
    final completedSets = session.exercises.fold<int>(
      0,
      (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length,
    );
    final setsRemaining = totalSets - completedSets;
    final progressPercent = totalSets > 0 ? (completedSets / totalSets) : 0.0;

    // Total volume logged so far
    double totalVolume = 0.0;
    for (final ex in session.exercises) {
      for (final s in ex.sets) {
        if (s.isCompleted) {
          final w = s.actualWeight ?? s.targetWeight;
          final r = s.actualReps ?? s.targetRepsMin;
          totalVolume += (w * r);
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 14),
            ),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 12, color: AppColors.primaryRed),
                const SizedBox(width: 4),
                Text(
                  _formatSeconds(_elapsedSeconds),
                  style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Ex ${_currentExerciseIndex + 1}/$totalExercises',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: AlphaXPressable(
              onTap: _onFinishWorkout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'FINISH',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            children: [
              // WORKOUT PROGRESS HEADER (Section 21)
              _buildProgressHeader(
                completedExercises: completedExercises,
                totalExercises: totalExercises,
                completedSets: completedSets,
                totalSets: totalSets,
                setsRemaining: setsRemaining,
                progressPercent: progressPercent,
                totalVolume: totalVolume,
              ),

              const SizedBox(height: 14),

              // SUPERSET GUIDANCE BANNER (Section 10)
              if (exercise.isSuperset) _buildSupersetGuidanceBanner(exercise),

              // EXERCISE NAVIGATION TABS (Horizontal scrolling)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: session.exercises.length,
                  itemBuilder: (ctx, idx) {
                    final ex = session.exercises[idx];
                    final isSelected = idx == _currentExerciseIndex;
                    final isCompleted = ex.isAllSetsCompleted;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentExerciseIndex = idx;
                          _initControllersForExercise(idx);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryRed
                              : isCompleted
                                  ? AppColors.success.withOpacity(0.18)
                                  : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryRed
                                : isCompleted
                                    ? AppColors.success
                                    : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ex.isSuperset) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.3) : AppColors.primaryRed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ex.supersetTag ?? 'SS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            if (isCompleted) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check, size: 12, color: AppColors.success),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // ACTIVE EXERCISE MAIN CARD
              _buildActiveExerciseCard(exercise, previousSets),

              const SizedBox(height: 20),

              // SETS TRACKING HEADER
              Row(
                children: [
                  const Text(
                    'SETS TRACKING',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${exercise.sets.where((s) => s.isCompleted).length} / ${exercise.sets.length} Completed',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // SECTION 8: PREVIOUS REFERENCE BAR (SET | PREVIOUS REFERENCE | TODAY)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 48,
                      child: Text(
                        'SET',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PREVIOUS (REFERENCE)',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      'TODAY ACTUAL',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // SETS INPUT CARDS WITH GYM-FRIENDLY STEPPERS (Section 15, 31)
              ...exercise.sets.asMap().entries.map((entry) {
                final setIndex = entry.key;
                final s = entry.value;
                return _buildGymSetCard(exercise, setIndex, s);
              }),

              const SizedBox(height: 16),

              // PREVIOUS / NEXT EXERCISE NAVIGATION
              Row(
                children: [
                  if (_currentExerciseIndex > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentExerciseIndex--;
                            _initControllersForExercise(_currentExerciseIndex);
                          });
                        },
                        icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
                        label: const Text('Previous Exercise', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (_currentExerciseIndex > 0 && _currentExerciseIndex < session.exercises.length - 1)
                    const SizedBox(width: 12),
                  if (_currentExerciseIndex < session.exercises.length - 1)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentExerciseIndex++;
                            _initControllersForExercise(_currentExerciseIndex);
                          });
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.textPrimary),
                        label: const Text('Next Exercise', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // FLOATING REST TIMER MODAL IF ACTIVE (Section 16)
          if (_isRestActive)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildRestTimerCard(),
            ),

          // NEXT SET READY BANNER
          if (_showNextSetBanner && !_isRestActive)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'REST FINISHED • READY FOR NEXT SET',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _showNextSetBanner = false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- SECTION 21: WORKOUT PROGRESS HEADER ---
  Widget _buildProgressHeader({
    required int completedExercises,
    required int totalExercises,
    required int completedSets,
    required int totalSets,
    required int setsRemaining,
    required double progressPercent,
    required double totalVolume,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WORKOUT PROGRESS',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '$completedExercises / $totalExercises Exercises (${(progressPercent * 100).toInt()}%)',
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricPill(Icons.done_all, '$completedSets Sets Done', AppColors.success),
              _metricPill(Icons.pending_actions, '$setsRemaining Remaining', AppColors.textSecondary),
              _metricPill(Icons.fitness_center, '${totalVolume.toInt()} kg Vol', AppColors.primaryRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  // --- SECTION 10: SUPERSET GUIDANCE BANNER ---
  Widget _buildSupersetGuidanceBanner(WorkoutExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              exercise.supersetTag ?? 'SUPERSET',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exercise.supersetGroupName ?? "SUPERSET"} FLOW',
                  style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 11),
                ),
                const Text(
                  'Complete round with minimal rest between paired exercises.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ACTIVE EXERCISE MAIN CARD ---
  Widget _buildActiveExerciseCard(WorkoutExercise exercise, List<ExerciseSet>? previousSets) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exercise.isSuperset ? AppColors.accentRed.withOpacity(0.5) : AppColors.border,
          width: exercise.isSuperset ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showExerciseInfo(exercise),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise.exerciseName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: AppColors.primaryRed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${exercise.primaryMusclesDisplay}${exercise.secondaryMusclesDisplay.isNotEmpty ? " • ${exercise.secondaryMusclesDisplay}" : ""}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                tooltip: 'Exercise Biomechanics & Guide',
                onPressed: () => _showExerciseInfo(exercise),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                tooltip: 'Exercise Options',
                onPressed: _skipExerciseDialog,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ACTIONS ROW: SWAP EXERCISE (Section 17) & REQUEST CHANGE (Section 19)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 16, color: AppColors.textPrimary),
                  label: const Text('SWAP EXERCISE', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => _openSwapExerciseDialog(exercise),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.handyman_outlined, size: 16, color: AppColors.textSecondary),
                  label: const Text('REQUEST CHANGE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => _openRequestChangeDialog(exercise),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),

          // TARGET TODAY VS LAST TIME (Section 14)
          Row(
            children: [
              // Target Today
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARGET TODAY',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exercise.sets.length} × ${exercise.sets.firstOrNull?.targetRepsDisplay ?? "8"} @ ${exercise.sets.firstOrNull?.targetWeight != null ? "${exercise.sets.firstOrNull!.targetWeight} kg" : "BW"}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Rest ${exercise.restSeconds}s | RIR ${exercise.sets.firstOrNull?.targetRir ?? 2}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      if (exercise.sets.firstOrNull?.tempo != null && exercise.sets.firstOrNull!.tempo.isNotEmpty)
                        Text(
                          'Tempo: ${exercise.sets.firstOrNull!.tempo}',
                          style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Last Time Performance & "USE PREVIOUS" Button
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LAST TIME',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _applyPreviousPerformance(exercise),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'USE PREVIOUS',
                                style: TextStyle(
                                  color: AppColors.primaryRed,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showExerciseInfo(exercise),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              previousSets != null && previousSets.isNotEmpty
                                  ? previousSets.map((s) => s.actualDisplay).join(', ')
                                  : 'No previous performance',
                              style: TextStyle(
                                color: previousSets != null && previousSets.isNotEmpty
                                    ? AppColors.primaryRed
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              previousSets != null && previousSets.isNotEmpty
                                  ? 'Tap to view full history'
                                  : 'First logged session for this exercise',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // TRAINER NOTE (Section 20: Read-only Coach Instruction)
          if (exercise.trainerNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glowRed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRAINER INSTRUCTION',
                          style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exercise.trainerNote,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // CLIENT PERSONAL NOTE (Section 20: My Note)
          const SizedBox(height: 12),
          TextField(
            controller: _clientNoteController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add personal note... (e.g. "Felt strong today")',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check, size: 18, color: AppColors.primaryRed),
                onPressed: () {
                  widget.workoutRepository.updateExerciseNote(
                    _currentExerciseIndex,
                    _clientNoteController.text.trim(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Personal note saved'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 15 & 31: GYM SET CARD WITH TOUCH STEPPERS ---
  Widget _buildGymSetCard(WorkoutExercise exercise, int setIndex, ExerciseSet s) {
    final weightCtrl = _weightControllers[s.id];
    final repsCtrl = _repsControllers[s.id];
    final rirCtrl = _rirControllers[s.id];
    final currentRir = int.tryParse(rirCtrl?.text ?? '') ?? s.targetRir ?? 2;

    // Resolve previous performance reference for this set index
    final previousSets = widget.workoutRepository.getPreviousPerformance(exercise.exerciseId);
    String? previousSetDisplay;
    if (previousSets != null && setIndex < previousSets.length) {
      final prev = previousSets[setIndex];
      final w = prev.actualWeight ?? prev.targetWeight;
      final wStr = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
      final r = prev.actualReps ?? prev.targetRepsMin;
      previousSetDisplay = '$wStr kg × $r';
    } else if (s.previousDisplay != '—') {
      previousSetDisplay = s.previousDisplay;
    }

    if (s.isCompleted) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F15), // Deep athletic dark emerald surface
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.success.withOpacity(0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'SET ${s.setNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.setType.displayName.toUpperCase(),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Target: ${s.targetRepsDisplay} reps @ ${s.targetWeight > 0 ? "${s.targetWeight} kg" : "BW"}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (previousSetDisplay != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• Prev: $previousSetDisplay',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
                const Spacer(),
                AlphaXPressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.workoutRepository.updateSetActual(
                      exerciseIndex: _currentExerciseIndex,
                      setIndex: setIndex,
                      weight: double.tryParse(weightCtrl?.text ?? '') ?? s.targetWeight,
                      reps: int.tryParse(repsCtrl?.text ?? '') ?? s.targetRepsMin,
                      rir: currentRir,
                    );
                    widget.workoutRepository.uncompleteSet(
                      exerciseIndex: _currentExerciseIndex,
                      setIndex: setIndex,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LOGGED: ${s.actualWeight?.toInt() ?? s.targetWeight} kg × ${s.actualReps ?? s.targetRepsMin} reps (RIR ${s.actualRir ?? s.targetRir ?? 2})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Set Title & Status Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SET ${s.setNumber}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.setType.displayName.toUpperCase(),
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              // PREVIOUS PERFORMANCE (Reference only)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PREV: ',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      previousSetDisplay ?? '—',
                      style: TextStyle(
                        color: previousSetDisplay != null ? AppColors.primaryRed : AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'Target: ${s.targetRepsDisplay} reps @ ${s.targetWeight > 0 ? "${s.targetWeight} kg" : "BW"}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // STEPPER: WEIGHT
          Row(
            children: [
              const SizedBox(
                width: 64,
                child: Text(
                  'Weight',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              _stepperButton('-2.5', () => _adjustWeight(s.id, -2.5)),
              const SizedBox(width: 4),
              _stepperButton('-', () => _adjustWeight(s.id, -1.0)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  decoration: InputDecoration(
                    suffixText: 'kg',
                    suffixStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _stepperButton('+', () => _adjustWeight(s.id, 1.0)),
              const SizedBox(width: 4),
              _stepperButton('+2.5', () => _adjustWeight(s.id, 2.5)),
            ],
          ),

          const SizedBox(height: 10),

          // STEPPER: REPS
          Row(
            children: [
              const SizedBox(
                width: 64,
                child: Text(
                  'Reps',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              _stepperButton('-5', () => _adjustReps(s.id, -5)),
              const SizedBox(width: 4),
              _stepperButton('-', () => _adjustReps(s.id, -1)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  decoration: InputDecoration(
                    suffixText: 'reps',
                    suffixStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _stepperButton('+', () => _adjustReps(s.id, 1)),
              const SizedBox(width: 4),
              _stepperButton('+5', () => _adjustReps(s.id, 5)),
            ],
          ),

          const SizedBox(height: 12),

          // RIR SELECTOR CHIPS
          Row(
            children: [
              const SizedBox(
                width: 64,
                child: Text(
                  'RIR',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Row(
                  children: [0, 1, 2, 3, 4].map((rirVal) {
                    final isSelected = currentRir == rirVal;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AlphaXPressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _selectRir(s.id, rirVal);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryRed : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryRed : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                rirVal == 4 ? '4+' : '$rirVal',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // LARGE PRIMARY "✓ COMPLETE SET" BUTTON WITH MICRO-INTERACTION (Section 6, 15, 31)
          AlphaXPressable(
            onTap: () => _handleCompleteSet(setIndex),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    '✓ COMPLETE SET ${s.setNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(String label, VoidCallback onTap) {
    return AlphaXPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  // --- SECTION 16: REST TIMER CARD (ENHANCED HUD) ---
  Widget _buildRestTimerCard() {
    final progress = _totalRestSeconds > 0
        ? (_restSecondsRemaining / _totalRestSeconds).clamp(0.0, 1.0)
        : 0.0;
    final isFinalFive = _restSecondsRemaining <= 5 && _restSecondsRemaining > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFinalFive ? AppColors.primaryRed : AppColors.primaryRed.withOpacity(0.6),
          width: isFinalFive ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFinalFive ? AppColors.primaryRed.withOpacity(0.25) : Colors.black87,
            blurRadius: isFinalFive ? 24 : 20,
            spreadRadius: isFinalFive ? 3 : 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Countdown Progress HUD
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFinalFive ? AppColors.primaryRed : AppColors.accentRed,
                  ),
                ),
                Icon(
                  isFinalFive ? Icons.alarm_on : Icons.timer,
                  color: isFinalFive ? AppColors.primaryRed : Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _restExerciseName.isNotEmpty ? 'REST • $_restExerciseName'.toUpperCase() : 'REST TIMER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatSeconds(_restSecondsRemaining),
                      style: TextStyle(
                        color: isFinalFive ? AppColors.primaryRed : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (_isRestPaused)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PAUSED', style: TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Timer Quick Buttons with AlphaXPressable
          AlphaXPressable(
            onTap: _togglePauseRest,
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                _isRestPaused ? Icons.play_arrow : Icons.pause,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          AlphaXPressable(
            onTap: () => _adjustRestTimer(15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('+15s', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
          AlphaXPressable(
            onTap: () => _adjustRestTimer(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('+30s', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
          AlphaXPressable(
            onTap: () {
              HapticFeedback.lightImpact();
              _stopRestTimer();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
              ),
              child: const Text('Skip', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
