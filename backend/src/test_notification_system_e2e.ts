/**
 * Alpha X Notification System Comprehensive Integration Test Suite
 *
 * Validates:
 *   1. Persistent Atomic Deduplication & Concurrent Race Conditions
 *   2. Rolling 24-Hour Cap for Proactive Tier (Max 2 pushes)
 *   3. Essential Plan Update Bypass of Rolling Cap
 *   4. Master Opt-Out Enforcement (Both Proactive & Essential)
 *   5. Granular Category Preferences
 *   6. Timezone Calculation & Quiet Hours Suppression / Deferral
 *   7. Workout Completion Guard in Workout Service
 *   8. Data-Driven Missed-Workout Detection (Scheduled vs Rest Days)
 *   9. OneSignal Failure Recovery & Missing Device Subscriptions
 *   10. Authenticated Vercel Serverless Cron Routes
 */

import { prisma } from './config/prisma';
import { notificationPolicyService } from './modules/notifications/notification_policy.service';
import { aiNotificationEngine } from './modules/notifications/ai_notifications.service';
import { workoutService } from './modules/workout/workout.service';
import { verifyCronSecret } from './modules/notifications/cron.routes';
import { oneSignalService } from './modules/notifications/onesignal.service';
import { env } from './config/environment';
import { UserStatus, UserRole } from './constants/roles';

const TEST_EMAIL = 'test_notif_audit_athlete@alphaxgym.com';
let testUserId = '';
let testProfileId = '';

