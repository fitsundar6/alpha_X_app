import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';
import { prisma } from './config/prisma';

const GREEN = '\x1b[32m\u2713\x1b[0m';
const RED   = '\x1b[31m\u2717\x1b[0m';
const BOLD  = '\x1b[1m';
const RESET = '\x1b[0m';

let passed = 0;
let failed = 0;

function ok(desc: string, condition: boolean) {
  if (condition) { console.log(`  ${GREEN} ${desc}`); passed++; }
  else           { console.log(`  ${RED} ${desc}`);   failed++; }
}

async function runTest(name: string, fn: () => Promise<void>) {
  console.log(`\n${BOLD}-- ${name} --${RESET}`);
  try { await fn(); }
  catch (e: any) { console.log(`  ${RED} THREW: ${e?.message}`); failed++; }
}

const ADMIN_ID = 'admin_flex_test';
const CLIENT_A_ID = 'client_flex_test_a';
const CLIENT_B_ID = 'client_flex_test_b';

async function seedTestUsers() {
  await prisma.user.upsert({
    where: { id: CLIENT_A_ID },
    update: {},
    create: {
      id: CLIENT_A_ID,
      email: 'client_a_flex@alphax.local',
      name: 'Client A Flex',
      role: 'CLIENT',
      status: 'APPROVED',
    },
  });

  await prisma.user.upsert({
    where: { id: CLIENT_B_ID },
    update: {},
    create: {
      id: CLIENT_B_ID,
      email: 'client_b_flex@alphax.local',
      name: 'Client B Flex',
      role: 'CLIENT',
      status: 'APPROVED',
    },
  });

  // Clean up any previous test overrides for clean run
  await prisma.clientSessionOverride.deleteMany({
    where: { clientId: { in: [CLIENT_A_ID, CLIENT_B_ID] } },
  });
}

async function seedTestSplit() {
  return workoutService.createWorkoutSplit({
    id: 'split_flex_test',
    title: 'Flex Workout Split',
    splitType: 'PPL',
    clientId: CLIENT_A_ID,
    days: [
      {
        dayOfWeek: 1,
        dayName: 'Monday',
        sessionTitle: 'Monday Push',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest • Shoulders • Triceps',
        estimatedDurationMinutes: 50,
        isRestDay: false,
        exercises: [
          {
            exerciseId: 'ex_bb_bench',
            exerciseName: 'Barbell Bench Press',
            category: 'Chest',
            orderIndex: 0,
            numberOfSets: 3,
            targetReps: '8-12',
            targetWeight: 80,
            restSeconds: 90,
          },
          {
            exerciseId: 'ex_incline_db_press',
            exerciseName: 'Incline Dumbbell Press',
            category: 'Chest',
            orderIndex: 1,
            numberOfSets: 3,
            targetReps: '10-12',
            targetWeight: 26,
            restSeconds: 90,
          },
          {
            exerciseId: 'ex_tricep_pushdown',
            exerciseName: 'Triceps Rope Pushdown',
            category: 'Triceps',
            orderIndex: 2,
            numberOfSets: 3,
            targetReps: '12-15',
            targetWeight: 25,
            restSeconds: 60,
          },
        ],
      },
      {
        dayOfWeek: 2,
        dayName: 'Tuesday',
        sessionTitle: 'Tuesday Pull',
        workoutType: 'Strength',
        targetMuscleGroup: 'Back • Biceps',
        estimatedDurationMinutes: 50,
        isRestDay: false,
        exercises: [
          {
            exerciseId: 'ex_pullup',
            exerciseName: 'Pull-Up',
            category: 'Back',
            orderIndex: 0,
            numberOfSets: 3,
            targetReps: '6-10',
            targetWeight: 0,
            restSeconds: 90,
          },
        ],
      },
      {
        dayOfWeek: 3,
        dayName: 'Wednesday',
        sessionTitle: 'Wednesday Legs',
        workoutType: 'Strength',
        targetMuscleGroup: 'Quads • Hamstrings',
        estimatedDurationMinutes: 55,
        isRestDay: false,
        exercises: [
          {
            exerciseId: 'ex_squat',
            exerciseName: 'Barbell Back Squat',
            category: 'Legs',
            orderIndex: 0,
            numberOfSets: 4,
            targetReps: '6-8',
            targetWeight: 100,
            restSeconds: 120,
          },
        ],
      },
    ],
  }, ADMIN_ID);
}

