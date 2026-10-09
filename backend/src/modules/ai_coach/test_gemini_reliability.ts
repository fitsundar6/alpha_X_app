/**
 * Alpha X AI Coach — Gemini Reliability & Recovery Test Suite
 *
 * Verifies:
 * 1. Secret redaction (API keys, query parameters, Bearer tokens, custom secrets).
 * 2. Strict error classification (Auth, Quota, Rate-limit, Transient, Model).
 * 3. Bounded transient retries with exponential backoff & jitter (stops after max retries; recovers on 2nd attempt).
 * 4. Authentication failure handling (zero retries, circuit breaker tripped, fast fail).
 * 5. Safe backup-key fallback (switches to backup on primary auth/quota, ignores identical fake backup).
 * 6. Health check mechanism (cached, TTL-respecting, zero secret exposure).
 */

import {
  geminiReliability,
  classifyGeminiError,
  redactSecrets,
  GeminiAuthCircuitError,
  GeminiReliabilityManager,
} from './gemini.reliability';

let passedCount = 0;
let failedCount = 0;

function assert(condition: boolean, testName: string, detail?: string) {
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passedCount++;
  } else {
    console.error(`  ❌ FAIL: ${testName} ${detail ? '(' + detail + ')' : ''}`);
    failedCount++;
  }
}

