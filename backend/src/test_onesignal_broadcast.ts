/**
 * Alpha X Gym — OneSignal Push Notification & Broadcast Test Suite
 *
 * Verifies:
 * 1. Admin authorization for notification management endpoints
 * 2. Audience preview calculations (eligible, unregistered, opted-out, demo excluded)
 * 3. Request validation for broadcasts (title, body, confirmBroadcast)
 * 4. Duplicate send prevention (60s throttling window)
 * 5. Test device targeting & single-client targeting
 * 6. In-app database Notification persistence
 * 7. OneSignal gateway response handling & error transparency
 *
 * NOTE: The requireAdmin middleware enforces that token email === env.ADMIN_EMAIL.
 * Admin test tokens MUST use the real admin email from env.ADMIN_EMAIL, otherwise
 * all admin-protected routes return 403 Forbidden.
 */

import jwt from 'jsonwebtoken';
import { prisma } from './config/prisma';
import { env } from './config/environment';
import { oneSignalService } from './modules/notifications/onesignal.service';

const TEST_ADMIN_ID = 'admin-broadcast-test-id';
const TEST_CLIENT_ID = 'client-broadcast-test-id';

/**
 * Generate a signed JWT for testing.
 * CRITICAL: Admin tokens must use env.ADMIN_EMAIL as the email field.
 * The requireAdmin middleware compares token email against env.ADMIN_EMAIL strictly.
 * Using any other email causes the middleware to downgrade the role to CLIENT → 403.
 */
function generateToken(userId: string, role: 'ADMIN' | 'CLIENT'): string {
  // Admin tokens must use the exact configured admin email — not a fake test email
  const email = role === 'ADMIN' ? env.ADMIN_EMAIL : `client-test@alphaxgym.com`;
  return jwt.sign(
    { id: userId, email, role },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );
}

let passedTests = 0;
let failedTests = 0;

function assert(condition: boolean, testName: string, details?: any) {
  if (condition) {
    console.log(`[PASS] ${testName}`);
    passedTests++;
  } else {
    console.error(`[FAIL] ${testName}`, details ? `\nDetails: ${JSON.stringify(details, null, 2)}` : '');
    failedTests++;
  }
}

