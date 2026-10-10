import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_picker_dialog.dart';
import 'client_workout_completion_screen.dart';
import 'widgets/client_exercise_detail_sheet.dart';
import 'services/rest_timer_sound_service.dart';

/// Premium Workout Session Execution Screen.
/// Follows reference designs (IMG_3853 & IMG_3854):
/// - Clean header with quick actions (Timer, Plate, Muscle), timer pill, finish pill, progress.
/// - Scrollable vertical list of numbered expandable exercise cards.
/// - Expanded cards with Set | Previous | Target | Kg | Reps | Completion checkmark.
/// - Immediate auto-saving of weights/reps to preserve workout progress.
/// - Auto rest timer trigger on set completion.
/// - Exercise Guide/History sheet (IMG_3855) integration.
class ClientWorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final String? sessionId;
  final WorkoutSession? session;

  const ClientWorkoutExecutionScreen({
    super.key,
    required this.workoutRepository,
    this.sessionId,
    this.session,
  });

  @override
  State<ClientWorkoutExecutionScreen> createState() => _ClientWorkoutExecutionScreenState();
}

class _ClientWorkoutExecutionScreenState extends State<ClientWorkoutExecutionScreen>
    with WidgetsBindingObserver {
  // Set of currently expanded exercise indices
  final Set<int> _expandedExerciseIndices = {0};

  // Controllers for weight & reps for each set
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};

  // Workout Elapsed Timer
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  bool _isTimerPaused = false;
  DateTime? _appPausedTime;

  // Rest Timer State
  Timer? _restTimer;
  Timer? _autoDismissRestTimer;
  int _restSecondsRemaining = 0;
  int _totalRestSeconds = 60;
  bool _isRestActive = false;
  bool _isRestPaused = false;
  bool _isRestFinished = false;
  String _restExerciseName = '';

  // PR tracker for current session
  final List<PersonalRecord> _achievedPRs = [];

  // Verification state
  bool _isAccessDenied = false;
  String _accessErrorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _verifyAndInitializeSession();
    _startElapsedTimer();
    _initAllSetControllers();
    widget.workoutRepository.addListener(_onRepoChange);

    // Restore saved elapsed seconds if resuming an active session
    widget.workoutRepository.getSavedActiveSessionDuration().then((savedDuration) {
      if (savedDuration != null && savedDuration > 0 && mounted) {
        setState(() {
          _elapsedSeconds = savedDuration;
        });
      }
    });
  }

  void _verifyAndInitializeSession() {
    final currentUserId = AuthService().currentUserId;

    // 1. If explicit session is passed, verify access
    if (widget.session != null) {
      final s = widget.session!;
      if (s.assignedClientId != null &&
          s.assignedClientId!.isNotEmpty &&
          s.assignedClientId != currentUserId) {
        _isAccessDenied = true;
        _accessErrorMessage = 'This workout is assigned to another client and cannot be accessed.';
        return;
      }
      // If active session is different from passed session, start it
      if (widget.workoutRepository.activeSession.id != s.id &&
          widget.workoutRepository.activeSession.assignedWorkoutId != s.id) {
        widget.workoutRepository.startSession(s, clientId: currentUserId);
      }
    } else if (widget.sessionId != null) {
      // 2. If sessionId is passed, verify authorization
      final authorized = widget.workoutRepository.getAuthorizedSessionsForClient(currentUserId);
      final active = widget.workoutRepository.activeSession;
      final match = (active.id == widget.sessionId || active.assignedWorkoutId == widget.sessionId)
          ? active
          : authorized.where((s) => s.id == widget.sessionId).firstOrNull;

      if (match == null) {
        _isAccessDenied = true;
        _accessErrorMessage = 'The requested workout is no longer assigned or accessible.';
        return;
      }
      if (active.id != match.id && active.assignedWorkoutId != match.id) {
        widget.workoutRepository.startSession(match, clientId: currentUserId);
      }
    } else {
      // 3. Use current active session
      final active = widget.workoutRepository.activeSession;
      if (active.assignedClientId != null &&
          active.assignedClientId!.isNotEmpty &&
          active.assignedClientId != currentUserId) {
        _isAccessDenied = true;
        _accessErrorMessage = 'This workout session belongs to another client.';
        return;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    _autoDismissRestTimer?.cancel();
    _disposeAllControllers();
    widget.workoutRepository.removeListener(_onRepoChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _appPausedTime = DateTime.now();
      widget.workoutRepository.saveActiveSessionToLocalStorage(elapsedSeconds: _elapsedSeconds);
    } else if (state == AppLifecycleState.resumed) {
      if (_appPausedTime != null) {
        final awaySeconds = DateTime.now().difference(_appPausedTime!).inSeconds;
        if (awaySeconds > 0 && !_isTimerPaused) {
          setState(() {
            _elapsedSeconds += awaySeconds;
          });
          if (_isRestActive && !_isRestPaused) {
            final remaining = _restSecondsRemaining - awaySeconds;
            if (remaining <= 0) {
              _stopRestTimer();
              HapticFeedback.heavyImpact();
            } else {
              setState(() {
                _restSecondsRemaining = remaining;
              });
            }
          }
        }
        _appPausedTime = null;
        widget.workoutRepository.saveActiveSessionToLocalStorage(elapsedSeconds: _elapsedSeconds);
      }
    }
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isTimerPaused) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _togglePauseElapsedTimer() {
    setState(() {
      _isTimerPaused = !_isTimerPaused;
    });
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isTimerPaused ? 'Workout timer paused' : 'Workout timer resumed'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  void _disposeAllControllers() {
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    for (final c in _repsControllers.values) {
      c.dispose();
    }
    _weightControllers.clear();
    _repsControllers.clear();
  }

  void _initAllSetControllers() {
    final session = widget.workoutRepository.activeSession;
    for (int exIdx = 0; exIdx < session.exercises.length; exIdx++) {
      final exercise = session.exercises[exIdx];
      for (int setIdx = 0; setIdx < exercise.sets.length; setIdx++) {
        final s = exercise.sets[setIdx];
        final key = s.id;

        if (!_weightControllers.containsKey(key)) {
          final String weightText;
          if (s.isCompleted && s.actualWeight != null && s.actualWeight! > 0) {
            final w = s.actualWeight!;
            weightText = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
          } else {
            weightText = '';
          }
          _weightControllers[key] = TextEditingController(text: weightText);
        }

        if (!_repsControllers.containsKey(key)) {
          final String repsText;
          if (s.isCompleted && s.actualReps != null && s.actualReps! > 0) {
            repsText = s.actualReps!.toString();
          } else {
            repsText = '';
          }
          _repsControllers[key] = TextEditingController(text: repsText);
        }
      }
    }
  }

  // --- Automatic Weight & Reps Carry-Forward Suggestion Engine ---
  ({double? weight, int? reps})? _getSuggestionForSet({
    required int exerciseIndex,
    required int setIndex,
  }) {
    if (setIndex <= 0) return null;
    final session = widget.workoutRepository.activeSession;
    if (exerciseIndex >= session.exercises.length) return null;
    final exercise = session.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return null;

    final targetSet = exercise.sets[setIndex];
    if (targetSet.isCompleted) return null;

    // Look at previous set in the same exercise
    final prevSet = exercise.sets[setIndex - 1];

    // 1. Check if user entered values into previous set's controllers
    final enteredWeightStr = _weightControllers[prevSet.id]?.text.trim() ?? '';
    final enteredRepsStr = _repsControllers[prevSet.id]?.text.trim() ?? '';
    final enteredWeight = double.tryParse(enteredWeightStr);
    final enteredReps = int.tryParse(enteredRepsStr);

    double? candidateWeight = (enteredWeight != null && enteredWeight > 0) ? enteredWeight : null;
    int? candidateReps = (enteredReps != null && enteredReps > 0) ? enteredReps : null;

    // 2. If no entered text, check if prevSet was completed with recorded values
    if (candidateWeight == null && prevSet.isCompleted && prevSet.actualWeight != null && prevSet.actualWeight! > 0) {
      candidateWeight = prevSet.actualWeight;
    }
    if (candidateReps == null && prevSet.isCompleted && prevSet.actualReps != null && prevSet.actualReps! > 0) {
      candidateReps = prevSet.actualReps;
    }

    if (candidateWeight != null || candidateReps != null) {
      return (weight: candidateWeight, reps: candidateReps);
    }
    return null;
  }

  // --- Set Logging & Persistence ---
  void _onSetInputChanged({
    required int exerciseIndex,
    required int setIndex,
  }) {
    final session = widget.workoutRepository.activeSession;
    if (exerciseIndex >= session.exercises.length) return;
    final exercise = session.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return;

    final s = exercise.sets[setIndex];
    final weightStr = _weightControllers[s.id]?.text.trim() ?? '';
    final repsStr = _repsControllers[s.id]?.text.trim() ?? '';

    final weight = double.tryParse(weightStr);
    final reps = int.tryParse(repsStr);

    widget.workoutRepository.updateSetActual(
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      weight: weight,
      reps: reps,
    );

    // Update UI immediately so next incomplete set shows placeholder suggestions in real time
    setState(() {});
  }

  void _toggleCompleteSet({
    required int exerciseIndex,
    required int setIndex,
  }) {
    final session = widget.workoutRepository.activeSession;
    if (exerciseIndex >= session.exercises.length) return;
    final exercise = session.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return;

    final s = exercise.sets[setIndex];
    HapticFeedback.mediumImpact();

    if (s.isCompleted) {
      // Undo set completion immediately
      widget.workoutRepository.uncompleteSet(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
      );
      setState(() {});
    } else {
      // Complete set immediately
      final weightStr = _weightControllers[s.id]?.text.trim() ?? '';
      final repsStr = _repsControllers[s.id]?.text.trim() ?? '';

      final suggestion = _getSuggestionForSet(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
      );

      // Preserve entered values; otherwise automatically use carry-forward suggestion; fallback to target
      final double weight;
      if (weightStr.isNotEmpty && double.tryParse(weightStr) != null && double.tryParse(weightStr)! >= 0) {
        weight = double.parse(weightStr);
      } else if (suggestion?.weight != null && suggestion!.weight! > 0) {
        weight = suggestion.weight!;
      } else {
        weight = s.targetWeight > 0 ? s.targetWeight : 0.0;
      }

      final int reps;
      if (repsStr.isNotEmpty && int.tryParse(repsStr) != null && int.tryParse(repsStr)! > 0) {
        reps = int.parse(repsStr);
      } else if (suggestion?.reps != null && suggestion!.reps! > 0) {
        reps = suggestion.reps!;
      } else {
        reps = s.targetRepsMin > 0 ? s.targetRepsMin : 10;
      }

      // Update controller text immediately so UI shows actual applied values
      if (weightStr == '0') {
        _weightControllers[s.id]?.text = '0';
      } else if (weight > 0) {
        _weightControllers[s.id]?.text = weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);
      }
      if (reps > 0) {
        _repsControllers[s.id]?.text = reps.toString();
      }

      widget.workoutRepository.updateSetActual(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
        weight: weight,
        reps: reps,
      );

      final pr = widget.workoutRepository.completeSet(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
      );

      if (pr != null) {
        _achievedPRs.add(pr);
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NEW PERSONAL RECORD: ${pr.displayName}!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Automatically trigger rest timer
      final restDuration = exercise.restSeconds > 0 ? exercise.restSeconds : 60;
      _startRestTimer(restDuration, exercise.exerciseName);

      setState(() {});
    }
  }

  // --- Rest Timer ---
  void _startRestTimer(int seconds, String exerciseName) {
    _restTimer?.cancel();
    final initial = seconds > 0 ? seconds : 60;
    setState(() {
      _totalRestSeconds = initial;
      _restSecondsRemaining = initial;
      _isRestActive = true;
      _isRestPaused = false;
      _isRestFinished = false;
      _restExerciseName = exerciseName;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_isRestPaused) return;

      if (_restSecondsRemaining > 1) {
        final next = _restSecondsRemaining - 1;
        setState(() => _restSecondsRemaining = next);

        // When the final 5 seconds begin, play short attention beep for each second (5, 4, 3, 2, 1)
        if (next >= 1 && next <= 5) {
          RestTimerSoundService.playCountdownBeep(next);
        }
      } else {
        // At 0, play clear completion sound/alert
        _restTimer?.cancel();
        RestTimerSoundService.playCompletionSound();
        setState(() {
          _restSecondsRemaining = 0;
          _isRestFinished = true;
        });

        // Automatically dismiss rest finished banner after 4 seconds if not dismissed manually
        _autoDismissRestTimer?.cancel();
        _autoDismissRestTimer = Timer(const Duration(seconds: 4), () {
          if (mounted && _isRestFinished) {
            _stopRestTimer();
          }
        });
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _autoDismissRestTimer?.cancel();
    setState(() {
      _isRestActive = false;
      _isRestPaused = false;
      _isRestFinished = false;
      _restSecondsRemaining = 0;
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

  String _formatSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}';
  }

  // --- Add Set to Exercise ---
  void _handleAddSet(int exerciseIndex) {
    HapticFeedback.lightImpact();
    widget.workoutRepository.addSet(exerciseIndex);
    _initAllSetControllers();
    setState(() {});
  }

  // --- Swap Exercise ---
  Future<void> _handleSwapExercise(int exerciseIndex) async {
    final session = widget.workoutRepository.activeSession;
    if (exerciseIndex >= session.exercises.length) return;
    final exercise = session.exercises[exerciseIndex];

    final selected = await ExercisePickerDialog.show(
      context,
      initialCategory: exercise.category.isNotEmpty ? exercise.category : null,
      excludedExerciseId: exercise.exerciseId,
    );

    if (selected != null && mounted) {
      final success = widget.workoutRepository.swapExercise(exerciseIndex, selected.id);
      if (success) {
        _initAllSetControllers();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Swapped to "${selected.name}" for today\'s session.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // --- Add Exercise to Workout ---
  Future<void> _handleAddExercise() async {
    final selected = await ExercisePickerDialog.show(
      context,
    );

    if (selected != null && mounted) {
      final newWorkoutExercise = WorkoutExercise(
        id: 'we_${DateTime.now().millisecondsSinceEpoch}',
        exerciseId: selected.id,
        exerciseName: selected.name,
        category: selected.category,
        primaryMusclesDisplay: selected.primaryMuscles.map((m) => m.displayName).join(' • '),
        secondaryMusclesDisplay: selected.secondaryMuscles.map((m) => m.displayName).join(' • '),
        trainerNote: selected.defaultTrainerNote,
        sets: [
          const ExerciseSet(
            id: 'set_new_1',
            setNumber: 1,
            targetWeight: 0.0,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRpe: 8.0,
          ),
          const ExerciseSet(
            id: 'set_new_2',
            setNumber: 2,
            targetWeight: 0.0,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRpe: 8.0,
          ),
          const ExerciseSet(
            id: 'set_new_3',
            setNumber: 3,
            targetWeight: 0.0,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRpe: 8.0,
          ),
        ],
      );

      widget.workoutRepository.addExerciseToActiveSession(newWorkoutExercise);
      _initAllSetControllers();
      final newIndex = widget.workoutRepository.activeSession.exercises.length - 1;
      _expandedExerciseIndices.add(newIndex);
      setState(() {});
    }
  }

  // --- Finish Workout Confirmation Dialog ---
  bool _isFinishingWorkout = false;

  Future<void> _showFinishConfirmation() async {
    HapticFeedback.lightImpact();
    final session = widget.workoutRepository.activeSession;
    final totalExercises = session.exercises.length;
    final completedExercises = session.exercises.where((e) => e.isAllSetsCompleted).length;
    final totalSets = session.totalSets;
    final completedSets = session.totalCompletedSets;
    final totalVolume = session.totalVolume;

    final colors = ClientThemeColors.of(context);

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        title: Text(
          'Finish Workout?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colors.primaryRed,
              ),
            ),
            const SizedBox(height: 14),
            _buildSummaryRow('Workout Duration', _formatSeconds(_elapsedSeconds), colors),
            const SizedBox(height: 8),
            _buildSummaryRow('Exercises Done', '$completedExercises / $totalExercises', colors),
            const SizedBox(height: 8),
            _buildSummaryRow('Sets Logged', '$completedSets / $totalSets', colors),
            const SizedBox(height: 8),
            _buildSummaryRow('Total Volume', '${totalVolume.round()} kg', colors),
            if (_achievedPRs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSummaryRow('Personal Records', '${_achievedPRs.length} PRs 🏆', colors),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Continue Workout',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finish Workout', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (shouldFinish == true && mounted) {
      _finishWorkout();
    }
  }

  Widget _buildSummaryRow(String label, String value, ClientThemeColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  void _finishWorkout() {
    if (_isFinishingWorkout) return;
    _isFinishingWorkout = true;

    final record = widget.workoutRepository.completeWorkout(
      durationSeconds: _elapsedSeconds,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => ClientWorkoutCompletionScreen(
          workoutRepository: widget.workoutRepository,
          completedRecord: record,
          durationSeconds: _elapsedSeconds,
          achievedPRs: _achievedPRs,
        ),
      ),
    );
  }

  // --- Plate Calculator Sheet ---
  void _openPlateCalculator(BuildContext context, double initialWeight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlateCalculatorSheet(initialWeight: initialWeight),
    );
  }

  // --- Target Muscle Sheet ---
  void _openTargetMuscleSheet(BuildContext context) {
    final session = widget.workoutRepository.activeSession;
    final colors = ClientThemeColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TARGET MUSCLE GROUPS',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, color: colors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.accessibility_new_rounded, color: colors.primaryRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session Focus', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                        Text(session.targetMuscleGroup, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Exercises in this workout:', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...session.exercises.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.exerciseName, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                  Text(e.category, style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                ],
              ),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final isDark = colors.isDark;

    // Handle Access Denied error state
    if (_isAccessDenied) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: const Text('Workout Access'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_rounded, size: 56, color: colors.primaryRed),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _accessErrorMessage,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colors.primaryRed),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final session = widget.workoutRepository.activeSession;
    final totalExercises = session.exercises.length;
    final completedExercises = session.exercises.where((e) => e.isAllSetsCompleted).length;
    final progressPercent = totalExercises > 0 ? (completedExercises / totalExercises) : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: colors.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
            title: Text('Exit Workout Session?', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: colors.textPrimary)),
            content: Text(
              'Your completed sets are safely saved on your device. You can resume this session anytime.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Stay & Train', style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colors.primaryRed),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit to Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // 1. WORKOUT TOP BAR (Matches reference screenshot IMG_3853 / IMG_3854)
              _buildWorkoutTopBar(colors, isDark),

              // 2. WORKOUT TITLE & PROGRESS HEADER
              _buildWorkoutHeader(session, completedExercises, totalExercises, progressPercent, colors),

              // 3. EXERCISE LIST (Expandable cards)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    ...session.exercises.asMap().entries.map((entry) {
                      final exIdx = entry.key;
                      final exercise = entry.value;
                      final isExpanded = _expandedExerciseIndices.contains(exIdx);

                      return _buildExerciseCard(
                        exerciseIndex: exIdx,
                        exercise: exercise,
                        isExpanded: isExpanded,
                        colors: colors,
                        isDark: isDark,
                      );
                    }),

                    const SizedBox(height: 12),

                    // 4. ADD EXERCISE BUTTON (Controlled by session permissions)
                    if (session.permissions.allowAddExercise)
                      Container(
                        width: double.infinity,
                        height: 52,
                        margin: const EdgeInsets.only(top: 4, bottom: 20),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colors.surfaceCard,
                            side: BorderSide(color: colors.border, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: colors.textPrimary),
                          label: Text(
                            'Add Exercise',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colors.textPrimary,
                            ),
                          ),
                          onPressed: _handleAddExercise,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 5. FLOATING REST TIMER BAR (Appears when rest timer is active or just completed)
        bottomSheet: (_isRestActive || _isRestFinished) ? _buildFloatingRestTimerBar(colors, isDark) : null,
      ),
    );
  }

  // --- Top Bar with Timer, Plate, Muscle, Timer Pill, Finish Pill ---
  Widget _buildWorkoutTopBar(ClientThemeColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Timer, Plate, Muscle icons with labels
          Row(
            children: [
              _buildTopIconButton(
                icon: Icons.timer_outlined,
                label: 'Timer',
                colors: colors,
                onTap: () => _startRestTimer(60, 'Rest Interval'),
              ),
              const SizedBox(width: 14),
              _buildTopIconButton(
                icon: Icons.calculate_outlined,
                label: 'Plate',
                colors: colors,
                onTap: () => _openPlateCalculator(context, 80.0),
              ),
              const SizedBox(width: 14),
              _buildTopIconButton(
                icon: Icons.accessibility_new_rounded,
                label: 'Muscle',
                colors: colors,
                onTap: () => _openTargetMuscleSheet(context),
              ),
            ],
          ),

          // Right: Elapsed Timer Pill + Finish Button Pill
          Row(
            children: [
              // Elapsed Timer Pill (tap to pause/resume)
              GestureDetector(
                onTap: _togglePauseElapsedTimer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222222) : const Color(0xFFEBEBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isTimerPaused ? AppColors.warning : colors.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTimerPaused ? Icons.pause_circle_filled_rounded : Icons.timer_outlined,
                        size: 13,
                        color: _isTimerPaused ? AppColors.warning : colors.textPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatSeconds(_elapsedSeconds),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _isTimerPaused ? AppColors.warning : colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Finish Button Pill (Amber / Yellow button matching screenshot)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800), // Vibrant amber/yellow matching reference
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _showFinishConfirmation,
                child: const Text(
                  'Finish',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required String label,
    required ClientThemeColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colors.textPrimary),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Title Row and Progress Header ---
  Widget _buildWorkoutHeader(
    WorkoutSession session,
    int completedExercises,
    int totalExercises,
    double progressPercent,
    ClientThemeColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: colors.textPrimary),
                color: colors.surfaceCard,
                onSelected: (val) {
                  if (val == 'discard') {
                    widget.workoutRepository.discardActiveSession();
                    Navigator.of(context).pop();
                  } else if (val == 'info') {
                    _openTargetMuscleSheet(context);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'info', child: Text('Workout Details')),
                  const PopupMenuItem(value: 'discard', child: Text('Discard Workout', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${session.workoutType} · ${session.targetMuscleGroup}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Progress indicator: "4 / 6 exercises" or "67% Complete"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedExercises / $totalExercises exercises',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '${(progressPercent * 100).round()}% Complete',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primaryRed),
            ),
          ),
        ],
      ),
    );
  }

  // --- Expandable Exercise Card (Matches IMG_3853 / IMG_3854) ---
  Widget _buildExerciseCard({
    required int exerciseIndex,
    required WorkoutExercise exercise,
    required bool isExpanded,
    required ClientThemeColors colors,
    required bool isDark,
  }) {
    final currentUserId = AuthService().currentUserId;
    final previousSets = widget.workoutRepository.getPreviousPerformance(
      exercise.exerciseId,
      clientId: currentUserId,
    );

    final isAllCompleted = exercise.isAllSetsCompleted;
    final exNumber = exerciseIndex + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? (isDark ? colors.primaryRed : const Color(0xFFFF6B00)) // Accent border when expanded
              : (isAllCompleted ? AppColors.success.withOpacity(0.5) : colors.border),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARD HEADER ROW
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedExerciseIndices.remove(exerciseIndex);
                } else {
                  _expandedExerciseIndices.add(exerciseIndex);
                }
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Exercise Number
                  Text(
                    '$exNumber',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Exercise Name (tapping name opens Exercise Detail Sheet)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ClientExerciseDetailSheet.show(
                          context,
                          workoutExercise: exercise,
                          workoutRepository: widget.workoutRepository,
                        );
                      },
                      child: Text(
                        exercise.exerciseName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // EXERCISE COMPLETION: Double-tick ✓✓ badge indicating Exercise Completed
                  if (isAllCompleted) ...[
                    Container(
                      key: ValueKey('exercise_completed_badge_${exercise.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.done_all_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '✓✓ Completed',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Chevron Expand / Collapse Icon
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: colors.textTertiary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // EXPANDED CONTENT AREA (Table + Actions)
          if (isExpanded) ...[
            Divider(height: 1, color: colors.borderSubtle),

            // TABLE HEADER: Set | Previous | Target | Kg | Reps | Checkbox
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('Set', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Previous', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Target', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 52,
                    child: Center(
                      child: Text('Kg', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    child: Center(
                      child: Text('Reps', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 38), // Space for completion circle
                ],
              ),
            ),
            Divider(height: 1, color: colors.borderSubtle.withOpacity(0.5)),

            // SET ROWS
            ...exercise.sets.asMap().entries.map((setEntry) {
              final setIdx = setEntry.key;
              final set = setEntry.value;

              // Previous data from real history for this set
              ExerciseSet? prevSet;
              if (previousSets != null && setIdx < previousSets.length) {
                prevSet = previousSets[setIdx];
              }

              return _buildSetRow(
                exerciseIndex: exerciseIndex,
                setIndex: setIdx,
                set: set,
                previousSet: prevSet,
                colors: colors,
                isDark: isDark,
              );
            }),

            const SizedBox(height: 10),

            // CARD BOTTOM ACTIONS: + Add Set | Swap | Rest Timer | ...
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // + Add Set
                  GestureDetector(
                    onTap: () => _handleAddSet(exerciseIndex),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 16, color: colors.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Add Set',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Swap Exercise
                  GestureDetector(
                    onTap: () => _handleSwapExercise(exerciseIndex),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 18, color: colors.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Swap',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Rest Timer Pill
                  GestureDetector(
                    onTap: () {
                      final rest = exercise.restSeconds > 0 ? exercise.restSeconds : 60;
                      _startRestTimer(rest, exercise.exerciseName);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: colors.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            _formatSeconds(exercise.restSeconds > 0 ? exercise.restSeconds : 60),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Details / Options ...
                  IconButton(
                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: colors.textTertiary),
                    onPressed: () {
                      ClientExerciseDetailSheet.show(
                        context,
                        workoutExercise: exercise,
                        workoutRepository: widget.workoutRepository,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // --- Set Row (Set | Previous | Target | Kg Input | Reps Input | Checkbox) ---
  Widget _buildSetRow({
    required int exerciseIndex,
    required int setIndex,
    required ExerciseSet set,
    required ExerciseSet? previousSet,
    required ClientThemeColors colors,
    required bool isDark,
  }) {
    final weightCtrl = _weightControllers[set.id];
    final repsCtrl = _repsControllers[set.id];

    // Previous text formatting
    final String previousText;
    final String? previousRpeText;
    if (previousSet != null) {
      final w = previousSet.actualWeight ?? previousSet.targetWeight;
      final r = previousSet.actualReps ?? previousSet.targetRepsMin;
      final wStr = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
      previousText = '$wStr kg × $r';
      previousRpeText = previousSet.actualRpe != null
          ? 'RPE ${previousSet.actualRpe}'
          : (previousSet.actualRir != null ? '${previousSet.actualRir} RIR' : null);
    } else {
      previousText = '-';
      previousRpeText = null;
    }

    // Target text formatting
    final targetReps = set.targetRepsDisplay;
    final targetRpeText = set.targetRpe != null ? 'RPE ${set.targetRpe}' : null;

    final isCompleted = set.isCompleted;

    final suggestion = _getSuggestionForSet(
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
    );

    final String weightHint;
    if (suggestion?.weight != null && suggestion!.weight! > 0) {
      final sw = suggestion.weight!;
      weightHint = sw % 1 == 0 ? sw.toInt().toString() : sw.toStringAsFixed(1);
    } else {
      weightHint = '-';
    }

    final TextStyle weightHintStyle = (suggestion?.weight != null && suggestion!.weight! > 0)
        ? GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF757575) : const Color(0xFF9E9E9E),
          )
        : GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textTertiary,
          );

    final String repsHint;
    if (suggestion?.reps != null && suggestion!.reps! > 0) {
      repsHint = suggestion.reps!.toString();
    } else {
      repsHint = '-';
    }

    final TextStyle repsHintStyle = (suggestion?.reps != null && suggestion!.reps! > 0)
        ? GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF757575) : const Color(0xFF9E9E9E),
          )
        : GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textTertiary,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SET NUMBER
          SizedBox(
            width: 32,
            child: Text(
              '${setIndex + 1}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCompleted ? colors.textTertiary : colors.textPrimary,
              ),
            ),
          ),

          // PREVIOUS PERFORMANCE (from real history)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  previousText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (previousRpeText != null)
                  Text(
                    previousRpeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // TARGET (from admin prescribed assignment)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  targetReps,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (targetRpeText != null)
                  Text(
                    targetRpeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // KG INPUT BOX
          Container(
            width: 52,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted
                    ? Colors.transparent
                    : (isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
              ),
            ),
            child: TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              enabled: !isCompleted,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCompleted ? colors.textTertiary : colors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintText: weightHint,
                hintStyle: weightHintStyle,
              ),
              onChanged: (_) => _onSetInputChanged(exerciseIndex: exerciseIndex, setIndex: setIndex),
            ),
          ),
          const SizedBox(width: 6),

          // REPS INPUT BOX
          Container(
            width: 52,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCompleted
                    ? Colors.transparent
                    : (isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
              ),
            ),
            child: TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enabled: !isCompleted,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCompleted ? colors.textTertiary : colors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintText: repsHint,
                hintStyle: repsHintStyle,
              ),
              onChanged: (_) => _onSetInputChanged(exerciseIndex: exerciseIndex, setIndex: setIndex),
            ),
          ),
          const SizedBox(width: 10),

          // COMPLETION CHECKBOX / TICK (☐ → ☑)
          GestureDetector(
            key: ValueKey('set_checkbox_${exerciseIndex}_$setIndex'),
            onTap: () => _toggleCompleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isCompleted
                    ? AppColors.success
                    : Colors.transparent,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success
                      : (isDark ? const Color(0xFF666666) : const Color(0xFFBDBDBD)),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                  : null, // ☐ empty box
            ),
          ),
        ],
      ),
    );
  }

  // --- Floating Rest Timer Bar at Bottom ---
  Widget _buildFloatingRestTimerBar(ClientThemeColors colors, bool isDark) {
    if (_isRestFinished) {
      return Container(
        key: const ValueKey('rest_timer_finished_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REST FINISHED!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Start your next set now',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _stopRestTimer,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'DISMISS',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('floating_rest_timer_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Timer indicator
            Icon(Icons.timer_outlined, color: colors.primaryRed, size: 22),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _restExerciseName.isNotEmpty ? _restExerciseName.toUpperCase() : 'REST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.textTertiary,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatSeconds(_restSecondsRemaining),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.primaryRed,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Quick adjustment buttons
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: colors.textSecondary,
              onPressed: () => _adjustRestTimer(-15),
              tooltip: '-15s',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: colors.textSecondary,
              onPressed: () => _adjustRestTimer(30),
              tooltip: '+30s',
            ),

            const Spacer(),

            // Pause / Resume toggle
            IconButton(
              icon: Icon(
                _isRestPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 22,
              ),
              color: colors.textPrimary,
              onPressed: () {
                setState(() => _isRestPaused = !_isRestPaused);
              },
            ),

            // Skip button
            TextButton(
              onPressed: _stopRestTimer,
              child: Text(
                'Skip',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barbell Plate Calculator Sheet (helper tool when tapping "Plate" in header)
class _PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;

  const _PlateCalculatorSheet({required this.initialWeight});

  @override
  State<_PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<_PlateCalculatorSheet> {
  late double _targetWeight;
  double _barWeight = 20.0; // Olympic barbell default

  final List<double> _plateSizes = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

  @override
  void initState() {
    super.initState();
    _targetWeight = widget.initialWeight > 0 ? widget.initialWeight : 80.0;
  }

  Map<double, int> _calculatePlatesPerSide() {
    final perSide = (_targetWeight - _barWeight) / 2.0;
    if (perSide <= 0) return {};

    double remainder = perSide;
    final Map<double, int> plates = {};

    for (final size in _plateSizes) {
      if (remainder >= size) {
        final count = (remainder / size).floor();
        plates[size] = count;
        remainder -= (count * size);
      }
    }

    return plates;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final platesPerSide = _calculatePlatesPerSide();
    final weightPerSide = ((_targetWeight - _barWeight) / 2.0).clamp(0.0, 999.0);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PLATE CALCULATOR',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15, color: colors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bar selection
            Row(
              children: [
                Text('Bar Weight: ', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('20 kg (Olympic)'),
                  selected: _barWeight == 20.0,
                  onSelected: (val) => setState(() => _barWeight = 20.0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('15 kg'),
                  selected: _barWeight == 15.0,
                  onSelected: (val) => setState(() => _barWeight = 15.0),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target weight stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Target: ${_targetWeight.toInt()} kg', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: colors.textPrimary)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() => _targetWeight = (_targetWeight - 2.5).clamp(20.0, 500.0)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _targetWeight = (_targetWeight + 2.5).clamp(20.0, 500.0)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Load per side: ${weightPerSide % 1 == 0 ? weightPerSide.toInt() : weightPerSide.toStringAsFixed(2)} kg', style: TextStyle(color: colors.primaryRed, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Plate breakdown per side
            if (platesPerSide.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Bar only. No extra plates needed.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: platesPerSide.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '${entry.key % 1 == 0 ? entry.key.toInt() : entry.key} kg × ${entry.value}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: colors.textPrimary),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