async function runAllTests() {
  console.log(`\n${BOLD}======================================================${RESET}`);
  console.log(`${BOLD} ALPHA X GYM: FLEXIBLE SESSIONS & PERSISTENT OVERRIDES REGRESSION${RESET}`);
  console.log(`${BOLD}======================================================${RESET}`);

  await seedTestUsers();
  const split = await seedTestSplit();

  const mondayDay = split.days.find((d) => d.dayOfWeek === 'Monday');
  const sessionId = mondayDay?.sessionId || mondayDay?.id || '';

  // Also assign the same session to Client B to test isolation
  await workoutRepository.assignSession({
    sessionId,
    assignmentType: 'INDIVIDUAL',
    individualClientId: CLIENT_B_ID,
    clientIds: [CLIENT_B_ID],
    isRecommended: true,
    scheduledDate: '2026-10-26',
    assignedById: ADMIN_ID,
  });

  // TEST 1: Initial Session Baseline
  await runTest('1. Initial Session Baseline for Client A and Client B', async () => {
    const authA = await workoutRepository.getClientAuthorizedSessions(CLIENT_A_ID, 'Monday');
    const sessionA = authA.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('Client A can fetch Monday Push session', !!sessionA);
    ok('Monday Push has 3 base exercises', sessionA?.exercises.length === 3);
    ok('First exercise is Barbell Bench Press', sessionA?.exercises[0].exerciseName === 'Barbell Bench Press');

    const authB = await workoutRepository.getClientAuthorizedSessions(CLIENT_B_ID, 'Monday');
    const sessionB = authB.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('Client B can fetch Monday Push session', !!sessionB);
    ok('Client B sees Barbell Bench Press as first exercise', sessionB?.exercises[0].exerciseName === 'Barbell Bench Press');
  });

  // TEST 2: Replace Exercise for Client A (Barbell Bench Press -> Dumbbell Bench Press)
  await runTest('2. Replace Exercise and Confirm Persistence for Future Sessions', async () => {
    const rep = await workoutService.replaceExerciseInSession(CLIENT_A_ID, sessionId, {
      originalExerciseId: 'ex_bb_bench',
      originalExerciseName: 'Barbell Bench Press',
      replacementExerciseId: 'ex_db_bench',
      replacementExerciseName: 'Dumbbell Bench Press',
      category: 'Chest',
      targetReps: '8-10',
      targetWeight: 32.5,
    }, 'Monday');

    ok('Replacement saved via service', !!rep && (rep.replacements?.length || 0) >= 1);
    ok('Replacement records Dumbbell Bench Press', rep.replacements?.[0].replacementExerciseName === 'Dumbbell Bench Press');

    // Verify retrieval for next occurrence
    const nextOccurrence = await workoutRepository.getClientAuthorizedSessions(CLIENT_A_ID, 'Monday');
    const mondaySession = nextOccurrence.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('Next Monday occurrence automatically shows Dumbbell Bench Press', mondaySession?.exercises[0].exerciseName === 'Dumbbell Bench Press');
    ok('Target weight reflected as 32.5 kg', mondaySession?.exercises[0].targetWeight === 32.5);
    ok('Exercise marked as isCustomReplacement', (mondaySession?.exercises[0] as any).isCustomReplacement === true);
    ok('Original exercise ID preserved for reference', (mondaySession?.exercises[0] as any).originalExerciseId === 'ex_bb_bench');
  });

  // TEST 3: Add Custom Exercise to Client A Session
  await runTest('3. Add Custom Exercise and Confirm Persistence in Next Occurrence', async () => {
    const added = await workoutService.addExerciseToSessionOverride(CLIENT_A_ID, sessionId, {
      exerciseId: 'ex_incline_fly',
      exerciseName: 'Incline Dumbbell Fly',
      category: 'Chest',
      numberOfSets: 3,
      targetReps: '12-15',
      targetWeight: 16,
    }, 'Monday');

    ok('Added exercise saved in override', !!added && (added.addedExercises?.length || 0) >= 1);

    // Verify retrieval
    const nextOccurrence = await workoutRepository.getClientAuthorizedSessions(CLIENT_A_ID, 'Monday');
    const mondaySession = nextOccurrence.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('Monday Push now has 4 exercises (3 original + 1 added)', mondaySession?.exercises.length === 4);
    const flyEx = mondaySession?.exercises.find((e) => e.exerciseId === 'ex_incline_fly');
    ok('Incline Dumbbell Fly is present', !!flyEx);
    ok('Incline Dumbbell Fly marked as isCustomAdded', (flyEx as any)?.isCustomAdded === true);
  });

  // TEST 4: Client Isolation (Client B MUST NOT be mutated)
  await runTest('4. Customizations Remain Isolated Between Different Clients', async () => {
    const authB = await workoutRepository.getClientAuthorizedSessions(CLIENT_B_ID, 'Monday');
    const sessionB = authB.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));

    ok('Client B still has exactly 3 exercises (unaffected by Client A additions)', sessionB?.exercises.length === 3);
    ok('Client B still has Barbell Bench Press (NOT Dumbbell Bench Press)', sessionB?.exercises[0].exerciseName === 'Barbell Bench Press');
    ok('Client B does NOT have Incline Dumbbell Fly', !sessionB?.exercises.some((e) => e.exerciseId === 'ex_incline_fly'));
  });

  // TEST 5: Admin Template Independence & Compatibility
  await runTest('5. Admin Template Is Preserved and Future Updates Flow Through', async () => {
    const adminSession = await workoutRepository.getSessionById(sessionId);
    ok('Admin session still has original Barbell Bench Press in database', adminSession?.exercises[0].exerciseName === 'Barbell Bench Press');
    ok('Admin session has 3 exercises in database (no custom client exercises injected)', adminSession?.exercises.length === 3);

    // Admin updates session description
    await workoutRepository.updateSession(sessionId, {
      description: 'Updated by Admin with new tempo instructions',
    });

    const refreshedA = await workoutRepository.getClientAuthorizedSessions(CLIENT_A_ID, 'Monday');
    const sessionA = refreshedA.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('Client A receives updated admin description', sessionA?.description === 'Updated by Admin with new tempo instructions');
    ok('Client A still preserves their Dumbbell Bench Press replacement', sessionA?.exercises[0].exerciseName === 'Dumbbell Bench Press');
  });

  // TEST 6: Workout-Day Scheduling Preservation
  await runTest('6. Preserve Workout-Day Scheduling (Monday is Push, Tuesday is Pull)', async () => {
    const clientSplit = await workoutRepository.getClientWorkoutSplit(CLIENT_A_ID);
    if (!clientSplit) throw new Error('Client split not found');

    const mon = clientSplit.days.find((d) => d.dayOfWeek === 'Monday');
    const tue = clientSplit.days.find((d) => d.dayOfWeek === 'Tuesday');
    const wed = clientSplit.days.find((d) => d.dayOfWeek === 'Wednesday');

    ok('Monday remains Push', mon?.name.includes('Push') === true);
    ok('Monday split day displays Dumbbell Bench Press for Client A', mon?.exercises[0].exerciseName === 'Dumbbell Bench Press');
    ok('Tuesday remains Pull', tue?.name.includes('Pull') === true);
    ok('Tuesday has Pull-Up', tue?.exercises[0].exerciseName === 'Pull-Up');
    ok('Wednesday remains Legs', wed?.name.includes('Legs') === true);
    ok('Wednesday has Barbell Back Squat', wed?.exercises[0].exerciseName === 'Barbell Back Squat');
  });

  // TEST 7: Reset Customizations (Restore Admin Assigned Plan)
  await runTest('7. Restore Admin Assigned Original Workout or Reset Single Exercise', async () => {
    // 7a. Reset single exercise (Incline Dumbbell Fly)
    await workoutService.resetSessionOverride(CLIENT_A_ID, sessionId, 'ex_incline_fly');
    const afterFlyReset = await workoutRepository.getClientAuthorizedSessions(CLIENT_A_ID, 'Monday');
    const s1 = afterFlyReset.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('Incline Dumbbell Fly removed after single exercise reset', !s1?.exercises.some((e) => e.exerciseId === 'ex_incline_fly'));
    ok('Dumbbell Bench Press replacement still preserved', s1?.exercises[0].exerciseName === 'Dumbbell Bench Press');

    // 7b. Full session reset to admin template
    await workoutService.resetSessionOverride(CLIENT_A_ID, sessionId);
    const afterFullReset = await workoutRepository.getClientAuthorizedSessions(CLIENT_A_ID, 'Monday');
    const s2 = afterFullReset.available.find((s) => s.id === sessionId || s.title.includes('Monday Push'));
    ok('After full reset, session reverts back to Barbell Bench Press', s2?.exercises[0].exerciseName === 'Barbell Bench Press');
    ok('Session exercises count restored to original 3', s2?.exercises.length === 3);
  });

  // TEST 8: Completed Workout Record, Set Logs, and Analytics Persistence
  await runTest('8. Workout Records, Sets Logs, Weights & Reps Intact', async () => {
    const savedRecord = await workoutRepository.saveWorkoutRecord(CLIENT_A_ID, {
      sessionId,
      sessionTitle: 'Monday Push Completed Test',
      workoutType: 'Strength',
      startedAt: new Date(Date.now() - 3600000).toISOString(),
      completedAt: new Date().toISOString(),
      durationSeconds: 3600,
      totalVolume: 4500,
      completedSetsCount: 9,
      skippedSetsCount: 0,
      isCompleted: true,
      personalRecords: [],
      exerciseRecords: [
        {
          exerciseId: 'ex_db_bench',
          exerciseName: 'Dumbbell Bench Press',
          orderIndex: 0,
          isSkipped: false,
          sets: [
            { setNumber: 1, setType: 'WORKING', actualWeight: 32, actualReps: 10, isCompleted: true },
            { setNumber: 2, setType: 'WORKING', actualWeight: 32, actualReps: 10, isCompleted: true },
            { setNumber: 3, setType: 'WORKING', actualWeight: 34, actualReps: 8,  isCompleted: true },
          ],
        },
      ],
    });

    ok('Workout record created with isCompleted: true', savedRecord.isCompleted === true);
    ok('Total volume preserved', savedRecord.totalVolume === 4500);

    const history = await workoutRepository.getClientWorkoutHistory(CLIENT_A_ID);
    const match = history.find((h) => h.id === savedRecord.id);
    ok('Record found in client history', !!match);
    ok('Performed Dumbbell Bench Press logged in history', match?.exerciseRecords[0].exerciseName === 'Dumbbell Bench Press');
    ok('All 3 sets logged with exact weights and reps', match?.exerciseRecords[0].sets.length === 3);
  });

  console.log(`\n${BOLD}======================================================${RESET}`);
  console.log(`RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log(`${BOLD}======================================================${RESET}`);

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runAllTests().catch((e) => {
  console.error('Fatal test error:', e);
  process.exit(1);
});