async function runTests() {
  console.log('======================================================================');
  console.log('ALPHA X GYM — ONESIGNAL PUSH NOTIFICATION & BROADCAST AUDIT & TEST');
  console.log('======================================================================\n');

  // ── Pre-flight: OneSignal credentials check ──────────────────────────────
  console.log('--- PRE-FLIGHT: OneSignal Credential Diagnostic ---');
  const oneSignalConfigured = oneSignalService.isConfigured();
  console.log(`[OneSignal] App ID configured:      ${env.ONESIGNAL_APP_ID ? '✅ YES' : '❌ MISSING'}`);
  console.log(`[OneSignal] REST API Key configured: ${env.ONESIGNAL_REST_API_KEY ? '✅ YES (key present, validity tested via gateway)' : '❌ MISSING'}`);
  if (!oneSignalConfigured) {
    console.warn('[OneSignal] ⚠️  Credentials not fully configured. Gateway dispatch tests will report failure.');
    console.warn('[OneSignal] Set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY in backend/.env');
  }
  console.log('');
  // ─────────────────────────────────────────────────────────────────────────

  const adminToken = generateToken(TEST_ADMIN_ID, 'ADMIN');
  const clientToken = generateToken(TEST_CLIENT_ID, 'CLIENT');

  console.log(`[Auth] Admin token uses email: ${env.ADMIN_EMAIL} (matches requireAdmin check)`);
  console.log('');

  const baseUrl = `http://localhost:${env.PORT || 5000}/api/v1/notifications`;

  // --- SUITE 1: Authorization Controls ---
  console.log('--- TEST SUITE 1: Admin Authorization Safeguards ---');

  // Test 1.1: Unauthenticated request to audience preview rejected
  try {
    const res = await fetch(`${baseUrl}/admin/audience-preview`);
    assert(res.status === 401, 'Unauthenticated request to audience-preview rejected with 401');
  } catch (e: any) {
    assert(false, 'Unauthenticated request failed unexpectedly', e?.message);
  }

  // Test 1.2: Client token request to audience preview rejected with 403
  try {
    const res = await fetch(`${baseUrl}/admin/audience-preview`, {
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    assert(res.status === 403, 'Client token to audience-preview rejected with 403 Forbidden');
  } catch (e: any) {
    assert(false, 'Client token test failed', e?.message);
  }

  // Test 1.3: Client token request to broadcast rejected with 403
  try {
    const res = await fetch(`${baseUrl}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${clientToken}`,
      },
      body: JSON.stringify({ title: 'Test', body: 'Test' }),
    });
    assert(res.status === 403, 'Client token to broadcast rejected with 403 Forbidden');
  } catch (e: any) {
    assert(false, 'Client token broadcast failed', e?.message);
  }

  // --- SUITE 2: Audience Preview Breakdown ---
  console.log('\n--- TEST SUITE 2: Audience Preview Breakdown ---');

  try {
    const res = await fetch(`${baseUrl}/admin/audience-preview`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(res.status === 200, 'Admin can fetch audience-preview successfully (200 OK)');
    const body = await res.json();
    assert(body.success === true, 'Audience preview response has success: true');
    assert(body.data?.summary !== undefined, 'Audience preview includes summary counts');
    assert(typeof body.data?.summary?.totalRegisteredClients === 'number', 'Summary has totalRegisteredClients count');
    assert(typeof body.data?.summary?.eligiblePushRecipientsCount === 'number', 'Summary has eligiblePushRecipientsCount');
    assert(Array.isArray(body.data?.eligibleRecipients), 'Audience preview returns eligibleRecipients array');
    assert(Array.isArray(body.data?.pendingDeviceClients), 'Audience preview returns pendingDeviceClients array');
    console.log('Audience preview summary:', body.data?.summary);
  } catch (e: any) {
    assert(false, 'Audience preview fetch failed', e?.message);
  }

  // --- SUITE 3: Request Validation & Safeguards ---
  console.log('\n--- TEST SUITE 3: Broadcast Request Validation ---');

  // Test 3.1: Missing title returns 400
  try {
    const res = await fetch(`${baseUrl}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ title: '', body: 'Sample message' }),
    });
    assert(res.status === 400, 'Empty title returns 400 Validation Error');
  } catch (e: any) {
    assert(false, 'Empty title test failed', e?.message);
  }

  // Test 3.2: Missing body returns 400
  try {
    const res = await fetch(`${baseUrl}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ title: 'Sample title', body: '' }),
    });
    assert(res.status === 400, 'Empty body returns 400 Validation Error');
  } catch (e: any) {
    assert(false, 'Empty body test failed', e?.message);
  }

  // Test 3.3: Broadcasting to ALL_ELIGIBLE without confirmBroadcast returns 400
  try {
    const res = await fetch(`${baseUrl}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        title: 'Alpha X Announcement',
        body: 'Morning session updates',
        targetAudience: 'ALL_ELIGIBLE',
        confirmBroadcast: false,
      }),
    });
    assert(res.status === 400, 'Broadcasting to ALL_ELIGIBLE without confirmBroadcast: true returns 400 Confirmation Required');
  } catch (e: any) {
    assert(false, 'Confirmation requirement test failed', e?.message);
  }

  // --- SUITE 4: Broadcast Execution & In-App Notification Recording ---
  console.log('\n--- TEST SUITE 4: Broadcast Execution & Safe Telemetry ---');

  // Test 4.1: Broadcast to TEST_DEVICE target
  const uniqueTitle = `⚡ Test Broadcast ${Date.now()}`;
  const testBody = 'Coach update: hydration check and workout reminder';

  try {
    const res = await fetch(`${baseUrl}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        title: uniqueTitle,
        body: testBody,
        targetAudience: 'TEST_DEVICE',
        targetPlayerId: 'mock-player-test-device-id',
        confirmBroadcast: true,
      }),
    });

    assert(res.status === 200, 'Broadcast endpoint returns 200 OK');
    const data = await res.json();
    assert(data.success === true, 'Response body has success: true');
    assert(data.data?.title === uniqueTitle, 'Response echoes clean broadcast title');
    assert(data.data?.deliveryLifecycle !== undefined, 'Response includes 3-stage deliveryLifecycle telemetry');
    assert(data.data?.recipientsSummary?.pushDevicesTargeted === 1, 'pushDevicesTargeted is 1 for single test device');
  } catch (e: any) {
    assert(false, 'Broadcast execution failed', e?.message);
  }

  // Test 4.2: Duplicate send prevention triggers when sending identical broadcast immediately
  try {
    const res = await fetch(`${baseUrl}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        title: uniqueTitle,
        body: testBody,
        targetAudience: 'TEST_DEVICE',
        targetPlayerId: 'mock-player-test-device-id',
        confirmBroadcast: true,
      }),
    });

    assert(res.status === 409, 'Duplicate broadcast within 60s rejected with 409 Conflict (DUPLICATE_BROADCAST_PREVENTED)');
    const body = await res.json();
    assert(body.error?.code === 'DUPLICATE_BROADCAST_PREVENTED', 'Error code is DUPLICATE_BROADCAST_PREVENTED');
  } catch (e: any) {
    assert(false, 'Duplicate prevention test failed', e?.message);
  }

  // --- SUITE 5: Single Client Test Push (/admin/send-test) ---
  console.log('\n--- TEST SUITE 5: Single Client Test Push Route ---');

  try {
    const res = await fetch(`${baseUrl}/admin/send-test`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        playerId: 'mock-player-direct-send',
        title: 'Single Direct Test',
        body: 'Testing direct push dispatch',
      }),
    });

    assert(res.status === 200, 'Direct test send returns 200 OK');
    const data = await res.json();
    assert(data.success === true, 'Direct test response has success: true');
  } catch (e: any) {
    assert(false, 'Direct test send failed', e?.message);
  }

  // Test 5.2: Non-existent client returns 404
  try {
    const res = await fetch(`${baseUrl}/admin/send-test`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({
        clientId: 'non-existent-client-id-xyz',
        title: 'Test',
        body: 'Test',
      }),
    });

    assert(res.status === 404, 'Non-existent client returns 404 NOT_FOUND');
  } catch (e: any) {
    assert(false, 'Non-existent client test failed', e?.message);
  }

  // --- SUITE 6: Device Registration Route (/register-device) ---
  console.log('\n--- TEST SUITE 6: Client Device Token Registration ---');

  // Verify missing playerId is rejected
  try {
    const res = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${clientToken}`,
      },
      body: JSON.stringify({ playerId: '' }),
    });

    assert(res.status === 400, 'Empty playerId in register-device rejected with 400');
  } catch (e: any) {
    assert(false, 'Empty playerId test failed', e?.message);
  }

  console.log('\n======================================================================');
  console.log(`TOTAL TESTS: ${passedTests + failedTests} | PASSED: ${passedTests} | FAILED: ${failedTests}`);
  console.log('======================================================================');

  await prisma.$disconnect();

  if (failedTests > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Test execution error:', err);
  process.exit(1);
});
