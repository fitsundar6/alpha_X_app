import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_picker_dialog.dart';
import 'admin_create_edit_session_screen.dart';
import 'admin_proposal_assignment_dialog.dart';

/// Dedicated Admin Workout Proposals Screen.
/// Displays AI-generated workout proposals with client name, client ID, creation date,
/// schedule, and status. Allows reviewing full plans, editing exercises, sets, reps,
/// rest, weight, and notes, and assigning them to Individual, Selected, or All clients.
class AdminWorkoutProposalsScreen extends StatefulWidget {
  final WorkoutRepository? workoutRepository;
  final AiCoachRepository? aiCoachRepository;
  final bool showAppBar;
  final String? initialStatusFilter;

  const AdminWorkoutProposalsScreen({
    super.key,
    this.workoutRepository,
    this.aiCoachRepository,
    this.showAppBar = true,
    this.initialStatusFilter,
  });

  @override
  State<AdminWorkoutProposalsScreen> createState() => _AdminWorkoutProposalsScreenState();
}

class _AdminWorkoutProposalsScreenState extends State<AdminWorkoutProposalsScreen> {
  late final AiCoachRepository _aiRepo;
  late final WorkoutRepository _workoutRepo;

  List<AiProposal> _proposals = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _statusFilter = 'ALL'; // 'ALL', 'PENDING', 'EDITED', 'APPROVED', 'REJECTED'
  String _typeFilter = 'ALL'; // 'ALL', 'WORKOUT', 'DIET'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _aiRepo = widget.aiCoachRepository ?? AiCoachRepository();
    _workoutRepo = widget.workoutRepository ?? WorkoutRepository();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
    _loadProposals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProposals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final all = await _aiRepo.getProposals();
      if (!mounted) return;
      setState(() {
        _proposals = all;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load proposals: $e';
        _isLoading = false;
      });
    }
  }

  List<AiProposal> get _filteredProposals {
    return _proposals.where((p) {
      if (_typeFilter != 'ALL') {
        if (_typeFilter == 'WORKOUT' && p.type != AiProposalType.workout) return false;
        if (_typeFilter == 'DIET' && p.type != AiProposalType.diet) return false;
      }
      if (_statusFilter != 'ALL') {
        if (p.status.name.toUpperCase() != _statusFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = p.title.toLowerCase();
        final clientName = (p.clientName ?? '').toLowerCase();
        final clientId = (p.clientId ?? '').toLowerCase();
        final summary = p.summary.toLowerCase();
        if (!title.contains(q) && !clientName.contains(q) && !clientId.contains(q) && !summary.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int get _pendingCount => _proposals.where((p) => p.status == AiProposalStatus.pending).length;
  int get _editedCount => _proposals.where((p) => p.status == AiProposalStatus.edited).length;
  int get _approvedCount => _proposals.where((p) => p.status == AiProposalStatus.approved).length;

  Color _getStatusColor(AiProposalStatus status) {
    switch (status) {
      case AiProposalStatus.approved:
        return AppColors.statusGreen;
      case AiProposalStatus.rejected:
        return AppColors.primaryRed;
      case AiProposalStatus.edited:
        return Colors.lightBlueAccent;
      case AiProposalStatus.pending:
        return AppColors.warningYellow;
    }
  }

  String _getStatusLabel(AiProposalStatus status) {
    switch (status) {
      case AiProposalStatus.approved:
        return 'APPROVED & ASSIGNED';
      case AiProposalStatus.rejected:
        return 'REJECTED';
      case AiProposalStatus.edited:
        return 'EDITED BY ADMIN';
      case AiProposalStatus.pending:
        return 'PENDING REVIEW';
    }
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute';
  }

  void _openProposalDetails(AiProposal proposal) {
    if (proposal.type == AiProposalType.diet) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _DietProposalDetailSheet(
          proposal: proposal,
          aiCoachRepository: _aiRepo,
          onProposalUpdated: () {
            _loadProposals();
          },
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProposalDetailSheet(
        proposal: proposal,
        workoutRepository: _workoutRepo,
        aiCoachRepository: _aiRepo,
        onProposalUpdated: () {
          _loadProposals();
        },
      ),
    );
  }

  Future<void> _openAssignDialog(AiProposal proposal) async {
    if (proposal.type == AiProposalType.diet) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('Approve & Assign Diet Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign "${proposal.title}" to athlete as their active nutrition protocol?',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.primaryRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proposal.clientName ?? 'Athlete',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Client ID: ${proposal.clientId ?? 'AXG'}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusGreen,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Approve & Assign', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final ok = await _aiRepo.approveProposal(
          proposal.id,
          clientIds: proposal.clientId != null ? [proposal.clientId!] : null,
          proposalData: proposal.toJson(),
        );
        if (ok && mounted) {
          setState(() {
            proposal.status = AiProposalStatus.approved;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✔ ${proposal.title} approved and assigned to ${proposal.clientName}!'),
              backgroundColor: AppColors.statusGreen,
            ),
          );
          _loadProposals();
        }
      }
      return;
    }

    await AdminProposalAssignmentDialog.show(
      context: context,
      proposal: proposal,
      aiCoachRepository: _aiRepo,
      workoutRepository: _workoutRepo,
      onAssigned: () {
        setState(() {
          proposal.status = AiProposalStatus.approved;
        });
        _loadProposals();
      },
    );
  }

  Future<void> _rejectProposal(AiProposal proposal) async {
    final reasonController = TextEditingController(text: 'Admin rejected this workout proposal');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Reject Proposal', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting "${proposal.title}" will close this proposal without creating active client workouts.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Reason for rejection (optional)',
                labelStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await _aiRepo.rejectProposal(proposal.id, reason: reasonController.text.trim());
      if (ok && mounted) {
        setState(() {
          proposal.status = AiProposalStatus.rejected;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal rejected.'), backgroundColor: AppColors.primaryRed),
        );
        _loadProposals();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: const Text(
                'AI WORKOUT PROPOSALS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh Proposals',
                  onPressed: _loadProposals,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // Metrics & Quick Stats Row
          _buildMetricsBar(),

          // Proposal Type Tabs (All / Workouts / Diet & Macros)
          _buildTypeTabs(),

          // Search & Filter Header
          _buildSearchBar(),

          // Status Filter Tabs
          _buildStatusTabs(),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryRed),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: AppColors.primaryRed),
                            const SizedBox(height: 10),
                            Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                              onPressed: _loadProposals,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredProposals.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadProposals,
                            color: AppColors.primaryRed,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _filteredProposals.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (ctx, idx) => _buildProposalCard(_filteredProposals[idx]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surfaceCard,
      child: Row(
        children: [
          _metricTile('Pending Review', '$_pendingCount', AppColors.warningYellow, 'PENDING'),
          const SizedBox(width: 8),
          _metricTile('Admin Edited', '$_editedCount', Colors.lightBlueAccent, 'EDITED'),
          const SizedBox(width: 8),
          _metricTile('Approved Plans', '$_approvedCount', AppColors.statusGreen, 'APPROVED'),
          const SizedBox(width: 8),
          _metricTile('Total Generated', '${_proposals.length}', Colors.white70, 'ALL'),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color, String filterKey) {
    final isSelected = _statusFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = filterKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.18) : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTabs() {
    final typeFilters = [
      {'key': 'ALL', 'label': 'All Types', 'icon': Icons.apps},
      {'key': 'WORKOUT', 'label': 'Workouts', 'icon': Icons.fitness_center},
      {'key': 'DIET', 'label': 'Diet & Macros', 'icon': Icons.restaurant_menu},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: typeFilters.map((f) {
          final isSelected = _typeFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                f['icon'] as IconData,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textTertiary,
              ),
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (_) => setState(() => _typeFilter = f['key'] as String),
              selectedColor: Colors.teal,
              backgroundColor: AppColors.surfaceElevated,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSelected ? Colors.tealAccent : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        decoration: InputDecoration(
          hintText: 'Search by client name, client ID, or plan title...',
          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    final filters = [
      {'key': 'ALL', 'label': 'All Plans'},
      {'key': 'PENDING', 'label': 'Pending'},
      {'key': 'EDITED', 'label': 'Edited'},
      {'key': 'APPROVED', 'label': 'Approved'},
      {'key': 'REJECTED', 'label': 'Rejected'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _statusFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) => setState(() => _statusFilter = f['key']!),
              selectedColor: AppColors.primaryRed,
              backgroundColor: AppColors.surfaceElevated,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSelected ? AppColors.primaryRed : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty ? 'No proposals matching "$_searchQuery"' : 'No workout proposals found',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Generate plans in Admin AI Coach by selecting an athlete and requesting a workout.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              onPressed: _loadProposals,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalCard(AiProposal proposal) {
    final statusColor = _getStatusColor(proposal.status);
    final statusLabel = _getStatusLabel(proposal.status);
    final payload = proposal.payload;

    final clientName = proposal.clientName ?? payload['clientName'] ?? 'Athlete';
    final clientId = proposal.clientId ?? payload['clientId'] ?? 'AXG-ID';
    final isDiet = proposal.type == AiProposalType.diet;

    // Workout properties
    final workoutType = payload['workoutType']?.toString() ?? 'Hypertrophy';
    final targetGroup = payload['targetMuscleGroup']?.toString() ?? 'Full Body';
    final duration = payload['estimatedDurationMinutes']?.toString() ?? '45';

    // Parse exercises count
    List<dynamic> exercises = [];
    if (!isDiet) {
      if (payload['exercises'] is List && (payload['exercises'] as List).isNotEmpty) {
        exercises = payload['exercises'] as List;
      } else if (payload['weeklySchedule'] is List) {
        for (final day in (payload['weeklySchedule'] as List)) {
          if (day is Map && day['exercises'] is List) {
            exercises.addAll(day['exercises'] as List);
          }
        }
      }
    }

    // Diet / Macro properties
    final planKind = payload['planKind']?.toString() ?? (isDiet ? 'DIET_PLAN' : '');
    final isMacroOnly = isDiet && (planKind == 'MACRO_ONLY' || (payload['meals'] is List && (payload['meals'] as List).isEmpty));
    final calories = payload['dailyCalories'] ?? payload['calories'] ?? payload['targetCalories'] ?? 2000;
    final protein = payload['protein'] ?? payload['proteinGrams'] ?? payload['targetProtein'] ?? 150;
    final carbs = payload['carbohydrates'] ?? payload['carbGrams'] ?? payload['carbs'] ?? payload['targetCarbs'] ?? 200;
    final fat = payload['fat'] ?? payload['fatGrams'] ?? payload['targetFat'] ?? 60;
    final water = payload['waterTargetLiters'] ?? payload['targetWaterLiters'] ?? payload['waterLiters'] ?? 3.5;

    List<dynamic> meals = [];
    if (isDiet && payload['meals'] is List) {
      meals = payload['meals'] as List;
    }

    final isActionable = proposal.status == AiProposalStatus.pending || proposal.status == AiProposalStatus.edited;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Client & Status Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDiet ? Colors.teal : AppColors.primaryRed,
                      child: Text(
                        clientName.isNotEmpty ? clientName[0].toUpperCase() : 'A',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                                  clientName,
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
                                  clientId,
                                  style: TextStyle(
                                    color: isDiet ? Colors.tealAccent : AppColors.primaryRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(proposal.createdAt ?? DateTime.now()),
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: (isDiet ? Colors.teal : AppColors.primaryRed).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: (isDiet ? Colors.teal : AppColors.primaryRed).withOpacity(0.4)),
                      ),
                      child: Text(
                        isDiet ? (isMacroOnly ? 'MACROS' : 'DIET') : 'WORKOUT',
                        style: TextStyle(
                          color: isDiet ? Colors.tealAccent : AppColors.primaryRed,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Plan Title
                Text(
                  proposal.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                if (proposal.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    proposal.summary,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),

                // Specs Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: isDiet
                      ? [
                          _pill(isMacroOnly ? Icons.tune : Icons.restaurant, isMacroOnly ? 'Macro Target Only' : '${meals.length} Meals'),
                          _pill(Icons.local_fire_department, '$calories kcal'),
                          _pill(Icons.fitness_center, '${protein}g Pro'),
                          _pill(Icons.grain, '${carbs}g Carb'),
                          _pill(Icons.opacity, '${fat}g Fat'),
                          _pill(Icons.water_drop, '${water}L Water'),
                        ]
                      : [
                          if (payload['weeklySchedule'] is List && (payload['weeklySchedule'] as List).isNotEmpty)
                            _pill(Icons.calendar_view_week, '${(payload['weeklySchedule'] as List).length} Days Split')
                          else
                            _pill(Icons.fitness_center, '${exercises.length} Exercises'),
                          _pill(Icons.category, workoutType),
                          _pill(Icons.accessibility_new, targetGroup),
                          _pill(Icons.timer_outlined, '~${duration}m'),
                        ],
                ),

                // Preview Snippet
                if (isDiet) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withOpacity(0.2)),
                    ),
                    child: isMacroOnly
                        ? Row(
                            children: [
                              const Icon(Icons.tune, size: 16, color: Colors.tealAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Daily Macro Protocol: $calories kcal • ${protein}g P • ${carbs}g C • ${fat}g F (Flexible food selection)',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...meals.take(3).map((m) {
                                final mName = m['mealType'] ?? m['name'] ?? 'Meal';
                                final timing = m['timing'] ?? '';
                                final foods = (m['items'] ?? m['foods'] ?? []) as List;
                                final foodsSummary = foods
                                    .map((f) => f is Map ? (f['foodName'] ?? f['name'] ?? '') : f.toString())
                                    .where((s) => s.isNotEmpty)
                                    .join(', ');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.restaurant_menu, size: 13, color: Colors.tealAccent),
                                      const SizedBox(width: 6),
                                      Text(
                                        mName.toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      if (timing.toString().isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text('($timing)', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                                      ],
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          foodsSummary.isNotEmpty ? ': $foodsSummary' : '',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (meals.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '+ ${meals.length - 3} more prescribed meals',
                                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ] else if (payload['weeklySchedule'] is List && (payload['weeklySchedule'] as List).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_view_week, size: 14, color: Colors.lightBlueAccent),
                            const SizedBox(width: 6),
                            Text(
                              'WEEKLY SPLIT: ${(payload['weeklySchedule'] as List).length} WORKOUT DAYS',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...(payload['weeklySchedule'] as List).map((d) {
                          final dayMap = d is Map ? d : {};
                          final dayName = dayMap['day'] ?? dayMap['dayName'] ?? dayMap['weekday'] ?? 'Day';
                          final title = dayMap['sessionTitle'] ?? dayMap['title'] ?? 'Session';
                          final dEx = (dayMap['exercises'] as List?) ?? [];
                          final splitCat = dayMap['splitCategory'] ?? dayMap['category'] ?? '';
                          final color = getSplitBadgeColor(splitCat.toString());
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: color.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    dayName.toString(),
                                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${dEx.length} exercises',
                                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ] else if (exercises.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...exercises.take(3).map((ex) {
                          final exName = ex['exerciseName'] ?? ex['name'] ?? 'Exercise';
                          final sets = ex['sets'] ?? ex['numberOfSets'] ?? 3;
                          final reps = ex['targetReps'] ?? ex['reps'] ?? '8-12';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_right, size: 14, color: AppColors.primaryRed),
                                Expanded(
                                  child: Text(
                                    exName,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$sets × $reps',
                                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (exercises.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '+ ${exercises.length - 3} more exercises',
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.edit_note, size: 16, color: Colors.white70),
                  label: const Text('Review & Edit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _openProposalDetails(proposal),
                ),
                const Spacer(),
                if (isActionable) ...[
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primaryRed, size: 18),
                    tooltip: 'Reject Proposal',
                    onPressed: () => _rejectProposal(proposal),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      isDiet ? 'Assign Diet' : 'Assign Plan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _openAssignDialog(proposal),
                  ),
                ] else ...[
                  Text(
                    proposal.status == AiProposalStatus.approved
                        ? (isDiet ? '✔ Active Diet Assigned' : '✔ Active Session Created')
                        : '✖ Proposal Closed',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

Color getSplitBadgeColor(String cat) {
  final lower = cat.toLowerCase();
  if (lower.contains('push')) return Colors.orangeAccent;
  if (lower.contains('pull')) return Colors.cyanAccent;
  if (lower.contains('leg')) return Colors.lightGreenAccent;
  if (lower.contains('upper')) return Colors.amberAccent;
  if (lower.contains('lower')) return Colors.purpleAccent;
  return AppColors.primaryRed;
}

typedef WorkoutProposalDetailSheet = _ProposalDetailSheet;

/// Bottom Sheet for In-depth Proposal Inspection and Inline Editing.
class _ProposalDetailSheet extends StatefulWidget {
  final AiProposal proposal;
  final WorkoutRepository workoutRepository;
  final AiCoachRepository aiCoachRepository;
  final VoidCallback onProposalUpdated;

  const _ProposalDetailSheet({
    required this.proposal,
    required this.workoutRepository,
    required this.aiCoachRepository,
    required this.onProposalUpdated,
  });

  @override
  State<_ProposalDetailSheet> createState() => _ProposalDetailSheetState();
}

class _ProposalDetailSheetState extends State<_ProposalDetailSheet> {
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _targetMuscleController;
  late TextEditingController _durationController;

  late List<Map<String, dynamic>> _editableExercises;
  late List<Map<String, dynamic>> _editableDays;
  bool _isMultiDay = false;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    final payload = Map<String, dynamic>.from(p.payload);

    _titleController = TextEditingController(text: p.title);
    _summaryController = TextEditingController(text: p.summary);
    _targetMuscleController = TextEditingController(text: payload['targetMuscleGroup']?.toString() ?? 'Full Body');
    _durationController = TextEditingController(text: payload['estimatedDurationMinutes']?.toString() ?? '45');

    _editableExercises = [];
    _editableDays = [];

    if (payload['weeklySchedule'] is List && (payload['weeklySchedule'] as List).isNotEmpty) {
      _isMultiDay = true;
      for (final day in (payload['weeklySchedule'] as List)) {
        if (day is Map) {
          final dayMap = Map<String, dynamic>.from(day);
          final dayExList = <Map<String, dynamic>>[];
          if (dayMap['exercises'] is List) {
            for (final ex in (dayMap['exercises'] as List)) {
              if (ex is Map) {
                dayExList.add(Map<String, dynamic>.from(ex));
              }
            }
          }
          dayMap['exercises'] = dayExList;
          _editableDays.add(dayMap);
        }
      }
    } else {
      _isMultiDay = false;
      if (payload['exercises'] is List && (payload['exercises'] as List).isNotEmpty) {
        for (final ex in (payload['exercises'] as List)) {
          if (ex is Map) _editableExercises.add(Map<String, dynamic>.from(ex));
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _targetMuscleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _saveModifications() async {
    setState(() => _isSaving = true);

    final updatedPayload = Map<String, dynamic>.from(widget.proposal.payload);
    updatedPayload['title'] = _titleController.text.trim();
    updatedPayload['summary'] = _summaryController.text.trim();
    updatedPayload['targetMuscleGroup'] = _targetMuscleController.text.trim();
    updatedPayload['estimatedDurationMinutes'] = int.tryParse(_durationController.text.trim()) ?? 45;

    if (_isMultiDay) {
      updatedPayload['weeklySchedule'] = _editableDays;
      // Preserve day isolation: do NOT concatenate all days into a single flat exercises list!
      if (_editableDays.isNotEmpty && _editableDays[0]['exercises'] is List) {
        updatedPayload['exercises'] = _editableDays[0]['exercises'];
      }
    } else {
      updatedPayload['exercises'] = _editableExercises;
    }

    final ok = await widget.aiCoachRepository.editProposal(widget.proposal.id, updatedPayload);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      setState(() {
        widget.proposal.title = _titleController.text.trim();
        widget.proposal.summary = _summaryController.text.trim();
        widget.proposal.status = AiProposalStatus.edited;
        widget.proposal.payload = updatedPayload;
        _isDirty = false;
      });
      widget.onProposalUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✔ Proposal modifications saved to database. Proposal ID retained.'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save proposal modifications.'), backgroundColor: AppColors.primaryRed),
      );
    }
  }

  void _addExercise() async {
    final picked = await ExercisePickerDialog.show(context);
    if (picked != null) {
      setState(() {
        _editableExercises.add({
          'exerciseId': picked.id,
          'exerciseName': picked.displayName,
          'sets': 3,
          'targetReps': '8-12',
          'targetWeight': 20.0,
          'restSeconds': 90,
          'targetRir': 2,
          'targetRpe': 8.0,
          'tempo': '3-1-1-0',
          'category': picked.category,
          'notes': picked.defaultTrainerNote,
        });
        _isDirty = true;
      });
    }
  }

  void _replaceExercise(int exIdx) async {
    if (exIdx < 0 || exIdx >= _editableExercises.length) return;
    final picked = await ExercisePickerDialog.show(context);
    if (picked != null) {
      setState(() {
        final oldEx = _editableExercises[exIdx];
        _editableExercises[exIdx] = {
          ...oldEx,
          'exerciseId': picked.id,
          'exerciseName': picked.displayName,
          'category': picked.category,
          'notes': (oldEx['notes'] != null && oldEx['notes'].toString().isNotEmpty)
              ? oldEx['notes']
              : picked.defaultTrainerNote,
        };
        _isDirty = true;
      });
    }
  }

  void _moveExercise(int oldIdx, int newIdx) {
    if (newIdx < 0 || newIdx >= _editableExercises.length) return;
    setState(() {
      final item = _editableExercises.removeAt(oldIdx);
      _editableExercises.insert(newIdx, item);
      _isDirty = true;
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _editableExercises.removeAt(index);
      _isDirty = true;
    });
  }

  void _addExerciseToDay(int dayIdx) async {
    final picked = await ExercisePickerDialog.show(context);
    if (picked != null) {
      setState(() {
        final day = _editableDays[dayIdx];
        final dayExList = (day['exercises'] as List<Map<String, dynamic>>);
        dayExList.add({
          'exerciseId': picked.id,
          'exerciseName': picked.displayName,
          'sets': 3,
          'targetReps': '8-12',
          'targetWeight': 20.0,
          'restSeconds': 90,
          'targetRir': 2,
          'targetRpe': 8.0,
          'tempo': '3-1-1-0',
          'category': picked.category,
          'notes': picked.defaultTrainerNote,
        });
        _isDirty = true;
      });
    }
  }

  void _replaceExerciseInDay(int dayIdx, int exIdx) async {
    final day = _editableDays[dayIdx];
    final dayExList = (day['exercises'] as List<Map<String, dynamic>>);
    if (exIdx < 0 || exIdx >= dayExList.length) return;

    final picked = await ExercisePickerDialog.show(context);
    if (picked != null) {
      setState(() {
        final oldEx = dayExList[exIdx];
        dayExList[exIdx] = {
          ...oldEx,
          'exerciseId': picked.id,
          'exerciseName': picked.displayName,
          'category': picked.category,
          'notes': (oldEx['notes'] != null && oldEx['notes'].toString().isNotEmpty)
              ? oldEx['notes']
              : picked.defaultTrainerNote,
        };
        _isDirty = true;
      });
    }
  }

  void _moveExerciseInDay(int dayIdx, int oldIdx, int newIdx) {
    final day = _editableDays[dayIdx];
    final dayExList = (day['exercises'] as List<Map<String, dynamic>>);
    if (newIdx < 0 || newIdx >= dayExList.length) return;
    setState(() {
      final item = dayExList.removeAt(oldIdx);
      dayExList.insert(newIdx, item);
      _isDirty = true;
    });
  }

  void _removeExerciseFromDay(int dayIdx, int exIdx) {
    setState(() {
      final day = _editableDays[dayIdx];
      final dayExList = (day['exercises'] as List<Map<String, dynamic>>);
      dayExList.removeAt(exIdx);
      _isDirty = true;
    });
  }

  void _openDayInSessionBuilder(int dayIdx) async {
    final day = _editableDays[dayIdx];
    final dayName = day['day'] ?? day['dayName'] ?? day['weekday'] ?? 'Day ${dayIdx + 1}';
    final sessionTitle = day['sessionTitle'] ?? day['title'] ?? '$dayName Workout';
    final splitCat = day['splitCategory'] ?? day['category'] ?? 'Strength';
    final targetMuscles = day['targetMuscleGroup'] ?? 'Full Body';
    final duration = day['estimatedDurationMinutes'] ?? 50;
    final exercisesData = (day['exercises'] as List<Map<String, dynamic>>?) ?? [];

    final workoutExercises = exercisesData.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final setsCount = (e['sets'] is int) ? e['sets'] as int : (int.tryParse(e['sets']?.toString() ?? '3') ?? 3);
      final weight = (e['targetWeight'] is num) ? (e['targetWeight'] as num).toDouble() : (double.tryParse(e['targetWeight']?.toString() ?? '20') ?? 20.0);
      final rest = (e['restSeconds'] is int) ? e['restSeconds'] as int : (int.tryParse(e['restSeconds']?.toString() ?? '90') ?? 90);
      final rpe = (e['targetRpe'] is num) ? (e['targetRpe'] as num).toDouble() : (double.tryParse(e['targetRpe']?.toString() ?? '8') ?? 8.0);
      final rir = (e['targetRir'] is int) ? e['targetRir'] as int : (int.tryParse(e['targetRir']?.toString() ?? '2') ?? 2);
      final repsStr = e['targetReps']?.toString() ?? e['reps']?.toString() ?? '8-12';
      int minReps = 8, maxReps = 12;
      if (repsStr.contains('-') || repsStr.contains('–')) {
        final p = repsStr.split(RegExp(r'[-–]'));
        minReps = int.tryParse(p[0].trim()) ?? 8;
        maxReps = int.tryParse(p[1].trim()) ?? minReps;
      }

      return WorkoutExercise(
        id: 'we_prop_${dayIdx}_$i',
        exerciseId: e['exerciseId']?.toString() ?? 'ex_prop_${dayIdx}_$i',
        exerciseName: e['exerciseName']?.toString() ?? e['name']?.toString() ?? 'Exercise',
        category: e['category']?.toString() ?? splitCat.toString(),
        primaryMusclesDisplay: e['primaryMuscles']?.toString() ?? targetMuscles.toString(),
        secondaryMusclesDisplay: e['secondaryMuscles']?.toString() ?? '',
        restSeconds: rest,
        trainerNote: e['notes']?.toString() ?? '',
        tempo: e['tempo']?.toString() ?? '3-1-1-0',
        supersetTag: e['supersetTag']?.toString(),
        sets: List.generate(
          setsCount,
          (sIdx) => ExerciseSet(
            id: 'set_${dayIdx}_${i}_${sIdx + 1}',
            setNumber: sIdx + 1,
            targetWeight: weight,
            targetRepsMin: minReps,
            targetRepsMax: maxReps,
            targetRpe: rpe,
            targetRir: rir,
          ),
        ),
      );
    }).toList();

    final draftSession = WorkoutSession(
      id: 'ai_draft_${widget.proposal.id}_day_$dayIdx',
      title: sessionTitle.toString(),
      workoutType: splitCat.toString(),
      targetMuscleGroup: targetMuscles.toString(),
      difficulty: 'Intermediate',
      estimatedDurationMinutes: duration is int ? duration : (int.tryParse(duration.toString()) ?? 50),
      recurringSchedule: dayName.toString(),
      assignedClientIds: widget.proposal.clientId != null ? [widget.proposal.clientId!] : const [],
      exercises: workoutExercises,
    );

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateEditSessionScreen(
          workoutRepository: widget.workoutRepository,
          sessionToEdit: draftSession,
          clientIdToAssign: widget.proposal.clientId,
          startInSplitMode: false,
          onSaved: () {},
        ),
      ),
    );

    if (saved == true && mounted) {
      widget.onProposalUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final isActionable = proposal.status == AiProposalStatus.pending || proposal.status == AiProposalStatus.edited;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REVIEW & EDIT PROPOSAL',
                        style: TextStyle(
                          color: _isDirty ? Colors.lightBlueAccent : AppColors.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${proposal.id}',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Form fields and exercises list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // Plan title
                const Text('Plan Title', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() => _isDirty = true),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),

                // Target Muscle & Duration
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Muscle', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _targetMuscleController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onChanged: (_) => setState(() => _isDirty = true),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Duration (min)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onChanged: (_) => setState(() => _isDirty = true),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Coaching Rationale / Notes
                const Text('Coaching Rationale & Description', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _summaryController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() => _isDirty = true),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 20),

                if (_isMultiDay) ...[
                  // Multi-Day Split Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_view_week, color: Colors.lightBlueAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WEEKLY SPLIT SCHEDULE (${_editableDays.length} WORKOUT DAYS)',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Each day is a distinct workout session with dedicated exercises scheduled for that weekday.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Separate workout-day cards
                  ..._editableDays.asMap().entries.map((dayEntry) {
                    final dayIdx = dayEntry.key;
                    final day = dayEntry.value;
                    return _buildWorkoutDayCard(dayIdx, day);
                  }),
                ] else ...[
                  // Exercises Section Header
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, size: 18, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Text(
                        'PRESCRIBED EXERCISES (${_editableExercises.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Exercise', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _addExercise,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Exercises List
                  ..._editableExercises.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final ex = entry.value;
                    return _buildExerciseEditCard(idx, ex);
                  }),
                ],
              ],
            ),
          ),

          // Footer actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                if (_isDirty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.save, size: 18),
                    label: const Text('SAVE EDITS', style: TextStyle(fontWeight: FontWeight.w900)),
                    onPressed: _isSaving ? null : _saveModifications,
                  ),
                const Spacer(),
                if (isActionable)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('ASSIGN WORKOUT', style: TextStyle(fontWeight: FontWeight.w900)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      AdminProposalAssignmentDialog.show(
                        context: context,
                        proposal: widget.proposal,
                        aiCoachRepository: widget.aiCoachRepository,
                        workoutRepository: widget.workoutRepository,
                        onAssigned: () {
                          widget.proposal.status = AiProposalStatus.approved;
                          widget.onProposalUpdated();
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutDayCard(int dayIdx, Map<String, dynamic> day) {
    final dayName = day['day'] ?? day['dayName'] ?? day['weekday'] ?? 'Day ${dayIdx + 1}';
    final sessionTitle = day['sessionTitle'] ?? day['title'] ?? 'Session';
    final splitCat = day['splitCategory'] ?? day['category'] ?? (sessionTitle.toString().contains('Pull') ? 'Pull' : (sessionTitle.toString().contains('Leg') ? 'Legs' : 'Push'));
    final targetMuscles = day['targetMuscleGroup'] ?? (day['targetMuscles'] is List ? (day['targetMuscles'] as List).join(', ') : 'Full Body');
    final duration = day['estimatedDurationMinutes'] ?? 50;
    final exercises = (day['exercises'] as List<Map<String, dynamic>>?) ?? [];
    final splitColor = getSplitBadgeColor(splitCat.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: splitColor.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Card Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: splitColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: splitColor),
                      ),
                      child: Text(
                        dayName.toString(),
                        style: TextStyle(color: splitColor, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Change workout category',
                      initialValue: splitCat.toString(),
                      onSelected: (val) {
                        setState(() {
                          day['splitCategory'] = val;
                          day['category'] = val;
                          _isDirty = true;
                        });
                      },
                      itemBuilder: (ctx) => [
                        'Push',
                        'Pull',
                        'Legs',
                        'Upper',
                        'Lower',
                        'Full Body',
                        'Strength',
                        'Conditioning',
                        'Cardio',
                        'Mobility',
                      ].map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              splitCat.toString().toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text('~${duration}m', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: sessionTitle.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    hintText: 'Session title (e.g. Monday Push)...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  onChanged: (val) {
                    day['sessionTitle'] = val;
                    day['title'] = val;
                    setState(() => _isDirty = true);
                  },
                ),
                Row(
                  children: [
                    const Icon(Icons.accessibility_new, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        initialValue: targetMuscles.toString(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 2),
                          border: InputBorder.none,
                          prefixText: 'Target: ',
                          prefixStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          hintText: 'e.g. Chest • Shoulders • Triceps',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                        ),
                        onChanged: (val) {
                          day['targetMuscleGroup'] = val;
                          setState(() => _isDirty = true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Day Exercises List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, size: 14, color: AppColors.primaryRed),
                const SizedBox(width: 6),
                Text(
                  'EXERCISES (${exercises.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 13),
                  label: const Text('Builder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _openDayInSessionBuilder(dayIdx),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: splitColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Exercise', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _addExerciseToDay(dayIdx),
                ),
              ],
            ),
          ),

          // Day Exercises
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: exercises.asMap().entries.map((exEntry) {
                final exIdx = exEntry.key;
                final ex = exEntry.value;
                return _buildExerciseEditCardForDay(dayIdx, exIdx, ex, exercises.length);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseEditCardForDay(int dayIdx, int exIdx, Map<String, dynamic> ex, int totalCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${exIdx + 1}.', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: ex['exerciseName']?.toString() ?? ex['name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 2),
                    border: InputBorder.none,
                    hintText: 'Exercise name...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  onChanged: (val) {
                    ex['exerciseName'] = val;
                    setState(() => _isDirty = true);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Move Up',
                onPressed: exIdx > 0 ? () => _moveExerciseInDay(dayIdx, exIdx, exIdx - 1) : null,
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Move Down',
                onPressed: exIdx < totalCount - 1 ? () => _moveExerciseInDay(dayIdx, exIdx, exIdx + 1) : null,
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.primaryRed),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Replace Exercise from Library',
                onPressed: () => _replaceExerciseInDay(dayIdx, exIdx),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove Exercise',
                onPressed: () => _removeExerciseFromDay(dayIdx, exIdx),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 12),
          Row(
            children: [
              _numericField('Sets', ex['sets']?.toString() ?? '3', (v) {
                ex['sets'] = int.tryParse(v) ?? 3;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 6),
              _textField('Reps', ex['targetReps']?.toString() ?? ex['reps']?.toString() ?? '8-12', (v) {
                ex['targetReps'] = v;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 6),
              _numericField('Weight (kg)', ex['targetWeight']?.toString() ?? ex['weight']?.toString() ?? '20', (v) {
                ex['targetWeight'] = double.tryParse(v) ?? 20.0;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 6),
              _numericField('Rest (s)', ex['restSeconds']?.toString() ?? ex['rest']?.toString() ?? '90', (v) {
                ex['restSeconds'] = int.tryParse(v) ?? 90;
                setState(() => _isDirty = true);
              }),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _textField('Tempo', ex['tempo']?.toString() ?? '3-1-1-0', (v) {
                ex['tempo'] = v;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 6),
              _numericField('RPE', ex['targetRpe']?.toString() ?? '8.0', (v) {
                ex['targetRpe'] = double.tryParse(v) ?? 8.0;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 6),
              _numericField('RIR', ex['targetRir']?.toString() ?? '2', (v) {
                ex['targetRir'] = int.tryParse(v) ?? 2;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 6),
              _textField('Superset', ex['supersetTag']?.toString() ?? '', (v) {
                ex['supersetTag'] = v.trim().isEmpty ? null : v.trim().toUpperCase();
                setState(() => _isDirty = true);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseEditCard(int index, Map<String, dynamic> ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${index + 1}.', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: ex['exerciseName']?.toString() ?? ex['name']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    hintText: 'Exercise name...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                  ),
                  onChanged: (val) {
                    ex['exerciseName'] = val;
                    setState(() => _isDirty = true);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Move Up',
                onPressed: index > 0 ? () => _moveExercise(index, index - 1) : null,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Move Down',
                onPressed: index < _editableExercises.length - 1 ? () => _moveExercise(index, index + 1) : null,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 20, color: AppColors.primaryRed),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Replace Exercise from Library',
                onPressed: () => _replaceExercise(index),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove Exercise',
                onPressed: () => _removeExercise(index),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 16),
          Row(
            children: [
              _numericField('Sets', ex['sets']?.toString() ?? '3', (v) {
                ex['sets'] = int.tryParse(v) ?? 3;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 8),
              _textField('Reps', ex['targetReps']?.toString() ?? ex['reps']?.toString() ?? '8-12', (v) {
                ex['targetReps'] = v;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 8),
              _numericField('Weight (kg)', ex['targetWeight']?.toString() ?? ex['weight']?.toString() ?? '20', (v) {
                ex['targetWeight'] = double.tryParse(v) ?? 20.0;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 8),
              _numericField('Rest (s)', ex['restSeconds']?.toString() ?? ex['rest']?.toString() ?? '90', (v) {
                ex['restSeconds'] = int.tryParse(v) ?? 90;
                setState(() => _isDirty = true);
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _textField('Tempo', ex['tempo']?.toString() ?? '3-1-1-0', (v) {
                ex['tempo'] = v;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 8),
              _numericField('RPE', ex['targetRpe']?.toString() ?? '8.0', (v) {
                ex['targetRpe'] = double.tryParse(v) ?? 8.0;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 8),
              _numericField('RIR', ex['targetRir']?.toString() ?? '2', (v) {
                ex['targetRir'] = int.tryParse(v) ?? 2;
                setState(() => _isDirty = true);
              }),
              const SizedBox(width: 8),
              _textField('Superset', ex['supersetTag']?.toString() ?? '', (v) {
                ex['supersetTag'] = v.trim().isEmpty ? null : v.trim().toUpperCase();
                setState(() => _isDirty = true);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numericField(String label, String initial, void Function(String) onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: initial,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, String initial, void Function(String) onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: initial,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet for In-depth Diet / Macro Proposal Inspection and Inline Editing.
/// Bottom Sheet for In-depth Diet / Macro Proposal Inspection and Inline Editing.
class DietProposalDetailSheet extends StatefulWidget {
  final AiProposal proposal;
  final AiCoachRepository aiCoachRepository;
  final VoidCallback onProposalUpdated;

  const DietProposalDetailSheet({
    super.key,
    required this.proposal,
    required this.aiCoachRepository,
    required this.onProposalUpdated,
  });

  @override
  State<DietProposalDetailSheet> createState() => DietProposalDetailSheetState();
}

typedef _DietProposalDetailSheet = DietProposalDetailSheet;

class DietProposalDetailSheetState extends State<DietProposalDetailSheet> {
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _waterController;
  late TextEditingController _notesController;

  late String _planKind;
  late List<Map<String, dynamic>> _editableMeals;
  final Set<int> _expandedMealIndices = {};
  bool _isSaving = false;
  bool _isActionInProgress = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    final payload = Map<String, dynamic>.from(p.payload);

    _titleController = TextEditingController(text: p.title);
    _summaryController = TextEditingController(text: p.summary);
    _planKind = payload['planKind']?.toString() ?? 'DIET_PLAN';

    final calories = payload['dailyCalories'] ?? payload['calories'] ?? payload['targetCalories'] ?? 2000;
    final protein = payload['protein'] ?? payload['proteinGrams'] ?? payload['targetProtein'] ?? 150;
    final carbs = payload['carbohydrates'] ?? payload['carbGrams'] ?? payload['carbs'] ?? payload['targetCarbs'] ?? 200;
    final fat = payload['fat'] ?? payload['fatGrams'] ?? payload['targetFat'] ?? 60;
    final fiber = payload['fiber'] ?? payload['fiberGrams'] ?? 30;
    final water = payload['waterTargetLiters'] ?? payload['targetWaterLiters'] ?? payload['waterLiters'] ?? 3.5;
    final notes = payload['notes'] ?? payload['coachNotes'] ?? '';

    _caloriesController = TextEditingController(text: calories.toString());
    _proteinController = TextEditingController(text: protein.toString());
    _carbsController = TextEditingController(text: carbs.toString());
    _fatController = TextEditingController(text: fat.toString());
    _fiberController = TextEditingController(text: fiber.toString());
    _waterController = TextEditingController(text: water.toString());
    _notesController = TextEditingController(text: notes.toString());

    _editableMeals = [];
    if (payload['meals'] is List) {
      for (final m in (payload['meals'] as List)) {
        if (m is Map) {
          final copy = Map<String, dynamic>.from(m);
          final rawItems = (copy['items'] ?? copy['foods'] ?? []) as List;
          final normalizedItems = rawItems.map((i) {
            if (i is Map) {
              final it = Map<String, dynamic>.from(i);
              final fName = it['foodName'] ?? it['name'] ?? 'Food';
              final rawQty = it['quantity'];
              final num parsedQty = rawQty is num ? rawQty : (num.tryParse(rawQty?.toString() ?? '') ?? 100);
              final normalizedQty = (parsedQty % 1 == 0) ? parsedQty.toInt() : parsedQty.toDouble();
              return {
                'foodId': it['foodId'] ?? 'f_${DateTime.now().millisecondsSinceEpoch}',
                'foodName': fName,
                'name': fName,
                'quantity': normalizedQty,
                'unit': it['unit']?.toString() ?? 'g',
                'calories': (it['calories'] as num?)?.round() ?? 0,
                'protein': (it['protein'] as num?)?.toDouble() ?? 0.0,
                'carbs': ((it['carbs'] ?? it['carbohydrates']) as num?)?.toDouble() ?? 0.0,
                'carbohydrates': ((it['carbs'] ?? it['carbohydrates']) as num?)?.toDouble() ?? 0.0,
                'fat': (it['fat'] as num?)?.toDouble() ?? 0.0,
                'fiber': (it['fiber'] as num?)?.toDouble() ?? 0.0,
                'notes': it['notes']?.toString() ?? '',
                'substitutions': (it['substitutions'] ?? it['substitute'])?.toString() ?? '',
              };
            }
            return i;
          }).toList();

          copy['items'] = normalizedItems;
          copy['foods'] = normalizedItems;
          _editableMeals.add(copy);
        }
      }
    }

    // Expand all meals by default so the coach can review them immediately
    for (var i = 0; i < _editableMeals.length; i++) {
      _expandedMealIndices.add(i);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _waterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, num> _calculateMealTotals(Map<String, dynamic> meal) {
    final items = (meal['items'] ?? meal['foods'] ?? []) as List;
    num cals = 0;
    num pro = 0;
    num crb = 0;
    num ft = 0;
    for (final it in items) {
      if (it is Map) {
        cals += (it['calories'] as num?) ?? 0;
        pro += (it['protein'] as num?) ?? 0;
        crb += ((it['carbs'] ?? it['carbohydrates']) as num?) ?? 0;
        ft += (it['fat'] as num?) ?? 0;
      }
    }
    return {
      'calories': cals.round(),
      'protein': (pro * 10).round() / 10,
      'carbs': (crb * 10).round() / 10,
      'fat': (ft * 10).round() / 10,
    };
  }

  Map<String, dynamic> _buildPreparedPayload() {
    final updatedPayload = Map<String, dynamic>.from(widget.proposal.payload);
    updatedPayload['title'] = _titleController.text.trim();
    updatedPayload['planName'] = _titleController.text.trim();
    updatedPayload['summary'] = _summaryController.text.trim();
    updatedPayload['planKind'] = _planKind;

    final cal = int.tryParse(_caloriesController.text.trim()) ?? 2000;
    final pro = int.tryParse(_proteinController.text.trim()) ?? 150;
    final crb = int.tryParse(_carbsController.text.trim()) ?? 200;
    final ft = int.tryParse(_fatController.text.trim()) ?? 60;
    final fbr = int.tryParse(_fiberController.text.trim()) ?? 30;
    final wtr = double.tryParse(_waterController.text.trim()) ?? 3.5;

    updatedPayload['dailyCalories'] = cal;
    updatedPayload['calories'] = cal;
    updatedPayload['targetCalories'] = cal;

    updatedPayload['protein'] = pro;
    updatedPayload['proteinGrams'] = pro;
    updatedPayload['targetProtein'] = pro;

    updatedPayload['carbohydrates'] = crb;
    updatedPayload['carbGrams'] = crb;
    updatedPayload['carbs'] = crb;
    updatedPayload['targetCarbs'] = crb;

    updatedPayload['fat'] = ft;
    updatedPayload['fatGrams'] = ft;
    updatedPayload['targetFat'] = ft;

    updatedPayload['fiber'] = fbr;
    updatedPayload['waterTargetLiters'] = wtr;
    updatedPayload['notes'] = _notesController.text.trim();

    if (_planKind != 'MACRO_ONLY') {
      updatedPayload['meals'] = _editableMeals;
    } else {
      updatedPayload['meals'] = [];
    }
    return updatedPayload;
  }

  Future<bool> _saveModifications({bool showFeedback = true}) async {
    setState(() => _isSaving = true);
    final updatedPayload = _buildPreparedPayload();

    final ok = await widget.aiCoachRepository.editProposal(widget.proposal.id, updatedPayload);
    if (!mounted) return false;
    setState(() => _isSaving = false);

    if (ok) {
      setState(() {
        widget.proposal.title = _titleController.text.trim();
        widget.proposal.summary = _summaryController.text.trim();
        widget.proposal.status = AiProposalStatus.edited;
        widget.proposal.payload = updatedPayload;
        _isDirty = false;
      });
      widget.onProposalUpdated();
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✔ Diet / Macro proposal modifications saved to database.'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
      return true;
    } else {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save proposal modifications.'), backgroundColor: AppColors.primaryRed),
        );
      }
      return false;
    }
  }

  Future<void> _approveAndAssign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Approve & Assign Diet Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign "${_titleController.text.trim()}" to ${widget.proposal.clientName ?? "athlete"} as their active diet protocol?',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, color: Colors.tealAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _planKind == 'MACRO_ONLY'
                          ? 'Protocol: Macro-only targets (${_caloriesController.text} kcal)'
                          : 'Protocol: Full meal plan (${_editableMeals.length} prescribed meals)',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Confirm Assign', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    if (_isDirty) {
      final saved = await _saveModifications(showFeedback: false);
      if (!saved && mounted) {
        setState(() => _isActionInProgress = false);
        return;
      }
    }

    final ok = await widget.aiCoachRepository.approveProposal(
      widget.proposal.id,
      clientIds: widget.proposal.clientId != null ? [widget.proposal.clientId!] : null,
      proposalData: widget.proposal.toJson(),
    );
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (ok) {
      widget.proposal.status = AiProposalStatus.approved;
      widget.onProposalUpdated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✔ "${widget.proposal.title}" approved and assigned to ${widget.proposal.clientName}!'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve proposal.'), backgroundColor: AppColors.primaryRed),
      );
    }
  }

  Future<void> _rejectProposal() async {
    final reasonController = TextEditingController(text: 'Admin requested nutrition revisions');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Reject Diet Proposal', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting this proposal will archive it without assigning any plan to ${widget.proposal.clientName ?? "athlete"}.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Reason for rejection (optional)',
                labelStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    final ok = await widget.aiCoachRepository.rejectProposal(widget.proposal.id, reason: reasonController.text.trim());
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (ok) {
      widget.proposal.status = AiProposalStatus.rejected;
      widget.onProposalUpdated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diet proposal rejected.'), backgroundColor: AppColors.primaryRed),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject proposal.'), backgroundColor: AppColors.primaryRed),
      );
    }
  }

  void _addMeal() {
    setState(() {
      final newIndex = _editableMeals.length;
      _editableMeals.add({
        'mealType': 'Meal ${_editableMeals.length + 1}',
        'timing': '12:00 PM',
        'notes': '',
        'foods': [
          {
            'foodId': 'f_${DateTime.now().millisecondsSinceEpoch}',
            'foodName': 'Food Item',
            'name': 'Food Item',
            'quantity': 100.0,
            'unit': 'g',
            'calories': 200,
            'protein': 15.0,
            'carbs': 20.0,
            'fat': 5.0,
            'fiber': 2.0,
            'notes': '',
            'substitutions': '',
          }
        ],
        'items': [
          {
            'foodId': 'f_${DateTime.now().millisecondsSinceEpoch}',
            'foodName': 'Food Item',
            'name': 'Food Item',
            'quantity': 100.0,
            'unit': 'g',
            'calories': 200,
            'protein': 15.0,
            'carbs': 20.0,
            'fat': 5.0,
            'fiber': 2.0,
            'notes': '',
            'substitutions': '',
          }
        ],
      });
      _expandedMealIndices.add(newIndex);
      _isDirty = true;
    });
  }

  void _removeMeal(int index) {
    setState(() {
      _editableMeals.removeAt(index);
      _expandedMealIndices.remove(index);
      _isDirty = true;
    });
  }

  void _openMealMetadataEditor(Map<String, dynamic> meal, int index) {
    final nameCtrl = TextEditingController(text: meal['mealType'] ?? meal['name'] ?? '');
    final timeCtrl = TextEditingController(text: meal['timing'] ?? '');
    final notesCtrl = TextEditingController(text: meal['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Edit Meal Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Meal Name', labelStyle: TextStyle(color: AppColors.textTertiary)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: timeCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Timing (e.g. 08:00 AM)', labelStyle: TextStyle(color: AppColors.textTertiary)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Preparation / Timing Notes', labelStyle: TextStyle(color: AppColors.textTertiary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              setState(() {
                meal['mealType'] = nameCtrl.text.trim();
                meal['name'] = nameCtrl.text.trim();
                meal['timing'] = timeCtrl.text.trim();
                meal['notes'] = notesCtrl.text.trim();
                _isDirty = true;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openFoodEditor(int mealIndex, [int? foodIndex]) {
    final meal = _editableMeals[mealIndex];
    final foodsList = (meal['items'] ?? meal['foods'] ?? []) as List;
    final isEditing = foodIndex != null && foodIndex < foodsList.length;
    final existing = isEditing && foodsList[foodIndex] is Map ? foodsList[foodIndex] as Map<String, dynamic> : <String, dynamic>{};

    final nameController = TextEditingController(text: existing['foodName'] ?? existing['name'] ?? '');
    final rawQty = existing['quantity'] ?? 100;
    final qtyText = (rawQty is num && rawQty % 1 == 0) ? rawQty.toInt().toString() : rawQty.toString();
    final qtyController = TextEditingController(text: qtyText);
    final unitController = TextEditingController(text: existing['unit'] ?? 'g');
    final calController = TextEditingController(text: (existing['calories'] ?? 200).toString());
    final proController = TextEditingController(text: (existing['protein'] ?? 15).toString());
    final carbsController = TextEditingController(text: (existing['carbs'] ?? existing['carbohydrates'] ?? 20).toString());
    final fatController = TextEditingController(text: (existing['fat'] ?? 5).toString());
    final notesController = TextEditingController(text: existing['notes'] ?? '');
    final subsController = TextEditingController(text: existing['substitutions'] ?? existing['substitute'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          isEditing ? 'Edit Food Item' : 'Add Food Item to ${meal['mealType'] ?? 'Meal'}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Food Name',
                  labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  hintText: 'e.g. Grilled Chicken Breast',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Unit (g/ml/piece)',
                        labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
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
                      controller: calController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Calories (kcal)',
                        labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: proController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Preparation Note (optional)',
                  labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  hintText: 'e.g. Steamed with minimal olive oil',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subsController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Allowed Substitutions (optional)',
                  labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  hintText: 'e.g. Fish fillet or Paneer',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final fName = nameController.text.trim();
              if (fName.isEmpty) return;
              final rawQty = double.tryParse(qtyController.text.trim()) ?? 100.0;
              final qty = (rawQty % 1 == 0) ? rawQty.toInt() : rawQty;
              final unit = unitController.text.trim().isNotEmpty ? unitController.text.trim() : 'g';
              final cal = int.tryParse(calController.text.trim()) ?? 0;
              final pro = double.tryParse(proController.text.trim()) ?? 0.0;
              final crb = double.tryParse(carbsController.text.trim()) ?? 0.0;
              final ft = double.tryParse(fatController.text.trim()) ?? 0.0;

              final updatedItem = {
                'foodId': existing['foodId'] ?? 'f_${DateTime.now().millisecondsSinceEpoch}',
                'foodName': fName,
                'name': fName,
                'quantity': qty,
                'unit': unit,
                'calories': cal,
                'protein': pro,
                'carbs': crb,
                'carbohydrates': crb,
                'fat': ft,
                'notes': notesController.text.trim(),
                'substitutions': subsController.text.trim(),
              };

              setState(() {
                if (isEditing) {
                  foodsList[foodIndex] = updatedItem;
                } else {
                  foodsList.add(updatedItem);
                }
                meal['items'] = foodsList;
                meal['foods'] = foodsList;
                _isDirty = true;
              });

              Navigator.of(ctx).pop();
            },
            child: Text(isEditing ? 'Save Food' : 'Add Food', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeFoodItem(int mealIndex, int foodIndex) {
    setState(() {
      final meal = _editableMeals[mealIndex];
      final foodsList = (meal['items'] ?? meal['foods'] ?? []) as List;
      if (foodIndex < foodsList.length) {
        foodsList.removeAt(foodIndex);
        meal['items'] = foodsList;
        meal['foods'] = foodsList;
        _isDirty = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final payload = proposal.payload;
    final athleteName = proposal.clientName ?? payload['clientName'] ?? 'Athlete';
    final clientId = proposal.clientId ?? payload['clientId'] ?? 'AXG';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header with Client Name and ID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.teal),
                            ),
                            child: const Text(
                              'DIET & MACRO PROPOSAL',
                              style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'ID: $clientId',
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (_isDirty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warningYellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('UNSAVED CHANGES', style: TextStyle(color: AppColors.warningYellow, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        athleteName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Scrollable Editor Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Plan Format Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _planKind = 'DIET_PLAN';
                            _isDirty = true;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _planKind != 'MACRO_ONLY' ? Colors.teal : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Full Diet Plan (With Meals)',
                                style: TextStyle(
                                  color: _planKind != 'MACRO_ONLY' ? Colors.white : AppColors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _planKind = 'MACRO_ONLY';
                            _isDirty = true;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _planKind == 'MACRO_ONLY' ? Colors.teal : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Macro Targets Only',
                                style: TextStyle(
                                  color: _planKind == 'MACRO_ONLY' ? Colors.white : AppColors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Title & Summary
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Proposal Title',
                    labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() => _isDirty = true),
                ),

                const SizedBox(height: 10),

                TextFormField(
                  controller: _summaryController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Summary / Clinical Notes',
                    labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() => _isDirty = true),
                ),

                const SizedBox(height: 18),

                // Daily Targets
                const Text(
                  'DAILY TARGET NUTRITION',
                  style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _numericField('Calories (kcal)', _caloriesController),
                    const SizedBox(width: 8),
                    _numericField('Protein (g)', _proteinController),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _numericField('Carbs (g)', _carbsController),
                    const SizedBox(width: 8),
                    _numericField('Fat (g)', _fatController),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _numericField('Fiber (g)', _fiberController),
                    const SizedBox(width: 8),
                    _numericField('Water (L/day)', _waterController),
                  ],
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Coach / Dietitian Guidance',
                    labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() => _isDirty = true),
                ),

                const SizedBox(height: 20),

                // Prescribed Meals Section
                if (_planKind != 'MACRO_ONLY') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PRESCRIBED MEALS (${_editableMeals.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Meal'),
                        onPressed: _addMeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_editableMeals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No meals prescribed yet. Tap "+ Add Meal" to create breakfast, lunch, or dinner.',
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ..._editableMeals.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final meal = entry.value;
                      return _buildExpandableMealCard(meal, idx);
                    }),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.tune, color: Colors.tealAccent, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flexible Macro-Only Target Protocol',
                                style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No fixed meals required. The client tracks daily calories and macros towards target values.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar with Reject, Save Changes, and Approve & Assign
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width > 32 ? MediaQuery.of(context).size.width - 32 : 300,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryRed),
                            foregroundColor: AppColors.primaryRed,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: _isActionInProgress ? null : _rejectProposal,
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _isDirty ? AppColors.warningYellow : Colors.teal),
                            foregroundColor: _isDirty ? AppColors.warningYellow : Colors.tealAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: _isSaving
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save, size: 14),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Changes',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _isSaving || _isActionInProgress ? null : () => _saveModifications(),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: _isActionInProgress
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve & Assign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _isActionInProgress || _isSaving ? null : _approveAndAssign,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableMealCard(Map<String, dynamic> meal, int index) {
    final mealType = meal['mealType'] ?? meal['name'] ?? 'Meal ${index + 1}';
    final timing = meal['timing'] ?? '';
    final notes = meal['notes']?.toString() ?? '';
    final foodsList = (meal['items'] ?? meal['foods'] ?? []) as List;
    final isExpanded = _expandedMealIndices.contains(index);
    final totals = _calculateMealTotals(meal);

    IconData mealIcon = Icons.restaurant;
    final lower = mealType.toString().toLowerCase();
    if (lower.contains('breakfast')) {
      mealIcon = Icons.free_breakfast;
    } else if (lower.contains('lunch')) {
      mealIcon = Icons.lunch_dining;
    } else if (lower.contains('dinner')) {
      mealIcon = Icons.dinner_dining;
    } else if (lower.contains('snack')) {
      mealIcon = Icons.cookie_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpanded ? Colors.teal.withOpacity(0.4) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expandable Card Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMealIndices.remove(index);
                } else {
                  _expandedMealIndices.add(index);
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(mealIcon, size: 18, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mealType.toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (timing.toString().isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  timing.toString(),
                                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${totals['calories']} kcal • ${totals['protein']}g P • ${totals['carbs']}g C • ${totals['fat']}g F',
                          style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${foodsList.length} items',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details & Editing Controls
          if (isExpanded) ...[
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notes,
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Food Items Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'FOOD ITEMS',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _openMealMetadataEditor(meal, index),
                            child: const Row(
                              children: [
                                Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
                                SizedBox(width: 3),
                                Text('Timing & Notes', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _openFoodEditor(index),
                            child: const Row(
                              children: [
                                Icon(Icons.add_circle_outline, size: 14, color: Colors.tealAccent),
                                SizedBox(width: 4),
                                Text('Add Food', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (foodsList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6)),
                      child: const Center(
                        child: Text('No food items in this meal.', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      ),
                    )
                  else
                    ...foodsList.asMap().entries.map((itemEntry) {
                      final fIdx = itemEntry.key;
                      final f = itemEntry.value;
                      if (f is! Map) return const SizedBox.shrink();

                      final fName = f['foodName'] ?? f['name'] ?? 'Food';
                      final qty = f['quantity'] ?? 100;
                      final unit = f['unit'] ?? 'g';
                      final cal = f['calories'] ?? 0;
                      final pro = f['protein'] ?? 0;
                      final crb = f['carbs'] ?? f['carbohydrates'] ?? 0;
                      final ft = f['fat'] ?? 0;
                      final foodNotes = f['notes']?.toString() ?? '';
                      final foodSubs = (f['substitutions'] ?? f['substitute'])?.toString() ?? '';
                      final formattedQty = qty is num ? qty.toDouble().toStringAsFixed(1) : qty.toString();

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: Colors.tealAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          fName.toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$formattedQty $unit • $cal kcal',
                                          style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pro}g P • ${crb}g C • ${ft}g F',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                  ),
                                  if (foodNotes.isNotEmpty || foodSubs.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        [
                                          if (foodNotes.isNotEmpty) (foodNotes.startsWith('Prep:') ? foodNotes : 'Prep: $foodNotes'),
                                          if (foodSubs.isNotEmpty) (foodSubs.startsWith('Sub:') ? foodSubs : 'Sub: $foodSubs'),
                                        ].join(' • '),
                                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textTertiary),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _openFoodEditor(index, fIdx),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.primaryRed),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeFoodItem(index, fIdx),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryRed,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.delete_forever, size: 14),
                      label: const Text('Delete Meal', style: TextStyle(fontSize: 11)),
                      onPressed: () => _removeMeal(index),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numericField(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (_) => setState(() => _isDirty = true),
          ),
        ],
      ),
    );
  }
}
