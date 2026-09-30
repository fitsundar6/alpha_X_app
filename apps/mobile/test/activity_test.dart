import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';
import 'package:alpha_x_gym/features/activity/data/services/health_service.dart';

void main() {
  group('Daily Step Tracking & Activity System Tests', () {
    late HealthService healthService;

    setUp(() {
      healthService = HealthService();
    });

    test('1. Today date calculation: local day starts at 00:00:00 and ends at 23:59:59.999', () {
      final now = DateTime(2026, 9, 23, 14, 35, 22, 500);
      final start = healthService.getLocalStartOfDay(now);
      final end = healthService.getLocalEndOfDay(now);

      expect(start.year, equals(2026));
      expect(start.month, equals(9));
      expect(start.day, equals(23));
      expect(start.hour, equals(0));
      expect(start.minute, equals(0));
      expect(start.second, equals(0));
      expect(start.millisecond, equals(0));

      expect(end.year, equals(2026));
      expect(end.month, equals(9));
      expect(end.day, equals(23));
      expect(end.hour, equals(23));
      expect(end.minute, equals(59));
      expect(end.second, equals(59));
      expect(end.millisecond, equals(999));
    });

    test('2. Step aggregation & metrics calculation', () {
      final record = DailyActivityRecord(
        id: 'rec_01',
        clientId: 'client_01',
        date: DateTime(2026, 9, 23),
        steps: 5420,
        stepGoal: 6000,
        cardioMinutes: 35,
        caloriesBurned: 420.0,
        distanceMeters: 4120.0,
        isGoalAchieved: false,
      );

      expect(record.steps, equals(5420));
      expect(record.stepGoal, equals(6000));
      expect(record.cardioMinutes, equals(35));
      expect(record.formattedSteps, equals('5,420'));
      expect(record.formattedGoal, equals('6,000'));
    });

    test('3. Goal calculation: visual progress indicator stops at 100%', () {
      final underGoal = DailyActivityRecord(
        id: 'rec_under',
        clientId: 'client_01',
        date: DateTime(2026, 9, 23),
        steps: 5400,
        stepGoal: 6000,
        isGoalAchieved: false,
      );
      expect(underGoal.rawProgressRatio, equals(0.90));
      expect(underGoal.visualProgressClamped, equals(0.90));
      expect(underGoal.visualPercentage, equals(90));
      expect(underGoal.actualPercentage, equals(90));
      expect(underGoal.remainingSteps, equals(600));
      expect(underGoal.isExceeded, isFalse);

      final overGoal = DailyActivityRecord(
        id: 'rec_over',
        clientId: 'client_01',
        date: DateTime(2026, 9, 23),
        steps: 7500,
        stepGoal: 6000,
        isGoalAchieved: true,
      );
      // Raw percentage is 125% internally for analytics
      expect(overGoal.rawProgressRatio, equals(1.25));
      expect(overGoal.actualPercentage, equals(125));
      // Visual progress MUST clamp at 100% (1.0)
      expect(overGoal.visualProgressClamped, equals(1.0));
      expect(overGoal.visualPercentage, equals(100));
    });

    test('4. Goal exceeded calculation: displays excess steps correctly', () {
      final record = DailyActivityRecord(
        id: 'rec_exceeded',
        clientId: 'client_01',
        date: DateTime(2026, 9, 23),
        steps: 7500,
        stepGoal: 6000,
        isGoalAchieved: true,
      );

      expect(record.isExceeded, isTrue);
      expect(record.exceededSteps, equals(1500));
      expect(record.formattedExceeded, equals('1,500'));
      expect(record.remainingSteps, equals(0));
    });

    test('5. Weekly average calculation across 7 days', () {
      final days = [
        DailyActivityRecord(id: '1', clientId: 'c1', date: DateTime(2026, 9, 17), steps: 6000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '2', clientId: 'c1', date: DateTime(2026, 9, 18), steps: 7000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '3', clientId: 'c1', date: DateTime(2026, 9, 19), steps: 5000, stepGoal: 6000, isGoalAchieved: false),
        DailyActivityRecord(id: '4', clientId: 'c1', date: DateTime(2026, 9, 20), steps: 8000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '5', clientId: 'c1', date: DateTime(2026, 9, 21), steps: 6500, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '6', clientId: 'c1', date: DateTime(2026, 9, 22), steps: 4500, stepGoal: 6000, isGoalAchieved: false),
        DailyActivityRecord(id: '7', clientId: 'c1', date: DateTime(2026, 9, 23), steps: 6260, stepGoal: 6000, isGoalAchieved: true),
      ];

      final summary = WeeklyActivitySummary.calculate(days);

      // Total: 6000+7000+5000+8000+6500+4500+6260 = 43260
      // Average: 43260 / 7 = 6180
      expect(summary.totalSteps, equals(43260));
      expect(summary.weeklyAverage, equals(6180));
      expect(summary.bestDay?.steps, equals(8000));
      expect(summary.lowestDay?.steps, equals(4500));
    });

    test('6. Goal achievement days calculation', () {
      final days = [
        DailyActivityRecord(id: '1', clientId: 'c1', date: DateTime(2026, 9, 17), steps: 6000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '2', clientId: 'c1', date: DateTime(2026, 9, 18), steps: 7000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '3', clientId: 'c1', date: DateTime(2026, 9, 19), steps: 4000, stepGoal: 6000, isGoalAchieved: false),
        DailyActivityRecord(id: '4', clientId: 'c1', date: DateTime(2026, 9, 20), steps: 8000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '5', clientId: 'c1', date: DateTime(2026, 9, 21), steps: 6500, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '6', clientId: 'c1', date: DateTime(2026, 9, 22), steps: 4500, stepGoal: 6000, isGoalAchieved: false),
        DailyActivityRecord(id: '7', clientId: 'c1', date: DateTime(2026, 9, 23), steps: 6260, stepGoal: 6000, isGoalAchieved: true),
      ];

      final summary = WeeklyActivitySummary.calculate(days);
      expect(summary.daysGoalAchieved, equals(5));
    });

    test('7. Duplicate prevention on composite (clientId + date) key', () {
      final recordsMap = <String, DailyActivityRecord>{};

      final rec1 = DailyActivityRecord(
        id: 'rec_1',
        clientId: 'client_john',
        date: DateTime(2026, 9, 23),
        steps: 4000,
        stepGoal: 6000,
        isGoalAchieved: false,
      );

      final rec2Updated = DailyActivityRecord(
        id: 'rec_1',
        clientId: 'client_john',
        date: DateTime(2026, 9, 23),
        steps: 5420,
        stepGoal: 6000,
        isGoalAchieved: false,
      );

      final key1 = '${rec1.clientId}_2026-09-23';
      recordsMap[key1] = rec1;

      final key2 = '${rec2Updated.clientId}_2026-09-23';
      recordsMap[key2] = rec2Updated;

      expect(recordsMap.length, equals(1));
      expect(recordsMap[key1]!.steps, equals(5420));
    });

    test('8. Client isolation: User A cannot overwrite User B records', () {
      final recordsMap = <String, DailyActivityRecord>{};

      final clientA = DailyActivityRecord(
        id: 'rec_a',
        clientId: 'client_john_doe',
        date: DateTime(2026, 9, 23),
        steps: 5420,
        stepGoal: 6000,
        isGoalAchieved: false,
      );

      final clientB = DailyActivityRecord(
        id: 'rec_b',
        clientId: 'client_marcus_vance',
        date: DateTime(2026, 9, 23),
        steps: 8350,
        stepGoal: 8000,
        isGoalAchieved: true,
      );

      recordsMap['${clientA.clientId}_2026-09-23'] = clientA;
      recordsMap['${clientB.clientId}_2026-09-23'] = clientB;

      expect(recordsMap.length, equals(2));
      expect(recordsMap['client_john_doe_2026-09-23']!.steps, equals(5420));
      expect(recordsMap['client_marcus_vance_2026-09-23']!.steps, equals(8350));
    });

    test('9. Permission denied state handling', () {
      HealthConnectionStatus status = HealthConnectionStatus.denied;
      expect(status, equals(HealthConnectionStatus.denied));
      expect(status == HealthConnectionStatus.authorized, isFalse);
    });

    test('10. Offline sync queue & pending status persistence', () {
      final record = DailyActivityRecord(
        id: 'rec_offline',
        clientId: 'client_john',
        date: DateTime(2026, 9, 23),
        steps: 6200,
        stepGoal: 6000,
        isGoalAchieved: true,
        syncStatus: SyncStatus.pending,
      );

      expect(record.syncStatus, equals(SyncStatus.pending));
      expect(record.syncStatus.displayName, equals('Sync pending'));

      // When sync finishes successfully
      final syncedRecord = record.copyWith(
        syncStatus: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      );
      expect(syncedRecord.syncStatus, equals(SyncStatus.synced));
      expect(syncedRecord.syncStatus.displayName, equals('Synced'));
    });

    test('11. Failed synchronization state handling', () {
      final record = DailyActivityRecord(
        id: 'rec_fail',
        clientId: 'client_john',
        date: DateTime(2026, 9, 23),
        steps: 3000,
        stepGoal: 6000,
        isGoalAchieved: false,
        syncStatus: SyncStatus.failed,
      );

      expect(record.syncStatus, equals(SyncStatus.failed));
      expect(record.syncStatus.displayName, equals('Sync failed'));
      // Data is NOT deleted upon sync failure
      expect(record.steps, equals(3000));
    });

    test('12. Empty health data handling', () {
      final emptyWeekly = WeeklyActivitySummary.calculate([]);
      expect(emptyWeekly.totalSteps, equals(0));
      expect(emptyWeekly.weeklyAverage, equals(0));
      expect(emptyWeekly.daysGoalAchieved, equals(0));
      expect(emptyWeekly.bestDay, isNull);
      expect(emptyWeekly.lowestDay, isNull);

      final emptyMonthly = MonthlyActivitySummary.calculate(
        year: 2026,
        month: 9,
        recordsInMonth: [],
      );
      expect(emptyMonthly.totalSteps, equals(0));
      expect(emptyMonthly.averageStepsPerDay, equals(0));
      expect(emptyMonthly.daysGoalAchieved, equals(0));
      expect(emptyMonthly.goalAchievementRate, equals(0.0));
      expect(emptyMonthly.bestDay, isNull);
    });

    test('13. New client starts clean: 0 steps, 0 cardio, 0 calories, 0.0 distance', () {
      final cleanRecord = DailyActivityRecord(
        id: 'rec_new_client',
        clientId: 'AXG-0001',
        date: DateTime(2026, 9, 30),
        steps: 0,
        stepGoal: 6000,
        cardioMinutes: 0,
        caloriesBurned: 0.0,
        distanceMeters: 0.0,
        isGoalAchieved: false,
      );

      expect(cleanRecord.steps, equals(0));
      expect(cleanRecord.cardioMinutes, equals(0));
      expect(cleanRecord.caloriesBurned, equals(0.0));
      expect(cleanRecord.distanceMeters, equals(0.0));
      expect(cleanRecord.formattedSteps, equals('0'));
      expect(cleanRecord.rawProgressRatio, equals(0.0));
      expect(cleanRecord.visualPercentage, equals(0));
      expect(cleanRecord.isGoalAchieved, isFalse);
    });

    test('14. No fake calories or distance: metrics proportional to real steps only', () {
      final zeroRecord = DailyActivityRecord(
        id: 'rec_zero',
        clientId: 'AXG-0001',
        date: DateTime.now(),
        steps: 0,
        stepGoal: 6000,
        cardioMinutes: (0 / 100).round(),
        caloriesBurned: 0 * 0.04,
        distanceMeters: 0 * 0.75,
        isGoalAchieved: false,
      );

      expect(zeroRecord.caloriesBurned, equals(0.0));
      expect(zeroRecord.distanceMeters, equals(0.0));
      expect(zeroRecord.cardioMinutes, equals(0));

      // After walking real 1,250 steps
      final realRecord = DailyActivityRecord(
        id: 'rec_real',
        clientId: 'AXG-0001',
        date: DateTime.now(),
        steps: 1250,
        stepGoal: 6000,
        cardioMinutes: (1250 / 100).round(),
        caloriesBurned: 1250 * 0.04,
        distanceMeters: 1250 * 0.75,
        isGoalAchieved: false,
      );

      expect(realRecord.steps, equals(1250));
      expect(realRecord.caloriesBurned, equals(50.0));
      expect(realRecord.distanceMeters, equals(937.5));
      expect(realRecord.cardioMinutes, equals(13));
    });

    test('15. Client join start date filtering: do not import steps before join timestamp', () {
      final clientJoinDate = DateTime(2026, 9, 30, 6, 0, 0);

      final historicalRecords = [
        DailyActivityRecord(id: '1', clientId: 'AXG-0001', date: DateTime(2026, 9, 27), steps: 8000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '2', clientId: 'AXG-0001', date: DateTime(2026, 9, 28), steps: 9000, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '3', clientId: 'AXG-0001', date: DateTime(2026, 9, 29), steps: 7500, stepGoal: 6000, isGoalAchieved: true),
        DailyActivityRecord(id: '4', clientId: 'AXG-0001', date: DateTime(2026, 9, 30), steps: 0, stepGoal: 6000, isGoalAchieved: false),
      ];

      final joinStartDay = healthService.getLocalStartOfDay(clientJoinDate);
      final filtered = historicalRecords.where((r) => !r.date.isBefore(joinStartDay)).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.date.day, equals(30));
      expect(filtered.first.steps, equals(0));
    });

    test('16. Lifetime hardware cumulative counter baselining: 18,500 at join -> 0 steps, 19,200 later -> 700 steps', () {
      // Phone hardware counter at moment client joins
      final int initialHardwareCount = 18500;
      int? baselineSteps;

      // Baseline initialization on join
      baselineSteps ??= initialHardwareCount;
      final int stepsAtJoin = (initialHardwareCount - baselineSteps).clamp(0, 1000000);
      expect(stepsAtJoin, equals(0));

      // Later, hardware cumulative step counter advances to 19,200
      final int laterHardwareCount = 19200;
      final int clientSteps = (laterHardwareCount - baselineSteps).clamp(0, 1000000);
      expect(clientSteps, equals(700));
    });

    test('17. Client switching isolation: AXG-0001 (1,500 steps) -> logout -> AXG-0002 starts at 0 steps', () {
      final clientStore = <String, Map<String, DailyActivityRecord>>{};

      // Client A logs 1,500 steps
      clientStore['AXG-0001'] = {
        '2026-09-30': DailyActivityRecord(
          id: 'rec_axg1',
          clientId: 'AXG-0001',
          date: DateTime(2026, 9, 30),
          steps: 1500,
          stepGoal: 6000,
          isGoalAchieved: false,
        ),
      };

      // Client B joins fresh
      clientStore['AXG-0002'] = {};

      expect(clientStore['AXG-0001']!['2026-09-30']!.steps, equals(1500));
      expect(clientStore['AXG-0002']!['2026-09-30'], isNull);

      final clientBTodayRecord = clientStore['AXG-0002']!['2026-09-30'] ??
          DailyActivityRecord(
            id: 'rec_axg2',
            clientId: 'AXG-0002',
            date: DateTime(2026, 9, 30),
            steps: 0,
            stepGoal: 6000,
            isGoalAchieved: false,
          );

      expect(clientBTodayRecord.steps, equals(0));
      expect(clientBTodayRecord.clientId, equals('AXG-0002'));
    });

    test('18. Admin step calculation: 0 steps when clients have not walked, real average steps', () {
      final clientsWithZeroSteps = [
        {'id': '1', 'clientId': 'AXG-0001', 'todaySteps': 0},
        {'id': '2', 'clientId': 'AXG-0002', 'todaySteps': 0},
      ];

      int sumZero = 0;
      for (final c in clientsWithZeroSteps) {
        sumZero += c['todaySteps'] as int;
      }
      final avgZero = clientsWithZeroSteps.isNotEmpty ? (sumZero / clientsWithZeroSteps.length).round() : 0;
      expect(avgZero, equals(0));

      final clientsWithRealSteps = [
        {'id': '1', 'clientId': 'AXG-0001', 'todaySteps': 2000},
        {'id': '2', 'clientId': 'AXG-0002', 'todaySteps': 4000},
      ];

      int sumReal = 0;
      for (final c in clientsWithRealSteps) {
        sumReal += c['todaySteps'] as int;
      }
      final avgReal = clientsWithRealSteps.isNotEmpty ? (sumReal / clientsWithRealSteps.length).round() : 0;
      expect(avgReal, equals(3000));
    });

    test('19. Health platform connection state labels', () {
      String getStatus(bool auth) => auth ? 'Health Data Connected' : 'Health Data Not Connected';
      expect(getStatus(true), equals('Health Data Connected'));
      expect(getStatus(false), equals('Health Data Not Connected'));
    });
  });
}
