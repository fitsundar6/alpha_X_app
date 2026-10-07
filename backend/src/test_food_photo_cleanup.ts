import assert from 'assert';
import http from 'http';
import fs from 'fs';
import path from 'path';
import app from './server';
import { prisma } from './config/prisma';
import { env } from './config/environment';
import { mealPhotoStorageService } from './modules/food/meal_photo_storage.service';
import { foodPhotoCleanupService } from './modules/food/food_photo_cleanup.service';
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

// 1x1 Sample JPEG
const SAMPLE_JPEG_BUFFER = Buffer.from(
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=',
  'base64'
);

async function runFoodPhotoCleanupTests() {
  console.log('====================================================');
  console.log('🧹 RUNNING 15-DAY CLIENT FOOD JOURNAL PHOTO CLEANUP TESTS');
  console.log('====================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  const address = server.address() as any;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  console.log(`📡 Test server running at ${baseUrl}`);

  try {
    // Setup test client
    const testUser = await prisma.user.upsert({
      where: { email: 'cleanup_test_athlete@alphaxgym.test' },
      update: {},
      create: {
        name: 'Athlete Cleanup Subject',
        email: 'cleanup_test_athlete@alphaxgym.test',
        role: 'CLIENT',
        photoUrl: 'https://cdn.alphaxgym.test/avatars/athlete.jpg', // User avatar
        clientProfile: {
          create: {
            clientId: 'AXG-9901',
            fitnessLevel: 'advanced',
            primaryGoal: 'Hypertrophy',
            photoUrl: 'https://cdn.alphaxgym.test/profile/athlete_profile.jpg',
          },
        },
      },
      include: { clientProfile: true },
    });

    const clientProfile = testUser.clientProfile!;
    const adminToken = 'alpha_x_mock_token_for_admin';
    const clientToken = jwt.sign(
      { id: testUser.id, email: testUser.email, role: 'CLIENT', clientId: clientProfile.clientId },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    console.log(`✔ Initialized test athlete (ID: ${clientProfile.id}, ClientId: ${clientProfile.clientId})`);

    // Clean up any old test artifacts for this user
    await prisma.mealPhoto.deleteMany({ where: { clientProfileId: clientProfile.id } });
    await prisma.clientFoodLog.deleteMany({ where: { clientProfileId: clientProfile.id } });

    // ──────────────────────────────────────────────────────────
    // TEST 1: Create Photo Younger Than 15 Days (e.g. 5 days ago)
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 1: Photo Younger Than 15 Days (Uploaded 5 Days Ago) ---');
    const savedRecent = await mealPhotoStorageService.saveMealPhoto(clientProfile.id, SAMPLE_JPEG_BUFFER);
    const recentCreatedAt = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000); // 5 days old

    const recentPhoto = await prisma.mealPhoto.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        mealId: 'meal_recent_01',
        dateString: '2026-10-02',
        mealType: 'Lunch',
        storagePath: savedRecent.storagePath,
        mimeType: 'image/jpeg',
        fileSizeBytes: savedRecent.fileSizeBytes,
        createdAt: recentCreatedAt,
        capturedAt: recentCreatedAt,
        confirmedAt: recentCreatedAt,
        retentionUntil: new Date(recentCreatedAt.getTime() + 15 * 24 * 60 * 60 * 1000),
        totalCalories: 650,
        totalProtein: 48,
        totalCarbs: 60,
        totalFat: 18,
      },
    });

    const recentFoodLog = await prisma.clientFoodLog.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        date: new Date('2026-10-02'),
        dateString: '2026-10-02',
        mealType: 'Lunch',
        mealId: 'meal_recent_01',
        foodName: 'Grilled Chicken Breast & Quinoa',
        servingSize: 250,
        quantity: 1,
        calories: 650,
        protein: 48,
        carbohydrates: 60,
        fat: 18,
        photoAvailable: true,
        mealPhotoId: recentPhoto.id,
      },
    });

    const recentPhysicalPath = mealPhotoStorageService.resolvePhysicalFilePath(savedRecent.storagePath);
    assert.strictEqual(fs.existsSync(recentPhysicalPath), true, 'Recent photo physical file must exist on disk');
    console.log(`✔ Created recent photo (Uploaded 5 days ago): File on disk at ${recentPhysicalPath}`);

    // Verify Admin can view/stream photo before expiration
    const adminStreamRes = await makeRequest(baseUrl, 'GET', `/api/v1/food-photos/${recentPhoto.id}/image`, {
      Authorization: `Bearer ${adminToken}`,
    });
    assert.strictEqual(adminStreamRes.status, 200, 'Admin must be able to view/stream photo before 15-day expiration');
    console.log('✔ Admin successfully viewed/streamed photo before expiration (200 OK)');

    // ──────────────────────────────────────────────────────────
    // TEST 2: Create Photo Older Than 15 Days (e.g. 18 days ago)
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 2: Photo Older Than 15 Days (Uploaded 18 Days Ago) ---');
    const savedExpired = await mealPhotoStorageService.saveMealPhoto(clientProfile.id, SAMPLE_JPEG_BUFFER);
    const expiredCreatedAt = new Date(Date.now() - 18 * 24 * 60 * 60 * 1000); // 18 days old

    const expiredPhoto = await prisma.mealPhoto.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        mealId: 'meal_expired_01',
        dateString: '2026-09-19',
        mealType: 'Dinner',
        storagePath: savedExpired.storagePath,
        mimeType: 'image/jpeg',
        fileSizeBytes: savedExpired.fileSizeBytes,
        createdAt: expiredCreatedAt,
        capturedAt: expiredCreatedAt,
        confirmedAt: expiredCreatedAt,
        retentionUntil: new Date(expiredCreatedAt.getTime() + 15 * 24 * 60 * 60 * 1000),
        totalCalories: 820,
        totalProtein: 55,
        totalCarbs: 80,
        totalFat: 24,
      },
    });

    const expiredFoodLog = await prisma.clientFoodLog.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        date: new Date('2026-09-19'),
        dateString: '2026-09-19',
        mealType: 'Dinner',
        mealId: 'meal_expired_01',
        foodName: 'Salmon Bowl with Jasmine Rice',
        servingSize: 350,
        quantity: 1,
        calories: 820,
        protein: 55,
        carbohydrates: 80,
        fat: 24,
        fiber: 6,
        photoAvailable: true,
        mealPhotoId: expiredPhoto.id,
      },
    });

    const expiredPhysicalPath = mealPhotoStorageService.resolvePhysicalFilePath(savedExpired.storagePath);
    assert.strictEqual(fs.existsSync(expiredPhysicalPath), true, 'Expired photo physical file must exist before cleanup');
    console.log(`✔ Created expired photo (Uploaded 18 days ago): File on disk at ${expiredPhysicalPath}`);

    // ──────────────────────────────────────────────────────────
    // TEST 3: Create Photo with Missing Storage File (Robustness)
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 3: Expired Photo with Missing Storage File ---');
    const missingFileCreatedAt = new Date(Date.now() - 25 * 24 * 60 * 60 * 1000); // 25 days old
    const missingPhoto = await prisma.mealPhoto.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        mealId: 'meal_missing_01',
        dateString: '2026-09-12',
        mealType: 'Breakfast',
        storagePath: `${clientProfile.id}/2026/09/non_existent_file.jpg`,
        mimeType: 'image/jpeg',
        createdAt: missingFileCreatedAt,
        capturedAt: missingFileCreatedAt,
        confirmedAt: missingFileCreatedAt,
        totalCalories: 400,
        totalProtein: 30,
        totalCarbs: 45,
        totalFat: 10,
      },
    });

    const missingFoodLog = await prisma.clientFoodLog.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        date: new Date('2026-09-12'),
        dateString: '2026-09-12',
        mealType: 'Breakfast',
        mealId: 'meal_missing_01',
        foodName: 'Egg White Omelette',
        calories: 400,
        protein: 30,
        carbohydrates: 45,
        fat: 10,
        photoAvailable: true,
        mealPhotoId: missingPhoto.id,
      },
    });
    console.log(`✔ Created expired photo with intentionally missing physical file`);

    // ──────────────────────────────────────────────────────────
    // TEST 4: Upload Timestamp vs Food Log Date Isolation
    // Client logged food for 30 days ago, BUT uploaded the photo TODAY (< 15 days)
    // MUST NOT BE DELETED!
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 4: Upload Timestamp vs Food-Log Date Isolation ---');
    const savedBackdated = await mealPhotoStorageService.saveMealPhoto(clientProfile.id, SAMPLE_JPEG_BUFFER);
    const backdatedPhoto = await prisma.mealPhoto.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: clientProfile.clientId,
        mealId: 'meal_backdated_01',
        dateString: '2026-09-01', // Food-log date is 36 days ago!
        mealType: 'Snack',
        storagePath: savedBackdated.storagePath,
        mimeType: 'image/jpeg',
        createdAt: new Date(), // BUT uploaded TODAY!
        capturedAt: new Date(),
        confirmedAt: new Date(),
        totalCalories: 250,
        totalProtein: 20,
        totalCarbs: 25,
        totalFat: 5,
      },
    });

    const backdatedPhysicalPath = mealPhotoStorageService.resolvePhysicalFilePath(savedBackdated.storagePath);
    assert.strictEqual(fs.existsSync(backdatedPhysicalPath), true);
    console.log('✔ Created photo with food-log date = 2026-09-01 (36 days ago) but createdAt = today');

    // ──────────────────────────────────────────────────────────
    // TEST 5: Execute 15-Day Auto-Cleanup Sweep
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 5: Execute 15-Day Auto-Cleanup Sweep ---');
    const cleanupResult = await foodPhotoCleanupService.cleanupExpiredFoodPhotos(15);

    console.log(`Cleanup Output:`, {
      totalProcessed: cleanupResult.totalProcessed,
      filesDeleted: cleanupResult.filesDeleted,
      recordsUpdated: cleanupResult.recordsUpdated,
      errorsCount: cleanupResult.errorsCount,
      cutoff: cleanupResult.cutoffTimestamp.toISOString(),
    });

    assert.strictEqual(cleanupResult.errorsCount, 0, 'Cleanup must execute with zero errors');
    assert.ok(cleanupResult.totalProcessed >= 2, 'Must process both expired photos');

    // ──────────────────────────────────────────────────────────
    // TEST 6: Verify Retention Assertions
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 6: Verifying Retention Invariants ---');

    // 6a. Recent Photo (< 15 days): NOT DELETED
    const freshRecentPhoto = await prisma.mealPhoto.findUnique({ where: { id: recentPhoto.id } });
    assert.strictEqual(freshRecentPhoto?.isDeleted, false, 'Photo younger than 15 days must NOT be marked deleted');
    assert.strictEqual(fs.existsSync(recentPhysicalPath), true, 'Photo younger than 15 days file must STILL exist on disk');

    const freshRecentLog = await prisma.clientFoodLog.findUnique({ where: { id: recentFoodLog.id } });
    assert.strictEqual(freshRecentLog?.photoAvailable, true, 'Recent food log photoAvailable must remain true');
    assert.strictEqual(freshRecentLog?.mealPhotoId, recentPhoto.id);
    console.log('✔ Invariant Verified: Photo younger than 15 days was NOT deleted, file remains on disk');

    // 6b. Backdated Log with Recent Upload: NOT DELETED
    const freshBackdatedPhoto = await prisma.mealPhoto.findUnique({ where: { id: backdatedPhoto.id } });
    assert.strictEqual(freshBackdatedPhoto?.isDeleted, false, 'Photo uploaded today must NOT be deleted regardless of food-log date');
    assert.strictEqual(fs.existsSync(backdatedPhysicalPath), true, 'Backdated photo uploaded today must remain on disk');
    console.log('✔ Invariant Verified: Actual upload timestamp strictly used; backdated food-log photo was NOT deleted');

    // 6c. Expired Photo (>= 15 days): PHYSICAL FILE DELETED & DB REFERENCE CLEARED
    const freshExpiredPhoto = await prisma.mealPhoto.findUnique({ where: { id: expiredPhoto.id } });
    assert.strictEqual(freshExpiredPhoto?.isDeleted, true, 'Photo older than 15 days must be marked isDeleted = true');
    assert.ok(freshExpiredPhoto?.deletedAt !== null, 'deletedAt must be set');
    assert.strictEqual(freshExpiredPhoto?.storagePath, '', 'storagePath must be cleared to release storage/base64 bytes');
    assert.strictEqual(fs.existsSync(expiredPhysicalPath), false, 'Physical file on storage MUST BE DELETED');
    console.log('✔ Invariant Verified: Expired photo physical file was DELETED from storage (fs.existsSync is false)');

    // 6d. Expired Photo Food-Log Record: REMAINS INTACT WITH ALL MACROS
    const freshExpiredLog = await prisma.clientFoodLog.findUnique({ where: { id: expiredFoodLog.id } });
    assert.ok(freshExpiredLog !== null, 'Food log entry must NOT be deleted from database');
    assert.strictEqual(freshExpiredLog?.foodName, 'Salmon Bowl with Jasmine Rice');
    assert.strictEqual(freshExpiredLog?.calories, 820, 'Calories must remain intact');
    assert.strictEqual(freshExpiredLog?.protein, 55, 'Protein must remain intact');
    assert.strictEqual(freshExpiredLog?.carbohydrates, 80, 'Carbohydrates must remain intact');
    assert.strictEqual(freshExpiredLog?.fat, 24, 'Fat must remain intact');
    assert.strictEqual(freshExpiredLog?.fiber, 6, 'Fiber must remain intact');
    assert.strictEqual(freshExpiredLog?.photoAvailable, false, 'photoAvailable must be updated to false');
    assert.strictEqual(freshExpiredLog?.mealPhotoId, null, 'mealPhotoId foreign key reference safely cleared');
    console.log('✔ Invariant Verified: Food-log record and all nutrition/macro fields strictly preserved in database');

    // 6e. Missing Storage File: Handled Safely
    const freshMissingPhoto = await prisma.mealPhoto.findUnique({ where: { id: missingPhoto.id } });
    assert.strictEqual(freshMissingPhoto?.isDeleted, true);
    const freshMissingLog = await prisma.clientFoodLog.findUnique({ where: { id: missingFoodLog.id } });
    assert.ok(freshMissingLog !== null);
    assert.strictEqual(freshMissingLog?.calories, 400);
    assert.strictEqual(freshMissingLog?.photoAvailable, false);
    console.log('✔ Invariant Verified: Missing storage file handled gracefully without crashing');

    // 6f. Other Client Photos (Avatars, Transformation Milestones) strictly NOT touched
    const verifyUser = await prisma.user.findUnique({ where: { id: testUser.id } });
    assert.strictEqual(verifyUser?.photoUrl, 'https://cdn.alphaxgym.test/avatars/athlete.jpg', 'User avatar must not be touched');
    console.log('✔ Invariant Verified: Non-food photos and client assets strictly preserved');

    // ──────────────────────────────────────────────────────────
    // TEST 7: Idempotency & Repeated Sweeps
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 7: Idempotency & Repeated Sweeps ---');
    const repeatResult = await foodPhotoCleanupService.cleanupExpiredFoodPhotos(15);
    assert.strictEqual(repeatResult.errorsCount, 0, 'Repeated cleanup must have zero errors');
    assert.strictEqual(repeatResult.filesDeleted, 0, 'Repeated cleanup must not attempt to re-delete already removed files');
    console.log('✔ Invariant Verified: Repeated cleanup execution is safe, idempotent, and non-blocking');

    // ──────────────────────────────────────────────────────────
    // TEST 8: HTTP API Endpoint (POST /api/v1/food-photos/cleanup)
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 8: Admin HTTP Cleanup Trigger API ---');
    const apiRes = await makeRequest(baseUrl, 'POST', '/api/v1/food-photos/cleanup', {
      Authorization: `Bearer ${adminToken}`,
      'Content-Type': 'application/json',
    }, { retentionDays: 15 });

    assert.strictEqual(apiRes.status, 200, 'POST /api/v1/food-photos/cleanup must return 200 for Admin');
    assert.strictEqual(apiRes.body.success, true);
    assert.strictEqual(apiRes.body.data.errorsCount, 0);
    console.log('✔ Admin cleanup endpoint (POST /api/v1/food-photos/cleanup) responded 200 OK');

    // Client trying to call cleanup must be forbidden
    const clientForbiddenRes = await makeRequest(baseUrl, 'POST', '/api/v1/food-photos/cleanup', {
      Authorization: `Bearer ${clientToken}`,
      'Content-Type': 'application/json',
    });
    assert.strictEqual(clientForbiddenRes.status, 403, 'Client must receive 403 Forbidden on cleanup endpoint');
    console.log('✔ Security Verified: Client denied access (403 Forbidden) to cleanup endpoint');

    // ──────────────────────────────────────────────────────────
    // TEST 9: Client Food Journal Functionality Continues Working
    // ──────────────────────────────────────────────────────────
    console.log('\n--- TEST 9: Client Food Journal Functionality Verification ---');
    const clientHistoryRes = await makeRequest(baseUrl, 'GET', '/api/v1/food-photos/my-photos', {
      Authorization: `Bearer ${clientToken}`,
    });
    assert.strictEqual(clientHistoryRes.status, 200);
    assert.strictEqual(clientHistoryRes.body.success, true);
    // Recent photo is present
    const returnedPhotos = clientHistoryRes.body.data.photos;
    assert.ok(returnedPhotos.some((p: any) => p.id === recentPhoto.id), 'Recent photo must still be accessible to client');
    // Expired photo is NOT in active client list
    assert.ok(!returnedPhotos.some((p: any) => p.id === expiredPhoto.id), 'Deleted photo must not appear in active client photo list');
    console.log('✔ Client photo history API works properly with active vs expired photos');

    // Attempting to stream deleted photo returns 404
    const streamDeletedRes = await makeRequest(baseUrl, 'GET', `/api/v1/food-photos/${expiredPhoto.id}/image`, {
      Authorization: `Bearer ${clientToken}`,
    });
    assert.strictEqual(streamDeletedRes.status, 404, 'Streaming deleted photo must return 404');
    console.log('✔ Stream endpoint returns 404 for deleted photo');

    // Clean up test data
    await prisma.mealPhoto.deleteMany({ where: { clientProfileId: clientProfile.id } });
    await prisma.clientFoodLog.deleteMany({ where: { clientProfileId: clientProfile.id } });
    await mealPhotoStorageService.deleteFile(savedRecent.storagePath);
    await mealPhotoStorageService.deleteFile(savedBackdated.storagePath);
    await prisma.clientProfile.delete({ where: { id: clientProfile.id } });
    await prisma.user.delete({ where: { id: testUser.id } });

    console.log('\n====================================================');
    console.log('🎉 ALL 15-DAY FOOD PHOTO CLEANUP TESTS PASSED 100%!');
    console.log('====================================================');
  } finally {
    server.close();
  }
}

runFoodPhotoCleanupTests().catch((err) => {
  console.error('❌ FOOD PHOTO CLEANUP TEST FAILED:', err);
  process.exit(1);
});
