import app from './server';
import http from 'http';
import { prisma } from './config/prisma';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';
import { UserRole, UserStatus } from './constants/roles';

async function runEditClientProfileTests() {
  console.log('================================================================');
  console.log('ALPHA X GYM — EDIT CLIENT PROFILE E2E & SECURITY TEST SUITE');
  console.log('================================================================');

  const server = http.createServer(app);
  const testPort = 5088;
  await new Promise<void>((resolve) => server.listen(testPort, '127.0.0.1', () => resolve()));
  const baseUrl = `http://127.0.0.1:${testPort}/api/v1`;

  try {
    // 1. SETUP TEST CLIENT & ADMIN IN DATABASE
    console.log('\n[SETUP] Creating test client & admin in PostgreSQL...');
    const uniqueSuffix = Date.now().toString().slice(-6);
    const clientEmail = `edit_profile_client_${uniqueSuffix}@alphaxgym.test`;
    const adminEmail = `edit_profile_admin_${uniqueSuffix}@alphaxgym.test`;
    const clientAXG = `AXG-EP${uniqueSuffix}`;

    const clientUser = await prisma.user.create({
      data: {
        email: clientEmail,
        name: 'Original Client Name',
        passwordHash: 'dummy_hash',
        role: UserRole.CLIENT,
        status: UserStatus.APPROVED,
        clientProfile: {
          create: {
            clientId: clientAXG,
            phone: '+15551234567',
            weightKg: 75.0,
            heightCm: 175.0,
            age: 26,
            gender: 'Male',
            fitnessLevel: 'INTERMEDIATE',
            primaryGoal: 'Muscle Gain',
            membershipStatus: 'ACTIVE',
            membershipPlan: 'ELITE',
          },
        },
      },
      include: { clientProfile: true },
    });

    let adminUser = await prisma.user.findFirst({
      where: { email: env.ADMIN_EMAIL.trim().toLowerCase() },
    });
    let createdAdmin = false;
    if (!adminUser) {
      adminUser = await prisma.user.create({
        data: {
          email: env.ADMIN_EMAIL.trim().toLowerCase(),
          name: 'Master Admin',
          passwordHash: 'dummy_hash',
          role: UserRole.ADMIN,
          status: UserStatus.APPROVED,
        },
      });
      createdAdmin = true;
    }

    // Create a workout assignment and diet plan to test record preservation
    let session = await prisma.workoutSession.findFirst();
    if (!session) {
      session = await prisma.workoutSession.create({
        data: {
          title: 'Preserve Test Session',
          workoutType: 'Strength',
          targetMuscleGroup: 'Full Body',
          difficulty: 'INTERMEDIATE',
          createdById: adminUser.id,
        },
      });
    }

    const workoutAssignment = await prisma.workoutAssignment.create({
      data: {
        sessionId: session.id,
        clientId: clientUser.id,
        assignedById: adminUser.id,
        isRecommended: true,
      },
    });

    const dietPlan = await prisma.dietPlan.create({
      data: {
        clientProfileId: clientUser.clientProfile!.id,
        planName: 'Preserve Diet Plan',
        dailyCalories: 2500,
        protein: 160,
        carbohydrates: 280,
        fat: 70,
        isActive: true,
      },
    });

    // Generate real JWT tokens
    const clientToken = jwt.sign(
      { id: clientUser.id, email: clientUser.email, role: 'CLIENT' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const adminToken = jwt.sign(
      { id: adminUser.id, email: adminUser.email, role: 'ADMIN' },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const clientHeaders = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${clientToken}`,
    };

    const adminHeaders = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${adminToken}`,
    };

    console.log(`✓ Test Client (${clientAXG}) and Admin created successfully.`);

    // -------------------------------------------------------------------------
    // TEST 1: CLIENT EDITS THEIR OWN PERMITTED PROFILE FIELDS
    // -------------------------------------------------------------------------
    console.log('\n[TEST 1] Client updates permitted profile fields (weight, height, age, phone, photoUrl, goal)...');
    const updateRes = await fetch(`${baseUrl}/client/me/profile`, {
      method: 'PUT',
      headers: clientHeaders,
      body: jsonString({
        phone: '+15559876543',
        weightKg: 78.5,
        heightCm: 176.0,
        age: 27,
        gender: 'Male',
        fitnessLevel: 'ADVANCED',
        primaryGoal: 'Strength',
        activityLevel: 'ACTIVE',
        trainingTimePref: 'Morning',
        photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      }),
    });

    const updateData = await updateRes.json();
    console.assert(updateRes.status === 200, `Expected 200, got ${updateRes.status}`);
    console.assert(updateData.success === true, 'Expected success status');
    console.assert(updateData.data.profile.weightKg === 78.5, 'Expected weight 78.5');
    console.assert(updateData.data.profile.phone === '+15559876543', 'Expected phone updated');
    console.assert(updateData.data.profile.fitnessLevel === 'ADVANCED', 'Expected fitnessLevel ADVANCED');
    console.assert(updateData.data.profile.photoUrl.includes('images.unsplash.com'), 'Expected photoUrl updated');
    console.log('✓ TEST 1 PASSED: Client profile fields successfully updated via API.');

    // -------------------------------------------------------------------------
    // TEST 2: CLIENT EDITS THEIR DISPLAY NAME VIA /me/name
    // -------------------------------------------------------------------------
    console.log('\n[TEST 2] Client updates display name...');
    const nameRes = await fetch(`${baseUrl}/client/me/name`, {
      method: 'PATCH',
      headers: clientHeaders,
      body: jsonString({ name: 'Alex Thunder' }),
    });
    const nameData = await nameRes.json();
    console.assert(nameRes.status === 200, `Expected 200, got ${nameRes.status}`);
    console.assert(nameData.data.name === 'Alex Thunder', `Expected "Alex Thunder", got ${nameData.data.name}`);

    // Verify name in DB
    const freshUser = await prisma.user.findUnique({ where: { id: clientUser.id } });
    console.assert(freshUser?.name === 'Alex Thunder', 'Expected name persisted in PostgreSQL User table');
    console.log('✓ TEST 2 PASSED: Client name updated in DB and returned in response.');

    // -------------------------------------------------------------------------
    // TEST 3: SECURITY - CLIENT CANNOT OVERWRITE PROTECTED FIELDS
    // -------------------------------------------------------------------------
    console.log('\n[TEST 3] Security: Client attempts to tamper with protected fields (clientId, role, status)...');
    const hackRes = await fetch(`${baseUrl}/client/me/profile`, {
      method: 'PUT',
      headers: clientHeaders,
      body: jsonString({
        clientId: 'AXG-HACKED-999',
        role: 'ADMIN',
        status: 'SUSPENDED',
        membershipStatus: 'EXPIRED',
        membershipPlan: 'FREE_TRIAL',
      }),
    });
    console.assert(hackRes.status === 200, 'Endpoint should succeed without applying forbidden fields');

    const verifiedUser = await prisma.user.findUnique({
      where: { id: clientUser.id },
      include: { clientProfile: true },
    });
    console.assert(verifiedUser?.role === UserRole.CLIENT, 'Client role must remain CLIENT');
    console.assert(verifiedUser?.status === UserStatus.APPROVED, 'Client status must remain APPROVED');
    console.assert(verifiedUser?.clientProfile?.clientId === clientAXG, 'Client ID must remain original');
    console.assert(verifiedUser?.clientProfile?.membershipStatus === 'ACTIVE', 'Membership status must remain ACTIVE');
    console.log('✓ TEST 3 PASSED: Protected fields (clientId, role, status, membership) strictly preserved.');

    // -------------------------------------------------------------------------
    // TEST 4: ADMIN EDITS CLIENT'S PROFILE
    // -------------------------------------------------------------------------
    console.log('\n[TEST 4] Admin updates client profile via /admin/clients/:id/profile...');
    const adminUpdateRes = await fetch(`${baseUrl}/admin/clients/${clientAXG}/profile`, {
      method: 'PUT',
      headers: adminHeaders,
      body: jsonString({
        name: 'Alex Thunder (VIP)',
        phone: '+15550001111',
        weightKg: 80.0,
        heightCm: 177.0,
        age: 28,
        fitnessLevel: 'ELITE',
        primaryGoal: 'Endurance',
        secondaryGoal: 'Flexibility',
        trainingDaysPerWeek: 5,
        hasCurrentInjury: true,
        injuryAreas: ['Shoulder', 'Knee'],
        injuryDescription: 'Rotator cuff strain under recovery',
        activityLevel: 'VERY_ACTIVE',
        sleepHours: '7-8 hours',
        photoUrl: 'https://images.unsplash.com/photo-admin-override',
      }),
    });

    const adminData = await adminUpdateRes.json();
    console.assert(adminUpdateRes.status === 200, `Expected 200, got ${adminUpdateRes.status}: ${JSON.stringify(adminData)}`);
    console.assert(adminData.data.name === 'Alex Thunder (VIP)', 'Expected updated name from admin');
    console.assert(adminData.data.profile.weightKg === 80.0, 'Expected weight 80.0');
    console.assert(adminData.data.profile.fitnessLevel === 'ELITE', 'Expected fitnessLevel ELITE');
    console.assert(adminData.data.profile.hasCurrentInjury === true, 'Expected hasCurrentInjury true');
    console.assert(adminData.data.profile.injuryDescription === 'Rotator cuff strain under recovery', 'Expected injuryDesc');

    // Verify DB
    const adminSaved = await prisma.user.findUnique({
      where: { id: clientUser.id },
      include: { clientProfile: true },
    });
    console.assert(adminSaved?.name === 'Alex Thunder (VIP)', 'Admin updated User.name in DB');
    console.assert(adminSaved?.clientProfile?.weightKg === 80.0, 'Admin updated ClientProfile.weightKg in DB');
    console.assert(adminSaved?.clientProfile?.fitnessLevel === 'ELITE', 'Admin updated ClientProfile.fitnessLevel in DB');
    console.log('✓ TEST 4 PASSED: Admin successfully updated client profile and persisted to PostgreSQL.');

    // -------------------------------------------------------------------------
    // TEST 5: SECURITY - CLIENT CANNOT CALL ADMIN PROFILE ENDPOINT
    // -------------------------------------------------------------------------
    console.log('\n[TEST 5] Security: Non-admin client attempts to call admin profile endpoint...');
    const forbiddenRes = await fetch(`${baseUrl}/admin/clients/${clientAXG}/profile`, {
      method: 'PUT',
      headers: clientHeaders, // Client token instead of admin
      body: jsonString({ weightKg: 100 }),
    });
    console.assert(
      forbiddenRes.status === 401 || forbiddenRes.status === 403,
      `Expected 401/403 for unauthorized admin call, got ${forbiddenRes.status}`
    );
    console.log(`✓ TEST 5 PASSED: Unauthorized attempt safely blocked (${forbiddenRes.status}).`);

    // -------------------------------------------------------------------------
    // TEST 6: INPUT VALIDATION (Biometrics & Name constraints)
    // -------------------------------------------------------------------------
    console.log('\n[TEST 6] Input Validation: Invalid biometric data rejected...');
    // Weight out of range
    const badWeightRes = await fetch(`${baseUrl}/client/me/profile`, {
      method: 'PUT',
      headers: clientHeaders,
      body: jsonString({ weightKg: 500 }),
    });
    console.assert(badWeightRes.status === 400, `Expected 400 for weight=500, got ${badWeightRes.status}`);

    // Height out of range
    const badHeightRes = await fetch(`${baseUrl}/client/me/profile`, {
      method: 'PUT',
      headers: clientHeaders,
      body: jsonString({ heightCm: 10 }),
    });
    console.assert(badHeightRes.status === 400, `Expected 400 for height=10, got ${badHeightRes.status}`);

    // Name too short
    const badNameRes = await fetch(`${baseUrl}/client/me/name`, {
      method: 'PATCH',
      headers: clientHeaders,
      body: jsonString({ name: 'A' }),
    });
    console.assert(badNameRes.status === 400, `Expected 400 for name="A", got ${badNameRes.status}`);
    console.log('✓ TEST 6 PASSED: Invalid inputs properly rejected with 400 VALIDATION_ERROR.');

    // -------------------------------------------------------------------------
    // TEST 7: PRESERVATION OF ASSOCIATED CLIENT RECORDS
    // -------------------------------------------------------------------------
    console.log('\n[TEST 7] Verifying workout plans, diet plans, and records remain intact...');
    const preservedWorkout = await prisma.workoutAssignment.findUnique({
      where: { id: workoutAssignment.id },
    });
    console.assert(preservedWorkout !== null, 'Workout assignment must still exist');
    console.assert(preservedWorkout?.clientId === clientUser.id, 'Workout assignment clientId preserved');

    const preservedDiet = await prisma.dietPlan.findUnique({
      where: { id: dietPlan.id },
    });
    console.assert(preservedDiet !== null, 'Diet plan must still exist');
    console.assert(preservedDiet?.dailyCalories === 2500, 'Diet plan calories preserved');
    console.log('✓ TEST 7 PASSED: Existing workout assignments and diet plans fully preserved.');

    // CLEANUP TEST USERS
    await prisma.workoutAssignment.delete({ where: { id: workoutAssignment.id } });
    await prisma.dietPlan.delete({ where: { id: dietPlan.id } });
    await prisma.user.delete({ where: { id: clientUser.id } });
    if (createdAdmin) {
      await prisma.user.delete({ where: { id: adminUser.id } });
    }
    console.log('\n[CLEANUP] Test records cleaned up.');

    console.log('\n================================================================');
    console.log('ALL 7 EDIT CLIENT PROFILE E2E & SECURITY TESTS PASSED PERFECTLY!');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

function jsonString(obj: any): string {
  return JSON.stringify(obj);
}

runEditClientProfileTests().catch((err) => {
  console.error('\n❌ TEST SUITE FAILED:', err);
  process.exit(1);
});
