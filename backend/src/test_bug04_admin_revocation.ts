/**
 * BUG-04: Durable PostgreSQL Master Admin JWT Revocation Regression Test Suite
 *
 * Verifies:
 * 1. Logout on Instance A causes immediate rejection on Instance B (Vercel multi-instance safety).
 * 2. Revocation survives service reinitialization / container cold starts.
 * 3. Session B remains valid after Session A logout (Per-session isolation).
 * 4. Legacy Admin token handling (revocation by SHA-256 token hash).
 * 5. Database unavailable → FAIL CLOSED (strictly no Admin access when revocation cannot be verified).
 * 6. Actual JWT expiry (exp claim) is used for revocation record expiry.
 * 7. Client authentication & tokenVersion revocation remain completely unchanged.
 */

import express from 'express';
import jwt from 'jsonwebtoken';
import http from 'http';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { authRoutes } from './modules/auth/auth.routes';
import { AdminAuthService, adminAuthService } from './modules/auth/admin_auth.service';
import { UserRole } from './constants/roles';

async function runBug04Suite() {
  console.log('================================================================');
  console.log('TEST SUITE: BUG-04 DURABLE POSTGRESQL ADMIN JWT REVOCATION');
  console.log('================================================================');

  let passedTests = 0;
  let totalTests = 0;

  function assertTest(name: string, condition: boolean, details?: string) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  [PASS] Test ${totalTests}: ${name}`);
    } else {
      console.error(`  [FAIL] Test ${totalTests}: ${name}`);
      if (details) console.error(`         Details: ${details}`);
      throw new Error(`Test failed: ${name}`);
    }
  }

  // Setup express test server mounting actual authRoutes
  const app = express();
  app.use(express.json());
  app.use('/api/v1/auth', authRoutes);

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}/api/v1/auth`;

  // Preserve original prisma methods
  const originalUserFindUnique = prisma.user.findUnique;
  const originalUserUpdate = prisma.user.update;
  const originalProfileFindUnique = prisma.clientProfile.findUnique;
  const originalRefreshToken = (prisma as any).refreshToken;
  const originalRevokedFindFirst = (prisma as any).revokedAdminSession?.findFirst;
  const originalRevokedCreate = (prisma as any).revokedAdminSession?.create;
  const originalRevokedDeleteMany = (prisma as any).revokedAdminSession?.deleteMany;
  const originalTransaction = prisma.$transaction;
  const originalQueryRaw = prisma.$queryRaw;

  // Shared durable mock storage simulating PostgreSQL table revoked_admin_sessions
  const dbRevokedStore = new Map<string, any>();

  try {
    (prisma as any).$transaction = async (cb: any) => cb(prisma);
    (prisma as any).$queryRaw = async () => [{ id: clientId }];
    // Attach durable store handlers to prisma.refreshToken
    (prisma as any).refreshToken = {
      updateMany: async () => ({ count: 0 }),
      create: async () => ({}),
      findUnique: async () => null,
    };
    // Attach durable store handlers to prisma.revokedAdminSession
    (prisma as any).revokedAdminSession = {
      create: async ({ data }: any) => {
        const id = data.id || `revoked-${Date.now()}-${Math.random()}`;
        const record = { id, ...data };
        dbRevokedStore.set(id, record);
        return record;
      },
      findFirst: async ({ where }: any) => {
        const orConditions = where?.OR || [];
        for (const record of dbRevokedStore.values()) {
          for (const cond of orConditions) {
            if (cond.sessionId && record.sessionId === cond.sessionId) {
              return record;
            }
            if (cond.tokenHash && record.tokenHash === cond.tokenHash) {
              return record;
            }
          }
        }
        return null;
      },
      deleteMany: async () => {
        dbRevokedStore.clear();
        return { count: 0 };
      },
    };

    // Client athlete mocks
    let clientTokenVersion = 1;
    const clientId = 'client-test-uuid-001';
    (prisma.user.findUnique as any) = async ({ where }: any) => {
      if (where.id === clientId) {
        return {
          id: clientId,
          email: 'client@alphaxgym.com',
          role: UserRole.CLIENT,
          status: 'APPROVED',
          tokenVersion: clientTokenVersion,
          mustChangePassword: false,
          clientProfile: { clientId: 'AXG-0001' },
          refreshTokens: [{ id: 'mock-rt-1' }],
        };
      }
      return null;
    };
    (prisma.clientProfile.findUnique as any) = async ({ where }: any) => {
      if (where.userId === clientId) {
        return { clientId: 'AXG-0001' };
      }
      return null;
    };
    (prisma.user.update as any) = async ({ where, data }: any) => {
      if (where.id === clientId && data?.tokenVersion?.increment) {
        clientTokenVersion += data.tokenVersion.increment;
        return { id: clientId, tokenVersion: clientTokenVersion };
      }
      return { id: where.id, ...data };
    };

    // -------------------------------------------------------------
    // TEST 1: Admin session generation contains a unique sessionId & exp claim
    // -------------------------------------------------------------
    const adminSessionA = adminAuthService.generateAdminSession();
    const adminTokenA = adminSessionA.token;
    const decodedA = jwt.decode(adminTokenA) as any;

    assertTest(
      'Admin JWT contains embedded sessionId in payload and user object',
      Boolean(decodedA?.sessionId) &&
        decodedA.sessionId === adminSessionA.user.sessionId &&
        decodedA.role === UserRole.ADMIN &&
        decodedA.email === env.ADMIN_EMAIL.toLowerCase(),
      `Expected sessionId present and matching, got decoded: ${JSON.stringify(decodedA)}`
    );

    assertTest(
      'Admin JWT contains exp claim for durable TTL expiration',
      typeof decodedA?.exp === 'number' && decodedA.exp > Math.floor(Date.now() / 1000),
      `Expected numeric exp claim in future, got: ${decodedA?.exp}`
    );

    // -------------------------------------------------------------
    // TEST 2: Active Admin Session A accesses protected GET /auth/me -> HTTP 200
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${adminTokenA}` },
      });
      const body: any = await res.json();

      assertTest(
        'GET /api/v1/auth/me succeeds with HTTP 200 for active admin token',
        res.status === 200 && body.success === true && body.data?.role === 'ADMIN',
        `Expected 200 with role ADMIN, got status ${res.status}: ${JSON.stringify(body)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 3: Generate second concurrent Admin Session B
    // -------------------------------------------------------------
    const adminSessionB = adminAuthService.generateAdminSession();
    const adminTokenB = adminSessionB.token;
    const decodedB = jwt.decode(adminTokenB) as any;

    assertTest(
      'Session B has distinct sessionId from Session A',
      Boolean(decodedB?.sessionId) && decodedB.sessionId !== decodedA.sessionId,
      `Session A id: ${decodedA.sessionId}, Session B id: ${decodedB.sessionId}`
    );

    // -------------------------------------------------------------
    // TEST 4: Admin logs out Session A via POST /auth/logout -> HTTP 200
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/logout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminTokenA}`,
        },
      });
      const body: any = await res.json();

      assertTest(
        'POST /api/v1/auth/logout succeeds with HTTP 200 for admin',
        res.status === 200 && body.success === true,
        `Expected 200 success, got: ${JSON.stringify(body)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 5: Durable record written to PostgreSQL store with actual JWT expiry
    // -------------------------------------------------------------
    {
      const storedRecord = Array.from(dbRevokedStore.values()).find(
        (r) => r.sessionId === decodedA.sessionId
      );
      assertTest(
        'Revocation record exists in durable store with matching sessionId & tokenHash',
        Boolean(storedRecord) &&
          storedRecord.sessionId === decodedA.sessionId &&
          storedRecord.tokenHash === adminAuthService.hashToken(adminTokenA),
        `Stored record: ${JSON.stringify(storedRecord)}`
      );

      const expectedExpiryMs = decodedA.exp * 1000;
      assertTest(
        'Revocation record uses actual JWT expiry from exp claim',
        storedRecord?.expiresAt instanceof Date &&
          Math.abs(storedRecord.expiresAt.getTime() - expectedExpiryMs) < 1000,
        `Expected expiresAt near ${new Date(expectedExpiryMs).toISOString()}, got: ${storedRecord?.expiresAt}`
      );
    }

    // -------------------------------------------------------------
    // TEST 6: Multi-Instance / Cold Start Simulation:
    // Reset service instance (simulating cold start / new Vercel container)
    // -------------------------------------------------------------
    {
      AdminAuthService.resetInstanceForTesting();
      const newInstance = AdminAuthService.getInstance();
      assertTest(
        'Service instance reinitialized cleanly (simulating serverless cold start)',
        newInstance !== undefined
      );

      // Subsequent request with revoked Session A to GET /auth/me
      const res = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${adminTokenA}` },
      });
      const body: any = await res.json();

      assertTest(
        'Revocation survives container cold start and rejects Session A with 401 TOKEN_REVOKED',
        res.status === 401 && body.success === false && body.error?.code === 'TOKEN_REVOKED',
        `Expected 401 TOKEN_REVOKED, got status ${res.status}: ${JSON.stringify(body)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 7: POST /auth/refresh rejects revoked Session A with 401 TOKEN_REVOKED
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminTokenA}`,
        },
      });
      const body: any = await res.json();

      assertTest(
        'POST /api/v1/auth/refresh rejects revoked Session A with 401 TOKEN_REVOKED',
        res.status === 401 && body.success === false && body.error?.code === 'TOKEN_REVOKED',
        `Expected 401 TOKEN_REVOKED, got status ${res.status}: ${JSON.stringify(body)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 8: Concurrent Admin Session B remains valid (Per-session isolation)
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${adminTokenB}` },
      });
      const body: any = await res.json();

      assertTest(
        'Concurrent Admin Session B is NOT affected by Session A logout (per-session isolation)',
        res.status === 200 && body.success === true && body.data?.role === 'ADMIN',
        `Expected Session B to remain 200 OK, got: ${res.status} ${JSON.stringify(body)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 9: Legacy Admin Token (without sessionId) handling & revocation by token hash
    // -------------------------------------------------------------
    {
      const legacyAdminToken = jwt.sign(
        {
          id: 'admin_legacy',
          email: env.ADMIN_EMAIL.toLowerCase(),
          role: UserRole.ADMIN,
        },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '1h' }
      );

      // Verify it works before logout
      const preRes = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${legacyAdminToken}` },
      });
      assertTest(
        'Legacy admin token without sessionId initially authenticates successfully',
        preRes.status === 200,
        `Expected 200, got ${preRes.status}`
      );

      // Logout legacy token
      const logoutRes = await fetch(`${baseUrl}/logout`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${legacyAdminToken}` },
      });
      assertTest(
        'Legacy admin token logout succeeds with HTTP 200',
        logoutRes.status === 200,
        `Expected 200, got ${logoutRes.status}`
      );

      // Verify it is now rejected
      const postRes = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${legacyAdminToken}` },
      });
      const postBody: any = await postRes.json();
      assertTest(
        'Legacy admin token rejected with HTTP 401 TOKEN_REVOKED via durable token hash',
        postRes.status === 401 && postBody.error?.code === 'TOKEN_REVOKED',
        `Expected 401 TOKEN_REVOKED, got: ${postRes.status} ${JSON.stringify(postBody)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 10: Fail-Closed Security: Database unavailable → strictly NO admin access
    // -------------------------------------------------------------
    {
      const activeAdminSessionC = adminAuthService.generateAdminSession();
      const activeAdminTokenC = activeAdminSessionC.token;

      // Simulate database connection failure
      const savedFindFirst = (prisma as any).revokedAdminSession.findFirst;
      (prisma as any).revokedAdminSession.findFirst = async () => {
        throw new Error('FATAL: connection to PostgreSQL database server lost');
      };

      try {
        const res = await fetch(`${baseUrl}/me`, {
          headers: { Authorization: `Bearer ${activeAdminTokenC}` },
        });
        const body: any = await res.json();

        assertTest(
          'Database unavailable causes fail-closed response (HTTP 503 AUTH_SERVICE_UNAVAILABLE, never 200 OK)',
          res.status === 503 &&
            body.success === false &&
            body.error?.code === 'AUTH_SERVICE_UNAVAILABLE',
          `Expected 503 AUTH_SERVICE_UNAVAILABLE, got status ${res.status}: ${JSON.stringify(body)}`
        );
      } finally {
        (prisma as any).revokedAdminSession.findFirst = savedFindFirst;
      }
    }

    // -------------------------------------------------------------
    // TEST 11: Client authentication & tokenVersion revocation non-regression
    // -------------------------------------------------------------
    {
      const initialClientToken = jwt.sign(
        {
          id: clientId,
          email: 'client@alphaxgym.com',
          role: UserRole.CLIENT,
          tokenVersion: 1,
          sessionId: 'mock-client-session-1',
          familyId: 'mock-client-family-1',
        },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '1h' }
      );

      // 1. Client accesses /me
      const clientMeRes = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${initialClientToken}` },
      });
      assertTest(
        'Client with matching tokenVersion accesses GET /me successfully',
        clientMeRes.status === 200,
        `Expected 200, got ${clientMeRes.status}`
      );

      // 2. Client logs out -> increments tokenVersion in DB (allDevices: true)
      const clientLogoutRes = await fetch(`${baseUrl}/logout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${initialClientToken}`,
        },
        body: JSON.stringify({ allDevices: true }),
      });
      assertTest(
        'Client logout increments tokenVersion without touching revoked_admin_sessions',
        clientLogoutRes.status === 200 && clientTokenVersion === 2,
        `Expected 200 and version 2, got status ${clientLogoutRes.status}, version: ${clientTokenVersion}`
      );

      // 3. Client initial token is now rejected due to tokenVersion mismatch
      const clientMeAfterLogout = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${initialClientToken}` },
      });
      const clientBody: any = await clientMeAfterLogout.json();
      assertTest(
        'Client token is rejected with HTTP 401 TOKEN_REVOKED after client logout',
        clientMeAfterLogout.status === 401 && clientBody.error?.code === 'TOKEN_REVOKED',
        `Expected 401 TOKEN_REVOKED, got ${clientMeAfterLogout.status}: ${JSON.stringify(clientBody)}`
      );
    }

    console.log('\n================================================================');
    console.log(`✅ ALL ${passedTests}/${totalTests} DURABLE BUG-04 TESTS PASSED!`);
    console.log('================================================================');
  } finally {
    prisma.user.findUnique = originalUserFindUnique;
    prisma.user.update = originalUserUpdate;
    prisma.clientProfile.findUnique = originalProfileFindUnique;
    (prisma as any).refreshToken = originalRefreshToken;
    (prisma as any).revokedAdminSession.findFirst = originalRevokedFindFirst;
    (prisma as any).revokedAdminSession.create = originalRevokedCreate;
    (prisma as any).revokedAdminSession.deleteMany = originalRevokedDeleteMany;
    prisma.$transaction = originalTransaction;
    prisma.$queryRaw = originalQueryRaw;
    server.close();
  }
}

runBug04Suite().catch((err) => {
  console.error('Fatal BUG-04 test error:', err);
  process.exit(1);
});
