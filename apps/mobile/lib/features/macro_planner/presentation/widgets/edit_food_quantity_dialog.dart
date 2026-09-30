import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/alpha_x_widgets.dart';
import '../../domain/models/food_log_entry.dart';
import '../../data/repositories/macro_repository.dart';

/// Modal dialog for modifying quantity or deleting an individual logged food item
class EditFoodQuantityDialog extends StatefulWidget {
  final FoodLogEntry entry;
  final MacroRepository repository;

  const EditFoodQuantityDialog({
    super.key,
    required this.entry,
    required this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required FoodLogEntry entry,
    required MacroRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => EditFoodQuantityDialog(
        entry: entry,
        repository: repository,
      ),
    );
  }

  @override
  State<EditFoodQuantityDialog> createState() => _EditFoodQuantityDialogState();
}

class _EditFoodQuantityDialogState extends State<EditFoodQuantityDialog> {
  late double _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.entry.quantity;
  }

  void _adjustQuantity(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _quantity = (_quantity + delta).clamp(0.25, 99.0);
    });
  }

  void _saveQuantity() {
    HapticFeedback.mediumImpact();
    widget.repository.updateFoodEntryQuantity(widget.entry.id, _quantity);
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        title: const Text('Delete Food Item?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Remove "${widget.entry.foodName}" from ${widget.entry.mealType.displayName}? Other foods in this meal will remain intact.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // pop confirmation
              HapticFeedback.lightImpact();
              widget.repository.deleteFoodEntry(widget.entry.id);
              Navigator.of(context).pop(); // pop edit dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${widget.entry.foodName} from ${widget.entry.mealType.displayName}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete Item', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curCal = (widget.entry.baseCalories * _quantity).round();
    final curProt = FoodLogEntry.formatMacro(widget.entry.baseProtein * _quantity);
    final curCarbs = FoodLogEntry.formatMacro(widget.entry.baseCarbs * _quantity);
    final curFat = FoodLogEntry.formatMacro(widget.entry.baseFat * _quantity);
    final curFiber = FoodLogEntry.formatMacro(widget.entry.baseFiber * _quantity);

    // Create a temporary entry to use its formatted quantity display
    final tempEntry = widget.entry.copyWith(quantity: _quantity);
    final quantityText = tempEntry.quantityDisplay;

    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.foodName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.entry.mealType.displayName} • Base: ${widget.entry.baseCalories.round()} kcal per ${widget.entry.servingSize % 1 == 0 ? widget.entry.servingSize.toInt() : widget.entry.servingSize} ${widget.entry.servingUnit}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Quantity Stepper Row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MODIFY QUANTITY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _stepperBtn('-1', () => _adjustQuantity(-1.0)),
                        const SizedBox(width: 6),
                        _stepperBtn('-0.5', () => _adjustQuantity(-0.5)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
                          ),
                          child: Text(
                            quantityText,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _stepperBtn('+0.5', () => _adjustQuantity(0.5)),
                        const SizedBox(width: 6),
                        _stepperBtn('+1', () => _adjustQuantity(1.0)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic Recalculated Macros
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _macroPill('Calories', '$curCal kcal', AppColors.primaryRed),
                    _macroPill('Protein', '${curProt}g', AppColors.accentRed),
                    _macroPill('Carbs', '${curCarbs}g', AppColors.info),
                    _macroPill('Fat', '${curFat}g', AppColors.gold),
                    if (widget.entry.baseFiber > 0)
                      _macroPill('Fiber', '${curFiber}g', AppColors.success),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons: Update & Delete
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.primaryRed, size: 22),
                    tooltip: 'Delete Food Item',
                    onPressed: _confirmDelete,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AlphaXPressable(
                      onTap: _saveQuantity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRed.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'UPDATE QUANTITY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepperBtn(String label, VoidCallback onTap) {
    return AlphaXPressable(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }

  Widget _macroPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
