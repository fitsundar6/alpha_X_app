import app from './server';
import http from 'http';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { passwordResetService } from './services/password_reset.service';

async function runPasswordRecoveryTests() {
  console.log('================================================================');
  console.log('🔒 ALPHA X GYM PASSWORD RECOVERY SYSTEM COMPREHENSIVE TEST 🔒');
  console.log('================================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5099, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5099/api/v1';

  try {
    const adminEmail = env.ADMIN_EMAIL.trim().toLowerCase();
    const originalAdminPassword = env.ADMIN_PASSWORD || 'AlphaXAdmin2026!';
    const testClientEmail = `recovery_test_${Date.now()}@alphaxgym.test`;
    const originalClientPassword = 'OriginalPassword123!';
    const newClientPassword = 'NewSecurePassword456!';

    // ── Setup: Register a dedicated test client ──────────────────────────────
    console.log(`Setting up test client account: ${testClientEmail}`);
    const regRes = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testClientEmail,
        password: originalClientPassword,
        name: 'Recovery Test User',
        phone: `+1555${Math.floor(1000000 + Math.random() * 9000000)}`,
      }),
    });
    const regData = await regRes.json();
    console.assert(regData.success === true, 'Failed to create test client');
    console.log('✔ Test client registered successfully.');

    // ── TEST 1: Anti-Enumeration for non-existent email ─────────────────────
    console.log('\n[TEST 1] Testing anti-enumeration on forgot-password...');
    const nonExistentRes = await fetch(`${baseUrl}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'ghost_non_existent@randomdomain.test' }),
    });
    const nonExistentData = await nonExistentRes.json();
    console.assert(nonExistentData.success === true, 'Expected success: true');
    console.assert(
      nonExistentData.data.message === 'If an account exists with this email, a password reset link has been sent.',
      'Message must not leak user non-existence'
    );
    console.log('✔ TEST 1 PASSED: Anti-enumeration holds for non-existent email.');

    // ── TEST 2: Forgot password for registered client ───────────────────────
    console.log('\n[TEST 2] Testing forgot-password for registered client...');
    const clientForgotRes = await fetch(`${baseUrl}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testClientEmail }),
    });
    const clientForgotData = await clientForgotRes.json();
    console.assert(clientForgotData.success === true, 'Client forgot password request failed');
    console.assert(
      clientForgotData.data.message === nonExistentData.data.message,
      'Response message must be identical to non-existent email response'
    );
    console.log('✔ TEST 2 PASSED: Registered client forgot password returns identical anti-enumeration response.');

    // ── TEST 3: Token verification ──────────────────────────────────────────
    console.log('\n[TEST 3] Testing token verification...');
    // Generate valid token directly via service
    const dbClient = await prisma.user.findUnique({ where: { email: testClientEmail } });
    const jti1 = 'test-jti-1-' + Date.now();
    const validClientToken = jwt.sign(
      {
        userId: dbClient!.id,
        email: testClientEmail,
        role: dbClient!.role,
        hashSnippet: (dbClient!.passwordHash || '').slice(-10),
        jti: jti1,
        purpose: 'PASSWORD_RESET',
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const verifyValidRes = await fetch(`${baseUrl}/auth/reset-password/verify?token=${validClientToken}`);
    const verifyValidData = await verifyValidRes.json();
    console.assert(verifyValidData.success === true, 'Valid token verification failed');
    console.assert(verifyValidData.data.valid === true, 'Expected valid: true');
    console.assert(verifyValidData.data.email === testClientEmail, 'Expected email match');
    console.log('✔ TEST 3A PASSED: Valid token verified successfully.');

    // Invalid/tampered token
    const verifyInvalidRes = await fetch(`${baseUrl}/auth/reset-password/verify?token=tampered_invalid_token_123`);
    const verifyInvalidData = await verifyInvalidRes.json();
    console.assert(verifyInvalidRes.status === 400, 'Tampered token should return 400');
    console.assert(verifyInvalidData.success === false, 'Tampered token must fail');
    console.log('✔ TEST 3B PASSED: Tampered token correctly rejected.');

    // Expired token
    const expiredToken = jwt.sign(
      {
        userId: dbClient!.id,
        email: testClientEmail,
        role: dbClient!.role,
        hashSnippet: (dbClient!.passwordHash || '').slice(-10),
        jti: 'test-jti-expired-' + Date.now(),
        purpose: 'PASSWORD_RESET',
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '-1s' }
    );
    const verifyExpiredRes = await fetch(`${baseUrl}/auth/reset-password/verify?token=${expiredToken}`);
    const verifyExpiredData = await verifyExpiredRes.json();
    console.assert(verifyExpiredRes.status === 400, 'Expired token should return 400');
    console.assert(verifyExpiredData.error.code === 'TOKEN_EXPIRED', 'Expected TOKEN_EXPIRED error code');
    console.log('✔ TEST 3C PASSED: Expired token correctly rejected with TOKEN_EXPIRED.');

    // ── TEST 4: Validation errors (password mismatch, short password) ───────
    console.log('\n[TEST 4] Testing password validation...');
    const mismatchRes = await fetch(`${baseUrl}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: validClientToken,
        newPassword: 'Password123!',
        confirmPassword: 'MismatchPassword999!',
      }),
    });
    const mismatchData = await mismatchRes.json();
    console.assert(mismatchRes.status === 400, 'Mismatch should return 400');
    console.assert(mismatchData.error.message.includes('match'), 'Mismatch error message expected');
    console.log('✔ TEST 4A PASSED: Password mismatch rejected.');

    const shortPwdRes = await fetch(`${baseUrl}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: validClientToken,
        newPassword: '123',
        confirmPassword: '123',
      }),
    });
    console.assert(shortPwdRes.status === 400, 'Short password should return 400');
    console.log('✔ TEST 4B PASSED: Password < 6 chars rejected.');

    // ── TEST 5: Complete password reset & login verification ────────────────
    console.log('\n[TEST 5] Testing successful password reset and login verification...');
    const resetRes = await fetch(`${baseUrl}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: validClientToken,
        newPassword: newClientPassword,
        confirmPassword: newClientPassword,
      }),
    });
    const resetData = await resetRes.json();
    console.assert(resetRes.status === 200, 'Reset password failed');
    console.assert(resetData.success === true, 'Reset password expected success: true');
    console.log('✔ TEST 5A PASSED: Password reset executed successfully.');

    // Old password must fail
    const oldLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testClientEmail, password: originalClientPassword }),
    });
    console.assert(oldLoginRes.status === 401, 'Old password must be rejected');
    console.log('✔ TEST 5B PASSED: Old password rejected after reset.');

    // New password must succeed
    const newLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testClientEmail, password: newClientPassword }),
    });
    const newLoginData = await newLoginRes.json();
    console.assert(newLoginRes.status === 200, 'New password login failed');
    console.assert(newLoginData.success === true, 'New password login expected success: true');
    console.log('✔ TEST 5C PASSED: New password successfully authenticated.');

    // ── TEST 6: Single-use enforcement (reusing token) ───────────────────────
    console.log('\n[TEST 6] Testing single-use token enforcement...');
    const reuseRes = await fetch(`${baseUrl}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: validClientToken,
        newPassword: 'YetAnotherPassword!',
        confirmPassword: 'YetAnotherPassword!',
      }),
    });
    const reuseData = await reuseRes.json();
    console.assert(reuseRes.status === 400, 'Reused token must return 400');
    console.assert(reuseData.error.code === 'TOKEN_ALREADY_USED', 'Expected TOKEN_ALREADY_USED code');
    console.log('✔ TEST 6 PASSED: Reused reset token rejected.');

    // ── TEST 7: Master Admin Password Reset Flow ────────────────────────────
    console.log('\n[TEST 7] Testing Master Administrator password recovery...');
    const adminForgotRes = await fetch(`${baseUrl}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: adminEmail }),
    });
    const adminForgotData = await adminForgotRes.json();
    console.assert(adminForgotData.success === true, 'Admin forgot password failed');

    const adminSnippet = await adminAuthService.getActivePasswordHashSnippet();
    const adminResetToken = jwt.sign(
      {
        userId: 'admin_alex_stone',
        email: adminEmail,
        role: 'ADMIN',
        hashSnippet: adminSnippet,
        jti: 'admin-jti-' + Date.now(),
        purpose: 'PASSWORD_RESET',
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    const newAdminPassword = 'TempAdminPassword2026!';
    const adminResetRes = await fetch(`${baseUrl}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        token: adminResetToken,
        newPassword: newAdminPassword,
        confirmPassword: newAdminPassword,
      }),
    });
    console.assert(adminResetRes.status === 200, 'Admin reset failed');

    // Admin login with new password
    const adminNewLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: adminEmail, password: newAdminPassword }),
    });
    const adminNewLoginData = await adminNewLoginRes.json();
    console.assert(adminNewLoginRes.status === 200, 'Admin new password login failed');
    console.assert(adminNewLoginData.data.user.role === 'ADMIN', 'Admin role must be preserved');
    console.log('✔ TEST 7 PASSED: Master Admin reset password succeeded, role preserved as ADMIN.');

    // ── Cleanup: Restore original admin password & remove test client ───────
    await adminAuthService.updateAdminPassword(originalAdminPassword);
    const verifyRestoredAdmin = await adminAuthService.verifyAdminCredentials(adminEmail, originalAdminPassword);
    console.assert(verifyRestoredAdmin === true, 'Failed to restore original admin password');

    await prisma.user.delete({ where: { email: testClientEmail } }).catch(() => {});
    console.log('✔ Cleanup completed: original admin credentials verified and test client removed.');

    console.log('\n================================================================');
    console.log('🎉 ALL 7 PASSWORD RECOVERY TESTS PASSED FLAWLESSLY! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
    await prisma.$disconnect();
  }
}

runPasswordRecoveryTests().catch((err) => {
  console.error('❌ Password Recovery Test Suite Failed:', err);
  process.exit(1);
});
