import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';

class WeeklyComparisonSheet extends StatefulWidget {
  final List<WeeklyCheckIn> history;
  final WeeklyCheckIn? initialWeekA;
  final WeeklyCheckIn? initialWeekB;

  const WeeklyComparisonSheet({
    super.key,
    required this.history,
    this.initialWeekA,
    this.initialWeekB,
  });

  @override
  State<WeeklyComparisonSheet> createState() => _WeeklyComparisonSheetState();
}

class _WeeklyComparisonSheetState extends State<WeeklyComparisonSheet> {
  late WeeklyCheckIn? _weekA;
  late WeeklyCheckIn? _weekB;

  @override
  void initState() {
    super.initState();
    final sorted = List<WeeklyCheckIn>.from(widget.history)
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    if (widget.initialWeekA != null) {
      _weekA = widget.initialWeekA;
    } else if (sorted.length >= 2) {
      _weekA = sorted[sorted.length - 2]; // Previous week
    } else if (sorted.isNotEmpty) {
      _weekA = sorted.first;
    } else {
      _weekA = null;
    }

    if (widget.initialWeekB != null) {
      _weekB = widget.initialWeekB;
    } else if (sorted.isNotEmpty) {
      _weekB = sorted.last; // Current / latest week
    } else {
      _weekB = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AlphaXColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    child: const Icon(Icons.compare_arrows_rounded, color: AlphaXColors.gold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'WEEK-TO-WEEK COMPARISON',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AlphaXColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Week Selectors
          Row(
            children: [
              Expanded(
                child: _buildWeekSelector(
                  label: 'Baseline Week',
                  selected: _weekA,
                  onChanged: (w) => setState(() => _weekA = w),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded, color: AlphaXColors.textTertiary, size: 18),
              ),
              Expanded(
                child: _buildWeekSelector(
                  label: 'Comparison Week',
                  selected: _weekB,
                  onChanged: (w) => setState(() => _weekB = w),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_weekA == null || _weekB == null)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Select two weeks to compare data side by side.',
                  style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 13),
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMetricComparisonCard(
                      title: 'BODY WEIGHT',
                      unit: 'kg',
                      valA: _weekA!.weightKg,
                      valB: _weekB!.weightKg,
                      valADisplay: _weekA!.weightDisplay,
                      valBDisplay: _weekB!.weightDisplay,
                      isNumeric: true,
                    ),
                    const SizedBox(height: 10),
                    _buildMetricComparisonCard(
                      title: 'WAIST MEASUREMENT',
                      unit: 'cm',
                      valA: _weekA!.waistCm,
                      valB: _weekB!.waistCm,
                      valADisplay: _weekA!.waistDisplay,
                      valBDisplay: _weekB!.waistDisplay,
                      isNumeric: true,
                    ),
                    const SizedBox(height: 10),
                    _buildDiscreteComparisonCard(
                      title: 'WORKOUT COMPLETION',
                      valA: _weekA!.workoutCompletion,
                      valB: _weekB!.workoutCompletion,
                      icon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildDiscreteComparisonCard(
                      title: 'PROTEIN ADHERENCE',
                      valA: _weekA!.nutritionProtein,
                      valB: _weekB!.nutritionProtein,
                      icon: Icons.egg_alt_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildDiscreteComparisonCard(
                      title: 'WATER INTAKE',
                      valA: _weekA!.nutritionWater,
                      valB: _weekB!.nutritionWater,
                      icon: Icons.water_drop_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildDiscreteComparisonCard(
                      title: 'SLEEP QUALITY & HOURS',
                      valA: '${_weekA!.sleepQuality} (${_weekA!.sleepHours.toStringAsFixed(1)}h)',
                      valB: '${_weekB!.sleepQuality} (${_weekB!.sleepHours.toStringAsFixed(1)}h)',
                      icon: Icons.bedtime_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildDiscreteComparisonCard(
                      title: 'RECOVERY STATUS',
                      valA: _weekA!.recoveryQuality,
                      valB: _weekB!.recoveryQuality,
                      icon: Icons.battery_charging_full_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildProblemsComparisonCard(
                      title: 'REPORTED PROBLEMS',
                      listA: _weekA!.weeklyProblems,
                      listB: _weekB!.weeklyProblems,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AlphaXColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Note: Observations are purely descriptive measurements and do not constitute health or medical conclusions.',
                        style: TextStyle(color: AlphaXColors.textMuted, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector({
    required String label,
    required WeeklyCheckIn? selected,
    required ValueChanged<WeeklyCheckIn?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<WeeklyCheckIn>(
              isExpanded: true,
              value: selected,
              dropdownColor: AlphaXColors.surfaceElevated,
              icon: const Icon(Icons.arrow_drop_down, color: AlphaXColors.textSecondary),
              items: widget.history.map((item) {
                return DropdownMenuItem<WeeklyCheckIn>(
                  value: item,
                  child: Text(
                    'Week ${item.weekNumber}',
                    style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricComparisonCard({
    required String title,
    required String unit,
    required double? valA,
    required double? valB,
    required String valADisplay,
    required String valBDisplay,
    required bool isNumeric,
  }) {
    double? delta;
    if (valA != null && valB != null) {
      delta = ((valB - valA) * 10).round() / 10;
    }

    String deltaDisplay = '—';
    Color deltaColor = AlphaXColors.textSecondary;
    if (delta != null) {
      final sign = delta > 0 ? '+' : '';
      deltaDisplay = '$sign${delta.toStringAsFixed(1)} $unit';
      if (delta < 0) {
        deltaColor = AlphaXColors.success;
      } else if (delta > 0) {
        deltaColor = AlphaXColors.warning;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week ${_weekA?.weekNumber}', style: const TextStyle(color: AlphaXColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(valADisplay, style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AlphaXColors.textMuted, size: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Week ${_weekB?.weekNumber}', style: const TextStyle(color: AlphaXColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(valBDisplay, style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  deltaDisplay,
                  style: TextStyle(color: deltaColor, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscreteComparisonCard({
    required String title,
    required String valA,
    required String valB,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AlphaXColors.textTertiary, size: 12),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week ${_weekA?.weekNumber}: $valA',
                  style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.compare_arrows_rounded, color: AlphaXColors.textMuted, size: 14),
              Expanded(
                child: Text(
                  'Week ${_weekB?.weekNumber}: $valB',
                  style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProblemsComparisonCard({
    required String title,
    required List<String> listA,
    required List<String> listB,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week ${_weekA?.weekNumber}', style: const TextStyle(color: AlphaXColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 4),
                    if (listA.isEmpty)
                      const Text('None reported', style: TextStyle(color: AlphaXColors.success, fontSize: 11))
                    else
                      ...listA.map((p) => Text('• $p', style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week ${_weekB?.weekNumber}', style: const TextStyle(color: AlphaXColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 4),
                    if (listB.isEmpty)
                      const Text('None reported', style: TextStyle(color: AlphaXColors.success, fontSize: 11))
                    else
                      ...listB.map((p) => Text('• $p', style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 11))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
