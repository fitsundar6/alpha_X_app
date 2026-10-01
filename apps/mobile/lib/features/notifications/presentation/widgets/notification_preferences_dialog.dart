import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';

class NotificationPreferencesDialog extends StatefulWidget {
  final NotificationRepository repository;

  const NotificationPreferencesDialog({super.key, required this.repository});

  static void show(BuildContext context, NotificationRepository repo) {
    repo.fetchPreferences();
    showDialog(
      context: context,
      builder: (ctx) => NotificationPreferencesDialog(repository: repo),
    );
  }

  @override
  State<NotificationPreferencesDialog> createState() => _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState extends State<NotificationPreferencesDialog> {
  late bool _workout;
  late bool _nutrition;
  late bool _checkIn;
  late bool _activity;
  late bool _membership;
  late bool _ai;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.repository.preferences;
    _workout = p.workoutReminders;
    _nutrition = p.nutritionReminders;
    _checkIn = p.weeklyCheckInReminders;
    _activity = p.activityReminders;
    _membership = p.membershipAlerts;
    _ai = p.aiEngagementEnabled;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = NotificationPreferences(
      workoutReminders: _workout,
      nutritionReminders: _nutrition,
      weeklyCheckInReminders: _checkIn,
      activityReminders: _activity,
      membershipAlerts: _membership,
      aiEngagementEnabled: _ai,
    );
    await widget.repository.updatePreferences(updated);
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preferences saved successfully.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: AppColors.primaryRed, size: 20),
          SizedBox(width: 8),
          Text(
            'NOTIFICATION SETTINGS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _switchTile('Workout Reminders', 'Scheduled session alerts and completion confirmations', _workout, (v) => setState(() => _workout = v)),
            _switchTile('Nutrition Tracking', 'Daily macro targets, protein gap and meal logging reminders', _nutrition, (v) => setState(() => _nutrition = v)),
            _switchTile('Weekly Check-In', 'Unlocked check-in and weekly progress submission reminders', _checkIn, (v) => setState(() => _checkIn = v)),
            _switchTile('Steps & Activity', 'Daily step target progress and evening activity prompts', _activity, (v) => setState(() => _activity = v)),
            _switchTile('Membership Notices', 'Renewal reminders and plan expiry warnings', _membership, (v) => setState(() => _membership = v)),
            const Divider(color: AppColors.border),
            _switchTile(
              'AI Personalized Motivation',
              'Allow AI coach to adapt message tone based on real progress metrics',
              _ai,
              (v) => setState(() => _ai = v),
              badge: 'AI COACH',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
          child: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('SAVE PREFERENCES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.glowRed, borderRadius: BorderRadius.circular(4)),
                        child: Text(badge, style: const TextStyle(color: AppColors.primaryRed, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primaryRed,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
