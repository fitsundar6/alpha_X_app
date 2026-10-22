import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_picker_dialog.dart';

class AdminCreateEditSessionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final WorkoutSession? sessionToEdit;
  final WorkoutSplitPlan? splitToEdit;
  final WorkoutSplitPlan? parentSplit;
  final WorkoutSplitDay? splitDay;
  final bool? startInSplitMode;
  final String? clientIdToAssign;
  final VoidCallback? onSaved;
  final void Function(WorkoutSession)? onSessionSaved;

  const AdminCreateEditSessionScreen({
    super.key,
    required this.workoutRepository,
    this.sessionToEdit,
    this.splitToEdit,
    this.parentSplit,
    this.splitDay,
    this.startInSplitMode,
    this.clientIdToAssign,
    this.onSaved,
    this.onSessionSaved,
  });

  @override
  State<AdminCreateEditSessionScreen> createState() =>
      _AdminCreateEditSessionScreenState();
}

class _AdminCreateEditSessionScreenState
    extends State<AdminCreateEditSessionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  late TextEditingController _titleController;
  late TextEditingController _targetMuscleGroupController;
  late TextEditingController _durationController;
  late TextEditingController _descriptionController;
  late TextEditingController _recurringScheduleController;

  String _selectedWorkoutType = 'Strength';
  String _selectedDifficulty = 'Intermediate';
  bool _isActive = true;
  String _availabilityType = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  // Split-Mode Day Isolation State
  bool _isSplitMode = false;
  final List<String> _splitDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String _selectedSplitDay = 'Monday';
  final Map<String, List<WorkoutExercise>> _dayExercises = {};
  final Map<String, String> _dayTitles = {};
  final Map<String, String> _dayMuscleGroups = {};
  final Map<String, String> _dayWorkoutTypes = {};
  final Map<String, bool> _dayIsRest = {};
  final Map<String, String?> _daySessionIds = {};

  // Sections, Exercises, Permissions, Weekly Schedule
  List<WorkoutSection> _sections = [];
  List<WorkoutExercise> _exercises = [];
  ClientWorkoutPermissions _permissions = const ClientWorkoutPermissions();
  WeeklyWorkoutSchedule _weeklySchedule = const WeeklyWorkoutSchedule();
  List<int> _trainingDays = [1, 3, 5]; // Default Mon, Wed, Fri

  final List<String> _workoutTypes = [
    'Strength',
    'Hypertrophy',
    'Full Body',
    'Conditioning',
    'HIIT',
    'Cardio',
    'Mobility',
    'Boxing',
  ];

  final List<String> _difficulties = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.sessionToEdit;
    _titleController = TextEditingController(text: s?.title ?? '');
    _targetMuscleGroupController =
        TextEditingController(text: s?.targetMuscleGroup ?? '');
    _durationController = TextEditingController(
      text: (s?.estimatedDurationMinutes ?? 45).toString(),
    );
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _recurringScheduleController =
        TextEditingController(text: s?.recurringSchedule ?? '');

    // Initialize canonical day-wise split structures
    for (final day in _splitDays) {
      _dayExercises[day] = [];
      _dayTitles[day] = _getDayDefaultTitle(day);
      _dayMuscleGroups[day] = _getDayDefaultMuscle(day);
      _dayWorkoutTypes[day] = 'Strength';
      _dayIsRest[day] = day == 'Sunday';
      _daySessionIds[day] = null;
    }

    // Determine initial split mode
    if (widget.splitToEdit != null) {
      _isSplitMode = true;
    } else if (widget.splitDay != null || widget.sessionToEdit != null) {
      _isSplitMode = false;
    } else if (widget.startInSplitMode != null) {
      _isSplitMode = widget.startInSplitMode!;
    } else {
      _isSplitMode = false;
    }

    // Populate from parent split days if available (to maintain split boundary context)
    if (widget.parentSplit != null) {
      for (final d in widget.parentSplit!.days) {
        _dayExercises[d.dayOfWeek] = List.from(d.exercises);
        _dayTitles[d.dayOfWeek] = d.name;
        _dayMuscleGroups[d.dayOfWeek] = d.targetMuscleGroup;
        _dayWorkoutTypes[d.dayOfWeek] = d.workoutType;
        _dayIsRest[d.dayOfWeek] = d.isRestDay;
        _daySessionIds[d.dayOfWeek] = d.sessionId;
      }
    }

    if (widget.splitToEdit != null) {
      for (final d in widget.splitToEdit!.days) {
        _dayExercises[d.dayOfWeek] = List.from(d.exercises);
        _dayTitles[d.dayOfWeek] = d.name;
        _dayMuscleGroups[d.dayOfWeek] = d.targetMuscleGroup;
        _dayWorkoutTypes[d.dayOfWeek] = d.workoutType;
        _dayIsRest[d.dayOfWeek] = d.isRestDay;
        _daySessionIds[d.dayOfWeek] = d.sessionId;
      }
      _exercises = List.from(_dayExercises[_selectedSplitDay] ?? []);
      _titleController.text = _dayTitles[_selectedSplitDay] ?? '';
      _targetMuscleGroupController.text = _dayMuscleGroups[_selectedSplitDay] ?? '';
      _selectedWorkoutType = _dayWorkoutTypes[_selectedSplitDay] ?? 'Strength';
    } else if (widget.splitDay != null) {
      final sd = widget.splitDay!;
      _selectedSplitDay = sd.dayOfWeek;
      _dayExercises[_selectedSplitDay] = List.from(sd.exercises);
      _dayTitles[_selectedSplitDay] = sd.name;
      _dayMuscleGroups[_selectedSplitDay] = sd.targetMuscleGroup;
      _dayWorkoutTypes[_selectedSplitDay] = sd.workoutType;
      _dayIsRest[_selectedSplitDay] = sd.isRestDay;
      _daySessionIds[_selectedSplitDay] = sd.sessionId;

      _titleController.text = sd.name;
      _targetMuscleGroupController.text = sd.targetMuscleGroup;
      _selectedWorkoutType = sd.workoutType;
      _durationController.text = (sd.estimatedDurationMinutes > 0 ? sd.estimatedDurationMinutes : 45).toString();
      _descriptionController.text = sd.notes ?? '';
      _recurringScheduleController.text = sd.dayOfWeek;
      _exercises = List.from(sd.exercises);

      if (s != null) {
        _selectedDifficulty = s.difficulty;
        _isActive = s.isActive;
        _availabilityType = s.availabilityType;
        _startDate = s.startDate;
        _endDate = s.endDate;
        _sections = List.from(s.sections);
        _permissions = s.permissions;
        _weeklySchedule = s.weeklySchedule ?? const WeeklyWorkoutSchedule();
        _trainingDays = List.from(s.trainingDays);
      }
    } else if (s != null) {
      final day = s.recurringSchedule ?? 'Monday';
      _selectedSplitDay = _splitDays.contains(day) ? day : 'Monday';
      _dayExercises[_selectedSplitDay] = List.from(s.exercises);
      _dayTitles[_selectedSplitDay] = s.title;
      _dayMuscleGroups[_selectedSplitDay] = s.targetMuscleGroup;
      _dayWorkoutTypes[_selectedSplitDay] = s.workoutType;
      _daySessionIds[_selectedSplitDay] = s.id;

      _selectedWorkoutType = s.workoutType;
      _selectedDifficulty = s.difficulty;
      _isActive = s.isActive;
      _availabilityType = s.availabilityType;
      _startDate = s.startDate;
      _endDate = s.endDate;
      _exercises = List.from(s.exercises);
      _sections = List.from(s.sections);
      _permissions = s.permissions;
      _weeklySchedule = s.weeklySchedule ?? const WeeklyWorkoutSchedule();
      _trainingDays = List.from(s.trainingDays);
    } else {
      _sections = [
        const WorkoutSection(
          id: 'sec_warmup',
          title: 'Warm-up & Activation',
          sectionType: WorkoutSectionType.warmUp,
          orderIndex: 0,
          trainerInstructions:
              'Dynamic movement prep, joint mobilization, & CNS activation.',
        ),
        const WorkoutSection(
          id: 'sec_main',
          title: 'Main Workout',
          sectionType: WorkoutSectionType.mainWorkout,
          orderIndex: 1,
          trainerInstructions:
              'Primary hypertrophy & strength volume. Maintain 1–2 RIR.',
        ),
        const WorkoutSection(
          id: 'sec_mobility',
          title: 'Mobility & Accessory',
          sectionType: WorkoutSectionType.mobility,
          orderIndex: 2,
        ),
        const WorkoutSection(
          id: 'sec_cooldown',
          title: 'Cool-down & Recovery',
          sectionType: WorkoutSectionType.coolDown,
          orderIndex: 3,
          trainerInstructions:
              'Parasympathetic breathing and static muscle decompression.',
        ),
      ];

      _exercises = [
        const WorkoutExercise(
          id: 'we_incline_smith_init',
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Machine Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Upper Chest',
          secondaryMusclesDisplay: 'Front Delts • Triceps',
          sectionId: 'sec_main',
          sectionType: WorkoutSectionType.mainWorkout,
          restSeconds: 90,
          trainerNote: 'Keep 2 RIR. Control eccentric 2-3s.',
          tempo: '3-1-1-0',
          sets: [
            ExerciseSet(
              id: 'set_init_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 75.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              targetRpe: 8.0,
              targetRir: 2,
              tempo: '3-1-1-0',
            ),
            ExerciseSet(
              id: 'set_init_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 75.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              targetRpe: 8.0,
              targetRir: 2,
              tempo: '3-1-1-0',
            ),
            ExerciseSet(
              id: 'set_init_3',
              setNumber: 3,
              setType: SetType.working,
              targetWeight: 75.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              targetRpe: 8.5,
              targetRir: 1,
              tempo: '3-1-1-0',
            ),
          ],
        ),
      ];
    }

    if (widget.clientIdToAssign != null &&
        widget.splitToEdit == null &&
        widget.sessionToEdit == null &&
        widget.splitDay == null &&
        widget.parentSplit == null) {
      _loadExistingClientSplit();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetMuscleGroupController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    _recurringScheduleController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingClientSplit() async {
    if (widget.clientIdToAssign == null) return;
    try {
      final split = await widget.workoutRepository.fetchClientWorkoutSplit(widget.clientIdToAssign!);
      if (split != null && mounted) {
        setState(() {
          for (final d in split.days) {
            _dayExercises[d.dayOfWeek] = List.from(d.exercises);
            _dayTitles[d.dayOfWeek] = d.name;
            _dayMuscleGroups[d.dayOfWeek] = d.targetMuscleGroup;
            _dayWorkoutTypes[d.dayOfWeek] = d.workoutType;
            _dayIsRest[d.dayOfWeek] = d.isRestDay;
            _daySessionIds[d.dayOfWeek] = d.sessionId;
          }
          _exercises = List.from(_dayExercises[_selectedSplitDay] ?? []);
          _titleController.text = _dayTitles[_selectedSplitDay] ?? '';
          _targetMuscleGroupController.text = _dayMuscleGroups[_selectedSplitDay] ?? '';
          _selectedWorkoutType = _dayWorkoutTypes[_selectedSplitDay] ?? 'Strength';
        });
      }
    } catch (_) {}
  }

  void _onSelectSplitDay(String newDay) {
    if (newDay == _selectedSplitDay) return;
    // 1. Preserve current active day exercises & titles
    _dayExercises[_selectedSplitDay] = List.from(_exercises);
    _dayTitles[_selectedSplitDay] = _titleController.text.trim();
    _dayMuscleGroups[_selectedSplitDay] = _targetMuscleGroupController.text.trim();
    _dayWorkoutTypes[_selectedSplitDay] = _selectedWorkoutType;

    // 2. Switch to selected day
    setState(() {
      _selectedSplitDay = newDay;
      _exercises = List.from(_dayExercises[newDay] ?? []);
      _titleController.text = _dayTitles[newDay]?.isNotEmpty == true
          ? _dayTitles[newDay]!
          : _getDayDefaultTitle(newDay);
      _targetMuscleGroupController.text = _dayMuscleGroups[newDay]?.isNotEmpty == true
          ? _dayMuscleGroups[newDay]!
          : _getDayDefaultMuscle(newDay);
      _selectedWorkoutType = _dayWorkoutTypes[newDay] ?? 'Strength';
      _recurringScheduleController.text = newDay;
    });
  }

  String _getDayDefaultTitle(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Monday — Push Day';
      case 'tuesday':
        return 'Tuesday — Pull Day';
      case 'wednesday':
        return 'Wednesday — Legs Day';
      case 'thursday':
        return 'Thursday — Push Day 2';
      case 'friday':
        return 'Friday — Pull Day 2';
      case 'saturday':
        return 'Saturday — Legs Day 2';
      case 'sunday':
        return 'Sunday — Rest & Recovery';
      default:
        return '$day Workout';
    }
  }

  String _getDayDefaultMuscle(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
      case 'thursday':
        return 'Chest • Shoulders • Triceps';
      case 'tuesday':
      case 'friday':
        return 'Back • Biceps • Rear Delts';
      case 'wednesday':
      case 'saturday':
        return 'Quads • Hamstrings • Calves';
      case 'sunday':
        return 'Active Recovery & Mobility';
      default:
        return 'Full Body';
    }
  }

  Widget _buildSplitDaySelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.primaryRed, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'WORKOUT SPLIT DAYS',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSplitMode ? '7-Day Split' : 'Single Workout',
                    style: TextStyle(
                      color: _isSplitMode ? AppColors.primaryRed : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: _isSplitMode,
                    activeColor: AppColors.primaryRed,
                    onChanged: (val) {
                      setState(() => _isSplitMode = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_isSplitMode) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _splitDays.map((day) {
                  final isSelected = day == _selectedSplitDay;
                  final isRest = _dayIsRest[day] ?? false;
                  final exCount = (_dayExercises[day] ?? []).length;
                  final shortName = day.substring(0, 3);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _onSelectSplitDay(day),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryRed
                              : (isRest ? AppColors.background : AppColors.surfaceCard),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryRed : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shortName.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isRest ? 'Rest' : '$exCount ex',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.9)
                                    : (isRest ? AppColors.textSecondary : AppColors.primaryRed),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    (_dayIsRest[_selectedSplitDay] ?? false) ? Icons.bedtime : Icons.fitness_center,
                    size: 16,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing: $_selectedSplitDay (${_exercises.length} exercises)',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Rest Day',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Checkbox(
                        value: _dayIsRest[_selectedSplitDay] ?? false,
                        activeColor: AppColors.primaryRed,
                        onChanged: (val) {
                          setState(() {
                            _dayIsRest[_selectedSplitDay] = val ?? false;
                            if (val == true) {
                              _titleController.text = '$_selectedSplitDay — Rest & Recovery';
                              _targetMuscleGroupController.text = 'Active Recovery • Mobility';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onReorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
      _dayExercises[_selectedSplitDay] = List.from(_exercises);
    });
  }

  void _moveExercise(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _exercises.length) return;
    setState(() {
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
      _dayExercises[_selectedSplitDay] = List.from(_exercises);
    });
  }

  void _replaceExerciseWithLibrary(int index) async {
    if (index < 0 || index >= _exercises.length) return;
    final existing = _exercises[index];
    final picked = await ExercisePickerDialog.show(
      context,
      initialCategory: existing.category,
      excludedExerciseId: existing.exerciseId,
    );
    if (picked != null) {
      if (picked.id == existing.exerciseId ||
          picked.displayName.toLowerCase().trim() ==
              existing.exerciseName.toLowerCase().trim()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Selected exercise is identical to current exercise. Please choose a different exercise to replace.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      final replaced = existing.copyWith(
        exerciseId: picked.id,
        exerciseName: picked.displayName,
        category: picked.category,
        primaryMusclesDisplay: picked.primaryMusclesDisplay,
        secondaryMusclesDisplay: picked.secondaryMusclesDisplay,
        trainerNote: existing.trainerNote.isNotEmpty
            ? existing.trainerNote
            : picked.defaultTrainerNote,
        approvedAlternativeIds: picked.approvedAlternativeIds,
      );
      setState(() {
        _exercises[index] = replaced;
        _dayExercises[_selectedSplitDay] = List.from(_exercises);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replaced with "${picked.displayName}"'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  void _pickExerciseFromDatabase() async {
    final picked = await ExercisePickerDialog.show(context);
    if (picked != null) {
      final newExercise = WorkoutExercise(
        id: 'we_${DateTime.now().millisecondsSinceEpoch}',
        exerciseId: picked.id,
        exerciseName: picked.displayName,
        category: picked.category,
        primaryMusclesDisplay: picked.primaryMusclesDisplay,
        secondaryMusclesDisplay: picked.secondaryMusclesDisplay,
        sectionId: _sections.isNotEmpty ? _sections[1].id : 'sec_main',
        sectionType: WorkoutSectionType.mainWorkout,
        restSeconds: 90,
        trainerNote: picked.defaultTrainerNote,
        tempo: '3-1-1-0',
        approvedAlternativeIds: picked.approvedAlternativeIds,
        sets: [
          const ExerciseSet(
            id: 'set_1',
            setNumber: 1,
            setType: SetType.working,
            targetWeight: 60.0,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRpe: 8.0,
            targetRir: 2,
            tempo: '3-1-1-0',
          ),
          const ExerciseSet(
            id: 'set_2',
            setNumber: 2,
            setType: SetType.working,
            targetWeight: 60.0,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRpe: 8.0,
            targetRir: 2,
            tempo: '3-1-1-0',
          ),
          const ExerciseSet(
            id: 'set_3',
            setNumber: 3,
            setType: SetType.working,
            targetWeight: 60.0,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetRpe: 8.5,
            targetRir: 1,
            tempo: '3-1-1-0',
          ),
        ],
      );

      setState(() => _exercises.add(newExercise));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${picked.displayName}" to session'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  void _openExerciseDialog({WorkoutExercise? existingExercise, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExerciseEditDialog(
        existingExercise: existingExercise,
        sections: _sections,
        onSave: (savedExercise) {
          setState(() {
            if (index != null && index >= 0 && index < _exercises.length) {
              _exercises[index] = savedExercise;
            } else {
              _exercises.add(savedExercise);
            }
          });
        },
      ),
    );
  }

  void _duplicateExercise(int index) {
    final original = _exercises[index];
    final copy = original.copyWith(
      id: 'ex_dup_${DateTime.now().millisecondsSinceEpoch}',
      exerciseName: '${original.exerciseName} (Copy)',
      sets: original.sets.map((s) => s.copyWith(isCompleted: false)).toList(),
    );
    setState(() => _exercises.insert(index + 1, copy));
  }

  void _deleteExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  void _addSectionDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    WorkoutSectionType sectionType = WorkoutSectionType.custom;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text('Add Workout Section', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Section Title', hintText: 'e.g. Finisher Circuit'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<WorkoutSectionType>(
                value: sectionType,
                dropdownColor: AppColors.surfaceElevated,
                items: WorkoutSectionType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => sectionType = val);
                },
                decoration: const InputDecoration(labelText: 'Section Type'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Trainer Instructions', hintText: 'Notes for client'),
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
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  setState(() {
                    _sections.add(
                      WorkoutSection(
                        id: 'sec_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        sectionType: sectionType,
                        orderIndex: _sections.length,
                        trainerInstructions: notesController.text.trim(),
                      ),
                    );
                  });
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Add Section', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // 1. Sync current active day exercises & titles
      _dayExercises[_selectedSplitDay] = List.from(_exercises);
      _dayTitles[_selectedSplitDay] = _titleController.text.trim();
      _dayMuscleGroups[_selectedSplitDay] = _targetMuscleGroupController.text.trim();
      _dayWorkoutTypes[_selectedSplitDay] = _selectedWorkoutType;

      if (_isSplitMode) {
        final totalExCount = _dayExercises.values.fold(0, (acc, list) => acc + list.length);
        if (totalExCount == 0 && !_dayIsRest.values.any((r) => r)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add exercises to at least one workout day in the split.'),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }

        final splitDays = <WorkoutSplitDay>[];
        for (int i = 0; i < _splitDays.length; i++) {
          final dayName = _splitDays[i];
          final dayExs = _dayExercises[dayName] ?? [];
          final isRest = _dayIsRest[dayName] ?? (dayExs.isEmpty);

          splitDays.add(WorkoutSplitDay(
            id: 'split_day_${dayName.toLowerCase()}',
            sessionId: _daySessionIds[dayName],
            dayOfWeek: dayName,
            dayIndex: i + 1,
            name: _dayTitles[dayName]?.isNotEmpty == true
                ? _dayTitles[dayName]!
                : (isRest ? 'Rest Day' : '$dayName Workout'),
            workoutType: _dayWorkoutTypes[dayName] ?? 'Strength',
            targetMuscleGroup: _dayMuscleGroups[dayName]?.isNotEmpty == true
                ? _dayMuscleGroups[dayName]!
                : (isRest ? 'Recovery' : 'Full Body'),
            estimatedDurationMinutes: int.tryParse(_durationController.text.trim()) ?? 45,
            isRestDay: isRest,
            notes: _descriptionController.text.trim(),
            exercises: isRest ? const [] : dayExs,
          ));
        }

        final split = WorkoutSplitPlan(
          id: widget.splitToEdit?.id ?? widget.parentSplit?.id ?? 'split_${DateTime.now().millisecondsSinceEpoch}',
          title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Weekly Workout Split',
          splitType: 'Custom',
          description: _descriptionController.text.trim(),
          frequencyPerWeek: splitDays.where((d) => !d.isRestDay).length,
          clientId: widget.clientIdToAssign ?? widget.splitToEdit?.clientId ?? widget.parentSplit?.clientId,
          days: splitDays,
        );

        await widget.workoutRepository.saveWorkoutSplit(split);

        widget.onSaved?.call();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.clientIdToAssign != null
                  ? 'Workout split saved and assigned to athlete day-by-day!'
                  : 'Workout split plan saved successfully.',
            ),
            backgroundColor: AppColors.primaryRed,
          ),
        );

        Navigator.of(context).pop(true);
        return;
      }

      // Single Session / Split Day Mode
      final isRest = _dayIsRest[_selectedSplitDay] ?? false;
      if (!isRest && _exercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one exercise to the session.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final duration = int.tryParse(_durationController.text.trim()) ?? 45;
      final isDraftSession = widget.sessionToEdit != null && widget.sessionToEdit!.id.startsWith('ai_draft_');
      final isEditing = widget.sessionToEdit != null && !isDraftSession;
      final sessionId = widget.sessionToEdit != null
          ? widget.sessionToEdit!.id
          : (widget.splitDay?.sessionId ?? 'ws_${DateTime.now().millisecondsSinceEpoch}');

      final session = WorkoutSession(
        id: sessionId,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : '$_selectedSplitDay Session',
        workoutType: _selectedWorkoutType,
        targetMuscleGroup: _targetMuscleGroupController.text.trim().isNotEmpty
            ? _targetMuscleGroupController.text.trim()
            : 'Full Body',
        difficulty: _selectedDifficulty,
        estimatedDurationMinutes: duration,
        description: _descriptionController.text.trim(),
        isActive: _isActive,
        startDate: _startDate,
        endDate: _endDate,
        recurringSchedule: _selectedSplitDay,
        availabilityType: _availabilityType,
        assignedClientIds: widget.clientIdToAssign != null
            ? [widget.clientIdToAssign!]
            : (widget.sessionToEdit?.assignedClientIds ?? const []),
        isRecommended: widget.sessionToEdit?.isRecommended ?? false,
        startedAt: widget.sessionToEdit?.startedAt ?? DateTime.now(),
        exercises: List.from(_exercises),
        sections: List.from(_sections),
        permissions: _permissions,
        weeklySchedule: _weeklySchedule,
        trainingDays: List.from(_trainingDays),
        planVersion: widget.sessionToEdit?.planVersion,
      );

      if (isEditing) {
        await widget.workoutRepository.updateSession(session);
      } else {
        await widget.workoutRepository.createSession(session);
      }

      // If editing a specific day within an existing parent split plan
      if (widget.parentSplit != null) {
        final dayOfWeek = widget.splitDay?.dayOfWeek ?? _selectedSplitDay;
        final dayId = widget.splitDay?.id ?? 'split_day_${dayOfWeek.toLowerCase()}';
        final splitDay = WorkoutSplitDay(
          id: dayId,
          sessionId: session.id,
          dayOfWeek: dayOfWeek,
          dayIndex: widget.splitDay?.dayIndex ?? (_splitDays.indexOf(dayOfWeek) + 1),
          name: session.title,
          workoutType: session.workoutType,
          targetMuscleGroup: session.targetMuscleGroup,
          estimatedDurationMinutes: session.estimatedDurationMinutes,
          isRestDay: isRest,
          notes: session.description,
          exercises: isRest ? const [] : session.exercises,
        );

        await widget.workoutRepository.updateWorkoutSplitDay(
          widget.parentSplit!.id,
          dayId,
          splitDay,
        );
      } else if (widget.clientIdToAssign != null && widget.clientIdToAssign!.isNotEmpty) {
        await widget.workoutRepository.assignSession(
          sessionId: session.id,
          assignmentType: 'INDIVIDUAL',
          individualClientId: widget.clientIdToAssign,
          isRecommended: true,
        );
      }

      widget.onSessionSaved?.call(session);
      widget.onSaved?.call();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.parentSplit != null
                ? 'Updated $_selectedSplitDay session in athlete workout plan!'
                : widget.clientIdToAssign != null
                    ? 'Workout plan saved and assigned to athlete!'
                    : isEditing
                        ? 'Workout session updated.'
                        : 'Workout session created successfully.',
          ),
          backgroundColor: AppColors.primaryRed,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving workout: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.sessionToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.splitDay != null
              ? 'EDIT ${widget.splitDay!.dayOfWeek.toUpperCase()} SESSION'
              : isEditing
                  ? 'EDIT WORKOUT PLAN'
                  : 'WORKOUT BUILDER',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: 16,
          ),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryRed,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveSession,
                  child: const Text(
                    'SAVE',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Day-Wise Split Selector
            _buildSplitDaySelector(),
            const SizedBox(height: 16),

            // 1. Basic Plan Overview
            _sectionHeader('1. WORKOUT PLAN OVERVIEW'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _titleController,
              label: 'Plan Title *',
              hint: 'e.g. PUSH DAY — Chest & Shoulders Overload',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Session title required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Workout Type',
                    value: _selectedWorkoutType,
                    items: _workoutTypes,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWorkoutType = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Difficulty',
                    value: _selectedDifficulty,
                    items: _difficulties,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDifficulty = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _targetMuscleGroupController,
                    label: 'Target Muscle Group *',
                    hint: 'e.g. Chest • Shoulders • Triceps',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Target muscle group required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _durationController,
                    label: 'Duration (min)',
                    hint: '55',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionController,
              label: 'Trainer Instructions & Adaptations',
              hint: 'Prescription notes, focus, target adaptation...',
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // 2. Workout Sections Management
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader('2. WORKOUT SECTIONS (${_sections.length})'),
                TextButton.icon(
                  onPressed: _addSectionDialog,
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primaryRed),
                  label: const Text('Add Section', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._sections.asMap().entries.map((entry) {
              final idx = entry.key;
              final sec = entry.value;
              final exercisesCount = _exercises.where((e) => e.sectionType == sec.sectionType || e.sectionId == sec.id).length;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SEC ${idx + 1}',
                        style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sec.title,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          if (sec.trainerInstructions != null && sec.trainerInstructions!.isNotEmpty)
                            Text(
                              sec.trainerInstructions!,
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '$exercisesCount exercises',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            // 3. Exercises in Session (Reorderable List & Picker)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _sectionHeader('3. EXERCISES IN SESSION (${_exercises.length})'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickExerciseFromDatabase,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('+ ADD EXERCISE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _openExerciseDialog(),
                      icon: const Icon(Icons.edit_note, size: 16, color: AppColors.textSecondary),
                      label: const Text('Custom', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const Text(
              'Drag and drop exercises to reorder prescribed flow. Superset tags (A1/A2) will guide clients.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 12),

            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _exercises.length,
              onReorder: _onReorderExercises,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final animValue =
                        Curves.easeInOut.transform(animation.value);
                    final elevation = 4.0 + (animValue * 6.0);
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: AppColors.primaryRed.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.primaryRed, width: 2),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (ctx, index) {
                final ex = _exercises[index];
                return _buildExerciseListItem(ex, index,
                    key: ValueKey('sess_ex_${ex.id}_$index'));
              },
            ),

            const SizedBox(height: 24),

            // 4. Client Permissions Settings (Admin Control)
            _sectionHeader('4. CLIENT WORKOUT PERMISSIONS'),
            const SizedBox(height: 4),
            const Text(
              'Configure what clients are permitted to adjust during this live session.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _permissionSwitch(
                    'Allow Exercise Swap',
                    'Client can substitute exercise with approved alternatives for today only',
                    _permissions.allowExerciseSwap,
                    (val) => setState(() => _permissions = _permissions.copyWith(allowExerciseSwap: val)),
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _permissionSwitch(
                    'Allow Adding Exercises',
                    'Client can add an extra movement during execution',
                    _permissions.allowAddExercise,
                    (val) => setState(() => _permissions = _permissions.copyWith(allowAddExercise: val)),
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _permissionSwitch(
                    'Allow Changing Sets Count',
                    'Client can add or remove sets during execution',
                    _permissions.allowChangingSets,
                    (val) => setState(() => _permissions = _permissions.copyWith(allowChangingSets: val)),
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _permissionSwitch(
                    'Allow Changing Rest Timers',
                    'Client can tweak rest seconds on the fly',
                    _permissions.allowChangingRest,
                    (val) => setState(() => _permissions = _permissions.copyWith(allowChangingRest: val)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 5. Training Days & Weekly Schedule
            _sectionHeader('5. PRESCRIBED TRAINING DAYS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _dayChip(1, 'Mon'),
                _dayChip(2, 'Tue'),
                _dayChip(3, 'Wed'),
                _dayChip(4, 'Thu'),
                _dayChip(5, 'Fri'),
                _dayChip(6, 'Sat'),
                _dayChip(7, 'Sun'),
              ],
            ),

            const SizedBox(height: 28),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : _saveSession,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving
                    ? 'SAVING...'
                    : widget.splitDay != null
                        ? 'SAVE ${widget.splitDay!.dayOfWeek.toUpperCase()} SESSION'
                        : isEditing
                            ? 'UPDATE WORKOUT PLAN (V${(widget.sessionToEdit?.planVersion.versionNumber ?? 1) + 1})'
                            : 'CREATE WORKOUT PLAN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _dayChip(int dayNumber, String label) {
    final isSelected = _trainingDays.contains(dayNumber);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryRed,
      backgroundColor: AppColors.surfaceCard,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primaryRed : AppColors.border,
        ),
      ),
      onSelected: (val) {
        setState(() {
          if (val) {
            _trainingDays.add(dayNumber);
          } else {
            _trainingDays.remove(dayNumber);
          }
        });
      },
    );
  }

  Widget _permissionSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: AppColors.primaryRed,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryRed),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          border: InputBorder.none,
        ),
        dropdownColor: AppColors.surfaceElevated,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildExerciseListItem(
    WorkoutExercise ex,
    int index, {
    required Key key,
  }) {
    final firstSet = ex.sets.firstOrNull;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ex.isSuperset
              ? AppColors.primaryRed.withOpacity(0.5)
              : AppColors.border,
          width: ex.isSuperset ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                  child: const Icon(
                    Icons.drag_indicator,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (ex.isSuperset) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ex.supersetTag ?? 'SS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        title: Text(
          ex.exerciseName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${ex.trainingMethod.displayName} • ${ex.sets.length} sets × ${firstSet?.targetRepsDisplay ?? "8-12"} reps @ ${firstSet?.targetWeight != null ? "${firstSet!.targetWeight} kg" : "BW"} | Rest: ${ex.restSeconds}s | Tempo: ${ex.tempo}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            if (ex.trainerNote.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Note: ${ex.trainerNote}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18, color: AppColors.textSecondary),
              tooltip: 'Move Up',
              onPressed: index > 0 ? () => _moveExercise(index, index - 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 18, color: AppColors.textSecondary),
              tooltip: 'Move Down',
              onPressed: index < _exercises.length - 1 ? () => _moveExercise(index, index + 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz, size: 20, color: AppColors.primaryRed),
              tooltip: 'Replace with Library Exercise',
              onPressed: () => _replaceExerciseWithLibrary(index),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
              tooltip: 'Duplicate Exercise',
              onPressed: () => _duplicateExercise(index),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
              tooltip: 'Edit Exercise Details',
              onPressed: () => _openExerciseDialog(existingExercise: ex, index: index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              tooltip: 'Delete Exercise',
              onPressed: () => _deleteExercise(index),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed Exercise Edit Dialog with Set Types and Training Methods
class _ExerciseEditDialog extends StatefulWidget {
  final WorkoutExercise? existingExercise;
  final List<WorkoutSection> sections;
  final void Function(WorkoutExercise) onSave;

  const _ExerciseEditDialog({
    this.existingExercise,
    required this.sections,
    required this.onSave,
  });

  @override
  State<_ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<_ExerciseEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _setsController;
  late TextEditingController _targetRepsController;
  late TextEditingController _targetWeightController;
  late TextEditingController _restSecondsController;
  late TextEditingController _targetRirController;
  late TextEditingController _targetRpeController;
  late TextEditingController _tempoController;
  late TextEditingController _supersetTagController;
  late TextEditingController _adminNoteController;

  String? _pickedExerciseId;
  String? _pickedCategory;
  String? _pickedPrimaryMuscles;
  String? _pickedSecondaryMuscles;
  List<String>? _pickedAlternatives;

  SetType _selectedSetType = SetType.working;
  AdvancedTrainingMethod _selectedMethod = AdvancedTrainingMethod.straightSets;
  WorkoutSectionType _selectedSectionType = WorkoutSectionType.mainWorkout;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingExercise;
    final firstSet = ex?.sets.firstOrNull;

    _pickedExerciseId = ex?.exerciseId;
    _pickedCategory = ex?.category;
    _pickedPrimaryMuscles = ex?.primaryMusclesDisplay;
    _pickedSecondaryMuscles = ex?.secondaryMusclesDisplay;
    _pickedAlternatives = ex?.approvedAlternativeIds;

    _nameController = TextEditingController(text: ex?.exerciseName ?? '');
    _setsController =
        TextEditingController(text: (ex?.sets.length ?? 3).toString());
    _targetRepsController =
        TextEditingController(text: firstSet?.targetRepsDisplay ?? '8–12');
    _targetWeightController = TextEditingController(
      text: firstSet?.targetWeight != null && firstSet!.targetWeight > 0
          ? '${firstSet.targetWeight}'
          : '',
    );
    _restSecondsController =
        TextEditingController(text: (ex?.restSeconds ?? 90).toString());
    _targetRirController =
        TextEditingController(text: (firstSet?.targetRir ?? 2).toString());
    _targetRpeController =
        TextEditingController(text: (firstSet?.targetRpe ?? 8.0).toString());
    _tempoController = TextEditingController(text: ex?.tempo ?? '3-1-1-0');
    _supersetTagController =
        TextEditingController(text: ex?.supersetTag ?? '');
    _adminNoteController =
        TextEditingController(text: ex?.trainerNote ?? '');

    if (firstSet != null) {
      _selectedSetType = firstSet.setType;
    }
    if (ex != null) {
      _selectedMethod = ex.trainingMethod;
      _selectedSectionType = ex.sectionType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _targetRepsController.dispose();
    _targetWeightController.dispose();
    _restSecondsController.dispose();
    _targetRirController.dispose();
    _targetRpeController.dispose();
    _tempoController.dispose();
    _supersetTagController.dispose();
    _adminNoteController.dispose();
    super.dispose();
  }

  void _pickFromLibrary() async {
    final picked = await ExercisePickerDialog.show(context);
    if (picked != null) {
      setState(() {
        _pickedExerciseId = picked.id;
        _pickedCategory = picked.category;
        _pickedPrimaryMuscles = picked.primaryMusclesDisplay;
        _pickedSecondaryMuscles = picked.secondaryMusclesDisplay;
        _pickedAlternatives = picked.approvedAlternativeIds;
        _nameController.text = picked.displayName;
        if (_adminNoteController.text.trim().isEmpty) {
          _adminNoteController.text = picked.defaultTrainerNote;
        }
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise name is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final setsCount = int.tryParse(_setsController.text.trim()) ?? 3;
    final weight = double.tryParse(_targetWeightController.text.trim());
    final rest = int.tryParse(_restSecondsController.text.trim()) ?? 90;
    final rir = int.tryParse(_targetRirController.text.trim()) ?? 2;
    final rpe = double.tryParse(_targetRpeController.text.trim()) ?? 8.0;
    final superset = _supersetTagController.text.trim().isEmpty
        ? null
        : _supersetTagController.text.trim().toUpperCase();

    // Parse reps range e.g. "8-12" or "10"
    final repsText = _targetRepsController.text.trim();
    int minReps = 8;
    int maxReps = 12;
    if (repsText.contains('–') || repsText.contains('-')) {
      final parts = repsText.split(RegExp(r'[–\-]'));
      minReps = int.tryParse(parts[0].trim()) ?? 8;
      maxReps = int.tryParse(parts[1].trim()) ?? minReps;
    } else {
      minReps = int.tryParse(repsText) ?? 8;
      maxReps = minReps;
    }

    final generatedSets = List.generate(
      setsCount,
      (idx) => ExerciseSet(
        id: 'set_${DateTime.now().millisecondsSinceEpoch}_${idx + 1}',
        setNumber: idx + 1,
        setType: _selectedSetType,
        targetWeight: weight ?? 0.0,
        targetRepsMin: minReps,
        targetRepsMax: maxReps,
        targetRpe: rpe,
        targetRir: rir,
        tempo: _tempoController.text.trim(),
      ),
    );

    final exercise = WorkoutExercise(
      id: widget.existingExercise?.id ??
          'we_${DateTime.now().millisecondsSinceEpoch}',
      exerciseId: _pickedExerciseId ??
          widget.existingExercise?.exerciseId ??
          'ex_custom_${DateTime.now().millisecondsSinceEpoch}',
      exerciseName: name,
      category: _pickedCategory ?? widget.existingExercise?.category ?? 'General',
      primaryMusclesDisplay: _pickedPrimaryMuscles ??
          widget.existingExercise?.primaryMusclesDisplay ?? 'Primary Muscles',
      secondaryMusclesDisplay: _pickedSecondaryMuscles ??
          widget.existingExercise?.secondaryMusclesDisplay ?? '',
      supersetTag: superset,
      sectionType: _selectedSectionType,
      trainingMethod: _selectedMethod,
      restSeconds: rest,
      trainerNote: _adminNoteController.text.trim(),
      tempo: _tempoController.text.trim(),
      approvedAlternativeIds: _pickedAlternatives ??
          widget.existingExercise?.approvedAlternativeIds ?? const [],
      sets: generatedSets,
    );

    widget.onSave(exercise);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingExercise != null
                      ? 'EDIT EXERCISE CONFIG'
                      : 'CONFIGURE EXERCISE',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    fontSize: 16,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFromLibrary,
                  icon: const Icon(Icons.storage, size: 16, color: AppColors.primaryRed),
                  label: const Text('Pick from Library', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Exercise Name Field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Exercise Name *',
                hintText: 'e.g. Incline Smith Machine Press',
                filled: true,
                fillColor: AppColors.surfaceCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Section & Method Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<WorkoutSectionType>(
                    value: _selectedSectionType,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    items: WorkoutSectionType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSectionType = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Section',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<AdvancedTrainingMethod>(
                    value: _selectedMethod,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    items: AdvancedTrainingMethod.values.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m.displayName));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMethod = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Training Method',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Superset Tag & Set Type Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SetType>(
                    value: _selectedSetType,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    items: SetType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSetType = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Default Set Type',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _supersetTagController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Superset Tag',
                      hintText: 'e.g. A1, A2, B1',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Prescription Parameters (Sets, Reps, Weight, Rest)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Number of Sets',
                      hintText: '3',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _targetRepsController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Target Reps',
                      hintText: '8–12',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Target Weight (kg)',
                      hintText: 'e.g. 80.0',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _restSecondsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Rest Seconds',
                      hintText: '90',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // RIR, RPE, Tempo
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetRirController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Target RIR',
                      hintText: '2',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _targetRpeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Target RPE',
                      hintText: '8.0',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _tempoController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Tempo',
                      hintText: '3-1-1-0',
                      filled: true,
                      fillColor: AppColors.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Trainer Note
            TextField(
              controller: _adminNoteController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Trainer Coaching Directive',
                hintText: 'e.g. Keep elbows 45 deg, control 3s negative...',
                filled: true,
                fillColor: AppColors.surfaceCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _submit,
                child: Text(
                  widget.existingExercise != null ? 'SAVE CHANGES' : 'ADD TO WORKOUT',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
