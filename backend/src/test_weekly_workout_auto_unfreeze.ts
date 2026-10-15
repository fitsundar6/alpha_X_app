import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';
import { setDateProviderForTesting, getTodayISTDateString } from './utils/istDate';
import { prisma } from './config/prisma';

async function runWeeklyUnfreezeE2ETest() {
  console.log('========================================================================');
  console.log('⚡ [ALPHA X GYM] WEEKLY WORKOUT AUTO-UNFREEZE SYSTEM E2E AUDIT & TESTS');
  console.log('========================================================================\n');

  try {
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

    // Dates for test:
    // Monday 1: 2026-10-12
    // Tuesday:  2026-10-13
    // Monday 2: 2026-10-19
    const monday1Date = '2026-10-12';
    const tuesdayDate = '2026-10-13';
    const monday2Date = '2026-10-19';

    console.log(`Test Client: ${testClientId} (${clientUser.name})`);
    console.log(`Test Admin: ${testAdminId}\n`);

    // =========================================================================
    // STEP 1: CREATE RECURRING CHEST DAY WORKOUT TEMPLATE (MONDAYS)
    // =========================================================================
    console.log('--- Step 1: Create Workout Template (Every Monday) ---');
    const chestSession = await workoutRepository.createSession({
      title: 'Alpha Pure Chest Hypertrophy',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest • Triceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      availabilityType: 'INDIVIDUAL',
      recurringSchedule: 'Monday',
      createdById: testAdminId,
      exercises: [
        {
          exerciseId: 'ex_incline_smith_bench',
          exerciseName: 'Incline Smith Press',
          category: 'Chest',
          orderIndex: 0,
          numberOfSets: 3,
          targetReps: '8-10',
          targetWeight: 80,
          restSeconds: 90,
          setType: 'Working',
        },
        {
          exerciseId: 'ex_cable_crossover',
          exerciseName: 'Standing Cable Fly',
          category: 'Chest',
          orderIndex: 1,
          numberOfSets: 3,
          targetReps: '12-15',
          targetWeight: 25,
          restSeconds: 60,
          setType: 'Working',
        },
      ],
    });
    console.log(`✔ Created Session Template: "${chestSession.title}" (${chestSession.id})`);
    console.log(`  Recurring Schedule: ${chestSession.recurringSchedule}\n`);

    // Assign Chest Day to client starting on Monday Oct 12
    const assignments = await workoutService.assignSession({
      sessionId: chestSession.id,
      assignmentType: 'INDIVIDUAL',
      individualClientId: testClientId,
      isRecommended: true,
      scheduledDate: monday1Date,
      assignedById: testAdminId,
    });
    const assignmentId = assignments[0]?.id;
    console.log(`✔ Assigned to Client ${testClientId} with scheduled start ${monday1Date}. Assignment ID: ${assignmentId}\n`);

    // =========================================================================
    // STEP 2: SIMULATE MONDAY, OCT 12 - CLIENT COMPLETES AND LOCKS WORKOUT
    // =========================================================================
    console.log('--- Step 2: Monday Oct 12, 2026 - Initial Occurrence ---');
    // Set clock to Monday, Oct 12, 2026 10:00 AM IST (04:30 UTC)
    setDateProviderForTesting(() => new Date('2026-10-12T04:30:00Z'));
    console.log(`Current IST Date: ${getTodayISTDateString()}`);

    // Verify session is authorized and unlocked for Monday Oct 12
    const oct12SessionsBefore = await workoutService.getClientSessions(testClientId);
    const oct12Chest = oct12SessionsBefore.available.find((s) => s.id === chestSession.id);
    if (!oct12Chest) {
      throw new Error('FAILED: Chest session should be available on Monday Oct 12!');
    }
    if (oct12Chest.isLocked) {
      throw new Error('FAILED: Fresh Chest session should NOT be locked before completion!');
    }
    console.log(`✔ Oct 12 Chest session available & unlocked (isLocked: ${oct12Chest.isLocked}, status: ${oct12Chest.status})`);

    // Client completes and saves workout on Oct 12
    console.log('Saving completed workout on Oct 12...');
    const oct12Record = await workoutService.recordWorkout(testClientId, {
      sessionId: chestSession.id,
      assignmentId,
      sessionTitle: chestSession.title,
      workoutType: chestSession.workoutType,
      startedAt: new Date('2026-10-12T04:30:00Z').toISOString(),
      completedAt: new Date('2026-10-12T05:20:00Z').toISOString(),
      durationSeconds: 3000,
      totalVolume: 3150,
      completedSetsCount: 6,
      skippedSetsCount: 0,
      isCompleted: true,
      scheduledDate: monday1Date,
      exerciseRecords: [
        {
          exerciseId: 'ex_incline_smith_bench',
          exerciseName: 'Incline Smith Press',
          orderIndex: 0,
          setRecords: [
            { setNumber: 1, setType: 'WORKING', actualWeight: 80, actualReps: 10, isCompleted: true },
            { setNumber: 2, setType: 'WORKING', actualWeight: 80, actualReps: 9, isCompleted: true },
            { setNumber: 3, setType: 'WORKING', actualWeight: 80, actualReps: 8, isCompleted: true },
          ],
        },
        {
          exerciseId: 'ex_cable_crossover',
          exerciseName: 'Standing Cable Fly',
          orderIndex: 1,
          setRecords: [
            { setNumber: 1, setType: 'WORKING', actualWeight: 25, actualReps: 15, isCompleted: true },
            { setNumber: 2, setType: 'WORKING', actualWeight: 25, actualReps: 14, isCompleted: true },
            { setNumber: 3, setType: 'WORKING', actualWeight: 25, actualReps: 12, isCompleted: true },
          ],
        },
      ],
    });
    console.log(`✔ Oct 12 Record Saved. Record ID: ${oct12Record.id}, isLocked: ${oct12Record.isLocked}`);
    if (!oct12Record.isLocked) {
      throw new Error('FAILED: Saved workout record must be marked isLocked: true!');
    }

    // =========================================================================
    // STEP 3: VERIFY WORKOUT REMAINS LOCKED ON REOPENING ON SAME MONDAY
    // =========================================================================
    console.log('\n--- Step 3: Reopen App on Same Monday (Oct 12) ---');
    const oct12SessionsAfter = await workoutService.getClientSessions(testClientId);
    const oct12ChestAfter = oct12SessionsAfter.available.find((s) => s.id === chestSession.id);
    if (!oct12ChestAfter) {
      throw new Error('FAILED: Chest session should still be listed on Oct 12 as completed/locked!');
    }
    if (!oct12ChestAfter.isLocked || oct12ChestAfter.status !== 'COMPLETED') {
      throw new Error(`FAILED: Chest session must be locked today! Found isLocked: ${oct12ChestAfter.isLocked}, status: ${oct12ChestAfter.status}`);
    }
    console.log(`✔ PASSED: Reopening on Oct 12 correctly shows Chest as LOCKED & COMPLETED (isLocked: true, status: COMPLETED)`);

    // Verify modifications on locked session are rejected server-side
    let editRejected = false;
    try {
      await workoutRepository.saveSetCompletion(testClientId, chestSession.id, {
        exerciseId: 'ex_incline_smith_bench',
        setNumber: 1,
        isCompleted: true,
        actualWeight: 85,
        actualReps: 10,
        scheduledDate: monday1Date,
      });
    } catch (err: any) {
      if (err.message && err.message.includes('SESSION_LOCKED')) {
        editRejected = true;
        console.log(`✔ PASSED: Set edit correctly rejected on locked Oct 12 session: "${err.message}"`);
      }
    }
    if (!editRejected) {
      throw new Error('FAILED: Modification on completed Oct 12 session should have been rejected!');
    }

    // =========================================================================
    // STEP 4: SIMULATE TUESDAY, OCT 13 - DIFFERENT SCHEDULED DAY
    // =========================================================================
    console.log('\n--- Step 4: Tuesday Oct 13, 2026 - Non-Scheduled Day for Chest ---');
    setDateProviderForTesting(() => new Date('2026-10-13T04:30:00Z'));
    console.log(`Current IST Date: ${getTodayISTDateString()}`);

    const tuesdaySessions = await workoutService.getClientSessions(testClientId);
    const hasChestOnTuesday = tuesdaySessions.available.some((s) => s.id === chestSession.id);
    if (hasChestOnTuesday) {
      throw new Error('FAILED: Chest Day (scheduled for Monday) must NOT appear on Tuesday Oct 13!');
    }
    console.log('✔ PASSED: Yesterday\'s completed Chest session is cleanly excluded on Tuesday! (Zero session pollution)');

    // =========================================================================
    // STEP 5: SIMULATE NEXT MONDAY, OCT 19 - AUTO-UNFREEZE & FRESH SESSION
    // =========================================================================
    console.log('\n--- Step 5: Next Monday Oct 19, 2026 - Weekly Auto-Unfreeze ---');
    setDateProviderForTesting(() => new Date('2026-10-19T04:30:00Z'));
    console.log(`Current IST Date: ${getTodayISTDateString()}`);

    const oct19Sessions = await workoutService.getClientSessions(testClientId);
    const oct19Chest = oct19Sessions.available.find((s) => s.id === chestSession.id);
    if (!oct19Chest) {
      throw new Error('FAILED: Chest Day MUST automatically appear on the next scheduled Monday (Oct 19)!');
    }
    if (oct19Chest.isLocked) {
      throw new Error(`FAILED: Chest Day on Oct 19 must be AUTOMATICALLY UNLOCKED, but found isLocked: ${oct19Chest.isLocked}!`);
    }
    if (oct19Chest.status === 'COMPLETED') {
      throw new Error(`FAILED: Oct 19 session status should be ASSIGNED, not COMPLETED! Found: ${oct19Chest.status}`);
    }
    console.log(`✔ PASSED: Weekly Auto-Unfreeze Success! Chest Day is automatically available & unlocked on Oct 19 (isLocked: ${oct19Chest.isLocked}, status: ${oct19Chest.status})`);

    // Verify fresh sets state (all sets clean / not completed)
    for (const ex of oct19Chest.exercises) {
      for (const s of ex.sets || []) {
        if (s.isCompleted) {
          throw new Error(`FAILED: Set ${s.setNumber} in ${ex.exerciseName} should NOT be marked completed for the new Oct 19 session!`);
        }
      }
    }
    console.log('✔ PASSED: Oct 19 session has fresh sets and reps completion state!');

    // Client logs sets for Oct 19 session
    console.log('Logging sets for new Oct 19 session...');
    const set1Result = await workoutRepository.saveSetCompletion(testClientId, chestSession.id, {
      exerciseId: 'ex_incline_smith_bench',
      setNumber: 1,
      isCompleted: true,
      actualWeight: 82.5,
      actualReps: 10,
      scheduledDate: monday2Date,
    });
    console.log(`✔ Set 1 logged on Oct 19: ${set1Result.actualWeight}kg x ${set1Result.actualReps} reps (isCompleted: ${set1Result.isCompleted})`);

    // Complete and save Oct 19 workout
    const oct19Record = await workoutService.recordWorkout(testClientId, {
      sessionId: chestSession.id,
      assignmentId,
      sessionTitle: chestSession.title,
      workoutType: chestSession.workoutType,
      startedAt: new Date('2026-10-19T04:30:00Z').toISOString(),
      completedAt: new Date('2026-10-19T05:25:00Z').toISOString(),
      durationSeconds: 3300,
      totalVolume: 3300,
      completedSetsCount: 6,
      skippedSetsCount: 0,
      isCompleted: true,
      scheduledDate: monday2Date,
      exerciseRecords: [
        {
          exerciseId: 'ex_incline_smith_bench',
          exerciseName: 'Incline Smith Press',
          orderIndex: 0,
          setRecords: [
            { setNumber: 1, setType: 'WORKING', actualWeight: 82.5, actualReps: 10, isCompleted: true },
            { setNumber: 2, setType: 'WORKING', actualWeight: 82.5, actualReps: 9, isCompleted: true },
            { setNumber: 3, setType: 'WORKING', actualWeight: 82.5, actualReps: 8, isCompleted: true },
          ],
        },
      ],
    });
    console.log(`✔ Oct 19 Record Saved. Record ID: ${oct19Record.id}, isLocked: ${oct19Record.isLocked}`);

    // =========================================================================
    // STEP 6: VERIFY HISTORICAL RECORD INTEGRITY (OCT 12 UNCHANGED)
    // =========================================================================
    console.log('\n--- Step 6: Verify Historical Workout Records Integrity ---');
    const history = await workoutService.getClientHistory(testClientId);
    console.log(`Total history records for client: ${history.length}`);

    const recOct12 = history.find((h) => h.id === oct12Record.id);
    const recOct19 = history.find((h) => h.id === oct19Record.id);

    if (!recOct12) {
      throw new Error('FAILED: Oct 12 workout record was lost or overwritten!');
    }
    if (!recOct19) {
      throw new Error('FAILED: Oct 19 workout record was not saved!');
    }

    if (recOct12.scheduledDate !== monday1Date || recOct12.totalVolume !== 3150) {
      throw new Error(`FAILED: Historical Oct 12 record was corrupted! Volume: ${recOct12.totalVolume}, Date: ${recOct12.scheduledDate}`);
    }
    if (recOct19.scheduledDate !== monday2Date || recOct19.totalVolume !== 3300) {
      throw new Error(`FAILED: Oct 19 record has incorrect data! Volume: ${recOct19.totalVolume}, Date: ${recOct19.scheduledDate}`);
    }
    console.log('✔ PASSED: Oct 12 record and Oct 19 record exist independently with correct sets, volumes, and dates! No historical data overwritten.');

    // =========================================================================
    // STEP 7: RACE CONDITION & CONCURRENT SAVE PROTECTION TEST
    // =========================================================================
    console.log('\n--- Step 7: Race Condition / Concurrent Save Protection ---');
    const testDate = '2026-10-26'; // Simulating next Monday
    setDateProviderForTesting(() => new Date('2026-10-26T04:30:00Z'));

    const concurrentData = {
      sessionId: chestSession.id,
      assignmentId,
      sessionTitle: chestSession.title,
      workoutType: chestSession.workoutType,
      startedAt: new Date('2026-10-26T04:30:00Z').toISOString(),
      completedAt: new Date('2026-10-26T05:20:00Z').toISOString(),
      durationSeconds: 3000,
      totalVolume: 3200,
      completedSetsCount: 3,
      skippedSetsCount: 0,
      isCompleted: true,
      scheduledDate: testDate,
      personalRecords: [],
      exerciseRecords: [],
    };

    // Fire 2 concurrent saves at the exact same millisecond
    console.log('Dispatching 2 simultaneous saves for the same client, session, and date...');
    const [res1, res2] = await Promise.allSettled([
      workoutRepository.saveWorkoutRecord(testClientId, concurrentData),
      workoutRepository.saveWorkoutRecord(testClientId, concurrentData),
    ]);

    const successes = [res1, res2].filter((r) => r.status === 'fulfilled');
    console.log(`Concurrent save responses: ${successes.length} resolved successfully`);
    if (successes.length < 1) {
      throw new Error('FAILED: At least one save must succeed during concurrent requests!');
    }

    // Verify only ONE record was created in PostgreSQL for testDate
    const dbRecordsCount = await prisma.workoutRecord.count({
      where: {
        clientId: clientUser.id,
        sessionId: chestSession.id,
        scheduledDate: testDate,
      },
    });
    console.log(`Total database records created for ${testDate}: ${dbRecordsCount}`);
    if (dbRecordsCount !== 1) {
      throw new Error(`FAILED: Exactly 1 record must be created, but found ${dbRecordsCount}! Duplicate records created!`);
    }
    console.log('✔ PASSED: Race condition prevented! Zero duplicate records created in PostgreSQL.');

    console.log('\n========================================================================');
    console.log('🎉 ALL WEEKLY AUTO-UNFREEZE AND LOCK SYSTEM TESTS PASSED CLEANLY!');
    console.log('========================================================================\n');
  } finally {
    // Restore real system time provider
    setDateProviderForTesting(null);
  }
}

runWeeklyUnfreezeE2ETest().catch((err) => {
  setDateProviderForTesting(null);
  console.error('❌ Weekly Unfreeze E2E Test Failed:', err);
  process.exit(1);
});
