import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in_status.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/motivational_quote_card.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_progress_charts.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/coach_review_card.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_weekly_check_in_form_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';

class ClientWeeklyProgressScreen extends StatefulWidget {
  final WeeklyProgressRepository repository;

  const ClientWeeklyProgressScreen({super.key, required this.repository});

  @override
  State<ClientWeeklyProgressScreen> createState() => _ClientWeeklyProgressScreenState();
}

class _ClientWeeklyProgressScreenState extends State<ClientWeeklyProgressScreen> {
  WeeklyCheckInStatus? _status;
  List<WeeklyCheckIn> _history = [];
  WeeklyCheckIn? _selectedCheckIn;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final status = await widget.repository.fetchCheckInStatus(forceRefresh: true);
    final history = await widget.repository.fetchClientHistory();

    if (mounted) {
      setState(() {
        _status = status;
        _history = history;
        _selectedCheckIn = history.isNotEmpty ? history.first : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCheckInForm() async {
    final nextWeekNum = _status?.currentWeekNumber ?? 1;
    final result = await Navigator.of(context).push<WeeklyCheckIn>(
      MaterialPageRoute(
        builder: (_) => ClientWeeklyCheckInFormScreen(
          repository: widget.repository,
          weekNumber: nextWeekNum,
        ),
      ),
    );

    if (result != null) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly Check-In Completed ✓'),
            backgroundColor: AlphaXColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'WEEKLY PROGRESS & CHECK-IN',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AlphaXColors.redAccent))
            : RefreshIndicator(
                color: AlphaXColors.redAccent,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Motivational Quote Card
                      const MotivationalQuoteCard(),
                      const SizedBox(height: 16),

                      // Weekly Availability & Locking Card
                      AlphaXSubtleEntrance(
                        child: _buildWeeklyStatusCard(),
                      ),
                      const SizedBox(height: 16),

                      if (_history.isNotEmpty) ...[
                        // Timeline of Weeks
                        _buildTimelineSelector(),
                        const SizedBox(height: 16),

                        if (_selectedCheckIn != null) ...[
                          // Main Weekly Progress Summary Banner
                          _buildSummaryBanner(_selectedCheckIn!),
                          const SizedBox(height: 16),

                          // Visual Cards
                          _buildBodyProgressCard(_selectedCheckIn!),
                          const SizedBox(height: 12),

                          NutritionConsistencyCard(checkIn: _selectedCheckIn!),
                          const SizedBox(height: 12),

                          WorkoutConsistencyCard(checkIn: _selectedCheckIn!),
                          const SizedBox(height: 12),

                          SleepRecoveryCard(checkIn: _selectedCheckIn!),
                          const SizedBox(height: 12),

                          WeeklyHabitOverviewCard(checkIn: _selectedCheckIn!),
                          const SizedBox(height: 12),

                          _buildCheckInNotesAndPainCard(_selectedCheckIn!),
                          const SizedBox(height: 12),

                          CoachReviewCard(checkIn: _selectedCheckIn!),
                          const SizedBox(height: 16),

                          // Trajectory Line Graphs
                          WeightProgressChartCard(checkIns: _history),
                          const SizedBox(height: 12),

                          WaistProgressChartCard(checkIns: _history),
                          const SizedBox(height: 24),
                        ],
                      ] else ...[
                        _buildEmptyHistoryPrompt(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Weekly Status / Lock Card
  Widget _buildWeeklyStatusCard() {
    final isAvailable = _status?.isAvailable ?? true;
    final nextDate = _status?.nextCheckInDate;
    final nextDateStr = nextDate != null ? nextDate.toIso8601String().substring(0, 10) : 'Next Week';
    final daysLeft = _status?.daysUntilNext ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(
          color: isAvailable
              ? AlphaXColors.success.withValues(alpha: 0.5)
              : AlphaXColors.redAccent.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AlphaXColors.success.withValues(alpha: 0.15)
                      : AlphaXColors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAvailable ? Icons.check_circle_outline_rounded : Icons.lock_rounded,
                  color: isAvailable ? AlphaXColors.success : AlphaXColors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAvailable ? 'WEEKLY CHECK-IN READY' : 'Weekly Check-In Completed ✓',
                      style: TextStyle(
                        color: isAvailable ? AlphaXColors.success : AlphaXColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAvailable
                          ? 'Week ${_status?.currentWeekNumber ?? 1} review window is open. Submit your progress.'
                          : 'Next Check-In: $nextDateStr (in $daysLeft ${daysLeft == 1 ? "day" : "days"})',
                      style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isAvailable) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _openCheckInForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AlphaXColors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.white),
                label: Text(
                  'START WEEK ${_status?.currentWeekNumber ?? 1} CHECK-IN',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AlphaXColors.textTertiary, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Submissions are restricted to once per week to ensure accurate tracking. Next week will unlock automatically.',
                      style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
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

  /// Horizontal Timeline of Weeks
  Widget _buildTimelineSelector() {
    final sorted = List<WeeklyCheckIn>.from(_history)
      ..sort((a, b) => b.weekNumber.compareTo(a.weekNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHECK-IN TIMELINE',
          style: TextStyle(
            color: AlphaXColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final item = sorted[idx];
              final isSelected = _selectedCheckIn?.id == item.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCheckIn = item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AlphaXColors.redAccent : AlphaXColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AlphaXColors.redAccent : AlphaXColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Week ${item.weekNumber}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AlphaXColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Weekly Progress ✓ Banner
  Widget _buildSummaryBanner(WeeklyCheckIn c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AlphaXColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'WEEK ${c.weekNumber} SUMMARY',
                style: const TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            c.checkInDate.toIso8601String().substring(0, 10),
            style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Body Progress Box with Week-to-Week Deltas
  Widget _buildBodyProgressCard(WeeklyCheckIn c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AlphaXColors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.monitor_weight_rounded, color: AlphaXColors.redAccent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'BODY PROGRESS',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weight', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        c.weightDisplay,
                        style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Change: ${c.weightChangeDisplay}',
                        style: TextStyle(
                          color: c.weightChange == null
                              ? AlphaXColors.textTertiary
                              : (c.weightChange! <= 0 ? AlphaXColors.success : AlphaXColors.warning),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Waist', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        c.waistDisplay,
                        style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Change: ${c.waistChangeDisplay}',
                        style: TextStyle(
                          color: c.waistChange == null
                              ? AlphaXColors.textTertiary
                              : (c.waistChange! <= 0 ? AlphaXColors.success : AlphaXColors.warning),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (c.chestCm != null || c.armsCm != null || c.hipsCm != null || c.thighsCm != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (c.chestCm != null) _buildMeasureChip('Chest', '${c.chestCm!.toStringAsFixed(1)} cm'),
                if (c.armsCm != null) _buildMeasureChip('Arms', '${c.armsCm!.toStringAsFixed(1)} cm'),
                if (c.hipsCm != null) _buildMeasureChip('Hips', '${c.hipsCm!.toStringAsFixed(1)} cm'),
                if (c.thighsCm != null) _buildMeasureChip('Thighs', '${c.thighsCm!.toStringAsFixed(1)} cm'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasureChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Problems, Pain, and Notes Card
  Widget _buildCheckInNotesAndPainCard(WeeklyCheckIn c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AlphaXColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AlphaXColors.warning, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'CHECK-IN DETAILS & OBSERVATIONS',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pain Report
          if (c.hasPain) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AlphaXColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AlphaXColors.error.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AlphaXColors.error, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Pain / Discomfort Reported (Level ${c.painLevel ?? "?"}/10)',
                        style: const TextStyle(color: AlphaXColors.error, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (c.painLocation != null) ...[
                    const SizedBox(height: 4),
                    Text('Location: ${c.painLocation}', style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 12)),
                  ],
                  if (c.painExercise != null && c.painExercise!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Exercise: ${c.painExercise}', style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12)),
                  ],
                  if (c.painDescription != null && c.painDescription!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Description: ${c.painDescription}', style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AlphaXColors.success, size: 16),
                const SizedBox(width: 6),
                const Text('No training pain or discomfort reported ✓', style: TextStyle(color: AlphaXColors.success, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Weekly Problems
          const Text('Reported Weekly Problems:', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (c.weeklyProblems.isEmpty)
            const Text('• No major problems reported ✓', style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: c.weeklyProblems.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Text(p, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11)),
                );
              }).toList(),
            ),

          if (c.clientNotes != null && c.clientNotes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Notes for Coach:', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c.clientNotes!,
                style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_outlined, size: 48, color: AlphaXColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'No Weekly Check-Ins Submitted Yet',
            style: TextStyle(color: AlphaXColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete your first weekly check-in to establish baseline metrics and unlock coach reviews.',
            style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openCheckInForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AlphaXColors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text('Submit Week 1 Check-In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
