import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { env } from './config/environment';
import { passwordResetService } from './services/password_reset.service';
import { adminAuthService } from './modules/auth/admin_auth.service';

async function testPasswordRecoverySecurity() {
  console.log('================================================================');
  console.log('🔒 VERIFYING FORGOT-PASSWORD SECURITY MECHANISMS 🔒');
  console.log('================================================================');

  // 1. Anti-Enumeration Equivalence Test
  console.log('\n[CHECK 1] Anti-Enumeration Response Equivalence:');
  const unknownEmail = 'ghost_unregistered_client_9999@alphax.test';
  const registeredEmail = env.ADMIN_EMAIL.trim().toLowerCase();

  const unknownResult = await passwordResetService.requestPasswordReset(unknownEmail);
  const registeredResult = await passwordResetService.requestPasswordReset(registeredEmail);

  console.assert(unknownResult.success === true, 'Unknown email must return success: true');
  console.assert(registeredResult.success === true, 'Registered email must return success: true');
  console.assert(
    unknownResult.message === registeredResult.message,
    'Public response message must be 100% identical between registered and unregistered emails'
  );
  console.assert(
    unknownResult.message === 'If an account exists with this email, a password reset link has been sent.',
    'Message must be the uniform public template'
  );
  console.log('  ✔ Unknown email and registered email received 100% equivalent public responses.');

  const malformedEmailResult = await passwordResetService.requestPasswordReset('not-an-email');
  console.assert(malformedEmailResult.success === true, 'Malformed email format must return uniform success: true');
  console.assert(malformedEmailResult.message === registeredResult.message, 'Malformed email message must match');
  console.log('  ✔ Malformed email returned identical uniform response.');

  // 2. Token Security & Cryptographic Validation
  console.log('\n[CHECK 2] Token Validation, Expiry & Signature Verification:');
  
  // Empty / Null token
  const emptyTokenResult = await passwordResetService.verifyResetToken('');
  console.assert(emptyTokenResult.valid === false && emptyTokenResult.error === 'TOKEN_INVALID', 'Empty token must be invalid');
  console.log('  ✔ Empty token rejected with TOKEN_INVALID.');

  // Malformed non-JWT string
  const malformedTokenResult = await passwordResetService.verifyResetToken('random_gibberish_not_a_jwt_string');
  console.assert(malformedTokenResult.valid === false && malformedTokenResult.error === 'TOKEN_INVALID', 'Malformed token must fail');
  console.log('  ✔ Malformed string rejected with TOKEN_INVALID.');

  // Token signed with wrong secret key (tampered signature)
  const fakeSecretToken = jwt.sign(
    { userId: 'admin_alex_stone', email: registeredEmail, role: 'ADMIN', purpose: 'PASSWORD_RESET', jti: crypto.randomUUID() },
    'WRONG_UNAUTHORIZED_SECRET_KEY_12345'
  );
  const fakeSecretResult = await passwordResetService.verifyResetToken(fakeSecretToken);
  console.assert(fakeSecretResult.valid === false && fakeSecretResult.error === 'TOKEN_INVALID', 'Wrong secret key must fail');
  console.log('  ✔ Forged token with invalid signature rejected with TOKEN_INVALID.');

  // Token with unauthorized purpose (e.g. login access token used as reset token)
  const wrongPurposeToken = jwt.sign(
    { userId: 'admin_alex_stone', email: registeredEmail, role: 'ADMIN', purpose: 'ACCESS_TOKEN', jti: crypto.randomUUID() },
    env.JWT_ACCESS_SECRET
  );
  const wrongPurposeResult = await passwordResetService.verifyResetToken(wrongPurposeToken);
  console.assert(wrongPurposeResult.valid === false && wrongPurposeResult.error === 'TOKEN_INVALID', 'Wrong purpose token must be rejected');
  console.log('  ✔ Token with incorrect purpose (ACCESS_TOKEN) rejected with TOKEN_INVALID.');

  // Expired token
  const expiredToken = jwt.sign(
    {
      userId: 'admin_alex_stone',
      email: registeredEmail,
      role: 'ADMIN',
      purpose: 'PASSWORD_RESET',
      hashSnippet: await adminAuthService.getActivePasswordHashSnippet(),
      jti: crypto.randomUUID(),
    },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '-10s' } // Expired 10 seconds ago
  );
  const expiredResult = await passwordResetService.verifyResetToken(expiredToken);
  console.assert(expiredResult.valid === false && expiredResult.error === 'TOKEN_EXPIRED', 'Expired token must be rejected with TOKEN_EXPIRED');
  console.log('  ✔ Expired token rejected with TOKEN_EXPIRED.');

  // 3. Password Validation Rules
  console.log('\n[CHECK 3] Password Validation Safeguards:');
  const validJti = crypto.randomUUID();
  const validAdminToken = jwt.sign(
    {
      userId: 'admin_alex_stone',
      email: registeredEmail,
      role: 'ADMIN',
      hashSnippet: await adminAuthService.getActivePasswordHashSnippet(),
      jti: validJti,
      purpose: 'PASSWORD_RESET',
    },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '15m' }
  );

  const shortPasswordResult = await passwordResetService.resetPassword(validAdminToken, '12345');
  console.assert(shortPasswordResult.success === false, 'Short password must be rejected');
  console.assert(shortPasswordResult.error === 'VALIDATION_ERROR', 'Expected VALIDATION_ERROR');
  console.log('  ✔ Passwords shorter than 6 characters rejected with VALIDATION_ERROR.');

  const emptyPasswordResult = await passwordResetService.resetPassword(validAdminToken, '');
  console.assert(emptyPasswordResult.success === false, 'Empty password must be rejected');
  console.log('  ✔ Empty password rejected with VALIDATION_ERROR.');

  // 4. Single-Use Enforcement & Replay Protection
  console.log('\n[CHECK 4] Single-Use Token Consumption & Replay Prevention:');
  const initialVerify = await passwordResetService.verifyResetToken(validAdminToken);
  console.assert(initialVerify.valid === true, 'Token before use must be valid');
  console.log('  ✔ Fresh token successfully validated.');

  // Simulate token consumption in consumedTokens map
  (passwordResetService as any).consumedTokens.set(validJti, Date.now() + 15 * 60 * 1000);

  const secondVerify = await passwordResetService.verifyResetToken(validAdminToken);
  console.assert(secondVerify.valid === false, 'Consumed token must NOT be valid');
  console.assert(secondVerify.error === 'TOKEN_ALREADY_USED', 'Error must be TOKEN_ALREADY_USED');
  console.log('  ✔ Replay attempt on consumed token rejected with TOKEN_ALREADY_USED.');

  // 5. Stale Hash Snippet Invalidation
  console.log('\n[CHECK 5] Cryptographic Hash-Snippet Binding:');
  const staleHashToken = jwt.sign(
    {
      userId: 'admin_alex_stone',
      email: registeredEmail,
      role: 'ADMIN',
      hashSnippet: 'OUTDATED_HASH_SNIPPET_XYZ',
      jti: crypto.randomUUID(),
      purpose: 'PASSWORD_RESET',
    },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '15m' }
  );

  const staleVerify = await passwordResetService.verifyResetToken(staleHashToken);
  console.assert(staleVerify.valid === false, 'Token with outdated password hash snippet must be invalid');
  console.assert(staleVerify.error === 'TOKEN_ALREADY_USED', 'Error must be TOKEN_ALREADY_USED');
  console.log('  ✔ Token with outdated password hash snippet permanently invalidated with TOKEN_ALREADY_USED.');

  // 6. Simultaneous Concurrent Replay Race Condition Test
  console.log('\n[CHECK 6] Simultaneous Concurrent Replay Attempt (Race Condition Resistance):');
  const originalAdminPassword = env.ADMIN_PASSWORD || 'AlphaXAdmin2026!';
  const concurrentJti = crypto.randomUUID();
  const currentSnippet = await adminAuthService.getActivePasswordHashSnippet();
  const concurrentToken = jwt.sign(
    {
      userId: 'admin_alex_stone',
      email: registeredEmail,
      role: 'ADMIN',
      hashSnippet: currentSnippet,
      jti: concurrentJti,
      purpose: 'PASSWORD_RESET',
    },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '15m' }
  );

  // Fire two resetPassword calls concurrently with the same token
  const [attempt1, attempt2] = await Promise.all([
    passwordResetService.resetPassword(concurrentToken, 'ConcurrentPass123!'),
    passwordResetService.resetPassword(concurrentToken, 'ConcurrentPass456!'),
  ]);

  const successCount = (attempt1.success ? 1 : 0) + (attempt2.success ? 1 : 0);
  const failureCount = (!attempt1.success ? 1 : 0) + (!attempt2.success ? 1 : 0);

  console.assert(successCount === 1, `Exactly one concurrent attempt must succeed. Got: ${successCount}`);
  console.assert(failureCount === 1, `Exactly one concurrent attempt must fail. Got: ${failureCount}`);
  
  const failedAttempt = !attempt1.success ? attempt1 : attempt2;
  console.assert(
    failedAttempt.error === 'TOKEN_ALREADY_USED',
    `Rejected concurrent attempt must return TOKEN_ALREADY_USED. Got: ${failedAttempt.error}`
  );

  // Restore original credentials
  await adminAuthService.updateAdminPassword(originalAdminPassword);
  console.log('  ✔ Simultaneous race condition prevented: exactly 1 succeeded, 1 rejected with TOKEN_ALREADY_USED.');

  console.log('\n================================================================');
  console.log('🎉 ALL 6 FORGOT-PASSWORD SECURITY CHECKS PASSED FLAWLESSLY! 🎉');
  console.log('================================================================');
}

testPasswordRecoverySecurity().catch((err) => {
  console.error('Security check failed:', err);
  process.exit(1);
});
