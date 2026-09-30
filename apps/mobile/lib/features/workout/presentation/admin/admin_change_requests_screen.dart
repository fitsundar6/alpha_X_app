import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/exercise/presentation/widgets/exercise_picker_dialog.dart';

class AdminChangeRequestsScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const AdminChangeRequestsScreen({
    super.key,
    required this.workoutRepository,
  });

  @override
  State<AdminChangeRequestsScreen> createState() =>
      _AdminChangeRequestsScreenState();
}

class _AdminChangeRequestsScreenState extends State<AdminChangeRequestsScreen> {
  String _selectedFilter = 'ALL'; // ALL, PENDING, APPROVED, REJECTED
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepoChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  List<ExerciseChangeRequest> get _filteredRequests {
    final query = _searchController.text.trim().toLowerCase();
    return widget.workoutRepository.changeRequests.where((req) {
      if (_selectedFilter == 'PENDING' && req.status != 'PENDING') return false;
      if (_selectedFilter == 'APPROVED' && req.status != 'APPROVED') return false;
      if (_selectedFilter == 'REJECTED' && req.status != 'REJECTED') return false;

      if (query.isNotEmpty) {
        final matchesClient = req.clientName.toLowerCase().contains(query);
        final matchesExercise = req.exerciseName.toLowerCase().contains(query);
        final matchesSession = req.sessionTitle.toLowerCase().contains(query);
        final matchesReason = req.reason.toLowerCase().contains(query);
        if (!matchesClient && !matchesExercise && !matchesSession && !matchesReason) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openApproveDialog(ExerciseChangeRequest req) {
    String? selectedReplacementId = req.replacementExerciseId;
    String? selectedReplacementName = req.replacementExerciseName;
    final noteController = TextEditingController(text: req.adminNote ?? '');
    bool isPermanent = req.isPermanent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'APPROVE CHANGE REQUEST',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Client: ${req.clientName} • Session: ${req.sessionTitle}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  'Requested to replace: ${req.exerciseName}',
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                // Select Replacement Exercise
                const Text(
                  'Select Biomechanical Replacement:',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await ExercisePickerDialog.show(
                      context,
                      excludedExerciseId: req.exerciseId,
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedReplacementId = picked.id;
                        selectedReplacementName = picked.displayName;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedReplacementName ?? 'Choose replacement exercise...',
                          style: TextStyle(
                            color: selectedReplacementName != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                            fontSize: 13,
                            fontWeight: selectedReplacementName != null ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.primaryRed),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Trainer Note
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Trainer Coaching Directive / Note',
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    hintText: 'e.g. Keep dumbbells angled at 45 deg, avoid full lockout...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                const SizedBox(height: 12),

                // Permanent vs Today Only Toggle
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.primaryRed,
                  title: const Text(
                    'Apply replacement permanently to client workout plan',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'If unchecked, replacement is active for current session only.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  value: isPermanent,
                  onChanged: (val) => setModalState(() => isPermanent = val ?? false),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      widget.workoutRepository.approveChangeRequest(
                        req.id,
                        replacementExerciseId: selectedReplacementId,
                        replacementExerciseName: selectedReplacementName,
                        adminNote: noteController.text.trim(),
                        isPermanent: isPermanent,
                      );
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exercise change request approved!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: const Text(
                      'APPROVE REQUEST',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openRejectDialog(ExerciseChangeRequest req) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reject Change Request',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client: ${req.clientName}\nExercise: ${req.exerciseName}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Reason for rejection or trainer instructions...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceCard,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              widget.workoutRepository.rejectChangeRequest(
                req.id,
                adminNote: noteController.text.trim(),
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Change request rejected'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Reject Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _filteredRequests;
    final pendingCount = widget.workoutRepository.changeRequests
        .where((r) => r.status == 'PENDING')
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'CHANGE REQUESTS',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 15),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by client, exercise, reason...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterChip('ALL', 'All (${widget.workoutRepository.changeRequests.length})'),
                    const SizedBox(width: 8),
                    _filterChip('PENDING', 'Pending ($pendingCount)', isBadge: pendingCount > 0),
                    const SizedBox(width: 8),
                    _filterChip('APPROVED', 'Approved'),
                    const SizedBox(width: 8),
                    _filterChip('REJECTED', 'Rejected'),
                  ],
                ),
              ],
            ),
          ),

          // Requests List
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inbox_outlined, size: 54, color: AppColors.textTertiary),
                          SizedBox(height: 12),
                          Text(
                            'No Change Requests Found',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Client exercise swap and modification requests will appear here for trainer review.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (ctx, index) {
                      final req = requests[index];
                      return _buildRequestCard(req);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label, {bool isBadge = false}) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isBadge ? AppColors.warning : AppColors.primaryRed,
      backgroundColor: AppColors.surfaceCard,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? (isBadge ? Colors.black : Colors.white) : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? (isBadge ? AppColors.warning : AppColors.primaryRed) : AppColors.border,
        ),
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = filterKey);
      },
    );
  }

  Widget _buildRequestCard(ExerciseChangeRequest req) {
    Color statusColor;
    switch (req.status) {
      case 'APPROVED':
        statusColor = AppColors.success;
        break;
      case 'REJECTED':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: req.status == 'PENDING' ? AppColors.warning.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryRed,
                    child: Text(
                      req.clientName.isNotEmpty ? req.clientName[0] : 'C',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    req.clientName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Session: ${req.sessionTitle} • Movement: ${req.exerciseName}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '"${req.reason}"',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

          if (req.replacementExerciseName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Replacement: ${req.replacementExerciseName} (${req.isPermanent ? "Permanent" : "Session Only"})',
              style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],

          if (req.adminNote != null && req.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Trainer Note: ${req.adminNote}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],

          if (req.status == 'PENDING') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _openRejectDialog(req),
                    child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _openApproveDialog(req),
                    child: const Text('APPROVE / REPLACE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
