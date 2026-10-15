import assert from 'assert';
import http from 'http';
import jwt from 'jsonwebtoken';
import app from './server';
import { prisma } from './config/prisma';
import { env } from './config/environment';

// Helper to make HTTP requests
function makeRequest(
  baseUrl: string,
  method: string,
  path: string,
  headers: Record<string, string> = {},
  body?: any
): Promise<{ status: number; headers: http.IncomingHttpHeaders; json: any; rawBuffer: Buffer }> {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const bodyStr = body ? JSON.stringify(body) : undefined;
    const reqHeaders: Record<string, string> = { ...headers };
    if (bodyStr) {
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(bodyStr).toString();
    }

    const req = http.request(
      url,
      {
        method,
        headers: reqHeaders,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const rawBuffer = Buffer.concat(chunks);
          let json = null;
          try {
            json = JSON.parse(rawBuffer.toString('utf8'));
          } catch (_) {}
          resolve({
            status: res.statusCode || 0,
            headers: res.headers,
            json,
            rawBuffer,
          });
        });
      }
    );

    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  });
}

// 1x1 transparent JPEG base64
const sampleJpgBase64 =
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

async function runTests() {
  console.log('\n===============================================================');
  console.log('🧪 RUNNING ALPHA X TRANSFORMATION PROGRESS & COMPARISON TESTS');
  console.log('===============================================================\n');

  // Start test server
  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}`;

  let userA: any;
  let userB: any;
  let adminUser: any;
  let profileA: any;
  let profileB: any;

  try {
    // 1. Setup Test Users
    const timestamp = Date.now();
    userA = await prisma.user.create({
      data: {
        email: `test_transform_a_${timestamp}@alphax.com`,
        passwordHash: 'dummy_hash',
        name: 'Transform Athlete A',
        role: 'CLIENT',
        status: 'APPROVED',
      },
    });

    profileA = await prisma.clientProfile.create({
      data: {
        userId: userA.id,
        clientId: `AXG-TR${timestamp.toString().slice(-4)}A`,
        weightKg: 85.0,
        heightCm: 180,
      },
    });

    userB = await prisma.user.create({
      data: {
        email: `test_transform_b_${timestamp}@alphax.com`,
        passwordHash: 'dummy_hash',
        name: 'Transform Athlete B',
        role: 'CLIENT',
        status: 'APPROVED',
      },
    });

    profileB = await prisma.clientProfile.create({
      data: {
        userId: userB.id,
        clientId: `AXG-TR${timestamp.toString().slice(-4)}B`,
        weightKg: 70.0,
        heightCm: 172,
      },
    });

    adminUser = await prisma.user.findFirst({
      where: { email: env.ADMIN_EMAIL.trim().toLowerCase() },
    });
    if (!adminUser) {
      adminUser = await prisma.user.create({
        data: {
          email: env.ADMIN_EMAIL.trim().toLowerCase(),
          passwordHash: 'admin_hash',
          name: 'Master Coach',
          role: 'ADMIN',
          status: 'APPROVED',
        },
      });
    }

    const tokenA = jwt.sign(
      { id: userA.id, email: userA.email, role: 'CLIENT' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const tokenB = jwt.sign(
      { id: userB.id, email: userB.email, role: 'CLIENT' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const adminToken = jwt.sign(
      { id: adminUser.id, email: adminUser.email, role: 'ADMIN' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    console.log(`✔ Initialized test clients: ${profileA.clientId} & ${profileB.clientId}`);

    // TEST 1: Client A uploads Baseline Week 1 "Before" Front Photo
    console.log('\n--- TEST 1: Client A Uploads Week 1 Baseline Photo ---');
    const uploadWeek1Res = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/transformation-timeline/upload-photo',
      { Authorization: `Bearer ${tokenA}` },
      {
        weekNumber: 1,
        angle: 'front',
        imageBase64: sampleJpgBase64,
        mimeType: 'image/jpeg',
        weightKg: 85.5,
        waistCm: 90.0,
        notes: 'Week 1 baseline front photo before starting strength cycle.',
        date: '2026-09-01T10:00:00.000Z',
      }
    );

    assert.strictEqual(uploadWeek1Res.status, 201, 'Week 1 photo upload must return 201');
    assert.strictEqual(uploadWeek1Res.json.success, true);
    assert.ok(uploadWeek1Res.json.data.photoUrl, 'Must return photoUrl');
    assert.strictEqual(uploadWeek1Res.json.data.angle, 'front');
    assert.strictEqual(uploadWeek1Res.json.data.milestone.weightKg, 85.5);
    assert.strictEqual(uploadWeek1Res.json.data.milestone.hasFrontPhoto, true);
    console.log(`✔ Week 1 Before photo saved. URL: ${uploadWeek1Res.json.data.photoUrl}`);

    const week1MilestoneId = uploadWeek1Res.json.data.milestone.id;

    // TEST 2: Client A uploads Week 1 Side Photo (does not overwrite Front photo)
    console.log('\n--- TEST 2: Client A Uploads Week 1 Side Photo (Preserves Front) ---');
    const uploadSideRes = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/transformation-timeline/upload-photo',
      { Authorization: `Bearer ${tokenA}` },
      {
        weekNumber: 1,
        angle: 'side',
        imageBase64: sampleJpgBase64,
      }
    );
    assert.strictEqual(uploadSideRes.status, 201);
    assert.strictEqual(uploadSideRes.json.data.milestone.hasFrontPhoto, true, 'Front photo must be preserved');
    assert.strictEqual(uploadSideRes.json.data.milestone.hasSidePhoto, true, 'Side photo must be set');
    assert.strictEqual(uploadSideRes.json.data.milestone.weightKg, 85.5, 'Weight must be preserved');
    console.log('✔ Week 1 Side photo saved without overwriting Front photo or weight');

    // TEST 3: Client A uploads Later Week 8 "After" Photo
    console.log('\n--- TEST 3: Client A Uploads Week 8 "After" Photo ---');
    const uploadWeek8Res = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/transformation-timeline/upload-photo',
      { Authorization: `Bearer ${tokenA}` },
      {
        weekNumber: 8,
        angle: 'front',
        imageBase64: sampleJpgBase64,
        weightKg: 80.2,
        waistCm: 82.0,
        notes: 'Week 8 cut complete. Core definition visible.',
        date: '2026-10-12T10:00:00.000Z',
      }
    );
    assert.strictEqual(uploadWeek8Res.status, 201);
    assert.strictEqual(uploadWeek8Res.json.data.milestone.weekNumber, 8);
    assert.strictEqual(uploadWeek8Res.json.data.milestone.weightKg, 80.2);
    const week8MilestoneId = uploadWeek8Res.json.data.milestone.id;
    console.log(`✔ Week 8 After photo saved. ID: ${week8MilestoneId}, Weight: 80.2kg`);

    // TEST 4: Fetch Timeline - Both Before and After available
    console.log('\n--- TEST 4: Client A Fetches Timeline ---');
    const timelineRes = await makeRequest(
      baseUrl,
      'GET',
      '/api/v1/client/me/transformation-timeline',
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.strictEqual(timelineRes.status, 200);
    assert.strictEqual(timelineRes.json.data.length, 2, 'Must have 2 milestones (Week 1 & Week 8)');
    const week1 = timelineRes.json.data.find((m: any) => m.weekNumber === 1);
    const week8 = timelineRes.json.data.find((m: any) => m.weekNumber === 8);
    assert.ok(week1.frontPhotoUrl.includes(week1MilestoneId));
    assert.ok(week8.frontPhotoUrl.includes(week8MilestoneId));
    console.log('✔ Timeline contains both Week 1 and Week 8 with valid streaming URLs');

    // TEST 5: Secure Binary Image Streaming
    console.log('\n--- TEST 5: Secure Binary Image Streaming ---');
    // Using Bearer token
    const streamRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/transformation-photos/${week1MilestoneId}/front`,
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.strictEqual(streamRes.status, 200, 'Streaming must return 200');
    assert.ok(streamRes.headers['content-type']?.includes('image/'), 'Content-Type must be image');
    assert.ok(streamRes.rawBuffer.length > 0, 'Must stream binary photo data');
    console.log(`✔ Client A successfully streamed Week 1 photo (${streamRes.rawBuffer.length} bytes)`);

    // Using query token (?token=) for mobile Image.network
    const streamQueryRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/transformation-photos/${week1MilestoneId}/front?token=${tokenA}`
    );
    assert.strictEqual(streamQueryRes.status, 200);
    assert.ok(streamQueryRes.rawBuffer.length > 0);
    console.log('✔ Direct streaming verified via ?token= query parameter');

    // TEST 6: Strict Privacy - Client B cannot view Client A's transformation photo
    console.log('\n--- TEST 6: Client B Forbidden from Viewing Client A Photo ---');
    const forbiddenRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/transformation-photos/${week1MilestoneId}/front`,
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.strictEqual(forbiddenRes.status, 403, 'Unauthorized client must receive 403 Forbidden');
    console.log('✔ Client B received 403 Forbidden when attempting to access Client A photo');

    // TEST 7: Admin can view and stream Client A's transformation history
    console.log('\n--- TEST 7: Admin Views & Streams Client A Transformation History ---');
    const adminTimelineRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/admin/clients/${profileA.clientId}/transformation-timeline`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(adminTimelineRes.status, 200);
    assert.strictEqual(adminTimelineRes.json.data.length, 2);
    console.log(`✔ Admin fetched Client A (${profileA.clientId}) timeline: 2 milestones`);

    // Admin streaming Client A photo
    const adminStreamRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/transformation-photos/${week1MilestoneId}/front`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(adminStreamRes.status, 200, 'Admin must be able to stream client photo');
    console.log('✔ Admin successfully streamed Client A photo (200 OK)');

    // TEST 8: Admin Data Isolation - Client B has 0 milestones
    console.log('\n--- TEST 8: Client Data Isolation ---');
    const adminClientBTimeline = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/admin/clients/${profileB.clientId}/transformation-timeline`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(adminClientBTimeline.status, 200);
    assert.strictEqual(adminClientBTimeline.json.data.length, 0, 'Client B must have 0 milestones');
    console.log('✔ Verified complete client data isolation: no cross-contamination');

    // TEST 9: Updating measurements via POST /me/transformation-timeline preserves photos
    console.log('\n--- TEST 9: Measurement Update Preserves Photos ---');
    const updateWeightRes = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/transformation-timeline',
      { Authorization: `Bearer ${tokenA}` },
      {
        weekNumber: 8,
        weightKg: 79.5, // updated
        waistCm: 81.0,  // updated
      }
    );
    assert.strictEqual(updateWeightRes.status, 201);
    assert.strictEqual(updateWeightRes.json.data.weightKg, 79.5);
    assert.strictEqual(updateWeightRes.json.data.hasFrontPhoto, true, 'Front photo must still be present');
    console.log('✔ Metric update preserved existing photos');

    // TEST 10: Validation Errors
    console.log('\n--- TEST 10: Validation Errors & Edge Cases ---');
    // Invalid angle
    const invalidAngleRes = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/transformation-timeline/upload-photo',
      { Authorization: `Bearer ${tokenA}` },
      {
        weekNumber: 1,
        angle: 'invalid_angle',
        imageBase64: sampleJpgBase64,
      }
    );
    assert.strictEqual(invalidAngleRes.status, 400);

    // Empty image
    const emptyImageRes = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/transformation-timeline/upload-photo',
      { Authorization: `Bearer ${tokenA}` },
      {
        weekNumber: 1,
        angle: 'front',
        imageBase64: '',
      }
    );
    assert.strictEqual(emptyImageRes.status, 400);
    console.log('✔ Rejected invalid photo angle and empty image payload');

    console.log('\n===============================================================');
    console.log('🎉 ALL BACKEND TRANSFORMATION TESTS PASSED CLEANLY (10/10)!');
    console.log('===============================================================\n');
  } finally {
    // Cleanup test data
    if (profileA) await prisma.transformationMilestone.deleteMany({ where: { clientProfileId: profileA.id } });
    if (profileB) await prisma.transformationMilestone.deleteMany({ where: { clientProfileId: profileB.id } });
    if (profileA) await prisma.clientProfile.delete({ where: { id: profileA.id } });
    if (profileB) await prisma.clientProfile.delete({ where: { id: profileB.id } });
    if (userA) await prisma.user.delete({ where: { id: userA.id } });
    if (userB) await prisma.user.delete({ where: { id: userB.id } });

    server.close();
  }
}

runTests().catch((err) => {
  console.error('❌ TRANSFORMATION TEST FAILED:', err);
  process.exit(1);
});
