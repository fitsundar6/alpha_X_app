import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in_status.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_progress_charts.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_weekly_check_in_form_screen.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_transformation_timeline_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';

/// Streamlined, premium Alpha X Client Progress & Weekly Check-In Dashboard.
///
/// Designed so clients understand their entire weekly progress within 5–10 seconds:
/// 1. Overall Progress (score & status)
/// 2. Key Weekly Changes (Weight, Waist, Protein, Sleep)
/// 3. Interactive Progress Chart (Weight, Waist, Strength)
/// 4. Weekly Intelligence Summary (What Improved, Needs Attention, Next Week Focus)
/// 5. Progress Journey (Visual Week Timeline)
/// 6. Body Measurements (Clean & non-overwhelming)
/// 7. Transformation Photos (Before → Current comparison)
class ClientWeeklyProgressScreen extends StatefulWidget {
  final WeeklyProgressRepository repository;
  final WorkoutRepository? workoutRepository;
  final ActivityRepository? activityRepository;

  const ClientWeeklyProgressScreen({
    super.key,
    required this.repository,
    this.workoutRepository,
    this.activityRepository,
  });

  @override
  State<ClientWeeklyProgressScreen> createState() => _ClientWeeklyProgressScreenState();
}

class _ClientWeeklyProgressScreenState extends State<ClientWeeklyProgressScreen> {
  WeeklyCheckInStatus? _status;
  List<WeeklyCheckIn> _history = [];
  WeeklyCheckIn? _selectedCheckIn;
  List<Map<String, dynamic>> _milestones = [];
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
    await _fetchMilestones();

