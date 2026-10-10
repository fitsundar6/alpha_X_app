import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/telemetry/domain/models/weekly_telemetry_report.dart';
import 'package:alpha_x_gym/features/telemetry/data/repositories/weekly_telemetry_repository.dart';

class ClientWeeklyTelemetryScreen extends StatefulWidget {
  final WeeklyTelemetryRepository repository;
  final WeeklyTelemetryReport? initialReport;

  const ClientWeeklyTelemetryScreen({
    super.key,
    required this.repository,
    this.initialReport,
  });

  @override
  State<ClientWeeklyTelemetryScreen> createState() => _ClientWeeklyTelemetryScreenState();
}

class _ClientWeeklyTelemetryScreenState extends State<ClientWeeklyTelemetryScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  static const int _totalPages = 5;
  WeeklyTelemetryReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _report = widget.initialReport;
    if (_report != null) {
      _isLoading = false;
    } else {
      _loadTelemetry();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTelemetry() async {
    setState(() => _isLoading = true);
    final report = await widget.repository.fetchWeeklyTelemetry();
    if (mounted) {
      setState(() {
        _report = report;
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      AlphaXHaptics.selection();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      AlphaXHaptics.selection();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF07090E),
        body: Center(
          child: CircularProgressIndicator(color: AlphaXColors.primary),
        ),
      );
    }

    if (_report == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07090E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Weekly Telemetry',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AlphaXColors.primary.withOpacity(0.12),
                    border: Border.all(color: AlphaXColors.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: AlphaXColors.primary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Telemetry Recorded Yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Complete your scheduled workouts this week to unlock your volumetric tonnage analysis, physical lift comparisons, and AI recovery feedback.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AlphaXColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: SafeArea(
        child: Stack(
                children: [
                  // Atmospheric Gradient Glow
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.0, -0.6),
                          radius: 1.2,
                          colors: [
                            Color(0x3300F0FF),
                            Color(0x1A7928CA),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      // Story Progress Indicators
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: List.generate(_totalPages, (index) {
                            return Expanded(
                              child: Container(
                                height: 3.5,
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: index <= _currentPage
                                      ? AlphaXColors.primary
                                      : Colors.white.withOpacity(0.18),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Header with Title & Close
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AlphaXColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AlphaXColors.primary.withOpacity(0.35)),
                                  ),
                                  child: const Text(
                                    'SPOTIFY-WRAPPED FOR LIFTING',
                                    style: TextStyle(
                                      color: AlphaXColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'WEEK ${_report!.weekNumber}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Swipable Wrapped Slides
                      Expanded(
                        child: GestureDetector(
                          onTapUp: (details) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            if (details.globalPosition.dx < screenWidth * 0.3) {
                              _prevPage();
                            } else {
                              _nextPage();
                            }
                          },
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (page) => setState(() => _currentPage = page),
                            children: [
                              _buildTonnageSlide(_report!),
                              _buildHeatmapSlide(_report!),
                              _buildPrSlide(_report!),
                              _buildAdherenceSlide(_report!),
                              _buildCoachReviewSlide(_report!),
                            ],
                          ),
                        ),
                      ),

                      // Bottom Navigation & Share Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        child: Row(
                          children: [
                            if (_currentPage > 0)
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 20),
                                onPressed: _prevPage,
                              ),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AlphaXColors.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 8,
                                  shadowColor: AlphaXColors.primary.withOpacity(0.5),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 20, color: Colors.black),
                                label: Text(
                                  _currentPage == _totalPages - 1 ? 'SHARE ALPHA TELEMETRY' : 'NEXT CARD',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: () {
                                  if (_currentPage == _totalPages - 1) {
                                    AlphaXHaptics.celebrate();
                                    AlphaXCelebrationBurst.show(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('📊 Alpha Telemetry Card exported to Stories!'),
                                        backgroundColor: Color(0xFF00FF87),
                                      ),
                                    );
                                  } else {
                                    _nextPage();
                                  }
                                },
                              ),
                            ),
                            if (_currentPage < _totalPages - 1)
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 20),
                                onPressed: _nextPage,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 1: TOTAL IRON TONNAGE (REAL-WORLD PHYSICAL EQUIVALENT)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTonnageSlide(WeeklyTelemetryReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: AlphaXColors.primary.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AlphaXColors.primary.withOpacity(0.2),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Text(
              report.physicalComparison.itemIcon,
              style: const TextStyle(fontSize: 54),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'TOTAL IRON MOVED',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00F0FF), Color(0xFF00FF87)],
            ).createShader(bounds),
            child: Text(
              '${report.totalVolumeKg.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} KG',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              'EQUIVALENT TO ${report.physicalComparison.equivalentLabel.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AlphaXColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            report.physicalComparison.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatPill('SESSIONS', '${report.totalWorkoutsCompleted} Completed'),
              _buildStatPill('SETS', '${report.completedSetsCount} Sets'),
              _buildStatPill('TIME', '${report.totalDurationMinutes} Mins'),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 2: 3D MUSCLE HEATMAP BREAKDOWN
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeatmapSlide(WeeklyTelemetryReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3D MUSCLE HEATMAP',
            style: TextStyle(
              color: AlphaXColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hypertrophy Volume Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: report.muscleHeatmap.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final item = report.muscleHeatmap[idx];
                final double maxVolume = report.muscleHeatmap
                    .map((e) => e.totalVolumeKg)
                    .fold(1.0, (prev, curr) => curr > prev ? curr : prev);
                final double fillRatio = maxVolume > 0 ? (item.totalVolumeKg / maxVolume).clamp(0.05, 1.0) : 0.05;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11141C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.statusColor.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(
                                color: item.statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${item.totalSets} Sets',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.totalVolumeKg.toInt()} kg volume',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillRatio,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(item.statusColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 3: PERSONAL RECORDS TROPHY SHELF
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPrSlide(WeeklyTelemetryReport report) {
    final prs = report.personalRecords;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TROPHY SHELF',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Personal Records Shattered',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (prs.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center_rounded, size: 54, color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text(
                      'Solid volume bank this week!',
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Load up the bar next week to break new PR milestones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: prs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final pr = prs[idx];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF171B26),
                          const Color(0xFFFFD700).withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pr.exerciseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pr.weight != null ? '${pr.weight} kg × ${pr.reps ?? 1} reps' : '${pr.value.toInt()} kg total volume',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'NEW PR',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 4: ADHERENCE & INTENSITY GAUGE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAdherenceSlide(WeeklyTelemetryReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: report.adherencePercentage / 100,
                  strokeWidth: 14,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(AlphaXColors.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${report.adherencePercentage}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'ADHERENCE',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'IRON DISCIPLINE',
            style: TextStyle(
              color: AlphaXColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.totalWorkoutsCompleted} of ${report.targetWorkouts} planned sessions logged',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF11141C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('STREAK', '${report.streakWeeks} WEEKS', Icons.local_fire_department_rounded, const Color(0xFFFF5722)),
                _buildMetricColumn('INTENSITY', report.averageRpe != null ? 'RPE ${report.averageRpe}' : 'RPE 8.0', Icons.bolt_rounded, const Color(0xFF00F0FF)),
                _buildMetricColumn('VOLUME', '${(report.totalVolumeKg / 1000).toStringAsFixed(1)} TONS', Icons.fitness_center_rounded, const Color(0xFF00FF87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SLIDE 5: AI HEAD COACH TELEMETRY REVIEW & SIGN-OFF
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCoachReviewSlide(WeeklyTelemetryReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AlphaXColors.primary.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(color: AlphaXColors.primary.withOpacity(0.4)),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 40, color: AlphaXColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'HEAD COACH ALEX',
            style: TextStyle(
              color: AlphaXColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sunday Telemetry Verdict',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF11141C),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: Colors.white24, size: 30),
                const SizedBox(height: 8),
                Text(
                  report.aiCoachCommentary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ALPHA X PERFORMANCE LABS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Icon(Icons.verified_rounded, color: AlphaXColors.primary, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
