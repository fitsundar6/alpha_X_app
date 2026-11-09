import express from 'express';
import jwt from 'jsonwebtoken';
import http from 'http';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { foodPhotoRoutes } from './modules/food/food.photo.routes';
import { transformationPhotoRoutes } from './modules/automation/transformation_photo.routes';
import { mealPhotoStorageService } from './modules/food/meal_photo_storage.service';
import { transformationPhotoStorageService } from './modules/automation/transformation_photo_storage.service';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { UserRole } from './constants/roles';

async function runMediaSecurityTestSuite() {
  console.log('================================================================');
  console.log('TEST SUITE: F-03 MEDIA ROUTES AUTHENTICATION & OWNERSHIP');
  console.log('================================================================');

  let passedTests = 0;
  let totalTests = 0;

  function assertTest(name: string, condition: boolean, details?: string) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  [PASS] Test ${totalTests}: ${name}`);
    } else {
      console.error(`  [FAIL] Test ${totalTests}: ${name}`);
      if (details) console.error(`         Details: ${details}`);
      throw new Error(`Test failed: ${name}`);
    }
  }

  // Setup express test server mounting real media routes
  const app = express();
  app.use(express.json());
  app.use('/api/v1/food-photos', foodPhotoRoutes);
  app.use('/api/v1/transformation-photos', transformationPhotoRoutes);

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}/api/v1`;

  // Preserve original prisma and storage methods
  const origUserFindUnique = prisma.user.findUnique;
  const origMealFindUnique = prisma.mealPhoto.findUnique;
  const origTransFindUnique = prisma.transformationMilestone.findUnique;
  const origClientFind = prisma.clientProfile.findFirst;
  const origUserFind = prisma.user.findFirst;
  const origFileExists = mealPhotoStorageService.fileExists;
  const origGetStream = mealPhotoStorageService.getFileStream;
  const origExtractBuffer = transformationPhotoStorageService.extractBuffer;
  const origIsRevoked = adminAuthService.isRevoked;

  try {
    adminAuthService.isRevoked = async () => false;
    // Test Entities
    const clientA = {
      userId: 'user-client-a-uuid',
      profileId: 'profile-client-a-uuid',
      email: 'client.a@alphaxgym.com',
      role: UserRole.CLIENT,
    };

    const clientB = {
      userId: 'user-client-b-uuid',
      profileId: 'profile-client-b-uuid',
      email: 'client.b@alphaxgym.com',
      role: UserRole.CLIENT,
    };

    const admin = {
      userId: 'user-admin-uuid',
      email: env.ADMIN_EMAIL.trim().toLowerCase(),
      role: UserRole.ADMIN,
    };

    // Valid JWTs
    const tokenA = jwt.sign(
      { id: clientA.userId, email: clientA.email, role: clientA.role, clientId: 'AXG-0001' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const tokenB = jwt.sign(
      { id: clientB.userId, email: clientB.email, role: clientB.role, clientId: 'AXG-0002' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const tokenAdmin = jwt.sign(
      { id: admin.userId, email: admin.email, role: admin.role },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const expiredToken = jwt.sign(
      { id: clientA.userId, email: clientA.email, role: clientA.role },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '-10s' }
    );

    const sampleImageBuffer = Buffer.from('fake-jpeg-binary-data-for-tests');

    // Mock Meal Photos
    const mealPhotoA = {
      id: 'meal-photo-a-id',
      clientProfileId: clientA.profileId,
      clientId: 'AXG-0001',
      storagePath: 'dummy/path/a.jpg',
      mimeType: 'image/jpeg',
      fileSizeBytes: sampleImageBuffer.length,
      isDeleted: false,
      clientProfile: {
        id: clientA.profileId,
        userId: clientA.userId,
      },
    };

    const mealPhotoB = {
      id: 'meal-photo-b-id',
      clientProfileId: clientB.profileId,
      clientId: 'AXG-0002',
      storagePath: 'dummy/path/b.jpg',
      mimeType: 'image/jpeg',
      fileSizeBytes: sampleImageBuffer.length,
      isDeleted: false,
      clientProfile: {
        id: clientB.profileId,
        userId: clientB.userId,
      },
    };

    const mealPhotoOrphan = {
      id: 'meal-photo-orphan-id',
      clientProfileId: 'missing-profile',
      clientId: 'AXG-9999',
      storagePath: 'dummy/path/orphan.jpg',
      mimeType: 'image/jpeg',
      fileSizeBytes: sampleImageBuffer.length,
      isDeleted: false,
      clientProfile: null,
    };

    // Mock Transformation Milestones
    const milestoneA = {
      id: 'milestone-a-id',
      clientProfileId: clientA.profileId,
      clientId: 'AXG-0001',
      weekNumber: 1,
      frontPhotoUrl: 'dummy/path/front_a.jpg',
      sidePhotoUrl: null,
      backPhotoUrl: null,
      clientProfile: {
        id: clientA.profileId,
        userId: clientA.userId,
      },
    };

    const milestoneB = {
      id: 'milestone-b-id',
      clientProfileId: clientB.profileId,
      clientId: 'AXG-0002',
      weekNumber: 2,
      frontPhotoUrl: 'dummy/path/front_b.jpg',
      sidePhotoUrl: null,
      backPhotoUrl: null,
      clientProfile: {
        id: clientB.profileId,
        userId: clientB.userId,
      },
    };

    // Attach Mocks
    (prisma.user.findUnique as any) = async (args: any) => {
      const id = args?.where?.id;
      if (id === clientA.userId) {
        return {
          id: clientA.userId,
          email: clientA.email,
          role: clientA.role,
          mustChangePassword: false,
          tokenVersion: 0,
        };
      }
      if (id === clientB.userId) {
        return {
          id: clientB.userId,
          email: clientB.email,
          role: clientB.role,
          mustChangePassword: false,
          tokenVersion: 0,
        };
      }
      if (id === admin.userId) {
        return {
          id: admin.userId,
          email: admin.email,
          role: admin.role,
          mustChangePassword: false,
          tokenVersion: 0,
        };
      }
      return null;
    };

    (prisma.mealPhoto.findUnique as any) = async (args: any) => {
      const id = args?.where?.id;
      if (id === mealPhotoA.id) return mealPhotoA;
      if (id === mealPhotoB.id) return mealPhotoB;
      if (id === mealPhotoOrphan.id) return mealPhotoOrphan;
      return null;
    };

    (prisma.transformationMilestone.findUnique as any) = async (args: any) => {
      const id = args?.where?.id;
      if (id === milestoneA.id) return milestoneA;
      if (id === milestoneB.id) return milestoneB;
      return null;
    };

    (prisma.clientProfile.findFirst as any) = async (args: any) => {
      const orClauses = args?.where?.OR || [];
      for (const clause of orClauses) {
        if (clause.userId === clientA.userId || clause.id === clientA.userId || clause.id === clientA.profileId) {
          return { id: clientA.profileId, userId: clientA.userId, clientId: 'AXG-0001' };
        }
        if (clause.userId === clientB.userId || clause.id === clientB.userId || clause.id === clientB.profileId) {
          return { id: clientB.profileId, userId: clientB.userId, clientId: 'AXG-0002' };
        }
      }
      return null;
    };

    (mealPhotoStorageService.fileExists as any) = () => true;
    (mealPhotoStorageService.getFileStream as any) = () => {
      const { Readable } = require('stream');
      return Readable.from([sampleImageBuffer]);
    };

    (transformationPhotoStorageService.extractBuffer as any) = () => ({
      buffer: sampleImageBuffer,
      mimeType: 'image/jpeg',
    });

    // Helper request function
    async function request(path: string, options: { headers?: Record<string, string>; query?: string } = {}) {
      const url = `${baseUrl}${path}${options.query ? `?${options.query}` : ''}`;
      return new Promise<{ status: number; headers: http.IncomingHttpHeaders; body: any }>((resolve, reject) => {
        const parsed = new URL(url);
        const req = http.request(
          {
            hostname: parsed.hostname,
            port: parsed.port,
            path: parsed.pathname + parsed.search,
            method: 'GET',
            headers: options.headers || {},
            timeout: 5000,
          },
          (res) => {
            let data = '';
            res.on('data', (chunk) => (data += chunk));
            res.on('end', () => {
              let parsedBody = data;
              try {
                parsedBody = JSON.parse(data);
              } catch (_) {}
              resolve({ status: res.statusCode || 0, headers: res.headers, body: parsedBody });
            });
          }
        );
        req.on('timeout', () => {
          req.destroy(new Error('Request timed out after 5000ms'));
        });
        req.on('error', reject);
        req.end();
      });
    }

    // -------------------------------------------------------------
    // Test 1: Unauthenticated food photo request -> 401
    // -------------------------------------------------------------
    const res1 = await request(`/food-photos/${mealPhotoA.id}/image`);
    assertTest('Unauthenticated food photo image returns HTTP 401', res1.status === 401);

    // -------------------------------------------------------------
    // Test 2: Unauthenticated transformation photo request -> 401
    // -------------------------------------------------------------
    const res2 = await request(`/transformation-photos/${milestoneA.id}/front`);
    assertTest('Unauthenticated transformation photo returns HTTP 401', res2.status === 401);

    // -------------------------------------------------------------
    // Test 3: Query-string token alone on food photo -> rejected (401)
    // -------------------------------------------------------------
    const res3 = await request(`/food-photos/${mealPhotoA.id}/image`, { query: `token=${tokenA}` });
    assertTest('Query-string ?token= alone on food-photos is rejected with HTTP 401', res3.status === 401);

    // -------------------------------------------------------------
    // Test 4: Query-string token alone on transformation photo -> rejected (401)
    // -------------------------------------------------------------
    const res4 = await request(`/transformation-photos/${milestoneA.id}/front`, { query: `token=${tokenA}` });
    assertTest('Query-string ?token= alone on transformation-photos is rejected with HTTP 401', res4.status === 401);

    // -------------------------------------------------------------
    // Test 5: Expired Bearer token on food photo -> 401
    // -------------------------------------------------------------
    const res5 = await request(`/food-photos/${mealPhotoA.id}/image`, {
      headers: { Authorization: `Bearer ${expiredToken}` },
    });
    assertTest('Expired Bearer token on food-photos returns HTTP 401', res5.status === 401);

    // -------------------------------------------------------------
    // Test 6: Expired Bearer token on transformation photo -> 401
    // -------------------------------------------------------------
    const res6 = await request(`/transformation-photos/${milestoneA.id}/front`, {
      headers: { Authorization: `Bearer ${expiredToken}` },
    });
    assertTest('Expired Bearer token on transformation-photos returns HTTP 401', res6.status === 401);

    // -------------------------------------------------------------
    // Test 7: Valid Bearer token from photo owner (Client A -> Photo A) -> 200
    // -------------------------------------------------------------
    const res7 = await request(`/food-photos/${mealPhotoA.id}/image`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    assertTest('Valid Bearer token by owner client streams food photo (HTTP 200)', res7.status === 200);

    // -------------------------------------------------------------
    // Test 8: Cross-client access (Client A -> Photo B) -> 403 Forbidden
    // -------------------------------------------------------------
    const res8 = await request(`/food-photos/${mealPhotoB.id}/image`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    assertTest('Cross-client food photo access is denied with HTTP 403 Forbidden', res8.status === 403);

    // -------------------------------------------------------------
    // Test 9: Master Admin accesses Client B's food photo -> 200 OK
    // -------------------------------------------------------------
    const res9 = await request(`/food-photos/${mealPhotoB.id}/image`, {
      headers: { Authorization: `Bearer ${tokenAdmin}` },
    });
    assertTest('Master Admin access to any client food photo returns HTTP 200 OK', res9.status === 200);

    // -------------------------------------------------------------
    // Test 10: Valid Bearer token by owner (Client A -> Milestone A) -> 200
    // -------------------------------------------------------------
    const res10 = await request(`/transformation-photos/${milestoneA.id}/front`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    assertTest('Valid Bearer token by owner client streams transformation photo (HTTP 200)', res10.status === 200);

    // -------------------------------------------------------------
    // Test 11: Cross-client access (Client A -> Milestone B) -> 403 Forbidden
    // -------------------------------------------------------------
    const res11 = await request(`/transformation-photos/${milestoneB.id}/front`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    assertTest('Cross-client transformation photo access is denied with HTTP 403 Forbidden', res11.status === 403);

    // -------------------------------------------------------------
    // Test 12: Master Admin accesses Client B's transformation photo -> 200 OK
    // -------------------------------------------------------------
    const res12 = await request(`/transformation-photos/${milestoneB.id}/front`, {
      headers: { Authorization: `Bearer ${tokenAdmin}` },
    });
    assertTest('Master Admin access to any client transformation photo returns HTTP 200 OK', res12.status === 200);

    // -------------------------------------------------------------
    // Test 13: Nullable clientProfile record safely returns 403 without 500 crash
    // -------------------------------------------------------------
    const res13 = await request(`/food-photos/${mealPhotoOrphan.id}/image`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    assertTest('Orphaned/null clientProfile record returns HTTP 403 safely without crash', res13.status === 403);

    // -------------------------------------------------------------
    // Test 14: Food photo response headers enforce private, no-store and no-referrer
    // -------------------------------------------------------------
    assertTest(
      'Food photo response includes Cache-Control: private, no-store',
      res7.headers['cache-control'] === 'private, no-store',
      `Actual: ${res7.headers['cache-control']}`
    );
    assertTest(
      'Food photo response includes Referrer-Policy: no-referrer',
      res7.headers['referrer-policy'] === 'no-referrer',
      `Actual: ${res7.headers['referrer-policy']}`
    );

    // -------------------------------------------------------------
    // Test 15: Transformation photo response headers enforce private, no-store and no-referrer
    // -------------------------------------------------------------
    assertTest(
      'Transformation photo response includes Cache-Control: private, no-store',
      res10.headers['cache-control'] === 'private, no-store',
      `Actual: ${res10.headers['cache-control']}`
    );
    assertTest(
      'Transformation photo response includes Referrer-Policy: no-referrer',
      res10.headers['referrer-policy'] === 'no-referrer',
      `Actual: ${res10.headers['referrer-policy']}`
    );

    // -------------------------------------------------------------
    // Test 16: Admin media responses enforce private, no-store and no-referrer
    // -------------------------------------------------------------
    assertTest(
      'Admin media access includes Cache-Control: private, no-store',
      res9.headers['cache-control'] === 'private, no-store',
      `Actual: ${res9.headers['cache-control']}`
    );
    assertTest(
      'Admin media access includes Referrer-Policy: no-referrer',
      res9.headers['referrer-policy'] === 'no-referrer',
      `Actual: ${res9.headers['referrer-policy']}`
    );

    console.log('================================================================');
    console.log(`ALL TESTS PASSED: ${passedTests}/${totalTests}`);
    console.log('================================================================');
  } finally {
    // Restore prisma and storage
    prisma.user.findUnique = origUserFindUnique;
    prisma.mealPhoto.findUnique = origMealFindUnique;
    prisma.transformationMilestone.findUnique = origTransFindUnique;
    prisma.clientProfile.findFirst = origClientFind;
    prisma.user.findFirst = origUserFind;
    mealPhotoStorageService.fileExists = origFileExists;
    mealPhotoStorageService.getFileStream = origGetStream;
    transformationPhotoStorageService.extractBuffer = origExtractBuffer;
    adminAuthService.isRevoked = origIsRevoked;
    server.close();
  }
}

runMediaSecurityTestSuite()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test suite failed:', err);
    process.exit(1);
  });
