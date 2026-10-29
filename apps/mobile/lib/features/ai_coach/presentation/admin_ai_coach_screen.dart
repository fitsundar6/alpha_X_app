import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/assigned_diet_plan.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/widgets/admin_ai_proposal_review_dialog.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_proposal_assignment_dialog.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_proposals_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/widgets/admin_three_step_plan_config_dialog.dart';

class AdminAiCoachScreen extends StatefulWidget {
  final AiCoachRepository? aiCoachRepository;
  final WorkoutRepository? workoutRepository;
  final MacroRepository? macroRepository;
  final String? initialClientId;
  final bool showAppBar;

  const AdminAiCoachScreen({
    super.key,
    this.aiCoachRepository,
    this.workoutRepository,
    this.macroRepository,
    this.initialClientId,
    this.showAppBar = true,
  });

  @override
  State<AdminAiCoachScreen> createState() => _AdminAiCoachScreenState();
}

class _AdminAiCoachScreenState extends State<AdminAiCoachScreen> with AutomaticKeepAliveClientMixin<AdminAiCoachScreen> {
  @override
  bool get wantKeepAlive => true;

  late final AiCoachRepository _repo;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiChatMessage> _messages = [];
  bool _isThinking = false;
  bool _isLoadingHistory = true;
  bool _historyLoadFailed = false;
  String? _conversationId;

  bool get _isTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  // Context Selectors
  String? _selectedClientId;
  String _selectedClientName = 'All Athletes';
  String _selectedDateRange = 'last_30_days';

  final List<String> _suggestedPrompts = [
    "Give me today's report",
    "Show clients needing review",
    "Who missed workouts today?",
    "Who has incomplete food tracking?",
    "Progress bench press",
    "Analyze selected client",
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.aiCoachRepository ?? AiCoachRepository();
    _selectedClientId = widget.initialClientId;

    // Resolve initial client name if provided
    if (_selectedClientId != null && widget.workoutRepository != null) {
      final match = widget.workoutRepository!.clientsList.firstWhere(
        (c) => c['clientId'] == _selectedClientId || c['id'] == _selectedClientId,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        _selectedClientName = match['name'] ?? _selectedClientId!;
      }
    }

    // Default welcome greeting
    _messages.add(_buildInitialWelcomeMessage());

    // Asynchronously restore persisted conversation history
    _loadHistory();
  }

