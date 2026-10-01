import assert from 'assert';
import http from 'http';
import app from './server';
import { prisma } from './config/prisma';
import { env } from './config/environment';
import { adminAuthService } from './modules/auth/admin_auth.service';
import jwt from 'jsonwebtoken';

async function makeRequest(
  serverUrl: string,
  method: string,
  path: string,
  headers: Record<string, string> = {},
  body?: any
): Promise<{ status: number; headers: http.IncomingHttpHeaders; body: any; rawBuffer: Buffer }> {
  return new Promise((resolve, reject) => {
    const url = new URL(path, serverUrl);
    const options: http.RequestOptions = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: { ...headers },
    };

    let postData: string | undefined;
    const reqHeaders: Record<string, any> = { ...headers };
    if (body !== undefined) {
      postData = typeof body === 'string' ? body : JSON.stringify(body);
      if (!reqHeaders['Content-Type']) {
        reqHeaders['Content-Type'] = 'application/json';
      }
      reqHeaders['Content-Length'] = Buffer.byteLength(postData);
    }
    options.headers = reqHeaders;

    const req = http.request(options, (res) => {
      const chunks: Buffer[] = [];
      res.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
      res.on('end', () => {
        const rawBuffer = Buffer.concat(chunks);
        let parsedBody: any = null;
        const contentType = res.headers['content-type'] || '';
        if (contentType.includes('application/json')) {
          try {
            parsedBody = JSON.parse(rawBuffer.toString('utf-8'));
          } catch (_) {
            parsedBody = rawBuffer.toString('utf-8');
          }
        } else {
          parsedBody = rawBuffer;
        }
        resolve({
          status: res.statusCode || 500,
          headers: res.headers,
          body: parsedBody,
          rawBuffer,
        });
      });
    });

    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

// 1x1 transparent JPEG
const SAMPLE_IMAGE_BASE64 =
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

async function runLiveFoodPhotoTests() {
  console.log('================================================================');
  console.log('ALPHA X GYM — LIVE FOOD PHOTO TRACKING & ADMIN VERIFICATION TEST');
  console.log('================================================================\n');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address() as any;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  console.log(`Test server running at ${baseUrl}`);

  try {
    // 1. Setup Test Client & Admin Tokens
    const clientUser = await prisma.user.upsert({
      where: { email: 'live_food_test_athlete@alphaxgym.com' },
      update: {},
      create: {
        email: 'live_food_test_athlete@alphaxgym.com',
        name: 'Sundar Athlete',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-8888',
          },
        },
      },
      include: { clientProfile: true },
    });

    const clientProfile = clientUser.clientProfile!;
    const clientToken = jwt.sign(
      { id: clientUser.id, email: clientUser.email, role: 'CLIENT', clientId: clientProfile.clientId },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const clientBUser = await prisma.user.upsert({
      where: { email: 'client_b_isolation_test@alphaxgym.com' },
      update: {},
      create: {
        email: 'client_b_isolation_test@alphaxgym.com',
        name: 'Other Athlete',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-9999',
          },
        },
      },
      include: { clientProfile: true },
    });

    const clientBToken = jwt.sign(
      { id: clientBUser.id, email: clientBUser.email, role: 'CLIENT', clientId: clientBUser.clientProfile!.clientId },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const adminSession = adminAuthService.generateAdminSession();
    const adminToken = adminSession.token;

    // TEST 1: Record Live Food Photo (Lunch)
    console.log('TEST 1: Client captures live food photo for Lunch with note');
    const captureTimestamp = new Date().toISOString();
    const uploadRes = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/food-photos/live',
      { Authorization: `Bearer ${clientToken}` },
      {
        image: SAMPLE_IMAGE_BASE64,
        mealType: 'Lunch',
        capturedAt: captureTimestamp,
        timezone: 'Asia/Kolkata',
        clientNote: 'Chicken rice + roasted vegetables',
      }
    );

    assert.strictEqual(uploadRes.status, 201, `Upload failed: ${JSON.stringify(uploadRes.body)}`);
    assert.strictEqual(uploadRes.body.success, true);
    const photo = uploadRes.body.data.foodPhoto;
    assert.ok(photo.id, 'Photo ID should exist');
    assert.strictEqual(photo.clientId, 'AXG-8888');
    assert.strictEqual(photo.mealType, 'Lunch');
    assert.strictEqual(photo.status, 'PENDING', 'New photo must be PENDING review');
    assert.strictEqual(photo.clientNote, 'Chicken rice + roasted vegetables');
    console.log(`  ✓ Live photo captured with status: ${photo.status}, ID: ${photo.id}`);

    // TEST 2: Ensure food photo is NOT automatically inserted into ClientFoodLog
    console.log('\nTEST 2: Verify Food Photo is evidence-only and NOT added to ClientFoodLog');
    const foodLogs = await prisma.clientFoodLog.findMany({
      where: { clientProfileId: clientProfile.id },
    });
    const photoLogEntries = foodLogs.filter((log) => log.mealId?.startsWith('live_'));
    assert.strictEqual(photoLogEntries.length, 0, 'Food photo must NOT create food log entries');
    console.log('  ✓ Verified: 0 food log entries created. Food log remains clean and separate.');

    // TEST 3: Client History (GET /api/v1/food-photos/my-photos)
    console.log('\nTEST 3: Client retrieves their photo history');
    const historyRes = await makeRequest(baseUrl, 'GET', '/api/v1/food-photos/my-photos', {
      Authorization: `Bearer ${clientToken}`,
    });
    assert.strictEqual(historyRes.status, 200);
    assert.strictEqual(historyRes.body.success, true);
    const myPhotos = historyRes.body.data.photos;
    assert.ok(myPhotos.length >= 1, 'Should have at least 1 photo');
    const latest = myPhotos[0];
    assert.strictEqual(latest.id, photo.id);
    assert.strictEqual(latest.status, 'PENDING');
    assert.strictEqual(historyRes.body.data.summary.totalToday >= 1, true);
    assert.strictEqual(historyRes.body.data.summary.lunchRecorded, true);
    console.log(`  ✓ Client history retrieved: ${myPhotos.length} photos, lunchRecorded: true, pending: ${historyRes.body.data.summary.pendingCount}`);

    // TEST 4: Client Isolation (Client B cannot see Client A's photo)
    console.log("\nTEST 4: Client isolation (Client B cannot see Client A's photo)");
    const clientBHistoryRes = await makeRequest(baseUrl, 'GET', '/api/v1/food-photos/my-photos', {
      Authorization: `Bearer ${clientBToken}`,
    });
    assert.strictEqual(clientBHistoryRes.status, 200);
    const clientBPhotos = clientBHistoryRes.body.data.photos;
    const hasPhotoA = clientBPhotos.some((p: any) => p.id === photo.id);
    assert.strictEqual(hasPhotoA, false, "Client B must NOT see Client A's food photos");

    // Direct access attempt by Client B to photo metadata
    const directAccessRes = await makeRequest(baseUrl, 'GET', `/api/v1/food-photos/${photo.id}`, {
      Authorization: `Bearer ${clientBToken}`,
    });
    assert.strictEqual(directAccessRes.status, 403, 'Direct access to another client photo must be forbidden (403)');
    console.log('  ✓ Client isolation verified: 403 Forbidden for unauthorized client.');

    // TEST 5: Admin Monitoring Dashboard (GET /api/v1/food-photos/admin/monitoring)
    console.log('\nTEST 5: Admin retrieves food photos monitoring dashboard');
    const adminMonitoringRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/admin/monitoring?clientId=AXG-8888`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(adminMonitoringRes.status, 200);
    assert.strictEqual(adminMonitoringRes.body.success, true);
    const adminPhotos = adminMonitoringRes.body.data.photos;
    assert.ok(adminPhotos.length >= 1);
    const targetPhoto = adminPhotos.find((p: any) => p.id === photo.id);
    assert.ok(targetPhoto, 'Admin must see Client A photo');
    assert.strictEqual(targetPhoto.clientName, 'Sundar Athlete');
    assert.strictEqual(targetPhoto.status, 'PENDING');
    console.log(`  ✓ Admin monitoring verified: found photo for Sundar Athlete (${targetPhoto.mealType})`);

    // TEST 6: Admin Verifies Photo (PATCH /api/v1/food-photos/:id/verify)
    console.log('\nTEST 6: Admin marks photo as VERIFIED');
    const verifyRes = await makeRequest(
      baseUrl,
      'PATCH',
      `/api/v1/food-photos/${photo.id}/verify`,
      { Authorization: `Bearer ${adminToken}` },
      {
        status: 'VERIFIED',
        adminNote: 'Excellent portion control and protein source.',
      }
    );
    assert.strictEqual(verifyRes.status, 200);
    assert.strictEqual(verifyRes.body.data.foodPhoto.status, 'VERIFIED');
    assert.strictEqual(verifyRes.body.data.foodPhoto.adminNote, 'Excellent portion control and protein source.');
    console.log('  ✓ Photo verified by Admin with note.');

    // TEST 7: Client Sees Updated Status (✓ Verified)
    console.log('\nTEST 7: Client checks status and sees ✓ Verified');
    const clientRefreshRes = await makeRequest(baseUrl, 'GET', '/api/v1/food-photos/my-photos', {
      Authorization: `Bearer ${clientToken}`,
    });
    const updatedClientPhoto = clientRefreshRes.body.data.photos.find((p: any) => p.id === photo.id);
    assert.strictEqual(updatedClientPhoto.status, 'VERIFIED');
    assert.strictEqual(updatedClientPhoto.adminNote, 'Excellent portion control and protein source.');
    console.log(`  ✓ Client sees updated status: ${updatedClientPhoto.status} with trainer note.`);

    // TEST 8: Admin Flags Photo as NEEDS_ATTENTION
    console.log('\nTEST 8: Admin flags photo as NEEDS_ATTENTION with guidance');
    const attentionRes = await makeRequest(
      baseUrl,
      'PATCH',
      `/api/v1/food-photos/${photo.id}/verify`,
      { Authorization: `Bearer ${adminToken}` },
      {
        status: 'NEEDS_ATTENTION',
        adminNote: 'Please follow the assigned diet for dinner: add more greens.',
      }
    );
    assert.strictEqual(attentionRes.status, 200);
    assert.strictEqual(attentionRes.body.data.foodPhoto.status, 'NEEDS_ATTENTION');

    // Verify Notification generated for client
    const notifications = await prisma.notification.findMany({
      where: { clientId: 'AXG-8888', category: 'FOOD_PHOTO_REVIEW' },
    });
    assert.ok(notifications.length >= 1, 'Client should receive review notification');
    console.log(`  ✓ Photo marked as NEEDS_ATTENTION; notification created: "${notifications[0].message}"`);

    // TEST 9: Secure Streaming of Photo Binary (GET /api/v1/food-photos/:id/image)
    console.log('\nTEST 9: Secure image binary streaming for authorized user');
    const streamRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/${photo.id}/image`,
      { Authorization: `Bearer ${clientToken}` }
    );
    assert.strictEqual(streamRes.status, 200);
    assert.ok(streamRes.headers['content-type']?.includes('image'));
    assert.ok(streamRes.rawBuffer.length > 0);
    console.log(`  ✓ Image streamed successfully (${streamRes.rawBuffer.length} bytes, ${streamRes.headers['content-type']})`);

    console.log('\n================================================================');
    console.log('ALL 9 BACKEND LIVE FOOD PHOTO TRACKING & VERIFICATION TESTS PASSED!');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

runLiveFoodPhotoTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test failed with error:', err);
    process.exit(1);
  });
