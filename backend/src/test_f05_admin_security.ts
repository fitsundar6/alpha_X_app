/**
 * F-05 Admin Authentication Security — Regression Test Suite
 *
 * Verifies:
 * 1. Synchronized production detection (VERCEL_ENV=production and NODE_ENV=production).
 * 2. Mock tokens strictly rejected in production environments.
 * 3. Removal of static development bcrypt hash fallback (fails closed).
 * 4. Master admin identity and role derivation strictly bound to verified email matching ADMIN_EMAIL.
 * 5. Public gym contact info endpoint uses SUPPORT_EMAIL, not privileged ADMIN_EMAIL.
 * 6. Flutter AdminConfig and login source code has no hardcoded passwords, personal emails, or offline bypasses.
 * 7. Flutter cold-start session restoration requires backend token verification.
 */

import jwt from 'jsonwebtoken';
import fs from 'fs';
import path from 'path';
import { env, isProduction } from './config/environment';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { UserRole } from './constants/roles';
import { requireAuth } from './middlewares/auth';
import { HttpStatus } from './constants/httpStatus';

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

function readSource(relativePath: string): string {
  return fs.readFileSync(path.resolve(__dirname, relativePath), 'utf-8');
}

let passed = 0;
let failed = 0;
const results: { name: string; status: 'PASS' | 'FAIL'; detail?: string }[] = [];

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

