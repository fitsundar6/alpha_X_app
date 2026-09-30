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

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
}
