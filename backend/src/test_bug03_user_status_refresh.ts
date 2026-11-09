/**
 * BUG-03 Regression Test Suite: User Status Enforcement on Token Refresh
 *
 * Verifies that POST /api/v1/auth/refresh strictly enforces user status:
 * 1. APPROVED / ACTIVE user -> Token refresh succeeds (HTTP 200, fresh JWT issued).
 * 2. SUSPENDED user -> Token refresh rejected with HTTP 403 (USER_SUSPENDED, no token issued).
 * 3. REJECTED user -> Token refresh rejected with HTTP 403 (USER_REJECTED, no token issued).
 * 4. Deleted/Nonexistent user -> Token refresh rejected with HTTP 401 (USER_NOT_FOUND).
 * 5. Expired / Invalid token -> Token refresh rejected with HTTP 401 (INVALID_TOKEN / UNAUTHORIZED).
 * 6. tokenVersion mismatch -> Token refresh rejected with HTTP 401 (TOKEN_REVOKED).
 *
 * Runs completely in-memory using mocked Prisma responses without connecting to any live database.
 */

import express from 'express';
import jwt from 'jsonwebtoken';
import http from 'http';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { authRoutes } from './modules/auth/auth.routes';
import { UserRole, UserStatus } from './constants/roles';
import { HttpStatus } from './constants/httpStatus';