    if (mounted) {
      setState(() {
        _status = status;
        _history = history;
        _selectedCheckIn = history.isNotEmpty ? history.first : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMilestones() async {
    try {
      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final res = await http.get(
        Uri.parse('$baseUrl/client/me/transformation-timeline'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List?) ?? [];
        if (mounted) {
          _milestones = list.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
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
        AlphaXHaptics.celebrate();
        AlphaXCelebrationBurst.show(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly Check-In Submitted & Analyzed ✓'),
            backgroundColor: AlphaXColors.success,
          ),
        );
      }
    }
  }

  void _openTransformationTimeline() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientTransformationTimelineScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          children: [
            Text(
              'PROGRESS & CHECK-IN',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'WEEKLY BODY & PERFORMANCE INTELLIGENCE',
              style: TextStyle(
                color: AlphaXColors.redAccent,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            tooltip: 'Transformation Gallery',
            onPressed: _openTransformationTimeline,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Refresh',
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
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    // 0. Actionable Check-In Availability Callout Banner
                    AlphaXSubtleEntrance(
                      child: _buildCheckInActionBanner(),
                    ),
                    const SizedBox(height: 14),

                    // 1. Overall Progress Hero Card
                    AlphaXSubtleEntrance(
                      delay: const Duration(milliseconds: 30),
                      child: _buildOverallProgressCard(),
                    ),
                    const SizedBox(height: 14),

                    // 2. Key Weekly Changes (5 Vital Metrics)
                    AlphaXSubtleEntrance(
                      delay: const Duration(milliseconds: 60),
                      child: _buildKeyWeeklyChangesCard(),
                    ),
                    const SizedBox(height: 14),

                    // 3. Interactive Progress Chart (Weight, Waist, Steps, Strength)
                    AlphaXSubtleEntrance(
                      delay: const Duration(milliseconds: 90),
                      child: _buildInteractiveChartSection(),
                    ),
                    const SizedBox(height: 14),

                    // 4. Weekly Intelligence Summary (What Improved, Needs Attention, Focus)
                    AlphaXSubtleEntrance(
                      delay: const Duration(milliseconds: 120),
                      child: _buildWeeklySummarySection(),
                    ),
                    const SizedBox(height: 14),

                    // 5. Progress Journey (Visual Week Timeline)
                    if (_history.length > 1) ...[
                      AlphaXSubtleEntrance(
                        delay: const Duration(milliseconds: 150),
                        child: _buildProgressJourneyTimeline(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 6. Body Measurements (Clean & non-overwhelming)
                    if (_selectedCheckIn != null && _hasBodyMeasurements(_selectedCheckIn!)) ...[
                      AlphaXSubtleEntrance(
                        delay: const Duration(milliseconds: 180),
                        child: _buildBodyMeasurementsCard(_selectedCheckIn!),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 7. Transformation Photos (Before → Current Comparison)
                    AlphaXSubtleEntrance(
                      delay: const Duration(milliseconds: 210),
                      child: _buildTransformationPhotosCard(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // ==========================================
  // SECTION 0: CHECK-IN AVAILABILITY BANNER
  // ==========================================
  Widget _buildCheckInActionBanner() {
    final isAvailable = _status?.isAvailable ?? true;
    final nextWeekNum = _status?.currentWeekNumber ?? 1;
    final nextDate = _status?.nextCheckInDate;
    final daysLeft = _status?.daysUntilNext ?? 0;
    final nextDateStr = nextDate != null ? nextDate.toIso8601String().substring(0, 10) : 'Next Week';

    if (isAvailable) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B1217), Color(0xFF1F0B0C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AlphaXColors.redAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AlphaXColors.redAccent.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openCheckInForm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'WEEK $nextWeekNum CHECK-IN READY',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AlphaXColors.gold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OPEN',
                                style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Record your weight and adherence to refresh your progress score.',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _openCheckInForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'START',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AlphaXColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AlphaXColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AlphaXColors.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Week $nextWeekNum Check-In Completed ✓ (Next review unlocks $nextDateStr, in $daysLeft ${daysLeft == 1 ? "day" : "days"})',
                style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ==========================================
  // SECTION 1: OVERALL PROGRESS HERO CARD
  // ==========================================
  Widget _buildOverallProgressCard() {
    final c = _selectedCheckIn;
    final int score = c != null ? _calculateOverallProgressScore(c) : 0;
    final status = _getProgressStatus(score, c != null);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AlphaXColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Animated Circular Progress Indicator
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: score / 100.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      backgroundColor: AlphaXColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(status.color),
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score%',
                      style: const TextStyle(
                        color: AlphaXColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'SCORE',
                      style: TextStyle(
                        color: AlphaXColors.textTertiary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Right: Score Details & Insight
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OVERALL PROGRESS',
                  style: TextStyle(
                    color: AlphaXColors.textTertiary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: status.color.withOpacity(0.35)),
                      ),
                      child: Text(
                        '$score% — ${status.title}',
                        style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (c != null)
                      Text(
                        'Week ${c.weekNumber}',
                        style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  c != null
                      ? _generateOneSentenceSummary(c)
                      : 'Complete your first check-in to establish starting body metrics and generate your progress score.',
                  style: const TextStyle(
                    color: AlphaXColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 2: KEY WEEKLY CHANGES (5 METRICS)
  // ==========================================
  Widget _buildKeyWeeklyChangesCard() {
    final c = _selectedCheckIn;

    // Weight delta
    final weightDelta = c?.weightChange;
    final weightDeltaStr = c?.weightChangeDisplay ?? 'Baseline';
    final weightColor = weightDelta == null
        ? AlphaXColors.textTertiary
        : (weightDelta <= 0 ? AlphaXColors.success : AlphaXColors.warning);
    final weightTag = weightDelta == null
        ? 'Baseline'
        : (weightDelta < 0 ? 'Decreased' : (weightDelta > 0 ? 'Increased' : 'Stable'));

    // Waist delta
    final waistDelta = c?.waistChange;
    final waistDeltaStr = c?.waistChangeDisplay ?? (c?.waistCm != null ? 'Baseline' : '—');
    final waistColor = waistDelta == null
        ? AlphaXColors.textTertiary
        : (waistDelta <= 0 ? AlphaXColors.success : AlphaXColors.warning);
    final waistTag = waistDelta == null
        ? (c?.waistCm != null ? 'Baseline' : 'Not Logged')
        : (waistDelta < 0 ? 'Tightened' : (waistDelta > 0 ? 'Increased' : 'Stable'));

    // Protein
    final proteinVal = c?.nutritionProtein ?? 'Good';
    final isProteinGood = proteinVal.toLowerCase() == 'good';
    final proteinColor = isProteinGood ? AlphaXColors.success : (proteinVal.toLowerCase() == 'mostly' ? AlphaXColors.warning : AlphaXColors.error);
    final proteinTag = isProteinGood ? 'Optimal' : (proteinVal.toLowerCase() == 'mostly' ? 'Acceptable' : 'Needs Work');

    // Sleep
    final sleepHrs = c?.sleepHours ?? 7.5;
    final sleepQuality = c?.sleepQuality ?? 'Good';
    final isSleepGood = sleepHrs >= 7.0 && sleepQuality.toLowerCase() == 'good';
    final sleepColor = isSleepGood ? AlphaXColors.success : (sleepHrs >= 6.0 ? AlphaXColors.warning : AlphaXColors.error);
    final sleepTag = isSleepGood ? 'Restored' : (sleepHrs >= 6.5 ? 'Moderate' : 'Low Sleep');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AlphaXColors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'KEY WEEKLY CHANGES',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              if (c != null)
                Text(
                  'Week ${c.weekNumber} vs Previous',
                  style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 5-Metric Responsive Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'WEIGHT',
                  value: c?.weightDisplay ?? '—',
                  sub: weightDeltaStr,
                  statusText: weightTag,
                  statusColor: weightColor,
                  icon: Icons.monitor_weight_outlined,
                  isImproved: weightDelta != null && weightDelta <= 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'WAIST',
                  value: c?.waistDisplay ?? '—',
                  sub: waistDeltaStr,
                  statusText: waistTag,
                  statusColor: waistColor,
                  icon: Icons.straighten_rounded,
                  isImproved: waistDelta != null && waistDelta <= 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'PROTEIN',
                  value: proteinVal,
                  sub: 'Nutrition Target',
                  statusText: proteinTag,
                  statusColor: proteinColor,
                  icon: Icons.restaurant_rounded,
                  isImproved: isProteinGood,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'SLEEP',
                  value: '${sleepHrs.toStringAsFixed(1)}h',
                  sub: sleepQuality,
                  statusText: sleepTag,
                  statusColor: sleepColor,
                  icon: Icons.bedtime_outlined,
                  isImproved: isSleepGood,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required String statusText,
    required Color statusColor,
    required IconData icon,
    required bool isImproved,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AlphaXColors.border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AlphaXColors.textTertiary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Icon(icon, size: 13, color: AlphaXColors.textSecondary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AlphaXColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 3: UNIFIED INTERACTIVE CHART
  // ==========================================
  Widget _buildInteractiveChartSection() {
    return ClientInteractiveProgressChart(
      checkIns: _history,
    );
  }

  // ==========================================
  // SECTION 4: WEEKLY INTELLIGENCE SUMMARY
  // ==========================================
  Widget _buildWeeklySummarySection() {
    final c = _selectedCheckIn;
    final summary = c != null ? _generateWeeklySummary(c) : _defaultEmptySummary();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AlphaXColors.gold, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'WEEKLY SUMMARY & FOCUS',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              if (c?.hasCoachReview == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AlphaXColors.redAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'COACH REVIEWED',
                    style: TextStyle(color: AlphaXColors.redAccent, fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. What Improved
          _buildSummaryItem(
            icon: Icons.check_circle_rounded,
            iconColor: AlphaXColors.success,
            title: 'WHAT IMPROVED',
            description: summary.whatImproved,
          ),
          const SizedBox(height: 10),

          // 2. What Needs Attention
          _buildSummaryItem(
            icon: Icons.warning_amber_rounded,
            iconColor: AlphaXColors.warning,
            title: 'WHAT NEEDS ATTENTION',
            description: summary.needsAttention,
          ),
          const SizedBox(height: 10),

          // 3. Focus For Next Week
          _buildSummaryItem(
            icon: Icons.track_changes_rounded,
            iconColor: AlphaXColors.gold,
            title: 'ONE FOCUS FOR NEXT WEEK',
            description: summary.nextWeekFocus,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AlphaXColors.border.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AlphaXColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 5: PROGRESS JOURNEY (TIMELINE)
  // ==========================================
  Widget _buildProgressJourneyTimeline() {
    final sorted = List<WeeklyCheckIn>.from(_history)
      ..sort((a, b) => b.weekNumber.compareTo(a.weekNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.timeline_rounded, size: 16, color: AlphaXColors.textSecondary),
              SizedBox(width: 8),
              Text(
                'PROGRESS JOURNEY',
                style: TextStyle(
                  color: AlphaXColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final item = sorted[idx];
              final isSelected = _selectedCheckIn?.id == item.id;
              final weightDiff = item.weightChange;

              return GestureDetector(
                onTap: () {
                  AlphaXHaptics.selection();
                  setState(() => _selectedCheckIn = item);
                },
                child: Container(
                  width: 124,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AlphaXColors.redAccent.withOpacity(0.18) : AlphaXColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AlphaXColors.redAccent : AlphaXColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Week ${item.weekNumber}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AlphaXColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AlphaXColors.redAccent,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.weightDisplay,
                              style: const TextStyle(
                                color: AlphaXColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (weightDiff != null)
                            Text(
                              '${weightDiff > 0 ? "+" : ""}${weightDiff.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: weightDiff <= 0 ? AlphaXColors.success : AlphaXColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 6: BODY MEASUREMENTS
  // ==========================================
  Widget _buildBodyMeasurementsCard(WeeklyCheckIn c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.accessibility_new_rounded, size: 16, color: AlphaXColors.gold),
                  SizedBox(width: 8),
                  Text(
                    'BODY MEASUREMENTS',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                'Week ${c.weekNumber}',
                style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (c.chestCm != null)
                Expanded(child: _buildMeasureCell('CHEST', '${c.chestCm!.toStringAsFixed(1)} cm')),
              if (c.armsCm != null)
                Expanded(child: _buildMeasureCell('ARMS', '${c.armsCm!.toStringAsFixed(1)} cm')),
              if (c.hipsCm != null)
                Expanded(child: _buildMeasureCell('HIPS', '${c.hipsCm!.toStringAsFixed(1)} cm')),
              if (c.thighsCm != null)
                Expanded(child: _buildMeasureCell('THIGHS', '${c.thighsCm!.toStringAsFixed(1)} cm')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureCell(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 7: TRANSFORMATION PHOTOS CARD
  // ==========================================
  Widget _buildTransformationPhotosCard() {
    Map<String, dynamic>? beforeMilestone;
    Map<String, dynamic>? currentMilestone;

    if (_milestones.isNotEmpty) {
      final withPhotos = _milestones.where((m) =>
          (m['frontPhotoUrl'] != null && m['frontPhotoUrl'].toString().isNotEmpty) ||
          (m['photoUrl'] != null && m['photoUrl'].toString().isNotEmpty)).toList();

      if (withPhotos.isNotEmpty) {
        beforeMilestone = withPhotos.first;
        currentMilestone = withPhotos.length > 1 ? withPhotos.last : withPhotos.first;
      }
    }

    final hasPhotos = beforeMilestone != null &&
        ((beforeMilestone['frontPhotoUrl'] ?? beforeMilestone['photoUrl']) != null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.camera_alt_outlined, size: 16, color: AlphaXColors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'TRANSFORMATION COMPARISON',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openTransformationTimeline,
                child: const Text(
                  'OPEN GALLERY →',
                  style: TextStyle(color: AlphaXColors.redAccent, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasPhotos) ...[
            Row(
              children: [
                Expanded(
                  child: _buildPhotoThumbnail(
                    title: 'BEFORE (WEEK ${beforeMilestone['weekNumber'] ?? 1})',
                    photoUrl: (beforeMilestone['frontPhotoUrl'] ?? beforeMilestone['photoUrl'])?.toString(),
                    weight: beforeMilestone['weightKg'] != null ? '${beforeMilestone['weightKg']} kg' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPhotoThumbnail(
                    title: 'CURRENT (WEEK ${currentMilestone?['weekNumber'] ?? beforeMilestone['weekNumber'] ?? 1})',
                    photoUrl: (currentMilestone?['frontPhotoUrl'] ?? currentMilestone?['photoUrl'])?.toString(),
                    weight: currentMilestone?['weightKg'] != null ? '${currentMilestone?['weightKg']} kg' : null,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: AlphaXColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Record milestone photos in the gallery to unlock side-by-side physique comparison.',
                      style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11.5),
                    ),
                  ),
                  TextButton(
                    onPressed: _openTransformationTimeline,
                    child: const Text('UPLOAD', style: TextStyle(color: AlphaXColors.redAccent, fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail({required String title, String? photoUrl, String? weight}) {
    return Container(
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AlphaXColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.black.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                if (weight != null)
                  Text(weight, style: const TextStyle(color: AlphaXColors.gold, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: photoUrl != null && photoUrl.startsWith('http')
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildNoPhotoPlaceholder(),
                  )
                : _buildNoPhotoPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPhotoPlaceholder() {
    return Container(
      color: AlphaXColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: AlphaXColors.textTertiary, size: 24),
          SizedBox(height: 4),
          Text('No photo', style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER CALCULATIONS & LOGIC
  // ==========================================
  bool _hasBodyMeasurements(WeeklyCheckIn c) {
    return c.chestCm != null || c.armsCm != null || c.hipsCm != null || c.thighsCm != null;
  }

  int _calculateOverallProgressScore(WeeklyCheckIn c) {
    int score = 0;

    // 1. Workout Completion (25 pts)
    switch (c.workoutCompletion.toLowerCase()) {
      case 'all': score += 25; break;
      case 'most': score += 20; break;
      case 'some': score += 10; break;
      case 'none': score += 0; break;
      default: score += 15;
    }

    // 2. Nutrition Adherence (25 pts)
    if (c.dietAdherence.toLowerCase() == 'good') {
      score += 10;
    } else if (c.dietAdherence.toLowerCase() == 'mostly') {
      score += 7;
    } else {
      score += 3;
    }

    if (c.nutritionProtein.toLowerCase() == 'good') {
      score += 10;
    } else if (c.nutritionProtein.toLowerCase() == 'mostly') {
      score += 6;
    } else {
      score += 2;
    }

    if (c.nutritionWater.toLowerCase() == 'good') {
      score += 5;
    } else {
      score += 2;
    }

    // 3. Sleep & Recovery (25 pts)
    if (c.sleepHours >= 7.5) {
      score += 12;
    } else if (c.sleepHours >= 6.5) {
      score += 9;
    } else {
      score += 4;
    }

    if (c.sleepQuality.toLowerCase() == 'good') {
      score += 7;
    } else if (c.sleepQuality.toLowerCase() == 'average') {
      score += 4;
    } else {
      score += 2;
    }

    if (c.recoveryQuality.toLowerCase() == 'good') {
      score += 6;
    } else {
      score += 2;
    }

    // 4. Trajectory & Consistency (25 pts)
    int bodyScore = 15;
    if (c.waistChange != null && c.waistChange! <= 0) {
      bodyScore += 10;
    } else if (c.weightChange != null && c.weightChange! <= 0) {
      bodyScore += 7;
    } else if (!c.hasPain) {
      bodyScore += 5;
    }

    score += bodyScore.clamp(0, 25);
    return score.clamp(10, 100);
  }

  _ProgressStatus _getProgressStatus(int score, bool hasData) {
    if (!hasData) {
      return _ProgressStatus('Ready for Week 1', AlphaXColors.textSecondary);
    }
    if (score >= 85) {
      return _ProgressStatus('Excellent Progress', const Color(0xFF10B981));
    }
    if (score >= 70) {
      return _ProgressStatus('Good Progress', const Color(0xFF34D399));
    }
    if (score >= 50) {
      return _ProgressStatus('On Track', AlphaXColors.gold);
    }
    return _ProgressStatus('Needs Attention', AlphaXColors.redAccent);
  }

  String _generateOneSentenceSummary(WeeklyCheckIn c) {
    final List<String> wins = [];
    if (c.workoutCompletion.toLowerCase() == 'all') wins.add('100% workout completion');
    if (c.waistChange != null && c.waistChange! < 0) wins.add('waist reduction of ${(-c.waistChange!).toStringAsFixed(1)} cm');
    if (c.weightChange != null && c.weightChange! < 0) wins.add('weight drop of ${(-c.weightChange!).toStringAsFixed(1)} kg');
    if (c.nutritionProtein.toLowerCase() == 'good') wins.add('optimal protein adherence');

    if (wins.isNotEmpty) {
      return 'Solid execution: ${wins.take(2).join(' and ')} this cycle.';
    }
    return 'Consistent training logging. Maintain discipline into next week.';
  }

  _WeeklySummaryData _generateWeeklySummary(WeeklyCheckIn c) {
    // If coach review exists, display verified coach review!
    if (c.hasCoachReview && c.whatWentWell != null && c.whatWentWell!.isNotEmpty) {
      return _WeeklySummaryData(
        whatImproved: c.whatWentWell!,
        needsAttention: c.needsImprovement ?? 'Maintain current workout and nutrition standard.',
        nextWeekFocus: c.nextWeekFocus ?? 'Progressive overload on compound movements.',
      );
    }

    // Auto-synthesized analysis from check-in metrics
    String improved = 'Solid workout adherence with ${c.energyLevel.toLowerCase()} training energy.';
    if (c.waistChange != null && c.waistChange! < 0) {
      improved = 'Waist circumference decreased by ${(-c.waistChange!).toStringAsFixed(1)} cm with consistent training.';
    } else if (c.weightChange != null && c.weightChange! < 0) {
      improved = 'Body weight decreased by ${(-c.weightChange!).toStringAsFixed(1)} kg with positive nutrition adherence.';
    } else if (c.nutritionProtein.toLowerCase() == 'good' && c.dietAdherence.toLowerCase() == 'good') {
      improved = 'Nutrition adherence and protein targets were fully sustained throughout the week.';
    }

    String attention = 'No critical training flags reported this week. Consistency is solid.';
    if (c.hasPain) {
      attention = 'Reported training pain in ${c.painLocation ?? "joint"} (level ${c.painLevel ?? "?"}/10).';
    } else if (c.sleepHours < 6.5 || c.sleepQuality.toLowerCase() == 'poor') {
      attention = 'Average sleep was ${c.sleepHours.toStringAsFixed(1)}h; prioritize bedtime discipline.';
    } else if (c.nutritionProtein.toLowerCase() == 'poor') {
      attention = 'Protein intake fell short of target; prioritize protein at every meal.';
    } else if (c.weeklyProblems.isNotEmpty) {
      attention = 'Noted challenges: ${c.weeklyProblems.take(2).join(", ")}.';
    }

    String focus = 'Progressive overload: add 1 rep or load increase on primary lifts.';
    if (c.sleepHours < 7.0) {
      focus = 'Aim for minimum 7.5 hours of sleep nightly before heavy training sessions.';
    } else if (c.nutritionProtein.toLowerCase() != 'good') {
      focus = 'Hit daily protein target on at least 6 out of 7 days.';
    } else if (c.workoutCompletion.toLowerCase() != 'all') {
      focus = 'Complete 100% of prescribed gym sessions without skipping accessory sets.';
    }

    return _WeeklySummaryData(
      whatImproved: improved,
      needsAttention: attention,
      nextWeekFocus: focus,
    );
  }

  _WeeklySummaryData _defaultEmptySummary() {
    return const _WeeklySummaryData(
      whatImproved: 'Welcome to Alpha X. Complete your Week 1 check-in to record baseline metrics.',
      needsAttention: 'Ensure you log your starting weight, waist, and nutrition profile.',
      nextWeekFocus: 'Complete all prescribed workout sessions and log your first weekly review.',
    );
  }
}

class _ProgressStatus {
  final String title;
  final Color color;
  const _ProgressStatus(this.title, this.color);
}

class _WeeklySummaryData {
  final String whatImproved;
  final String needsAttention;
  final String nextWeekFocus;
  const _WeeklySummaryData({
    required this.whatImproved,
    required this.needsAttention,
    required this.nextWeekFocus,
  });
}
