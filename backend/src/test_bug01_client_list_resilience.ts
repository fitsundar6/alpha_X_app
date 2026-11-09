/**
 * BUG-01 Regression Test Suite: Workout Service & Controller Client List Resilience
 *
 * Verifies that:
 * 1. When the database succeeds and has clients, getClientsList returns the mapped clients and HTTP 200.
 * 2. When the database succeeds and has ZERO clients, getClientsList legitimately returns [] and HTTP 200.
 * 3. When the database query fails (connection drop, auth error, timeout), getClientsList throws
 *    and the controller responds with HTTP 500 (DATABASE_ERROR), NEVER silently returning [] or HTTP 200.
 *
 * Runs completely in-memory via Prisma mock fixtures without connecting to any live database.
 */

import { prisma } from './config/prisma';
import { workoutService } from './modules/workout/workout.service';
import { workoutController } from './modules/workout/workout.controller';
import { HttpStatus } from './constants/httpStatus';

interface MockResponse {
  statusCode: number;
  body: any;
  status(code: number): MockResponse;
  json(payload: any): MockResponse;
}

function createMockRes(): MockResponse {
  const res: MockResponse = {
    statusCode: 200,
    body: null,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(payload: any) {
      this.body = payload;
      return this;
    },
  };
  return res;
}

const mockClients = [
  {
    id: 'user_client_1',
    name: 'Athlete One',
    email: 'athlete1@example.com',
    role: 'CLIENT',
    photoUrl: 'https://example.com/p1.jpg',
    googleUid: null,
    createdAt: new Date('2026-01-01T10:00:00Z'),
    clientProfile: {
      id: 'cp_1',
      clientId: 'AXG-1001',
      googleUid: null,
      photoUrl: null,
      phone: '+919876543210',
      adminNotes: 'Consistent runner',
      dailyStepGoal: 8000,
      fitnessLevel: 'intermediate',
      primaryGoal: 'Muscle Gain',
      secondaryGoal: 'Endurance',
      weightKg: 75.5,
      heightCm: 180,
      age: 28,
      gender: 'Male',
      trainingExperience: '2 years',
      trainingDaysPerWeek: 4,
      hasCurrentInjury: false,
      injuryAreas: [],
      injuryDescription: null,
      hasPreviousSurgery: false,
      surgeryDetails: null,
      activityLevel: 'ACTIVE',
      sleepHours: '8 hours',
      dailySteps: 8000,
      trainingTimePref: 'Morning',
      preferredDays: ['Monday', 'Wednesday', 'Friday'],
      trainingPreferences: ['Hypertrophy'],
      onboardingCompleted: true,
      onboardingStep: 5,
    },
  },
  {
    id: 'user_client_2',
    name: 'Athlete Two',
    email: 'athlete2@example.com',
    role: 'CLIENT',
    photoUrl: null,
    googleUid: null,
    createdAt: new Date('2026-02-01T10:00:00Z'),
    clientProfile: null,
  },
];

