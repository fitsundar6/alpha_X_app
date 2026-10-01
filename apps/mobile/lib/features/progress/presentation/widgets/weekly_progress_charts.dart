import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';

/// 1. Weight Progress Line Chart Card
class WeightProgressChartCard extends StatelessWidget {
  final List<WeeklyCheckIn> checkIns;

  const WeightProgressChartCard({super.key, required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final sorted = List<WeeklyCheckIn>.from(checkIns)
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AlphaXColors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.show_chart_rounded, color: AlphaXColors.redAccent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'WEIGHT PROGRESS',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (sorted.isNotEmpty)
                Text(
                  'Latest: ${sorted.last.weightDisplay}',
                  style: const TextStyle(
                    color: AlphaXColors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            _buildEmptyState('No weekly weight check-in data yet')
          else if (sorted.length == 1)
            _buildSinglePointState(
              label: 'Week ${sorted.first.weekNumber}',
              value: sorted.first.weightDisplay,
              sub: 'Baseline recorded. Complete next week to see trajectory.',
            )
          else
            _buildLineChart(sorted),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 12),
      ),
    );
  }

  Widget _buildSinglePointState({required String label, required String value, required String sub}) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AlphaXColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<WeeklyCheckIn> sorted) {
    final spots = <FlSpot>[];
    double minWeight = double.infinity;
    double maxWeight = -double.infinity;

    for (int i = 0; i < sorted.length; i++) {
      final w = sorted[i].weightKg;
      spots.add(FlSpot(i.toDouble(), w));
      minWeight = min(minWeight, w);
      maxWeight = max(maxWeight, w);
    }

    final minY = (minWeight - 1.5).floorToDouble();
    final maxY = (maxWeight + 1.5).ceilToDouble();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AlphaXColors.border.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}kg',
                    style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < sorted.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'W${sorted[idx].weekNumber}',
                        style: const TextStyle(
                          color: AlphaXColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sorted.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AlphaXColors.surfaceElevated,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final item = sorted[idx];
                  return LineTooltipItem(
                    'Week ${item.weekNumber}\n${item.weightDisplay}',
                    const TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AlphaXColors.redAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AlphaXColors.redAccent,
                    strokeWidth: 2,
                    strokeColor: Colors.black,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AlphaXColors.redAccent.withValues(alpha: 0.25),
                    AlphaXColors.redAccent.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Waist Progress Line Chart Card
class WaistProgressChartCard extends StatelessWidget {
  final List<WeeklyCheckIn> checkIns;

  const WaistProgressChartCard({super.key, required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final sortedWithWaist = List<WeeklyCheckIn>.from(checkIns)
        .where((c) => c.waistCm != null && c.waistCm! > 0)
        .toList()
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AlphaXColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.straighten_rounded, color: AlphaXColors.gold, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'WAIST PROGRESS',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (sortedWithWaist.isNotEmpty)
                Text(
                  'Latest: ${sortedWithWaist.last.waistDisplay}',
                  style: const TextStyle(
                    color: AlphaXColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedWithWaist.isEmpty)
            _buildEmptyState('No waist measurement data recorded yet')
          else if (sortedWithWaist.length == 1)
            _buildSinglePointState(
              label: 'Week ${sortedWithWaist.first.weekNumber}',
              value: sortedWithWaist.first.waistDisplay,
              sub: 'Baseline recorded. Complete next week to see trajectory.',
            )
          else
            _buildLineChart(sortedWithWaist),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 12),
      ),
    );
  }

  Widget _buildSinglePointState({required String label, required String value, required String sub}) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AlphaXColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<WeeklyCheckIn> sorted) {
    final spots = <FlSpot>[];
    double minWaist = double.infinity;
    double maxWaist = -double.infinity;

    for (int i = 0; i < sorted.length; i++) {
      final w = sorted[i].waistCm!;
      spots.add(FlSpot(i.toDouble(), w));
      minWaist = min(minWaist, w);
      maxWaist = max(maxWaist, w);
    }

    final minY = (minWaist - 1.5).floorToDouble();
    final maxY = (maxWaist + 1.5).ceilToDouble();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AlphaXColors.border.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}cm',
                    style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < sorted.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'W${sorted[idx].weekNumber}',
                        style: const TextStyle(
                          color: AlphaXColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sorted.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AlphaXColors.surfaceElevated,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final item = sorted[idx];
                  return LineTooltipItem(
                    'Week ${item.weekNumber}\n${item.waistDisplay}',
                    const TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AlphaXColors.gold,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AlphaXColors.gold,
                    strokeWidth: 2,
                    strokeColor: Colors.black,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AlphaXColors.gold.withValues(alpha: 0.2),
                    AlphaXColors.gold.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. Workout Consistency Visual Card
class WorkoutConsistencyCard extends StatelessWidget {
  final WeeklyCheckIn checkIn;

  const WorkoutConsistencyCard({super.key, required this.checkIn});

  Color _getCompletionColor(String completion) {
    switch (completion.toLowerCase()) {
      case 'all':
        return AlphaXColors.success;
      case 'most':
        return const Color(0xFF66BB6A);
      case 'some':
        return AlphaXColors.warning;
      case 'none':
        return AlphaXColors.error;
      default:
        return AlphaXColors.textSecondary;
    }
  }

  Color _getFeelingColor(String feeling) {
    switch (feeling.toLowerCase()) {
      case 'very good':
        return AlphaXColors.success;
      case 'good':
        return const Color(0xFF66BB6A);
      case 'average':
        return AlphaXColors.warning;
      case 'difficult':
        return AlphaXColors.error;
      default:
        return AlphaXColors.textSecondary;
    }
  }

  Color _getEnergyColor(String energy) {
    switch (energy.toLowerCase()) {
      case 'high':
        return AlphaXColors.gold;
      case 'good':
        return AlphaXColors.success;
      case 'low':
        return AlphaXColors.error;
      default:
        return AlphaXColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.fitness_center_rounded, color: AlphaXColors.redAccent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'WORKOUT CONSISTENCY',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRow('Planned Workouts', checkIn.workoutCompletion, _getCompletionColor(checkIn.workoutCompletion)),
          const SizedBox(height: 10),
          _buildRow('Workout Feeling', checkIn.workoutFeeling, _getFeelingColor(checkIn.workoutFeeling)),
          const SizedBox(height: 10),
          _buildRow('Energy Level', checkIn.energyLevel, _getEnergyColor(checkIn.energyLevel)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color badgeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 4. Nutrition Consistency Visual Card
class NutritionConsistencyCard extends StatelessWidget {
  final WeeklyCheckIn checkIn;

  const NutritionConsistencyCard({super.key, required this.checkIn});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return AlphaXColors.success;
      case 'mostly':
      case 'average':
        return AlphaXColors.warning;
      case 'poor':
        return AlphaXColors.error;
      default:
        return AlphaXColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.restaurant_rounded, color: Color(0xFF4CAF50), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'NUTRITION CONSISTENCY',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRow('Calories Target', checkIn.nutritionCalories, _getStatusColor(checkIn.nutritionCalories)),
          const SizedBox(height: 10),
          _buildRow('Protein Intake', checkIn.nutritionProtein, _getStatusColor(checkIn.nutritionProtein)),
          const SizedBox(height: 10),
          _buildRow('Water Hydration', checkIn.nutritionWater, _getStatusColor(checkIn.nutritionWater)),
          const SizedBox(height: 10),
          _buildRow('Diet Adherence', checkIn.dietAdherence, _getStatusColor(checkIn.dietAdherence)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 5. Sleep & Recovery Visual Card
class SleepRecoveryCard extends StatelessWidget {
  final WeeklyCheckIn checkIn;

  const SleepRecoveryCard({super.key, required this.checkIn});

  Color _getQualityColor(String q) {
    switch (q.toLowerCase()) {
      case 'good':
        return AlphaXColors.success;
      case 'average':
        return AlphaXColors.warning;
      case 'poor':
        return AlphaXColors.error;
      default:
        return AlphaXColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF29B6F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bedtime_rounded, color: Color(0xFF29B6F6), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'SLEEP & RECOVERY',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Average Sleep',
                        style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${checkIn.sleepHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                          color: AlphaXColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Sleep Quality',
                        style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkIn.sleepQuality,
                        style: TextStyle(
                          color: _getQualityColor(checkIn.sleepQuality),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Recovery',
                        style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkIn.recoveryQuality,
                        style: TextStyle(
                          color: _getQualityColor(checkIn.recoveryQuality),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 6. Weekly Habit Overview Card
class WeeklyHabitOverviewCard extends StatelessWidget {
  final WeeklyCheckIn checkIn;

  const WeeklyHabitOverviewCard({super.key, required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final habits = [
      _HabitStatus(
        title: 'Protein',
        isPassed: checkIn.nutritionProtein.toLowerCase() == 'good',
        label: checkIn.nutritionProtein,
        icon: Icons.egg_alt_outlined,
      ),
      _HabitStatus(
        title: 'Water',
        isPassed: checkIn.nutritionWater.toLowerCase() == 'good',
        label: checkIn.nutritionWater,
        icon: Icons.water_drop_outlined,
      ),
      _HabitStatus(
        title: 'Sleep',
        isPassed: checkIn.sleepQuality.toLowerCase() == 'good' || checkIn.sleepHours >= 7.0,
        label: '${checkIn.sleepHours.toStringAsFixed(1)}h',
        icon: Icons.nightlight_outlined,
      ),
      _HabitStatus(
        title: 'Workout',
        isPassed: checkIn.workoutCompletion.toLowerCase() == 'all' || checkIn.workoutCompletion.toLowerCase() == 'most',
        label: checkIn.workoutCompletion,
        icon: Icons.fitness_center_outlined,
      ),
      _HabitStatus(
        title: 'Recovery',
        isPassed: checkIn.recoveryQuality.toLowerCase() == 'good',
        label: checkIn.recoveryQuality,
        icon: Icons.battery_charging_full_outlined,
      ),
    ];

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
                  color: AlphaXColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.checklist_rounded, color: AlphaXColors.gold, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'WEEKLY HABIT OVERVIEW',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: habits.map((h) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: h.isPassed
                          ? AlphaXColors.success.withValues(alpha: 0.4)
                          : AlphaXColors.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        h.isPassed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: h.isPassed ? AlphaXColors.success : AlphaXColors.textTertiary,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        h.title,
                        style: const TextStyle(
                          color: AlphaXColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        h.label,
                        style: TextStyle(
                          color: h.isPassed ? AlphaXColors.success : AlphaXColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HabitStatus {
  final String title;
  final bool isPassed;
  final String label;
  final IconData icon;

  const _HabitStatus({
    required this.title,
    required this.isPassed,
    required this.label,
    required this.icon,
  });
}
