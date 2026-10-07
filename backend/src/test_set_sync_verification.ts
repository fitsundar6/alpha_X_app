import { prisma } from './config/prisma';
import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';

async function runSetSyncVerification() {
  console.log('=== ALPHA X WORKOUT SET-COUNT SYNCHRONIZATION REAL DATA TEST ===\n');

  const clients = await prisma.user.findMany({
    where: { role: 'CLIENT' },
    select: { id: true, name: true, email: true },
  });
  console.log(`Found ${clients.length} clients in database:`, clients);

  if (clients.length < 2) {
    throw new Error('Expected at least 2 clients in database for testing');
  }

  const adminUser = await prisma.user.findFirst({
    where: { role: 'ADMIN' },
    select: { id: true },
  });
  const adminId = adminUser ? adminUser.id : 'admin_alex_stone';
  const clientAId = clients[0].id;
  const clientBId = clients[1].id;
  console.log(`Client A: ${clients[0].name} (${clientAId})`);
  console.log(`Client B: ${clients[1].name} (${clientBId})\n`);

  // Step 1: Admin creates test workout session with 3 exercises:
  // Exercise 1: 3 sets
  // Exercise 2: 5 sets
  // Exercise 3: 4 sets
  const testSessionId = `ws_test_sync_${Date.now()}`;
  const sessionData = {
    id: testSessionId,
    title: 'Alpha X Hypertrophy Test Sync',
    workoutType: 'Hypertrophy',
    targetMuscleGroup: 'Chest • Back • Arms',
    difficulty: 'Advanced',
    estimatedDurationMinutes: 65,
    description: 'Real data test for 3 / 5 / 4 set synchronization.',
    isActive: true,
    availabilityType: 'INDIVIDUAL',
    exercises: [
      {
        exerciseId: 'ex_bench_press',
        exerciseName: 'Barbell Bench Press',
        category: 'Chest',
        orderIndex: 0,
        numberOfSets: 3,
        targetReps: '8–10',
        targetWeight: 90.0,
        restSeconds: 120,
        targetRir: 2,
        targetRpe: 8.0,
        tempo: '3-1-1-0',
        setType: 'Working',
        exerciseNotes: 'Control bar to lower chest.',
      },
      {
        exerciseId: 'ex_db_incline',
        exerciseName: 'Incline Dumbbell Press',
        category: 'Chest',
        orderIndex: 1,
        numberOfSets: 5,
        targetReps: '10–12',
        targetWeight: 34.0,
        restSeconds: 90,
        targetRir: 1,
        targetRpe: 8.5,
        tempo: '3-0-1-0',
        setType: 'Working',
        exerciseNotes: 'Deep stretch at bottom.',
      },
      {
        exerciseId: 'ex_cable_fly',
        exerciseName: 'Standing Cable Fly',
        category: 'Chest',
        orderIndex: 2,
        numberOfSets: 4,
        targetReps: '12–15',
        targetWeight: 20.0,
        restSeconds: 60,
        targetRir: 1,
        targetRpe: 9.0,
        tempo: '2-1-1-1',
        setType: 'Working',
        exerciseNotes: 'Peak contraction 1 second.',
      },
    ],
  };

  console.log('1. Admin creating session with sets: 3 / 5 / 4...');
  const createdSession = await workoutService.createSession(sessionData, adminId);
  console.log(`   Admin created session: ${createdSession.id}`);
  console.log(`   Exercise 1 sets: ${createdSession.exercises[0].numberOfSets}`);
  console.log(`   Exercise 2 sets: ${createdSession.exercises[1].numberOfSets}`);
  console.log(`   Exercise 3 sets: ${createdSession.exercises[2].numberOfSets}`);

  if (
    createdSession.exercises[0].numberOfSets !== 3 ||
    createdSession.exercises[1].numberOfSets !== 5 ||
    createdSession.exercises[2].numberOfSets !== 4
  ) {
    throw new Error('FAILED: Admin created session set counts do not match 3 / 5 / 4');
  }
  console.log('   ✔ Admin session sets verified: 3 / 5 / 4\n');

  // Step 2: Assign session specifically to Client A as Recommended
  console.log('2. Assigning session to Client A (client_john_doe)...');
  await workoutService.assignSession({
    sessionId: testSessionId,
    assignmentType: 'INDIVIDUAL',
    individualClientId: clientAId,
    isRecommended: true,
    assignedById: adminId,
  });
  console.log('   ✔ Session assigned to Client A as Recommended\n');

  // Step 3: Inspect Database Record directly via Prisma
  console.log('3. Inspecting PostgreSQL Database records directly...');
  const dbSession = await prisma.workoutSession.findUnique({
    where: { id: testSessionId },
    include: {
      exercises: {
        include: { setTemplates: true },
        orderBy: { orderIndex: 'asc' },
      },
    },
  });

  if (!dbSession) {
    throw new Error('FAILED: Session not found in PostgreSQL workout_sessions table');
  }

  console.log(`   DB Session: ${dbSession.title} (${dbSession.id})`);
  console.log(`   DB Exercise 1 (${dbSession.exercises[0].exerciseName}): numberOfSets = ${dbSession.exercises[0].numberOfSets}, templates = ${dbSession.exercises[0].setTemplates.length}`);
  console.log(`   DB Exercise 2 (${dbSession.exercises[1].exerciseName}): numberOfSets = ${dbSession.exercises[1].numberOfSets}, templates = ${dbSession.exercises[1].setTemplates.length}`);
  console.log(`   DB Exercise 3 (${dbSession.exercises[2].exerciseName}): numberOfSets = ${dbSession.exercises[2].numberOfSets}, templates = ${dbSession.exercises[2].setTemplates.length}`);

  if (
    dbSession.exercises[0].numberOfSets !== 3 ||
    dbSession.exercises[0].setTemplates.length !== 3 ||
    dbSession.exercises[1].numberOfSets !== 5 ||
    dbSession.exercises[1].setTemplates.length !== 5 ||
    dbSession.exercises[2].numberOfSets !== 4 ||
    dbSession.exercises[2].setTemplates.length !== 4
  ) {
    throw new Error('FAILED: Database record numberOfSets or setTemplates does not match 3 / 5 / 4');
  }
  console.log('   ✔ DATABASE sets verified: 3 / 5 / 4 (PASS)\n');

  // Step 4: Client Workout API response verification
  console.log('4. Calling Client Workout GET endpoint for Client A...');
  const clientAData = await workoutRepository.getClientAuthorizedSessions(clientAId);
  const clientASession = clientAData.available.find((s) => s.id === testSessionId);

  if (!clientASession) {
    throw new Error('FAILED: Test session not returned in Client A authorized sessions');
  }

  console.log(`   Client API Session: ${clientASession.title}`);
  for (let i = 0; i < clientASession.exercises.length; i++) {
    const ex = clientASession.exercises[i];
    console.log(`   Client API Exercise ${i + 1} (${ex.exerciseName}):`);
    console.log(`      numberOfSets: ${ex.numberOfSets}`);
    console.log(`      setCount: ${ex.setCount}`);
    console.log(`      sets.length: ${ex.sets?.length}`);
  }

  if (
    clientASession.exercises[0].numberOfSets !== 3 ||
    clientASession.exercises[0].setCount !== 3 ||
    (clientASession.exercises[0].sets?.length ?? 0) !== 3 ||
    clientASession.exercises[1].numberOfSets !== 5 ||
    clientASession.exercises[1].setCount !== 5 ||
    (clientASession.exercises[1].sets?.length ?? 0) !== 5 ||
    clientASession.exercises[2].numberOfSets !== 4 ||
    clientASession.exercises[2].setCount !== 4 ||
    (clientASession.exercises[2].sets?.length ?? 0) !== 4
  ) {
    throw new Error('FAILED: Client API did not return 3 / 5 / 4 sets');
  }
  console.log('   ✔ CLIENT API sets verified: 3 / 5 / 4 (PASS)\n');

  // Step 5: Client Isolation check
  console.log('5. Verifying Client Isolation (Client B vs Client A)...');
  const clientBData = await workoutRepository.getClientAuthorizedSessions(clientBId);
  const clientBSession = clientBData.available.find((s) => s.id === testSessionId);

  if (clientBSession) {
    throw new Error('FAILED: Client B received Client A\'s individually assigned workout!');
  }
  console.log('   ✔ Client B cannot see Client A\'s workout session. Client isolation: PASS\n');

  // Step 6: Admin Workout Editing & Persistence Check
  console.log('6. Testing Admin Workout Editing (updating sets to 4 / 6 / 5)...');
  const updatedData = {
    exercises: [
      {
        ...sessionData.exercises[0],
        numberOfSets: 4,
      },
      {
        ...sessionData.exercises[1],
        numberOfSets: 6,
      },
      {
        ...sessionData.exercises[2],
        numberOfSets: 5,
      },
    ],
  };

  await workoutService.updateSession(testSessionId, updatedData);
  const dbUpdated = await prisma.workoutSession.findUnique({
    where: { id: testSessionId },
    include: {
      exercises: {
        include: { setTemplates: true },
        orderBy: { orderIndex: 'asc' },
      },
    },
  });

  if (!dbUpdated) throw new Error('DB session not found after update');

  console.log(`   Updated DB Exercise 1: ${dbUpdated.exercises[0].numberOfSets} sets (${dbUpdated.exercises[0].setTemplates.length} templates)`);
  console.log(`   Updated DB Exercise 2: ${dbUpdated.exercises[1].numberOfSets} sets (${dbUpdated.exercises[1].setTemplates.length} templates)`);
  console.log(`   Updated DB Exercise 3: ${dbUpdated.exercises[2].numberOfSets} sets (${dbUpdated.exercises[2].setTemplates.length} templates)`);

  if (
    dbUpdated.exercises[0].numberOfSets !== 4 ||
    dbUpdated.exercises[0].setTemplates.length !== 4 ||
    dbUpdated.exercises[1].numberOfSets !== 6 ||
    dbUpdated.exercises[1].setTemplates.length !== 6 ||
    dbUpdated.exercises[2].numberOfSets !== 5 ||
    dbUpdated.exercises[2].setTemplates.length !== 5
  ) {
    throw new Error('FAILED: DB session update did not persist updated set counts');
  }
  console.log('   ✔ Admin workout editing & DB update verified: 4 / 6 / 5 (PASS)\n');

  // Clean up test data
  console.log('7. Cleaning up test data...');
  await workoutService.deleteSession(testSessionId);
  console.log('   ✔ Test session cleaned up successfully\n');

  console.log('=== ALL REAL DATA SYNCHRONIZATION TESTS PASSED ===');
}

runSetSyncVerification()
  .catch((err) => {
    console.error('Test Failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
