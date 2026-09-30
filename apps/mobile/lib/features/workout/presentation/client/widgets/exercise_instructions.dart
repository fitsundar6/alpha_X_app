import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';

/// Clean, expandable instruction card displaying authentic Setup and Execution steps.
class ExerciseInstructions extends StatefulWidget {
  final List<String> setupInstructions;
  final List<String> executionSteps;
  final List<String> coachingCues;
  final bool initialExpanded;

  const ExerciseInstructions({
    super.key,
    required this.setupInstructions,
    required this.executionSteps,
    this.coachingCues = const [],
    this.initialExpanded = true,
  });

  @override
  State<ExerciseInstructions> createState() => _ExerciseInstructionsState();
}

class _ExerciseInstructionsState extends State<ExerciseInstructions>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSetup = widget.setupInstructions.isNotEmpty;
    final hasExecution = widget.executionSteps.isNotEmpty;
    final hasCues = widget.coachingCues.isNotEmpty;

    if (!hasSetup && !hasExecution && !hasCues) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header toggle button
          AlphaXPressable(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: Colors.transparent,
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'How to Perform',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable body
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),

                  // SETUP SECTION
                  if (hasSetup) ...[
                    _buildSectionHeader('Setup'),
                    const SizedBox(height: 8),
                    ...widget.setupInstructions.asMap().entries.map(
                          (entry) => _buildStepRow(entry.key + 1, entry.value),
                        ),
                    const SizedBox(height: 12),
                  ],

                  // EXECUTION SECTION
                  if (hasExecution) ...[
                    _buildSectionHeader('Execution'),
                    const SizedBox(height: 8),
                    ...widget.executionSteps.asMap().entries.map(
                          (entry) => _buildStepRow(entry.key + 1, entry.value),
                        ),
                  ],

                  // COACHING CUES SECTION (Optional)
                  if (hasCues) ...[
                    const SizedBox(height: 12),
                    _buildSectionHeader('Key Form Cues'),
                    const SizedBox(height: 8),
                    ...widget.coachingCues.map((cue) => _buildCueRow(cue)),
                  ],
                ],
              ),
            ),
            crossFadeState:
                _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildStepRow(int number, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCueRow(String cue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 15,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cue,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
