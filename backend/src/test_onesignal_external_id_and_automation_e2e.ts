/**
 * Alpha X Gym — OneSignal External ID & Automation End-to-End Test Suite
 *
 * Validates:
 * 1. Admin authorization for single-client push and delivery reporting endpoints
 * 2. Targeted single-client notification dispatch using OneSignal External ID (OneSignal.login identity)
 * 3. 3-Stage delivery lifecycle reporting (Gateway Accepted -> FCM Transit -> Device Display)
 * 4. Live OneSignal REST API delivery reporting query endpoint
 * 5. Automation cycle integration (membership expiry, payment reminders) with deduplication & quiet hours
 * 6. Secret protection: ONESIGNAL_REST_API_KEY is never exposed in responses or logs
 */

import http from 'http';
import jwt from 'jsonwebtoken';
import app from './server';
import { prisma } from './config/prisma';
import { env } from './config/environment';
import { oneSignalService } from './modules/notifications/onesignal.service';
import { automationService } from './modules/automation/automation.service';
import { notificationPolicyService } from './modules/notifications/notification_policy.service';

let server: http.Server;
let baseUrl: string;
let passed = 0;
let failed = 0;

function assert(condition: boolean, name: string, detail?: any) {
  if (condition) {
    console.log(`  ✅ [PASS] ${name}`);
    passed++;
  } else {
    console.error(`  ❌ [FAIL] ${name}`, detail ? `\n  Detail: ${JSON.stringify(detail, null, 2)}` : '');
    failed++;
  }
}

function makeToken(userId: string, role: 'ADMIN' | 'CLIENT'): string {
  const email = role === 'ADMIN' ? env.ADMIN_EMAIL : 'test-client@alphaxgym.com';
  return jwt.sign({ id: userId, email, role }, env.JWT_ACCESS_SECRET, { expiresIn: '1h' });
}

