import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';

class CoachReviewDialog extends StatefulWidget {
  final String clientId;
  final WeeklyCheckIn checkIn;
  final WeeklyProgressRepository repository;
  final ValueChanged<WeeklyCheckIn>? onReviewSaved;

  const CoachReviewDialog({
    super.key,
    required this.clientId,
    required this.checkIn,
    required this.repository,
    this.onReviewSaved,
  });

  @override
  State<CoachReviewDialog> createState() => _CoachReviewDialogState();
}

class _CoachReviewDialogState extends State<CoachReviewDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _whatWentWellCtrl;
  late TextEditingController _needsImprovementCtrl;
  late TextEditingController _nextWeekFocusCtrl;
  late TextEditingController _workoutNotesCtrl;
  late TextEditingController _nutritionNotesCtrl;
  late TextEditingController _recoveryNotesCtrl;
  bool _followUpRequired = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.checkIn;
    _whatWentWellCtrl = TextEditingController(text: c.whatWentWell ?? '');
    _needsImprovementCtrl = TextEditingController(text: c.needsImprovement ?? '');
    _nextWeekFocusCtrl = TextEditingController(text: c.nextWeekFocus ?? '');
    _workoutNotesCtrl = TextEditingController(text: c.workoutNotes ?? '');
    _nutritionNotesCtrl = TextEditingController(text: c.nutritionNotes ?? '');
    _recoveryNotesCtrl = TextEditingController(text: c.recoveryNotes ?? '');
    _followUpRequired = c.followUpRequired;
  }

  @override
  void dispose() {
    _whatWentWellCtrl.dispose();
    _needsImprovementCtrl.dispose();
    _nextWeekFocusCtrl.dispose();
    _workoutNotesCtrl.dispose();
    _nutritionNotesCtrl.dispose();
    _recoveryNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final updated = await widget.repository.submitCoachReview(
        widget.clientId,
        widget.checkIn.id,
        {
          'whatWentWell': _whatWentWellCtrl.text.trim(),
          'needsImprovement': _needsImprovementCtrl.text.trim(),
          'nextWeekFocus': _nextWeekFocusCtrl.text.trim(),
          'workoutNotes': _workoutNotesCtrl.text.trim(),
          'nutritionNotes': _nutritionNotesCtrl.text.trim(),
          'recoveryNotes': _recoveryNotesCtrl.text.trim(),
          'followUpRequired': _followUpRequired,
        },
      );

      if (mounted) {
        widget.onReviewSaved?.call(updated);
        Navigator.of(context).pop(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coach review saved successfully!'),
            backgroundColor: AlphaXColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save review: $e'),
            backgroundColor: AlphaXColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AlphaXColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlphaXRadius.lg),
        side: const BorderSide(color: AlphaXColors.border),
      ),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COACH REVIEW: WEEK ${widget.checkIn.weekNumber}',
                        style: const TextStyle(
                          color: AlphaXColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Provide structured feedback for the athlete',
                        style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AlphaXColors.textSecondary),
                  ),
                ],
              ),
              const Divider(color: AlphaXColors.border, height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _whatWentWellCtrl,
                        label: 'What Went Well',
                        hint: 'Great consistency on hydration and workouts...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _needsImprovementCtrl,
                        label: 'Needs Improvement',
                        hint: 'Protein intake was slightly lower than target...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _nextWeekFocusCtrl,
                        label: 'Focus for Next Week',
                        hint: 'Hit 8 hours of sleep and prioritize post-workout meals...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _workoutNotesCtrl,
                        label: 'Workout Notes (Optional)',
                        hint: 'Progression cues, exercise adjustments...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _nutritionNotesCtrl,
                        label: 'Nutrition Notes (Optional)',
                        hint: 'Meal timing, snack suggestions...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _recoveryNotesCtrl,
                        label: 'Recovery Notes (Optional)',
                        hint: 'Mobility work, hydration protocol...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AlphaXColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AlphaXColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Follow-up Required with Client',
                              style: TextStyle(
                                color: AlphaXColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch(
                              value: _followUpRequired,
                              activeColor: AlphaXColors.redAccent,
                              onChanged: (val) => setState(() => _followUpRequired = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: AlphaXColors.border, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AlphaXColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AlphaXColors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Save Review',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AlphaXColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AlphaXColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: AlphaXColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AlphaXColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AlphaXColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AlphaXColors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}
