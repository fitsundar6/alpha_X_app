import { prisma } from './config/prisma';
import { adminAuthService } from './modules/auth/admin_auth.service';
import { workoutService } from './modules/workout/workout.service';
import { workoutRepository } from './modules/workout/workout.repository';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

const JWT_SECRET = process.env.JWT_SECRET || 'alpha_x_default_secret_key_change_in_production';

async function main() {
  console.log('=====================================================');
  console.log('ALPHA X — DATA SYNCHRONIZATION & ISOLATION E2E TEST');
  console.log('=====================================================\n');

  try {
    // -------------------------------------------------------------------------
    // STEP 1: CLIENT IDENTITY & ACCOUNT SETUP
    // -------------------------------------------------------------------------
    console.log('--- STEP 1: PREPARING CLIENT A AND CLIENT B IN POSTGRESQL ---');
    const passwordHash = await bcrypt.hash('Password123!', 10);

    // Client A
    const userA = await prisma.user.upsert({
      where: { email: 'client.sync.a@alphaxgym.com' },
      update: {},
      create: {
        email: 'client.sync.a@alphaxgym.com',
        name: 'Client Alpha',
        passwordHash,
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-SYNC-A',
            phone: '9876543210',
            dailyStepGoal: 7000,
            dailySteps: 7000,
            fitnessLevel: 'intermediate',
            primaryGoal: 'Strength',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });
    console.log(`✔ Client A: ID=${userA.id}, ClientId=${userA.clientProfile?.clientId}, Email=${userA.email}`);

    // Client B
    const userB = await prisma.user.upsert({
      where: { email: 'client.sync.b@alphaxgym.com' },
      update: {},
      create: {
        email: 'client.sync.b@alphaxgym.com',
        name: 'Client Beta',
        passwordHash,
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-SYNC-B',
            phone: '9876543211',
            dailyStepGoal: 8000,
            dailySteps: 8000,
            fitnessLevel: 'advanced',
            primaryGoal: 'Hypertrophy',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });
    console.log(`✔ Client B: ID=${userB.id}, ClientId=${userB.clientProfile?.clientId}, Email=${userB.email}\n`);

    // Verify Admin authentication
    const adminSession = adminAuthService.generateAdminSession();
    console.log(`✔ Admin Session Token: Authenticated as ${adminSession.user.name} (${adminSession.user.role})`);

    // -------------------------------------------------------------------------
    // STEP 2: WORKOUT CREATION & ADMIN ASSIGNMENT WRITE PATH
    // -------------------------------------------------------------------------
    console.log('\n--- STEP 2: WORKOUT CREATION & ASSIGNMENT TO DATABASE ---');

    // Create Workout Plan A for Client A
    const workoutSessionA = await workoutService.createSession({
      title: 'Power Hypertrophy Plan A',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest • Back',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 50,
      description: 'Custom targeted hypertrophy for Client A',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      exercises: [
        {
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Press',
          category: 'Chest',
          orderIndex: 0,
          numberOfSets: 3,
          targetReps: '8–10',
          targetWeight: 85.0,
          restSeconds: 90,
          targetRir: 2,
          targetRpe: 8.5,
          tempo: '3-1-1-0',
          setType: 'Working',
          exerciseNotes: 'Control negative',
        },
      ],
    }, adminSession.user.id);
    console.log(`✔ Created Workout Session A in DB: ID=${workoutSessionA.id}, Title="${workoutSessionA.title}"`);

    // Assign Workout Plan A to Client A as Recommended
    const assignmentA = await workoutService.assignSession({
      sessionId: workoutSessionA.id,
      assignmentType: 'INDIVIDUAL',
      individualClientId: userA.clientProfile!.clientId, // Test resolution via AXG-XXXX
      isRecommended: true,
      assignedById: adminSession.user.id,
    });
    console.log(`✔ Admin Assigned Workout A to Client A (${userA.clientProfile!.clientId}). Returned ${assignmentA.length} assignment(s)`);

    // Verify in PostgreSQL table `workout_assignments` directly
    const dbAssignmentA = await prisma.workoutAssignment.findFirst({
      where: {
        sessionId: workoutSessionA.id,
        clientId: userA.id,
        active: true,
      },
      include: { session: true },
    });
    if (!dbAssignmentA) throw new Error('Database verification failed: workout assignment not found in PostgreSQL!');
    console.log(`✔ DATABASE VERIFIED: Assignment ID=${dbAssignmentA.id}, ClientId=${dbAssignmentA.clientId}, Recommended=${dbAssignmentA.isRecommended}`);

    // Create Workout Plan B for Client B
    const workoutSessionB = await workoutService.createSession({
      title: 'Leg Destruction Plan B',
      workoutType: 'Conditioning',
      targetMuscleGroup: 'Quads • Hamstrings',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 60,
      description: 'High volume leg training for Client B',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      exercises: [
        {
          exerciseId: 'ex_squats',
          exerciseName: 'Barbell Back Squat',
          category: 'Legs',
          orderIndex: 0,
          numberOfSets: 4,
          targetReps: '6–8',
          targetWeight: 140.0,
          restSeconds: 150,
          targetRir: 2,
          targetRpe: 8.5,
          tempo: '3-1-1-0',
          setType: 'Working',
          exerciseNotes: 'Full depth below parallel',
        },
      ],
    }, adminSession.user.id);

    await workoutService.assignSession({
      sessionId: workoutSessionB.id,
      assignmentType: 'INDIVIDUAL',
      individualClientId: userB.id, // Test resolution via User UUID
      isRecommended: true,
      assignedById: adminSession.user.id,
    });
    console.log(`✔ Admin Assigned Workout B to Client B (${userB.id})`);

    // -------------------------------------------------------------------------
    // STEP 3: CLIENT READ FLOW & ISOLATION CHECK (WORKOUTS)
    // -------------------------------------------------------------------------
    console.log('\n--- STEP 3: CLIENT WORKOUT RETRIEVAL & CLIENT ISOLATION ---');

    // Client A retrieval
    const clientAWorkouts = await workoutRepository.getClientAuthorizedSessions(userA.id);
    console.log(`✔ Client A authorized sessions count: ${clientAWorkouts.available.length}`);
    console.log(`✔ Client A recommended session: "${clientAWorkouts.recommended?.title}" (ID=${clientAWorkouts.recommended?.id})`);
    if (clientAWorkouts.recommended?.id !== workoutSessionA.id) {
      throw new Error(`Client A expected recommended session ${workoutSessionA.id}, got ${clientAWorkouts.recommended?.id}`);
    }

    // Client B retrieval
    const clientBWorkouts = await workoutRepository.getClientAuthorizedSessions(userB.id);
    console.log(`✔ Client B authorized sessions count: ${clientBWorkouts.available.length}`);
    console.log(`✔ Client B recommended session: "${clientBWorkouts.recommended?.title}" (ID=${clientBWorkouts.recommended?.id})`);
    if (clientBWorkouts.recommended?.id !== workoutSessionB.id) {
      throw new Error(`Client B expected recommended session ${workoutSessionB.id}, got ${clientBWorkouts.recommended?.id}`);
    }

    // STRICT ISOLATION ASSERTIONS:
    // Client A must NOT see Workout Plan B
    const aSeesB = clientAWorkouts.available.some((s) => s.id === workoutSessionB.id);
    if (aSeesB) throw new Error('ISOLATION BREACH: Client A can see Client B\'s workout plan!');
    console.log('✔ ISOLATION PASSED: Client A CANNOT see Client B\'s Workout Plan B');

    // Client B must NOT see Workout Plan A
    const bSeesA = clientBWorkouts.available.some((s) => s.id === workoutSessionA.id);
    if (bSeesA) throw new Error('ISOLATION BREACH: Client B can see Client A\'s workout plan!');
    console.log('✔ ISOLATION PASSED: Client B CANNOT see Client A\'s Workout Plan A');

    // -------------------------------------------------------------------------
    // STEP 4: DIET PLAN CREATION & ADMIN ASSIGNMENT
    // -------------------------------------------------------------------------
    console.log('\n--- STEP 4: DIET PLAN CREATION & ASSIGNMENT TO DATABASE ---');

    // Assign Diet Plan A to Client A
    await prisma.dietPlan.updateMany({
      where: { clientProfileId: userA.clientProfile!.id, isActive: true },
      data: { isActive: false },
    });
    const dietPlanA = await prisma.dietPlan.create({
      data: {
        clientProfileId: userA.clientProfile!.id,
        clientId: userA.clientProfile!.clientId,
        planName: 'Hypertrophy Diet Plan 2800 kcal',
        version: 1,
        dailyCalories: 2800,
        protein: 180,
        carbohydrates: 320,
        fat: 70,
        fiber: 35,
        waterTargetLiters: 4.0,
        isActive: true,
        assignedById: adminSession.user.id,
        assignedByName: adminSession.user.name,
        notes: 'Strict high protein diet for Client A',
      },
    });
    console.log(`✔ Created Diet Plan A in DB: ID=${dietPlanA.id}, PlanName="${dietPlanA.planName}", Calories=${dietPlanA.dailyCalories}`);

    // Assign Diet Plan B to Client B
    await prisma.dietPlan.updateMany({
      where: { clientProfileId: userB.clientProfile!.id, isActive: true },
      data: { isActive: false },
    });
    const dietPlanB = await prisma.dietPlan.create({
      data: {
        clientProfileId: userB.clientProfile!.id,
        clientId: userB.clientProfile!.clientId,
        planName: 'Keto Cut Plan 2100 kcal',
        version: 1,
        dailyCalories: 2100,
        protein: 170,
        carbohydrates: 50,
        fat: 130,
        fiber: 25,
        waterTargetLiters: 3.5,
        isActive: true,
        assignedById: adminSession.user.id,
        assignedByName: adminSession.user.name,
        notes: 'Low carb plan for Client B',
      },
    });
    console.log(`✔ Created Diet Plan B in DB: ID=${dietPlanB.id}, PlanName="${dietPlanB.planName}", Calories=${dietPlanB.dailyCalories}`);

    // -------------------------------------------------------------------------
    // STEP 5: CLIENT READ FLOW & ISOLATION CHECK (DIET PLANS)
    // -------------------------------------------------------------------------
    console.log('\n--- STEP 5: CLIENT DIET RETRIEVAL & ISOLATION VERIFICATION ---');

    // Client A retrieval via Prisma (same logic as GET /api/v1/client/me/diet-plan)
    const clientAFetchedDiet = await prisma.dietPlan.findFirst({
      where: {
        OR: [
          { clientProfileId: userA.clientProfile!.id },
          { clientId: userA.clientProfile!.clientId },
          { clientId: userA.id },
        ],
        isActive: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    console.log(`✔ Client A active diet plan fetched: "${clientAFetchedDiet?.planName}" (${clientAFetchedDiet?.dailyCalories} kcal)`);
    if (!clientAFetchedDiet || clientAFetchedDiet.id !== dietPlanA.id) {
      throw new Error(`Client A failed to retrieve Diet Plan A! Expected ${dietPlanA.id}`);
    }

    // Client B retrieval
    const clientBFetchedDiet = await prisma.dietPlan.findFirst({
      where: {
        OR: [
          { clientProfileId: userB.clientProfile!.id },
          { clientId: userB.clientProfile!.clientId },
          { clientId: userB.id },
        ],
        isActive: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    console.log(`✔ Client B active diet plan fetched: "${clientBFetchedDiet?.planName}" (${clientBFetchedDiet?.dailyCalories} kcal)`);
    if (!clientBFetchedDiet || clientBFetchedDiet.id !== dietPlanB.id) {
      throw new Error(`Client B failed to retrieve Diet Plan B! Expected ${dietPlanB.id}`);
    }

    // STRICT DIET ISOLATION:
    if (clientAFetchedDiet.id === dietPlanB.id) {
      throw new Error('ISOLATION BREACH: Client A retrieved Client B\'s diet plan!');
    }
    if (clientBFetchedDiet.id === dietPlanA.id) {
      throw new Error('ISOLATION BREACH: Client B retrieved Client A\'s diet plan!');
    }
    console.log('✔ ISOLATION PASSED: Client A and Client B only see their respective diet plans');

    // -------------------------------------------------------------------------
    // STEP 6: VERIFY PRODUCTION CLIENT ANUBHARATHI (AXG-0002)
    // -------------------------------------------------------------------------
    console.log('\n--- STEP 6: VERIFYING REAL PRODUCTION CLIENT ANUBHARATHI (AXG-0002) ---');
    const realClient = await prisma.user.findFirst({
      where: { clientProfile: { clientId: 'AXG-0002' } },
      include: { clientProfile: true },
    });
    if (realClient) {
      const realClientDiet = await prisma.dietPlan.findFirst({
        where: {
          OR: [
            { clientProfileId: realClient.clientProfile!.id },
            { clientId: realClient.clientProfile!.clientId },
          ],
          isActive: true,
        },
      });
      console.log(`✔ Real Client ${realClient.name} (${realClient.clientProfile?.clientId}) active diet plan: "${realClientDiet?.planName}" (${realClientDiet?.dailyCalories} kcal)`);
      if (realClientDiet) {
        console.log(`✔ Confirmed: Real phone user Anubharathi diet is persisted in PostgreSQL with ${realClientDiet.dailyCalories} kcal, ${realClientDiet.protein}g protein!`);
      }
    }

    console.log('\n=====================================================');
    console.log('🎉 ALL DATA SYNCHRONIZATION AND ISOLATION TESTS PASSED!');
    console.log('=====================================================');
  } catch (err: any) {
    console.error('\n❌ TEST FAILED:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();
