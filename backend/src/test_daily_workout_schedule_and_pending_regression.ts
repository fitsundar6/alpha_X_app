import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';
import { setDateProviderForTesting, getTodayISTDateString } from './utils/istDate';
import { prisma } from './config/prisma';

async function runDailyScheduleAndPendingRegressionTests() {
  console.log('======================================================================');
  console.log('🧪 ALPHA X — DAILY WORKOUT SCHEDULE & PENDING WORKOUTS REGRESSION SUITE');
  console.log('======================================================================\n');

  let passedTests = 0;
  const totalTests = 10;

  try {
    // 1. Resolve test admin and test clients
    const adminUser = await prisma.user.findFirst({
      where: { role: 'ADMIN' },
    });
    const testAdminId = adminUser ? adminUser.id : 'admin_alex_stone';

    const clientUsers = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      include: { clientProfile: true },
      take: 2,
    });

    if (clientUsers.length < 1) {
      throw new Error('At least one CLIENT user is required in the database for testing.');
    }

    const clientAUser = clientUsers[0];
    const clientAId = clientAUser.clientProfile?.clientId || clientAUser.id;

    // Use second client or synthesize client B
    let clientBId = 'client_beta_isolated_test';
    let clientBUser = clientUsers.length > 1 ? clientUsers[1] : null;
    if (clientBUser) {
      clientBId = clientBUser.clientProfile?.clientId || clientBUser.id;
    }

    console.log(`[INFO] Operating with Test Admin: ${testAdminId}`);
    console.log(`[INFO] Test Client A: ${clientAId} (${clientAUser.name})`);
    console.log(`[INFO] Test Client B: ${clientBId} (${clientBUser ? clientBUser.name : 'Isolated Mock Client'})\n`);

    // Clean up test assignments and records for Client A and Client B
    await prisma.workoutRecord.deleteMany({
      where: {
        clientId: { in: [clientAUser.id, clientAId, clientBId, clientBUser?.id || 'none'] },
      },
    });
    await prisma.workoutAssignment.deleteMany({
      where: {
        clientId: { in: [clientAUser.id, clientAId, clientBId, clientBUser?.id || 'none'] },
      },
    });

    // Dates for testing:
    // Monday Oct 12, 2026
    // Tuesday Oct 13, 2026
    // Wednesday Oct 14, 2026
    // Following Monday Oct 19, 2026
    // Following Tuesday Oct 20, 2026
    const monday1Date = '2026-10-12';
    const tuesday1Date = '2026-10-13';
    const wednesday1Date = '2026-10-14';
    const monday2Date = '2026-10-19';
    const tuesday2Date = '2026-10-20';

    // Create 3 distinct session templates
    const pushSession = await workoutRepository.createSession({
      title: 'Alpha Push Strength',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest • Shoulders • Triceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      availabilityType: 'INDIVIDUAL',
      recurringSchedule: 'Weekly on Monday',
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
        {
          exerciseId: 'ex_incline_dumbbell',
          exerciseName: 'Incline Dumbbell Press',
          category: 'Chest',
          orderIndex: 1,
          numberOfSets: 3,
          targetReps: '10-12',
          targetWeight: 30,
          restSeconds: 90,
          setType: 'Working',
        },
      ],
    });

    const pullSession = await workoutRepository.createSession({
      title: 'Alpha Pull Hypertrophy',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Back • Biceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 55,
      availabilityType: 'INDIVIDUAL',
      recurringSchedule: 'Weekly on Tuesday',
      createdById: testAdminId,
      exercises: [
        {
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Wide-Grip Lat Pulldown',
          category: 'Back',
          orderIndex: 0,
          numberOfSets: 3,
          targetReps: '10-12',
          targetWeight: 65,
          restSeconds: 90,
          setType: 'Working',
        },
        {
          exerciseId: 'ex_barbell_row',
          exerciseName: 'Bent-Over Barbell Row',
          category: 'Back',
          orderIndex: 1,
          numberOfSets: 3,
          targetReps: '8-10',
          targetWeight: 75,
          restSeconds: 90,
          setType: 'Working',
        },
      ],
    });

    const legsSession = await workoutRepository.createSession({
      title: 'Alpha Legs Dominance',
      workoutType: 'Strength',
      targetMuscleGroup: 'Quads • Hamstrings • Calves',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 60,
      availabilityType: 'INDIVIDUAL',
      recurringSchedule: 'Weekly on Wednesday',
      createdById: testAdminId,
      exercises: [
        {
          exerciseId: 'ex_barbell_squat',
          exerciseName: 'Barbell Back Squat',
          category: 'Legs',
          orderIndex: 0,
          numberOfSets: 4,
          targetReps: '6-8',
          targetWeight: 110,
          restSeconds: 120,
          setType: 'Working',
        },
      ],
    });

    console.log(`✔ Created distinct sessions: Push (${pushSession.id}), Pull (${pullSession.id}), Legs (${legsSession.id})\n`);

    // Assign sessions to Client A:
    // Monday = Push (scheduledDate: monday1Date)
    // Tuesday = Pull (scheduledDate: tuesday1Date)
    // Wednesday = Legs (scheduledDate: wednesday1Date)
    const pushAssignments = await workoutService.assignSession({
      sessionId: pushSession.id,
      assignmentType: 'INDIVIDUAL',
      individualClientId: clientAId,
      isRecommended: false,
      scheduledDate: monday1Date,
      assignedById: testAdminId,
    });
    const pushAssignmentId = pushAssignments[0]?.id;

    const pullAssignments = await workoutService.assignSession({
      sessionId: pullSession.id,
      assignmentType: 'INDIVIDUAL',
      individualClientId: clientAId,
      isRecommended: false,
      scheduledDate: tuesday1Date,
      assignedById: testAdminId,
    });
    const pullAssignmentId = pullAssignments[0]?.id;

    const legsAssignments = await workoutService.assignSession({
      sessionId: legsSession.id,
      assignmentType: 'INDIVIDUAL',
      individualClientId: clientAId,
      isRecommended: false,
      scheduledDate: wednesday1Date,
      assignedById: testAdminId,
    });
    const legsAssignmentId = legsAssignments[0]?.id;

    console.log(`✔ Assigned split to Client A:`);
    console.log(`   - Monday (${monday1Date}): Push (Assign ID: ${pushAssignmentId})`);
    console.log(`   - Tuesday (${tuesday1Date}): Pull (Assign ID: ${pullAssignmentId})`);
    console.log(`   - Wednesday (${wednesday1Date}): Legs (Assign ID: ${legsAssignmentId})\n`);

    // =========================================================================
    // TEST 1: Admin assigns different workouts to different days;
    // Client sees ONLY today's workout.
    // =========================================================================
    console.log('--- TEST 1: Client sees ONLY today\'s workout according to admin schedule ---');
    // Simulate Tuesday Oct 13, 2026 10:00 AM IST (04:30 UTC)
    setDateProviderForTesting(() => new Date('2026-10-13T04:30:00Z'));
    console.log(`Current IST Date: ${getTodayISTDateString()}`);

    const tuesdaySessions = await workoutService.getClientSessions(clientAId);

    if (!tuesdaySessions.todaySession) {
      throw new Error('FAILED: Client must have a todaySession on Tuesday Oct 13!');
    }
    if (tuesdaySessions.todaySession.id !== pullSession.id) {
      throw new Error(`FAILED: Expected todaySession to be Pull (${pullSession.id}), but got "${tuesdaySessions.todaySession.id}" (${tuesdaySessions.todaySession.title})`);
    }
    if (tuesdaySessions.isRestDay) {
      throw new Error('FAILED: isRestDay must be false when a workout is scheduled for today!');
    }
    console.log(`   ✔ Client sees ONLY Tuesday's workout: "${tuesdaySessions.todaySession.title}"`);
    passedTests++;

    // =========================================================================
    // TEST 2: Exercises from separate sessions never appear in one session.
    // =========================================================================
    console.log('\n--- TEST 2: Exercise Isolation (Zero Contamination Across Sessions) ---');
    const todayExercises = tuesdaySessions.todaySession.exercises || [];
    const exerciseNames = todayExercises.map((e: any) => e.exerciseName);
    console.log(`   Today's Session Exercises: [${exerciseNames.join(', ')}]`);

    const hasBench = todayExercises.some((e: any) => e.exerciseId === 'ex_bench_press');
    const hasSquat = todayExercises.some((e: any) => e.exerciseId === 'ex_barbell_squat');
    const hasLatPulldown = todayExercises.some((e: any) => e.exerciseId === 'ex_lat_pulldown');

    if (hasBench || hasSquat) {
      throw new Error('FAILED: Push or Legs exercises bled into Tuesday\'s Pull session!');
    }
    if (!hasLatPulldown) {
      throw new Error('FAILED: Pull session exercises missing from Tuesday\'s session!');
    }
    console.log('   ✔ No exercise contamination: Bench and Squats never appear in Pull session.');
    passedTests++;

    // =========================================================================
    // TEST 3: Missing Monday leaves Monday pending on Tuesday and following week.
    // =========================================================================
    console.log('\n--- TEST 3: Missed Monday Workout Stays Pending Separately ---');
    const pendingOnTuesday = tuesdaySessions.pendingWorkouts;
    console.log(`   Pending workouts count on Tuesday: ${pendingOnTuesday.length}`);
    const mondayPending = pendingOnTuesday.find((p: any) => p.id === pushSession.id);

    if (!mondayPending) {
      throw new Error('FAILED: Incomplete Monday Push workout MUST appear in pendingWorkouts!');
    }
    if (mondayPending.scheduledDate !== monday1Date) {
      throw new Error(`FAILED: Expected pending workout scheduledDate to be ${monday1Date}, got ${mondayPending.scheduledDate}`);
    }
    console.log(`   ✔ Missed Monday session "${mondayPending.title}" is in pendingWorkouts with original date: ${mondayPending.scheduledDate}`);

    // Check following week: Move clock to next Thursday Oct 22, 2026
    setDateProviderForTesting(() => new Date('2026-10-22T04:30:00Z'));
    const nextWeekSessions = await workoutService.getClientSessions(clientAId);
    const mondayStillPending = nextWeekSessions.pendingWorkouts.find(
      (p: any) => p.id === pushSession.id && p.scheduledDate === monday1Date
    );
    if (!mondayStillPending) {
      throw new Error('FAILED: Incomplete workout from previous week MUST remain pending into subsequent weeks!');
    }
    console.log(`   ✔ On Oct 22 (following week), Oct 12 Monday workout is STILL preserved in pendingWorkouts!`);
    passedTests++;

    // Return to Tuesday Oct 13
    setDateProviderForTesting(() => new Date('2026-10-13T04:30:00Z'));

    // =========================================================================
    // TEST 4: Tuesday's workout remains independently accessible and completable.
    // =========================================================================
    console.log('\n--- TEST 4: Tuesday\'s Workout Remains Independently Accessible ---');
    if (tuesdaySessions.todaySession.isLocked) {
      throw new Error('FAILED: Tuesday workout should NOT be locked simply because Monday was missed!');
    }
    if (tuesdaySessions.todaySession.status !== 'ASSIGNED') {
      throw new Error(`FAILED: Tuesday session status should be ASSIGNED, got "${tuesdaySessions.todaySession.status}"`);
    }
    console.log('   ✔ Tuesday\'s workout is completely unlocked and accessible without any progression lock.');
    passedTests++;

    // =========================================================================
    // TEST 5: Completing Monday's pending workout does NOT complete Tuesday's workout.
    // =========================================================================
    console.log('\n--- TEST 5: Completing Pending Workout Does NOT Mark Today Complete ---');
    console.log('   Simulating completion of Monday\'s pending workout...');
    await workoutService.recordWorkout(clientAId, {
      sessionId: pushSession.id,
      assignmentId: pushAssignmentId,
      sessionTitle: pushSession.title,
      workoutType: pushSession.workoutType,
      scheduledDate: monday1Date,
      startedAt: new Date('2026-10-13T06:00:00Z').toISOString(),
      completedAt: new Date('2026-10-13T06:50:00Z').toISOString(),
      durationSeconds: 3000,
      totalVolume: 2400,
      completedSetsCount: 6,
      skippedSetsCount: 0,
      isCompleted: true,
      exerciseRecords: [
        {
          exerciseId: 'ex_bench_press',
          exerciseName: 'Barbell Flat Bench Press',
          orderIndex: 0,
          setRecords: [
            { setNumber: 1, setType: 'Working', actualWeight: 80, actualReps: 10, isCompleted: true },
          ],
        },
      ],
    });

    // Re-query client sessions on Tuesday Oct 13
    const afterMondayDone = await workoutService.getClientSessions(clientAId);

    // Monday should NO LONGER be pending
    const mondayInPendingNow = afterMondayDone.pendingWorkouts.find(
      (p: any) => p.id === pushSession.id && p.scheduledDate === monday1Date
    );
    if (mondayInPendingNow) {
      throw new Error('FAILED: Completed Monday workout must be removed from pendingWorkouts!');
    }

    // Tuesday (today) MUST still be unlocked and ASSIGNED
    if (!afterMondayDone.todaySession) {
      throw new Error('FAILED: Tuesday todaySession disappeared after completing pending workout!');
    }
    if (afterMondayDone.todaySession.id !== pullSession.id) {
      throw new Error('FAILED: Tuesday todaySession mutated after completing pending workout!');
    }
    if (afterMondayDone.todaySession.isLocked) {
      throw new Error('FAILED: Completing Monday pending workout erroneously marked Tuesday\'s workout locked/completed!');
    }
    if (afterMondayDone.todaySession.status !== 'ASSIGNED') {
      throw new Error(`FAILED: Tuesday session status should remain ASSIGNED, got "${afterMondayDone.todaySession.status}"`);
    }
    console.log('   ✔ Monday pending workout marked COMPLETED; Tuesday todaySession remains intact, ASSIGNED, and UNLOCKED.');
    passedTests++;

    // =========================================================================
    // TEST 6: New week creates correct scheduled occurrences without overwriting history.
    // =========================================================================
    console.log('\n--- TEST 6: New Week Scheduled Occurrences Preserve History ---');
    // Move clock to next Monday Oct 19, 2026
    setDateProviderForTesting(() => new Date('2026-10-19T04:30:00Z'));
    console.log(`Current IST Date: ${getTodayISTDateString()}`);

    const oct19Sessions = await workoutService.getClientSessions(clientAId);
    if (!oct19Sessions.todaySession) {
      throw new Error('FAILED: Next Monday Oct 19 must have todaySession scheduled!');
    }
    if (oct19Sessions.todaySession.id !== pushSession.id) {
      throw new Error(`FAILED: Expected Push session on next Monday Oct 19, got "${oct19Sessions.todaySession.id}"`);
    }
    if (oct19Sessions.todaySession.isLocked) {
      throw new Error('FAILED: Next week\'s Monday occurrence should NOT inherit last week\'s locked status!');
    }
    if (oct19Sessions.todaySession.status !== 'ASSIGNED') {
      throw new Error(`FAILED: Next week\'s fresh occurrence should be ASSIGNED, got "${oct19Sessions.todaySession.status}"`);
    }

    // Verify history still has Monday Oct 12 completion
    const clientHistory = await prisma.workoutRecord.findMany({
      where: {
        clientId: clientAUser.id,
        sessionId: pushSession.id,
      },
    });
    const oct12Record = clientHistory.find((r) => r.scheduledDate === monday1Date);
    if (!oct12Record || !oct12Record.isCompleted) {
      throw new Error('FAILED: Historical completion for Oct 12 was lost or overwritten!');
    }
    console.log(`   ✔ New occurrence on Oct 19 is fresh and ASSIGNED; Oct 12 record preserved in DB history.`);
    passedTests++;

    // =========================================================================
    // TEST 7: Completed workouts cannot be accidentally duplicated.
    // =========================================================================
    console.log('\n--- TEST 7: Duplicate Completion Prevention ---');
    let duplicateRejected = false;
    try {
      await workoutRepository.saveWorkoutRecord(clientAId, {
        sessionId: pushSession.id,
        assignmentId: pushAssignmentId,
        sessionTitle: pushSession.title,
        workoutType: pushSession.workoutType,
        scheduledDate: monday1Date,
        durationSeconds: 3000,
        totalVolume: 2400,
        completedSetsCount: 6,
        skippedSetsCount: 0,
        isCompleted: true,
        startedAt: new Date('2026-10-12T06:00:00Z').toISOString(),
        completedAt: new Date('2026-10-12T06:50:00Z').toISOString(),
        personalRecords: [],
        exerciseRecords: [],
      });
    } catch (err: any) {
      if (err.message && err.message.includes('SESSION_LOCKED')) {
        duplicateRejected = true;
      }
    }
    if (!duplicateRejected) {
      throw new Error('FAILED: Attempt to re-save an already completed & locked workout must throw SESSION_LOCKED!');
    }
    console.log('   ✔ Duplicate save prevented: SESSION_LOCKED correctly thrown by repository.');
    passedTests++;

    // =========================================================================
    // TEST 8: App restart & re-login preserve today's workout & pending status.
    // =========================================================================
    console.log('\n--- TEST 8: Re-querying (Simulating App Restart/Re-login) Preserves State ---');
    const freshQuery1 = await workoutService.getClientSessions(clientAId);
    const freshQuery2 = await workoutService.getClientSessions(clientAId);

    if (freshQuery1.todaySession?.id !== freshQuery2.todaySession?.id ||
        freshQuery1.todaySession?.status !== freshQuery2.todaySession?.status ||
        freshQuery1.pendingWorkouts.length !== freshQuery2.pendingWorkouts.length) {
      throw new Error('FAILED: Consecutive queries produced different states!');
    }
    console.log('   ✔ Re-querying produces 100% idempotent, deterministic state.');
    passedTests++;

    // =========================================================================
    // TEST 9: Different clients' assignments and history remain isolated.
    // =========================================================================
    console.log('\n--- TEST 9: Strict Client Isolation (Client A vs Client B) ---');
    const clientBSessions = await workoutService.getClientSessions(clientBId);

    // Client B must NOT see Client A's assignments or pending workouts
    const bHasPush = clientBSessions.available.some((s) => s.id === pushSession.id);
    const bPendingCount = clientBSessions.pendingWorkouts.length;

    if (bHasPush) {
      throw new Error('FAILED: Client A\'s push session leaked into Client B\'s available sessions!');
    }
    if (bPendingCount > 0) {
      throw new Error('FAILED: Client A\'s pending workouts leaked to Client B!');
    }
    console.log('   ✔ Complete isolation: Client B sees zero sessions from Client A.');
    passedTests++;

    // =========================================================================
    // TEST 10: Existing set logging, exercise ordering, workout completion, analytics.
    // =========================================================================
    console.log('\n--- TEST 10: Set Logging, Exercise Ordering & Analytics Continuity ---');
    const todayTuesday = '2026-10-20';
    setDateProviderForTesting(() => new Date('2026-10-20T04:30:00Z'));

    const completedRecord = await workoutService.recordWorkout(clientAId, {
      sessionId: pullSession.id,
      assignmentId: pullAssignmentId,
      sessionTitle: pullSession.title,
      workoutType: pullSession.workoutType,
      scheduledDate: todayTuesday,
      startedAt: new Date('2026-10-20T04:30:00Z').toISOString(),
      completedAt: new Date('2026-10-20T05:25:00Z').toISOString(),
      durationSeconds: 3300,
      totalVolume: 3500,
      completedSetsCount: 4,
      skippedSetsCount: 0,
      averageRpe: 8.5,
      averageRir: 2,
      isCompleted: true,
      exerciseRecords: [
        {
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Wide-Grip Lat Pulldown',
          orderIndex: 0,
          setRecords: [
            { setNumber: 1, setType: 'Working', actualWeight: 65, actualReps: 12, actualRpe: 8, actualRir: 2, isCompleted: true },
            { setNumber: 2, setType: 'Working', actualWeight: 70, actualReps: 10, actualRpe: 9, actualRir: 1, isCompleted: true },
          ],
        },
        {
          exerciseId: 'ex_barbell_row',
          exerciseName: 'Bent-Over Barbell Row',
          orderIndex: 1,
          setRecords: [
            { setNumber: 1, setType: 'Working', actualWeight: 75, actualReps: 10, actualRpe: 8.5, actualRir: 2, isCompleted: true },
            { setNumber: 2, setType: 'Working', actualWeight: 80, actualReps: 8, actualRpe: 9.5, actualRir: 0, isCompleted: true },
          ],
        },
      ],
    });

    if (completedRecord.totalVolume !== 3500) {
      throw new Error(`FAILED: Expected volume 3500, got ${completedRecord.totalVolume}`);
    }
    if (completedRecord.completedSetsCount !== 4) {
      throw new Error(`FAILED: Expected 4 completed sets, got ${completedRecord.completedSetsCount}`);
    }
    if (completedRecord.exerciseRecords.length !== 2) {
      throw new Error(`FAILED: Expected 2 exercise records, got ${completedRecord.exerciseRecords.length}`);
    }
    if (completedRecord.exerciseRecords[0].orderIndex !== 0 || completedRecord.exerciseRecords[1].orderIndex !== 1) {
      throw new Error('FAILED: Exercise orderIndex was not preserved!');
    }

    // Verify session is now locked on todayTuesday
    const recheckedTuesday = await workoutService.getClientSessions(clientAId);
    if (!recheckedTuesday.todaySession || !recheckedTuesday.todaySession.isLocked) {
      throw new Error('FAILED: Completed todaySession must be locked!');
    }
    if (recheckedTuesday.todaySession.status !== 'COMPLETED') {
      throw new Error(`FAILED: Completed todaySession status must be COMPLETED, got "${recheckedTuesday.todaySession.status}"`);
    }
    console.log('   ✔ Set logging, ordering, volume tracking, and locked completion state verified 100%');
    passedTests++;

    console.log('\n======================================================================');
    console.log(`🎉 ALL ${passedTests}/${totalTests} REGRESSION TESTS PASSED (100% SUCCESS)`);
    console.log('======================================================================\n');
  } finally {
    setDateProviderForTesting(null);
  }
}

runDailyScheduleAndPendingRegressionTests().catch((err) => {
  setDateProviderForTesting(null);
  console.error('\n❌ REGRESSION TEST FAILED:', err);
  process.exit(1);
});
