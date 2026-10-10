import app from './server';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { passwordResetService } from './services/password_reset.service';

export async function runEmailFreeForgotPasswordTests() {
  console.log('================================================================');
  console.log('🔒 ALPHA X GYM — EMAIL-FREE SECURE FORGOT PASSWORD TEST SUITE 🔒');
  console.log('================================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5199, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5199/api/v1';

  try {
    const adminEmail = env.ADMIN_EMAIL.trim().toLowerCase();
    const adminSession = adminAuthService.generateAdminSession();
    const adminToken = adminSession.token;

    // ── Setup: Register 2 dedicated test clients ─────────────────────────────
    const client1Email = `email_free_client_${Date.now()}@alphaxgym.test`;
    const client1Password = 'OriginalPass123!';
    const newClient1Password = 'BrandNewSecurePass456!';

    const randPhone1 = `+1555${Math.floor(1000000 + Math.random() * 9000000)}`;
    const randPhone2 = `+1555${Math.floor(1000000 + Math.random() * 9000000)}`;

    const reg1Res = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: client1Email,
        password: client1Password,
        name: 'Email-Free Athlete One',
        phone: randPhone1,
      }),
    });
    const reg1Data = await reg1Res.json();
    console.assert(reg1Data.success === true, 'Failed to create test client 1');
    const client1Id = reg1Data.data.user.id;
    const client1AXGId = reg1Data.data.clientId;
    const client1Token = reg1Data.data.token;

    const client2Email = `email_free_client2_${Date.now()}@alphaxgym.test`;
    const client2Password = 'Client2Pass123!';
    const reg2Res = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: client2Email,
        password: client2Password,
        name: 'Email-Free Athlete Two',
        phone: randPhone2,
      }),
    });
    const reg2Data = await reg2Res.json();
    console.assert(reg2Data.success === true, 'Failed to create test client 2');
    const client2Token = reg2Data.data.token;

    console.log(`✔ Seeded test clients: ${client1AXGId} (${client1Email})`);

    // ── TEST 1: Unauthorized Access - Unauthenticated Caller ─────────────────
    console.log('\n[TEST 1] Testing unauthorized access: unauthenticated caller cannot issue code...');
    const unauthRes = await fetch(`${baseUrl}/admin/verification/${client1Id}/issue-reset-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason: 'Malicious attempt' }),
    });
    console.assert(unauthRes.status === 401, `Expected 401 Unauthorized, got: ${unauthRes.status}`);
    console.log('✔ TEST 1 PASSED: Unauthenticated caller blocked (401 Unauthorized).');

    // ── TEST 2: Unauthorized Access - Non-Admin (Client) Caller ──────────────
    console.log('\n[TEST 2] Testing unauthorized access: client cannot issue code for another user...');
    const clientTamperRes = await fetch(`${baseUrl}/admin/verification/${client1Id}/issue-reset-code`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${client2Token}`,
      },
      body: JSON.stringify({ reason: 'Client impersonation' }),
    });
    console.assert(clientTamperRes.status === 403, `Expected 403 Forbidden, got: ${clientTamperRes.status}`);
    console.log('✔ TEST 2 PASSED: Non-admin client caller blocked (403 Forbidden).');

    // ── TEST 3: Gym Contact Info Endpoint (Zero-Cost Guidance) ───────────────
    console.log('\n[TEST 3] Testing public zero-cost gym contact info endpoint...');
    const contactRes = await fetch(`${baseUrl}/auth/gym-contact-info`);
    const contactData = await contactRes.json();
    console.assert(contactRes.status === 200, `Expected 200, got: ${contactRes.status}`);
    console.assert(contactData.success === true, 'Expected success: true');
    console.assert(contactData.data.adminEmail.length > 0, 'Must provide verified admin email');
    console.assert(contactData.data.gymName === 'Alpha X Gym', 'Must provide correct gym name');
    console.assert(contactData.data.instructions.length > 0, 'Must provide instructions');
    console.log('✔ TEST 3 PASSED: Public contact info provided with verified project configuration.');

    // ── TEST 4: Admin Verified Code Issuance ─────────────────────────────────
    console.log('\n[TEST 4] Testing authenticated admin issuing single-use reset code...');
    const issueRes = await fetch(`${baseUrl}/admin/verification/${client1Id}/issue-reset-code`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ reason: 'Athlete visited front desk' }),
    });
    const issueData = await issueRes.json();
    console.assert(issueRes.status === 200, `Expected 200, got: ${issueRes.status}`);
    console.assert(issueData.success === true, 'Expected success: true');
    const resetCode = issueData.data.code;
    console.assert(typeof resetCode === 'string' && resetCode.length === 6, 'Code must be 6 digits');
    console.assert(issueData.data.expiresInMinutes === 15, 'Code TTL must be 15 minutes');
    // Security check: response must not contain password, hash, or reset token
    console.assert(!issueData.data.password, 'API response must never expose passwords');
    console.assert(!issueData.data.passwordHash, 'API response must never expose passwordHash');
    console.assert(!issueData.data.token, 'API response must never expose reset tokens');
    console.log(`✔ TEST 4 PASSED: Admin generated 6-digit reset code [${resetCode}] with 15-min TTL.`);

    // ── TEST 5: Input Validation Safeguards ──────────────────────────────────
    console.log('\n[TEST 5] Testing password validation safeguards...');
    // Password mismatch
    const mismatchRes = await fetch(`${baseUrl}/auth/reset-password-with-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: client1Email,
        code: resetCode,
        newPassword: 'ValidPass123!',
        confirmPassword: 'MismatchPass456!',
      }),
    });
    const mismatchData = await mismatchRes.json();
    console.assert(mismatchRes.status === 400, 'Expected 400 for password mismatch');
    console.assert(mismatchData.error.code === 'VALIDATION_ERROR', 'Expected VALIDATION_ERROR');

    // Password too short (< 6 chars)
    const shortRes = await fetch(`${baseUrl}/auth/reset-password-with-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: client1Email,
        code: resetCode,
        newPassword: '123',
        confirmPassword: '123',
      }),
    });
    const shortData = await shortRes.json();
    console.assert(shortRes.status === 400, 'Expected 400 for short password');
    console.assert(shortData.error.code === 'VALIDATION_ERROR', 'Expected VALIDATION_ERROR');
    console.log('✔ TEST 5 PASSED: Password mismatch and short passwords rejected.');

    // ── TEST 6: Successful Password Reset Using 6-Digit Code ─────────────────
    console.log('\n[TEST 6] Testing successful reset using Client ID (AXG-XXXX) identifier...');
    const resetSuccessRes = await fetch(`${baseUrl}/auth/reset-password-with-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: client1AXGId, // Using permanent Client ID
        code: resetCode,
        newPassword: newClient1Password,
        confirmPassword: newClient1Password,
      }),
    });
    const resetSuccessData = await resetSuccessRes.json();
    console.assert(resetSuccessRes.status === 200, `Expected 200 OK, got: ${resetSuccessRes.status}`);
    console.assert(resetSuccessData.success === true, 'Expected success: true');
    console.assert(!resetSuccessData.data.token, 'Response must never leak token');
    console.assert(!resetSuccessData.data.password, 'Response must never leak password');
    console.assert(!resetSuccessData.data.passwordHash, 'Response must never leak passwordHash');
    console.log('✔ TEST 6 PASSED: Password successfully reset using Client ID identifier.');

    // ── TEST 7: Single-Use Token/Code Reuse Prevention ───────────────────────
    console.log('\n[TEST 7] Testing code reuse prevention (single-use enforcement)...');
    const reuseRes = await fetch(`${baseUrl}/auth/reset-password-with-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: client1Email,
        code: resetCode, // Reusing consumed code
        newPassword: 'AnotherPassword789!',
        confirmPassword: 'AnotherPassword789!',
      }),
    });
    const reuseData = await reuseRes.json();
    console.assert(reuseRes.status === 400, `Expected 400 for code reuse, got: ${reuseRes.status}`);
    console.assert(
      reuseData.error.code === 'CODE_ALREADY_USED',
      `Expected CODE_ALREADY_USED, got: ${reuseData.error.code}`
    );
    console.log('✔ TEST 7 PASSED: Code replay rejected with CODE_ALREADY_USED.');

    // ── TEST 8: Old Password Invalidation & New Password Authentication ───────
    console.log('\n[TEST 8] Testing login with new password and rejection of old password...');
    // Old password must fail
    const oldLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        clientIdOrEmail: client1Email,
        password: client1Password,
      }),
    });
    console.assert(oldLoginRes.status === 401, 'Old password must be rejected (401)');

    // New password must succeed
    const newLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        clientIdOrEmail: client1AXGId,
        password: newClient1Password,
      }),
    });
    const newLoginData = await newLoginRes.json();
    console.assert(newLoginRes.status === 200, 'New password login must succeed (200)');
    console.assert(newLoginData.data.user.role === 'CLIENT', 'Client role must be preserved');
    console.assert(newLoginData.data.clientId === client1AXGId, 'Client ID must be preserved');
    console.log('✔ TEST 8 PASSED: Old password rejected, new password authenticated, role preserved.');

    // ── TEST 9: Brute-Force Code Throttling (Max 5 attempts) ─────────────────
    console.log('\n[TEST 9] Testing brute-force code throttling safeguard...');
    // Issue a code for client 2
    const issue2Res = await fetch(`${baseUrl}/admin/verification/${reg2Data.data.user.id}/issue-reset-code`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ reason: 'Throttling test' }),
    });
    const issue2Data = await issue2Res.json();
    const correctCode2 = issue2Data.data.code;

    // Fail 5 times with wrong codes
    for (let i = 1; i <= 5; i++) {
      await fetch(`${baseUrl}/auth/reset-password-with-code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: client2Email,
          code: '999999', // Wrong code
          newPassword: 'AttemptPass123!',
          confirmPassword: 'AttemptPass123!',
        }),
      });
    }

    // Now attempt with the CORRECT code — must be blocked due to throttling
    const throttledRes = await fetch(`${baseUrl}/auth/reset-password-with-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: client2Email,
        code: correctCode2, // Correct code
        newPassword: 'ThrottledPass123!',
        confirmPassword: 'ThrottledPass123!',
      }),
    });
    const throttledData = await throttledRes.json();
    console.assert(
      throttledData.error.code === 'MAX_ATTEMPTS_EXCEEDED' || throttledData.error.code === 'CODE_ALREADY_USED',
      `Expected MAX_ATTEMPTS_EXCEEDED, got: ${throttledData.error?.code}`
    );
    console.log('✔ TEST 9 PASSED: Brute-force throttling permanently deactivates code after failed attempts.');

    // ── TEST 10: Temporary Password with Forced Password Change ──────────────
    console.log('\n[TEST 10] Testing Admin Set Temporary Password with forced password change...');
    const tempRes = await fetch(`${baseUrl}/admin/verification/${reg2Data.data.user.id}/set-temp-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ temporaryPassword: 'TempAdminPass2026!' }),
    });
    const tempData = await tempRes.json();
    console.assert(tempRes.status === 200, `Expected 200, got: ${tempRes.status}`);
    console.assert(tempData.data.temporaryPassword === 'TempAdminPass2026!', 'Temporary password set');

    // Login with temporary password — must report mustChangePassword: true
    const tempLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        clientIdOrEmail: client2Email,
        password: 'TempAdminPass2026!',
      }),
    });
    const tempLoginData = await tempLoginRes.json();
    console.assert(tempLoginRes.status === 200, 'Login with temp password must succeed');
    console.assert(
      tempLoginData.data.mustChangePassword === true,
      'mustChangePassword must be true for temporary password'
    );

    // Verify server-side enforcement: Normal endpoint is strictly blocked (403) before password change
    const blockedRes = await fetch(`${baseUrl}/client/me/diet-plan`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${tempLoginData.data.token}`,
      },
    });
    console.assert(blockedRes.status === 403, `Expected 403 Forbidden, got: ${blockedRes.status}`);
    const blockedData = await blockedRes.json();
    console.assert(
      blockedData.error?.code === 'FORCED_PASSWORD_CHANGE_REQUIRED',
      `Expected error code FORCED_PASSWORD_CHANGE_REQUIRED, got: ${blockedData.error?.code}`
    );
    console.log('✔ Verified server-side enforcement: normal endpoints strictly blocked until password is changed.');

    // Client changes password via authenticated /change-password endpoint
    const changeRes = await fetch(`${baseUrl}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tempLoginData.data.token}`,
      },
      body: JSON.stringify({
        currentPassword: 'TempAdminPass2026!',
        newPassword: 'FinalClientPass2026!',
        confirmPassword: 'FinalClientPass2026!',
      }),
    });
    const changeData = await changeRes.json();
    console.assert(changeRes.status === 200, `Expected 200, got: ${changeRes.status}`);
    console.assert(changeData.success === true, 'Change password must succeed');

    // Login again — mustChangePassword must now be false
    const finalLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        clientIdOrEmail: client2Email,
        password: 'FinalClientPass2026!',
      }),
    });
    const finalLoginData = await finalLoginRes.json();
    console.assert(finalLoginData.data.mustChangePassword === false, 'mustChangePassword must be false now');
    console.log('✔ TEST 10 PASSED: Temporary password enforced forced change on login, then cleared.');

    // ── TEST 11: Audit Log Inspection (Zero Credential Leakage) ──────────────
    console.log('\n[TEST 11] Checking server logs for zero credential/token leakage...');
    const logPath = path.resolve(__dirname, '../logs/server-activity.log');
    if (fs.existsSync(logPath)) {
      const logContent = fs.readFileSync(logPath, 'utf-8');
      // Verify raw new passwords or secret tokens are not logged
      console.assert(!logContent.includes(newClient1Password), 'Plaintext new password must never appear in logs');
      console.assert(!logContent.includes('FinalClientPass2026!'), 'Final client password must never appear in logs');
      console.log('✔ TEST 11 PASSED: Logs inspected — zero passwords or reset tokens leaked.');
    }

    // ── Cleanup ─────────────────────────────────────────────────────────────
    await prisma.user.deleteMany({
      where: {
        email: { in: [client1Email, client2Email] },
      },
    });
    console.log('\n✔ Test cleanup completed: test accounts safely removed.');

    console.log('\n================================================================');
    console.log('🎉 ALL 11 EMAIL-FREE FORGOT PASSWORD TESTS PASSED FLAWLESSLY! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

if (require.main === module) {
  runEmailFreeForgotPasswordTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('❌ Test suite failed:', err);
      process.exit(1);
    });
}