async function runTests() {
  console.log('================================================================');
  console.log('🔒 BUG-01 REGRESSION TEST SUITE: CLIENT LIST DB ERROR RESILIENCE 🔒');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${testName}${detail ? ` (${detail})` : ''}`);
      failed++;
    }
  }

  // Preserve original findMany implementation
  const originalFindMany = prisma.user.findMany;

  try {
    // ── TEST 1: Database Query Succeeds with Clients ──────────────────────────
    console.log('[TEST 1] Database query succeeds with client records:');
    (prisma.user as any).findMany = async () => mockClients;

    const serviceResult1 = await workoutService.getClientsList();
    assert(Array.isArray(serviceResult1) && serviceResult1.length === 2, 'Service returns 2 mapped clients');
    assert(serviceResult1[0].id === 'user_client_1' && serviceResult1[0].clientId === 'AXG-1001', 'Service correctly maps clientProfile and displayClientId');
    assert(serviceResult1[1].id === 'user_client_2' && serviceResult1[1].clientId === 'user_client_2', 'Service falls back to user.id when clientProfile is null');

    const mockReq1 = {} as any;
    const mockRes1 = createMockRes();
    await workoutController.getClientsList(mockReq1, mockRes1 as any);
    assert(mockRes1.statusCode === HttpStatus.OK, 'Controller responds with HTTP 200 OK');
    assert(mockRes1.body?.success === true, 'Controller response envelope has success: true');
    assert(Array.isArray(mockRes1.body?.data) && mockRes1.body?.data.length === 2, 'Controller sends 2 clients in payload');
    assert(mockRes1.body?.meta?.version === '1.0.0', 'Controller metadata reports valid envelope version');

    // ── TEST 2: Database Query Succeeds with ZERO Clients (Legitimate Empty List) ─
    console.log('\n[TEST 2] Database query succeeds with 0 clients (genuine empty gym):');
    (prisma.user as any).findMany = async () => [];

    const serviceResult2 = await workoutService.getClientsList();
    assert(Array.isArray(serviceResult2) && serviceResult2.length === 0, 'Service returns empty array [] on genuine empty list');

    const mockReq2 = {} as any;
    const mockRes2 = createMockRes();
    await workoutController.getClientsList(mockReq2, mockRes2 as any);
    assert(mockRes2.statusCode === HttpStatus.OK, 'Controller responds with HTTP 200 OK on genuine empty list');
    assert(mockRes2.body?.success === true, 'Controller envelope has success: true');
    assert(Array.isArray(mockRes2.body?.data) && mockRes2.body?.data.length === 0, 'Controller payload contains empty array data: []');
    assert(mockRes2.body?.meta?.version === '1.0.0', 'Controller metadata reports valid envelope version');

    // ── TEST 3: Database Query Fails (Authentication / Connection Error) ──────
    console.log('\n[TEST 3] Database query throws connection/authentication failure:');
    const simulatedDbError = new Error('connection failed: ERROR: password authentication failed for user "neondb_owner"');
    (prisma.user as any).findMany = async () => {
      throw simulatedDbError;
    };

    // 3A: Service layer MUST throw and MUST NOT return []
    let serviceThrew = false;
    let serviceOutput: any = null;
    try {
      serviceOutput = await workoutService.getClientsList();
    } catch (err: any) {
      serviceThrew = true;
      assert(err === simulatedDbError, 'Service re-throws exact database error without swallowing');
    }
    assert(serviceThrew, 'workoutService.getClientsList() re-throws on database failure');
    assert(serviceOutput === null, 'workoutService.getClientsList() does NOT return [] when database query fails');

    // 3B: Controller layer MUST NOT respond with HTTP 200 and MUST NOT send data: []
    const mockReq3 = {} as any;
    const mockRes3 = createMockRes();
    await workoutController.getClientsList(mockReq3, mockRes3 as any);

    assert(mockRes3.statusCode !== HttpStatus.OK, 'Controller does NOT return HTTP 200 on database failure');
    assert(mockRes3.statusCode === HttpStatus.INTERNAL_SERVER_ERROR, 'Controller returns HTTP 500 INTERNAL_SERVER_ERROR');
    assert(mockRes3.body?.success === false, 'Controller response envelope has success: false');
    assert(mockRes3.body?.data === null, 'Controller response data is null (NEVER empty array [])');
    assert(mockRes3.body?.error?.code === 'DATABASE_ERROR', 'Controller error code is DATABASE_ERROR');
    assert(mockRes3.body?.error?.message === 'Failed to retrieve clients list from database', 'Controller returns clear error message');

  } finally {
    // Restore original method
    (prisma.user as any).findMany = originalFindMany;
  }

  console.log('\n================================================================');
  console.log(`SUMMARY: ${passed} PASSED, ${failed} FAILED out of ${passed + failed}`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});

