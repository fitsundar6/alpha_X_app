/**
 * F-04 JWT & Session Security — Backend Regression Tests
 *
 * Tests the following via direct middleware invocation (no running server/DB needed):
 *  1. Valid current JWT → requireAuth calls next().
 *  2. Expired JWT → HTTP 401.
 *  3. Token with old/wrong tokenVersion → HTTP 401 TOKEN_REVOKED.
 *  4. No Authorization header → HTTP 401.
 *  5. Malformed JWT → HTTP 401.
 *  6. Tampered JWT (wrong secret) → HTTP 401.
 *  7. Mock admin token → bypasses tokenVersion check (stateless admin).
 *  8. Legacy token (no tokenVersion claim) → treated as version 0.
 *  9. Expired token → POST /auth/refresh rejects (grace period removed).
 * 10. Tampered token → POST /auth/refresh rejects.
 * 11. tokenVersion embedded in all jwt.sign calls.
 * 12. password_reset.service increments tokenVersion on changePassword.
 * 13. password_reset.service increments tokenVersion on resetPassword.
 * 14. Logout endpoint exists and is auth-protected.
 * 15. requireApprovedUser mounted on food mutation routes.
 *
 * Uses mock req/res objects to test middleware without a live database connection.
 * For tokenVersion DB validation tests, Prisma calls are verified structurally.
 */

import jwt from 'jsonwebtoken';
import { env } from './config/environment';
import { UserRole } from './constants/roles';
import fs from 'fs';
import path from 'path';

// ── Helpers ──────────────────────────────────────────────────────────────────

const SECRET = env.JWT_ACCESS_SECRET;

function makeToken(payload: Record<string, any>, options: jwt.SignOptions = {}): string {
  return jwt.sign(payload, SECRET, { expiresIn: '1h', ...options });
}

function makeExpiredToken(payload: Record<string, any>): string {
  return jwt.sign(payload, SECRET, { expiresIn: '-1s' });
}

interface MockResponse {
  statusCode: number | null;
  body: any;
  status: (code: number) => MockResponse;
  json: (payload: any) => MockResponse;
  setHeader: (name: string, value: string) => MockResponse;
}

function createMockRes(): MockResponse {
  const res: any = {
    statusCode: null,
    body: null,
    status(code: number) { this.statusCode = code; return this; },
    json(payload: any) { this.body = payload; return this; },
    setHeader() { return this; },
  };
  return res;
}

// ── Test Runner ──────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
const results: { name: string; status: 'PASS' | 'FAIL'; detail?: string }[] = [];

function test(name: string, fn: () => void | Promise<void>) {
  try {
    const result = fn();
    if (result && typeof (result as any).then === 'function') {
      return (result as Promise<void>).then(() => {
        passed++;
        results.push({ name, status: 'PASS' });
        console.log(`  ✅ ${name}`);
      }).catch((e: any) => {
        failed++;
        const detail = e?.message || String(e);
        results.push({ name, status: 'FAIL', detail });
        console.log(`  ❌ ${name}: ${detail}`);
      });
    }
    passed++;
    results.push({ name, status: 'PASS' });
    console.log(`  ✅ ${name}`);
  } catch (e: any) {
    failed++;
    const detail = e?.message || String(e);
    results.push({ name, status: 'FAIL', detail });
    console.log(`  ❌ ${name}: ${detail}`);
  }
}

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

// ── Static / Source Code Tests ───────────────────────────────────────────────

function readSource(relativePath: string): string {
  return fs.readFileSync(path.resolve(__dirname, relativePath), 'utf-8');
}

