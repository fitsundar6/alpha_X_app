import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/macro_repository.dart';
import '../../domain/models/macro_input.dart';
import '../../domain/models/macro_result.dart';
import '../widgets/calculation_breakdown.dart';
import '../widgets/macro_target_card.dart';

/// Screen presenting the computed daily nutrition targets
class MacroResultScreen extends StatefulWidget {
  final MacroInput input;
  final MacroResult result;
  final MacroRepository repository;
  final bool isFromHistory;

  const MacroResultScreen({
    super.key,
    required this.input,
    required this.result,
    required this.repository,
    this.isFromHistory = false,
  });

  @override
  State<MacroResultScreen> createState() => _MacroResultScreenState();
}

class _MacroResultScreenState extends State<MacroResultScreen> {
  bool _isSaved = false;

  void _saveTarget() {
    widget.repository.saveTargets(
      input: widget.input,
      result: widget.result,
      note: 'Saved on ${DateTime.now().day}/${DateTime.now().month}',
    );
    setState(() => _isSaved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daily Nutrition Targets saved successfully!'),
        backgroundColor: AppColors.primaryRed,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final input = widget.input;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YOUR DAILY TARGETS'),
        actions: [
          if (!_isSaved && !widget.isFromHistory)
            TextButton.icon(
              onPressed: _saveTarget,
              icon: const Icon(Icons.bookmark_border, size: 18, color: AppColors.primaryRed),
              label: const Text(
                'SAVE',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryRed),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Goal & Maintenance Header Pill
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMATED MAINTENANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.maintenanceCalories} kcal/day',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 14, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text(
                        input.goal.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Safeguard alert banner if target falls below safety floor
          if (result.isBelowSafeguardThreshold && result.safeguardWarning != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF261D10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withAlpha(150), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MINIMUM CALORIE SAFEGUARD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.safeguardWarning!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE8DAC2),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary Calorie Card
          MacroTargetCard(
            label: 'Daily Calories',
            emoji: '🔥',
            value: result.targetCalories,
            unit: 'kcal / day',
            isPrimaryHighlight: true,
            accentColor: AppColors.primaryRed,
          ),

          const SizedBox(height: 12),

          // Macronutrients Grid (Protein, Carbohydrates, Fat)
          MacroTargetCard(
            label: 'Protein',
            emoji: '🥩',
            value: result.proteinGrams,
            unit: 'g / day',
            range: result.proteinRange,
            caloriePercent: result.proteinCaloriePercent,
            accentColor: AppColors.accentRed,
          ),

          const SizedBox(height: 12),

          MacroTargetCard(
            label: 'Carbohydrates',
            emoji: '🍚',
            value: result.carbGrams,
            unit: 'g / day',
            range: result.carbRange,
            caloriePercent: result.carbCaloriePercent,
            accentColor: AppColors.info,
          ),

          const SizedBox(height: 12),

          MacroTargetCard(
            label: 'Dietary Fat',
            emoji: '🥑',
            value: result.fatGrams,
            unit: 'g / day',
            range: result.fatRange,
            caloriePercent: result.fatCaloriePercent,
            accentColor: AppColors.gold,
          ),

          const SizedBox(height: 12),

          // Fiber Target Card
          MacroTargetCard(
            label: 'Daily Fiber Target',
            emoji: '🌾',
            value: result.fiberGrams,
            unit: 'g / day',
            range: result.fiberRange,
            accentColor: AppColors.success,
          ),

          const SizedBox(height: 20),

          // Step-by-Step Calculation Breakdown
          CalculationBreakdownWidget(input: input, result: result),

          const SizedBox(height: 20),

          // Action Buttons: Save My Targets & Recalculate
          if (!_isSaved && !widget.isFromHistory) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveTarget,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'SAVE MY TARGETS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'RECALCULATE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Educational & Non-medical Disclaimer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These targets are estimates based on the information you provided. Individual energy and nutrition needs vary. This calculator does not provide medical or dietary treatment. If you have a medical condition, are pregnant/breastfeeding, are under 18, or have specific nutritional needs, consult a qualified healthcare professional.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
