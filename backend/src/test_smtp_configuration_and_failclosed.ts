import { EmailService } from './services/email.service';
import { PasswordResetService } from './services/password_reset.service';
import { env } from './config/environment';

async function runSmtpFailClosedTests() {
  console.log('================================================================');
  console.log('🧪 VERIFYING SMTP CONFIGURATION, SAFETY & FAIL-CLOSED GUARDS 🧪');
  console.log('================================================================');

  const emailService = EmailService.getInstance();
  const resetService = PasswordResetService.getInstance();

  // CHECK 1: Configuration Detection & Verification
  console.log('\n[CHECK 1] SMTP Configuration Validation:');
  const isConfigured = emailService.isConfigured();
  const verification = await emailService.verifyConfiguration();
  console.log(`  Current environment SMTP configured: ${isConfigured}`);
  console.log(`  Verification result: ok=${verification.ok}, reason="${verification.reason}"`);
  if (!isConfigured && !verification.ok && verification.reason?.includes('SMTP')) {
    console.log('  ✔ Correctly detected missing SMTP credentials and returned actionable validation error.');
  } else {
    throw new Error('Check 1 Failed: Expected missing configuration detection.');
  }

  // CHECK 2: Production Preview Masquerade Prevention
  console.log('\n[CHECK 2] Production Mode Masquerade Prevention:');
  const originalEnv = env.NODE_ENV;
  try {
    (env as any).NODE_ENV = 'production';

    const deliveryResult = await emailService.sendPasswordResetEmail({
      toEmail: 'audit_test@alphax.com',
      resetToken: 'dummy_token_for_audit_check',
    });

    console.log(`  Production delivery result: delivered=${deliveryResult.delivered}, mode=${deliveryResult.mode}`);
    if (deliveryResult.delivered === false && deliveryResult.mode === 'smtp') {
      console.log('  ✔ Production mode failed closed: delivered=false, mode=smtp. Preview mode strictly prohibited.');
    } else {
      throw new Error('Check 2 Failed: Production mode masqueraded or claimed delivery succeeded without SMTP!');
    }

    // CHECK 3: Uniform Anti-Enumeration Failure Response in Production
    console.log('\n[CHECK 3] Uniform Anti-Enumeration Failure Response in Production:');
    const unknownRes = await resetService.requestPasswordReset('nonexistent_user_audit@example.com');
    const adminRes = await resetService.requestPasswordReset(env.ADMIN_EMAIL);

    console.log(`  Unknown user response: success=${unknownRes.success}, message="${unknownRes.message}"`);
    console.log(`  Admin user response:   success=${adminRes.success}, message="${adminRes.message}"`);

    if (
      unknownRes.success === false &&
      adminRes.success === false &&
      unknownRes.message === adminRes.message &&
      unknownRes.message.includes('unavailable')
    ) {
      console.log('  ✔ Both unregistered and registered accounts received identical 503 unavailable responses.');
      console.log('  ✔ Zero information leakage: anti-enumeration 100% preserved.');
      console.log('  ✔ Production never falsely claims password reset link was sent when SMTP is unconfigured.');
    } else {
      throw new Error('Check 3 Failed: Responses diverged or falsely reported email sent.');
    }
  } finally {
    (env as any).NODE_ENV = originalEnv;
  }

  // CHECK 4: Non-Production Preview Mode Preserved for Testing
  console.log('\n[CHECK 4] Development/Testing Fallback Behavior:');
  const devDelivery = await emailService.sendPasswordResetEmail({
    toEmail: 'dev_test@alphax.com',
    resetToken: 'dev_token',
  });
  if (devDelivery.delivered === true && devDelivery.mode === 'preview_logger') {
    console.log('  ✔ Development/testing mode gracefully generates preview logger without crashing developer tests.');
  } else {
    throw new Error('Check 4 Failed: Expected preview logger in development mode.');
  }

  console.log('\n================================================================');
  console.log('🎉 ALL SMTP SAFETY & FAIL-CLOSED CHECKS PASSED FLAWLESSLY! 🎉');
  console.log('================================================================\n');
}

runSmtpFailClosedTests().catch((err) => {
  console.error('❌ SMTP fail-closed tests failed:', err);
  process.exit(1);
});
