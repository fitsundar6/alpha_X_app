import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

class AdminClientResultsScreen extends StatefulWidget {
  final Map<String, String> client;
  final WorkoutRepository workoutRepository;

  const AdminClientResultsScreen({
    super.key,
    required this.client,
    required this.workoutRepository,
  });

  @override
  State<AdminClientResultsScreen> createState() => _AdminClientResultsScreenState();
}

class _AdminClientResultsScreenState extends State<AdminClientResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final clientId = widget.client['id']!;
    final history = widget.workoutRepository.getClientWorkoutHistory(clientId);

    final totalVolume = history.fold(0.0, (acc, r) => acc + r.totalVolume);
    final totalHours = (history.fold(0, (acc, r) => acc + r.durationSeconds) / 3600).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.client['name']!.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 16),
            ),
            const Text(
              'WORKOUT HISTORY & RESULTS',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Client Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryRed,
                      child: Text(
                        widget.client['name']!.substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.client['name']!,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(
                            widget.client['email']!,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.glowRed,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryRed, width: 0.8),
                      ),
                      child: Text(
                        widget.client['tier'] ?? 'Member',
                        style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Completed', '${history.length}', AppColors.success),
                    _statItem('Total Volume', '${totalVolume.toInt()} kg', AppColors.primaryRed),
                    _statItem('Time Trained', '$totalHours hrs', AppColors.info),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'LOGGED WORKOUT PERFORMANCES',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No workout sessions recorded yet for this client.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...history.map((record) => _buildRecordCard(record)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildRecordCard(WorkoutRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        collapsedIconColor: AppColors.textSecondary,
        iconColor: AppColors.primaryRed,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                record.workoutType.toUpperCase(),
                style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                record.sessionTitle,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            if (record.isLocked) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
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
                  color: Colors.green.withOpacity(0.15),
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
                '${record.startedAt.day} ${_monthName(record.startedAt.month)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
              Text(
                record.durationDisplay,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
              Text(
                '${record.totalVolume.toInt()} kg vol',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
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
                // Lock & Unlock Management Card
                if (record.isLocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session Locked & Completed',
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                'Client cannot modify sets, reps, or weights.',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.lock_open_rounded, size: 14),
                          label: const Text('Unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          onPressed: () => _showUnlockDialog(record),
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
                            'Session Unlocked. Reason: "${record.unlockReason ?? 'Admin approval'}"',
                            style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
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
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Client Workout Note: "${record.notes}"',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                ...record.exercises.map((ex) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ex.isSuperset ? AppColors.accentRed.withOpacity(0.3) : AppColors.border,
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
                                  color: AppColors.primaryRed,
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
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            if (ex.isSkipped)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SKIPPED',
                                  style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                        if (ex.clientNote != null && ex.clientNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Client Note: "${ex.clientNote}"',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Sets Breakdown
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(1.5),
                          },
                          children: [
                            const TableRow(
                              children: [
                                Text('Set', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('Prescribed', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('Actual', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('RIR', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                                Text('RPE', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
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
                                    child: Text('${s.setNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      '${s.targetRepsDisplay} @ ${s.targetWeight > 0 ? "${s.targetWeight}kg" : "BW"}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      s.isCompleted ? '$weightStr kg × ${s.actualReps ?? 0}' : 'Incomplete',
                                      style: TextStyle(
                                        color: s.isCompleted ? AppColors.textPrimary : AppColors.textDisabled,
                                        fontWeight: s.isCompleted ? FontWeight.w700 : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(s.actualRir != null ? '${s.actualRir}' : '—',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(s.actualRpe != null ? '${s.actualRpe}' : '—',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Future<void> _showUnlockDialog(WorkoutRecord record) async {
    final reasonController = TextEditingController();
    bool reopenSession = true;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
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
              const Expanded(
                child: Text(
                  'Unlock Session',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to release and unlock "${record.sessionTitle}"?',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: const Text(
                  'Audit notice: All unlock operations are recorded with your Admin ID, reason, and UTC/IST timestamp.',
                  style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Reason for Unlock *',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Correcting mistakenly logged bench press weight',
                  hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
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
                  const Expanded(
                    child: Text(
                      'Reopen as active workout for client',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
                      content: Text('Please enter an unlock reason for audit purposes.'),
                      backgroundColor: AppColors.primaryRed,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  await widget.workoutRepository.unlockSession(
                    recordId: record.id,
                    adminId: 'admin_1',
                    reason: reason,
                    reopenSession: reopenSession,
                  );
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Session "${record.sessionTitle}" unlocked successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to unlock session: $e'),
                        backgroundColor: AppColors.primaryRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm Unlock', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
}
