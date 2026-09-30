import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'admin_create_edit_session_screen.dart';
import 'admin_assign_session_dialog.dart';
import 'admin_change_requests_screen.dart';
import 'admin_performance_dashboard_screen.dart';
import 'package:alpha_x_gym/features/exercise/presentation/admin/admin_exercise_database_screen.dart';

class AdminWorkoutSessionsScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final bool showAppBar;

  const AdminWorkoutSessionsScreen({
    super.key,
    required this.workoutRepository,
    this.showAppBar = true,
  });

  @override
  State<AdminWorkoutSessionsScreen> createState() => _AdminWorkoutSessionsScreenState();
}

class _AdminWorkoutSessionsScreenState extends State<AdminWorkoutSessionsScreen> {
  String _filter = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepositoryUpdate);
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepositoryUpdate);
    super.dispose();
  }

  void _onRepositoryUpdate() {
    if (mounted) setState(() {});
  }

  List<WorkoutSession> get _filteredSessions {
    return widget.workoutRepository.adminSessions.where((session) {
      if (_filter == 'ACTIVE' && !session.isActive) return false;
      if (_filter == 'INACTIVE' && session.isActive) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = session.title.toLowerCase().contains(query);
        final matchesTarget = session.targetMuscleGroup.toLowerCase().contains(query);
        final matchesType = session.workoutType.toLowerCase().contains(query);
        if (!matchesTitle && !matchesTarget && !matchesType) return false;
      }
      return true;
    }).toList();
  }

  void _openCreateSession() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AdminCreateEditSessionScreen(
          workoutRepository: widget.workoutRepository,
        ),
      ),
    );
  }

  void _openEditSession(WorkoutSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AdminCreateEditSessionScreen(
          workoutRepository: widget.workoutRepository,
          sessionToEdit: session,
        ),
      ),
    );
  }

  void _previewSession(WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.workoutType.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.difficulty,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '~${session.estimatedDurationMinutes} min',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    session.targetMuscleGroup,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (session.description != null && session.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      session.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  Text(
                    'EXERCISES (${session.exercises.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...session.exercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ex = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ex.isSuperset ? AppColors.accentRed.withOpacity(0.4) : AppColors.border,
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
                                    color: AppColors.primaryRed,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ex.supersetTag ?? 'SS',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  ex.exerciseName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                '${ex.sets.length} sets',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Target: ${ex.sets.firstOrNull?.targetRepsDisplay ?? "8-12"} reps @ ${ex.sets.firstOrNull?.targetWeight != null ? "${ex.sets.firstOrNull!.targetWeight} kg" : "bodyweight"} | Rest: ${ex.restSeconds}s | RIR: ${ex.sets.firstOrNull?.targetRir ?? 2}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (ex.trainerNote.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Instruction: ${ex.trainerNote}',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAssignDialog(WorkoutSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AdminAssignSessionDialog(
        session: session,
        workoutRepository: widget.workoutRepository,
      ),
    );
  }

  void _confirmDeleteSession(WorkoutSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Session', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to permanently delete "${session.title}"? Clients will no longer have access to this prescribed workout.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              widget.workoutRepository.deleteSession(session.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted session "${session.title}"'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _filteredSessions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'WORKOUT SESSIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  fontSize: 16,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fitness_center_outlined, color: AppColors.textPrimary),
                  tooltip: 'Exercise Library',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const AdminExerciseDatabaseScreen()),
                    );
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_calls_outlined, color: AppColors.textPrimary),
                      tooltip: 'Change Requests',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => AdminChangeRequestsScreen(workoutRepository: widget.workoutRepository),
                          ),
                        );
                      },
                    ),
                    if (widget.workoutRepository.changeRequests.where((r) => r.isPending).isNotEmpty)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              '${widget.workoutRepository.changeRequests.where((r) => r.isPending).length}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: AppColors.textPrimary),
                  tooltip: 'Athlete Performance',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => AdminPerformanceDashboardScreen(workoutRepository: widget.workoutRepository),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed),
                  tooltip: 'Create Workout Session',
                  onPressed: _openCreateSession,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search sessions, muscles, types...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterChip('ALL', 'All (${widget.workoutRepository.adminSessions.length})'),
                    const SizedBox(width: 8),
                    _filterChip('ACTIVE', 'Active'),
                    const SizedBox(width: 8),
                    _filterChip('INACTIVE', 'Inactive'),
                  ],
                ),
              ],
            ),
          ),

          // Sessions List
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fitness_center_outlined, size: 48, color: AppColors.textDisabled),
                        const SizedBox(height: 12),
                        const Text(
                          'No workout sessions found',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: _openCreateSession,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Create First Session', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (ctx, index) {
                      final session = sessions[index];
                      return _buildSessionCard(session);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Session', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _openCreateSession,
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _filter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _filter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(WorkoutSession session) {
    final assignments = widget.workoutRepository.assignments.where((a) => a.sessionId == session.id).toList();
    final isAssignedToAll = assignments.any((a) => a.clientId == null);
    final hasRecommended = assignments.any((a) => a.isRecommended);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasRecommended ? AppColors.primaryRed.withOpacity(0.6) : AppColors.border,
          width: hasRecommended ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasRecommended) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.glowRed,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primaryRed, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 12, color: AppColors.gold),
                                  SizedBox(width: 4),
                                  Text(
                                    'Recommended',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: session.isActive
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.textDisabled.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              session.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                color: session.isActive ? AppColors.success : AppColors.textTertiary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              session.workoutType,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.targetMuscleGroup,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  color: AppColors.surfaceElevated,
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _openEditSession(session);
                        break;
                      case 'duplicate':
                        widget.workoutRepository.duplicateSession(session.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Duplicated "${session.title}"'),
                            backgroundColor: AppColors.primaryRed,
                          ),
                        );
                        break;
                      case 'preview':
                        _previewSession(session);
                        break;
                      case 'assign':
                        _openAssignDialog(session);
                        break;
                      case 'toggle':
                        widget.workoutRepository.toggleSessionActive(session.id);
                        break;
                      case 'delete':
                        _confirmDeleteSession(session);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'preview',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18, color: AppColors.info),
                          SizedBox(width: 10),
                          Text('Preview Session', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: 10),
                          Text('Edit Session', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: 10),
                          Text('Duplicate Session', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'assign',
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_1_outlined, size: 18, color: AppColors.primaryRed),
                          SizedBox(width: 10),
                          Text('Assign Session', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            session.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            size: 18,
                            color: session.isActive ? AppColors.warning : AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            session.isActive ? 'Deactivate' : 'Activate',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 10),
                          Text('Delete Session', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details Chip Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(Icons.fitness_center, '${session.exercises.length} Exercises'),
                _pill(Icons.timer_outlined, '~${session.estimatedDurationMinutes} min'),
                _pill(Icons.speed, session.difficulty),
                if (isAssignedToAll)
                  _pill(Icons.groups, 'All Clients', color: AppColors.info)
                else if (assignments.isNotEmpty)
                  _pill(Icons.person, '${assignments.length} Assigned', color: AppColors.info)
                else
                  _pill(Icons.person_off_outlined, 'Unassigned', color: AppColors.textTertiary),
              ],
            ),
          ),

          // Exercise Mini Overview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...session.exercises.take(3).map((ex) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          if (ex.isSuperset) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                ex.supersetTag ?? 'SS',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.arrow_right, size: 14, color: AppColors.primaryRed),
                          ],
                          Expanded(
                            child: Text(
                              ex.exerciseName,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${ex.sets.length} × ${ex.sets.firstOrNull?.targetRepsDisplay ?? "8-12"}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (session.exercises.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${session.exercises.length - 3} more exercises',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _previewSession(session),
                  icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.textSecondary),
                  label: const Text('Preview', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openAssignDialog(session),
                  icon: const Icon(Icons.person_add_outlined, size: 16, color: AppColors.primaryRed),
                  label: const Text('Assign', style: TextStyle(color: AppColors.primaryRed, fontSize: 12)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                  tooltip: 'Edit Session',
                  onPressed: () => _openEditSession(session),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  tooltip: 'Delete Session',
                  onPressed: () => _confirmDeleteSession(session),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, {Color? color}) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
