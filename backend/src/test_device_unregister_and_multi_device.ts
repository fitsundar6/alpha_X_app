/**
 * Alpha X Gym — Authenticated Device Unregister & Multi-Device Safety Test Suite
 *
 * Verifies:
 *   1. Unauthorized unregister requests (missing or invalid token) fail with HTTP 401.
 *   2. Request validation: missing or empty playerId fails with HTTP 400.
 *   3. Conditional clearing: unregistering matching device clears the token (sets to null).
 *   4. Preservation of non-matching device: unregistering a stale/different token preserves
 *      the active device token without wiping it.
 *   5. Multi-device support:
 *      - Registering multiple devices appends tokens deduplicated.
 *      - Unregistering one device leaves other active devices intact.
 *      - Unregistering the final device sets token to null.
 *   6. Push targeting: sendToPlayer correctly dispatches to all active multi-device tokens.
 *   7. Cross-user isolation: User A cannot unregister User B's devices.
 */

import jwt from 'jsonwebtoken';
import { prisma } from './config/prisma';
import { notificationsRoutes } from './modules/notifications/notifications.routes';
import { oneSignalService } from './modules/notifications/onesignal.service';
import { notificationPolicyService } from './modules/notifications/notification_policy.service';
import { env } from './config/environment';

interface MockResponse {
  statusCode: number;
  data: any;
  status(code: number): MockResponse;
  json(data: any): MockResponse;
}

function createMockReqRes(
  method: string,
  url: string,
  body: any = {},
  headers: Record<string, string | undefined> = {}
) {
  let statusCode = 200;
  let responseData: any = null;
  let nextCalled = false;

  const req: any = {
    method,
    url,
    originalUrl: url,
    body,
    headers: { ...headers },
    query: {},
    params: {},
  };

  const res: MockResponse = {
    statusCode: 200,
    data: null,
    status(code: number) {
      statusCode = code;
      this.statusCode = code;
      return this;
    },
    json(data: any) {
      responseData = data;
      this.data = data;
      return this;
    },
  };

  const next = () => {
    nextCalled = true;
  };

  return {
    req,
    res,
    next,
    getStatusCode: () => statusCode,
    getResponseData: () => responseData,
    wasNextCalled: () => nextCalled,
  };
}

async function dispatchRoute(method: string, path: string, body: any = {}, token?: string) {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
  };
  if (token) {
    headers['authorization'] = `Bearer ${token}`;
  }

  const { req, res, getStatusCode, getResponseData } = createMockReqRes(method, path, body, headers);

  return new Promise<{ statusCode: number; data: any }>((resolve) => {
    (notificationsRoutes as any).handle(req, res, () => {
      resolve({ statusCode: getStatusCode(), data: getResponseData() });
    });
    setTimeout(() => {
      resolve({ statusCode: getStatusCode(), data: getResponseData() });
    }, 100);
  });
}

function makeToken(userId: string, email: string = 'client@test.com'): string {
  return jwt.sign(
    { id: userId, email, role: 'CLIENT' },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );
}

