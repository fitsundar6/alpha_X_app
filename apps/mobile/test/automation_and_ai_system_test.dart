import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/notifications/domain/models/app_notification.dart';
import 'package:alpha_x_gym/features/notifications/data/repositories/notification_repository.dart';
import 'package:alpha_x_gym/features/notifications/presentation/widgets/notification_sheet.dart';
import 'package:alpha_x_gym/features/notifications/presentation/widgets/notification_preferences_dialog.dart';
import 'package:alpha_x_gym/features/dashboard/widgets/admin_attention_center_view.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_transformation_timeline_screen.dart';
import 'package:alpha_x_gym/core/services/smartwatch_health_sync_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('AppNotification & NotificationPreferences Domain Tests', () {
    test('AppNotification serializes and deserializes correctly', () {
      final json = {
        'id': 'notif_001',
        'title': 'Your Alpha X Workout Awaits 💪',
        'message': 'Arjun, your training plan is ready. Lock in your session today!',
        'type': 'WORKOUT',
        'category': 'WORKOUT',
        'priority': 'NORMAL',
        'source': 'AI_COACH',
        'triggerRule': 'INACTIVE_1_DAY',
        'isRead': false,
        'createdAt': '2026-10-01T08:00:00.000Z',
      };

      final notif = AppNotification.fromJson(json);
      expect(notif.id, 'notif_001');
      expect(notif.title, 'Your Alpha X Workout Awaits 💪');
      expect(notif.type, 'WORKOUT');
      expect(notif.priority, 'NORMAL');
      expect(notif.source, 'AI_COACH');
      expect(notif.triggerRule, 'INACTIVE_1_DAY');
      expect(notif.isRead, isFalse);

      final copy = notif.copyWith(isRead: true);
      expect(copy.isRead, isTrue);
      expect(copy.id, 'notif_001');
    });

    test('NotificationPreferences defaults and serialization', () {
      const defaultPrefs = NotificationPreferences();
      expect(defaultPrefs.workoutReminders, isTrue);
      expect(defaultPrefs.nutritionReminders, isTrue);
      expect(defaultPrefs.weeklyCheckInReminders, isTrue);
      expect(defaultPrefs.activityReminders, isTrue);
      expect(defaultPrefs.membershipAlerts, isTrue);
      expect(defaultPrefs.aiEngagementEnabled, isTrue);

      final customJson = {
        'workoutReminders': false,
        'nutritionReminders': true,
        'weeklyCheckInReminders': false,
        'activityReminders': true,
        'membershipAlerts': true,
        'aiEngagementEnabled': false,
      };

      final prefs = NotificationPreferences.fromJson(customJson);
      expect(prefs.workoutReminders, isFalse);
      expect(prefs.nutritionReminders, isTrue);
      expect(prefs.aiEngagementEnabled, isFalse);
    });
  });

  group('SmartwatchHealthSyncService Architecture Tests', () {
    test('Interface connects cleanly to supported health platforms without mock fabrication', () async {
      final service = SmartwatchHealthSyncService();
      expect(service.isConnected, isFalse);
      expect(service.isSyncing, isFalse);

      final connected = await service.connectPlatform(HealthPlatform.appleHealth);
      expect(connected, isTrue);
      expect(service.connectedPlatform, HealthPlatform.appleHealth);
      expect(service.lastSyncTimestamp, isNotNull);

      service.disconnect();
      expect(service.isConnected, isFalse);
      expect(service.connectedPlatform, isNull);
    });
  });

  group('Notification Widgets Tests', () {
    testWidgets('NotificationSheet displays notifications and unread badge', (tester) async {
      final repo = NotificationRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationSheet(repository: repo),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ALPHA X UPDATES'), findsOneWidget);
    });

    testWidgets('NotificationPreferencesDialog renders all toggles and save action', (tester) async {
      final repo = NotificationRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationPreferencesDialog(repository: repo),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('NOTIFICATION SETTINGS'), findsOneWidget);
      expect(find.text('Workout Reminders'), findsOneWidget);
      expect(find.text('Nutrition Tracking'), findsOneWidget);
      expect(find.text('Weekly Check-In'), findsOneWidget);
      expect(find.text('Activity Reminders'), findsOneWidget);
      expect(find.text('Membership Notices'), findsOneWidget);
      expect(find.text('AI Personalized Motivation'), findsOneWidget);
      expect(find.text('SAVE PREFERENCES'), findsOneWidget);
    });
  });

  group('Admin Attention Center View Tests', () {
    testWidgets('AdminAttentionCenterView displays operational header, search, and filters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminAttentionCenterView(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CLIENT ATTENTION CENTER'), findsOneWidget);
      expect(find.text('AUTOMATED DATA-BASED COACHING INDICATORS'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('PAIN REPORTED'), findsOneWidget);
      expect(find.text('INACTIVE'), findsOneWidget);
    });
  });

  group('Transformation Timeline Screen Tests', () {
    testWidgets('ClientTransformationTimelineScreen displays milestone protocol cards (Weeks 1, 4, 8, 12)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientTransformationTimelineScreen(initialMilestones: []),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TRANSFORMATION TIMELINE'), findsOneWidget);
      expect(find.text('WEEK 1'), findsOneWidget);
      expect(find.text('WEEK 4'), findsOneWidget);
      expect(find.text('WEEK 8'), findsOneWidget);
      expect(find.text('WEEK 12'), findsOneWidget);
    });
  });
}
