/**
 * Alpha X Gym — Fully Mocked Preview Database Safety Test Suite
 *
 * Verifies:
 *   1. isIsolatedTestDatabase() NEVER trusts IS_ISOLATED_TEST_DB=true.
 *   2. enforcePreviewSafety() strictly blocks mutating sweeps with HTTP 403 in Preview.
 *   3. All mutating cron routes (/morning-sweep, /missed-workout-sweep, /evening-sweep, /dispatcher, /recover-stale)
 *      fail closed with HTTP 403 in Preview, even when IS_ISOLATED_TEST_DB=true.
 *   4. Zero Prisma database writes occur.
 *   5. Zero OneSignal network dispatches occur.
 *   6. Authenticated dry-run diagnostics remain available with databaseWrites: 0 and oneSignalDispatches: 0.
 *   7. Unauthenticated dry-run / diagnostics requests fail closed with HTTP 401.
 *   8. Production behavior is fully preserved.
 *
 * SAFETY GUARANTEE:
 *   - Runs 100% offline with zero live database queries or mutations.
 *   - All Prisma write methods are mocked and spied upon.
 *   - All network/fetch requests are blocked and spied upon.
 */

import { prisma } from './config/prisma';
import router, { isVercelPreview, isIsolatedTestDatabase, enforcePreviewSafety, verifyCronSecret } from './modules/notifications/cron.routes';
import { aiNotificationEngine } from './modules/notifications/ai_notifications.service';
import { oneSignalService } from './modules/notifications/onesignal.service';
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
  headers: Record<string, string | undefined> = {},
  query: Record<string, string | undefined> = {}
) {
  let statusCode = 200;
  let responseData: any = null;
  let nextCalled = false;

  const req: any = {
    method,
    url,
    headers: { ...headers },
    query: { ...query },
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

async function runMockedTests() {
  console.log('================================================================');
  console.log('🛡️  ALPHA X PREVIEW DATABASE SAFETY MOCKED VALIDATION SUITE');
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

  // ── SENSORS & SPIES: Intercept any unexpected Prisma write or network call ─
  let prismaWriteCount = 0;
  const prismaWriteMethods = ['create', 'createMany', 'update', 'updateMany', 'delete', 'deleteMany', 'upsert'];

  // Spy on all Prisma models
  const prismaModels = ['user', 'clientProfile', 'notification', 'clientFoodLog', 'dietPlan', 'assignedWorkout'];
  for (const model of prismaModels) {
    if ((prisma as any)[model]) {
      for (const method of prismaWriteMethods) {
        if (typeof (prisma as any)[model][method] === 'function') {
          const original = (prisma as any)[model][method];
          (prisma as any)[model][method] = async (...args: any[]) => {
            prismaWriteCount++;
            throw new Error(`UNEXPECTED PRISMA WRITE in safety test: ${model}.${method}(${JSON.stringify(args)})`);
          };
        }
      }
    }
  }

  // Intercept global fetch to detect any network dispatch
  let networkCallCount = 0;
  const originalFetch = global.fetch;
  global.fetch = (async (url: any, ...args: any[]) => {
    networkCallCount++;
    throw new Error(`UNEXPECTED NETWORK CALL in safety test: ${url}`);
  }) as any;

  const originalVercelEnv = process.env.VERCEL_ENV;
  const originalIsolatedDb = process.env.IS_ISOLATED_TEST_DB;

  try {
    // ── SECTION 1: isIsolatedTestDatabase() Security Guard ───────────────────
    console.log('\n[SECTION 1] Testing isIsolatedTestDatabase() Security Guard...');

    delete process.env.IS_ISOLATED_TEST_DB;
    assert(isIsolatedTestDatabase() === false, 'isIsolatedTestDatabase() returns false by default');

    process.env.IS_ISOLATED_TEST_DB = 'true';
    assert(
      isIsolatedTestDatabase() === false,
      'isIsolatedTestDatabase() returns false even when IS_ISOLATED_TEST_DB=true (does NOT trust unverified flag)'
    );

    process.env.IS_ISOLATED_TEST_DB = '1';
    assert(
      isIsolatedTestDatabase() === false,
      'isIsolatedTestDatabase() returns false even when IS_ISOLATED_TEST_DB=1'
    );

    delete process.env.IS_ISOLATED_TEST_DB;

    // ── SECTION 2: enforcePreviewSafety() Fail-Closed Enforcement ───────────
    console.log('\n[SECTION 2] Testing enforcePreviewSafety() Fail-Closed Behavior...');
    process.env.VERCEL_ENV = 'preview';

    // 2A: Mutating sweep blocked when IS_ISOLATED_TEST_DB=true
    process.env.IS_ISOLATED_TEST_DB = 'true';
    const blockedRes1 = createMockReqRes('GET', '/test');
    const allowed1 = enforcePreviewSafety(blockedRes1.res as any, false);
    assert(allowed1 === false, 'enforcePreviewSafety returns false for mutating sweep in Preview when IS_ISOLATED_TEST_DB=true');
    assert(blockedRes1.getStatusCode() === 403, 'enforcePreviewSafety sends HTTP 403 for mutating sweep in Preview');
    assert(blockedRes1.getResponseData()?.error?.code === 'PREVIEW_SWEEP_BLOCKED', 'Error code is PREVIEW_SWEEP_BLOCKED');

    // 2B: Mutating sweep blocked when IS_ISOLATED_TEST_DB is unset
    delete process.env.IS_ISOLATED_TEST_DB;
    const blockedRes2 = createMockReqRes('GET', '/test');
    const allowed2 = enforcePreviewSafety(blockedRes2.res as any, false);
    assert(allowed2 === false, 'enforcePreviewSafety returns false for mutating sweep in Preview when unconfigured');
    assert(blockedRes2.getStatusCode() === 403, 'enforcePreviewSafety sends HTTP 403');

    // 2C: Dry-run allowed in Preview
    const dryRunRes = createMockReqRes('GET', '/test?dryRun=true');
    const allowedDryRun = enforcePreviewSafety(dryRunRes.res as any, true);
    assert(allowedDryRun === true, 'enforcePreviewSafety permits read-only dry-run diagnostics (isDryRun=true)');
    assert(dryRunRes.getStatusCode() === 200, 'Status code remains 200 for dry-run');

    // 2D: Production allows mutating sweeps
    process.env.VERCEL_ENV = 'production';
    const prodRes = createMockReqRes('GET', '/test');
    const allowedProd = enforcePreviewSafety(prodRes.res as any, false);
    assert(allowedProd === true, 'enforcePreviewSafety permits mutating sweeps in Production');

    // ── SECTION 3: OneSignal Circuit Breakers in Preview ─────────────────────
    console.log('\n[SECTION 3] Testing OneSignal Server-Side Preview Guard...');
    process.env.VERCEL_ENV = 'preview';

    assert(oneSignalService.isPreviewEnvironment() === true, 'oneSignalService detects Preview runtime');
    assert(oneSignalService.isConfigured() === false, 'oneSignalService reports isConfigured: false in Preview');

    const pushRes = await oneSignalService.sendToPlayer('mock_player_id', { title: 'T', body: 'B' });
    assert(pushRes.success === false, 'sendToPlayer rejected in Preview before network');
    assert(Boolean(pushRes.error?.includes('Preview')), 'sendToPlayer error explains Preview guard');

    const broadcastRes = await oneSignalService.broadcastToDevices(['p1', 'p2'], { title: 'T', body: 'B' });
    assert(broadcastRes.success === false, 'broadcastToDevices rejected in Preview before network');

    const userRes = await oneSignalService.sendToUser('user_123', { title: 'T', body: 'B' });
    assert(userRes.success === false, 'sendToUser rejected in Preview before network');

    assert(networkCallCount === 0, 'Zero network calls made during OneSignal Preview dispatches');

    // ── SECTION 4: verifyCronSecret in Preview ──────────────────────────────
    console.log('\n[SECTION 4] Testing verifyCronSecret Authentication in Preview...');
    process.env.VERCEL_ENV = 'preview';
    const validSecret = env.CRON_SECRET || 'test_cron_secret_for_mock';

    // 4A: Missing header
    const ctxNoAuth = createMockReqRes('GET', '/api/v1/cron/morning-sweep');
    verifyCronSecret(ctxNoAuth.req, ctxNoAuth.res as any, ctxNoAuth.next);
    assert(ctxNoAuth.getStatusCode() === 401 && !ctxNoAuth.wasNextCalled(), 'Missing auth header rejected with HTTP 401');

    // 4B: Query param secret rejected in Preview
    const ctxQueryAuth = createMockReqRes('GET', '/api/v1/cron/morning-sweep', {}, { secret: validSecret });
    verifyCronSecret(ctxQueryAuth.req, ctxQueryAuth.res as any, ctxQueryAuth.next);
    assert(ctxQueryAuth.getStatusCode() === 401 && !ctxQueryAuth.wasNextCalled(), 'Query-parameter secret rejected with HTTP 401 in Preview');

    // 4C: Invalid Bearer token
    const ctxInvalidBearer = createMockReqRes('GET', '/api/v1/cron/morning-sweep', { authorization: 'Bearer wrong_token' });
    verifyCronSecret(ctxInvalidBearer.req, ctxInvalidBearer.res as any, ctxInvalidBearer.next);
    assert(ctxInvalidBearer.getStatusCode() === 401 && !ctxInvalidBearer.wasNextCalled(), 'Invalid Bearer token rejected with HTTP 401');

    // 4D: Valid Bearer token
    const ctxValidBearer = createMockReqRes('GET', '/api/v1/cron/morning-sweep', { authorization: `Bearer ${validSecret}` });
    verifyCronSecret(ctxValidBearer.req, ctxValidBearer.res as any, ctxValidBearer.next);
    assert(ctxValidBearer.wasNextCalled() === true, 'Valid Bearer token authorized and next() invoked');

    // ── SECTION 5: Router Mutating Endpoints Fail Closed in Preview ───────────
    console.log('\n[SECTION 5] Testing All Cron Endpoints Fail Closed in Preview (even if IS_ISOLATED_TEST_DB=true)...');
    process.env.VERCEL_ENV = 'preview';
    process.env.IS_ISOLATED_TEST_DB = 'true';

    const mutatingEndpoints = [
      '/morning-sweep',
      '/missed-workout-sweep',
      '/evening-sweep',
      '/dispatcher',
      '/recover-stale',
    ];

    for (const endpoint of mutatingEndpoints) {
      const mock = createMockReqRes('GET', endpoint, { authorization: `Bearer ${validSecret}` });
      await new Promise<void>((resolve) => {
        router(mock.req, mock.res as any, () => resolve());
        // If handler finishes synchronously or via sendSuccess/sendError
        setTimeout(resolve, 50);
      });

      assert(
        mock.getStatusCode() === 403,
        `GET ${endpoint} rejected with HTTP 403 in Preview (got ${mock.getStatusCode()})`
      );
      assert(
        mock.getResponseData()?.error?.code === 'PREVIEW_SWEEP_BLOCKED',
        `GET ${endpoint} returned error code PREVIEW_SWEEP_BLOCKED`
      );
    }

    // ── SECTION 6: Authenticated Dry-Run Diagnostics Available in Preview ─────
    console.log('\n[SECTION 6] Testing Authenticated Dry-Run Diagnostics in Preview...');
    process.env.VERCEL_ENV = 'preview';
    process.env.IS_ISOLATED_TEST_DB = 'true';

    // 6A: /morning-sweep?dryRun=true
    const dryMorningMock = createMockReqRes('GET', '/morning-sweep?dryRun=true', { authorization: `Bearer ${validSecret}` }, { dryRun: 'true' });
    await new Promise<void>((resolve) => {
      router(dryMorningMock.req, dryMorningMock.res as any, () => resolve());
      setTimeout(resolve, 50);
    });
    assert(dryMorningMock.getStatusCode() === 200, 'GET /morning-sweep?dryRun=true succeeds with HTTP 200');
    assert(dryMorningMock.getResponseData()?.data?.dryRun === true, 'dryRun flag is true');
    assert(dryMorningMock.getResponseData()?.data?.databaseWrites === 0, 'databaseWrites is strictly 0');
    assert(dryMorningMock.getResponseData()?.data?.oneSignalDispatches === 0, 'oneSignalDispatches is strictly 0');
    assert(dryMorningMock.getResponseData()?.data?.previewGuardActive === true, 'previewGuardActive is true');
    assert(dryMorningMock.getResponseData()?.data?.isolatedDbVerified === false, 'isolatedDbVerified is false');
    assert(
      dryMorningMock.getResponseData()?.data?.diagnostics?.targetAudience.includes('PROTECTED_PRODUCTION_DATABASE'),
      'Production database queries suppressed in Preview dry-run'
    );

    // 6B: /diagnostics
    const diagnosticsMock = createMockReqRes('GET', '/diagnostics', { authorization: `Bearer ${validSecret}` });
    await new Promise<void>((resolve) => {
      router(diagnosticsMock.req, diagnosticsMock.res as any, () => resolve());
      setTimeout(resolve, 50);
    });
    assert(diagnosticsMock.getStatusCode() === 200, 'GET /diagnostics succeeds with HTTP 200');
    assert(diagnosticsMock.getResponseData()?.data?.databaseWrites === 0, 'databaseWrites is strictly 0');
    assert(diagnosticsMock.getResponseData()?.data?.oneSignalDispatches === 0, 'oneSignalDispatches is strictly 0');

    // 6C: /recover-stale?dryRun=true
    const dryRecoverMock = createMockReqRes('GET', '/recover-stale?dryRun=true', { authorization: `Bearer ${validSecret}` }, { dryRun: 'true' });
    await new Promise<void>((resolve) => {
      router(dryRecoverMock.req, dryRecoverMock.res as any, () => resolve());
      setTimeout(resolve, 50);
    });
    assert(dryRecoverMock.getStatusCode() === 200, 'GET /recover-stale?dryRun=true succeeds with HTTP 200');
    assert(dryRecoverMock.getResponseData()?.data?.databaseWrites === 0, 'recover-stale dryRun databaseWrites: 0');

    // ── SECTION 7: Unauthenticated Dry-Run Fails Closed ───────────────────────
    console.log('\n[SECTION 7] Testing Unauthenticated Dry-Run Fails Closed...');
    const unauthDryRun = createMockReqRes('GET', '/morning-sweep?dryRun=true', {}, { dryRun: 'true' });
    await new Promise<void>((resolve) => {
      router(unauthDryRun.req, unauthDryRun.res as any, () => resolve());
      setTimeout(resolve, 50);
    });
    assert(unauthDryRun.getStatusCode() === 401, 'Unauthenticated dry-run rejected with HTTP 401 (cannot bypass auth)');

    // ── SECTION 8: Final Assertion on Prisma Writes & Provider Dispatches ─────
    console.log('\n[SECTION 8] Final Zero-Mutation and Zero-Network Audit Verification...');
    assert(prismaWriteCount === 0, `Total Prisma writes during test suite is strictly 0 (recorded: ${prismaWriteCount})`);
    assert(networkCallCount === 0, `Total network/fetch calls during test suite is strictly 0 (recorded: ${networkCallCount})`);

    // ── Summary ─────────────────────────────────────────────────────────────
    console.log('\n================================================================');
    console.log(`📊 PREVIEW SAFETY TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
    console.log('================================================================');

    if (failed > 0) {
      throw new Error(`${failed} preview safety tests failed!`);
    }
  } finally {
    // Restore environment
    if (originalVercelEnv) {
      process.env.VERCEL_ENV = originalVercelEnv;
    } else {
      delete process.env.VERCEL_ENV;
    }
    if (originalIsolatedDb) {
      process.env.IS_ISOLATED_TEST_DB = originalIsolatedDb;
    } else {
      delete process.env.IS_ISOLATED_TEST_DB;
    }
    global.fetch = originalFetch;
  }
}

runMockedTests()
  .then(() => {
    console.log('🔒 ALL PREVIEW DATABASE SAFETY ASSERTIONS VERIFIED CLEANLY.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Preview database safety tests failed:', err);
    process.exit(1);
  });