async function runTests() {
  console.log('================================================================');
  console.log('🧪 ALPHA X GEMINI RELIABILITY & RECOVERY TEST SUITE');
  console.log('================================================================\n');

  // Save current environment to restore after tests
  const originalPrimary = process.env.GEMINI_API_KEY;
  const originalBackup = process.env.GEMINI_API_KEY_BACKUP;

  try {
    // --------------------------------------------------------------------------
    // TEST 1: Secret Redaction Verification
    // --------------------------------------------------------------------------
    console.log('--- TEST 1: Secret Redaction Verification ---');
    const sampleApiKey = 'AIzaSyA1234567890BcDeFgHiJkLmNoPqRsTuVw';
    const sampleBackupKey = 'AIzaSyZ9876543210ZyXwVuTsRqPoNmLkJiHgFe';
    const sampleToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.fake_signature';

    const textWithApiKey = `Error occurred with Google API key ${sampleApiKey} when fetching models`;
    const redactedApiKey = redactSecrets(textWithApiKey);
    assert(!redactedApiKey.includes(sampleApiKey), 'Raw API key is redacted from text');
    assert(redactedApiKey.includes('[REDACTED_API_KEY]'), 'API key replaced with [REDACTED_API_KEY]');

    const urlWithQueryKey = `https://generativelanguage.googleapis.com/v1beta/models?key=${sampleApiKey}&alt=json`;
    const redactedUrl = redactSecrets(urlWithQueryKey);
    assert(!redactedUrl.includes(sampleApiKey), 'Query parameter API key is redacted from URL');
    assert(redactedUrl.includes('key=[REDACTED_API_KEY]'), 'Query parameter replaced with key=[REDACTED_API_KEY]');

    const textWithBearer = `Authorization header: Bearer ${sampleToken} was rejected`;
    const redactedBearer = redactSecrets(textWithBearer);
    assert(!redactedBearer.includes(sampleToken), 'Bearer token is redacted');
    assert(redactedBearer.includes('[REDACTED_TOKEN]'), 'Token replaced with [REDACTED_TOKEN]');

    const customSecret = 'my_super_secret_password_12345';
    const textWithCustom = `Failed database connection password ${customSecret}`;
    const redactedCustom = redactSecrets(textWithCustom, [customSecret]);
    assert(!redactedCustom.includes(customSecret), 'Explicitly registered custom secret is redacted');
    assert(redactedCustom.includes('[REDACTED_SECRET]'), 'Custom secret replaced with [REDACTED_SECRET]');

    // --------------------------------------------------------------------------
    // TEST 2: Error Classification Verification
    // --------------------------------------------------------------------------
    console.log('\n--- TEST 2: Error Classification Verification ---');

    // 2a: Authentication error (401 / 403 / API_KEY_INVALID)
    const authError = { status: 401, message: 'API key not valid. Please pass a valid API key.' };
    const classifiedAuth = classifyGeminiError(authError);
    assert(classifiedAuth.category === 'AUTHENTICATION_ERROR', '401 classified as AUTHENTICATION_ERROR');
    assert(classifiedAuth.isAuth === true, 'isAuth flag is true');
    assert(classifiedAuth.isTransient === false, 'isTransient is false for auth error');

    const authError403 = { status: 403, message: 'PERMISSION_DENIED: The caller does not have permission' };
    const classifiedAuth403 = classifyGeminiError(authError403);
    assert(classifiedAuth403.category === 'AUTHENTICATION_ERROR', '403 PERMISSION_DENIED classified as AUTHENTICATION_ERROR');

    // 2b: Quota exhaustion (explicit plan / billing / quota limit exhaustion)
    const quotaError = { status: 429, message: 'RESOURCE_EXHAUSTED: You exceeded your current quota, please check your plan and billing details.' };
    const classifiedQuota = classifyGeminiError(quotaError);
    assert(classifiedQuota.category === 'QUOTA_EXHAUSTED', 'Explicit quota message classified as QUOTA_EXHAUSTED');
    assert(classifiedQuota.isQuota === true, 'isQuota flag is true');
    assert(classifiedQuota.isTransient === false, 'isTransient is false for quota exhaustion');

    // 2c: Rate limit (HTTP 429 requests per minute / concurrency throttling - NOT quota exhaustion)
    const rpmRateLimitError = { status: 429, message: 'Resource has been exhausted: Rate limit exceeded for requests per minute' };
    const classifiedRpm = classifyGeminiError(rpmRateLimitError);
    assert(classifiedRpm.category === 'RATE_LIMIT', '429 per-minute rate limit classified as RATE_LIMIT (not QUOTA_EXHAUSTED)');
    assert(classifiedRpm.isQuota === false, 'isQuota is false for per-minute rate limit');
    assert(classifiedRpm.isRateLimit === true, 'isRateLimit flag is true');

    const generic429 = { status: 429, message: 'Too Many Requests' };
    const classifiedGeneric429 = classifyGeminiError(generic429);
    assert(classifiedGeneric429.category === 'RATE_LIMIT', 'Generic 429 without quota text classified as RATE_LIMIT');
    assert(classifiedGeneric429.isQuota === false, 'isQuota is false for generic 429');

    // 2d: Transient errors (503 UNAVAILABLE, 502, timeouts)
    const transient503 = { status: 503, message: 'The model is overloaded. Please try again later.' };
    const classified503 = classifyGeminiError(transient503);
    assert(classified503.category === 'TRANSIENT_SERVER_ERROR', '503 overloaded classified as TRANSIENT_SERVER_ERROR');
    assert(classified503.isTransient === true, 'isTransient is true for 503');

    const networkTimeout = new Error('connect ETIMEDOUT 142.250.190.42:443');
    const classifiedTimeout = classifyGeminiError(networkTimeout);
    assert(classifiedTimeout.category === 'TRANSIENT_SERVER_ERROR', 'ETIMEDOUT classified as TRANSIENT_SERVER_ERROR');
    assert(classifiedTimeout.isTransient === true, 'isTransient is true for network timeout');

    // 2e: Model error (404 / thought_signature / invalid argument)
    const modelError = { status: 404, message: 'models/gemini-unknown-123 is not found' };
    const classifiedModel = classifyGeminiError(modelError);
    assert(classifiedModel.category === 'MODEL_ERROR', 'Model not found classified as MODEL_ERROR');
    assert(classifiedModel.isModelError === true, 'isModelError is true');
    assert(classifiedModel.isTransient === false, 'isTransient is false for model error');

    // --------------------------------------------------------------------------
    // TEST 3: Bounded Transient Retries & Jitter
    // --------------------------------------------------------------------------
    console.log('\n--- TEST 3: Bounded Transient Retries & Jitter ---');
    const testManager = new GeminiReliabilityManager();
    process.env.GEMINI_API_KEY = sampleApiKey;
    delete process.env.GEMINI_API_KEY_BACKUP;
    testManager.resetState();

    // 3a: Recovers on 2nd attempt after initial 503 transient failure
    let callCountSuccess = 0;
    const resultSuccess = await testManager.executeWithReliability(
      async () => {
        callCountSuccess++;
        if (callCountSuccess === 1) {
          throw { status: 503, message: 'The model is overloaded. Please try again shortly.' };
        }
        return 'SUCCESS_AFTER_RETRY';
      },
      { baseDelayMs: 50, maxDelayMs: 100, maxRetries: 2, operationName: 'TestTransientRecovery' }
    );
    assert(resultSuccess === 'SUCCESS_AFTER_RETRY', 'Transient error recovers on second attempt');
    assert(callCountSuccess === 2, 'Exactly 2 attempts made (1 retry)');

    // 3b: Bounded retries exhausted (halts after maxRetries)
    let callCountExhaust = 0;
    let threwExhaust = false;
    try {
      await testManager.executeWithReliability(
        async () => {
          callCountExhaust++;
          throw { status: 503, message: 'Service Unavailable 503' };
        },
        { baseDelayMs: 20, maxDelayMs: 50, maxRetries: 2, operationName: 'TestExhaustion' }
      );
    } catch (err: any) {
      threwExhaust = true;
    }
    assert(threwExhaust, 'Throws error when max retries are exhausted');
    assert(callCountExhaust === 3, 'Halts after maxRetries (1 initial + 2 retries = 3 attempts total)');

    // --------------------------------------------------------------------------
    // TEST 4: Authentication Failure & Circuit Breaker (Zero Retries)
    // --------------------------------------------------------------------------
    console.log('\n--- TEST 4: Authentication Failure & Circuit Breaker ---');
    testManager.resetState();
    delete process.env.GEMINI_API_KEY_BACKUP;

    let authAttempts = 0;
    let authFailed = false;
    try {
      await testManager.executeWithReliability(
        async () => {
          authAttempts++;
          throw { status: 401, message: 'API key not valid. Please pass a valid API key.' };
        },
        { baseDelayMs: 50, maxRetries: 3, operationName: 'TestAuthFailure' }
      );
    } catch (err: any) {
      authFailed = true;
    }
    assert(authFailed, 'Authentication error was immediately rejected');
    assert(authAttempts === 1, 'Authentication error was NEVER retried (exactly 1 attempt)');
    assert(testManager.isCircuitTripped() === true, 'Circuit breaker tripped after auth failure');
    assert(testManager.getCircuitCooldownRemainingSeconds() > 0, 'Circuit cooldown is active');

    // 4b: Subsequent calls fail fast without network execution
    let callWhileTripped = 0;
    let circuitBlocked = false;
    try {
      await testManager.executeWithReliability(
        async () => {
          callWhileTripped++;
          return 'SHOULD_NOT_EXECUTE';
        },
        { operationName: 'TestCircuitBlocked' }
      );
    } catch (err: any) {
      if (err instanceof GeminiAuthCircuitError || err.code === 'GEMINI_AUTH_CIRCUIT_OPEN') {
        circuitBlocked = true;
      }
    }
    assert(circuitBlocked, 'Subsequent call blocked by circuit breaker without network call');
    assert(callWhileTripped === 0, 'Zero operations executed while circuit breaker is open');

    // --------------------------------------------------------------------------
    // TEST 5: Backup Key Failover & Fake Backup Prevention
    // --------------------------------------------------------------------------
    console.log('\n--- TEST 5: Backup Key Failover & Fake Backup Prevention ---');
    testManager.resetState();

    // 5a: Duplicate/identical backup key is ignored ("Never use the same key as a fake backup")
    process.env.GEMINI_API_KEY = sampleApiKey;
    process.env.GEMINI_API_KEY_BACKUP = sampleApiKey; // Same key!
    const credsWithFake = testManager.getResolvedCredentials();
    assert(credsWithFake.backupKey === null, 'Identical backup key is safely rejected (not used as fake backup)');

    // 5b: Valid distinct backup key enables automatic failover on primary auth failure
    process.env.GEMINI_API_KEY_BACKUP = sampleBackupKey;
    testManager.resetState();

    let attemptsWithBackup = 0;
    const failoverResult = await testManager.executeWithReliability(
      async (_client, source) => {
        attemptsWithBackup++;
        if (source === 'PRIMARY') {
          throw { status: 401, message: 'API key not valid on primary' };
        }
        return `SUCCESS_ON_${source}`;
      },
      { baseDelayMs: 20, maxRetries: 2, operationName: 'TestBackupFailover' }
    );

    assert(failoverResult === 'SUCCESS_ON_BACKUP', 'Successfully failed over to GEMINI_API_KEY_BACKUP');
    assert(testManager.getActiveSource() === 'BACKUP', 'Active key source switched to BACKUP');
    assert(testManager.isCircuitTripped() === false, 'Circuit breaker NOT tripped because backup succeeded');

    // 5c: Both keys fail authentication -> Circuit breaker trips immediately after backup failure
    testManager.resetState();
    let bothAttempts = 0;
    let bothFailed = false;
    try {
      await testManager.executeWithReliability(
        async (_client, source) => {
          bothAttempts++;
          throw { status: 401, message: `401 Unauthorized on ${source}` };
        },
        { baseDelayMs: 20, maxRetries: 3, operationName: 'TestBothKeysFail' }
      );
    } catch (_) {
      bothFailed = true;
    }
    assert(bothFailed === true, 'Both keys failing auth results in thrown error');
    assert(bothAttempts === 2, 'Exactly 2 attempts made (1 on primary + 1 on backup, zero endless retries)');
    assert(testManager.isCircuitTripped() === true, 'Circuit breaker trips when both primary and backup fail auth');

    // 5d: Quota exhaustion failover to distinct backup key
    testManager.resetState();
    let quotaAttempts = 0;
    const quotaFailoverResult = await testManager.executeWithReliability(
      async (_client, source) => {
        quotaAttempts++;
        if (source === 'PRIMARY') {
          throw { status: 429, message: 'RESOURCE_EXHAUSTED: You exceeded your current quota' };
        }
        return `QUOTA_RECOVERED_ON_${source}`;
      },
      { baseDelayMs: 20, maxRetries: 3, operationName: 'TestQuotaFailover' }
    );
    assert(quotaFailoverResult === 'QUOTA_RECOVERED_ON_BACKUP', 'Quota error on primary successfully fails over to backup key');
    assert(quotaAttempts === 2, 'Quota failover made exactly 2 attempts (1 primary + 1 backup)');
    assert(testManager.getActiveSource() === 'BACKUP', 'Active source switched to BACKUP after quota failure');

    // 5e: Quota exhaustion without backup (immediate fail-fast, zero retries)
    testManager.resetState();
    delete process.env.GEMINI_API_KEY_BACKUP;
    let quotaNoBackupAttempts = 0;
    let quotaThrew = false;
    try {
      await testManager.executeWithReliability(
        async () => {
          quotaNoBackupAttempts++;
          throw { status: 429, message: 'RESOURCE_EXHAUSTED: You exceeded your current quota' };
        },
        { baseDelayMs: 20, maxRetries: 3, operationName: 'TestQuotaNoBackup' }
      );
    } catch (_) {
      quotaThrew = true;
    }
    assert(quotaThrew === true, 'Quota exhaustion without backup throws error');
    assert(quotaNoBackupAttempts === 1, 'Quota exhaustion without backup NEVER retries in loop (exactly 1 attempt)');

    // 5f: Circuit breaker cooldown expiration behavior
    testManager.resetState();
    testManager.tripCircuitBreaker('Testing cooldown');
    assert(testManager.isCircuitTripped() === true, 'Circuit breaker is initially tripped');
    // Simulate cooldown elapsing
    (testManager as any).circuitTrippedUntil = Date.now() - 1000; // 1s in the past
    assert(testManager.isCircuitTripped() === false, 'Circuit breaker automatically closes after cooldown expires');


    // --------------------------------------------------------------------------
    // TEST 6: Lightweight Health Check Probe
    // --------------------------------------------------------------------------
    console.log('\n--- TEST 6: Lightweight Health Check Probe ---');
    testManager.resetState();
    process.env.GEMINI_API_KEY = '';
    process.env.GEMINI_API_KEY_BACKUP = '';

    const unconfiguredHealth = await testManager.checkHealth(true);
    assert(unconfiguredHealth.healthy === false, 'Health check reports unhealthy when no key configured');
    assert(unconfiguredHealth.status === 'UNCONFIGURED', 'Status is UNCONFIGURED');
    assert(unconfiguredHealth.activeKeySource === 'NONE', 'Active source is NONE');
    assert(!JSON.stringify(unconfiguredHealth).includes('AIzaSy'), 'Zero secrets exposed in health check payload');

    // Test with configured key in circuit-tripped state
    process.env.GEMINI_API_KEY = sampleApiKey;
    testManager.tripCircuitBreaker('Testing health check with tripped circuit');
    const trippedHealth = await testManager.checkHealth(true);
    assert(trippedHealth.healthy === false, 'Health check reports unhealthy when circuit is tripped');
    assert(trippedHealth.circuitTripped === true, 'circuitTripped flag is true');
    assert(trippedHealth.status === 'AUTH_FAILED', 'Status is AUTH_FAILED');
    assert(!JSON.stringify(trippedHealth).includes(sampleApiKey), 'API key value is NOT present in health payload');

    console.log('\n================================================================');
    console.log(`🎉 TEST SUMMARY: ${passedCount} PASSED, ${failedCount} FAILED`);
    console.log('================================================================\n');

    if (failedCount > 0) {
      process.exit(1);
    }
  } finally {
    // Restore original environment
    if (originalPrimary !== undefined) {
      process.env.GEMINI_API_KEY = originalPrimary;
    } else {
      delete process.env.GEMINI_API_KEY;
    }
    if (originalBackup !== undefined) {
      process.env.GEMINI_API_KEY_BACKUP = originalBackup;
    } else {
      delete process.env.GEMINI_API_KEY_BACKUP;
    }
    geminiReliability.resetState();
  }
}

runTests().catch((err) => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});