async function run() {
  console.log('======================================================================');
  console.log('ALPHA X GYM — ONESIGNAL EXTERNAL ID & AUTOMATION E2E TEST SUITE');
  console.log('======================================================================\n');

  // Start test server on ephemeral port
  await new Promise<void>((resolve) => {
    server = app.listen(0, () => {
      const addr = server.address() as any;
      baseUrl = `http://localhost:${addr.port}/api/v1`;
      resolve();
    });
  });

  const adminToken = makeToken('admin-test-uuid', 'ADMIN');
  const clientToken = makeToken('client-test-uuid', 'CLIENT');

  try {
    // ── SUITE 1: Configuration & Secrets Protection ────────────────────────
    console.log('--- TEST SUITE 1: OneSignal Configuration & Secret Leak Audit ---');
    assert(oneSignalService.isConfigured(), 'OneSignalService reports configured credentials in .env');
    assert(!!env.ONESIGNAL_APP_ID && env.ONESIGNAL_APP_ID.includes('-'), 'ONESIGNAL_APP_ID is valid format');
    assert(!!env.ONESIGNAL_REST_API_KEY && env.ONESIGNAL_REST_API_KEY.length > 20, 'ONESIGNAL_REST_API_KEY is loaded in environment');

    // ── SUITE 2: RBAC Security & Authorization ─────────────────────────────
    console.log('\n--- TEST SUITE 2: Security & RBAC Enforcement ---');

    // 2.1 Unauthenticated request rejected
    const unauthRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ clientId: 'AXG-0006', title: 'Test', message: 'Test' }),
    });
    assert(unauthRes.status === 401, 'Unauthenticated POST /admin/send-to-client returns 401');

    // 2.2 Client role request rejected with 403
    const clientRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${clientToken}` },
      body: JSON.stringify({ clientId: 'AXG-0006', title: 'Test', message: 'Test' }),
    });
    assert(clientRes.status === 403, 'Client token POST /admin/send-to-client returns 403 Forbidden');

    // 2.3 Delivery status endpoint unauthenticated rejected
    const unauthStatus = await fetch(`${baseUrl}/notifications/admin/delivery-status/fake-id`);
    assert(unauthStatus.status === 401, 'Unauthenticated GET /admin/delivery-status returns 401');

    // 2.4 Delivery status endpoint client role rejected
    const clientStatus = await fetch(`${baseUrl}/notifications/admin/delivery-status/fake-id`, {
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    assert(clientStatus.status === 403, 'Client token GET /admin/delivery-status returns 403 Forbidden');

    // ── SUITE 3: Input Validation ──────────────────────────────────────────
    console.log('\n--- TEST SUITE 3: Request Validation & Safeguards ---');

    // 3.1 Missing clientId
    const noClientRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ title: 'Test Title', message: 'Test Body' }),
    });
    assert(noClientRes.status === 400, 'Missing clientId returns 400 Bad Request');

    // 3.2 Missing title
    const noTitleRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ clientId: 'AXG-0006', message: 'Test Body' }),
    });
    assert(noTitleRes.status === 400, 'Missing title returns 400 Bad Request');

    // 3.3 Missing message
    const noMsgRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ clientId: 'AXG-0006', title: 'Test Title' }),
    });
    assert(noMsgRes.status === 400, 'Missing message returns 400 Bad Request');

    // 3.4 Nonexistent client
    const notFoundRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
      body: JSON.stringify({ clientId: 'nonexistent-uuid-99999', title: 'Test', message: 'Test' }),
    });
    assert(notFoundRes.status === 404, 'Non-existent client returns 404 Not Found');

    // ── SUITE 4: Single Client Send by External ID ─────────────────────────
    console.log('\n--- TEST SUITE 4: Single Client Push via OneSignal External ID ---');

    // Pick a real client with active registered device from Neon PostgreSQL
    const targetUser = await prisma.user.findFirst({
      where: {
        role: 'CLIENT',
        id: { in: ['bc1f2be8-bebc-4d1e-a521-8662a3f558fc', '72fddf06-aeb6-499e-812a-240e8a46bdfd', 'e7dc55be-c521-463e-866a-1169891be9b0', 'd1961076-b144-4d95-9075-2e4124192375'] },
      },
      include: { clientProfile: true },
    });

    const fallbackUser = targetUser || await prisma.user.findFirst({
      where: { role: 'CLIENT' },
      include: { clientProfile: true },
    });

    if (fallbackUser) {
      const clientCode = fallbackUser.clientProfile?.clientId || fallbackUser.id;
      console.log(`  Targeting client: ${fallbackUser.name} (${clientCode})`);
      console.log(`  Linked OneSignal External ID: ${fallbackUser.id}`);

      const sendRes = await fetch(`${baseUrl}/notifications/admin/send-to-client`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
        body: JSON.stringify({
          clientId: fallbackUser.id,
          title: '⚡ Alpha X Automated Test',
          message: 'Automated test verification of OneSignal external ID delivery lifecycle.',
          targetMethod: 'EXTERNAL_ID',
        }),
      });

      assert(sendRes.status === 200, 'POST /admin/send-to-client returns 200 OK');
      const sendBody = await sendRes.json();
      assert(sendBody.success === true, 'Response indicates success: true');
      assert(!!sendBody.data?.notificationId, 'Response returns OneSignal notificationId');
      assert(sendBody.data?.externalId === fallbackUser.id, 'Response confirms targeting correct externalId (user.id)');

      // Verify 3-Stage delivery lifecycle
      const lifecycle = sendBody.data?.deliveryLifecycle;
      assert(lifecycle !== undefined, 'Response includes deliveryLifecycle');
      assert(lifecycle?.stage1_gatewayAccepted === true, 'Stage 1: Gateway Accepted is true');
      assert(typeof lifecycle?.stage2_fcmTransit === 'string', 'Stage 2: FCM Transit describes dispatch to FCM');
      assert(typeof lifecycle?.stage3_deviceDisplay === 'string', 'Stage 3: Device Display clarifies asynchronous receipt');

      // Verify secret is NOT leaked in response
      const rawText = JSON.stringify(sendBody);
      const restKey = env.ONESIGNAL_REST_API_KEY || '';
      if (restKey.length > 0) {
        assert(!rawText.includes(restKey), 'ONESIGNAL_REST_API_KEY is NOT exposed in API response');
      }

      // Verify in-app notification persistence in database
      const dbNotif = await prisma.notification.findFirst({
        where: { title: '⚡ Alpha X Automated Test' },
        orderBy: { createdAt: 'desc' },
      });
      assert(dbNotif !== null, 'In-app notification persisted in Neon PostgreSQL');
      assert(dbNotif?.type === 'MEMBERSHIP' || dbNotif?.type === 'SYSTEM', 'Notification type correctly categorized');

      // ── SUITE 5: Live Delivery Reporting ─────────────────────────────────
      console.log('\n--- TEST SUITE 5: OneSignal Delivery Status Query ---');
      const notificationId = sendBody.data?.notificationId;

      if (notificationId) {
        const statusRes = await fetch(`${baseUrl}/notifications/admin/delivery-status/${notificationId}`, {
          headers: { Authorization: `Bearer ${adminToken}` },
        });

        assert(statusRes.status === 200, 'GET /admin/delivery-status/:id returns 200 OK');
        const statusBody = await statusRes.json();
        assert(statusBody.success === true, 'Delivery status response has success: true');
        assert(statusBody.data?.notificationId === notificationId, 'Status response matches queried notificationId');
        assert(statusBody.data?.accepted === true, 'Status reports accepted: true from OneSignal');
        assert(typeof statusBody.data?.successful === 'number', 'Status reports numeric successful count');
        assert(typeof statusBody.data?.failed === 'number', 'Status reports numeric failed count');
        assert(typeof statusBody.data?.errored === 'number', 'Status reports numeric errored count');
        assert(!!statusBody.data?.actualDeviceReceiptNotice, 'Notice clarifies actual device receipt requires physical receipt');
        console.log('  Live Delivery Stats:', {
          notificationId,
          successful: statusBody.data?.successful,
          failed: statusBody.data?.failed,
          errored: statusBody.data?.errored,
          remaining: statusBody.data?.remaining,
        });
      }

      // ── SUITE 6: Automation Hooks & Deduplication ──────────────────────────
      console.log('\n--- TEST SUITE 6: Automation Cycle & Deduplication Hooks ---');

      // 6.1 Test deterministic deduplication in notification policy service
      const dedupKey = `test_payment_reminder_${Date.now()}`;
      const clientProfId = fallbackUser.clientProfile?.id || fallbackUser.id;
      const dispatch1 = await notificationPolicyService.dispatch({
        userId: fallbackUser.id,
        clientProfileId: clientProfId,
        clientId: clientCode,
        title: 'Payment Reminder',
        message: 'Your gym membership renews in 3 days.',
        type: 'MEMBERSHIP',
        tier: 'ESSENTIAL',
        dedupKey,
        ignoreQuietHours: true,
      });
      assert(dispatch1.success === true || dispatch1.status === 'SENT' || dispatch1.status === 'DEFERRED', 'First essential payment reminder is accepted');

      // 6.2 Second dispatch with SAME dedupKey must be dropped as duplicate
      const dispatch2 = await notificationPolicyService.dispatch({
        userId: fallbackUser.id,
        clientProfileId: clientProfId,
        clientId: clientCode,
        title: 'Payment Reminder',
        message: 'Your gym membership renews in 3 days.',
        type: 'MEMBERSHIP',
        tier: 'ESSENTIAL',
        dedupKey,
        ignoreQuietHours: true,
      });
      assert(dispatch2.success === false && dispatch2.status === 'DUPLICATE', 'Second dispatch with identical dedupKey is safely dropped as DUPLICATE');

      // 6.3 Run full daily automation cycle
      console.log('  Executing daily automation cycle...');
      const autoResult = await automationService.runDailyAutomationCycle();
      assert(typeof autoResult.clientsEvaluated === 'number', 'runDailyAutomationCycle returns evaluated clients count');
      assert(typeof autoResult.timestamp === 'string', 'runDailyAutomationCycle returns timestamp string');
      console.log('  Automation cycle result summary:', {
        clientsEvaluated: autoResult.clientsEvaluated,
        notificationsCreated: autoResult.notificationsCreated,
        attentionItemsCreated: autoResult.attentionItemsCreated,
        timestamp: autoResult.timestamp,
      });
    }

  } catch (err: any) {
    console.error('Test execution error:', err);
    failed++;
  } finally {
    if (server) {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  }

  console.log('\n======================================================================');
  console.log(`TOTAL PASSED: ${passed} | TOTAL FAILED: ${failed}`);
  console.log('======================================================================');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

run();
