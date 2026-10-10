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
import 'package:alpha_x_gym/features/dashboard/widgets/admin_meal_photo_viewer_dialog.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';

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
              if (val == 'progress') {
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
              } else if (val == 'refresh') {
                _loadLiveProfile();
                _loadWorkoutHistory();
                _loadNutritionSummary();
              }
            },
            itemBuilder: (ctx) => [
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
  // CORE SECTION 2: WORKOUT (ACTUAL PERFORMANCE)
  // ==========================================
  Widget _buildWorkoutTab(ClientThemeColors colors) {
    if (_isLoadingWorkouts && _workoutRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
    }

    final totalVolume = _workoutRecords.fold(0.0, (acc, r) => acc + r.totalVolume);
    final totalHours = (_workoutRecords.fold(0, (acc, r) => acc + r.durationSeconds) / 3600).toStringAsFixed(1);

    // Active assignments for this client
    final assignments = widget.workoutRepository.assignments
        .where((a) => a.clientId == null || a.clientId == _clientId || a.clientId == _displayId)
        .toList();

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadWorkoutHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Summary Bar
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

          // Action Bar: Assign Session
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
                label: const Text('+ ASSIGN SESSION', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 11)),
                onPressed: _openAssignWorkoutDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_workoutRecords.isEmpty)
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
                    style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
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
                    label: const Text('ASSIGN WORKOUT NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            )
          else
            ..._workoutRecords.map((record) => _buildWorkoutRecordCard(record, colors)),

          if (assignments.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'ACTIVE ASSIGNMENTS (${assignments.length})',
              style: GoogleFonts.poppins(
                color: colors.textTertiary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            ...assignments.map((assign) {
              final session = widget.workoutRepository.adminSessions
                  .where((s) => s.id == assign.sessionId)
                  .firstOrNull;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: assign.isRecommended ? colors.primary : colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    if (assign.isRecommended)
                      const Icon(Icons.star, size: 16, color: AppColors.gold),
                    if (assign.isRecommended) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session?.title ?? 'Session ${assign.sessionId}',
                        style: GoogleFonts.poppins(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      assign.isRecommended ? 'RECOMMENDED' : 'ASSIGNED',
                      style: TextStyle(
                        color: assign.isRecommended ? AppColors.gold : colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutRecordCard(WorkoutRecord record, ClientThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
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
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
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