async function runBug03Suite() {
  console.log('================================================================');
  console.log('🔒 BUG-03 REGRESSION SUITE: USER STATUS ENFORCEMENT ON REFRESH 🔒');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${testName}${detail ? ` (${detail})` : ''}`);
      failed++;
    }
  }

  // Setup express test server mounting actual authRoutes
  const app = express();
  app.use(express.json());
  app.use('/api/v1/auth', authRoutes);

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as any).port;
  const refreshUrl = `http://127.0.0.1:${port}/api/v1/auth/refresh`;

  // Helper for making HTTP POST requests
  function makePostRequest(url: string, headers: Record<string, string>): Promise<{ status: number; body: any }> {
    return new Promise((resolve, reject) => {
      const parsedUrl = new URL(url);
      const req = http.request(
        {
          hostname: parsedUrl.hostname,
          port: parsedUrl.port,
          path: parsedUrl.pathname,
          method: 'POST',
          headers,
        },
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => {
            try {
              const body = data ? JSON.parse(data) : null;
              resolve({ status: res.statusCode || 500, body });
            } catch (e) {
              resolve({ status: res.statusCode || 500, body: data });
            }
          });
        }
      );
      req.on('error', reject);
      req.end();
    });
  }

  // Preserve original prisma method
  const originalUserFindUnique = prisma.user.findUnique;

  try {
    const activeUserId = 'user-active-uuid-001';
    const suspendedUserId = 'user-suspended-uuid-002';
    const rejectedUserId = 'user-rejected-uuid-003';
    const nonexistentUserId = 'user-ghost-uuid-004';
    const revokedUserId = 'user-revoked-uuid-005';

    // Generate valid test JWTs with tokenVersion = 1
    const activeToken = jwt.sign(
      { id: activeUserId, email: 'active@alphaxgym.com', role: UserRole.CLIENT, tokenVersion: 1 },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const suspendedToken = jwt.sign(
      { id: suspendedUserId, email: 'suspended@alphaxgym.com', role: UserRole.CLIENT, tokenVersion: 1 },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const rejectedToken = jwt.sign(
      { id: rejectedUserId, email: 'rejected@alphaxgym.com', role: UserRole.CLIENT, tokenVersion: 1 },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const nonexistentToken = jwt.sign(
      { id: nonexistentUserId, email: 'ghost@alphaxgym.com', role: UserRole.CLIENT, tokenVersion: 1 },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const revokedToken = jwt.sign(
      { id: revokedUserId, email: 'revoked@alphaxgym.com', role: UserRole.CLIENT, tokenVersion: 1 },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const expiredToken = jwt.sign(
      { id: activeUserId, email: 'active@alphaxgym.com', role: UserRole.CLIENT, tokenVersion: 1 },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '-10s' }
    );

    // Mock prisma responses based on ID
    (prisma.user.findUnique as any) = async ({ where }: any) => {
      if (where.id === activeUserId) {
        return {
          id: activeUserId,
          email: 'active@alphaxgym.com',
          role: UserRole.CLIENT,
          status: UserStatus.APPROVED,
          tokenVersion: 1,
          clientProfile: { clientId: 'AXG-ACTIVE-01' },
          mustChangePassword: false,
        };
      }
      if (where.id === suspendedUserId) {
        return {
          id: suspendedUserId,
          email: 'suspended@alphaxgym.com',
          role: UserRole.CLIENT,
          status: UserStatus.SUSPENDED,
          tokenVersion: 1,
          clientProfile: { clientId: 'AXG-SUSPENDED-02' },
          mustChangePassword: false,
        };
      }
      if (where.id === rejectedUserId) {
        return {
          id: rejectedUserId,
          email: 'rejected@alphaxgym.com',
          role: UserRole.CLIENT,
          status: UserStatus.REJECTED,
          rejectionReason: 'Failed background verification',
          tokenVersion: 1,
          clientProfile: { clientId: 'AXG-REJECTED-03' },
          mustChangePassword: false,
        };
      }
      if (where.id === revokedUserId) {
        return {
          id: revokedUserId,
          email: 'revoked@alphaxgym.com',
          role: UserRole.CLIENT,
          status: UserStatus.APPROVED,
          tokenVersion: 2, // Mismatch: token carries version 1, DB has version 2
          clientProfile: { clientId: 'AXG-REVOKED-05' },
          mustChangePassword: false,
        };
      }
      return null;
    };

    // ── TEST 1: APPROVED / ACTIVE User Refresh ──────────────────────────────
    console.log('[TEST 1] Active / Approved user requests token refresh:');
    const res1 = await makePostRequest(refreshUrl, {
      Authorization: `Bearer ${activeToken}`,
    });
    assert(res1.status === HttpStatus.OK, 'HTTP status is 200 OK');
    assert(res1.body?.success === true, 'Response envelope has success: true');
    assert(typeof res1.body?.data?.token === 'string', 'Fresh JWT token is issued in response');
    const decodedNewToken = jwt.verify(res1.body.data.token, env.JWT_ACCESS_SECRET) as any;
    assert(decodedNewToken.id === activeUserId, 'New token contains correct user ID');
    assert(decodedNewToken.tokenVersion === 1, 'New token preserves active tokenVersion');

    // ── TEST 2: SUSPENDED User Refresh Blocked ───────────────────────────────
    console.log('\n[TEST 2] Suspended user requests token refresh:');
    const res2 = await makePostRequest(refreshUrl, {
      Authorization: `Bearer ${suspendedToken}`,
    });
    assert(res2.status === HttpStatus.FORBIDDEN, 'HTTP status is 403 FORBIDDEN');
    assert(res2.body?.success === false, 'Response envelope has success: false');
    assert(res2.body?.error?.code === 'USER_SUSPENDED', 'Error code is USER_SUSPENDED');
    assert(res2.body?.data === null || res2.body?.data === undefined, 'No token is returned in data payload');

    // ── TEST 3: REJECTED User Refresh Blocked ────────────────────────────────
    console.log('\n[TEST 3] Rejected user requests token refresh:');
    const res3 = await makePostRequest(refreshUrl, {
      Authorization: `Bearer ${rejectedToken}`,
    });
    assert(res3.status === HttpStatus.FORBIDDEN, 'HTTP status is 403 FORBIDDEN');
    assert(res3.body?.success === false, 'Response envelope has success: false');
    assert(res3.body?.error?.code === 'USER_REJECTED', 'Error code is USER_REJECTED');
    assert(res3.body?.data === null || res3.body?.data === undefined, 'No token is returned in data payload');

    // ── TEST 4: Deleted / Nonexistent User Refresh Blocked ───────────────────
    console.log('\n[TEST 4] Deleted or nonexistent user requests token refresh:');
    const res4 = await makePostRequest(refreshUrl, {
      Authorization: `Bearer ${nonexistentToken}`,
    });
    assert(res4.status === HttpStatus.UNAUTHORIZED, 'HTTP status is 401 UNAUTHORIZED');
    assert(res4.body?.success === false, 'Response envelope has success: false');
    assert(res4.body?.error?.code === 'USER_NOT_FOUND', 'Error code is USER_NOT_FOUND');

    // ── TEST 5: Expired / Missing Token Blocked ──────────────────────────────
    console.log('\n[TEST 5] Expired or missing tokens are rejected:');
    const res5a = await makePostRequest(refreshUrl, {
      Authorization: `Bearer ${expiredToken}`,
    });
    assert(res5a.status === HttpStatus.UNAUTHORIZED, 'Expired token rejected with 401');
    assert(res5a.body?.error?.code === 'INVALID_TOKEN', 'Error code is INVALID_TOKEN');

    const res5b = await makePostRequest(refreshUrl, {});
    assert(res5b.status === HttpStatus.UNAUTHORIZED, 'Missing Authorization header rejected with 401');
    assert(res5b.body?.error?.code === 'UNAUTHORIZED', 'Error code is UNAUTHORIZED');

    // ── TEST 6: tokenVersion Mismatch Blocked ────────────────────────────────
    console.log('\n[TEST 6] Revoked token (tokenVersion mismatch) is rejected:');
    const res6 = await makePostRequest(refreshUrl, {
      Authorization: `Bearer ${revokedToken}`,
    });
    assert(res6.status === HttpStatus.UNAUTHORIZED, 'Revoked token rejected with 401');
    assert(res6.body?.error?.code === 'TOKEN_REVOKED', 'Error code is TOKEN_REVOKED');
    assert(res6.body?.data === null || res6.body?.data === undefined, 'No token issued for revoked session');

  } finally {
    prisma.user.findUnique = originalUserFindUnique;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }

  console.log('\n================================================================');
  console.log(`SUMMARY: ${passed} PASSED, ${failed} FAILED out of ${passed + failed}`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runBug03Suite().catch((err) => {
  console.error('Unhandled test error:', err);
  process.exit(1);
});

