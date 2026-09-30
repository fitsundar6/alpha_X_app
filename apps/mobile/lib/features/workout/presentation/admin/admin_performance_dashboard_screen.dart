import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

class AdminPerformanceDashboardScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const AdminPerformanceDashboardScreen({
    super.key,
    required this.workoutRepository,
  });

  @override
  State<AdminPerformanceDashboardScreen> createState() =>
      _AdminPerformanceDashboardScreenState();
}

class _AdminPerformanceDashboardScreenState
    extends State<AdminPerformanceDashboardScreen> {
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final clients = widget.workoutRepository.clientsList;
    if (clients.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          titleSpacing: 16,
          title: const Text('CLIENT PERFORMANCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: AppColors.textTertiary.withOpacity(0.4)),
              const SizedBox(height: 16),
              const Text(
                'No clients found',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Clients will appear here once they register via the mobile app.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedClientId == null || !clients.any((c) => c['id'] == _selectedClientId)) {
      _selectedClientId = clients.first['id'];
    }

    final selectedClient = clients.firstWhere(
      (c) => c['id'] == _selectedClientId,
      orElse: () => clients.first,
    );

    final history = widget.workoutRepository.getClientWorkoutHistory(_selectedClientId!);
    final changeRequests = widget.workoutRepository.changeRequests
        .where((r) => r.clientId == _selectedClientId)
        .toList();

    // Aggregates
    final totalCompletedWorkouts = history.where((h) => h.isCompleted).length;
    final totalVolumeKg = history.fold(0.0, (acc, h) => acc + h.totalVolume);
    final totalPRsCount = history.fold(0, (acc, h) => acc + h.personalRecords.length);
    final totalSwapsCount = history.fold(0, (acc, h) => acc + h.exerciseSwaps.length);

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
              'CLIENT PERFORMANCE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 15),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Client Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedClientId,
                isExpanded: true,
                dropdownColor: AppColors.surfaceElevated,
                items: clients.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primaryRed,
                          child: Text(
                            c['name']!.substring(0, 1),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${c['name']} (${c['tier']})',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedClientId = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Overview KPI Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _kpiCard(
                title: 'WORKOUTS',
                value: '$totalCompletedWorkouts',
                subtext: 'Completed sessions',
                icon: Icons.fitness_center,
                accentColor: AppColors.primaryRed,
              ),
              _kpiCard(
                title: 'TOTAL VOLUME',
                value: totalVolumeKg > 0
                    ? '${(totalVolumeKg / 1000).toStringAsFixed(1)}k kg'
                    : '0 kg',
                subtext: 'Muscular tonnage',
                icon: Icons.line_weight,
                accentColor: AppColors.textPrimary,
              ),
              _kpiCard(
                title: 'PERSONAL RECORDS',
                value: '$totalPRsCount',
                subtext: 'Lifetime PR badges',
                icon: Icons.emoji_events,
                accentColor: AppColors.gold,
              ),
              _kpiCard(
                title: 'EXERCISE SWAPS',
                value: '$totalSwapsCount',
                subtext: '${changeRequests.length} change requests',
                icon: Icons.swap_horiz,
                accentColor: AppColors.info,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Workout History Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMPLETED WORKOUT SESSIONS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '${history.length} records',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 44, color: AppColors.textTertiary),
                    const SizedBox(height: 10),
                    Text(
                      'No completed workouts yet for ${selectedClient['name']}',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live client logged sessions will sync here automatically.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...history.map((record) => _buildRecordCard(record)),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accentColor == AppColors.gold ? AppColors.gold : AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            subtext,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(WorkoutRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          record.sessionTitle,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          '${record.startedAt.day}/${record.startedAt.month}/${record.startedAt.year} • ${record.durationDisplay} • ${record.totalVolume.toInt()} kg volume',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: record.personalRecords.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      '${record.personalRecords.length} PR',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ],
                ),
              )
            : null,
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Exercise Logs
          ...record.exercises.map((ex) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ex.exerciseName,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        '${ex.completedSetsCount} / ${ex.sets.length} sets',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                  if (ex.swapRecord != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Swapped from: ${ex.swapRecord!.originalExerciseName}',
                      style: const TextStyle(color: AppColors.warning, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: ex.sets.where((s) => s.isCompleted).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'S${s.setNumber}: ${s.actualWeight?.toInt() ?? 0}kg × ${s.actualReps ?? 0}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                  if (ex.clientNote != null && ex.clientNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Client Note: "${ex.clientNote}"',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
