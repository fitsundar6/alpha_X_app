import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';

/// Modal dialog allowing Admin to inspect, accept, edit, or reject an AI-generated proposal.
/// Enforces the strict rule: AI NEVER directly assigns a plan to an athlete.
/// Every proposal requires explicit Admin review.
class AdminAiProposalReviewDialog extends StatefulWidget {
  final AiProposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final void Function(String? reason) onReject;

  const AdminAiProposalReviewDialog({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onEdit,
    required this.onReject,
  });

  static Future<void> show({
    required BuildContext context,
    required AiProposal proposal,
    required VoidCallback onAccept,
    required VoidCallback onEdit,
    required void Function(String? reason) onReject,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminAiProposalReviewDialog(
        proposal: proposal,
        onAccept: onAccept,
        onEdit: onEdit,
        onReject: onReject,
      ),
    );
  }

  @override
  State<AdminAiProposalReviewDialog> createState() =>
      _AdminAiProposalReviewDialogState();
}

class _AdminAiProposalReviewDialogState
    extends State<AdminAiProposalReviewDialog> {
  final Set<int> _expandedMealIndices = {};

  @override
  void initState() {
    super.initState();
    final p = widget.proposal.payload;
    if (p['meals'] is List) {
      for (var i = 0; i < (p['meals'] as List).length; i++) {
        _expandedMealIndices.add(i);
      }
    }
  }

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
        return 'PENDING ADMIN REVIEW';
    }
  }

  void _confirmAccept() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Confirm Plan Assignment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to approve this AI ${widget.proposal.type.name.toUpperCase()} proposal and assign it to the athlete as their active plan?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).pop(); // close review sheet
              widget.onAccept();
            },
            child: const Text(
              'ACCEPT & ASSIGN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReject() {
    final reasonController = TextEditingController(
      text: 'Adjustments required before assignment',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Reject AI Proposal',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This AI proposal will NOT be assigned to the athlete. Please provide an optional reason for the audit log:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Reason for rejection...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).pop(); // close review sheet
              widget.onReject(reason.isEmpty ? null : reason);
            },
            child: const Text(
              'REJECT PROPOSAL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    final statusColor = _getStatusColor(proposal.status);
    final statusLabel = _getStatusLabel(proposal.status);

    final payload = proposal.payload;
    final isWorkout = proposal.type == AiProposalType.workout;
    final isDiet = proposal.type == AiProposalType.diet;

    final athleteName =
        proposal.clientName ??
        payload['clientName'] ??
        payload['workoutPlan']?['clientName'] ??
        'Athlete';

    final clientId = proposal.clientId ?? payload['clientId'] ?? 'AXG';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isWorkout
                                ? '🏋️ AI WORKOUT PLAN'
                                : (isDiet
                                      ? '🥗 AI DIET PLAN'
                                      : '📈 AI PROGRESSION'),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        proposal.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

          // Scrollable Body Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // Client Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              athleteName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: $clientId',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // AI Reasoning & Analysis Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.lightBlueAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            color: Colors.lightBlueAccent,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'AI ANALYSIS & REASONING',
                            style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        proposal.reason.isNotEmpty
                            ? proposal.reason
                            : proposal.summary,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppColors.warningYellow,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'AI NEVER directly assigns plans. Admin approval required for activation.',
                                style: TextStyle(
                                  color: AppColors.warningYellow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Specific Breakdown (Workout or Diet)
                if (isWorkout)
                  _buildWorkoutBreakdown(payload)
                else if (isDiet)
                  _buildDietBreakdown(payload)
                else
                  _buildGeneralBreakdown(payload),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Review Action Bar (Exactly the 3 actions: ACCEPT, EDIT, REJECT)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child:
                  proposal.status == AiProposalStatus.pending ||
                      proposal.status == AiProposalStatus.edited
                  ? Row(
                      children: [
                        // 1. REJECT
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primaryRed,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.primaryRed,
                              size: 18,
                            ),
                            label: const Text(
                              'REJECT',
                              style: TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: _confirmReject,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // 2. EDIT
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white54,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              'EDIT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(); // close sheet
                              widget.onEdit();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),

                        // 3. ACCEPT
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text(
                              'ACCEPT & ASSIGN',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: _confirmAccept,
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        proposal.status == AiProposalStatus.approved
                            ? '✔ Activated in athlete\'s active plan system.'
                            : '✖ Proposal closed without altering athlete\'s active plan.',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSplitColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('push')) return Colors.orangeAccent;
    if (lower.contains('pull')) return Colors.cyanAccent;
    if (lower.contains('leg')) return Colors.lightGreenAccent;
    if (lower.contains('upper')) return Colors.amberAccent;
    if (lower.contains('lower')) return Colors.purpleAccent;
    return AppColors.primaryRed;
  }

  Widget _buildWorkoutBreakdown(Map<String, dynamic> payload) {
    // If weeklySchedule is present and non-empty, render separate days
    if (payload['weeklySchedule'] is List && (payload['weeklySchedule'] as List).isNotEmpty) {
      final days = payload['weeklySchedule'] as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WEEKLY SPLIT SCHEDULE',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${days.length} Workout Days',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...days.asMap().entries.map((entry) {
            final dIdx = entry.key;
            final day = entry.value is Map ? entry.value as Map : {};
            final dayName = day['day'] ?? day['dayName'] ?? day['weekday'] ?? 'Day ${dIdx + 1}';
            final sessionTitle = day['sessionTitle'] ?? day['title'] ?? 'Session';
            final splitCat = day['splitCategory'] ?? day['category'] ?? (sessionTitle.toString().contains('Pull') ? 'Pull' : (sessionTitle.toString().contains('Leg') ? 'Legs' : 'Push'));
            final targetMuscleGroup = day['targetMuscleGroup'] ?? (day['targetMuscles'] is List ? (day['targetMuscles'] as List).join(', ') : 'Full Body');
            final duration = day['estimatedDurationMinutes'] ?? 50;
            final dayExercises = (day['exercises'] as List?) ?? [];
            final splitColor = _getSplitColor(splitCat.toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: splitColor.withOpacity(0.4), width: 1.2),
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
                          style: TextStyle(
                            color: splitColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          splitCat.toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sessionTitle.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${dayExercises.length} ex · ~${duration}m',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Target: $targetMuscleGroup',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  ...dayExercises.map((e) {
                    final name = e['exerciseName'] ?? e['name'] ?? 'Exercise';
                    final sets = e['sets'] ?? (e['setList'] as List?)?.length ?? 3;
                    final reps = e['targetReps'] ?? e['reps'] ?? '8-10';
                    final weight = e['targetWeight'] ?? e['weight'] ?? 0;
                    final rest = e['restSeconds'] ?? e['rest'] ?? 90;
                    final notes = e['notes'] ?? e['adminInstruction'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center, size: 14, color: AppColors.primaryRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                if (notes.toString().isNotEmpty)
                                  Text(
                                    notes.toString(),
                                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '$sets × $reps • ${weight > 0 ? '${weight}kg • ' : ''}${rest}s rest',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      );
    }

    // Parse exercises from payload
    List<dynamic> exercises = [];
    if (payload['exercises'] is List &&
        (payload['exercises'] as List).isNotEmpty) {
      exercises = payload['exercises'] as List;
    } else if (payload['workoutPlan']?['sessions'] is List &&
        (payload['workoutPlan']['sessions'] as List).isNotEmpty) {
      final firstSession = (payload['workoutPlan']['sessions'] as List).first;
      if (firstSession['exercises'] is List) {
        exercises = firstSession['exercises'] as List;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROPOSED WORKOUT STRUCTURE',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${exercises.length} Exercises',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...exercises.map((e) {
          final name = e['exerciseName'] ?? e['name'] ?? 'Exercise';
          final sets = e['sets'] ?? (e['setList'] as List?)?.length ?? 3;
          final reps = e['targetReps'] ?? e['reps'] ?? '8-10';
          final weight = e['targetWeight'] ?? e['weight'] ?? 0;
          final rpe = e['targetRpe'] ?? e['rpe'] ?? 8.0;
          final rir = e['targetRir'] ?? e['rir'] ?? 2;
          final rest = e['restSeconds'] ?? e['rest'] ?? 90;
          final notes = e['notes'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$sets sets × $reps reps',
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPill('Weight', '$weight kg', AppColors.accentRed),
                    const SizedBox(width: 6),
                    _buildPill('RPE', '$rpe', AppColors.info),
                    const SizedBox(width: 6),
                    _buildPill('RIR', '$rir', AppColors.gold),
                    const SizedBox(width: 6),
                    _buildPill('Rest', '${rest}s', AppColors.textSecondary),
                  ],
                ),
                if (notes.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Notes: $notes',
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
    );
  }

  Widget _buildDietBreakdown(Map<String, dynamic> payload) {
    final calories =
        payload['dailyCalories'] ??
        payload['calories'] ??
        payload['targetCalories'] ??
        2000;
    final protein =
        payload['protein'] ??
        payload['proteinGrams'] ??
        payload['targetProtein'] ??
        150;
    final carbs =
        payload['carbohydrates'] ??
        payload['carbGrams'] ??
        payload['carbs'] ??
        payload['targetCarbs'] ??
        200;
    final fat =
        payload['fat'] ?? payload['fatGrams'] ?? payload['targetFat'] ?? 60;
    final fiber = payload['fiber'] ?? payload['fiberGrams'] ?? 30;
    final water =
        payload['waterTargetLiters'] ??
        payload['targetWaterLiters'] ??
        payload['waterLiters'] ??
        3.5;

    List<dynamic> meals = [];
    if (payload['meals'] is List) {
      meals = payload['meals'] as List;
    }
    final isMacroOnly = payload['planKind'] == 'MACRO_ONLY' || meals.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Macros Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DAILY TARGET NUTRITION',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMacroStat(
                      'CALORIES',
                      '$calories',
                      'kcal',
                      AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMacroStat(
                      'PROTEIN',
                      '${protein}g',
                      '',
                      AppColors.accentRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMacroStat(
                      'CARBS',
                      '${carbs}g',
                      '',
                      AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMacroStat(
                      'FAT',
                      '${fat}g',
                      '',
                      AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fiber Target: ${fiber}g',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Water: ${water}L/day',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (isMacroOnly)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.lightBlueAccent.withOpacity(0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.tune, color: Colors.lightBlueAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FLEXIBLE MACRO-ONLY TARGET PROTOCOL',
                        style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'This plan prescribes daily calorie and macronutrient targets. The athlete hits these targets with flexible food choices without fixed meal schedules.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          const Text(
            'PRESCRIBED MEALS',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
        ],

        ...meals.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          final mealType = m['mealType'] ?? m['name'] ?? 'Meal';
          final timing = m['timing']?.toString() ?? '';
          final mealNotes = m['notes']?.toString();
          final items = (m['items'] ?? m['foods'] ?? []) as List;
          final isExpanded = _expandedMealIndices.contains(idx);

          // Calculate per-meal nutrition totals
          num mealCal = 0;
          num mealPro = 0;
          num mealCarbs = 0;
          num mealFat = 0;
          for (final it in items) {
            if (it is Map) {
              mealCal += (it['calories'] as num?) ?? 0;
              mealPro += (it['protein'] as num?) ?? 0;
              mealCarbs += ((it['carbs'] ?? it['carbohydrates']) as num?) ?? 0;
              mealFat += (it['fat'] as num?) ?? 0;
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expandable Meal Card Header
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedMealIndices.remove(idx);
                      } else {
                        _expandedMealIndices.add(idx);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    mealType.toString().toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (timing.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        timing,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${mealCal.round()} kcal • P:${mealPro.round()}g C:${mealCarbs.round()}g F:${mealFat.round()}g • ${items.length} foods',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                if (isExpanded) ...[
                  const Divider(color: AppColors.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mealNotes != null && mealNotes.trim().isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.warningYellow),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    mealNotes,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        ...items.map((it) {
                          final fName = it['foodName'] ?? it['name'] ?? 'Food';
                          final qty = it['quantity'] ?? 1;
                          final unit = it['unit'] ?? 'g';
                          final cal = it['calories'] ?? 0;
                          final pro = it['protein'] ?? 0;
                          final carbs = it['carbs'] ?? it['carbohydrates'] ?? 0;
                          final fat = it['fat'] ?? 0;
                          final foodNotes = it['notes']?.toString();
                          final subs = (it['substitutions'] ?? it['substitute'])?.toString();

                          final macroSub = '$cal kcal • ${pro}g P • ${carbs}g C • ${fat}g F';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• $fName',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$qty $unit',
                                        style: const TextStyle(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  macroSub,
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (foodNotes != null && foodNotes.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Prep: $foodNotes',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                if (subs != null && subs.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Substitutions: $subs',
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGeneralBreakdown(Map<String, dynamic> payload) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        payload.toString(),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
