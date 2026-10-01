import assert from 'assert';
import http from 'http';
import fs from 'fs';
import path from 'path';
import app from './server';
import { prisma } from './config/prisma';
import { env } from './config/environment';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { mealPhotoStorageService } from './modules/food/meal_photo_storage.service';
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
      if (typeof body === 'string') {
        postData = body;
      } else {
        postData = JSON.stringify(body);
        if (!reqHeaders['Content-Type']) {
          reqHeaders['Content-Type'] = 'application/json';
        }
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
          status: res.statusCode || 0,
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

// 1x1 Transparent JPEG for testing
const SAMPLE_JPEG_BASE64 =
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

async function runMealPhotoTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING ALPHA X CONFIRMED MEAL PHOTO & SECURITY TESTS');
  console.log('====================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  const address = server.address() as any;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  console.log(`📡 Test server running at ${baseUrl}`);

  try {
    // 1. Prepare two client accounts for isolation testing
    const clientAUser = await prisma.user.upsert({
      where: { email: 'photo_client_a@alphaxgym.test' },
      update: {},
      create: {
        name: 'Client Alpha',
        email: 'photo_client_a@alphaxgym.test',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-7001',
            fitnessLevel: 'intermediate',
            primaryGoal: 'Fat Loss',
          },
        },
      },
      include: { clientProfile: true },
    });

    const clientBUser = await prisma.user.upsert({
      where: { email: 'photo_client_b@alphaxgym.test' },
      update: {},
      create: {
        name: 'Client Beta',
        email: 'photo_client_b@alphaxgym.test',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-7002',
            fitnessLevel: 'beginner',
            primaryGoal: 'Muscle Gain',
          },
        },
      },
      include: { clientProfile: true },
    });

    const tokenA = jwt.sign(
      { id: clientAUser.id, email: clientAUser.email, role: 'CLIENT', clientId: clientAUser.clientProfile!.clientId },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const tokenB = jwt.sign(
      { id: clientBUser.id, email: clientBUser.email, role: 'CLIENT', clientId: clientBUser.clientProfile!.clientId },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const adminSession = adminAuthService.generateAdminSession();
    const adminToken = adminSession.token;

    console.log('✔ Test clients (Client A: AXG-7001, Client B: AXG-7002) and Admin session initialized');

    // Clean up any previous test artifacts
    await prisma.clientFoodLog.deleteMany({ where: { clientProfileId: clientAUser.clientProfile!.id } });
    await prisma.mealPhoto.deleteMany({ where: { clientProfileId: clientAUser.clientProfile!.id } });

    // ----------------------------------------------------
    // TEST 1: Client A Confirms and Uploads Live Scanned Meal Photo
    // ----------------------------------------------------
    console.log('\n--- TEST 1: Client A Confirms and Uploads Meal Photo ---');
    const todayStr = '2026-10-01';
    const uploadPayload = {
      imageBase64: SAMPLE_JPEG_BASE64,
      mimeType: 'image/jpeg',
      mealId: `meal_${Date.now()}`,
      dateString: todayStr,
      mealType: 'Breakfast',
      weightSource: 'AI_ESTIMATE',
      items: [
        {
          foodName: 'Brown Rice',
          foodId: 'rice_1',
          servingSize: 150,
          servingUnit: 'g',
          quantity: 1.0,
          calories: 165,
          protein: 3.5,
          carbohydrates: 35,
          fat: 1.2,
          fiber: 2.0,
          category: 'Rice & Meals',
          source: 'AI_CAMERA',
          weightSource: 'AI_ESTIMATE',
        },
        {
          foodName: 'Boiled Egg',
          foodId: 'egg_1',
          servingSize: 50,
          servingUnit: 'g',
          quantity: 2.0,
          calories: 140,
          protein: 12,
          carbohydrates: 1,
          fat: 10,
          fiber: 0,
          category: 'Protein',
          source: 'AI_CAMERA',
          weightSource: 'CLIENT_ENTERED',
        },
      ],
    };

    const confirmRes = await makeRequest(baseUrl, 'POST', '/api/v1/client/me/food-photos/confirm', {
      Authorization: `Bearer ${tokenA}`,
    }, uploadPayload);

    assert.strictEqual(confirmRes.status, 201, 'Confirm meal photo must return 201 CREATED');
    assert.strictEqual(confirmRes.body.success, true);
    const mealPhoto = confirmRes.body.data.mealPhoto;
    assert.ok(mealPhoto.id, 'MealPhoto ID must be created');
    assert.strictEqual(mealPhoto.photoAvailable, true);
    assert.strictEqual(mealPhoto.mealType, 'Breakfast');
    assert.strictEqual(mealPhoto.totalCalories, 445); // 165 + 140 * 2
    console.log(`✔ Meal photo successfully confirmed: ID ${mealPhoto.id} for client ${mealPhoto.clientId}`);

    // Verify linked ClientFoodLog records
    const foodLogs = confirmRes.body.data.foodLogs;
    assert.strictEqual(foodLogs.length, 2, 'Should create 2 ClientFoodLog entries');
    assert.strictEqual(foodLogs[0].photoAvailable, true);
    assert.strictEqual(foodLogs[0].mealPhotoId, mealPhoto.id);
    console.log('✔ Linked ClientFoodLog entries created with photoAvailable: true');

    // ----------------------------------------------------
    // TEST 2: Storage Verification (Saved to private storage)
    // ----------------------------------------------------
    console.log('\n--- TEST 2: Private Storage Verification ---');
    const photoRecord = await prisma.mealPhoto.findUnique({ where: { id: mealPhoto.id } });
    assert.ok(photoRecord, 'MealPhoto record must exist in DB');
    const fullDiskPath = mealPhotoStorageService.getAbsoluteFilePath(photoRecord.storagePath);
    assert.ok(fs.existsSync(fullDiskPath), `File must exist on disk at ${fullDiskPath}`);
    console.log(`✔ Confirmed meal photo verified on disk: ${fullDiskPath} (${photoRecord.fileSizeBytes} bytes)`);

    // ----------------------------------------------------
    // TEST 3: Security & Access Control
    // ----------------------------------------------------
    console.log('\n--- TEST 3: Authenticated Image Access & Security Isolation ---');

    // 3a. Client A requests their own photo -> 200 OK
    const clientAGetRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/${mealPhoto.id}/image`,
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.strictEqual(clientAGetRes.status, 200, 'Client A must be able to view their own photo');
    assert.strictEqual(clientAGetRes.headers['content-type'], 'image/jpeg');
    assert.ok(clientAGetRes.rawBuffer.length > 0, 'Image binary must be streamed');
    console.log('✔ Client A successfully streamed their own photo (200 OK)');

    // 3b. Client B (different client) requests Client A's photo -> 403 FORBIDDEN
    const clientBGetRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/${mealPhoto.id}/image`,
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.strictEqual(clientBGetRes.status, 403, 'Client B MUST be denied access to Client A photo (403)');
    console.log('✔ Client B was strictly FORBIDDEN (403) from accessing Client A meal photo');

    // 3c. Unauthenticated request without token -> 401 UNAUTHORIZED
    const unauthGetRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/${mealPhoto.id}/image`
    );
    assert.strictEqual(unauthGetRes.status, 401, 'Unauthenticated request must be denied (401)');
    console.log('✔ Unauthenticated photo request was strictly rejected (401)');

    // 3d. Master Admin requests Client A's photo -> 200 OK
    const adminGetRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/${mealPhoto.id}/image`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(adminGetRes.status, 200, 'Master Admin must be authorized to view client photo (200 OK)');
    assert.strictEqual(adminGetRes.headers['content-type'], 'image/jpeg');
    console.log('✔ Master Admin successfully streamed Client A photo (200 OK)');

    // 3e. Query token authentication (for Flutter Image.network ?token=...)
    const queryTokenRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/food-photos/${mealPhoto.id}/image?token=${tokenA}`
    );
    assert.strictEqual(queryTokenRes.status, 200, 'Query token parameter ?token= must be supported for image widget');
    console.log('✔ Image streaming verified via signed query token ?token= (200 OK)');

    // ----------------------------------------------------
    // TEST 4: Admin Nutrition Summary with Photo Integration
    // ----------------------------------------------------
    console.log('\n--- TEST 4: Admin Nutrition Summary with Meal Photos ---');
    const adminSummaryRes = await makeRequest(
      baseUrl,
      'GET',
      `/api/v1/admin/clients/${clientAUser.id}/nutrition-summary?date=${todayStr}`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(adminSummaryRes.status, 200);
    const summaryData = adminSummaryRes.body.data;
    assert.ok(summaryData.mealPhotos, 'Nutrition summary must include mealPhotos array');
    assert.strictEqual(summaryData.mealPhotos.length, 1);
    assert.ok(summaryData.mealPhotosByType.Breakfast, 'Breakfast must have photos in mealPhotosByType');
    assert.strictEqual(summaryData.mealPhotosByType.Breakfast[0].photoAvailable, true);
    assert.strictEqual(summaryData.mealPhotosByType.Breakfast[0].weightSource, 'AI_ESTIMATE');
    console.log('✔ Admin nutrition summary returns meal photos grouped by Breakfast/Lunch/Snacks/Dinner');

    // ----------------------------------------------------
    // TEST 5: Manual Logging Without Photo (Zero Breaking Changes)
    // ----------------------------------------------------
    console.log('\n--- TEST 5: Manual Meal Logging Without Photo ---');
    const manualLogRes = await makeRequest(
      baseUrl,
      'POST',
      '/api/v1/client/me/food-logs',
      { Authorization: `Bearer ${tokenA}` },
      {
        foodName: 'Almonds',
        category: 'Nuts & Seeds',
        servingSize: 30,
        servingUnit: 'g',
        quantity: 1.0,
        calories: 170,
        protein: 6,
        carbohydrates: 6,
        fat: 15,
        fiber: 3.5,
        mealType: 'Snacks',
        source: 'FOOD_LIBRARY',
        dateString: todayStr,
      }
    );
    assert.strictEqual(manualLogRes.status, 201);
    const createdManualLog = manualLogRes.body.data[0];
    assert.strictEqual(createdManualLog.photoAvailable, false, 'Manual log must have photoAvailable: false');
    assert.strictEqual(createdManualLog.mealPhotoId, null);
    console.log('✔ Manual food log successfully logged with photoAvailable: false (Zero regressions)');

    // ----------------------------------------------------
    // TEST 6: Admin Meal Photo Deletion
    // ----------------------------------------------------
    console.log('\n--- TEST 6: Admin Meal Photo Deletion & Storage Cleanup ---');
    const deleteRes = await makeRequest(
      baseUrl,
      'DELETE',
      `/api/v1/admin/meal-photos/${mealPhoto.id}`,
      { Authorization: `Bearer ${adminToken}` }
    );
    assert.strictEqual(deleteRes.status, 200, 'Admin can delete meal photo');
    assert.strictEqual(deleteRes.body.data.deleted, true);

    // Verify file deleted from disk
    assert.strictEqual(fs.existsSync(fullDiskPath), false, 'Photo file must be removed from disk');
    console.log('✔ Photo successfully deleted from storage and marked deleted in DB');

    console.log('\n====================================================');
    console.log('🎉 ALL CONFIRMED MEAL PHOTO & SECURITY TESTS PASSED!');
    console.log('====================================================\n');
  } finally {
    server.close();
  }
}

runMealPhotoTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
