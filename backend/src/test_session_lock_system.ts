import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';
import { getTodayISTDateString } from './utils/istDate';
import { prisma } from './config/prisma';

async function runTests() {
  console.log('=== [ALPHA X GYM] WORKOUT ASSIGNMENT & SESSION LOCK SYSTEM TESTS ===');

  const clientUser = await prisma.user.findFirst({
    where: { role: 'CLIENT' },
    include: { clientProfile: true },
  });
  if (!clientUser) {
    throw new Error('No client user found in database');
  }

  const adminUser = await prisma.user.findFirst({
    where: { role: 'ADMIN' },
  });
  const testAdminId = adminUser ? adminUser.id : 'admin_alex_stone';
  const testClientId = clientUser.clientProfile?.clientId || clientUser.id;

  const todayIST = getTodayISTDateString();
  const yesterdayIST = '2026-10-12';

  console.log(`Today in IST: ${todayIST}`);
  console.log(`Yesterday in IST: ${yesterdayIST}`);
  console.log(`Test Client: ${testClientId} (${clientUser.name}, userId: ${clientUser.id})`);
  console.log(`Test Admin: ${testAdminId}`);

  // Step 1: Create two workout sessions: Chest (yesterday) and Lat (today)
  const chestSession = await workoutRepository.createSession({
    title: 'Alpha Chest & Triceps Hypertrophy',
    workoutType: 'Hypertrophy',
    targetMuscleGroup: 'Chest • Triceps',
    difficulty: 'Intermediate',
    estimatedDurationMinutes: 55,
    availabilityType: 'INDIVIDUAL',
    createdById: testAdminId,
    exercises: [
      {
        exerciseId: 'ex_bench_press',
        exerciseName: 'Barbell Flat Bench Press',
        category: 'Chest',
        orderIndex: 0,
        numberOfSets: 3,
        targetReps: '8-10',
        targetWeight: 80,
        restSeconds: 90,
        setType: 'Working',
      },
    ],
  });
  console.log(`✔ Created Chest Session: ${chestSession.id}`);

  const latSession = await workoutRepository.createSession({
    title: 'Alpha Lat & Biceps Pull Session',
    workoutType: 'Strength',
    targetMuscleGroup: 'Back • Biceps',
    difficulty: 'Intermediate',
    estimatedDurationMinutes: 60,
    availabilityType: 'INDIVIDUAL',
    createdById: testAdminId,
    exercises: [
      {
        exerciseId: 'ex_lat_pulldown',
        exerciseName: 'Wide Grip Lat Pulldown',
        category: 'Back',
        orderIndex: 0,
        numberOfSets: 4,
        targetReps: '10-12',
        targetWeight: 65,
        restSeconds: 75,
        setType: 'Working',
      },
    ],
  });
  console.log(`✔ Created Lat Session: ${latSession.id}`);

  // Step 2: Assign Chest for yesterday
  const yesterdayAssignments = await workoutService.assignSession({
    sessionId: chestSession.id,
    assignmentType: 'INDIVIDUAL',
    individualClientId: testClientId,
    isRecommended: true,
    scheduledDate: yesterdayIST,
    assignedById: testAdminId,
  });
  const chestAssignmentId = yesterdayAssignments[0]?.id;
  console.log(`✔ Assigned Chest to client for yesterday (${yesterdayIST}), assignment ID: ${chestAssignmentId}`);

  // Step 3: Complete Chest workout yesterday and lock it
  const completedChestRecord = await workoutService.recordWorkout(testClientId, {
    sessionId: chestSession.id,
    assignmentId: chestAssignmentId,
    sessionTitle: chestSession.title,
    workoutType: chestSession.workoutType,
    startedAt: new Date(Date.now() - 25 * 3600 * 1000).toISOString(),
    completedAt: new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
    durationSeconds: 3300,
    totalVolume: 2400,
    completedSetsCount: 3,
    skippedSetsCount: 0,
    isCompleted: true,
    scheduledDate: yesterdayIST,
    exerciseRecords: [
      {
        exerciseId: 'ex_bench_press',
        exerciseName: 'Barbell Flat Bench Press',
        orderIndex: 0,
        setRecords: [
          { setNumber: 1, setType: 'WORKING', actualWeight: 80, actualReps: 10, isCompleted: true },
          { setNumber: 2, setType: 'WORKING', actualWeight: 80, actualReps: 9, isCompleted: true },
          { setNumber: 3, setType: 'WORKING', actualWeight: 80, actualReps: 8, isCompleted: true },
        ],
      },
    ],
  });
  console.log(`✔ Completed Chest Workout. Record ID: ${completedChestRecord.id}, isLocked: ${completedChestRecord.isLocked}`);

  if (!completedChestRecord.isLocked) {
    throw new Error('Chest record should be marked isLocked: true upon completion!');
  }

  // Step 4: Assign Lat workout for TODAY in IST
  const todayAssignments = await workoutService.assignSession({
    sessionId: latSession.id,
    assignmentType: 'INDIVIDUAL',
    individualClientId: testClientId,
    isRecommended: true,
    scheduledDate: todayIST,
    assignedById: testAdminId,
  });
  const latAssignmentId = todayAssignments[0]?.id;
  console.log(`✔ Assigned Lat workout to client for today (${todayIST}), assignment ID: ${latAssignmentId}`);

  // Step 5: Test Client Authorized Sessions - Must return TODAY'S Lat session, NOT yesterday's Chest session
  const authorized = await workoutService.getClientSessions(testClientId);
  console.log(`Client Authorized Sessions count: ${authorized.available.length}`);
  console.log(`Available titles: ${authorized.available.map((s) => s.title).join(', ')}`);

  const hasYesterdayChest = authorized.available.some((s) => s.id === chestSession.id);
  const hasTodayLat = authorized.available.some((s) => s.id === latSession.id);

  if (hasYesterdayChest) {
    throw new Error('FAILED: Yesterday\'s Chest workout should NOT be in today\'s client authorized sessions!');
  }
  if (!hasTodayLat) {
    throw new Error('FAILED: Today\'s Lat workout MUST be in today\'s client authorized sessions!');
  }
  console.log('✔ PASSED: Client only sees today\'s Lat workout in IST! Yesterday\'s completed Chest is cleanly excluded.');

  // Step 6: Test Modification Rejection on Locked Chest Workout
  let lockRejected = false;
  try {
    await workoutRepository.saveSetCompletion(testClientId, chestSession.id, {
      exerciseId: 'ex_bench_press',
      setNumber: 1,
      isCompleted: true,
      actualWeight: 85,
      actualReps: 10,
    });
  } catch (err: any) {
    if (err.message && err.message.includes('SESSION_LOCKED')) {
      lockRejected = true;
      console.log(`✔ PASSED: Modification rejected as expected with error: "${err.message}"`);
    } else {
      throw err;
    }
  }

  if (!lockRejected) {
    throw new Error('FAILED: Modifying a completed/locked session should have been rejected!');
  }

  // Step 7: Admin Unlocks the Locked Chest Session
  console.log('Testing Admin Unlock...');
  const unlockResult = await workoutService.unlockSession(testAdminId, {
    sessionId: chestSession.id,
    clientId: testClientId,
    reason: 'Client requested correction of bench press weight from 80kg to 85kg.',
  });

  console.log(`✔ Admin Unlock response: ${unlockResult.message}`);
  console.log(`✔ Unlocked by: ${unlockResult.adminId}, Reason: "${unlockResult.reason}", At: ${unlockResult.unlockedAt}`);

  // Step 8: Test that modifications now succeed after unlock
  const setUpdateAfterUnlock = await workoutRepository.saveSetCompletion(testClientId, chestSession.id, {
    exerciseId: 'ex_bench_press',
    setNumber: 1,
    isCompleted: true,
    actualWeight: 85,
    actualReps: 10,
  });
  console.log(`✔ PASSED: Modification succeeded post-unlock. New weight: ${setUpdateAfterUnlock.actualWeight}kg`);

  console.log('\n======================================================');
  console.log('🎉 ALL BACKEND WORKOUT SYSTEM TESTS PASSED SUCCESSFULLY!');
  console.log('======================================================\n');
}

runTests().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