  AiChatMessage _buildInitialWelcomeMessage() {
    return AiChatMessage(
      id: 'msg_welcome',
      sender: 'AI',
      content: '👋 **Welcome to the Alpha X Master AI Coach.**\n\nI am your single, centralized AI intelligence controller with direct access to athlete profiles, exercise databases, food libraries, performance records, and check-ins.\n\nSelect an athlete above or ask me facility-wide questions below.',
      intent: 'GREETING',
      suggestedFollowUps: [
        "Give me today's report",
        "Show clients needing review",
        "Who missed workouts today?",
      ],
    );
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyLoadFailed = false;
    });

    try {
      final session = await _repo.loadConversationLocally();
      if (!mounted) return;

      setState(() {
        if (session.messages.isNotEmpty) {
          _messages.clear();
          _messages.addAll(session.messages);
          _conversationId = session.conversationId;
        }
        _isLoadingHistory = false;
        _historyLoadFailed = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[AI COACH SCREEN] Error loading conversation history: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyLoadFailed = true;
      });
    }
  }

  void _persistCurrentConversation() {
    _repo.saveConversationLocally(
      messages: _messages,
      conversationId: _conversationId,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _isThinking) return;

    if (overrideText == null) {
      _textController.clear();
    }

    final userMessage = AiChatMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString().replaceAll('#', '')}',
      sender: 'ADMIN',
      content: text,
      intent: 'USER_QUERY',
    );

    setState(() {
      _messages.add(userMessage);
      _isThinking = true;
    });
    _persistCurrentConversation();
    _scrollToBottom();

    try {
      final aiReply = await _repo.sendMessage(
        message: text,
        conversationId: _conversationId,
        selectedClientId: _selectedClientId,
        dateRangePreset: _selectedDateRange,
      );

      if (mounted) {
        setState(() {
          if (aiReply.conversationId != null && aiReply.conversationId!.isNotEmpty) {
            _conversationId = aiReply.conversationId;
          }
          if (aiReply.verifiedClient != null) {
            _selectedClientId = aiReply.verifiedClient!.clientId;
            _selectedClientName = aiReply.verifiedClient!.displayName;
          }
          _messages.add(aiReply);
          _isThinking = false;
        });
        _persistCurrentConversation();
        _scrollToBottom();

        if (aiReply.proposal != null) {
          _repo.registerProposal(aiReply.proposal!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎯 ${aiReply.proposal!.title} staged in Proposals.'),
              backgroundColor: AppColors.surfaceElevated,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'REVIEW',
                textColor: AppColors.primaryRed,
                onPressed: () => _showProposalReviewDialog(aiReply.proposal!),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            AiChatMessage(
              id: 'msg_err_${DateTime.now().millisecondsSinceEpoch}',
              sender: 'AI',
              content: '⚠️ **Alpha X AI Coach is temporarily unavailable.**\n\nYour existing client data and plans are safe. Please check your connection and tap retry.',
              isError: true,
            ),
          );
          _isThinking = false;
        });
        _persistCurrentConversation();
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleNewChat() async {
    final newId = await _repo.startNewConversation();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _conversationId = newId;
      _messages.add(
        AiChatMessage(
          id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'AI',
          content: '👋 **Started a fresh Alpha X AI Coach session.**\n\nPrevious conversation context has been cleared. What would you like to explore?',
          intent: 'GREETING',
          suggestedFollowUps: [
            "Explain progressive overload for beginners",
            "What is RIR and how does it differ from RPE?",
            "How do I balance hypertrophy and strength?",
          ],
        ),
      );
    });
    _persistCurrentConversation();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Started new AI conversation session'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleApproveProposal(AiProposal proposal) async {
    if (proposal.type == AiProposalType.workout) {
      await AdminProposalAssignmentDialog.show(
        context: context,
        proposal: proposal,
        aiCoachRepository: _repo,
        workoutRepository: widget.workoutRepository ?? WorkoutRepository(),
        onAssigned: () {
          if (mounted) {
            setState(() {
              proposal.status = AiProposalStatus.approved;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✔ ${proposal.title} assigned and active!'),
                backgroundColor: AppColors.statusGreen,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );
      return;
    }

    final success = await _repo.approveProposal(
      proposal.id,
      clientIds: proposal.clientId != null ? [proposal.clientId!] : null,
      proposalData: proposal.toJson(),
    );
    if (success && mounted) {
      if (proposal.type == AiProposalType.diet && widget.macroRepository != null) {
        final dietPlan = _convertProposalToDietPlan(proposal);
        widget.macroRepository!.setAssignedDietPlan(dietPlan);
      }
      setState(() {
        proposal.status = AiProposalStatus.approved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✔ ${proposal.title} APPROVED and active!'),
          backgroundColor: AppColors.statusGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleRejectProposal(AiProposal proposal, [String? explicitReason]) async {
    final success = await _repo.rejectProposal(proposal.id, reason: explicitReason ?? 'Rejected by Admin');
    if (success && mounted) {
      setState(() {
        proposal.status = AiProposalStatus.rejected;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✖ ${proposal.title} REJECTED. Athlete current plan remains untouched.'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  // ignore: unused_element
  WorkoutSession _convertProposalToWorkoutSession(AiProposal proposal) {
    final payload = proposal.payload;
    final title = payload['title']?.toString() ?? proposal.title;
    final workoutType = payload['workoutType']?.toString() ?? 'Strength';
    final targetMuscleGroup = payload['targetMuscleGroup']?.toString() ?? 'Full Body';
    final difficulty = payload['difficulty']?.toString() ?? 'Intermediate';
    final estDuration = (payload['estimatedDurationMinutes'] as num?)?.toInt() ?? 45;
    final description = payload['description']?.toString() ?? proposal.summary;

    List<dynamic> rawExercises = [];
    if (payload['weeklySchedule'] is List && (payload['weeklySchedule'] as List).isNotEmpty) {
      // Isolate day: do NOT combine all days from weeklySchedule into one 30-exercise session!
      final firstDay = (payload['weeklySchedule'] as List).first;
      if (firstDay is Map && firstDay['exercises'] is List) {
        rawExercises = firstDay['exercises'] as List;
      }
    } else if (payload['exercises'] is List && (payload['exercises'] as List).isNotEmpty) {
      rawExercises = payload['exercises'] as List;
    } else if (payload['workoutPlan']?['sessions'] is List && (payload['workoutPlan']['sessions'] as List).isNotEmpty) {
      final firstSession = (payload['workoutPlan']['sessions'] as List).first;
      if (firstSession['exercises'] is List) {
        rawExercises = firstSession['exercises'] as List;
      }
    }

    final exercises = <WorkoutExercise>[];
    for (int i = 0; i < rawExercises.length; i++) {
      final raw = rawExercises[i];
      final exName = raw['exerciseName']?.toString() ?? raw['name']?.toString() ?? 'Exercise ${i + 1}';
      final exId = raw['exerciseId']?.toString() ?? raw['id']?.toString() ?? 'ex_$i';
      final category = raw['category']?.toString() ?? 'Strength';
      final setsCount = (raw['sets'] as num?)?.toInt() ?? 3;
      final targetWeight = (raw['targetWeight'] as num?)?.toDouble() ?? (raw['weight'] as num?)?.toDouble() ?? 50.0;
      final rpe = (raw['targetRpe'] as num?)?.toDouble() ?? (raw['rpe'] as num?)?.toDouble() ?? 8.0;
      final rir = (raw['targetRir'] as num?)?.toInt() ?? (raw['rir'] as num?)?.toInt() ?? 2;
      final rest = (raw['restSeconds'] as num?)?.toInt() ?? (raw['rest'] as num?)?.toInt() ?? 90;
      final tempo = raw['tempo']?.toString() ?? '3-1-1-0';
      final notes = raw['notes']?.toString() ?? '';

      int repsMin = 8;
      int repsMax = 10;
      final rawReps = raw['targetReps'] ?? raw['reps'];
      if (rawReps != null) {
        final parts = rawReps.toString().split(RegExp(r'[-–]'));
        if (parts.length == 2) {
          repsMin = int.tryParse(parts[0].trim()) ?? 8;
          repsMax = int.tryParse(parts[1].trim()) ?? 10;
        } else {
          final single = int.tryParse(rawReps.toString().trim());
          if (single != null) {
            repsMin = single;
            repsMax = single;
          }
        }
      }

      final setsList = List.generate(setsCount, (sIdx) {
        return ExerciseSet(
          id: 'set_${exId}_$sIdx',
          setNumber: sIdx + 1,
          setType: SetType.working,
          targetWeight: targetWeight,
          targetRepsMin: repsMin,
          targetRepsMax: repsMax,
          targetRpe: rpe,
          targetRir: rir,
          restSeconds: rest,
          tempo: tempo,
          notes: notes,
        );
      });

      exercises.add(
        WorkoutExercise(
          id: 'we_$i',
          exerciseId: exId,
          exerciseName: exName,
          category: category,
          primaryMusclesDisplay: targetMuscleGroup,
          secondaryMusclesDisplay: '',
          restSeconds: rest,
          tempo: tempo,
          trainerNote: notes,
          sets: setsList,
        ),
      );
    }

    return WorkoutSession(
      id: 'ai_draft_${proposal.id}',
      title: title,
      workoutType: workoutType,
      targetMuscleGroup: targetMuscleGroup,
      difficulty: difficulty,
      estimatedDurationMinutes: estDuration,
      description: description,
      exercises: exercises,
    );
  }

  AssignedDietPlan _convertProposalToDietPlan(AiProposal proposal) {
    final payload = proposal.payload;
    final planName = payload['planName']?.toString() ?? proposal.title;
    final calories = (payload['dailyCalories'] as num?)?.toDouble() ?? 2000.0;
    final protein = (payload['protein'] as num?)?.toDouble() ?? 150.0;
    final carbs = (payload['carbohydrates'] as num?)?.toDouble() ?? (payload['carbs'] as num?)?.toDouble() ?? 200.0;
    final fat = (payload['fat'] as num?)?.toDouble() ?? 60.0;
    final fiber = (payload['fiber'] as num?)?.toDouble() ?? 30.0;
    final water = (payload['waterTargetLiters'] as num?)?.toDouble() ?? (payload['water'] as num?)?.toDouble() ?? 3.5;
    final notes = payload['notes']?.toString() ?? proposal.summary;

    final prescribedMeals = <PrescribedMeal>[];
    if (payload['meals'] is List) {
      for (final m in (payload['meals'] as List)) {
        final mType = m['mealType']?.toString() ?? m['name']?.toString() ?? 'Meal';
        final timing = m['timing']?.toString() ??
            (mType.toLowerCase() == 'breakfast'
                ? '8:00 AM'
                : (mType.toLowerCase() == 'lunch'
                    ? '1:00 PM'
                    : (mType.toLowerCase() == 'snacks' ? '4:30 PM' : '8:00 PM')));
        final mNotes = m['notes']?.toString();

        final foods = <PrescribedFoodItem>[];
        final items = (m['items'] ?? m['foods'] ?? []) as List;
        for (final it in items) {
          final fId = it['foodId']?.toString();
          final fName = it['foodName']?.toString() ?? it['name']?.toString() ?? 'Food';
          final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
          final unit = it['unit']?.toString() ?? 'g';
          final cals = (it['calories'] as num?)?.toDouble() ?? 0.0;
          final pro = (it['protein'] as num?)?.toDouble() ?? 0.0;
          final crbs = ((it['carbs'] ?? it['carbohydrates']) as num?)?.toDouble() ?? 0.0;
          final ft = (it['fat'] as num?)?.toDouble() ?? 0.0;
          final fib = (it['fiber'] as num?)?.toDouble() ?? 0.0;

          foods.add(PrescribedFoodItem(
            foodId: fId,
            name: fName,
            quantity: qty,
            unit: unit,
            calories: cals,
            protein: pro,
            carbs: crbs,
            fat: ft,
            fiber: fib,
          ));
        }

        prescribedMeals.add(PrescribedMeal(
          mealType: mType,
          timing: timing,
          notes: mNotes,
          foods: foods,
        ));
      }
    }

    return AssignedDietPlan(
      id: 'ai_draft_diet_${proposal.id}',
      clientId: proposal.clientId ?? _selectedClientId ?? '',
      planName: planName,
      dailyCalories: calories,
      protein: protein,
      carbohydrates: carbs,
      fat: fat,
      fiber: fiber,
      waterTargetLiters: water,
      notes: notes,
      prescribedMeals: prescribedMeals,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _handleEditProposal(AiProposal proposal) async {
    if (proposal.type == AiProposalType.workout) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => WorkoutProposalDetailSheet(
          proposal: proposal,
          workoutRepository: widget.workoutRepository ?? WorkoutRepository(),
          aiCoachRepository: _repo,
          onProposalUpdated: () {
            if (mounted) {
              _repo.registerProposal(proposal);
              setState(() {});
            }
          },
        ),
      );
      return;
    } else if (proposal.type == AiProposalType.diet) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DietProposalDetailSheet(
          proposal: proposal,
          aiCoachRepository: _repo,
          onProposalUpdated: () {
            if (mounted) {
              _repo.registerProposal(proposal);
              setState(() {});
            }
          },
        ),
      );
    } else {
      _showEditProposalDialog(proposal);
    }
  }

  void _showProposalReviewDialog(AiProposal proposal) {
    AdminAiProposalReviewDialog.show(
      context: context,
      proposal: proposal,
      onAccept: () => _handleApproveProposal(proposal),
      onEdit: () => _handleEditProposal(proposal),
      onReject: (reason) => _handleRejectProposal(proposal, reason),
    );
  }

  void _showEditProposalDialog(AiProposal proposal) {
    final titleController = TextEditingController(text: proposal.title);
    final summaryController = TextEditingController(text: proposal.summary);
    final isDiet = proposal.type == AiProposalType.diet;
    final payload = Map<String, dynamic>.from(proposal.payload);

    final caloriesController = TextEditingController(text: (payload['dailyCalories'] ?? '').toString());
    final proteinController = TextEditingController(text: (payload['protein'] ?? '').toString());
    final carbsController = TextEditingController(text: (payload['carbohydrates'] ?? '').toString());
    final fatController = TextEditingController(text: (payload['fat'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                children: [
                  const Icon(Icons.edit_note, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'EDIT PROPOSAL: ${proposal.type.name.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Prescription Summary / Notes',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
                ),
              ),
              if (isDiet) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: caloriesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: proteinController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: carbsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fatController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final edited = Map<String, dynamic>.from(proposal.payload);
                      edited['title'] = titleController.text.trim();
                      edited['summary'] = summaryController.text.trim();

                      if (isDiet) {
                        if (int.tryParse(caloriesController.text.trim()) != null) {
                          edited['dailyCalories'] = int.parse(caloriesController.text.trim());
                        }
                        if (int.tryParse(proteinController.text.trim()) != null) {
                          edited['protein'] = int.parse(proteinController.text.trim());
                        }
                        if (int.tryParse(carbsController.text.trim()) != null) {
                          edited['carbohydrates'] = int.parse(carbsController.text.trim());
                        }
                        if (int.tryParse(fatController.text.trim()) != null) {
                          edited['fat'] = int.parse(fatController.text.trim());
                        }
                      }

                      final ok = await _repo.editProposal(proposal.id, edited);
                      if (ok && mounted) {
                        setState(() {
                          proposal.status = AiProposalStatus.edited;
                          proposal.payload = edited;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Proposal updated with your changes.')),
                        );
                      }
                    },
                    child: const Text('Save Modifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPendingProposalsModal() async {
    final proposals = await _repo.getProposals(status: 'PENDING');
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  const Text(
                    'PENDING AI PROPOSALS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'AI proposals require admin acceptance or edit before client assignment.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: proposals.isEmpty
                    ? const Center(
                        child: Text(
                          'No proposals currently pending review.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: proposals.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (pCtx, idx) {
                          final prop = proposals[idx];
                          return InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showProposalReviewDialog(prop);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.warningYellow.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    prop.type == AiProposalType.workout
                                        ? Icons.fitness_center
                                        : (prop.type == AiProposalType.diet ? Icons.restaurant_menu : Icons.trending_up),
                                    color: AppColors.primaryRed,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prop.title,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${prop.clientName ?? 'Athlete'} • ${prop.type.name.toUpperCase()}',
                                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.white54),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClientPicker() {
    final clients = widget.workoutRepository?.clientsList ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            final filtered = clients.where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              final name = (c['name'] ?? '').toLowerCase();
              final cId = (c['clientId'] ?? c['id'] ?? '').toLowerCase();
              final goal = (c['primaryGoal'] ?? '').toLowerCase();
              return name.contains(q) || cId.contains(q) || goal.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'SELECT ATHLETE CONTEXT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search athlete by name or client ID...',
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceCard,
                      child: Icon(Icons.groups, color: AppColors.textSecondary),
                    ),
                    title: const Text('All Athletes (Facility Command)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Facility-wide analytics & operational queries', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: _selectedClientId == null ? const Icon(Icons.check, color: AppColors.primaryRed) : null,
                    onTap: () {
                      setState(() {
                        _selectedClientId = null;
                        _selectedClientName = 'All Athletes';
                      });
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                  const Divider(color: AppColors.border),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching athletes found',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (cCtx, i) {
                              final c = filtered[i];
                              final cId = c['clientId'] ?? c['id'] ?? '';
                              final cName = c['name'] ?? 'Athlete';
                              final goal = c['primaryGoal'] ?? 'General Fitness';
                              final level = c['fitnessLevel'] ?? 'Intermediate';
                              final isSelected = _selectedClientId == cId;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.glowRed,
                                  child: Text(
                                    cName.isNotEmpty ? cName[0].toUpperCase() : 'A',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        cName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        cId,
                                        style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text('$goal • $level', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryRed) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedClientId = cId;
                                    _selectedClientName = cName;
                                  });
                                  Navigator.of(sheetCtx).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryRed, width: 1.5),
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ALPHA X AI COACH',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'MASTER INTELLIGENCE CONTROLLER',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('admin_ai_pending_proposals_button'),
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white70),
            tooltip: 'Pending Proposals',
            onPressed: _showPendingProposalsModal,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion_outlined, color: Colors.white70),
            tooltip: 'Workout Proposals',
            onPressed: _openWorkoutProposalsScreen,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              key: const Key('admin_ai_new_chat_button'),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceCard,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              icon: const Icon(Icons.add_comment_outlined, size: 15, color: AppColors.primaryRed),
              label: const Text('New Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _handleNewChat,
            ),
          ),
        ],
      )
    : null,
      body: Column(
        children: [
          _buildTopBanner(),

          // Control Bar: Client Context & Date Range Selector
          _buildControlHeader(),

          if (_isLoadingHistory)
            _isTestEnvironment
                ? const SizedBox(
                    key: Key('admin_ai_history_loading_indicator'),
                    height: 2.5,
                  )
                : const LinearProgressIndicator(
                    key: Key('admin_ai_history_loading_indicator'),
                    minHeight: 2.5,
                    color: AppColors.primaryRed,
                    backgroundColor: Colors.transparent,
                  ),

          if (_historyLoadFailed && _messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.amber.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Could not sync history from server. Showing cached conversation.',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadHistory,
                    child: const Text('RETRY', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Suggested Prompts
          _buildSuggestedPromptsBar(),

          // Messages View
          Expanded(
            child: _isLoadingHistory && _messages.isEmpty && !_isTestEnvironment
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Restoring conversation history...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : (_historyLoadFailed && _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: AppColors.primaryRed, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load conversation history',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _loadHistory,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length + (_isThinking ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (index == _messages.length && _isThinking) {
                            return _buildThinkingBubble();
                          }
                          final message = _messages[index];
                          return _buildMessageItem(message);
                        },
                      )),
          ),

          // Selected Athlete Context Card (Prominently shown before generating plan)
          _buildSelectedClientIdentityBanner(),

          // Message Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  void _openWorkoutProposalsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AdminWorkoutProposalsScreen(
          workoutRepository: widget.workoutRepository,
          aiCoachRepository: _repo,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Map<String, String>? get _currentSelectedClient {
    if (_selectedClientId == null) return null;
    final clients = widget.workoutRepository?.clientsList ?? [];
    return clients.firstWhere(
      (c) => c['clientId'] == _selectedClientId || c['id'] == _selectedClientId,
      orElse: () => {},
    );
  }

  Widget _buildSelectedClientIdentityBanner() {
    if (_selectedClientId == null) return const SizedBox.shrink();
    final client = _currentSelectedClient ?? {};
    final cId = client['clientId'] ?? client['id'] ?? _selectedClientId ?? '';
    final name = client['name'] ?? _selectedClientName;
    final goal = client['primaryGoal'] ?? 'General Fitness';
    final level = client['fitnessLevel'] ?? 'Intermediate';
    final days = client['trainingDaysPerWeek'] ?? '4';
    final injury = client['hasCurrentInjury'] == 'true' ? client['injuryAreas'] ?? 'Injury noted' : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.4), width: 1.2),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed.withOpacity(0.08),
            AppColors.surfaceCard,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_pin_outlined, size: 12, color: AppColors.primaryRed),
                    SizedBox(width: 4),
                    Text(
                      'ACTIVE ATHLETE CONTEXT',
                      style: TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _showClientPicker,
                child: const Text(
                  'Change Athlete',
                  style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedClientId = null;
                    _selectedClientName = 'All Athletes';
                  });
                },
                child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryRed,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            cId,
                            style: const TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$goal • $level • $days days/wk${injury != null ? ' • ⚠️ $injury' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Personalized Workout Plan for $_selectedClientName',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('admin_ai_three_step_config_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                    side: const BorderSide(color: AppColors.primaryRed, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.tune, color: AppColors.primaryRed, size: 16),
                  label: const Text(
                    '⚡ Three-Step Plan Configuration (Workout / Diet)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _isThinking ? null : () => _openThreeStepPlanConfig(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('admin_ai_workout_proposal_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.fitness_center, size: 14),
                      label: const Text(
                        'AI Workout Proposal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isThinking
                          ? null
                          : () => _openThreeStepPlanConfig(initialType: AiProposalType.workout),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('admin_ai_diet_macro_proposal_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.restaurant_menu, size: 14),
                      label: const Text(
                        'AI Diet / Macro Proposal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isThinking
                          ? null
                          : () => _openThreeStepPlanConfig(initialType: AiProposalType.diet),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openThreeStepPlanConfig({AiProposalType? initialType}) {
    AdminThreeStepPlanConfigDialog.show(
      context: context,
      aiCoachRepository: _repo,
      workoutRepository: widget.workoutRepository,
      initialClientId: _selectedClientId,
      initialPlanType: initialType,
      conversationId: _conversationId,
      onProposalCreated: (proposal) {
        if (mounted) {
          _repo.registerProposal(proposal);
          setState(() {
            _messages.add(
              AiChatMessage(
                id: 'msg_prop_${DateTime.now().millisecondsSinceEpoch}',
                sender: 'AI',
                content: '🎯 **${proposal.title}** created successfully and staged as **PENDING** in Admin Review.\n\nReview, customize, and approve or reject before client assignment.',
                intent: proposal.type == AiProposalType.workout ? 'WORKOUT_PROPOSAL' : 'DIET_PROPOSAL',
                proposal: proposal,
              ),
            );
          });
          _persistCurrentConversation();
          _scrollToBottom();
          // Promptly display the proposal review dialog for the staged proposal
          _showProposalReviewDialog(proposal);
        }
      },
    );
  }

  Widget _buildTopBanner() {
    if (widget.showAppBar) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryRed, width: 1),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ALPHA X AI COACH',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'MASTER INTELLIGENCE CONTROLLER',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion_outlined, color: Colors.white70, size: 20),
            tooltip: 'Workout Proposals',
            onPressed: _openWorkoutProposalsScreen,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            key: const Key('admin_ai_new_chat_button_embedded'),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surfaceCard,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            icon: const Icon(Icons.add_comment_outlined, size: 14, color: AppColors.primaryRed),
            label: const Text('New Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _handleNewChat,
          ),
        ],
      ),
    );
  }

  Widget _buildControlHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Client Context Selector
          Expanded(
            child: InkWell(
              onTap: _showClientPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedClientId != null ? AppColors.primaryRed : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedClientId != null ? Icons.person : Icons.groups,
                      size: 16,
                      color: _selectedClientId != null ? AppColors.primaryRed : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedClientName,
                        style: TextStyle(
                          color: _selectedClientId != null ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Date Range Selector
          PopupMenuButton<String>(
            initialValue: _selectedDateRange,
            onSelected: (val) {
              setState(() => _selectedDateRange = val);
            },
            color: AppColors.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _selectedDateRange == 'today'
                        ? 'Today'
                        : _selectedDateRange == 'this_week'
                            ? '7 Days'
                            : _selectedDateRange == 'last_90_days'
                                ? '90 Days'
                                : '30 Days',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'today', child: Text('Today', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'this_week', child: Text('Last 7 Days', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'last_30_days', child: Text('Last 30 Days', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'last_90_days', child: Text('Last 90 Days', style: TextStyle(color: Colors.white))),
            ],
          ),
          const SizedBox(width: 8),

          // Proposals Review Quick Button
          InkWell(
            onTap: _openWorkoutProposalsScreen,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningYellow.withOpacity(0.5), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fact_check, size: 14, color: AppColors.warningYellow),
                  SizedBox(width: 5),
                  Text(
                    'Proposals',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPromptsBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestedPrompts.length,
        itemBuilder: (ctx, i) {
          final prompt = _suggestedPrompts[i];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              label: Text(
                prompt,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _handleSendMessage(prompt),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRichText(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }

  Widget _buildCodeBlock(String code, String? language) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withOpacity(0.9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language != null && language.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Text(
                language.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              code,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12.5,
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    bool inCodeBlock = false;
    final codeBlockLines = <String>[];
    String? codeBlockLang;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Check for code block delimiter
      if (trimmed.startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          codeBlockLang = trimmed.substring(3).trim();
          codeBlockLines.clear();
        } else {
          inCodeBlock = false;
          widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), codeBlockLang));
          codeBlockLines.clear();
          codeBlockLang = null;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      // Headers (####, ###, ##, #)
      if (trimmed.startsWith('#### ') || trimmed.startsWith('### ') || trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final headerText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        final isMainHeader = trimmed.startsWith('# ') || trimmed.startsWith('## ');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: _buildRichText(
              headerText,
              TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isMainHeader ? 15.0 : 14.0,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }
      // Bullet items (- , • , * )
      else if (trimmed.startsWith('- ') || trimmed.startsWith('• ') || trimmed.startsWith('* ')) {
        final bulletText = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: _buildRichText(
                    bulletText,
                    const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Numbered lists (1. , 2. )
      else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: _buildRichText(
              trimmed,
              const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
      // Empty line spacing
      else if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      }
      // Standard line/paragraph
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildRichText(
              line,
              const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
            ),
          ),
        );
      }
    }

    // Flush any unclosed code block (e.g. streaming responses)
    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), codeBlockLang));
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage message) {
    if (message.isAdmin) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16).copyWith(bottomRight: Radius.zero),
            border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
          ),
          child: SelectionArea(
            child: Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
          ),
        ),
      );
    }

    // AI Message Bubble
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryRed, width: 1),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
                    border: Border.all(
                      color: message.isError ? AppColors.primaryRed : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Data Completeness Badge if available
                      if (message.completeness != null) ...[
                        _buildCompletenessBadge(message.completeness!),
                        const SizedBox(height: 12),
                      ],

                      // Message Body (Markdown-aware structured rendering)
                      _buildFormattedContent(message.content),

                      // RAG Knowledge Attribution Badge
                      if (message.retrievedKnowledgeIds != null && message.retrievedKnowledgeIds!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book, size: 12, color: AppColors.statusGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Grounded in Alpha X Knowledge (${message.retrievedKnowledgeIds!.length} sources)',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Verified Client Context Badge (Phase 7)
                      if (message.verifiedClient != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 12, color: AppColors.primaryRed),
                              const SizedBox(width: 5),
                              Text(
                                'Client: ${message.verifiedClient!.displayName} • ${message.verifiedClient!.clientId}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Retry action for error messages
                      if (message.isError) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            final lastUserMsg = _messages.reversed.firstWhere(
                              (m) => m.isAdmin,
                              orElse: () => _messages.first,
                            );
                            _handleSendMessage(lastUserMsg.content);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryRed),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Retry Request', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Proposal Card Widget
                      if (message.proposal != null) ...[
                        const SizedBox(height: 14),
                        _buildProposalCard(message.proposal!),
                      ],

                      // Report Card Widget
                      if (message.reportCard != null) ...[
                        const SizedBox(height: 14),
                        _buildReportCard(message.reportCard!),
                      ],
                    ],
                  ),
                ),

                // Suggested Follow-up chips
                if (message.suggestedFollowUps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: message.suggestedFollowUps.map((p) {
                      return InkWell(
                        onTap: () => _handleSendMessage(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                          ),
                          child: Text(
                            p,
                            style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletenessBadge(AiDataCompleteness completeness) {
    final isHigh = completeness.scorePercentage >= 80;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isHigh ? AppColors.statusGreen : AppColors.warningYellow).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isHigh ? AppColors.statusGreen : AppColors.warningYellow).withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHigh ? Icons.verified : Icons.info_outline,
            size: 14,
            color: isHigh ? AppColors.statusGreen : AppColors.warningYellow,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${completeness.scorePercentage}% Data Complete — ${completeness.missingItems.isEmpty ? 'All metrics verified' : completeness.missingItems.first}',
              style: TextStyle(
                color: isHigh ? AppColors.statusGreen : AppColors.warningYellow,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalCard(AiProposal proposal) {
    Color statusColor;
    String statusLabel;

    switch (proposal.status) {
      case AiProposalStatus.approved:
        statusColor = AppColors.statusGreen;
        statusLabel = 'APPROVED & ACTIVE';
        break;
      case AiProposalStatus.rejected:
        statusColor = AppColors.primaryRed;
        statusLabel = 'REJECTED';
        break;
      case AiProposalStatus.edited:
        statusColor = Colors.lightBlueAccent;
        statusLabel = 'EDITED BY ADMIN';
        break;
      case AiProposalStatus.pending:
        statusColor = AppColors.warningYellow;
        statusLabel = 'PENDING ADMIN APPROVAL';
        break;
    }

    return InkWell(
      onTap: () => _showProposalReviewDialog(proposal),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                Text(
                  proposal.type.name.toUpperCase(),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              proposal.title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
            ),
            if (proposal.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                proposal.summary,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            if (proposal.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: ${proposal.reason}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 10),

            // Tap hint
            Row(
              children: [
                const Icon(Icons.touch_app, size: 12, color: Colors.lightBlueAccent),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Tap to inspect complete breakdown & analysis',
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.white54),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons: Edit, Approve, Reject (Strict 3 actions)
            if (proposal.status == AiProposalStatus.pending || proposal.status == AiProposalStatus.edited) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryRed),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _handleRejectProposal(proposal),
                      child: const Text('Reject', style: TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _handleEditProposal(proposal),
                      child: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusGreen,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _handleApproveProposal(proposal),
                      child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  proposal.status == AiProposalStatus.approved
                      ? '✔ Active client plan updated in Alpha X database.'
                      : '✖ Proposal closed without altering active plan.',
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(AiReportCard card) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (card.workoutsCompleted != null)
                _reportTile('Workouts', '${card.workoutsCompleted}', Icons.fitness_center),
              if (card.foodLogsRecorded != null)
                _reportTile('Food Logs', '${card.foodLogsRecorded}', Icons.restaurant),
              if (card.checkInsPending != null)
                _reportTile('Pending Check-Ins', '${card.checkInsPending}', Icons.assignment_outlined),
              if (card.clientsNeedReview != null)
                _reportTile('Need Review', '${card.clientsNeedReview}', Icons.warning_amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: AppColors.primaryRed),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 48),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryRed, width: 1),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                ),
                SizedBox(width: 10),
                Text(
                  'Alpha X AI Coach is analyzing records...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSendMessage(),
                decoration: InputDecoration(
                  hintText: _selectedClientId != null
                      ? 'Ask about $_selectedClientName...'
                      : 'Ask Alpha X AI Coach anything...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.primaryRed),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _isThinking ? null : () => _handleSendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
