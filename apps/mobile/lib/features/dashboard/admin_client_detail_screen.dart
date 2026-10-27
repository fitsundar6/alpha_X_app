import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/admin_weekly_progress_screen.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_transformation_timeline_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';
import 'package:alpha_x_gym/features/dashboard/admin_create_edit_diet_plan_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_assign_session_dialog.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_create_edit_session_screen.dart';
import 'package:alpha_x_gym/features/dashboard/widgets/admin_meal_photo_viewer_dialog.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/profile/admin_edit_client_profile_screen.dart';

/// Reconstructed Alpha X Admin Client Hub
/// Provides instant access to the THREE CORE AREAS for an individual athlete:
/// 1. PROFILE (Factual client data, demographics, health assessments, goals)
/// 2. WORKOUT (Real logged workout performance records from PostgreSQL database)
/// 3. NUTRITION (What client actually ate today, factual macros, meal photos)
class AdminClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final WorkoutRepository workoutRepository;
  final MacroRepository macroRepository;
  final ActivityRepository? activityRepository;
  final WeeklyProgressRepository? weeklyProgressRepository;
  final int initialTabIndex;

  const AdminClientDetailScreen({
    super.key,
    required this.client,
    required this.workoutRepository,
    required this.macroRepository,
    this.activityRepository,
    this.weeklyProgressRepository,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminClientDetailScreen> createState() => _AdminClientDetailScreenState();
}

class _AdminClientDetailScreenState extends State<AdminClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _clientData;

  // Profile State
  bool _isLoadingProfile = false;
  final TextEditingController _notesController = TextEditingController();
  bool _isSavingNotes = false;

  // Workout State
  bool _isLoadingWorkouts = false;
  List<WorkoutRecord> _workoutRecords = [];

  // Assigned workout split for this client
  WorkoutSplitPlan? _clientWorkoutSplit;
  bool _isLoadingSplit = false;

  // Nutrition State
  DateTime _selectedNutritionDate = DateTime.now();
  bool _isLoadingNutrition = false;
  Map<String, dynamic>? _nutritionSummary;
  String _selectedMealFilter = 'ALL';

  String get _clientId =>
      _clientData['id']?.toString() ??
      _clientData['clientId']?.toString() ??
      '';

  String get _displayId =>
      _clientData['clientId']?.toString() ?? _clientId;

  String get _clientName =>
      _clientData['name']?.toString() ?? 'Athlete';

  String get _nutritionDateStr =>
      DateFormat('yyyy-MM-dd').format(_selectedNutritionDate);

  @override
  void initState() {
    super.initState();
    _clientData = Map<String, dynamic>.from(widget.client);
    _notesController.text = _clientData['adminNotes']?.toString() ?? '';
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );

    _loadLiveProfile();
    _loadWorkoutHistory();
    _loadClientWorkoutSplit();
    _loadNutritionSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- DATA LOADERS ---

  Future<void> _loadLiveProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final fresh = await widget.workoutRepository.fetchClientProfile(_clientId);
      if (fresh != null && mounted) {
        setState(() {
          _clientData = {..._clientData, ...fresh};
          if (fresh['adminNotes'] != null) {
            _notesController.text = fresh['adminNotes'].toString();
          }
        });
      }
    } catch (_) {
      // Keep cached client data safely
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadClientWorkoutSplit() async {
    if (!mounted) return;
    setState(() => _isLoadingSplit = true);
    try {
      final split = await widget.workoutRepository.fetchClientWorkoutSplit(_clientId);
      if (mounted) setState(() => _clientWorkoutSplit = split);
    } catch (_) {
      // Non-fatal: split section will show empty state
    } finally {
      if (mounted) setState(() => _isLoadingSplit = false);
    }
  }

  Future<void> _loadWorkoutHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingWorkouts = true);
    try {
      final list = await widget.workoutRepository.fetchClientWorkoutHistory(_clientId, forceRefresh: true);
      if (mounted) {
        setState(() {
          _workoutRecords = list;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _workoutRecords = widget.workoutRepository.getClientWorkoutHistory(_clientId);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingWorkouts = false);
    }
  }

  Future<void> _loadNutritionSummary() async {
    if (!mounted) return;
    setState(() => _isLoadingNutrition = true);
    try {
      final summary = await widget.macroRepository.fetchAdminNutritionSummary(_clientId, _nutritionDateStr);
      if (mounted) {
        setState(() {
          _nutritionSummary = summary;
        });
      }
    } catch (_) {
      // Handled cleanly with empty state
    } finally {
      if (mounted) setState(() => _isLoadingNutrition = false);
    }
  }

  Future<void> _saveAdminNotes() async {
    setState(() => _isSavingNotes = true);
    try {
      final text = _notesController.text.trim();
      final success = await widget.workoutRepository.saveAdminNotes(_clientId, text);
      if (!mounted) return;
      if (success) {
        _clientData['adminNotes'] = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coach notes saved to database.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save notes. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNotes = false);
    }
  }

  void _openAssignWorkoutDialog() {
    final sessions = widget.workoutRepository.adminSessions;
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No workout sessions found. Create a session first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assign Workout to $_clientName',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Select a session from the gym library to assign:',
                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (ctx, i) {
                    final session = sessions[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        title: Text(
                          session.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${session.workoutType} • ${session.targetMuscleGroup} • ${session.exercises.length} exercises',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            showDialog(
                              context: context,
                              builder: (_) => AdminAssignSessionDialog(
                                session: session,
                                workoutRepository: widget.workoutRepository,
                              ),
                            );
                          },
                          child: const Text('ASSIGN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

  void _openCreateEditDiet() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => AdminCreateEditDietPlanScreen(
          client: _clientData,
          macroRepository: widget.macroRepository,
        ),
      ),
    );
    if (updated == true) {
      _loadNutritionSummary();
      AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Admin updated client diet plan');
    }
  }

  void _openAskAiCoach() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminAiCoachScreen(
          workoutRepository: widget.workoutRepository,
          macroRepository: widget.macroRepository,
          initialClientId: _clientId,
        ),
      ),
    );
  }

  void _openEditClientProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminEditClientProfileScreen(
          client: _clientData,
          workoutRepository: widget.workoutRepository,
        ),
      ),
    );
    if (updated == true && mounted) {
      // Reload the live profile so all displayed data is up-to-date
      _loadLiveProfile();
      AppAutoRefreshService.instance.triggerImmediateSync(
        reason: 'Admin edited client profile',
      );
    }
  }

  Future<void> _sendTestPushNotification() async {
    final titleController = TextEditingController(text: '⚡ Alpha X Coach Alert');
    final bodyController = TextEditingController(text: 'Hydration and training reminder from your coach.');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.primaryRed, size: 22),
            const SizedBox(width: 8),
            Text(
              'Targeted Push Notification',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispatch a real OneSignal push notification to $_clientName ($_displayId) targeted by their linked OneSignal External ID.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Target: External ID ($_clientId)',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fitness Engagement Presets:',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _presetChip(
                      label: '💧 Hydration',
                      onTap: () {
                        setDialogState(() {
                          titleController.text = 'Stay Hydrated 💧';
                          bodyController.text = 'Stay Hydrated 💧 Time to drink some water!';
                        });
                      },
                    ),
                    _presetChip(
                      label: '🥚 Protein Goal',
                      onTap: () {
                        setDialogState(() {
                          titleController.text = 'Protein Check 🥚';
                          bodyController.text = 'Protein Check 🥚 How close are you to your daily protein goal?';
                        });
                      },
                    ),
                    _presetChip(
                      label: '💪 Motivation',
                      onTap: () {
                        setDialogState(() {
                          titleController.text = 'Ready to Grind? 💪';
                          bodyController.text = "Ready to Grind? 💪 Let's make today's workout count!";
                        });
                      },
                    ),
                    _presetChip(
                      label: '🔥 Consistency',
                      onTap: () {
                        setDialogState(() {
                          titleController.text = 'Stay Consistent 🔥';
                          bodyController.text = 'Consistency beats motivation. Show up for yourself today 🔥';
                        });
                      },
                    ),
                    _presetChip(
                      label: '😴 Recovery',
                      onTap: () {
                        setDialogState(() {
                          titleController.text = 'Recovery Matters 😴';
                          bodyController.text = 'Recovery matters 😴 Get enough rest and come back stronger.';
                        });
                      },
                    ),
                    _presetChip(
                      label: '🎯 Goal Check',
                      onTap: () {
                        setDialogState(() {
                          titleController.text = 'Goal Check-In 🎯';
                          bodyController.text = 'Small steps. Strong habits. Keep moving toward your goal!';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SEND PUSH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/notifications/admin/send-to-client');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'clientId': _clientId,
          'title': titleController.text.trim(),
          'body': bodyController.text.trim(),
          'targetMethod': 'EXTERNAL_ID',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (!mounted) return;

      if (res.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        final gateway = payload?['gatewayResponse'];
        final notificationId = payload?['notificationId']?.toString() ?? gateway?['details']?['id']?.toString() ?? 'N/A';
        final isSuccess = gateway?['success'] == true;

        await _showPushResultDialog(
          title: isSuccess ? 'Push Notification Dispatched' : 'Dispatch Partially Processed',
          isSuccess: isSuccess,
          notificationId: notificationId,
          clientName: _clientName,
          clientId: _displayId,
          externalId: _clientId,
          httpStatus: res.statusCode,
          errorMsg: gateway?['error']?.toString(),
        );
      } else {
        final msg = data['error']?['message'] ?? 'Failed to send push notification';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _presetChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showPushResultDialog({
    required String title,
    required bool isSuccess,
    required String notificationId,
    required String clientName,
    required String clientId,
    required String externalId,
    required int httpStatus,
    String? errorMsg,
  }) async {
    Map<String, dynamic>? liveReport;
    bool isCheckingLive = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: isSuccess ? Colors.greenAccent : Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailResultRow('Recipient', '$clientName ($clientId)'),
                  const SizedBox(height: 6),
                  _detailResultRow('External ID', externalId),
                  const SizedBox(height: 6),
                  _detailResultRow('Notification ID', notificationId),
                  const SizedBox(height: 6),
                  _detailResultRow('Gateway Status', 'HTTP $httpStatus (${isSuccess ? "ACCEPTED" : "REJECTED"})'),
                  if (errorMsg != null && errorMsg.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text('Error: $errorMsg', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                    ),
                  ],
                  const Divider(color: Colors.white12, height: 20),
                  const Text(
                    'DELIVERY LIFECYCLE',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  _lifecycleStageRow('Stage 1: API Acceptance', isSuccess, 'Payload accepted by OneSignal REST API'),
                  _lifecycleStageRow(
                    'Stage 2: Gateway Transmission',
                    isSuccess,
                    liveReport != null
                        ? 'Successful dispatches to FCM/APNs: ${liveReport!['successful']} (Remaining: ${liveReport!['remaining']})'
                        : 'Dispatched to push provider gateway',
                  ),
                  _lifecycleStageRow('Stage 3: Physical Device Display', false, 'Requires client device connectivity & notification permission'),
                  if (liveReport != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LIVE ONESIGNAL DELIVERY REPORT', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Successful Deliveries: ${liveReport!['successful']}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          Text('Failed / Inactive: ${liveReport!['failed']}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Text('Remaining In-Flight: ${liveReport!['remaining']}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (notificationId != 'N/A')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isCheckingLive
                            ? null
                            : () async {
                                setDialogState(() { isCheckingLive = true; });
                                try {
                                  final token = await AuthService().getValidToken();
                                  final statusUrl = Uri.parse('${AppConstants.apiBaseUrl}/notifications/admin/delivery-status/$notificationId');
                                  final statusRes = await http.get(
                                    statusUrl,
                                    headers: { 'Authorization': 'Bearer $token' },
                                  ).timeout(const Duration(seconds: 10));
                                  if (statusRes.statusCode == 200) {
                                    final reportData = jsonDecode(statusRes.body);
                                    if (reportData['success'] == true) {
                                      setDialogState(() { liveReport = reportData['data']; });
                                    }
                                  }
                                } catch (_) {} finally {
                                  setDialogState(() { isCheckingLive = false; });
                                }
                              },
                        icon: isCheckingLive
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(isCheckingLive ? 'Querying OneSignal...' : 'Check Live Delivery Status', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailResultRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _lifecycleStageRow(String stage, bool isDone, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: isDone ? Colors.greenAccent : Colors.white30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage, style: TextStyle(color: isDone ? Colors.greenAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final photoUrl = _clientData['photoUrl']?.toString();
    final isOnboarded = _clientData['onboardingCompleted'] == true || _clientData['onboardingCompleted'] == 'true';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: colors.primary,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      _clientName.isNotEmpty ? _clientName.substring(0, 1).toUpperCase() : 'A',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _clientName,
                    style: GoogleFonts.poppins(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _displayId,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnboarded ? AppColors.success : Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnboarded ? 'Active' : 'Pending',
                        style: TextStyle(
                          color: isOnboarded ? AppColors.success : Colors.orangeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined, color: AppColors.accentRed, size: 22),
            tooltip: 'Ask AI Coach About Client',
            onPressed: _openAskAiCoach,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.textSecondary),
            color: colors.surfaceCard,
            onSelected: (val) {
              if (val == 'edit_profile') {
                _openEditClientProfile();
              } else if (val == 'progress') {
                if (widget.weeklyProgressRepository != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminWeeklyProgressScreen(
                        repository: widget.weeklyProgressRepository!,
                        initialClientId: _clientId,
                      ),
                    ),
                  );
                }
              } else if (val == 'timeline') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClientTransformationTimelineScreen(
                      adminTargetClientId: _clientId,
                      athleteName: _clientName,
                    ),
                  ),
                );
              } else if (val == 'test_push') {
                _sendTestPushNotification();
              } else if (val == 'refresh') {
                _loadLiveProfile();
                _loadWorkoutHistory();
                _loadNutritionSummary();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit_profile',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryRed),
                    SizedBox(width: 10),
                    Text('Edit Client Profile', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_push',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: Colors.greenAccent),
                    SizedBox(width: 10),
                    Text('Send Test Push Notification', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'progress',
                child: Row(
                  children: [
                    Icon(Icons.insights, size: 18, color: AppColors.gold),
                    SizedBox(width: 10),
                    Text('Weekly Progress Review', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'timeline',
                child: Row(
                  children: [
                    Icon(Icons.timeline, size: 18, color: Colors.lightBlueAccent),
                    SizedBox(width: 10),
                    Text('Transformation Timeline', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Refresh Client Data', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
          tabs: const [
            Tab(text: '👤 PROFILE'),
            Tab(text: '🏋️ WORKOUT'),
            Tab(text: '🥗 NUTRITION'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(colors),
          _buildWorkoutTab(colors),
          _buildNutritionTab(colors),
        ],
      ),
    );
  }

  // ==========================================
  // CORE SECTION 1: PROFILE
  // ==========================================
  Widget _buildProfileTab(ClientThemeColors colors) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
    }

    final email = _clientData['email']?.toString() ?? 'Not specified';
    final phone = _clientData['phone']?.toString().isNotEmpty == true ? _clientData['phone'].toString() : 'Not recorded';
    final age = _clientData['age']?.toString() ?? '—';
    final height = _clientData['heightCm']?.toString() ?? '—';
    final weight = _clientData['weightKg']?.toString() ?? '—';
    final gender = _clientData['gender']?.toString() ?? 'Not specified';

    final fitnessLevel = (_clientData['fitnessLevel']?.toString() ?? 'Beginner').toUpperCase();
    final primaryGoal = _clientData['primaryGoal']?.toString() ?? 'General Fitness';
    final secondaryGoal = _clientData['secondaryGoal']?.toString() ?? 'None';
    final trainingExperience = _clientData['trainingExperience']?.toString() ?? 'Not specified';
    final daysPerWeek = _clientData['trainingDaysPerWeek']?.toString() ?? '4';
    final preferredDays = _formatList(_clientData['preferredDays']);
    final trainingTimePref = _clientData['trainingTimePref']?.toString() ?? 'Flexible';

    final hasInjury = _clientData['hasCurrentInjury'] == true || _clientData['hasCurrentInjury'] == 'true';
    final injuryAreas = _formatList(_clientData['injuryAreas']);
    final injuryDetails = _clientData['injuryDescription']?.toString() ?? _clientData['injuryDetails']?.toString() ?? 'None';

    final hasSurgery = _clientData['hasPreviousSurgery'] == true || _clientData['hasPreviousSurgery'] == 'true';
    final surgeryDetails = _clientData['surgeryDetails']?.toString() ?? 'None';

    final activityLevel = _clientData['activityLevel']?.toString() ?? 'MODERATE';
    final sleepHours = _clientData['sleepHours']?.toString() ?? '7–8 hours';

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadLiveProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Action Command Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.fitness_center, size: 16, color: Colors.white),
                  label: const Text('ASSIGN WORKOUT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  onPressed: _openAssignWorkoutDialog,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surfaceCard,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.restaurant_menu, size: 16, color: AppColors.accentRed),
                  label: const Text('UPDATE DIET', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  onPressed: _openCreateEditDiet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryRed),
              label: const Text('EDIT CLIENT PROFILE', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900)),
              onPressed: _openEditClientProfile,
            ),
          ),
          const SizedBox(height: 16),

          // 1. Biometrics & Identity Card
          _buildCard(
            colors: colors,
            title: 'PHYSICAL METRICS & CONTACT',
            icon: Icons.person_outline,
            children: [
              _buildDataRow('Email', email),
              _buildDataRow('Phone', phone),
              _buildDataRow('Age', age != '—' ? '$age years' : 'Not recorded'),
              _buildDataRow('Height', height != '—' ? '$height cm' : 'Not recorded'),
              _buildDataRow('Current Weight', weight != '—' ? '$weight kg' : 'Not recorded'),
              _buildDataRow('Gender', gender),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Fitness & Training Goals Card
          _buildCard(
            colors: colors,
            title: 'TRAINING GOALS & EXPERIENCE',
            icon: Icons.emoji_events_outlined,
            children: [
              _buildDataRow('Fitness Level', fitnessLevel, isHighlight: true),
              _buildDataRow('Primary Goal', primaryGoal),
              _buildDataRow('Secondary Goal', secondaryGoal),
              _buildDataRow('Experience', trainingExperience),
              _buildDataRow('Training Days', '$daysPerWeek days / week'),
              _buildDataRow('Preferred Days', preferredDays),
              _buildDataRow('Training Time', trainingTimePref),
            ],
          ),
          const SizedBox(height: 14),

          // 2.5 Athlete Before & After Transformation Progress Card
          _buildCard(
            colors: colors,
            title: 'BEFORE & AFTER TRANSFORMATION',
            icon: Icons.compare_arrows_rounded,
            trailing: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14, color: AppColors.gold),
              label: const Text('OPEN GALLERY', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClientTransformationTimelineScreen(
                      adminTargetClientId: _clientId,
                      athleteName: _clientName,
                    ),
                  ),
                );
              },
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compare Baseline vs Protocol Milestones',
                            style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Inspect front, side, and back physique photos, weight changes, waist delta, and protocol progress.',
                            style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClientTransformationTimelineScreen(
                              adminTargetClientId: _clientId,
                              athleteName: _clientName,
                            ),
                          ),
                        );
                      },
                      child: const Text('COMPARE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Health, Injury & Surgery Information Card
          _buildCard(
            colors: colors,
            title: 'HEALTH & INJURY SAFETY',
            icon: Icons.health_and_safety_outlined,
            children: [
              _buildStatusPillRow(
                'Current Injury/Pain',
                hasInjury ? 'REPORTED' : 'NONE REPORTED',
                hasInjury ? Colors.amber : AppColors.success,
              ),
              if (hasInjury) ...[
                _buildDataRow('Affected Areas', injuryAreas),
                _buildDataRow('Injury Notes', injuryDetails),
              ],
              const SizedBox(height: 6),
              _buildStatusPillRow(
                'Previous Surgeries',
                hasSurgery ? 'REPORTED' : 'NONE REPORTED',
                hasSurgery ? Colors.purpleAccent : AppColors.success,
              ),
              if (hasSurgery) ...[
                _buildDataRow('Surgery Details', surgeryDetails),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // 4. Daily Lifestyle & Activity Card
          _buildCard(
            colors: colors,
            title: 'LIFESTYLE & DAILY ACTIVITY',
            icon: Icons.nightlife_rounded,
            children: [
              _buildDataRow('Activity Level', activityLevel),
              _buildDataRow('Sleep Schedule', sleepHours),
            ],
          ),
          const SizedBox(height: 14),

          // 5. Coach Admin Notes Card
          _buildCard(
            colors: colors,
            title: 'TRAINER / COACH PRIVATE NOTES',
            icon: Icons.edit_note_rounded,
            children: [
              TextField(
                controller: _notesController,
                maxLines: 4,
                style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter coach observations, program adjustments, athlete notes...',
                  hintStyle: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 12),
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _isSavingNotes ? null : _saveAdminNotes,
                  icon: _isSavingNotes
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16, color: Colors.white),
                  label: const Text('SAVE COACH NOTES', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ==========================================
  // CORE SECTION 2: WORKOUT (ASSIGNED PLAN + PERFORMANCE)
  // ==========================================

  /// Opens [AdminCreateEditSessionScreen] for one individual split day.
  /// Only that session is mutated — other days are untouched.
  void _openEditSplitDay(WorkoutSplitDay day) async {
    // 1. Resolve WorkoutSession from cache or by fetching
    WorkoutSession? session = day.sessionId != null
        ? widget.workoutRepository.adminSessions
            .where((s) => s.id == day.sessionId)
            .firstOrNull
        : null;

    if (session == null && day.sessionId != null) {
      session = await widget.workoutRepository.getSessionById(day.sessionId!);
      if (!mounted) return;
    }

    // 2. If not materialized, synthesize session from day so admin can edit independently
    session ??= WorkoutSession(
      id: day.sessionId ?? 'ws_${_clientWorkoutSplit?.id ?? _clientId}_${day.dayOfWeek}',
      title: day.name,
      workoutType: day.workoutType,
      targetMuscleGroup: day.targetMuscleGroup,
      difficulty: 'Intermediate',
      estimatedDurationMinutes: day.estimatedDurationMinutes > 0 ? day.estimatedDurationMinutes : 45,
      description: day.notes,
      recurringSchedule: day.dayOfWeek,
      assignedClientIds: [_clientId],
      isRecommended: day.dayIndex == 1,
      exercises: List.from(day.exercises),
    );

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateEditSessionScreen(
          workoutRepository: widget.workoutRepository,
          sessionToEdit: session,
          parentSplit: _clientWorkoutSplit,
          splitDay: day,
          clientIdToAssign: _clientId,
          startInSplitMode: false,
          onSaved: () {},
        ),
      ),
    );

    if (saved == true && mounted) {
      _loadClientWorkoutSplit();
      widget.workoutRepository.fetchAdminSessions(forceRefresh: true);
    }
  }

  /// Opens [AdminCreateEditSessionScreen] in full-split mode for this client.
  void _openEditFullSplit() async {
    final split = _clientWorkoutSplit;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateEditSessionScreen(
          workoutRepository: widget.workoutRepository,
          splitToEdit: split,
          clientIdToAssign: _clientId,
          onSaved: () {},
        ),
      ),
    );
    if (saved == true && mounted) {
      _loadClientWorkoutSplit();
      widget.workoutRepository.fetchAdminSessions(forceRefresh: true);
    }
  }

  Widget _buildWorkoutTab(ClientThemeColors colors) {
    final totalVolume = _workoutRecords.fold(0.0, (acc, r) => acc + r.totalVolume);
    final totalHours = (_workoutRecords.fold(0, (acc, r) => acc + r.durationSeconds) / 3600).toStringAsFixed(1);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async {
        await Future.wait([_loadWorkoutHistory(), _loadClientWorkoutSplit()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── CURRENT WORKOUT PLAN SECTION ──────────────────────────────
          _buildCurrentPlanSection(colors),
          const SizedBox(height: 24),

          // ── PERFORMANCE STATS BAR ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMetric('COMPLETED', '${_workoutRecords.length}', AppColors.success),
                _buildStatMetric('TOTAL VOLUME', '${totalVolume.toInt()} kg', colors.primary),
                _buildStatMetric('TIME TRAINED', '$totalHours hrs', AppColors.info),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── LOGGED SESSION HISTORY ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOGGED SESSIONS (${_workoutRecords.length})',
                style: GoogleFonts.poppins(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: AppColors.primaryRed),
                label: const Text('+ ASSIGN SESSION',
                    style: TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
                onPressed: _openAssignWorkoutDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingWorkouts && _workoutRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
            )
          else if (_workoutRecords.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.fitness_center_outlined, size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No Workout Logs Yet',
                    style: GoogleFonts.poppins(
                        color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When $_clientName performs their assigned sessions in the client app, exact sets, reps, weights, RIR, and rest times will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                    onPressed: _openAssignWorkoutDialog,
                    icon: const Icon(Icons.assignment, size: 16, color: Colors.white),
                    label: const Text('ASSIGN WORKOUT NOW',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            )
          else
            ..._workoutRecords.map((record) => _buildWorkoutRecordCard(record, colors)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // CURRENT WORKOUT PLAN — editable split card
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildCurrentPlanSection(ClientThemeColors colors) {
    if (_isLoadingSplit) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
    }

    final split = _clientWorkoutSplit;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 18, color: AppColors.primaryRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        split != null
                            ? (split.title.isNotEmpty ? split.title : 'WORKOUT PLAN')
                            : 'WORKOUT PLAN',
                        style: GoogleFonts.poppins(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (split != null)
                        Text(
                          '${split.days.where((d) => !d.isRestDay).length} training days/week',
                          style: GoogleFonts.poppins(
                              color: colors.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                // Edit full split button
                if (split != null)
                  TextButton.icon(
                    onPressed: _openEditFullSplit,
                    icon: const Icon(Icons.edit_note_rounded,
                        size: 15, color: AppColors.primaryRed),
                    label: const Text('EDIT PLAN',
                        style: TextStyle(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          if (split == null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.fitness_center_outlined,
                      size: 36, color: AppColors.textTertiary),
                  const SizedBox(height: 10),
                  Text(
                    'No Workout Plan Assigned',
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate an AI plan from the AI Coach tab, or assign a session manually.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: colors.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: _openEditFullSplit,
                    icon: const Icon(Icons.add, size: 15, color: Colors.white),
                    label: const Text('CREATE WORKOUT PLAN',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                ],
              ),
            )
          else
            // Day-by-day split cards
            ...split.days.map((day) => _buildSplitDayEditCard(day, colors)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSplitDayEditCard(WorkoutSplitDay day, ClientThemeColors colors) {
    final isRest = day.isRestDay;
    final exCount = day.exercises.length;

    // Determine color accent per day
    final Color dayAccent = _dayAccentColor(day.dayOfWeek);

    return InkWell(
      onTap: () => _openEditSplitDay(day),
      borderRadius: BorderRadius.circular(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.6),
          ),
          color: isRest ? Colors.transparent : null,
        ),
        child: Row(
          children: [
            // Day chip
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRest
                    ? AppColors.surfaceElevated
                    : dayAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRest ? AppColors.border : dayAccent.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: Text(
                  day.dayOfWeek.substring(0, 3).toUpperCase(),
                  style: TextStyle(
                    color: isRest ? AppColors.textDisabled : dayAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + muscle group
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.name,
                    style: GoogleFonts.poppins(
                      color: isRest
                          ? colors.textTertiary
                          : colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isRest
                        ? 'Rest & Recovery (Tap to add session)'
                        : '$exCount exercise${exCount == 1 ? '' : 's'} • ${day.targetMuscleGroup}',
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Edit button or rest label
            if (isRest)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'REST',
                      style: TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.edit_outlined,
                        size: 11, color: AppColors.textSecondary),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primaryRed.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit_outlined,
                        size: 13, color: AppColors.primaryRed),
                    SizedBox(width: 4),
                    Text(
                      'EDIT',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _dayAccentColor(String dayOfWeek) {
    switch (dayOfWeek.toLowerCase()) {
      case 'monday':
        return Colors.orangeAccent;
      case 'tuesday':
        return Colors.lightBlueAccent;
      case 'wednesday':
        return Colors.greenAccent;
      case 'thursday':
        return Colors.deepOrangeAccent;
      case 'friday':
        return Colors.purpleAccent;
      case 'saturday':
        return Colors.tealAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildWorkoutRecordCard(WorkoutRecord record, ClientThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          iconColor: colors.primary,
          collapsedIconColor: colors.textSecondary,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.workoutType.toUpperCase(),
                  style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.sessionTitle,
                  style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              if (record.isLocked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.gold, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 10, color: AppColors.gold),
                      SizedBox(width: 3),
                      Text('LOCKED', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ] else if (record.unlockedAt != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 10, color: Colors.green),
                      SizedBox(width: 3),
                      Text('UNLOCKED', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Text(
                DateFormat('dd MMM yyyy').format(record.startedAt),
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              Text(' • ', style: TextStyle(color: colors.textTertiary)),
              Text(record.durationDisplay, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              Text(' • ', style: TextStyle(color: colors.textTertiary)),
              Text('${record.totalVolume.toInt()} kg vol', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AppColors.border),
                if (record.isLocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session Locked & Completed',
                                style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                'Client cannot access or modify this workout.',
                                style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('admin_release_unlock_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 14),
                          label: const Text('Release / Unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          onPressed: () => _showUnlockSessionDialog(record, colors),
                        ),
                      ],
                    ),
                  ),
                ] else if (record.unlockedAt != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_open_rounded, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Session Released & Unlocked. Reason: "${record.unlockReason ?? 'Admin approval'}"',
                            style: GoogleFonts.poppins(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (record.notes != null && record.notes!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Client Workout Note: "${record.notes}"',
                      style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                ...record.exercises.map((ex) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ex.isSuperset ? colors.primary.withOpacity(0.3) : colors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (ex.isSuperset) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  ex.supersetTag ?? 'SS',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                ex.exerciseName,
                                style: GoogleFonts.poppins(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (ex.isSkipped)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('SKIPPED', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        if (ex.clientNote != null && ex.clientNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Client Note: "${ex.clientNote}"',
                            style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Sets Breakdown Table
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(2.2),
                            2: FlexColumnWidth(2.4),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.2),
                          },
                          children: [
                            TableRow(
                              children: [
                                Text('Set', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('Prescribed', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('Actual Logged', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('RIR', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('RPE', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            ...ex.sets.map((s) {
                              final weightStr = s.actualWeight != null
                                  ? (s.actualWeight! % 1 == 0 ? s.actualWeight!.toInt().toString() : s.actualWeight!.toStringAsFixed(1))
                                  : '—';
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text('${s.setNumber}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      '${s.targetRepsDisplay} @ ${s.targetWeight > 0 ? "${s.targetWeight}kg" : "BW"}',
                                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      s.isCompleted ? '$weightStr kg × ${s.actualReps ?? 0}' : 'Incomplete',
                                      style: TextStyle(
                                        color: s.isCompleted ? colors.textPrimary : colors.textDisabled,
                                        fontWeight: s.isCompleted ? FontWeight.w700 : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(s.actualRir != null ? '${s.actualRir}' : '—', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(s.actualRpe != null ? '${s.actualRpe}' : '—', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _showUnlockSessionDialog(WorkoutRecord record, ClientThemeColors colors) async {
    if (!AuthService().isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: Only administrators can unlock workout sessions.'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
      return;
    }

    final reasonController = TextEditingController(
      text: 'Accidental completion by client - released for workout access',
    );
    bool reopenSession = true;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sbCtx, setDialogState) => AlertDialog(
          backgroundColor: colors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_open_rounded, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Release & Unlock Session',
                  style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Release and unlock "${record.sessionTitle}" for $_clientName?',
                style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Text(
                  'Audit Notice: All releases are recorded with your Admin ID, reason, and timestamp.',
                  style: GoogleFonts.poppins(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'REASON FOR RELEASE / UNLOCK *',
                style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Accidental completion by client',
                  hintStyle: TextStyle(color: colors.textDisabled, fontSize: 12),
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gold)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: reopenSession,
                    activeColor: AppColors.gold,
                    checkColor: Colors.black,
                    onChanged: (val) => setDialogState(() => reopenSession = val ?? true),
                  ),
                  Expanded(
                    child: Text(
                      'Reopen as active workout for client',
                      style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reason for unlocking the session.'),
                      backgroundColor: AppColors.primaryRed,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  final adminId = AuthService().currentUserId.isNotEmpty
                      ? AuthService().currentUserId
                      : 'admin_1';
                  final success = await widget.workoutRepository.unlockSession(
                    recordId: record.id,
                    adminId: adminId,
                    reason: reason,
                    reopenSession: reopenSession,
                    clientId: _clientId,
                    sessionId: record.sessionId,
                  );
                  if (success) {
                    await _loadWorkoutHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Session "${record.sessionTitle}" released and unlocked for $_clientName.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to release session: Record not found.'),
                          backgroundColor: AppColors.primaryRed,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to release session: $e'),
                        backgroundColor: AppColors.primaryRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm Release', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CORE SECTION 3: NUTRITION (WHAT CLIENT ATE)
  // ==========================================
  Widget _buildNutritionTab(ClientThemeColors colors) {
    if (_isLoadingNutrition && _nutritionSummary == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
    }

    final comp = _nutritionSummary?['comparison'];
    final meals = _nutritionSummary?['meals'] as Map<String, dynamic>? ?? {};
    final totalMealsLogged = _nutritionSummary?['totalMealsLogged'] ?? 0;
    final lastMealTime = _nutritionSummary?['lastMealTime'];

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadNutritionSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: colors.textPrimary),
                  onPressed: () {
                    setState(() => _selectedNutritionDate = _selectedNutritionDate.subtract(const Duration(days: 1)));
                    _loadNutritionSummary();
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedNutritionDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() => _selectedNutritionDate = picked);
                      _loadNutritionSummary();
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_selectedNutritionDate).toUpperCase(),
                        style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: colors.textPrimary),
                  onPressed: () {
                    setState(() => _selectedNutritionDate = _selectedNutritionDate.add(const Duration(days: 1)));
                    _loadNutritionSummary();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Daily Target vs Actual Grid Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DAILY TARGET VS ACTUAL CONSUMPTION',
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '$totalMealsLogged / 4 meals logged',
                      style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (lastMealTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last logged meal: ${DateFormat('h:mm a').format(DateTime.parse(lastMealTime).toLocal())}',
                    style: TextStyle(color: colors.textTertiary, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 12),

                _buildNutritionMacroRow('Calories', comp?['calories'], 'kcal', colors.primary, colors),
                const SizedBox(height: 10),
                _buildNutritionMacroRow('Protein', comp?['protein'], 'g', AppColors.accentRed, colors),
                const SizedBox(height: 10),
                _buildNutritionMacroRow('Carbohydrates', comp?['carbohydrates'], 'g', AppColors.info, colors),
                const SizedBox(height: 10),
                _buildNutritionMacroRow('Fat', comp?['fat'], 'g', AppColors.gold, colors),
                const SizedBox(height: 10),
                _buildNutritionMacroRow('Fiber', comp?['fiber'], 'g', AppColors.success, colors),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Food Log Header with Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CLIENT FOOD LOG',
                style: GoogleFonts.poppins(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${comp?['calories']?['actual'] ?? 0} kcal consumed',
                style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Meal category selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'].map((filter) {
                final isSelected = _selectedMealFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      filter == 'ALL' ? 'ALL MEALS' : filter,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : colors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colors.primary,
                    backgroundColor: colors.surfaceCard,
                    side: BorderSide(
                      color: isSelected ? colors.primary : colors.border,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMealFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Render Filtered Meal Cards
          ..._buildClientMealLogCards(meals, colors),

          const SizedBox(height: 16),
          // Prescribed Diet Plan Footer Action
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_calendar, size: 16, color: AppColors.primaryRed),
              label: const Text('UPDATE / ASSIGN DIET PLAN', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _openCreateEditDiet,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClientMealLogCards(Map<String, dynamic> meals, ClientThemeColors colors) {
    final photosByType = _nutritionSummary?['mealPhotosByType'] as Map<String, dynamic>? ?? {};
    final allCategories = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

    final filteredCategories = _selectedMealFilter == 'ALL'
        ? allCategories
        : allCategories.where((c) => c.toUpperCase() == _selectedMealFilter).toList();

    return filteredCategories.map((mealCategory) {
      final entries = (meals[mealCategory] as List<dynamic>? ?? []);
      final photos = (photosByType[mealCategory] as List<dynamic>? ?? []);
      final bool hasPhotos = photos.isNotEmpty || entries.any((e) => e['photoAvailable'] == true);
      final photoData = photos.isNotEmpty ? (photos[0] as Map<String, dynamic>) : null;

      double mealCal = 0;
      double mealProt = 0;
      double mealCrbs = 0;
      double mealFt = 0;
      double mealFbr = 0;

      for (final item in entries) {
        final q = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        mealCal += ((item['calories'] as num?)?.toDouble() ?? 0) * q;
        mealProt += ((item['protein'] as num?)?.toDouble() ?? 0) * q;
        mealCrbs += ((item['carbohydrates'] ?? item['carbs'] as num?)?.toDouble() ?? 0) * q;
        mealFt += ((item['fat'] as num?)?.toDouble() ?? 0) * q;
        mealFbr += ((item['fiber'] as num?)?.toDouble() ?? 0) * q;
      }

      if (entries.isEmpty && photoData != null) {
        mealCal = (photoData['totalCalories'] as num?)?.toDouble() ?? 0;
        mealProt = (photoData['totalProtein'] as num?)?.toDouble() ?? 0;
        mealCrbs = (photoData['totalCarbs'] as num?)?.toDouble() ?? 0;
        mealFt = (photoData['totalFat'] as num?)?.toDouble() ?? 0;
        mealFbr = (photoData['totalFiber'] as num?)?.toDouble() ?? 0;
      }

      String timeDisplay = _nutritionDateStr;
      if (photoData != null && photoData['confirmedAt'] != null) {
        final dt = DateTime.tryParse(photoData['confirmedAt'].toString());
        if (dt != null) {
          timeDisplay = DateFormat('h:mm a').format(dt.toLocal());
        }
      } else if (entries.isNotEmpty && entries[0]['loggedAt'] != null) {
        final dt = DateTime.tryParse(entries[0]['loggedAt'].toString());
        if (dt != null) {
          timeDisplay = DateFormat('h:mm a').format(dt.toLocal());
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPhotos ? colors.primary.withOpacity(0.5) : colors.border,
            width: hasPhotos ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colors.surfaceElevated,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        mealCategory.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('• $timeDisplay', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasPhotos ? AppColors.success.withOpacity(0.15) : colors.surfaceCard,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasPhotos ? '📸 PHOTO VERIFIED' : 'NO PHOTO',
                      style: TextStyle(
                        color: hasPhotos ? AppColors.success : colors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${mealCal.toInt()} kcal',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'P: ${mealProt.toInt()}g • C: ${mealCrbs.toInt()}g • F: ${mealFt.toInt()}g • Fib: ${mealFbr.toInt()}g',
                        style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 8),
                    ...entries.map((entry) {
                      final q = (entry['quantity'] as num?)?.toDouble() ?? 1.0;
                      final cal = ((entry['calories'] as num?)?.toDouble() ?? 0) * q;
                      final p = ((entry['protein'] as num?)?.toDouble() ?? 0) * q;
                      final c = ((entry['carbohydrates'] ?? entry['carbs'] as num?)?.toDouble() ?? 0) * q;
                      final f = ((entry['fat'] as num?)?.toDouble() ?? 0) * q;
                      final unit = entry['servingUnit'] ?? 'serving';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${entry['foodName'] ?? 'Food'} ($q $unit)',
                                style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${cal.toInt()} kcal (P:${p.toInt()}g C:${c.toInt()}g F:${f.toInt()}g)',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else if (photoData != null && photoData['items'] is List) ...[
                    const SizedBox(height: 8),
                    ...(photoData['items'] as List).map((i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '• ${i['foodName'] ?? 'Item'}: ${(i['calories'] as num?)?.toInt() ?? 0} kcal (P:${(i['protein'] as num?)?.toInt() ?? 0}g)',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text('No food entries recorded for $mealCategory.', style: TextStyle(color: colors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],

                  if (photoData != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => AdminMealPhotoViewerDialog(
                              mealPhoto: photoData,
                              clientName: _clientName,
                              clientId: _clientId,
                              onPhotoDeleted: _loadNutritionSummary,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_camera_rounded, color: AppColors.primaryRed, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'View Client Uploaded Meal Photo',
                                style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.open_in_new, size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // --- HELPER WIDGETS ---

  Widget _buildCard({
    required ClientThemeColors colors,
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: colors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isHighlight ? AppColors.primaryRed : Colors.white,
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPillRow(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 0.8),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildNutritionMacroRow(
    String label,
    dynamic macroData,
    String unit,
    Color color,
    ClientThemeColors colors,
  ) {
    final actual = (macroData?['actual'] as num?)?.toDouble() ?? 0.0;
    final target = (macroData?['target'] as num?)?.toDouble() ?? 0.0;
    final pct = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(
              '${actual.toInt()} / ${target.toInt()} $unit',
              style: GoogleFonts.poppins(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: colors.surfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  String _formatList(dynamic val) {
    if (val == null) return 'None';
    if (val is List) {
      return val.isEmpty ? 'None' : val.join(', ');
    }
    final s = val.toString().trim();
    return s.isEmpty ? 'None' : s;
  }
}