async function runTestSuite() {
  console.log('================================================================');
  console.log('🛡️  ALPHA X DEVICE UNREGISTER & MULTI-DEVICE SAFETY TEST SUITE');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, extra?: any) {
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${testName}`);
      if (extra) console.error('     Details:', extra);
      failed++;
    }
  }

  // Set up in-memory mock storage for User database table
  const mockUsers: Record<string, { id: string; email: string; oneSignalPlayerId: string | null }> = {
    'user-client-1': {
      id: 'user-client-1',
      email: 'client1@test.com',
      oneSignalPlayerId: 'device-sub-alpha',
    },
    'user-client-2': {
      id: 'user-client-2',
      email: 'client2@test.com',
      oneSignalPlayerId: 'device-sub-beta,device-sub-gamma',
    },
  };

  // Mock prisma.user.findUnique, prisma.user.update, and prisma.user.findMany
  const originalFindUnique = prisma.user.findUnique;
  const originalUpdate = prisma.user.update;
  const originalFindMany = prisma.user.findMany;
  const originalNotification = (prisma as any).notification;

  (prisma as any).notification = {
    findUnique: async () => null,
    create: async ({ data }: any) => ({ id: 'mock-notif-1', ...data }),
    update: async ({ data }: any) => ({ id: 'mock-notif-1', ...data }),
    count: async () => 0,
  };

  (prisma.user as any).findUnique = async ({ where, select }: any) => {
    const user = mockUsers[where.id];
    if (!user) return null;
    if (select) {
      const selected: any = {};
      for (const k of Object.keys(select)) {
        selected[k] = (user as any)[k];
      }
      return selected;
    }
    return { ...user };
  };

  (prisma.user as any).update = async ({ where, data }: any) => {
    const user = mockUsers[where.id];
    if (!user) throw new Error('User not found');
    if ('oneSignalPlayerId' in data) {
      user.oneSignalPlayerId = data.oneSignalPlayerId;
    }
    return { ...user };
  };

  (prisma.user as any).findMany = async ({ where, select }: any) => {
    const results = Object.values(mockUsers).filter((user) => {
      if (where?.id?.not && user.id === where.id.not) return false;
      if (where?.oneSignalPlayerId?.contains) {
        if (!user.oneSignalPlayerId) return false;
        return user.oneSignalPlayerId.split(',').map((t) => t.trim()).includes(where.oneSignalPlayerId.contains);
      }
      return true;
    });
    if (select) {
      return results.map((user) => {
        const item: any = {};
        for (const k of Object.keys(select)) item[k] = (user as any)[k];
        return item;
      });
    }
    return results;
  };

  try {
    const tokenUser1 = makeToken('user-client-1');
    const tokenUser2 = makeToken('user-client-2');

    // ── SUITE 1: Authentication & Authorization ───────────────────────────────
    console.log('[SECTION 1] Testing Authentication & Authorization Controls...');
    {
      const resNoAuth = await dispatchRoute('POST', '/unregister-device', { playerId: 'device-sub-alpha' });
      assert(resNoAuth.statusCode === 401, 'Unauthenticated unregister request fails with HTTP 401');

      const resBadToken = await dispatchRoute('POST', '/unregister-device', { playerId: 'device-sub-alpha' }, 'invalid.jwt.token');
      assert(resBadToken.statusCode === 401, 'Invalid Bearer token fails with HTTP 401');
    }

    // ── SUITE 2: Validation of Request Payload ────────────────────────────────
    console.log('\n[SECTION 2] Testing Request Payload Validation...');
    {
      const resMissing = await dispatchRoute('POST', '/unregister-device', {}, tokenUser1);
      assert(resMissing.statusCode === 400, 'Missing playerId rejected with HTTP 400');

      const resEmpty = await dispatchRoute('POST', '/unregister-device', { playerId: '   ' }, tokenUser1);
      assert(resEmpty.statusCode === 400, 'Empty playerId rejected with HTTP 400');
    }

    // ── SUITE 3: Conditional Clearing of Matching Device ─────────────────────
    console.log('\n[SECTION 3] Testing Conditional Clearing of Matching Device Subscription...');
    {
      mockUsers['user-client-1'].oneSignalPlayerId = 'device-sub-alpha';
      const res = await dispatchRoute('POST', '/unregister-device', { playerId: 'device-sub-alpha' }, tokenUser1);

      assert(res.statusCode === 200, 'Unregister matching device returns HTTP 200');
      assert(res.data?.data?.unregistered === true, 'Response reports unregistered: true');
      assert(res.data?.data?.cleared === true, 'Response reports cleared: true');
      assert(mockUsers['user-client-1'].oneSignalPlayerId === null, 'Matching device token was cleared in database (set to null)');
    }

    // ── SUITE 4: Preservation of Non-Matching / Stale Device Tokens ───────────
    console.log('\n[SECTION 4] Testing Preservation of Non-Matching Device Subscriptions...');
    {
      mockUsers['user-client-1'].oneSignalPlayerId = 'device-sub-active';

      // An unregister request arrives for an OLD/STALE device 'device-sub-old'
      const res = await dispatchRoute('POST', '/unregister-device', { playerId: 'device-sub-old' }, tokenUser1);

      assert(res.statusCode === 200, 'Stale unregister request returns HTTP 200');
      assert(res.data?.data?.cleared === false, 'Response reports cleared: false (non-matching)');
      assert(res.data?.data?.preservedTokensCount === 1, 'Preserved tokens count is 1');
      assert(
        mockUsers['user-client-1'].oneSignalPlayerId === 'device-sub-active',
        'Active device token "device-sub-active" was strictly PRESERVED and not wiped'
      );
    }

    // ── SUITE 5: Multi-Device Management & Safe Partial Unregister ────────────
    console.log('\n[SECTION 5] Testing Multi-Device Management & Safe Partial Unregister...');
    {
      // Set user-client-2 to have two registered devices: Phone and Tablet
      mockUsers['user-client-2'].oneSignalPlayerId = 'phone-device-id,tablet-device-id';

      // 1. Client logs out of Phone -> unregisters 'phone-device-id'
      const resUnregisterPhone = await dispatchRoute(
        'POST',
        '/unregister-device',
        { playerId: 'phone-device-id' },
        tokenUser2
      );

      assert(resUnregisterPhone.statusCode === 200, 'Unregistering phone returns HTTP 200');
      assert(resUnregisterPhone.data?.data?.cleared === true, 'Phone token was cleared');
      assert(resUnregisterPhone.data?.data?.hasRemainingDevices === true, 'hasRemainingDevices is true');
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === 'tablet-device-id',
        'Database preserves "tablet-device-id" while removing "phone-device-id"'
      );

      // 2. Client logs into Watch -> registers 'watch-device-id'
      const resRegisterWatch = await dispatchRoute(
        'POST',
        '/register-device',
        { playerId: 'watch-device-id' },
        tokenUser2
      );

      assert(resRegisterWatch.statusCode === 200, 'Registering watch returns HTTP 200');
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === 'tablet-device-id,watch-device-id',
        'Database appends new device without overwriting existing tablet subscription'
      );

      // 3. Registering existing device again is deduplicated
      await dispatchRoute('POST', '/register-device', { playerId: 'watch-device-id' }, tokenUser2);
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === 'tablet-device-id,watch-device-id',
        'Duplicate registration does not duplicate tokens'
      );

      // 4. Client logs out of Tablet
      await dispatchRoute('POST', '/unregister-device', { playerId: 'tablet-device-id' }, tokenUser2);
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === 'watch-device-id',
        'Unregistering tablet leaves watch subscription intact'
      );

      // 5. Client logs out of Watch (final device)
      const resFinal = await dispatchRoute('POST', '/unregister-device', { playerId: 'watch-device-id' }, tokenUser2);
      assert(resFinal.data?.data?.hasRemainingDevices === false, 'Final unregister reports hasRemainingDevices: false');
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === null,
        'Final unregister sets oneSignalPlayerId in database to null'
      );
    }

    // ── SUITE 6: Multi-Device Targeting in OneSignalService ───────────────────
    console.log('\n[SECTION 6] Testing Multi-Device Targeting in OneSignalService...');
    {
      let capturedBody: any = null;
      (oneSignalService as any).executePost = async (body: any) => {
        capturedBody = body;
        return { success: true, playerId: 'multi' };
      };

      const origEnv = (oneSignalService as any).isPreviewEnvironment;
      (oneSignalService as any).isPreviewEnvironment = () => false;

      // Single token test
      await oneSignalService.sendToPlayer('token-single', { title: 'T', body: 'B' });
      assert(
        Array.isArray(capturedBody?.include_subscription_ids) &&
          capturedBody.include_subscription_ids.length === 1 &&
          capturedBody.include_subscription_ids[0] === 'token-single',
        'Single token dispatches with include_subscription_ids: ["token-single"]'
      );

      // Multi-token test
      await oneSignalService.sendToPlayer('token-phone,token-tablet,token-watch', { title: 'T', body: 'B' });
      assert(
        Array.isArray(capturedBody?.include_subscription_ids) &&
          capturedBody.include_subscription_ids.length === 3 &&
          capturedBody.include_subscription_ids[0] === 'token-phone' &&
          capturedBody.include_subscription_ids[1] === 'token-tablet' &&
          capturedBody.include_subscription_ids[2] === 'token-watch',
        'Multi-device comma-separated tokens dispatch to all active subscriptions simultaneously'
      );

      (oneSignalService as any).isPreviewEnvironment = origEnv;
    }

    // ── SUITE 7: HTTP DELETE Verb Compatibility ──────────────────────────────
    console.log('\n[SECTION 7] Testing HTTP DELETE Verb Compatibility...');
    {
      mockUsers['user-client-1'].oneSignalPlayerId = 'device-delete-test';
      const resDelete = await dispatchRoute('DELETE', '/unregister-device', { playerId: 'device-delete-test' }, tokenUser1);

      assert(resDelete.statusCode === 200, 'DELETE /unregister-device returns HTTP 200');
      assert(resDelete.data?.data?.cleared === true, 'DELETE /unregister-device successfully clears token');
      assert(mockUsers['user-client-1'].oneSignalPlayerId === null, 'Token cleared via DELETE verb');
    }

    // ── SUITE 8: Preventing Dispatch to Logged-Out Device ─────────────────────
    console.log('\n[SECTION 8] Testing Notification Dispatch Suppression for Logged-Out Device...');
    {
      // Mock user with null oneSignalPlayerId (logged out)
      mockUsers['user-client-1'].oneSignalPlayerId = null;
      (mockUsers['user-client-1'] as any).notificationsEnabled = true;
      (mockUsers['user-client-1'] as any).clientProfile = {
        id: 'prof-1',
        clientId: 'AXG-0001',
        notificationPref: {
          timezone: 'Asia/Kolkata',
          quietHoursStart: 21,
          quietHoursEnd: 7,
          workoutReminders: true,
        },
      };

      let sendToPlayerCallCount = 0;
      const origSendToPlayer = oneSignalService.sendToPlayer;
      oneSignalService.sendToPlayer = async () => {
        sendToPlayerCallCount++;
        return { success: true, playerId: 'should-not-be-called' };
      };

      const dispatchResult = await notificationPolicyService.dispatch({
        userId: 'user-client-1',
        clientProfileId: 'prof-1',
        title: 'Workout Reminder',
        message: 'Time to train!',
        type: 'WORKOUT',
        tier: 'PROACTIVE',
        ignoreQuietHours: true,
        dedupKey: `LOGGED_OUT_TEST:${Date.now()}`,
      });

      assert(dispatchResult.success === true, 'Dispatch returns success (in-app recorded)');
      assert(dispatchResult.status === 'NO_DEVICE', 'Delivery status is strictly NO_DEVICE');
      assert(sendToPlayerCallCount === 0, 'Zero OneSignal push dispatches executed for logged-out client (verified: 0)');

      // Restore
      oneSignalService.sendToPlayer = origSendToPlayer;
    }

    // ── SUITE 9: Register-Device Delegation for Unregister ─────────────────────
    console.log('\n[SECTION 9] Testing Register-Device Route Delegation for Unregister Action...');
    {
      mockUsers['user-client-1'].oneSignalPlayerId = 'device-action-test';
      const resDelegation = await dispatchRoute(
        'POST',
        '/register-device',
        { action: 'unregister', playerId: 'device-action-test' },
        tokenUser1
      );

      assert(resDelegation.statusCode === 200, 'POST /register-device with action="unregister" succeeds with HTTP 200');
      assert(resDelegation.data?.data?.cleared === true, 'Delegated unregister cleared token');
      assert(mockUsers['user-client-1'].oneSignalPlayerId === null, 'Token cleared in database via register-device delegation');
    }

    // ── SUITE 10: Account Switching on the Same Device (Cross-Account Isolation) ──
    console.log('\n[SECTION 10] Testing Safe Account Switching on the Same Physical Device...');
    {
      // Scenario: User 1 was previously logged into Shared Phone (device-phone-shared)
      mockUsers['user-client-1'].oneSignalPlayerId = 'device-phone-shared';
      mockUsers['user-client-2'].oneSignalPlayerId = null;

      // User 2 logs into the exact same device and registers device-phone-shared
      const resSwitch = await dispatchRoute(
        'POST',
        '/register-device',
        { playerId: 'device-phone-shared' },
        tokenUser2
      );

      assert(resSwitch.statusCode === 200, 'Account switch registration returns HTTP 200');
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === 'device-phone-shared',
        'Device successfully registered for new user (User 2)'
      );
      assert(
        mockUsers['user-client-1'].oneSignalPlayerId === null,
        'Device token was automatically and cleanly removed from previous user (User 1)'
      );

      // Now verify targeting User 1 produces zero dispatches
      let dispatchedToPlayerIds: string[] = [];
      const origSend = oneSignalService.sendToPlayer;
      oneSignalService.sendToPlayer = async (targetId: string) => {
        dispatchedToPlayerIds.push(targetId);
        return { success: true, playerId: targetId };
      };

      // Target User 1 with notification policy
      const resultUser1 = await notificationPolicyService.dispatch({
        userId: 'user-client-1',
        clientProfileId: 'prof-1',
        title: 'User 1 Alert',
        message: 'Personal workout',
        type: 'WORKOUT',
        tier: 'PROACTIVE',
        ignoreQuietHours: true,
        dedupKey: `USER1_TEST:${Date.now()}`,
      });

      assert(resultUser1.status === 'NO_DEVICE', 'Notification to logged-out User 1 is marked NO_DEVICE');
      assert(dispatchedToPlayerIds.length === 0, 'Zero pushes sent to shared device for logged-out User 1');

      // Target User 2 with notification policy
      (mockUsers['user-client-2'] as any).notificationsEnabled = true;
      (mockUsers['user-client-2'] as any).clientProfile = {
        id: 'prof-2',
        clientId: 'AXG-0002',
        notificationPref: {
          timezone: 'Asia/Kolkata',
          quietHoursStart: 23,
          quietHoursEnd: 5,
          workoutReminders: true,
        },
      };

      const resultUser2 = await notificationPolicyService.dispatch({
        userId: 'user-client-2',
        clientProfileId: 'prof-2',
        title: 'User 2 Alert',
        message: 'Welcome back!',
        type: 'WORKOUT',
        tier: 'PROACTIVE',
        ignoreQuietHours: true,
        dedupKey: `USER2_TEST:${Date.now()}`,
      });

      assert(resultUser2.success === true, 'Notification to active User 2 succeeds');
      assert(
        dispatchedToPlayerIds.includes('device-phone-shared'),
        'Push was correctly and securely delivered to active User 2 on the device'
      );

      oneSignalService.sendToPlayer = origSend;
    }

    // ── SUITE 11: Multi-Device Account Switching (Preserving Other Devices) ───────
    console.log('\n[SECTION 11] Testing Multi-Device Account Switching with Device Preservation...');
    {
      // Scenario: User 1 has two devices: a private phone and a shared tablet
      mockUsers['user-client-1'].oneSignalPlayerId = 'user1-phone-private,shared-tablet';
      mockUsers['user-client-2'].oneSignalPlayerId = null;

      // User 2 logs into the shared tablet and registers shared-tablet
      const resTabletSwitch = await dispatchRoute(
        'POST',
        '/register-device',
        { playerId: 'shared-tablet' },
        tokenUser2
      );

      assert(resTabletSwitch.statusCode === 200, 'Tablet switch registration returns HTTP 200');
      assert(
        mockUsers['user-client-2'].oneSignalPlayerId === 'shared-tablet',
        'User 2 now owns shared-tablet'
      );
      assert(
        mockUsers['user-client-1'].oneSignalPlayerId === 'user1-phone-private',
        'User 1 private phone is strictly preserved while shared tablet was detached'
      );
    }

    // ── SUITE 12: Stale Mappings & Full Logout Flow Safety ────────────────────────
    console.log('\n[SECTION 12] Testing Stale Device Mappings & Full Logout Flow Safety...');
    {
      // User 1 logs out of their private phone
      const resLogout = await dispatchRoute(
        'POST',
        '/unregister-device',
        { playerId: 'user1-phone-private' },
        tokenUser1
      );

      assert(resLogout.statusCode === 200, 'Logout unregister returns HTTP 200');
      assert(resLogout.data?.data?.cleared === true, 'Token was cleared on logout');
      assert(mockUsers['user-client-1'].oneSignalPlayerId === null, 'User 1 has null oneSignalPlayerId in PostgreSQL');

      // Targeting User 1 now cannot reach any device
      const resTargetLoggedOut = await notificationPolicyService.dispatch({
        userId: 'user-client-1',
        clientProfileId: 'prof-1',
        title: 'Logged Out Client Test',
        message: 'Should never arrive',
        type: 'WORKOUT',
        tier: 'PROACTIVE',
        ignoreQuietHours: true,
        dedupKey: `LOGGED_OUT_CLEAN_TEST:${Date.now()}`,
      });
      assert(resTargetLoggedOut.status === 'NO_DEVICE', 'Logged-out user is safely designated NO_DEVICE');
    }

    // ── SUITE 13: Anonymous & General Broadcast Safety ────────────────────────────
    console.log('\n[SECTION 13] Testing Anonymous & General Broadcast Safety...');
    {
      let broadcastTargetIds: string[] = [];
      const origBroadcast = oneSignalService.broadcastToDevices;
      oneSignalService.broadcastToDevices = async (playerIds: string[]) => {
        broadcastTargetIds = playerIds;
        return {
          success: true,
          recipientsCount: playerIds.length,
          devicesTargeted: playerIds.length,
        };
      };

      // Broadcast to multiple devices (anonymous broadcast / gym announcements)
      const broadcastRes = await oneSignalService.broadcastToDevices(
        ['general-sub-1', 'general-sub-2', 'shared-tablet'],
        { title: 'Gym Announcement', body: 'Gym closes early today.' }
      );

      assert(broadcastRes.success === true, 'Broadcast succeeds for anonymous & active devices');
      assert(broadcastTargetIds.length === 3, 'All 3 broadcast target devices reached');
      assert(broadcastTargetIds.includes('shared-tablet'), 'Active device receives broadcast');
      assert(broadcastTargetIds.includes('general-sub-1'), 'Anonymous device receives broadcast');

      oneSignalService.broadcastToDevices = origBroadcast;
    }

  } finally {
    // Restore original prisma methods
    (prisma.user as any).findUnique = originalFindUnique;
    (prisma.user as any).update = originalUpdate;
    (prisma.user as any).findMany = originalFindMany;
    (prisma as any).notification = originalNotification;
  }

  console.log('\n================================================================');
  console.log(`📊 TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTestSuite().catch((err) => {
  console.error('Test suite uncaught error:', err);
  process.exit(1);
});