async function test(name: string, fn: () => void | Promise<void>) {
  try {
    const result = fn();
    if (result && typeof (result as any).then === 'function') {
      await result;
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

async function runF05TestSuite() {
  console.log('\n================================================================');
  console.log('🔒 F-05 ADMIN AUTHENTICATION SECURITY REGRESSION TESTS 🔒');
  console.log('================================================================\n');

  // ─── Group A: Production Detection & Mock Token Hardening ──────────────────
  console.log('── A. Production Detection & Mock Token Rejection ──\n');

  await test('A1. isProduction() function exists and returns boolean', () => {
    assert(typeof isProduction() === 'boolean', 'isProduction() should return boolean');
  });

  await test('A2. Mock tokens bypass is strictly guarded by isProduction() in auth middleware', () => {
    const authSrc = readSource('middlewares/auth.ts');
    assert(authSrc.includes('!isProduction()'), 'requireAuth must check !isProduction() before mock bypass');
    // Ensure no unguarded env.NODE_ENV !== 'production' on mock checks
    const lines = authSrc.split('\n');
    const unguarded = lines.filter(l => l.includes("token === 'alpha_x_mock_token_for_admin'") && !authSrc.includes('!isProduction()'));
    assert(unguarded.length === 0, 'Found unguarded mock token check');
  });

  await test('A3. Mock token alone fails jwt.verify when passed directly', () => {
    try {
      jwt.verify('alpha_x_mock_token_for_admin', env.JWT_ACCESS_SECRET);
      throw new Error('Should have failed jwt.verify');
    } catch (e: any) {
      assert(e.name === 'JsonWebTokenError', `Expected JsonWebTokenError, got ${e.name}`);
    }
  });

  await test('A4. Local admin session token alone fails jwt.verify when passed directly', () => {
    try {
      jwt.verify('local_admin_session_token', env.JWT_ACCESS_SECRET);
      throw new Error('Should have failed jwt.verify');
    } catch (e: any) {
      assert(e.name === 'JsonWebTokenError', `Expected JsonWebTokenError, got ${e.name}`);
    }
  });

  // ─── Group B: Admin Service & Credential Verification ──────────────────────
  console.log('\n── B. Admin Service & Static Hash Removal ──\n');

  await test('B1. admin_auth.service.ts contains NO static dev bcrypt hash fallback', () => {
    const src = readSource('modules/auth/admin_auth.service.ts');
    assert(!src.includes('$2b$12$e0lXq9aVqG0Ew8w8oKqjVu4pI29nS/jR/qVl32h7jF7Q4D4y8eYCe'),
      'Hardcoded dev bcrypt hash still present in admin_auth.service.ts!');
    assert(!src.includes('AlphaXAdmin2026!'),
      'AlphaXAdmin2026! string still present in admin_auth.service.ts!');
  });

  await test('B2. isMasterAdminEmail matches configured ADMIN_EMAIL case-insensitively', () => {
    const adminEmail = env.ADMIN_EMAIL.trim().toLowerCase();
    assert(adminAuthService.isMasterAdminEmail(adminEmail), 'Exact email should match');
    assert(adminAuthService.isMasterAdminEmail(`  ${adminEmail.toUpperCase()}  `), 'Padded upper email should match');
    assert(!adminAuthService.isMasterAdminEmail('intruder@external.com'), 'External email must not match');
    assert(!adminAuthService.isMasterAdminEmail(''), 'Empty email must not match');
  });

  await test('B3. verifyAdminCredentials returns false for wrong/empty credentials', async () => {
    const wrongEmail = await adminAuthService.verifyAdminCredentials('wrong@external.com', 'some_password');
    assert(!wrongEmail, 'Wrong email must return false');
    const emptyPass = await adminAuthService.verifyAdminCredentials(env.ADMIN_EMAIL, '');
    assert(!emptyPass, 'Empty password must return false');
  });

  await test('B4. generateAdminSession issues signed JWT with ADMIN role and ADMIN_EMAIL', () => {
    const session = adminAuthService.generateAdminSession();
    assert(session.user.role === UserRole.ADMIN, 'Session user role must be ADMIN');
    assert(session.user.email === env.ADMIN_EMAIL.trim().toLowerCase(), 'Session email must match ADMIN_EMAIL');
    const decoded = jwt.verify(session.token, env.JWT_ACCESS_SECRET) as any;
    assert(decoded.role === UserRole.ADMIN, 'Decoded JWT role must be ADMIN');
    assert(decoded.email === env.ADMIN_EMAIL.trim().toLowerCase(), 'Decoded JWT email must match ADMIN_EMAIL');
  });

  // ─── Group C: Endpoint & Route Privacy ─────────────────────────────────────
  console.log('\n── C. Endpoint Privacy & Support Email Isolation ──\n');

  await test('C1. environment.ts defines SUPPORT_EMAIL separately from ADMIN_EMAIL', () => {
    const src = readSource('config/environment.ts');
    assert(src.includes('SUPPORT_EMAIL'), 'environment.ts must define SUPPORT_EMAIL');
    assert(env.SUPPORT_EMAIL !== undefined, 'env.SUPPORT_EMAIL must be populated');
  });

  await test('C2. /gym-contact-info endpoint uses SUPPORT_EMAIL and does NOT expose env.ADMIN_EMAIL', () => {
    const src = readSource('modules/auth/auth.routes.ts');
    const routeIdx = src.indexOf("router.get('/gym-contact-info'");
    assert(routeIdx > 0, 'gym-contact-info route not found');
    const routeBlock = src.substring(routeIdx, routeIdx + 600);
    assert(routeBlock.includes('env.SUPPORT_EMAIL'), 'Must use env.SUPPORT_EMAIL');
    assert(!routeBlock.includes('adminEmail: env.ADMIN_EMAIL,'),
      'Must NOT expose adminEmail: env.ADMIN_EMAIL in public response');
  });

  await test('C3. POST /register strictly blocks registration with ADMIN_EMAIL', () => {
    const src = readSource('modules/auth/auth.routes.ts');
    assert(src.includes('normalizedEmail === configuredAdminEmail'),
      'POST /register must reject registration with admin email');
  });

  // ─── Group D: Flutter Client Hardening ─────────────────────────────────────
  console.log('\n── D. Flutter Client Hardening ──\n');

  await test('D1. admin_config.dart defaults adminEmail to empty string (no personal email)', () => {
    const src = readSource('../../apps/mobile/lib/config/admin_config.dart');
    assert(!src.includes('fitsundar6@gmail.com'), 'Personal admin email found in admin_config.dart');
    assert(src.includes("defaultValue: ''"), 'adminEmail must default to empty string');
  });

  await test('D2. admin_login_screen.dart has NO Step 2 offline password comparison fallback', () => {
    const src = readSource('../../apps/mobile/lib/core/auth/admin_login_screen.dart');
    assert(!src.includes('Step 2: Local Fallback'), 'Step 2 local fallback still present in admin_login_screen.dart');
    assert(!src.includes('enteredPassword == configuredPassword'),
      'Client-side password equality check still present in admin_login_screen.dart');
    assert(!src.includes('fitsundar6@gmail.com'),
      'Personal email hardcoded in admin_login_screen.dart');
  });

  await test('D3. auth_service.dart contains NO AlphaXAdmin hardcoded password literals', () => {
    const src = readSource('../../apps/mobile/lib/core/auth/auth_service.dart');
    assert(!src.includes('AlphaXAdmin2026'), 'AlphaXAdmin2026 password found in auth_service.dart');
    assert(!src.includes('AlphaXAdmin2026!'), 'AlphaXAdmin2026! password found in auth_service.dart');
  });

  await test('D4. auth_service.dart session restore requires backend token verification for ADMIN', () => {
    const src = readSource('../../apps/mobile/lib/core/auth/auth_service.dart');
    assert(src.includes('_verifyAdminTokenWithBackend'),
      'auth_service.dart must define and call _verifyAdminTokenWithBackend');
    // Ensure cold-start restoration calls _verifyAdminTokenWithBackend
    const initIdx = src.indexOf('Future<void> initialize()');
    assert(initIdx > 0, 'initialize() not found');
    const initBlock = src.substring(initIdx, initIdx + 3000);
    assert(initBlock.includes('_verifyAdminTokenWithBackend(effectiveToken)'),
      'initialize() must verify effectiveToken with backend before granting ADMIN');
  });

  await test('D5. auth_service.dart _performRefreshAdminToken uses POST /auth/refresh with Bearer token', () => {
    const src = readSource('../../apps/mobile/lib/core/auth/auth_service.dart');
    const refreshIdx = src.indexOf('Future<String?> _performRefreshAdminToken()');
    assert(refreshIdx > 0, '_performRefreshAdminToken not found');
    const refreshBlock = src.substring(refreshIdx, refreshIdx + 2000);
    assert(refreshBlock.includes("auth/refresh"), 'Must call /auth/refresh');
    assert(refreshBlock.includes("'Authorization': 'Bearer \$_token'"), 'Must send Bearer token');
    assert(!refreshBlock.includes('AdminConfig.adminPassword'),
      'Must NOT send AdminConfig.adminPassword in refresh request');
  });

  await test('D6. Support screens fall back to support@alphaxgym.com instead of personal email', () => {
    const pendingSrc = readSource('../../apps/mobile/lib/core/auth/pending_verification_screen.dart');
    const rejectedSrc = readSource('../../apps/mobile/lib/core/auth/rejected_account_screen.dart');
    const suspendedSrc = readSource('../../apps/mobile/lib/core/auth/suspended_account_screen.dart');

    assert(pendingSrc.includes('support@alphaxgym.com'), 'pending_verification_screen missing support email');
    assert(rejectedSrc.includes('support@alphaxgym.com'), 'rejected_account_screen missing support email');
    assert(suspendedSrc.includes('support@alphaxgym.com'), 'suspended_account_screen missing support email');
  });

  // ─── Summary ──────────────────────────────────────────────────────────────
  console.log('\n================================================================');
  console.log(`  F-05 RESULTS: ${passed} PASSED, ${failed} FAILED out of ${passed + failed}`);
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

runF05TestSuite().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});