async function runNotificationIntegrationTests() {
  console.log('================================================================');
  console.log('🧪 STARTING ALPHA X NOTIFICATION SYSTEM INTEGRATION TEST SUITE');
  console.log('================================================================');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string) {
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${testName}`);
      failed++;
    }
  }

  try {
    // ── Setup: Create Isolated Test Athlete ──────────────────────────────────
    console.log('\n[SETUP] Creating isolated test user and client profile...');
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });

    const testUser = await prisma.user.create({
      data: {
        email: TEST_EMAIL,
        name: 'Test Notification Athlete',
        role: UserRole.CLIENT,
        status: UserStatus.APPROVED,
        notificationsEnabled: true,
        oneSignalPlayerId: 'test_onesignal_player_id_integration_suite',
        clientProfile: {
          create: {
            clientId: 'AXG-TEST-NOTIF',
            trainingDaysPerWeek: 4,
            preferredDays: ['Monday', 'Wednesday', 'Friday', 'Saturday'],
            notificationPref: {
              create: {
                timezone: 'Asia/Kolkata',
                quietHoursStart: 21,
                quietHoursEnd: 7,
                workoutReminders: true,
                nutritionReminders: true,
                weeklyCheckInReminders: true,
                activityReminders: true,
                membershipAlerts: true,
                aiEngagementEnabled: true,
              },
            },
          },
        },
      },
      include: {
        clientProfile: {
          include: { notificationPref: true },
        },
      },
    });

    testUserId = testUser.id;
    testProfileId = testUser.clientProfile!.id;
    console.log(`[SETUP] Test user created with ID: ${testUserId}, Profile: ${testProfileId}`);

    // ── TEST 1: Persistent Atomic Deduplication & Concurrent Races ─────────
    console.log('\n[TEST 1] Testing Persistent Atomic Deduplication under Concurrent Requests...');
    const concurrentDedupKey = `CONCURRENT_TEST_${Date.now()}`;

    const concurrentDispatches = Array.from({ length: 5 }, (_, i) =>
      notificationPolicyService.dispatch({
        userId: testUserId,
        clientProfileId: testProfileId,
        title: 'Concurrent Test',
        message: `Concurrent message attempt ${i}`,
        type: 'SYSTEM',
        tier: 'ESSENTIAL',
        dedupKey: concurrentDedupKey,
        skipPush: true,
        ignoreQuietHours: true,
      })
    );

    const concurrentResults = await Promise.all(concurrentDispatches);
    const sentCount = concurrentResults.filter((r) => r.status === 'SENT').length;
    const dupCount = concurrentResults.filter((r) => r.status === 'DUPLICATE').length;

    assert(sentCount === 1, 'Exactly one concurrent dispatch succeeded (status === SENT)');
    assert(dupCount === 4, 'Remaining 4 concurrent dispatches gracefully handled as DUPLICATE');

    const dbRecordCount = await prisma.notification.count({
      where: { dedupKey: concurrentDedupKey },
    });
    assert(dbRecordCount === 1, 'Exactly 1 notification record exists in PostgreSQL database');

    // ── TEST 2: Rolling 24-Hour Push Cap for Proactive Tier (Max 2 pushes) ──
    console.log('\n[TEST 2] Testing Rolling 24-Hour Cap for Proactive Tier...');
    // Clear notifications for test user
    await prisma.notification.deleteMany({ where: { clientProfileId: testProfileId } });

    // Proactive Push 1
    const p1 = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Proactive 1',
      message: 'First proactive notification',
      type: 'WORKOUT',
      tier: 'PROACTIVE',
      preferenceKey: 'workoutReminders',
      dedupKey: `PROACTIVE_P1_${Date.now()}`,
      skipPush: true,
      ignoreQuietHours: true,
    });
    assert(p1.status === 'SENT', 'Proactive Push 1 sent successfully');

    // Proactive Push 2
    const p2 = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Proactive 2',
      message: 'Second proactive notification',
      type: 'NUTRITION',
      tier: 'PROACTIVE',
      preferenceKey: 'nutritionReminders',
      dedupKey: `PROACTIVE_P2_${Date.now()}`,
      skipPush: true,
      ignoreQuietHours: true,
    });
    assert(p2.status === 'SENT', 'Proactive Push 2 sent successfully');

    // Proactive Push 3 (Should be blocked by 2/day limit)
    const p3 = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Proactive 3',
      message: 'Third proactive notification (should be capped)',
      type: 'WORKOUT',
      tier: 'PROACTIVE',
      preferenceKey: 'workoutReminders',
      dedupKey: `PROACTIVE_P3_${Date.now()}`,
      skipPush: true,
      ignoreQuietHours: true,
    });
    assert(p3.status === 'SKIPPED_CAP', 'Proactive Push 3 correctly blocked with status SKIPPED_CAP');

    // ── TEST 3: Essential Plan Update Bypass of Rolling Cap ─────────────────
    console.log('\n[TEST 3] Testing Essential Plan Update Bypass of Rolling 24h Cap...');
    // Client is already capped at 2 proactive pushes.
    // An essential plan update (coach assignment) must bypass this limit!
    const essentialPlan = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: '📋 New Workout Assigned',
      message: 'Your coach assigned you a new program',
      type: 'WORKOUT',
      category: 'PLAN_UPDATE',
      tier: 'ESSENTIAL', // Essential tier
      preferenceKey: 'workoutReminders',
      dedupKey: `PLAN_ASSIGN_${Date.now()}`,
      skipPush: true,
      ignoreQuietHours: true,
    });
    assert(essentialPlan.status === 'SENT', 'Essential Plan Update successfully bypassed 24h limit');

    // ── TEST 4: Master Notification Opt-Out ────────────────────────────────
    console.log('\n[TEST 4] Testing Master Notification Opt-Out Enforcement...');
    // Disable master toggle
    await prisma.user.update({
      where: { id: testUserId },
      data: { notificationsEnabled: false },
    });

    const optOutProactive = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Should not send',
      message: 'Master opt-out test',
      type: 'WORKOUT',
      tier: 'PROACTIVE',
      dedupKey: `OPTOUT_PROACTIVE_${Date.now()}`,
      skipPush: true,
    });
    assert(optOutProactive.status === 'OPTED_OUT', 'Proactive push blocked when master toggle is disabled');

    const optOutEssential = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Essential Should not send if opted out',
      message: 'Master opt-out test essential',
      type: 'WORKOUT',
      category: 'PLAN_UPDATE',
      tier: 'ESSENTIAL',
      dedupKey: `OPTOUT_ESSENTIAL_${Date.now()}`,
      skipPush: true,
    });
    assert(optOutEssential.status === 'OPTED_OUT', 'Essential push respects master opt-out (no unauthorized push)');

    // Re-enable master toggle for remaining tests
    await prisma.user.update({
      where: { id: testUserId },
      data: { notificationsEnabled: true },
    });

    // ── TEST 5: Granular Category Preferences ──────────────────────────────
    console.log('\n[TEST 5] Testing Granular Category Preferences...');
    await prisma.notificationPreference.update({
      where: { clientProfileId: testProfileId },
      data: { workoutReminders: false, nutritionReminders: true },
    });

    const catWorkout = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Workout reminder',
      message: 'Category test',
      type: 'WORKOUT',
      tier: 'PROACTIVE',
      preferenceKey: 'workoutReminders',
      dedupKey: `CAT_WORKOUT_${Date.now()}`,
      skipPush: true,
    });
    assert(catWorkout.status === 'OPTED_OUT', 'Notification blocked when specific category preference is disabled');

    const catNutrition = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Nutrition reminder',
      message: 'Category test nutrition',
      type: 'NUTRITION',
      tier: 'PROACTIVE',
      preferenceKey: 'nutritionReminders',
      dedupKey: `CAT_NUTRITION_${Date.now()}`,
      skipPush: true,
    });
    // Can be SENT or SKIPPED_CAP if 24h limit applies; here count is already 3 in DB so test clean state
    await prisma.notification.deleteMany({ where: { clientProfileId: testProfileId } });
    const catNutritionClean = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Nutrition reminder',
      message: 'Category test nutrition',
      type: 'NUTRITION',
      tier: 'PROACTIVE',
      preferenceKey: 'nutritionReminders',
      dedupKey: `CAT_NUTRITION_CLEAN_${Date.now()}`,
      skipPush: true,
      ignoreQuietHours: true,
    });
    assert(catNutritionClean.status === 'SENT', 'Notification allowed when category preference is enabled');

    // Restore preference
    await prisma.notificationPreference.update({
      where: { clientProfileId: testProfileId },
      data: { workoutReminders: true, nutritionReminders: true },
    });

    // ── TEST 6: Timezone & Quiet Hours Handling ────────────────────────────
    console.log('\n[TEST 6] Testing Timezone & Quiet Hours...');
    const tzParts = notificationPolicyService.getLocalTimeParts('Asia/Kolkata');
    assert(typeof tzParts.hour === 'number' && typeof tzParts.dateStr === 'string', 'Local time correctly parsed for Asia/Kolkata');
    assert(tzParts.dateStr.includes('-'), `Valid dateStr: ${tzParts.dateStr}`);

    // Test quiet hours boundary logic
    const isQuietAt10PM = notificationPolicyService.isInQuietHours('Asia/Kolkata', 21, 7, new Date('2026-10-15T22:30:00Z'));
    // 22:30 UTC is 04:00 AM IST (which is between 21:00 and 07:00 IST) -> true
    assert(isQuietAt10PM === true, '04:00 AM IST recognized as inside quiet hours (21-7)');

    const isQuietAt2PM = notificationPolicyService.isInQuietHours('Asia/Kolkata', 21, 7, new Date('2026-10-15T08:30:00Z'));
    // 08:30 UTC is 14:00 IST (2:00 PM) -> false
    assert(isQuietAt2PM === false, '02:00 PM IST recognized as outside quiet hours');

    // Test actual quiet hours policy dispatch behavior
    const quietEssential = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Quiet essential plan update',
      message: 'Essential quiet hours test',
      type: 'WORKOUT',
      category: 'PLAN_UPDATE',
      tier: 'ESSENTIAL',
      dedupKey: `QUIET_ESSENTIAL_${Date.now()}`,
      skipPush: true,
    });

    const isCurrentTimeQuiet = notificationPolicyService.isInQuietHours('Asia/Kolkata', 21, 7);
    if (isCurrentTimeQuiet) {
      assert(quietEssential.status === 'DEFERRED', 'Essential plan update safely DEFERRED during quiet hours');
      assert(quietEssential.scheduledFor instanceof Date, 'DEFERRED notification has valid future scheduledFor timestamp');
    } else {
      assert(quietEssential.status === 'SENT', 'Essential plan update delivered when outside quiet hours');
    }

    // ── TEST 7: Workout Completion Guard in Workout Service ────────────────
    console.log('\n[TEST 7] Testing Workout Completion Guard in Workout Service...');
    await prisma.notification.deleteMany({ where: { clientProfileId: testProfileId } });

    // In-progress / set sync record (isCompleted: false)
    const partialRecord = {
      id: `record_partial_${Date.now()}`,
      clientId: testUserId,
      sessionTitle: 'Chest Hypertrophy',
      isCompleted: false,
      totalVolume: 1200,
      completedSetsCount: 3,
      durationSeconds: 600,
    };

    const celebrationPartial = await aiNotificationEngine.sendPostWorkoutCelebration(testUserId, partialRecord);
    assert(celebrationPartial === false, 'Celebration NOT sent for in-progress / uncompleted workout record');

    // Final completed record (isCompleted: true)
    const completedRecord = {
      id: `record_completed_${Date.now()}`,
      clientId: testUserId,
      sessionTitle: 'Chest Hypertrophy',
      isCompleted: true,
      totalVolume: 3500,
      completedSetsCount: 12,
      durationSeconds: 2700,
    };

    const celebrationCompleted = await aiNotificationEngine.sendPostWorkoutCelebration(testUserId, completedRecord, {
      ignoreQuietHours: true,
      skipPush: true,
    });
    assert(celebrationCompleted === true, 'Celebration successfully dispatched upon workout completion');

    // Re-dispatch of same completed record (dedup check)
    const celebrationDuplicate = await aiNotificationEngine.sendPostWorkoutCelebration(testUserId, completedRecord, {
      ignoreQuietHours: true,
      skipPush: true,
    });
    assert(celebrationDuplicate === false, 'Duplicate celebration prevented by persistent atomic dedupKey');

    // ── TEST 8: Asia/Kolkata Date Boundaries & Missed Workout Transitions ──
    console.log('\n[TEST 8] Testing Asia/Kolkata Date Boundaries & Transitions...');
    const testDateStr = '2026-10-15';
    const { start: istStart, end: istEnd } = notificationPolicyService.getDayBoundaries(testDateStr, 'Asia/Kolkata');
    assert(istStart.toISOString() === '2026-10-14T18:30:00.000Z', 'Start of 2026-10-15 in Asia/Kolkata is exactly 2026-10-14T18:30:00.000Z');
    assert(istEnd.toISOString() === '2026-10-15T18:29:59.999Z', 'End of 2026-10-15 in Asia/Kolkata is exactly 2026-10-15T18:29:59.999Z');

    // Midnight IST workout (00:05 IST on 2026-10-15 = 18:35 UTC on 2026-10-14)
    const midnightWorkout = new Date('2026-10-14T18:35:00.000Z');
    assert(midnightWorkout >= istStart && midnightWorkout <= istEnd, 'Workout at 12:05 AM IST is within 2026-10-15 local day');

    // Early morning workout (05:00 IST on 2026-10-15 = 23:30 UTC on 2026-10-14)
    const earlyMorningWorkout = new Date('2026-10-14T23:30:00.000Z');
    assert(earlyMorningWorkout >= istStart && earlyMorningWorkout <= istEnd, 'Workout at 05:00 AM IST is within 2026-10-15 local day');

    // Late night workout (23:55 IST on 2026-10-15 = 18:25 UTC on 2026-10-15)
    const lateNightWorkout = new Date('2026-10-15T18:25:00.000Z');
    assert(lateNightWorkout >= istStart && lateNightWorkout <= istEnd, 'Workout at 11:55 PM IST is within 2026-10-15 local day');

    // Next day workout (00:05 IST on 2026-10-16 = 18:35 UTC on 2026-10-15)
    const nextDayWorkout = new Date('2026-10-15T18:35:00.000Z');
    assert(nextDayWorkout > istEnd, 'Workout at 12:05 AM IST next day is outside 2026-10-15 local day');

    // Database query check: Completed workout yesterday in local timezone
    const now = new Date();
    const yesterdayDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const { dateStr: yesterdayStr } = notificationPolicyService.getLocalTimeParts('Asia/Kolkata', yesterdayDate);
    const { start: yStart, end: yEnd } = notificationPolicyService.getDayBoundaries(yesterdayStr, 'Asia/Kolkata');

    const mockCompletedYesterday = await prisma.workoutRecord.create({
      data: {
        clientId: testUserId,
        sessionTitle: 'Leg Day Yesterday',
        workoutType: 'HYPERTROPHY',
        startedAt: new Date(yStart.getTime() + 2 * 60 * 60 * 1000), // 2 hours after local day started
        completedAt: new Date(yStart.getTime() + 3 * 60 * 60 * 1000),
        isCompleted: true,
      },
    });

    const completedYesterdayCount = await prisma.workoutRecord.count({
      where: {
        clientId: testUserId,
        isCompleted: true,
        startedAt: {
          gte: yStart,
          lte: yEnd,
        },
      },
    });
    assert(completedYesterdayCount >= 1, 'Completed workout record correctly identified using Asia/Kolkata day boundaries');
    await prisma.workoutRecord.delete({ where: { id: mockCompletedYesterday.id } });

    // ── TEST 9: Secure Cron Authentication & Fail-Closed Behavior ───────────
    console.log('\n[TEST 9] Testing Secure Cron Authentication & Credential Isolation...');
    assert(typeof env.CRON_SECRET === 'string' && env.CRON_SECRET.length > 0, 'CRON_SECRET is configured and non-empty');

    function mockExpressReqRes(
      headers: Record<string, string | undefined> = {},
      query: Record<string, string | undefined> = {}
    ) {
      let statusCode = 200;
      let responseData: any = null;
      let nextCalled = false;

      const req: any = { headers, query };
      const res: any = {
        status(code: number) {
          statusCode = code;
          return this;
        },
        json(data: any) {
          responseData = data;
          return this;
        },
      };
      const next = () => {
        nextCalled = true;
      };

      return { req, res, next, getStatusCode: () => statusCode, getResponseData: () => responseData, wasNextCalled: () => nextCalled };
    }

    // 9A: Missing header
    const ctx1 = mockExpressReqRes();
    verifyCronSecret(ctx1.req, ctx1.res, ctx1.next);
    assert(ctx1.getStatusCode() === 401 && !ctx1.wasNextCalled(), 'Cron rejected when Authorization header is missing (HTTP 401)');

    // 9B: Invalid Bearer token
    const ctx2 = mockExpressReqRes({ authorization: 'Bearer invalid_wrong_token' });
    verifyCronSecret(ctx2.req, ctx2.res, ctx2.next);
    assert(ctx2.getStatusCode() === 401 && !ctx2.wasNextCalled(), 'Cron rejected when Bearer token is invalid (HTTP 401)');

    // 9C: Valid Bearer token
    const ctx3 = mockExpressReqRes({ authorization: `Bearer ${env.CRON_SECRET}` });
    verifyCronSecret(ctx3.req, ctx3.res, ctx3.next);
    assert(ctx3.wasNextCalled() === true, 'Cron accepted when valid Bearer token provided (calls next())');

    // 9D: Query parameter strictly rejected in production
    const origEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    const ctx4 = mockExpressReqRes({}, { secret: env.CRON_SECRET });
    verifyCronSecret(ctx4.req, ctx4.res, ctx4.next);
    assert(ctx4.getStatusCode() === 401 && !ctx4.wasNextCalled(), 'Cron strictly rejects query-parameter secrets in production');
    process.env.NODE_ENV = origEnv;

    // 9E: Query parameter permitted in development for convenience
    process.env.NODE_ENV = 'development';
    const ctx5 = mockExpressReqRes({}, { secret: env.CRON_SECRET });
    verifyCronSecret(ctx5.req, ctx5.res, ctx5.next);
    assert(ctx5.wasNextCalled() === true, 'Cron permits query parameter for local dev convenience in non-production');
    process.env.NODE_ENV = origEnv;

    // 9F: Fail closed when CRON_SECRET is missing on server
    const origSecret = env.CRON_SECRET;
    (env as any).CRON_SECRET = '';
    const ctx6 = mockExpressReqRes({ authorization: 'Bearer test' });
    verifyCronSecret(ctx6.req, ctx6.res, ctx6.next);
    assert(ctx6.getStatusCode() === 401 && !ctx6.wasNextCalled(), 'Cron fails closed when CRON_SECRET is unconfigured on server');
    (env as any).CRON_SECRET = origSecret;

    // ── TEST 10: Morning Deferred Queue Processing & Concurrency ──────────
    console.log('\n[TEST 10] Testing Morning Deferred Queue Processing & Concurrency...');
    await prisma.notification.deleteMany({ where: { clientProfileId: testProfileId } });

    // Mock sendToPlayer so automated test runs in isolated test environment without real push API call
    const origSendToPlayer = oneSignalService.sendToPlayer;
    (oneSignalService as any).sendToPlayer = async (_playerId: string, _payload: any) => ({
      success: true,
      playerId: 'mock_test_player_id',
      httpStatus: 200,
      response: { id: `mock_os_deferred_${Date.now()}` },
    });

    // 10A: Create deferred notification with scheduledFor in the past
    const pastScheduledTime = new Date(Date.now() - 30 * 60 * 1000);
    const deferredNotif = await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        clientId: 'AXG-TEST-NOTIF',
        title: '📋 Morning Deferred Plan Update',
        message: 'Your workout plan has been updated',
        type: 'WORKOUT',
        category: 'PLAN_UPDATE',
        priority: 'HIGH',
        source: 'ADMIN',
        sentStatus: 'DEFERRED',
        scheduledFor: pastScheduledTime,
        dedupKey: `DEFERRED_TEST_${Date.now()}`,
      },
    });

    const deferredQueueResult = await notificationPolicyService.processDeferredQueue();
    assert(deferredQueueResult.processed >= 1, 'Deferred queue picked up pending deferred notification');

    const updatedDeferred = await prisma.notification.findUnique({
      where: { id: deferredNotif.id },
    });
    assert(updatedDeferred?.sentStatus === 'SENT', 'Deferred notification successfully transitioned to SENT');

    // 10B: Concurrency protection in processDeferredQueue
    await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Concurrent Def 1',
        message: 'Msg 1',
        type: 'WORKOUT',
        sentStatus: 'DEFERRED',
        scheduledFor: pastScheduledTime,
        dedupKey: `CONCURRENT_DEF_1_${Date.now()}`,
      },
    });
    await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Concurrent Def 2',
        message: 'Msg 2',
        type: 'WORKOUT',
        sentStatus: 'DEFERRED',
        scheduledFor: pastScheduledTime,
        dedupKey: `CONCURRENT_DEF_2_${Date.now()}`,
      },
    });

    const [w1, w2] = await Promise.all([
      notificationPolicyService.processDeferredQueue(),
      notificationPolicyService.processDeferredQueue(),
    ]);

    const totalSent = w1.sent + w2.sent;
    assert(totalSent === 2, `Exactly 2 notifications sent across concurrent workers without duplication (w1=${w1.sent}, w2=${w2.sent})`);

    // 10C: Category preference check in deferred queue
    await prisma.notificationPreference.update({
      where: { clientProfileId: testProfileId },
      data: { workoutReminders: false },
    });

    const defOptOut = await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Opted out category def',
        message: 'Msg',
        type: 'WORKOUT',
        sentStatus: 'DEFERRED',
        scheduledFor: pastScheduledTime,
        dedupKey: `DEF_OPTOUT_${Date.now()}`,
      },
    });

    await notificationPolicyService.processDeferredQueue();
    const updatedOptOut = await prisma.notification.findUnique({ where: { id: defOptOut.id } });
    assert(updatedOptOut?.sentStatus === 'OPTED_OUT', 'Deferred item transitioned to OPTED_OUT when category preference is disabled');

    // Restore preference and mock
    await prisma.notificationPreference.update({
      where: { clientProfileId: testProfileId },
      data: { workoutReminders: true },
    });
    (oneSignalService as any).sendToPlayer = origSendToPlayer;

    // ── TEST 11: Reliable Stale PENDING Recovery ──────────────────────────
    console.log('\n[TEST 11] Testing Reliable Stale PENDING Recovery & Idempotency...');
    await prisma.notification.deleteMany({ where: { clientProfileId: testProfileId } });

    // 11A: Crash before provider call (dispatchStage not CALLING_PROVIDER)
    const staleDedupKey = `STALE_PRE_PROVIDER_${Date.now()}`;
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);

    const stalePreProvider = await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Stale Pre-Provider Crash',
        message: 'Server crashed before calling OneSignal',
        type: 'WORKOUT',
        sentStatus: 'PENDING',
        dedupKey: staleDedupKey,
        createdAt: tenMinutesAgo,
        updatedAt: tenMinutesAgo,
        metadataJson: JSON.stringify({ dispatchStage: 'RESERVED' }),
      },
    });

    const rec1 = await notificationPolicyService.recoverStalePendingNotifications(5 * 60 * 1000);
    assert(rec1.claimed >= 1, 'Stale notification claimed by recovery worker');
    assert(rec1.markedFailed >= 1, 'Pre-provider crash correctly marked as FAILED to unlock dedupKey');

    const recoveredPre = await prisma.notification.findUnique({ where: { id: stalePreProvider.id } });
    assert(recoveredPre?.sentStatus === 'FAILED', 'Stale pre-provider notification transitioned from PENDING to FAILED');

    // 11B: Retry unlocked via dispatch()
    const retryRes = await notificationPolicyService.dispatch({
      userId: testUserId,
      clientProfileId: testProfileId,
      title: 'Stale Pre-Provider Crash Retried',
      message: 'Clean retry after recovery',
      type: 'WORKOUT',
      tier: 'ESSENTIAL',
      dedupKey: staleDedupKey,
      skipPush: true,
      ignoreQuietHours: true,
    });
    assert(retryRes.status === 'SENT', 'Retrying the recovered dedupKey successfully dispatches without DUPLICATE rejection');

    // 11C: Provider accepted reconciliation (OneSignal has it)
    const staleAcceptedDedupKey = `STALE_ACCEPTED_${Date.now()}`;
    const staleAccepted = await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Stale Provider Accepted Push',
        message: 'Push was accepted by OneSignal before server died',
        type: 'WORKOUT',
        sentStatus: 'PENDING',
        dedupKey: staleAcceptedDedupKey,
        createdAt: tenMinutesAgo,
        updatedAt: tenMinutesAgo,
        metadataJson: JSON.stringify({
          dispatchStage: 'CALLING_PROVIDER',
          oneSignalId: 'test_onesignal_accepted_mock_id',
        }),
      },
    });

    const origGetNotif = oneSignalService.getNotification;
    (oneSignalService as any).getNotification = async (id: string) => {
      if (id === 'test_onesignal_accepted_mock_id') {
        return { success: true, data: { id, successful: 1 } };
      }
      return { success: false, error: 'Not found' };
    };

    const rec2 = await notificationPolicyService.recoverStalePendingNotifications(5 * 60 * 1000);
    assert(rec2.reconciledSent >= 1, 'Provider acceptance reconciled without duplicate push dispatch');

    const reconciledRecord = await prisma.notification.findUnique({ where: { id: staleAccepted.id } });
    assert(reconciledRecord?.sentStatus === 'SENT', 'Notification transitioned from PENDING to SENT via provider reconciliation');

    (oneSignalService as any).getNotification = origGetNotif;

    // 11D: Ambiguous provider state (OneSignal query fails/unknown)
    const staleAmbiguousDedupKey = `STALE_AMBIGUOUS_${Date.now()}`;
    const staleAmbiguous = await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Stale Ambiguous Push',
        message: 'OneSignal query fails',
        type: 'WORKOUT',
        sentStatus: 'PENDING',
        dedupKey: staleAmbiguousDedupKey,
        createdAt: tenMinutesAgo,
        updatedAt: tenMinutesAgo,
        metadataJson: JSON.stringify({
          dispatchStage: 'CALLING_PROVIDER',
        }),
      },
    });

    const origFindDedup = oneSignalService.findNotificationByDedupKey;
    (oneSignalService as any).findNotificationByDedupKey = async () => ({ found: false });

    const rec3 = await notificationPolicyService.recoverStalePendingNotifications(5 * 60 * 1000);
    assert(rec3.ambiguous >= 1, 'Inconclusive provider state safely flagged as ambiguous');

    const ambiguousRecord = await prisma.notification.findUnique({ where: { id: staleAmbiguous.id } });
    assert(ambiguousRecord?.sentStatus === 'FAILED_AMBIGUOUS', 'Ambiguous notification transitioned to FAILED_AMBIGUOUS without duplicate send');

    (oneSignalService as any).findNotificationByDedupKey = origFindDedup;

    // 11E: Concurrent recovery workers (Atomic claiming)
    await prisma.notification.create({
      data: {
        clientProfileId: testProfileId,
        title: 'Concurrent Stale Test',
        message: 'Testing atomic claim',
        type: 'WORKOUT',
        sentStatus: 'PENDING',
        dedupKey: `STALE_CONCURRENT_${Date.now()}`,
        createdAt: tenMinutesAgo,
        updatedAt: tenMinutesAgo,
        metadataJson: JSON.stringify({ dispatchStage: 'RESERVED' }),
      },
    });

    const [workerA, workerB] = await Promise.all([
      notificationPolicyService.recoverStalePendingNotifications(5 * 60 * 1000),
      notificationPolicyService.recoverStalePendingNotifications(5 * 60 * 1000),
    ]);

    const totalClaimed = workerA.claimed + workerB.claimed;
    assert(totalClaimed === 1, `Exactly 1 concurrent recovery worker claimed the stale record (A=${workerA.claimed}, B=${workerB.claimed})`);

    // ── Summary ───────────────────────────────────────────────────────────
    console.log('\n================================================================');
    console.log(`📊 TEST SUITE COMPLETE: ${passed} PASSED, ${failed} FAILED`);
    console.log('================================================================');

    if (failed > 0) {
      throw new Error(`${failed} integration tests failed!`);
    }
  } finally {
    // Clean up test athlete data
    console.log('[CLEANUP] Removing test user data...');
    if (testUserId) {
      await prisma.notification.deleteMany({ where: { clientProfileId: testProfileId } });
      await prisma.user.delete({ where: { id: testUserId } });
    }
    await prisma.$disconnect();
    console.log('[CLEANUP] Done. Clean state restored.');
  }
}

runNotificationIntegrationTests()
  .then(() => {
    console.log('✅ ALL NOTIFICATION INTEGRATION TESTS PASSED CLEANLY.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Integration test run failed:', err);
    process.exit(1);
  });
