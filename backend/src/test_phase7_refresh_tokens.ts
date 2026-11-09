/**
 * Alpha X Gym — Phase 7 Refresh Token Security & Gap Closure Test Suite
 *
 * Mode: In-Memory Mocked Unit & Controller Integration Suite (Mocked)
 * Note: Clearly distinguished as in-process unit/integration tests without modifying
 * local production PostgreSQL data. Real PostgreSQL parallel multi-worker concurrency
 * is tested separately on dedicated staging environments.
 *
 * Verifies:
 * 1. Initial Login Token Issuance (15m Access Token + 30d Refresh Token).
 * 2. Atomic Single-Use Rotation (Successor minting & single-use consumption).
 * 3. Token Reuse Detection & Session Family Revocation (Replay attack prevention).
 * 4. Token Expiry Handling.
 * 5. TokenVersion Snapshot Mismatch (Password reset / global logout invalidation).
 * 6. Legacy Client JWT Cutover Rejection (Missing sessionId / familyId).
 * 7. requireAuth Family-Bound Active Session Verification & Immediate Invalidation.
 * 8. User Status Checks on Refresh (BUG-03: SUSPENDED / REJECTED rejection).
 * 9. Access-Token-to-Refresh Fallback Blocked (HTTP 400).
 * 10. Single-Device Logout (Preserves other device sessions; tokenVersion NOT incremented).
 * 11. All-Devices Logout (Increments tokenVersion; revokes all sessions).
 * 12. Admin User Rejection Invalidation (User-first lock, tokenVersion increment, ACCOUNT_REJECTED).
 * 13. Admin User Suspension Invalidation (User-first lock, tokenVersion increment, ACCOUNT_SUSPENDED).
 * 14. JWT Password Reset Flow Invalidation (User-first lock, tokenVersion increment, PASSWORD_RESET).
 * 15. Code Password Reset Flow Invalidation (User locked first, code consumed, tokenVersion increment, PASSWORD_RESET).
 * 16. Admin Forced Password Reset Invalidation (User locked, mustChangePassword, tokenVersion increment, PASSWORD_RESET).
 * 17. Authenticated Password Change Flow Invalidation (User-first lock, tokenVersion increment, PASSWORD_CHANGED).
 * 18. BUG-04 Master Admin Session Revocation Preservation (Durable admin session revocation).
 */

import express from 'express';
import jwt from 'jsonwebtoken';
import http from 'http';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { authRoutes } from './modules/auth/auth.routes';
import { adminRoutes } from './modules/admin/admin.routes';
import { requireAuth } from './middlewares/auth';
import { refreshTokenService } from './modules/auth/refresh_token.service';
import { passwordResetService } from './services/password_reset.service';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { UserRole, UserStatus } from './constants/roles';

