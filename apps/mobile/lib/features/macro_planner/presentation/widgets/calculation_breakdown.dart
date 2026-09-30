import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/macro_input.dart';
import '../../domain/models/macro_result.dart';

/// Transparent expandable breakdown explaining every calculation step
class CalculationBreakdownWidget extends StatefulWidget {
  final MacroInput input;
  final MacroResult result;

  const CalculationBreakdownWidget({
    super.key,
    required this.input,
    required this.result,
  });

  @override
  State<CalculationBreakdownWidget> createState() => _CalculationBreakdownWidgetState();
}

class _CalculationBreakdownWidgetState extends State<CalculationBreakdownWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.result.breakdown;
    final input = widget.input;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.analytics_outlined, color: AppColors.primaryRed, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'HOW WE CALCULATED THIS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(color: AppColors.borderSubtle, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BreakdownRow(
                    title: '1. Basal Metabolic Rate (BMR)',
                    formula: 'Mifflin-St Jeor (${input.sex.displayName})',
                    math: '10 × ${input.weightKg}kg + 6.25 × ${input.heightCm}cm − 5 × ${input.age} ${input.sex.bmrOffset >= 0 ? '+' : ''}${input.sex.bmrOffset.toInt()}',
                    resultText: '${widget.result.bmr.toString()} kcal',
                    tooltip: 'Calories burned simply maintaining basic life functions at complete rest.',
                  ),
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    title: '2. Estimated Maintenance (TDEE)',
                    formula: '${input.activityLevel.displayName} Multiplier',
                    math: '${widget.result.bmr} kcal × ${input.activityLevel.defaultMultiplier}',
                    resultText: '${widget.result.maintenanceCalories.toString()} kcal/day',
                    tooltip: 'Estimated daily energy expenditure including lifestyle activity.',
                  ),
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    title: '3. Goal Energy Adjustment',
                    formula: input.goal.displayName,
                    math: '${widget.result.maintenanceCalories} kcal × ${input.goal.defaultAdjustmentFactor} (${b.goalAdjustmentPercent >= 0 ? '+' : ''}${b.goalAdjustmentPercent.toStringAsFixed(0)}%)',
                    resultText: '${widget.result.targetCalories.toString()} kcal/day',
                    tooltip: 'Calorie target calibrated for your chosen goal.',
                  ),
                  if (widget.result.isBelowSafeguardThreshold) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withAlpha(100)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.shield_outlined, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Minimum safety threshold safeguard applied to prevent extreme deficits.',
                              style: TextStyle(fontSize: 11, color: AppColors.warning, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    title: '4. Protein Target',
                    formula: '${input.goal.defaultProteinFactor} g / kg bodyweight',
                    math: '${input.weightKg}kg × ${input.goal.defaultProteinFactor} = ${widget.result.proteinGrams}g (×4 kcal)',
                    resultText: '${(widget.result.proteinGrams * 4)} kcal (${widget.result.proteinGrams}g)',
                    tooltip: 'Protects lean tissue and supports muscle recovery.',
                  ),
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    title: '5. Dietary Fat Target',
                    formula: '0.8 g / kg bodyweight',
                    math: '${input.weightKg}kg × 0.8 = ${widget.result.fatGrams}g (×9 kcal)',
                    resultText: '${(widget.result.fatGrams * 9)} kcal (${widget.result.fatGrams}g)',
                    tooltip: 'Supports healthy endocrine function and essential fatty acid absorption.',
                  ),
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    title: '6. Carbohydrates Target',
                    formula: 'Remaining Calories ÷ 4',
                    math: '${widget.result.targetCalories} kcal − ${(widget.result.proteinGrams * 4)} (P) − ${(widget.result.fatGrams * 9)} (F) = ${(widget.result.carbGrams * 4)} kcal',
                    resultText: '${(widget.result.carbGrams * 4)} kcal (${widget.result.carbGrams}g)',
                    tooltip: 'Supplies glycogen to fuel high-intensity strength training.',
                  ),
                  if (b.wasCarbRebalanced) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '• Note: Fat was adjusted slightly to guarantee a safe minimum carbohydrate intake floor.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textTertiary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    title: '7. Daily Fiber Target',
                    formula: '14 g / 1,000 kcal',
                    math: '(${widget.result.targetCalories} ÷ 1,000) × 14',
                    resultText: '${widget.result.fiberGrams}g / day',
                    tooltip: 'Supports digestion, gut microbiome, and sustained satiety.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String title;
  final String formula;
  final String math;
  final String resultText;
  final String tooltip;

  const _BreakdownRow({
    required this.title,
    required this.formula,
    required this.math,
    required this.resultText,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                resultText,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryRed),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formula,
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              Text(
                math,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tooltip,
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