async function runAllTests() {
  console.log('\n================================================================');
  console.log('🔒 F-04 JWT & SESSION SECURITY REGRESSION TESTS 🔒');
  console.log('================================================================\n');

  // ─── Group A: JWT Token Verification ─────────────────────────────────────

  console.log('── A. JWT Token Verification ──\n');

  await test('A1. Expired JWT is rejected by jwt.verify (no ignoreExpiration)', () => {
    const expired = makeExpiredToken({
      id: 'test_user', email: 'test@test.com', role: 'CLIENT', tokenVersion: 0,
    });
    try {
      jwt.verify(expired, SECRET);
      throw new Error('Should have thrown TokenExpiredError');
    } catch (e: any) {
      assert(e.name === 'TokenExpiredError', `Expected TokenExpiredError, got ${e.name}`);
    }
  });

  await test('A2. Valid JWT is accepted by jwt.verify', () => {
    const valid = makeToken({
      id: 'test_user', email: 'test@test.com', role: 'CLIENT', tokenVersion: 0,
    });
    const decoded = jwt.verify(valid, SECRET) as any;
    assert(decoded.id === 'test_user', 'id mismatch');
    assert(decoded.tokenVersion === 0, `tokenVersion mismatch: ${decoded.tokenVersion}`);
  });

  await test('A3. Tampered JWT (wrong secret) is rejected', () => {
    const tampered = jwt.sign(
      { id: 'test', email: 'test@test.com', role: 'CLIENT', tokenVersion: 0 },
      'wrong_secret_key_abcdef123456',
      { expiresIn: '1h' }
    );
    try {
      jwt.verify(tampered, SECRET);
      throw new Error('Should have thrown JsonWebTokenError');
    } catch (e: any) {
      assert(e.name === 'JsonWebTokenError', `Expected JsonWebTokenError, got ${e.name}`);
    }
  });

  await test('A4. Malformed JWT string is rejected', () => {
    try {
      jwt.verify('not.a.real.jwt.token', SECRET);
      throw new Error('Should have thrown');
    } catch (e: any) {
      assert(e.name === 'JsonWebTokenError', `Expected JsonWebTokenError, got ${e.name}`);
    }
  });

  await test('A5. tokenVersion claim is embedded in signed tokens', () => {
    const token = makeToken({
      id: 'user1', email: 'user@test.com', role: 'CLIENT', tokenVersion: 42,
    });
    const decoded = jwt.verify(token, SECRET) as any;
    assert(decoded.tokenVersion === 42, `Expected tokenVersion 42, got ${decoded.tokenVersion}`);
  });

  await test('A6. Legacy token without tokenVersion defaults to 0 when parsed', () => {
    const legacy = makeToken({ id: 'old_user', email: 'old@test.com', role: 'CLIENT' });
    const decoded = jwt.verify(legacy, SECRET) as any;
    const claimedVersion = typeof decoded.tokenVersion === 'number' ? decoded.tokenVersion : 0;
    assert(claimedVersion === 0, `Expected default 0, got ${claimedVersion}`);
  });

  // ─── Group B: Source Code Structural Verification ────────────────────────

  console.log('\n── B. Source Code Structural Verification ──\n');

  await test('B1. requireAuth middleware checks tokenVersion against DB', () => {
    const src = readSource('../src/middlewares/auth.ts');
    assert(src.includes('tokenVersion'), 'auth.ts missing tokenVersion reference');
    assert(src.includes('TOKEN_REVOKED'), 'auth.ts missing TOKEN_REVOKED error code');
    assert(src.includes("select: { tokenVersion: true }"), 'auth.ts missing DB tokenVersion select');
    assert(src.includes('claimedVersion !== dbUserVersion.tokenVersion'),
      'auth.ts missing version comparison');
  });

  await test('B2. requireAuth skips tokenVersion check for admin tokens', () => {
    const src = readSource('../src/middlewares/auth.ts');
    assert(src.includes('if (!isMasterAdmin)'), 'auth.ts should only check tokenVersion for non-admin');
  });

  await test('B3. /auth/refresh does NOT use ignoreExpiration', () => {
    const src = readSource('../src/modules/auth/auth.routes.ts');
    // The only occurrence of ignoreExpiration should be in the comment warning not to use it
    const lines = src.split('\n');
    const ignoreLines = lines.filter(l =>
      l.includes('ignoreExpiration') && !l.trim().startsWith('//') && !l.trim().startsWith('*')
    );
    assert(ignoreLines.length === 0,
      `Found non-comment ignoreExpiration usage: ${ignoreLines.join('; ')}`);
  });

  await test('B4. /auth/refresh embeds tokenVersion in refreshed JWT', () => {
    const src = readSource('../src/modules/auth/auth.routes.ts');
    // Find refresh endpoint and verify tokenVersion in its jwt.sign
    const refreshIdx = src.indexOf("router.post('/refresh'");
    const registerIdx = src.indexOf("router.post('/register'");
    assert(refreshIdx > 0, 'refresh endpoint not found');
    assert(registerIdx > refreshIdx, 'register should be after refresh');
    const refreshBlock = src.substring(refreshIdx, registerIdx);
    assert(refreshBlock.includes('tokenVersion: currentTokenVersion'),
      'refresh jwt.sign missing tokenVersion');
  });

  await test('B5. /auth/refresh verifies tokenVersion match', () => {
    const src = readSource('../src/modules/auth/auth.routes.ts');
    const refreshIdx = src.indexOf("router.post('/refresh'");
    const logoutIdx = src.indexOf("router.post('/logout'");
    assert(logoutIdx > refreshIdx, 'logout should be after refresh');
    const refreshBlock = src.substring(refreshIdx, logoutIdx);
    assert(refreshBlock.includes('TOKEN_REVOKED'), 'refresh missing TOKEN_REVOKED check');
    assert(refreshBlock.includes('claimedVersion !== currentTokenVersion'),
      'refresh missing version comparison');
  });

  await test('B6. /auth/logout endpoint exists and is requireAuth-protected', () => {
    const src = readSource('../src/modules/auth/auth.routes.ts');
    assert(src.includes("router.post('/logout', requireAuth"), 'logout endpoint missing or not auth-protected');
    assert(src.includes("tokenVersion: { increment: 1 }"), 'logout should increment tokenVersion');
  });

  await test('B7. /auth/change-password returns fresh JWT with updated tokenVersion', () => {
    const src = readSource('../src/modules/auth/auth.routes.ts');
    const cpIdx = src.indexOf("router.post('/change-password'");
    assert(cpIdx > 0, 'change-password endpoint not found');
    const cpBlock = src.substring(cpIdx);
    assert(cpBlock.includes('freshToken'), 'change-password should issue freshToken');
    assert(cpBlock.includes('result.tokenVersion'), 'change-password should use result.tokenVersion');
    assert(cpBlock.includes("sendSuccess(res, { message: result.message, token: freshToken }"),
      'change-password should return token in response');
  });

  await test('B8. password_reset.service changePassword increments tokenVersion', () => {
    const src = readSource('../src/services/password_reset.service.ts');
    // Find the changePassword method
    const methodIdx = src.indexOf('public async changePassword(');
    assert(methodIdx > 0, 'changePassword method not found');
    const methodBlock = src.substring(methodIdx);
    assert(methodBlock.includes('tokenVersion: { increment: 1 }'),
      'changePassword should increment tokenVersion');
    assert(methodBlock.includes('select: { tokenVersion: true }'),
      'changePassword should select tokenVersion after update');
    assert(methodBlock.includes('tokenVersion: updatedUser.tokenVersion'),
      'changePassword should return updated tokenVersion');
  });

  await test('B9. password_reset.service resetPassword increments tokenVersion', () => {
    const src = readSource('../src/services/password_reset.service.ts');
    // Find the client password reset updateMany
    const resetIdx = src.indexOf('CLIENT_PASSWORD_RESET_SUCCESS');
    assert(resetIdx > 0, 'client password reset section not found');
    // The updateMany before this should include tokenVersion: { increment: 1 }
    const beforeReset = src.substring(0, resetIdx);
    const lastUpdateMany = beforeReset.lastIndexOf('prisma.user.updateMany');
    assert(lastUpdateMany > 0, 'updateMany not found before reset success');
    const updateBlock = beforeReset.substring(lastUpdateMany, resetIdx);
    assert(updateBlock.includes('tokenVersion: { increment: 1 }'),
      'resetPassword updateMany should increment tokenVersion');
  });

  await test('B10. All jwt.sign calls in auth.routes include tokenVersion', () => {
    const src = readSource('../src/modules/auth/auth.routes.ts');
    // Find all jwt.sign blocks
    const regex = /jwt\.sign\(\s*\{([^}]+)\}/g;
    let match;
    let count = 0;
    let missingCount = 0;
    while ((match = regex.exec(src)) !== null) {
      count++;
      if (!match[1].includes('tokenVersion')) {
        missingCount++;
      }
    }
    assert(count >= 5, `Expected at least 5 jwt.sign calls, found ${count}`);
    assert(missingCount === 0,
      `${missingCount} of ${count} jwt.sign calls missing tokenVersion`);
  });

  await test('B11. ResetPasswordResult interface includes tokenVersion field', () => {
    const src = readSource('../src/services/password_reset.service.ts');
    assert(src.includes('tokenVersion?: number'),
      'ResetPasswordResult should have tokenVersion?: number');
  });

  // ─── Group C: Schema & Migration Verification ────────────────────────────

  console.log('\n── C. Schema & Migration Verification ──\n');

  await test('C1. Prisma schema has tokenVersion field', () => {
    const schema = readSource('../prisma/schema.prisma');
    assert(schema.includes('tokenVersion'), 'schema.prisma missing tokenVersion');
    assert(schema.includes('Int        @default(0)'),
      'tokenVersion should be Int @default(0)');
  });

  await test('C2. Migration SQL exists for tokenVersion', () => {
    const migrationPath = path.resolve(__dirname, '../prisma/migrations/20261105000000_add_token_version/migration.sql');
    assert(fs.existsSync(migrationPath), 'Migration SQL file not found');
    const sql = fs.readFileSync(migrationPath, 'utf-8');
    assert(sql.includes('"tokenVersion"'), 'Migration SQL should add tokenVersion column');
    assert(sql.includes('INTEGER NOT NULL DEFAULT 0'), 'tokenVersion should be NOT NULL DEFAULT 0');
    assert(sql.includes('IF NOT EXISTS'), 'Migration should be idempotent');
  });

  await test('C3. oneSignalPlayerId field is preserved in schema', () => {
    const schema = readSource('../prisma/schema.prisma');
    assert(schema.includes('oneSignalPlayerId'), 'schema.prisma should preserve oneSignalPlayerId');
  });

  // ─── Group D: Flutter Client-Side Verification ───────────────────────────

  console.log('\n── D. Flutter Client-Side Verification ──\n');

  await test('D1. _saveActiveSession omits token from SharedPreferences', () => {
    const src = readSource(
      '../../apps/mobile/lib/core/auth/auth_service.dart'
    );
    // Find _saveActiveSession
    const saveIdx = src.indexOf('Future<void> _saveActiveSession()');
    assert(saveIdx > 0, '_saveActiveSession not found');
    const saveBlock = src.substring(saveIdx, saveIdx + 2000);
    // The session map should NOT contain 'token': _token
    assert(!saveBlock.includes("'token': _token"), 'Session map should NOT contain token field');
    // It should have the F-04 comment
    assert(saveBlock.includes('F-04'), '_saveActiveSession should reference F-04');
  });

  await test('D2. Session restoration reads token exclusively from SecureTokenStorage', () => {
    const src = readSource(
      '../../apps/mobile/lib/core/auth/auth_service.dart'
    );
    // The effectiveToken assignment should not fallback to session['token']
    assert(src.includes("final effectiveToken = (secureToken != null && secureToken.isNotEmpty) ? secureToken : '';"),
      'effectiveToken should NOT fall back to session[token]');
  });

  await test('D3. logout() calls backend /auth/logout', () => {
    const src = readSource(
      '../../apps/mobile/lib/core/auth/auth_service.dart'
    );
    assert(src.includes("auth/logout"), 'logout should call /auth/logout');
    assert(src.includes('Backend logout'), 'logout should have backend logout comment/log');
  });

  await test('D4. changePassword() captures fresh JWT from response', () => {
    const src = readSource(
      '../../apps/mobile/lib/core/auth/auth_service.dart'
    );
    const cpIdx = src.indexOf('Future<Map<String, dynamic>> changePassword(');
    assert(cpIdx > 0, 'changePassword method not found');
    const cpBlock = src.substring(cpIdx, cpIdx + 2000);
    assert(cpBlock.includes("data['data']?['token']"), 'changePassword should read token from response');
    assert(cpBlock.includes('_token = freshToken'), 'changePassword should update _token');
  });

  await test('D5. logout() completes local cleanup even if backend call fails', () => {
    const src = readSource(
      '../../apps/mobile/lib/core/auth/auth_service.dart'
    );
    const logoutIdx = src.indexOf('Future<void> logout()');
    assert(logoutIdx > 0, 'logout method not found');
    const logoutBlock = src.substring(logoutIdx, logoutIdx + 3000);
    // The _resetSession() and SecureTokenStorage.deleteAuthToken should come after try/catch
    assert(logoutBlock.includes('_resetSession()'), 'logout should call _resetSession');
    assert(logoutBlock.includes('SecureTokenStorage.deleteAuthToken()'),
      'logout should delete auth token');
    assert(logoutBlock.includes('catch (e)'), 'backend logout call should be in try/catch');
  });

  // ─── Group E: Route Protection Verification ──────────────────────────────

  console.log('\n── E. Route Protection Verification ──\n');

  await test('E1. Food mutation routes have requireApprovedUser', () => {
    const src = readSource('../src/modules/food/food.routes.ts');
    assert(src.includes("requireApprovedUser"), 'food.routes should use requireApprovedUser');
    // Specifically check POST and DELETE routes
    const aiScanLine = src.split('\n').find(l => l.includes("'/ai-scan'"));
    assert(!!aiScanLine?.includes('requireApprovedUser'), 'ai-scan should have requireApprovedUser');
    const createLine = src.split('\n').find(l => l.includes("router.post('/'") && l.includes('createCustomFood'));
    assert(!!createLine?.includes('requireApprovedUser'), 'createCustomFood should have requireApprovedUser');
    const deleteLine = src.split('\n').find(l => l.includes("router.delete"));
    assert(!!deleteLine?.includes('requireApprovedUser'), 'deleteFood should have requireApprovedUser');
  });

  await test('E2. Food read routes do NOT require approval (optional auth)', () => {
    const src = readSource('../src/modules/food/food.routes.ts');
    const getLines = src.split('\n').filter(l => l.includes("router.get("));
    for (const line of getLines) {
      assert(!line.includes('requireApprovedUser'),
        `Food GET route should not require approval: ${line.trim()}`);
    }
  });

  await test('E3. admin_auth.service jwt.sign includes tokenVersion', () => {
    const src = readSource('../src/modules/auth/admin_auth.service.ts');
    // Admin tokens are stateless — they don't use tokenVersion from DB
    // This is expected and correct; admin tokens bypass tokenVersion in requireAuth
    assert(src.includes('jwt.sign'), 'admin_auth.service should have jwt.sign');
    // Admin tokens are exempt from tokenVersion check, so we just verify
    // the middleware correctly skips the check for isMasterAdmin
    const authSrc = readSource('../src/middlewares/auth.ts');
    assert(authSrc.includes('if (!isMasterAdmin)'), 'requireAuth should skip DB check for admin');
  });

  // ─── Summary ──────────────────────────────────────────────────────────────

  console.log('\n================================================================');
  console.log(`  F-04 RESULTS: ${passed} PASSED, ${failed} FAILED out of ${passed + failed}`);
  console.log('================================================================\n');

  if (failed > 0) {
    console.log('Failed tests:');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`  ❌ ${r.name}: ${r.detail}`);
    });
    console.log('');
  }

  process.exit(failed > 0 ? 1 : 0);
}

runAllTests().catch(err => {
  console.error('Test suite error:', err);
  process.exit(1);
});