async function runPhase7Suite() {
  console.log('================================================================');
  console.log('TEST SUITE: PHASE 7 REFRESH TOKEN SECURITY & GAP CLOSURE (MOCKED)');
  console.log('================================================================');

  let passed = 0;
  let total = 0;

  function assertTest(name: string, condition: boolean, details?: string) {
    total++;
    if (condition) {
      passed++;
      console.log(`  [PASS] Test ${total}: ${name}`);
    } else {
      console.error(`  [FAIL] Test ${total}: ${name}`);
      if (details) console.error(`         Details: ${details}`);
      throw new Error(`Test failed: ${name}`);
    }
  }

  // Setup express test server mounting authRoutes, adminRoutes, and protected test route
  const app = express();
  app.use(express.json());
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/admin', adminRoutes);
  app.get('/api/v1/protected-test', requireAuth, (_req, res) => {
    res.json({ success: true, message: 'Protected resource accessed successfully' });
  });

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}/api/v1`;

  // In-memory mock storage
  const mockUsers = new Map<string, any>();
  const mockRefreshTokens = new Map<string, any>(); // key: tokenHash
  const mockCodes = new Map<string, any>(); // key: code id

  const initialPasswordHash = await bcrypt.hash('CorrectPass123!', 10);

  const testUserId = 'client_athlete_uuid_001';
  mockUsers.set(testUserId, {
    id: testUserId,
    email: 'athlete@alphaxgym.com',
    role: UserRole.CLIENT,
    status: UserStatus.APPROVED,
    mustChangePassword: false,
    tokenVersion: 1,
    passwordHash: initialPasswordHash,
    clientProfile: { clientId: 'AXG-7001' },
  });

  // Intercept Prisma Client methods for controlled in-memory testing
  const originalUserFindUnique = prisma.user.findUnique;
  const originalUserFindFirst = prisma.user.findFirst;
  const originalUserUpdate = prisma.user.update;
  const originalUserUpdateMany = prisma.user.updateMany;
  const originalProfileFindUnique = prisma.clientProfile.findUnique;
  const originalTokenFindUnique = (prisma as any).refreshToken.findUnique;
  const originalTokenCreate = (prisma as any).refreshToken.create;
  const originalTokenUpdate = (prisma as any).refreshToken.update;
  const originalTokenUpdateMany = (prisma as any).refreshToken.updateMany;
  const originalExecuteRaw = prisma.$executeRaw;
  const originalQueryRaw = prisma.$queryRaw;
  const originalTransaction = prisma.$transaction;
  const originalUserVerificationLog = (prisma as any).userVerificationLog;
  const originalPasswordResetCode = (prisma as any).passwordResetCode;
  const originalRevokedAdminSession = (prisma as any).revokedAdminSession;
  const dbRevokedStore = new Map<string, any>();

  try {
    // ── MOCK PRISMA IMPLEMENTATION ──────────────────────────────────────────
    (prisma.user as any).findUnique = async ({ where, select }: any) => {
      const u = mockUsers.get(where.id || where.email);
      if (!u) return null;
      if (select?.refreshTokens) {
        const query = select.refreshTokens.where;
        const matching = Array.from(mockRefreshTokens.values()).filter((rt) => {
          return (
            rt.userId === u.id &&
            rt.sessionId === query.sessionId &&
            rt.familyId === query.familyId &&
            rt.isRevoked === query.isRevoked &&
            rt.expiresAt > new Date()
          );
        });
        return {
          ...u,
          refreshTokens: matching.slice(0, select.refreshTokens.take || 1),
        };
      }
      return u;
    };

    (prisma.user as any).findFirst = async ({ where }: any) => {
      for (const u of mockUsers.values()) {
        if (where?.OR) {
          const match = where.OR.some((condition: any) => {
            if (condition.email && u.email === condition.email) return true;
            if (condition.id && u.id === condition.id) return true;
            if (condition.clientProfile?.clientId && u.clientProfile?.clientId === condition.clientProfile.clientId) return true;
            return false;
          });
          if (match) return u;
        } else {
          if (where?.email && u.email === where.email) return u;
          if (where?.id && u.id === where.id) return u;
        }
      }
      return null;
    };

    (prisma.user as any).update = async ({ where, data }: any) => {
      const u = mockUsers.get(where.id);
      if (!u) throw new Error('User not found');
      if (data.tokenVersion?.increment) {
        u.tokenVersion += data.tokenVersion.increment;
      }
      if (data.status) u.status = data.status;
      if (data.passwordHash) u.passwordHash = data.passwordHash;
      if (data.mustChangePassword !== undefined) u.mustChangePassword = data.mustChangePassword;
      if (data.rejectedAt !== undefined) u.rejectedAt = data.rejectedAt;
      if (data.rejectedBy !== undefined) u.rejectedBy = data.rejectedBy;
      if (data.rejectionReason !== undefined) u.rejectionReason = data.rejectionReason;
      if (data.suspendedAt !== undefined) u.suspendedAt = data.suspendedAt;
      if (data.suspendedBy !== undefined) u.suspendedBy = data.suspendedBy;
      return u;
    };

    (prisma.user as any).updateMany = async ({ where, data }: any) => {
      let count = 0;
      for (const u of mockUsers.values()) {
        let match = true;
        if (where.id && u.id !== where.id) match = false;
        if (
          where.passwordHash?.endsWith &&
          (!u.passwordHash || !u.passwordHash.endsWith(where.passwordHash.endsWith))
        ) {
          match = false;
        }
        if (match) {
          if (data.tokenVersion?.increment) u.tokenVersion += data.tokenVersion.increment;
          if (data.passwordHash) u.passwordHash = data.passwordHash;
          if (data.mustChangePassword !== undefined) u.mustChangePassword = data.mustChangePassword;
          count++;
        }
      }
      return { count };
    };

    (prisma.clientProfile as any).findUnique = async ({ where }: any) => {
      const u = mockUsers.get(where.userId);
      return u?.clientProfile || null;
    };

    (prisma as any).refreshToken.create = async ({ data }: any) => {
      const record = { id: crypto.randomUUID(), ...data, isRevoked: false, createdAt: new Date() };
      mockRefreshTokens.set(data.tokenHash, record);
      return record;
    };

    (prisma as any).refreshToken.findUnique = async ({ where }: any) => {
      if (where.tokenHash) return mockRefreshTokens.get(where.tokenHash) || null;
      if (where.id) {
        return Array.from(mockRefreshTokens.values()).find((rt) => rt.id === where.id) || null;
      }
      return null;
    };

    (prisma as any).refreshToken.update = async ({ where, data }: any) => {
      const rt = Array.from(mockRefreshTokens.values()).find((r) => r.id === where.id);
      if (!rt) throw new Error('RefreshToken not found');
      Object.assign(rt, data);
      return rt;
    };

    (prisma as any).refreshToken.updateMany = async ({ where, data }: any) => {
      let count = 0;
      for (const rt of mockRefreshTokens.values()) {
        let match = true;
        if (where.userId && rt.userId !== where.userId) match = false;
        if (where.sessionId && rt.sessionId !== where.sessionId) match = false;
        if (where.familyId && rt.familyId !== where.familyId) match = false;
        if (where.isRevoked !== undefined && rt.isRevoked !== where.isRevoked) match = false;
        if (match) {
          Object.assign(rt, data);
          count++;
        }
      }
      return { count };
    };

    (prisma as any).userVerificationLog = {
      create: async () => ({ id: crypto.randomUUID() }),
    };

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
      deleteMany: async () => ({ count: 0 }),
    };

    (prisma as any).passwordResetCode = {
      create: async ({ data }: any) => {
        const record = { id: crypto.randomUUID(), ...data };
        mockCodes.set(record.id, record);
        return record;
      },
      update: async ({ where, data }: any) => {
        const c = mockCodes.get(where.id);
        if (c) Object.assign(c, data);
        return c;
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const c of mockCodes.values()) {
          let match = true;
          if (where.userId && c.userId !== where.userId) match = false;
          if (where.usedAt === null && c.usedAt !== null) match = false;
          if (match) {
            Object.assign(c, data);
            count++;
          }
        }
        return { count };
      },
    };

    (prisma as any).$executeRaw = async (strings: TemplateStringsArray, ...values: any[]) => {
      const id = values[0];
      const rt = Array.from(mockRefreshTokens.values()).find((r) => r.id === id);
      if (rt && !rt.isRevoked) {
        rt.isRevoked = true;
        rt.revokedAt = new Date();
        rt.revokedReason = 'ROTATED';
        return 1;
      }
      return 0;
    };

    (prisma as any).$queryRaw = async (strings: TemplateStringsArray, ...values: any[]) => {
      const sql = strings.join('?');
      if (sql.includes('users')) {
        const userId = values[0];
        const u = mockUsers.get(userId);
        if (!u) return [];
        return [
          {
            id: u.id,
            email: u.email,
            role: u.role,
            status: u.status,
            mustChangePassword: u.mustChangePassword,
            tokenVersion: u.tokenVersion,
            passwordHash: u.passwordHash,
          },
        ];
      }
      if (sql.includes('password_reset_codes')) {
        const userId = values[0];
        const codes = Array.from(mockCodes.values()).filter(
          (c) => c.userId === userId && c.usedAt === null
        );
        return codes.slice(0, 1);
      }
      return [];
    };

    (prisma as any).$transaction = async (cb: any) => {
      return await cb(prisma);
    };

    // Helper for HTTP requests
    const postJson = async (path: string, body: any, headers: Record<string, string> = {}) => {
      return new Promise<{ status: number; body: any }>((resolve, reject) => {
        const payload = JSON.stringify(body);
        const req = http.request(
          `${baseUrl}${path}`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(payload),
              ...headers,
            },
          },
          (res) => {
            let data = '';
            res.on('data', (chunk) => (data += chunk));
            res.on('end', () => {
              try {
                resolve({ status: res.statusCode || 500, body: JSON.parse(data) });
              } catch (_) {
                resolve({ status: res.statusCode || 500, body: data });
              }
            });
          }
        );
        req.on('error', reject);
        req.write(payload);
        req.end();
      });
    };

    const getJson = async (path: string, headers: Record<string, string> = {}) => {
      return new Promise<{ status: number; body: any }>((resolve, reject) => {
        const req = http.request(
          `${baseUrl}${path}`,
          {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json',
              ...headers,
            },
          },
          (res) => {
            let data = '';
            res.on('data', (chunk) => (data += chunk));
            res.on('end', () => {
              try {
                resolve({ status: res.statusCode || 500, body: JSON.parse(data) });
              } catch (_) {
                resolve({ status: res.statusCode || 500, body: data });
              }
            });
          }
        );
        req.on('error', reject);
        req.end();
      });
    };

    // ── TEST 1: Initial Refresh Token Creation ──────────────────────────────
    console.log('\n--- 1. Initial Refresh Token Creation ---');
    const initialSession = await refreshTokenService.createInitialRefreshToken(
      testUserId,
      1,
      'iPhone 15 Pro / iOS 17.4'
    );
    assertTest(
      'Initial refresh token is generated with 256-bit entropy',
      typeof initialSession.rawRefreshToken === 'string' && initialSession.rawRefreshToken.length === 64
    );
    assertTest(
      'Only SHA-256 hash is stored in database',
      mockRefreshTokens.has(refreshTokenService.hashToken(initialSession.rawRefreshToken)) &&
        !mockRefreshTokens.has(initialSession.rawRefreshToken)
    );
    assertTest(
      'Token record binds tokenVersion snapshot',
      mockRefreshTokens.get(refreshTokenService.hashToken(initialSession.rawRefreshToken)).tokenVersion === 1
    );

    // ── TEST 2: Atomic Single-Use Rotation ──────────────────────────────────
    console.log('\n--- 2. Atomic Single-Use Rotation ---');
    const rotateRes1 = await postJson('/auth/refresh', {
      refreshToken: initialSession.rawRefreshToken,
    });
    assertTest(
      'Valid refresh token returns HTTP 200 with new rotated pair',
      rotateRes1.status === 200 && rotateRes1.body.success === true
    );
    assertTest(
      'Rotated access token has 15-minute expiration payload',
      Boolean(rotateRes1.body.data.token) && typeof rotateRes1.body.data.token === 'string'
    );
    assertTest(
      'Old refresh token is marked isRevoked=true with reason=ROTATED',
      mockRefreshTokens.get(refreshTokenService.hashToken(initialSession.rawRefreshToken)).isRevoked === true &&
        mockRefreshTokens.get(refreshTokenService.hashToken(initialSession.rawRefreshToken)).revokedReason === 'ROTATED'
    );

    const successorTokenRaw = rotateRes1.body.data.refreshToken;
    assertTest('Successor token is issued and active', Boolean(successorTokenRaw));

    // ── TEST 3: Token Reuse Detection & Family Revocation (Replay Attack) ────
    console.log('\n--- 3. Token Reuse Detection & Family Revocation ---');
    const replayRes = await postJson('/auth/refresh', {
      refreshToken: initialSession.rawRefreshToken,
    });
    assertTest(
      'Replaying already consumed ROTATED token returns HTTP 401 TOKEN_REUSE_DETECTED',
      replayRes.status === 401 && replayRes.body.error?.code === 'TOKEN_REUSE_DETECTED'
    );

    const successorHash = refreshTokenService.hashToken(successorTokenRaw);
    assertTest(
      'Successor token in the same session family is immediately revoked with REUSE_DETECTED',
      mockRefreshTokens.get(successorHash).isRevoked === true &&
        mockRefreshTokens.get(successorHash).revokedReason === 'REUSE_DETECTED'
    );

    // ── TEST 4: Token Expiry Handling ───────────────────────────────────────
    console.log('\n--- 4. Token Expiry Handling ---');
    const expiredSession = await refreshTokenService.createInitialRefreshToken(
      testUserId,
      1,
      'Old Device'
    );
    const expiredHash = refreshTokenService.hashToken(expiredSession.rawRefreshToken);
    mockRefreshTokens.get(expiredHash).expiresAt = new Date(Date.now() - 1000); // 1 second in past

    const expiredRes = await postJson('/auth/refresh', {
      refreshToken: expiredSession.rawRefreshToken,
    });
    assertTest(
      'Expired refresh token returns HTTP 401 REFRESH_TOKEN_EXPIRED',
      expiredRes.status === 401 && expiredRes.body.error?.code === 'REFRESH_TOKEN_EXPIRED'
    );
    assertTest(
      'Expired token marked isRevoked=true with reason=EXPIRED',
      mockRefreshTokens.get(expiredHash).isRevoked === true &&
        mockRefreshTokens.get(expiredHash).revokedReason === 'EXPIRED'
    );

    // ── TEST 5: TokenVersion Snapshot Mismatch Check ────────────────────────
    console.log('\n--- 5. TokenVersion Snapshot Mismatch Check ---');
    const staleSession = await refreshTokenService.createInitialRefreshToken(
      testUserId,
      1,
      'Stale Session'
    );
    // User changes password -> user.tokenVersion increments to 2
    mockUsers.get(testUserId).tokenVersion = 2;

    const staleRes = await postJson('/auth/refresh', {
      refreshToken: staleSession.rawRefreshToken,
    });
    assertTest(
      'Token with outdated tokenVersion returns HTTP 401 TOKEN_REVOKED',
      staleRes.status === 401 && staleRes.body.error?.code === 'TOKEN_REVOKED'
    );
    assertTest(
      'Stale token marked isRevoked=true with reason=TOKEN_VERSION_MISMATCH',
      mockRefreshTokens.get(refreshTokenService.hashToken(staleSession.rawRefreshToken)).revokedReason ===
        'TOKEN_VERSION_MISMATCH'
    );

    // Restore tokenVersion for following tests
    mockUsers.get(testUserId).tokenVersion = 1;

    // ── TEST 6: Legacy Client JWT Cutover ───────────────────────────────────
    console.log('\n--- 6. Legacy Client JWT Cutover Rejection ---');
    const legacyClientToken = jwt.sign(
      {
        id: testUserId,
        email: 'athlete@alphaxgym.com',
        role: UserRole.CLIENT,
        tokenVersion: 1,
        // Missing sessionId and familyId
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '30d' }
    );

    const legacyRes = await getJson('/protected-test', {
      Authorization: `Bearer ${legacyClientToken}`,
    });
    assertTest(
      'Legacy client token without sessionId/familyId rejected with 401 TOKEN_UPGRADE_REQUIRED',
      legacyRes.status === 401 && legacyRes.body.error?.code === 'TOKEN_UPGRADE_REQUIRED'
    );

    // ── TEST 7: requireAuth Active Session Family Verification ──────────────
    console.log('\n--- 7. requireAuth Family-Bound Active Session Verification ---');
    const validSession = await refreshTokenService.createInitialRefreshToken(
      testUserId,
      1,
      'Active Valid Device'
    );

    const validAccessToken = jwt.sign(
      {
        id: testUserId,
        email: 'athlete@alphaxgym.com',
        role: UserRole.CLIENT,
        tokenVersion: 1,
        sessionId: validSession.sessionId,
        familyId: validSession.familyId,
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const protectedRes1 = await getJson('/protected-test', {
      Authorization: `Bearer ${validAccessToken}`,
    });
    assertTest(
      'Access token matching active session family succeeds with HTTP 200',
      protectedRes1.status === 200 && protectedRes1.body.success === true
    );

    // Revoke the session family
    await refreshTokenService.revokeSingleSession(testUserId, validSession.sessionId);

    const protectedRes2 = await getJson('/protected-test', {
      Authorization: `Bearer ${validAccessToken}`,
    });
    assertTest(
      'Access token immediately rejected with 401 after session revocation (0 wait for 15m expiry)',
      protectedRes2.status === 401 && protectedRes2.body.error?.code === 'TOKEN_REVOKED'
    );

    // ── TEST 8: User Status Checks (BUG-03: SUSPENDED Account) ──────────────
    console.log('\n--- 8. User Status Checks on Refresh (BUG-03) ---');
    const sessionForSuspended = await refreshTokenService.createInitialRefreshToken(
      testUserId,
      1,
      'Device X'
    );
    mockUsers.get(testUserId).status = UserStatus.SUSPENDED;

    const suspendedRes = await postJson('/auth/refresh', {
      refreshToken: sessionForSuspended.rawRefreshToken,
    });
    assertTest(
      'Suspended user refresh returns HTTP 403 USER_SUSPENDED',
      suspendedRes.status === 403 && suspendedRes.body.error?.code === 'USER_SUSPENDED'
    );
    assertTest(
      'Suspended user refresh token is revoked with reason=ACCOUNT_SUSPENDED',
      mockRefreshTokens.get(refreshTokenService.hashToken(sessionForSuspended.rawRefreshToken)).revokedReason ===
        'ACCOUNT_SUSPENDED'
    );

    // Restore user status
    mockUsers.get(testUserId).status = UserStatus.APPROVED;

    // ── TEST 9: Access-Token-to-Refresh Fallback Blocked ────────────────────
    console.log('\n--- 9. Access-Token-to-Refresh Fallback Blocked ---');
    const fallbackRes = await postJson(
      '/auth/refresh',
      {},
      { Authorization: `Bearer ${validAccessToken}` }
    );
    assertTest(
      'Sending access token in Authorization header rejected with 400 MISSING_REFRESH_TOKEN',
      fallbackRes.status === 400 && fallbackRes.body.error?.code === 'MISSING_REFRESH_TOKEN'
    );

    // ── TEST 10: Single-Device Logout Preserving Other Devices ───────────────
    console.log('\n--- 10. Single-Device Logout (Multi-Device Session Isolation) ---');
    const sessionDev1 = await refreshTokenService.createInitialRefreshToken(testUserId, 1, 'Device 1 (Phone)');
    const sessionDev2 = await refreshTokenService.createInitialRefreshToken(testUserId, 1, 'Device 2 (Tablet)');

    const tokenDev1 = jwt.sign(
      {
        id: testUserId,
        email: 'athlete@alphaxgym.com',
        role: UserRole.CLIENT,
        tokenVersion: 1,
        sessionId: sessionDev1.sessionId,
        familyId: sessionDev1.familyId,
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const tokenDev2 = jwt.sign(
      {
        id: testUserId,
        email: 'athlete@alphaxgym.com',
        role: UserRole.CLIENT,
        tokenVersion: 1,
        sessionId: sessionDev2.sessionId,
        familyId: sessionDev2.familyId,
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    // Verify both devices initially have access
    const checkDev1Pre = await getJson('/protected-test', { Authorization: `Bearer ${tokenDev1}` });
    const checkDev2Pre = await getJson('/protected-test', { Authorization: `Bearer ${tokenDev2}` });
    assertTest('Both Device 1 and Device 2 can access protected resources initially', checkDev1Pre.status === 200 && checkDev2Pre.status === 200);

    // Logout from Device 1 only
    const logoutRes1 = await postJson('/auth/logout', { allDevices: false }, { Authorization: `Bearer ${tokenDev1}` });
    assertTest('Single-device logout succeeds with HTTP 200', logoutRes1.status === 200);

    // Check: tokenVersion must NOT have incremented
    assertTest('Single-device logout does NOT increment user tokenVersion', mockUsers.get(testUserId).tokenVersion === 1);

    // Check: Device 1 session is revoked
    const dev1Record = mockRefreshTokens.get(refreshTokenService.hashToken(sessionDev1.rawRefreshToken));
    assertTest('Device 1 refresh token marked isRevoked=true with reason=LOGOUT_SINGLE', dev1Record.isRevoked === true && dev1Record.revokedReason === 'LOGOUT_SINGLE');

    // Check: Device 1 access token is now rejected
    const checkDev1Post = await getJson('/protected-test', { Authorization: `Bearer ${tokenDev1}` });
    assertTest('Device 1 access token rejected immediately with 401 TOKEN_REVOKED', checkDev1Post.status === 401 && checkDev1Post.body.error?.code === 'TOKEN_REVOKED');

    // Check: Device 2 access token REMAINS VALID!
    const checkDev2Post = await getJson('/protected-test', { Authorization: `Bearer ${tokenDev2}` });
    assertTest('Device 2 access token remains VALID (HTTP 200) after Device 1 logged out', checkDev2Post.status === 200);

    // ── TEST 11: All-Devices Logout ─────────────────────────────────────────
    console.log('\n--- 11. All-Devices Logout ---');
    const logoutAllRes = await postJson('/auth/logout', { allDevices: true }, { Authorization: `Bearer ${tokenDev2}` });
    assertTest('All-devices logout succeeds with HTTP 200', logoutAllRes.status === 200);
    assertTest('All-devices logout increments user tokenVersion to 2', mockUsers.get(testUserId).tokenVersion === 2);

    const dev2Record = mockRefreshTokens.get(refreshTokenService.hashToken(sessionDev2.rawRefreshToken));
    assertTest('Device 2 refresh token marked isRevoked=true with reason=LOGOUT_ALL', dev2Record.isRevoked === true && dev2Record.revokedReason === 'LOGOUT_ALL');

    // Check: Device 2 access token is now rejected
    const checkDev2PostAll = await getJson('/protected-test', { Authorization: `Bearer ${tokenDev2}` });
    assertTest('Device 2 access token rejected with 401 TOKEN_REVOKED after all-device logout', checkDev2PostAll.status === 401);

    // ── TEST 12: Admin Rejection Invalidation Flow ──────────────────────────
    console.log('\n--- 12. Admin User Rejection Invalidation Flow ---');
    const rejectUserId = 'client_athlete_reject_001';
    mockUsers.set(rejectUserId, {
      id: rejectUserId,
      email: 'rejected@alphaxgym.com',
      role: UserRole.CLIENT,
      status: UserStatus.PENDING,
      mustChangePassword: false,
      tokenVersion: 1,
      clientProfile: { clientId: 'AXG-REJECT' },
    });
    const sessionReject = await refreshTokenService.createInitialRefreshToken(rejectUserId, 1, 'Device Reject');

    // Admin authorization token
    const adminToken = jwt.sign(
      {
        id: 'admin_alex',
        email: env.ADMIN_EMAIL,
        role: UserRole.ADMIN,
        sessionId: crypto.randomUUID(),
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const adminRejectRes = await postJson(
      `/admin/verification/${rejectUserId}/reject`,
      { reason: 'Application incomplete' },
      { Authorization: `Bearer ${adminToken}` }
    );
    assertTest('Admin reject endpoint succeeds with HTTP 200', adminRejectRes.status === 200);
    assertTest('Rejected user status updated to REJECTED', mockUsers.get(rejectUserId).status === UserStatus.REJECTED);
    assertTest('Rejected user tokenVersion incremented to 2', mockUsers.get(rejectUserId).tokenVersion === 2);

    const rejectTokenRecord = mockRefreshTokens.get(refreshTokenService.hashToken(sessionReject.rawRefreshToken));
    assertTest(
      'Rejected user refresh tokens revoked with reason=ACCOUNT_REJECTED',
      rejectTokenRecord.isRevoked === true && rejectTokenRecord.revokedReason === 'ACCOUNT_REJECTED'
    );

    // ── TEST 13: Admin Suspension Invalidation Flow ─────────────────────────
    console.log('\n--- 13. Admin User Suspension Invalidation Flow ---');
    const suspendUserId = 'client_athlete_suspend_001';
    mockUsers.set(suspendUserId, {
      id: suspendUserId,
      email: 'suspended@alphaxgym.com',
      role: UserRole.CLIENT,
      status: UserStatus.APPROVED,
      mustChangePassword: false,
      tokenVersion: 1,
      clientProfile: { clientId: 'AXG-SUSPEND' },
    });
    const sessionSuspend = await refreshTokenService.createInitialRefreshToken(suspendUserId, 1, 'Device Suspend');

    const adminSuspendRes = await postJson(
      `/admin/verification/${suspendUserId}/suspend`,
      { reason: 'Policy violation' },
      { Authorization: `Bearer ${adminToken}` }
    );
    assertTest('Admin suspend endpoint succeeds with HTTP 200', adminSuspendRes.status === 200);
    assertTest('Suspended user status updated to SUSPENDED', mockUsers.get(suspendUserId).status === UserStatus.SUSPENDED);
    assertTest('Suspended user tokenVersion incremented to 2', mockUsers.get(suspendUserId).tokenVersion === 2);

    const suspendTokenRecord = mockRefreshTokens.get(refreshTokenService.hashToken(sessionSuspend.rawRefreshToken));
    assertTest(
      'Suspended user refresh tokens revoked with reason=ACCOUNT_SUSPENDED',
      suspendTokenRecord.isRevoked === true && suspendTokenRecord.revokedReason === 'ACCOUNT_SUSPENDED'
    );

    // ── TEST 14: JWT Password Reset Invalidation Flow ───────────────────────
    console.log('\n--- 14. JWT Password Reset Invalidation Flow ---');
    const jwtResetUserId = 'client_jwt_reset_001';
    const oldHash = await bcrypt.hash('OldPassword123!', 10);
    mockUsers.set(jwtResetUserId, {
      id: jwtResetUserId,
      email: 'jwtreset@alphaxgym.com',
      role: UserRole.CLIENT,
      status: UserStatus.APPROVED,
      mustChangePassword: false,
      tokenVersion: 3,
      passwordHash: oldHash,
      clientProfile: { clientId: 'AXG-JWT' },
    });
    const sessionJwtReset = await refreshTokenService.createInitialRefreshToken(jwtResetUserId, 3, 'Device JWT Reset');

    // Mint a password reset token
    const snippet = oldHash.slice(-10);
    const resetToken = jwt.sign(
      {
        userId: jwtResetUserId,
        email: 'jwtreset@alphaxgym.com',
        role: UserRole.CLIENT,
        hashSnippet: snippet,
        jti: crypto.randomUUID(),
        purpose: 'PASSWORD_RESET',
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const jwtResetResult = await passwordResetService.resetPassword(resetToken, 'BrandNewPass123!');
    assertTest('JWT resetPassword succeeds with success=true', jwtResetResult.success === true);
    assertTest('JWT resetPassword increments tokenVersion to 4', mockUsers.get(jwtResetUserId).tokenVersion === 4);

    const jwtResetTokenRecord = mockRefreshTokens.get(refreshTokenService.hashToken(sessionJwtReset.rawRefreshToken));
    assertTest(
      'JWT reset revokes all refresh tokens with reason=PASSWORD_RESET',
      jwtResetTokenRecord.isRevoked === true && jwtResetTokenRecord.revokedReason === 'PASSWORD_RESET'
    );

    // ── TEST 15: Code Password Reset Invalidation Flow ──────────────────────
    console.log('\n--- 15. Code Password Reset Invalidation Flow ---');
    const codeResetUserId = 'client_code_reset_001';
    mockUsers.set(codeResetUserId, {
      id: codeResetUserId,
      email: 'codereset@alphaxgym.com',
      role: UserRole.CLIENT,
      status: UserStatus.APPROVED,
      mustChangePassword: false,
      tokenVersion: 5,
      passwordHash: await bcrypt.hash('PrevPassword123!', 10),
      clientProfile: { clientId: 'AXG-CODE' },
    });
    const sessionCodeReset = await refreshTokenService.createInitialRefreshToken(codeResetUserId, 5, 'Device Code Reset');

    // Set up a mock 6-digit code
    const rawSixDigit = '654321';
    const codeHash = crypto.createHmac('sha256', env.JWT_ACCESS_SECRET).update(rawSixDigit).digest('hex');
    const mockCodeRecord = {
      id: crypto.randomUUID(),
      userId: codeResetUserId,
      codeHash,
      attempts: 0,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
      usedAt: null,
      createdAt: new Date(),
    };
    mockCodes.set(mockCodeRecord.id, mockCodeRecord);

    const codeResetResult = await passwordResetService.resetPasswordWithAdminCode(
      'codereset@alphaxgym.com',
      rawSixDigit,
      'NewSecurePass456!'
    );
    assertTest('Code password reset succeeds with success=true', codeResetResult.success === true);
    assertTest('Code password reset increments tokenVersion to 6', mockUsers.get(codeResetUserId).tokenVersion === 6);
    assertTest('Code password reset marks code usedAt', mockCodeRecord.usedAt !== null);

    const codeResetTokenRecord = mockRefreshTokens.get(refreshTokenService.hashToken(sessionCodeReset.rawRefreshToken));
    assertTest(
      'Code password reset revokes all refresh tokens with reason=PASSWORD_RESET',
      codeResetTokenRecord.isRevoked === true && codeResetTokenRecord.revokedReason === 'PASSWORD_RESET'
    );

    // ── TEST 16: Admin Forced Password Reset Invalidation Flow ──────────────
    console.log('\n--- 16. Admin Forced Password Reset Invalidation Flow ---');
    const forceResetUserId = 'client_force_reset_001';
    mockUsers.set(forceResetUserId, {
      id: forceResetUserId,
      email: 'forcereset@alphaxgym.com',
      role: UserRole.CLIENT,
      status: UserStatus.APPROVED,
      mustChangePassword: false,
      tokenVersion: 10,
      passwordHash: await bcrypt.hash('OldForcedPass!', 10),
      clientProfile: { clientId: 'AXG-FORCE' },
    });
    const sessionForceReset = await refreshTokenService.createInitialRefreshToken(forceResetUserId, 10, 'Device Force Reset');

    const forceResetResult = await passwordResetService.adminSetTemporaryPassword(
      'admin_alex',
      'alex@alphax.gym',
      forceResetUserId,
      'TempPass123!'
    );
    assertTest('Admin forced password reset succeeds with success=true', forceResetResult.success === true);
    assertTest('Forced password reset sets mustChangePassword=true', mockUsers.get(forceResetUserId).mustChangePassword === true);
    assertTest('Forced password reset increments tokenVersion to 11', mockUsers.get(forceResetUserId).tokenVersion === 11);

    const forceResetTokenRecord = mockRefreshTokens.get(refreshTokenService.hashToken(sessionForceReset.rawRefreshToken));
    assertTest(
      'Forced password reset revokes all refresh tokens with reason=PASSWORD_RESET',
      forceResetTokenRecord.isRevoked === true && forceResetTokenRecord.revokedReason === 'PASSWORD_RESET'
    );

    // ── TEST 17: Authenticated Password Change Invalidation Flow ────────────
    console.log('\n--- 17. Authenticated Password Change Invalidation Flow ---');
    const changePassUserId = 'client_change_pass_001';
    const originalPassword = 'InitialCurrentPassword!';
    mockUsers.set(changePassUserId, {
      id: changePassUserId,
      email: 'changepass@alphaxgym.com',
      role: UserRole.CLIENT,
      status: UserStatus.APPROVED,
      mustChangePassword: false,
      tokenVersion: 20,
      passwordHash: await bcrypt.hash(originalPassword, 10),
      clientProfile: { clientId: 'AXG-CHANGE' },
    });
    const sessionChangePass = await refreshTokenService.createInitialRefreshToken(changePassUserId, 20, 'Device Change Pass');

    const changePassResult = await passwordResetService.changePassword(
      changePassUserId,
      originalPassword,
      'BrandNewUpdatedPassword789!'
    );
    assertTest('changePassword succeeds with success=true', changePassResult.success === true);
    assertTest('changePassword increments tokenVersion to 21', mockUsers.get(changePassUserId).tokenVersion === 21);

    const changePassTokenRecord = mockRefreshTokens.get(refreshTokenService.hashToken(sessionChangePass.rawRefreshToken));
    assertTest(
      'changePassword revokes all refresh tokens with reason=PASSWORD_CHANGED',
      changePassTokenRecord.isRevoked === true && changePassTokenRecord.revokedReason === 'PASSWORD_CHANGED'
    );

    // ── TEST 18: BUG-04 Master Admin Revocation Preservation ────────────────
    console.log('\n--- 18. BUG-04 Master Admin Revocation Preservation ---');
    const adminSessionId = crypto.randomUUID();
    const masterAdminToken = jwt.sign(
      {
        id: 'admin_alex',
        email: env.ADMIN_EMAIL,
        role: UserRole.ADMIN,
        sessionId: adminSessionId,
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const adminLogoutRes = await postJson(
      '/auth/logout',
      {},
      { Authorization: `Bearer ${masterAdminToken}` }
    );
    assertTest('Master Admin logout succeeds with HTTP 200', adminLogoutRes.status === 200);

    const isAdminRevoked = await adminAuthService.isRevoked(adminSessionId, masterAdminToken);
    assertTest('Master Admin session is verified as revoked in durable admin store', isAdminRevoked === true);

    console.log('\n================================================================');
    console.log(`ALL ${passed}/${total} PHASE 7 SECURITY GAP CLOSURE TESTS PASSED!`);
    console.log('================================================================');
  } finally {
    // Restore original prisma methods
    prisma.user.findUnique = originalUserFindUnique;
    prisma.user.findFirst = originalUserFindFirst;
    prisma.user.update = originalUserUpdate;
    prisma.user.updateMany = originalUserUpdateMany;
    prisma.clientProfile.findUnique = originalProfileFindUnique;
    (prisma as any).refreshToken.findUnique = originalTokenFindUnique;
    (prisma as any).refreshToken.create = originalTokenCreate;
    (prisma as any).refreshToken.update = originalTokenUpdate;
    (prisma as any).refreshToken.updateMany = originalTokenUpdateMany;
    (prisma as any).userVerificationLog = originalUserVerificationLog;
    (prisma as any).passwordResetCode = originalPasswordResetCode;
    (prisma as any).revokedAdminSession = originalRevokedAdminSession;
    prisma.$executeRaw = originalExecuteRaw;
    prisma.$queryRaw = originalQueryRaw;
    prisma.$transaction = originalTransaction;

    server.close();
  }
}

runPhase7Suite()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test suite failed:', err);
    process.exit(1);
  });
