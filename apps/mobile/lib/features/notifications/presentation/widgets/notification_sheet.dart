import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationSheet extends StatelessWidget {
  final NotificationRepository repository;

  const NotificationSheet({super.key, required this.repository});

  static void show(BuildContext context, NotificationRepository repo) {
    repo.fetchNotifications();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationSheet(repository: repo),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'WORKOUT':
        return Icons.fitness_center_rounded;
      case 'NUTRITION':
        return Icons.restaurant_rounded;
      case 'CHECK_IN':
        return Icons.event_available_rounded;
      case 'ACTIVITY':
        return Icons.local_fire_department_rounded;
      case 'MEMBERSHIP':
        return Icons.card_membership_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toUpperCase()) {
      case 'WORKOUT':
        return AppColors.primaryRed;
      case 'NUTRITION':
        return AppColors.success;
      case 'CHECK_IN':
        return AppColors.gold;
      case 'ACTIVITY':
        return Colors.lightBlueAccent;
      case 'MEMBERSHIP':
        return Colors.orangeAccent;
      default:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final notifications = repository.notifications;
        final unreadCount = repository.unreadCount;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
          ),
          child: Column(
            children: [
              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: AppColors.primaryRed, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'ALPHA X UPDATES',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount NEW',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: () => repository.markAllAsRead(),
                        child: const Text(
                          'MARK ALL READ',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),

              // Notification List
              Expanded(
                child: repository.isLoading && notifications.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                    : notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.done_all_rounded, color: AppColors.textTertiary, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  'You\'re completely caught up!',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Daily coaching guidance and targets will appear here.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: notifications.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.borderSubtle, height: 1),
                            itemBuilder: (context, idx) {
                              final notif = notifications[idx];
                              final color = _colorForType(notif.type);

                              return Container(
                                color: notif.isRead ? Colors.transparent : AppColors.primaryRed.withOpacity(0.04),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: color.withOpacity(0.15),
                                    child: Icon(_iconForType(notif.type), color: color, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif.title,
                                          style: TextStyle(
                                            color: notif.isRead ? Colors.white70 : Colors.white,
                                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      if (!notif.isRead)
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryRed,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif.message,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              _timeAgo(notif.createdAt),
                                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                                            ),
                                            if (notif.source == 'AI_COACH') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.glowRed,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'AI COACH',
                                                  style: TextStyle(
                                                    color: AppColors.primaryRed,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    if (!notif.isRead) {
                                      repository.markAsRead(notif.id);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 60)}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
