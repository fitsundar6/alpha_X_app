import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/macro_repository.dart';
import 'macro_result_screen.dart';

/// Screen displaying the history of saved daily nutrition targets
class MacroHistoryScreen extends StatelessWidget {
  final MacroRepository repository;

  const MacroHistoryScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final history = repository.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MACRO HISTORY'),
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history_outlined, size: 48, color: AppColors.textTertiary),
                  SizedBox(height: 12),
                  Text('No Macro History Yet', style: AppTypography.headlineSmall),
                  SizedBox(height: 6),
                  Text(
                    'Calculated and saved nutrition targets will appear here.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              itemCount: history.length,
              itemBuilder: (ctx, index) {
                final entry = history[index];
                final r = entry.result;
                final dateStr = DateFormat('d MMM yyyy • h:mm a').format(entry.timestamp);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => MacroResultScreen(
                            input: entry.input,
                            result: entry.result,
                            repository: repository,
                            isFromHistory: true,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Text(
                                  entry.input.goal.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${r.targetCalories}',
                                style: AppTypography.displayMedium.copyWith(fontSize: 26),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'kcal / day',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Macro Pill Row
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _MacroPill(label: 'Protein', value: '${r.proteinGrams}g', color: AppColors.accentRed),
                              _MacroPill(label: 'Carbs', value: '${r.carbGrams}g', color: AppColors.info),
                              _MacroPill(label: 'Fat', value: '${r.fatGrams}g', color: AppColors.gold),
                              _MacroPill(label: 'Fiber', value: '${r.fiberGrams}g', color: AppColors.success),
                            ],
                          ),
                          if (entry.note.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              entry.note,
                              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
