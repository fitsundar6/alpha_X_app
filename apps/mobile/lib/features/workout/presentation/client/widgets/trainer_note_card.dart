import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';

/// Visually noticeable, non-distracting trainer note card.
/// Automatically hides itself when note is empty.
class TrainerNoteCard extends StatelessWidget {
  final String note;

  const TrainerNoteCard({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.primaryRed,
              ),
              SizedBox(width: 8),
              Text(
                'Trainer Note',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '“$cleanNote”',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
