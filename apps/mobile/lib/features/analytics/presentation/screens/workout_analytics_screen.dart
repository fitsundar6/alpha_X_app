import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_motion.dart';
import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';
import 'package:alpha_x_gym/features/analytics/domain/services/workout_analytics_calculator.dart';
import 'package:alpha_x_gym/features/analytics/presentation/widgets/body_muscle_visualizer.dart';
import 'package:alpha_x_gym/features/analytics/presentation/widgets/exercise_1rm_chart.dart';
import 'package:alpha_x_gym/features/analytics/presentation/widgets/muscle_distribution_table.dart';
import 'package:alpha_x_gym/features/analytics/presentation/widgets/muscle_radar_chart.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

class WorkoutAnalyticsScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final bool showAppBar;

  const WorkoutAnalyticsScreen({
    super.key,
    required this.workoutRepository,
    this.showAppBar = true,
  });

  @override
  State<WorkoutAnalyticsScreen> createState() => _WorkoutAnalyticsScreenState();
}

class _WorkoutAnalyticsScreenState extends State<WorkoutAnalyticsScreen> {
  AnalyticsPeriod _musclePeriod = AnalyticsPeriod.sevenDays;
  AnalyticsPeriod _exercisePeriod = AnalyticsPeriod.thirtyDays;
  String? _selectedExerciseId;
  String? _selectedExerciseName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepositoryUpdated);
    _initInitialExercise();
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepositoryUpdated);
    super.dispose();
  }

  void _onRepositoryUpdated() {
    if (mounted) setState(() {});
  }

  List<WorkoutRecord> _getClientRecords() {
    final uid = AuthService().currentUserId;
    final cid = AuthService().currentClientId;
    var records = widget.workoutRepository.getClientWorkoutHistory(uid);
    if (records.isEmpty && cid.isNotEmpty && cid != uid) {
      final alt = widget.workoutRepository.getClientWorkoutHistory(cid);
      if (alt.isNotEmpty) records = alt;
    }
    return records;
  }

  void _initInitialExercise() {
    final records = _getClientRecords();
    final recordedExercises = WorkoutAnalyticsCalculator.extractRecordedExercises(records);

    if (recordedExercises.isNotEmpty) {
      _selectedExerciseId = recordedExercises.first['id'];
      _selectedExerciseName = recordedExercises.first['name'];
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    AlphaXHaptics.tap();
    final clientId = AuthService().currentUserId.isNotEmpty
        ? AuthService().currentUserId
        : AuthService().currentClientId;
    if (clientId.isNotEmpty) {
      await widget.workoutRepository.fetchClientWorkoutHistory(clientId, forceRefresh: true);
    }
    if (mounted) {
      _initInitialExercise();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final records = _getClientRecords();
    final recordedExercises = WorkoutAnalyticsCalculator.extractRecordedExercises(records);

    // If initial exercise was not yet selected and exercises exist
    if (_selectedExerciseId == null && recordedExercises.isNotEmpty) {
      _selectedExerciseId = recordedExercises.first['id'];
      _selectedExerciseName = recordedExercises.first['name'];
    }

    // Perform real calculations
    final weeklyOverview = WorkoutAnalyticsCalculator.calculateWeeklyOverview(records);
    final weeklyReport = WorkoutAnalyticsCalculator.calculateWeeklyReport(records);
    final muscleTracker = WorkoutAnalyticsCalculator.calculateMuscleTracker(
      records,
      period: _musclePeriod,
    );

    final exerciseAnalytics = WorkoutAnalyticsCalculator.calculateExerciseAnalytics(
      records,
      exerciseId: _selectedExerciseId ?? 'ex_none',
      exerciseName: _selectedExerciseName ?? 'Select Exercise',
      period: _exercisePeriod,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: colors.background,
              elevation: 0,
              title: Text(
                'WORKOUT ANALYTICS',
                style: GoogleFonts.poppins(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.0,
                ),
              ),
              actions: [
                IconButton(
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 20),
                  tooltip: 'Refresh Analytics',
                  onPressed: _isLoading ? null : _refreshData,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surfaceCard,
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Screen Header Banner
            _buildScreenBanner(colors),
            const SizedBox(height: 20),

            // A. WEEKLY OVERVIEW
            _buildSectionHeader(
              title: 'A. Weekly Overview',
              subtitle: '7-day momentum & week-over-week consistency',
              icon: Icons.calendar_view_week_rounded,
              colors: colors,
            ),
            const SizedBox(height: 12),
            _buildWeeklyOverviewSection(weeklyOverview, colors),
            const SizedBox(height: 24),

            // B. WEEKLY REPORT
            _buildSectionHeader(
              title: 'B. Weekly Report',
              subtitle: 'Completed workouts, total volume & PRs',
              icon: Icons.assignment_outlined,
              colors: colors,
            ),
            const SizedBox(height: 12),
            _buildWeeklyReportSection(weeklyReport, colors),
            const SizedBox(height: 24),

            // C. MUSCLE TRACKER
            _buildSectionHeader(
              title: 'C. Muscle Tracker',
              subtitle: 'Anatomical training distribution & frequency',
              icon: Icons.accessibility_new_rounded,
              colors: colors,
              periodFilter: _buildPeriodSelector(
                selected: _musclePeriod,
                onChanged: (p) {
                  AlphaXHaptics.selection();
                  setState(() => _musclePeriod = p);
                },
                colors: colors,
              ),
            ),
            const SizedBox(height: 12),
            _buildMuscleTrackerSection(muscleTracker, colors),
            const SizedBox(height: 24),

            // D. EXERCISE ANALYTICS
            _buildSectionHeader(
              title: 'D. Exercise Analytics',
              subtitle: 'Brzycki estimated 1RM & strength trends',
              icon: Icons.insights_rounded,
              colors: colors,
              periodFilter: _buildPeriodSelector(
                selected: _exercisePeriod,
                onChanged: (p) {
                  AlphaXHaptics.selection();
                  setState(() => _exercisePeriod = p);
                },
                colors: colors,
              ),
            ),
            const SizedBox(height: 12),
            _buildExerciseAnalyticsSection(
              exerciseAnalytics,
              recordedExercises,
              colors,
            ),
          ],
        ),
      ),
    );
  }

  // --- Header Banner ---
  Widget _buildScreenBanner(ClientThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withOpacity(0.08),
            colors.surfaceCard,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.analytics_rounded, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORKOUT ANALYTICS',
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Calculated strictly from completed set records & real workout history.',
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Section Header with Period Filter ---
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required ClientThemeColors colors,
    Widget? periodFilter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: colors.primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ?periodFilter,
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: colors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // --- Period Selector Pills (7D, 30D, 90D) ---
  Widget _buildPeriodSelector({
    required AnalyticsPeriod selected,
    required ValueChanged<AnalyticsPeriod> onChanged,
    required ClientThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AnalyticsPeriod.values.map((p) {
          final isSel = p == selected;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSel ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                p.label,
                style: GoogleFonts.poppins(
                  color: isSel ? colors.onPrimary : colors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- A. Weekly Overview ---
  Widget _buildWeeklyOverviewSection(
    WeeklyOverviewData data,
    ClientThemeColors colors,
  ) {
    return Column(
      children: [
        // Top 2 KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'SESSIONS COMPLETED',
                value: '${data.completedSessions}',
                subValue: data.sessionsDiffText,
                icon: Icons.fitness_center_rounded,
                isPositive: data.sessionsDiff >= 0,
                colors: colors,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'TOTAL VOLUME LIFTED',
                value: data.formattedVolume,
                subValue: data.volumeChangeText,
                icon: Icons.scale_rounded,
                isPositive: (data.volumeChangePercent ?? 0) >= 0,
                colors: colors,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bottom 2 KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'PERSONAL RECORDS (PRs)',
                value: '${data.prsAchieved}',
                subValue: data.prsDiff >= 0 ? '+${data.prsDiff} vs last wk' : '${data.prsDiff} vs last wk',
                icon: Icons.emoji_events_rounded,
                isPositive: data.prsDiff >= 0,
                colors: colors,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'WORKOUT CONSISTENCY',
                          style: GoogleFonts.poppins(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Icon(Icons.trending_up_rounded, color: colors.primary, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(data.consistencyRate * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: data.consistencyRate,
                        backgroundColor: colors.isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.daysTrained} of ${data.targetDays} target days',
                      style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required bool isPositive,
    required ClientThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: colors.primary, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 11,
                color: isPositive ? colors.success : colors.textTertiary,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  subValue,
                  style: GoogleFonts.poppins(
                    color: isPositive ? colors.success : colors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- B. Weekly Report ---
  Widget _buildWeeklyReportSection(
    WeeklyReportData data,
    ClientThemeColors colors,
  ) {
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
          // Completed vs Planned Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WORKOUTS COMPLETED VS PLANNED',
                style: GoogleFonts.poppins(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${data.completedWorkouts} / ${data.plannedWorkouts} (${data.completionPercentage.toInt()}%)',
                style: GoogleFonts.poppins(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: data.plannedWorkouts > 0
                  ? (data.completedWorkouts / data.plannedWorkouts).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: colors.isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),

          // 3-Column Metrics Breakdown
          Row(
            children: [
              Expanded(
                child: _buildReportMetricPill(
                  label: 'SETS / REPS',
                  value: '${data.totalCompletedSets}s • ${data.totalReps}r',
                  icon: Icons.repeat_rounded,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildReportMetricPill(
                  label: 'TRAINING VOL',
                  value: data.formattedVolume,
                  icon: Icons.fitness_center_rounded,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildReportMetricPill(
                  label: 'PRS HIT',
                  value: '${data.prsAchieved}',
                  icon: Icons.star_rounded,
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Muscle Groups Trained Chips
          Text(
            'MUSCLE GROUPS TRAINED',
            style: GoogleFonts.poppins(
              color: colors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (data.muscleGroupsTrained.isEmpty)
            Text(
              'No muscles targeted this week yet.',
              style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 11),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.muscleGroupsTrained.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.primary.withOpacity(0.25)),
                  ),
                  child: Text(
                    m,
                    style: GoogleFonts.poppins(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Weekly Summary Narrative Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withOpacity(0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.smart_toy_rounded, color: colors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEEKLY PERFORMANCE SUMMARY',
                        style: GoogleFonts.poppins(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data.summaryNarrative,
                        style: GoogleFonts.poppins(
                          color: colors.textPrimary,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required ClientThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- C. Muscle Tracker ---
  Widget _buildMuscleTrackerSection(
    MuscleTrackerData data,
    ClientThemeColors colors,
  ) {
    return Column(
      children: [
        // Body / Muscle Region Visualization
        BodyMuscleVisualizer(stats: data.stats),
        const SizedBox(height: 14),

        // Radar Chart
        MuscleRadarChart(stats: data.stats),
        const SizedBox(height: 14),

        // Table
        MuscleDistributionTable(stats: data.stats),
      ],
    );
  }

  // --- D. Exercise Analytics ---
  Widget _buildExerciseAnalyticsSection(
    ExerciseAnalyticsData data,
    List<Map<String, String>> recordedExercises,
    ClientThemeColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exercise Selector Dropdown / Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.fitness_center_rounded, color: colors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: recordedExercises.isEmpty
                    ? Text(
                        'No exercises logged yet',
                        style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 13),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedExerciseId,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSecondary),
                          dropdownColor: colors.surfaceCard,
                          isExpanded: true,
                          style: GoogleFonts.poppins(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                          items: recordedExercises.map((e) {
                            return DropdownMenuItem<String>(
                              value: e['id'],
                              child: Text(e['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null && newId != _selectedExerciseId) {
                              AlphaXHaptics.selection();
                              final matched = recordedExercises.firstWhere((e) => e['id'] == newId);
                              setState(() {
                                _selectedExerciseId = newId;
                                _selectedExerciseName = matched['name'];
                              });
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 1RM Line Chart & Progression Cards
        Exercise1RMChart(data: data),
      ],
    );
  }
}
