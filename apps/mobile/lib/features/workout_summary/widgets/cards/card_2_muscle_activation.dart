import 'package:flutter/material.dart';
import '../../models/workout_summary_models.dart';
import '../../utils/muscle_mapping.dart';
import '../muscle_body_widget.dart';
import '../share_card_base.dart';

/// Page 2: MUSCLE ACTIVATION CARD (The flagship anatomy visualization feature).
///
/// Features:
/// - Dark background (#0A0A0A), radius 32, padding 24
/// - Header with Plan Name, Week · Day, Date, and yellow #FFC400 divider
/// - Center: Dual FRONT and BACK vector anatomical silhouettes side-by-side
///   highlighting trained muscles with dynamic orange/amber gradients
/// - Wrap chips (dark pill #1A1A1A, radius 20) with matching colored dots
///   and pluralized "N set(s)"
/// - Footer: App logo + wordmark and user handle
class Card2MuscleActivation extends StatelessWidget {
  final WorkoutSummary summary;
  final String? customWordmark;

  const Card2MuscleActivation({
    super.key,
    required this.summary,
    this.customWordmark,
  });

  @override
  Widget build(BuildContext context) {
    final activations = computeMuscleActivations(summary.exercises);

    return ShareCardBase(
      summary: summary,
      customWordmark: customWordmark ?? 'BOOSTCAMP',
      child: Column(
        children: [
          // Center Anatomy Figures (FRONT & BACK side-by-side)
          Expanded(
            flex: 3,
            child: Center(
              child: MuscleBodyWidget(
                activations: activations,
                height: 230,
                animateEntry: true,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Wrap chips: [colored dot] MuscleName "N set(s)"
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: activations.map((activation) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2C2C2C),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Colored dot matching the muscle highlight color
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: activation.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activation.color.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Muscle Name
                    Text(
                      activation.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // "N set(s)"
                    Text(
                      formatSetsPlural(activation.sets),
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
