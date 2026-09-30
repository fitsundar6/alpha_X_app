import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/app_typography.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';

/// 1. Hero Step Progress Card
class StepProgressCard extends StatelessWidget {
  final DailyActivityRecord record;
  final VoidCallback? onSyncTap;
  final bool isSyncing;

  const StepProgressCard({
    super.key,
    required this.record,
    this.onSyncTap,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isExceeded = record.isExceeded;
    final progressVal = record.visualProgressClamped;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExceeded ? AppColors.success : AppColors.primaryRed,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isExceeded ? AppColors.success.withAlpha(40) : AppColors.glowRed,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (record.isGoalAchieved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'GOAL REACHED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (onSyncTap != null)
                IconButton(
                  icon: isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                          ),
                        )
                      : const Icon(Icons.sync, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Sync Live Steps',
                  onPressed: isSyncing ? null : onSyncTap,
                ),
            ],
          ),

          const SizedBox(height: 18),

          // Main Step Count Row & Circular Progress
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.formattedSteps,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '/ ${record.formattedGoal} STEPS',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Goal Exceeded / Remaining Label
                    if (record.steps == 0)
                      const Text(
                        'No steps recorded yet. Start moving and your real steps will appear here.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                          height: 1.3,
                        ),
                      )
                    else if (isExceeded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withAlpha(80)),
                        ),
                        child: Text(
                          'Goal exceeded by ${record.formattedExceeded} steps',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${record.formattedRemaining} steps remaining',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),

              // Circular Gauge Indicator (Capped visually at 100%)
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: progressVal,
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isExceeded ? AppColors.success : AppColors.primaryRed,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${record.actualPercentage}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'GOAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 16),

          // Secondary metrics: Cardio Minutes, Calories, Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricItem(
                icon: Icons.timer_outlined,
                iconColor: AppColors.warning,
                label: 'Cardio',
                value: '${record.cardioMinutes} mins',
              ),
              _MetricItem(
                icon: Icons.local_fire_department_outlined,
                iconColor: AppColors.primaryRed,
                label: 'Calories',
                value: '${record.caloriesBurned.toInt()} kcal',
              ),
              _MetricItem(
                icon: Icons.straighten_outlined,
                iconColor: AppColors.info,
                label: 'Distance',
                value: '${(record.distanceMeters / 1000).toStringAsFixed(1)} km',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 2. Weekly Steps Chart (Mon-Sun) with fl_chart
class WeeklyStepsChart extends StatelessWidget {
  final WeeklyActivitySummary summary;
  final int stepGoal;

  const WeeklyStepsChart({
    super.key,
    required this.summary,
    required this.stepGoal,
  });

  @override
  Widget build(BuildContext context) {
    final days = summary.days;
    final maxStepsInWeek = days.fold<int>(
      stepGoal,
      (max, d) => d.steps > max ? d.steps : max,
    );
    final chartYMax = (maxStepsInWeek * 1.25).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'WEEKLY ACTIVITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('7-Day Step History', style: AppTypography.titleMedium),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Goal: ${NumberFormat('#,###').format(stepGoal)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (summary.totalSteps == 0 || days.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bar_chart, size: 36, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No step history yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Start moving and your real steps will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
          // fl_chart BarChart
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: chartYMax,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceElevated,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = days[groupIndex];
                      return BarTooltipItem(
                        '${day.dayOfWeekShort}\n${NumberFormat('#,###').format(day.steps)} steps',
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                        final isToday = index == days.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[index].dayOfWeekShort,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                              color: isToday ? AppColors.primaryRed : AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (chartYMax / 4).clamp(1000.0, 10000.0),
                  getDrawingHorizontalLine: (val) {
                    return FlLine(
                      color: AppColors.borderSubtle,
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: List.generate(days.length, (index) {
                  final day = days[index];
                  final isToday = index == days.length - 1;
                  final metGoal = day.isGoalAchieved;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: day.steps.toDouble(),
                        color: metGoal
                            ? AppColors.primaryRed
                            : (isToday ? AppColors.accentRed : AppColors.surfaceElevated),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: chartYMax,
                          color: AppColors.surface,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 16),

          // Weekly Analytics Grid
          Row(
            children: [
              Expanded(
                child: _AnalyticsStatCard(
                  label: 'WEEKLY AVERAGE',
                  value: '${NumberFormat('#,###').format(summary.weeklyAverage)} / day',
                  icon: Icons.trending_up,
                  accentColor: AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsStatCard(
                  label: 'GOAL ACHIEVED',
                  value: '${summary.daysGoalAchieved} / ${days.length} days',
                  icon: Icons.emoji_events_outlined,
                  accentColor: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnalyticsStatCard(
                  label: 'BEST DAY',
                  value: summary.bestDay != null
                      ? '${summary.bestDay!.dayOfWeekShort} (${summary.bestDay!.formattedSteps})'
                      : '-',
                  icon: Icons.star_border,
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsStatCard(
                  label: 'TOTAL STEPS',
                  value: NumberFormat('#,###').format(summary.totalSteps),
                  icon: Icons.directions_walk,
                  accentColor: AppColors.info,
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

class _AnalyticsStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _AnalyticsStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Monthly Activity Summary Card with Navigation
class MonthlyActivityCard extends StatelessWidget {
  final MonthlyActivitySummary summary;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;

  const MonthlyActivityCard({
    super.key,
    required this.summary,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.canGoNext = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MONTHLY SUMMARY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(summary.monthName, style: AppTypography.titleMedium),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                    onPressed: onPreviousMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: canGoNext ? AppColors.textSecondary : AppColors.textDisabled,
                    ),
                    onPressed: canGoNext ? onNextMonth : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Stats 2x2 grid
          Row(
            children: [
              Expanded(
                child: _MonthlyMetricTile(
                  label: 'Total Month Steps',
                  value: NumberFormat('#,###').format(summary.totalSteps),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MonthlyMetricTile(
                  label: 'Average Steps / Day',
                  value: '${NumberFormat('#,###').format(summary.averageStepsPerDay)} / day',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MonthlyMetricTile(
                  label: 'Goal Hit Days',
                  value: '${summary.daysGoalAchieved} days (${(summary.goalAchievementRate * 100).toInt()}%)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MonthlyMetricTile(
                  label: 'Best Day Record',
                  value: summary.bestDay != null
                      ? '${DateFormat('MMM d').format(summary.bestDay!.date)} (${summary.bestDay!.formattedSteps})'
                      : '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyMetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MonthlyMetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. Activity History List
class ActivityHistoryList extends StatelessWidget {
  final List<DailyActivityRecord> records;

  const ActivityHistoryList({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty || records.every((r) => r.steps == 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, size: 30, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            const Text(
              'No step history yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Step history begins after you start walking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: records.map((record) {
        final isGoalAchieved = record.isGoalAchieved;
        final percentage = record.actualPercentage;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGoalAchieved
                      ? AppColors.primaryRed.withAlpha(30)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isGoalAchieved ? AppColors.primaryRed : AppColors.border,
                  ),
                ),
                child: Icon(
                  isGoalAchieved ? Icons.check : Icons.directions_walk,
                  color: isGoalAchieved ? AppColors.primaryRed : AppColors.textSecondary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 14),

              // Date & Goal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.formattedDate(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Goal: ${record.formattedGoal}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Steps & Achievement Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${record.formattedSteps} steps',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isGoalAchieved)
                    const Text(
                      'Goal achieved',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    )
                  else
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// 5. Health Platform Connection Card
class HealthConnectionCard extends StatelessWidget {
  final HealthConnectionStatus status;
  final VoidCallback onConnectTap;
  final VoidCallback onDisconnectTap;
  final VoidCallback onSyncTap;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;

  const HealthConnectionCard({
    super.key,
    required this.status,
    required this.onConnectTap,
    required this.onDisconnectTap,
    required this.onSyncTap,
    required this.syncStatus,
    this.lastSyncedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = status == HealthConnectionStatus.authorized;
    final lastSyncText = lastSyncedAt != null
        ? DateFormat('h:mm a').format(lastSyncedAt!)
        : 'Never';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isConnected ? Icons.favorite : Icons.favorite_border,
                    color: isConnected ? AppColors.primaryRed : AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Health & Step Synchronization',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.success.withAlpha(25)
                      : AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isConnected ? 'Health Data Connected' : 'Health Data Not Connected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isConnected ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            isConnected
                ? 'Syncs automatically with Android Health Connect & Apple Health. Last sync: $lastSyncText (${syncStatus.displayName}).'
                : 'Connect Health Connect or Apple Health for automatic daily activity tracking.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              if (!isConnected)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConnectTap,
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Connect Health Platform'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSyncTap,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sync Now'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onDisconnectTap,
                  child: const Text(
                    'Disconnect',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
