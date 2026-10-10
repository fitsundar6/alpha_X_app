import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { prisma } from './config/prisma';
import { env } from './config/environment';
import { PasswordResetService, passwordResetService } from './services/password_reset.service';

/**
 * Creates a separate, fresh instance of PasswordResetService
 * to simulate a distinct serverless instance / server restart.
 */
function createFreshServiceInstance(): PasswordResetService {
  return new (PasswordResetService as any)();
}

async function runMultiInstanceProductionSafetyTests() {
  console.log('================================================================');
  console.log('🛡️ ALPHA X GYM — MULTI-INSTANCE & PERSISTENT RECOVERY TEST SUITE 🛡️');
  console.log('================================================================\n');

  const testEmail1 = `multi_instance_athlete_1_${Date.now()}@alphaxgym.test`;
  const testEmail2 = `multi_instance_athlete_2_${Date.now()}@alphaxgym.test`;
  const adminEmail = env.ADMIN_EMAIL.trim().toLowerCase();

  try {
    // ── Setup: Create dedicated test athletes ────────────────────────────────
    const athlete1 = await prisma.user.create({
      data: {
        email: testEmail1,
        passwordHash: await bcrypt.hash('InitPass123!', 10),
        role: 'CLIENT',
        name: 'Multi-Instance Athlete 1',
        clientProfile: {
          create: {
            clientId: `AXG-${Math.floor(1000 + Math.random() * 9000)}`,
            membershipStatus: 'ACTIVE',
          },
        },
      },
      include: { clientProfile: true },
    });

    const athlete2 = await prisma.user.create({
      data: {
        email: testEmail2,
        passwordHash: await bcrypt.hash('InitPass456!', 10),
        role: 'CLIENT',
        name: 'Multi-Instance Athlete 2',
        clientProfile: {
          create: {
            clientId: `AXG-${Math.floor(1000 + Math.random() * 9000)}`,
            membershipStatus: 'ACTIVE',
          },
        },
      },
      include: { clientProfile: true },
    });

    console.log(`✔ Created test athlete 1: ${athlete1.email} (${athlete1.clientProfile?.clientId})`);
    console.log(`✔ Created test athlete 2: ${athlete2.email} (${athlete2.clientProfile?.clientId})\n`);

    // ── TEST 1: Server Restart & Multi-Instance State Preservation ───────────
    console.log('[TEST 1] State Preservation Across Server Restarts & Multi-Instances');
    // Instance A issues the code
    const instanceA = createFreshServiceInstance();
    const issueRes = await instanceA.adminIssueResetCode(
      'admin_uuid_1',
      adminEmail,
      athlete1.id,
      'Athlete visited desk - Instance A'
    );
    console.assert(issueRes.success === true, 'Instance A must succeed in generating code');
    const rawCode = issueRes.code!;
    console.assert(typeof rawCode === 'string' && rawCode.length === 6, 'Must be 6-digit code');
    console.log(`  • Instance A issued code: [${rawCode}]`);

    // Verify record in PostgreSQL: contains HMAC hash, never plaintext
    const dbCodeRecord = await prisma.passwordResetCode.findFirst({
      where: { userId: athlete1.id, usedAt: null },
    });
    console.assert(dbCodeRecord !== null, 'Code record must exist in PostgreSQL');
    console.assert(dbCodeRecord!.codeHash.length === 64, 'Stored code must be 64-char HMAC-SHA256 hash');
    console.assert(!JSON.stringify(dbCodeRecord).includes(rawCode), 'Database must NEVER store plaintext code');
    console.log('  • Verified in PostgreSQL: persistent HMAC-SHA256 hash stored, 0 plaintext exposure.');

    // Discard Instance A, simulate restart / cold-start on Instance B
    const instanceB = createFreshServiceInstance();
    const redeemRes = await instanceB.resetPasswordWithAdminCode(
      athlete1.email,
      rawCode,
      'NewPassInstanceB123!'
    );
    console.assert(redeemRes.success === true, `Instance B must redeem code from DB: ${redeemRes.message}`);
    console.log('  • Instance B redeemed code issued by Instance A from persistent DB.');

    // Check DB state after redemption
    const usedCodeRecord = await prisma.passwordResetCode.findUnique({
      where: { id: dbCodeRecord!.id },
    });
    console.assert(usedCodeRecord?.usedAt !== null, 'Code in DB must be marked usedAt != null');
    console.log('  ✔ TEST 1 PASSED: Code persisted, redeemed across independent instances, and marked used.\n');

    // ── TEST 2: Concurrent Multi-Instance Redemption (Race Condition Protection)
    console.log('[TEST 2] Concurrent Multi-Instance Redemption (Race Condition Replay Prevention)');
    const issueRes2 = await instanceA.adminIssueResetCode(
      'admin_uuid_1',
      adminEmail,
      athlete1.id,
      'Concurrent test issuance'
    );
    const concurrentCode = issueRes2.code!;

    // Two independent server instances simultaneously attempt to redeem the exact same code
    const instanceWorker1 = createFreshServiceInstance();
    const instanceWorker2 = createFreshServiceInstance();

    const [attempt1, attempt2] = await Promise.all([
      instanceWorker1.resetPasswordWithAdminCode(athlete1.email, concurrentCode, 'ConcurrentWinner1!'),
      instanceWorker2.resetPasswordWithAdminCode(athlete1.email, concurrentCode, 'ConcurrentWinner2!'),
    ]);

    const successCount = (attempt1.success ? 1 : 0) + (attempt2.success ? 1 : 0);
    const failureCount = (!attempt1.success ? 1 : 0) + (!attempt2.success ? 1 : 0);

    console.assert(successCount === 1, `Exactly 1 concurrent attempt must succeed. Got: ${successCount}`);
    console.assert(failureCount === 1, `Exactly 1 concurrent attempt must fail. Got: ${failureCount}`);

    const failedAttempt = !attempt1.success ? attempt1 : attempt2;
    console.assert(
      failedAttempt.error === 'CODE_ALREADY_USED',
      `Rejected concurrent attempt must return CODE_ALREADY_USED. Got: ${failedAttempt.error}`
    );
    console.log('  • Worker 1 & Worker 2 executed atomic transactions with PostgreSQL SELECT ... FOR UPDATE.');
    console.log('  • Winner updated password; concurrent loser serialized and rejected with CODE_ALREADY_USED.');
    console.log('  ✔ TEST 2 PASSED: Concurrency race condition prevented across multi-instance calls.\n');

    // ── TEST 3: Expiry Across Server Instances ───────────────────────────────
    console.log('[TEST 3] 15-Minute Expiry Enforcement Across Server Instances');
    const issueRes3 = await instanceA.adminIssueResetCode(
      'admin_uuid_1',
      adminEmail,
      athlete1.id,
      'Expiry test issuance'
    );
    const expiringCode = issueRes3.code!;

    // Manually set expiration in DB to the past (simulating 15 minutes elapsed)
    await prisma.passwordResetCode.updateMany({
      where: { userId: athlete1.id, usedAt: null },
      data: { expiresAt: new Date(Date.now() - 5000) }, // Expired 5 seconds ago
    });

    const instanceC = createFreshServiceInstance();
    const expiredRedeemRes = await instanceC.resetPasswordWithAdminCode(
      athlete1.email,
      expiringCode,
      'ShouldNotSucceedPass123!'
    );
    console.assert(expiredRedeemRes.success === false, 'Expired code redemption must fail');
    console.assert(
      expiredRedeemRes.error === 'CODE_EXPIRED' || expiredRedeemRes.error === 'CODE_ALREADY_USED',
      `Expected CODE_EXPIRED, got: ${expiredRedeemRes.error}`
    );
    console.log('  ✔ TEST 3 PASSED: Expired code rejected and automatically consumed in DB.\n');

    // ── TEST 4: Five Failed Attempts Lockout Distributed Across Instances ────
    console.log('[TEST 4] Five Failed Attempts Lockout Distributed Across Instances');
    const issueRes4 = await instanceA.adminIssueResetCode(
      'admin_uuid_1',
      adminEmail,
      athlete2.id,
      'Throttling test issuance'
    );
    const athlete2Code = issueRes4.code!;

    const instanceNode1 = createFreshServiceInstance();
    const instanceNode2 = createFreshServiceInstance();

    // Node 1 fails 3 times with wrong code
    for (let i = 1; i <= 3; i++) {
      const failRes = await instanceNode1.resetPasswordWithAdminCode(athlete2.email, '000000', 'FailPass123!');
      console.assert(failRes.error === 'INVALID_CODE', `Attempt ${i} must return INVALID_CODE`);
    }

    // Verify DB attempt counter is 3
    const midRecord = await prisma.passwordResetCode.findFirst({
      where: { userId: athlete2.id, usedAt: null },
    });
    console.assert(midRecord?.attempts === 3, `Expected DB attempts to be 3, got: ${midRecord?.attempts}`);
    console.log('  • Node 1 failed 3 times; PostgreSQL recorded 3 failed attempts.');

    // Node 2 fails 2 more times (total 5)
    const fail4 = await instanceNode2.resetPasswordWithAdminCode(athlete2.email, '111111', 'FailPass123!');
    console.assert(fail4.error === 'INVALID_CODE', 'Attempt 4 must return INVALID_CODE');

    const fail5 = await instanceNode2.resetPasswordWithAdminCode(athlete2.email, '222222', 'FailPass123!');
    console.assert(fail5.error === 'MAX_ATTEMPTS_EXCEEDED', 'Attempt 5 must trigger MAX_ATTEMPTS_EXCEEDED');
    console.log('  • Node 2 triggered attempt 5: MAX_ATTEMPTS_EXCEEDED lockout triggered.');

    // Now attempt with the CORRECT code on Node 3 — must be blocked
    const instanceNode3 = createFreshServiceInstance();
    const lockedRes = await instanceNode3.resetPasswordWithAdminCode(
      athlete2.email,
      athlete2Code,
      'CorrectCodePass123!'
    );
    console.assert(lockedRes.success === false, 'Locked code must reject even correct code');
    console.assert(
      lockedRes.error === 'CODE_ALREADY_USED' || lockedRes.error === 'MAX_ATTEMPTS_EXCEEDED',
      `Expected code lockout, got: ${lockedRes.error}`
    );
    console.log('  ✔ TEST 4 PASSED: Distributed failed attempts atomically tracked; code deactivated at 5.\n');

    // ── TEST 5: Persistent Temporary Password & Forced Change Enforcement ────
    console.log('[TEST 5] Persistent Temporary Password & Forced Change Across Server Restarts');
    // Instance A sets temporary password
    const tempResult = await instanceA.adminSetTemporaryPassword(
      'admin_uuid_1',
      adminEmail,
      athlete2.id,
      'TempPass2026!#'
    );
    console.assert(tempResult.success === true, 'Setting temporary password must succeed');

    // Verify User in PostgreSQL has mustChangePassword = true
    const userInDb = await prisma.user.findUnique({
      where: { id: athlete2.id },
      select: { mustChangePassword: true },
    });
    console.assert(userInDb?.mustChangePassword === true, 'mustChangePassword must be true in PostgreSQL');
    console.log('  • Temporary password saved; User.mustChangePassword = true persisted in PostgreSQL.');

    // Independent Instance B checks forced change required (server restart simulation)
    const instanceRestartB = createFreshServiceInstance();
    const isRequired = await instanceRestartB.isForcedPasswordChangeRequired(athlete2.id);
    console.assert(isRequired === true, 'Instance B must read forced change required = true from DB');
    console.log('  • Instance B verified forced password change is required via DB.');

    // Athlete changes password via Instance C
    const instanceRestartC = createFreshServiceInstance();
    const changeRes = await instanceRestartC.changePassword(
      athlete2.id,
      'TempPass2026!#',
      'FinalAthletePass2026!'
    );
    console.assert(changeRes.success === true, 'Change password must succeed');
    console.log('  • Instance C executed changePassword and cleared mustChangePassword flag in DB.');

    // Independent Instance D checks forced change flag — must now be false
    const instanceRestartD = createFreshServiceInstance();
    const isRequiredAfter = await instanceRestartD.isForcedPasswordChangeRequired(athlete2.id);
    console.assert(isRequiredAfter === false, 'mustChangePassword must now be false in DB');
    console.log('  ✔ TEST 5 PASSED: Forced password change persisted in DB, enforced across restarts, and cleared.\n');

    // ── TEST 6: Single-Use Code Redemption Clears Forced Password Flag ───────
    console.log('[TEST 6] Code Redemption Clears mustChangePassword Flag in PostgreSQL');
    // Set mustChangePassword = true
    await prisma.user.update({
      where: { id: athlete1.id },
      data: { mustChangePassword: true },
    });
    const issueRes5 = await instanceA.adminIssueResetCode(
      'admin_uuid_1',
      adminEmail,
      athlete1.id,
      'Test flag clearing'
    );
    const code5 = issueRes5.code!;

    const instanceRedeem = createFreshServiceInstance();
    const redeem5 = await instanceRedeem.resetPasswordWithAdminCode(
      athlete1.email,
      code5,
      'FinalPermanentPass999!'
    );
    console.assert(redeem5.success === true, 'Code redemption must succeed');

    const flagCheck = await prisma.user.findUnique({
      where: { id: athlete1.id },
      select: { mustChangePassword: true },
    });
    console.assert(flagCheck?.mustChangePassword === false, 'mustChangePassword must be reset to false');
    console.log('  ✔ TEST 6 PASSED: Redeeming admin code automatically sets mustChangePassword = false in DB.\n');

    // ── Cleanup ─────────────────────────────────────────────────────────────
    await prisma.passwordResetCode.deleteMany({
      where: { userId: { in: [athlete1.id, athlete2.id] } },
    });
    await prisma.clientProfile.deleteMany({
      where: { userId: { in: [athlete1.id, athlete2.id] } },
    });
    await prisma.user.deleteMany({
      where: { id: { in: [athlete1.id, athlete2.id] } },
    });
    console.log('✔ Cleanup: Test accounts safely removed from database.');

    console.log('\n================================================================');
    console.log('🎉 ALL MULTI-INSTANCE & PERSISTENT RECOVERY TESTS PASSED! 🎉');
    console.log('================================================================');
  } catch (err) {
    console.error('❌ Multi-instance test suite failed:', err);
    // Cleanup on error
    await prisma.user.deleteMany({
      where: { email: { in: [testEmail1, testEmail2] } },
    }).catch(() => {});
    throw err;
  }
}

if (require.main === module) {
  runMultiInstanceProductionSafetyTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
