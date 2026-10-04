import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/app_typography.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';
import 'package:alpha_x_gym/features/activity/presentation/widgets/activity_widgets.dart';

class ActivityDashboardScreen extends StatefulWidget {
  final ActivityRepository activityRepository;
  final bool showAppBar;

  const ActivityDashboardScreen({
    super.key,
    required this.activityRepository,
    this.showAppBar = true,
  });

  @override
  State<ActivityDashboardScreen> createState() => _ActivityDashboardScreenState();
}

class _ActivityDashboardScreenState extends State<ActivityDashboardScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    widget.activityRepository.addListener(_onRepoUpdate);

    // Initial check for health permission dialog on first launch if not configured and shown standalone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showAppBar && widget.activityRepository.connectionStatus == HealthConnectionStatus.notConfigured) {
        _showPermissionBottomSheet();
      }
    });
  }

  @override
  void dispose() {
    widget.activityRepository.removeListener(_onRepoUpdate);
    super.dispose();
  }

  void _onRepoUpdate() {
    if (mounted) setState(() {});
  }

  void _onPreviousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _onNextMonth() {
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth >= now.month) return;

    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  void _showPermissionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.glowRed,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryRed, width: 2),
                  ),
                  child: const Icon(Icons.directions_run, color: AppColors.primaryRed, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Track Your Daily Activity',
                  style: AppTypography.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Alpha X Gym uses your health data to track your daily steps and help you monitor your transformation.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final success = await widget.activityRepository.connectHealthTracking();
                      if (!mounted) return;
                      if (!success) {
                        _showPermissionDeniedDialog();
                      }
                    },
                    child: const Text('Allow Step Tracking'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Not Now', style: TextStyle(color: AppColors.textTertiary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Health Permission Required', style: AppTypography.titleMedium),
        content: const Text(
          'Step permissions were denied or Health Connect is disabled. Please enable step access in your device settings to activate automatic tracking.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.activityRepository.connectHealthTracking();
            },
            child: const Text('Open Health Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.activityRepository;
    final today = repo.todayRecord;
    final weekly = repo.weeklySummary;
    final monthly = repo.getMonthlySummary(_selectedYear, _selectedMonth);
    final history = repo.history30Days;
    final now = DateTime.now();
    final canGoNext = !(_selectedYear == now.year && _selectedMonth >= now.month);

    final lastSyncString = repo.lastSyncedAt != null
        ? 'Last synced: ${DateFormat('h:mm a').format(repo.lastSyncedAt!)}'
        : 'Sync pending';

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('DAILY ACTIVITY'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync Now',
                  onPressed: repo.syncStatus == SyncStatus.syncing
                      ? null
                      : () => repo.refreshActivityData(),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () => repo.refreshActivityData(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // Status bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: repo.syncStatus == SyncStatus.synced
                            ? AppColors.success
                            : (repo.syncStatus == SyncStatus.syncing
                                ? AppColors.warning
                                : AppColors.primaryRed),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lastSyncString,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Goal: ${today.formattedGoal}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 1. Hero Step Progress Card
            StepProgressCard(
              record: today,
              isSyncing: repo.syncStatus == SyncStatus.syncing,
              onSyncTap: () => repo.refreshActivityData(),
            ),

            const SizedBox(height: 20),

            // 2. Weekly Activity Chart
            WeeklyStepsChart(
              summary: weekly,
              stepGoal: repo.currentStepGoal,
            ),

            const SizedBox(height: 20),

            // 3. Monthly Activity Summary
            MonthlyActivityCard(
              summary: monthly,
              onPreviousMonth: _onPreviousMonth,
              onNextMonth: _onNextMonth,
              canGoNext: canGoNext,
            ),

            const SizedBox(height: 20),

            // 4. Activity History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'ACTIVITY HISTORY (LAST 30 DAYS)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ActivityHistoryList(records: history),

            const SizedBox(height: 20),

            // 5. Health Platform Connection Card
            HealthConnectionCard(
              status: repo.connectionStatus,
              syncStatus: repo.syncStatus,
              lastSyncedAt: repo.lastSyncedAt,
              stepSourceLabel: repo.stepSourceLabel,
              activeStepSource: repo.activeStepSource,
              onConnectTap: () => _showPermissionBottomSheet(),
              onDisconnectTap: () => repo.disconnectHealthTracking(),
              onSyncTap: () => repo.refreshActivityData(),
              onManualStepsSubmit: (steps) => repo.submitManualSteps(steps),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
