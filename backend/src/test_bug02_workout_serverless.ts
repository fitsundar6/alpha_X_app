/**
 * BUG-02: Workout Serverless Persistence & Concurrency Regression Test Suite
 *
 * Verifies:
 * 1. Split created on Instance A is readable on Instance B (PostgreSQL shared persistence).
 * 2. Split data survives repository memory clearing / cold start reinitialization.
 * 3. Two simultaneous completion requests create exactly ONE logical completed workout (idempotency).
 * 4. Legitimate separate workouts (different sessions or different dates) remain separate.
 * 5. In-progress sets survive repository reinitialization and are read from PostgreSQL.
 * 6. Database failures fail safely (never silently reporting success on saveSetCompletion).
 * 7. Workout assignment, completion, unlock and client history flows remain fully operational.
 */

import { prisma } from './config/prisma';
import { workoutRepository, WorkoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';

async function runBug02Suite() {
  console.log('================================================================');
  console.log('TEST SUITE: BUG-02 WORKOUT SERVERLESS PERSISTENCE & CONCURRENCY');
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

  // Preserve original prisma methods
  const originalUserFindUnique = prisma.user.findUnique;
  const originalUserFindFirst = prisma.user.findFirst;
  const originalProfileFindUnique = prisma.clientProfile.findUnique;
  const originalSplitUpsert = (prisma as any).workoutSplitPlan?.upsert;
  const originalSplitFindUnique = (prisma as any).workoutSplitPlan?.findUnique;
  const originalSplitFindFirst = (prisma as any).workoutSplitPlan?.findFirst;
  const originalSplitUpdate = (prisma as any).workoutSplitPlan?.update;
  const originalRecordCreate = prisma.workoutRecord.create;
  const originalRecordFindFirst = prisma.workoutRecord.findFirst;
  const originalRecordFindMany = prisma.workoutRecord.findMany;
  const originalRecordUpdate = prisma.workoutRecord.update;
  const originalRecordDeleteMany = prisma.workoutRecord.deleteMany;
  const originalAssignmentFindMany = prisma.workoutAssignment.findMany;
  const originalAssignmentFindFirst = prisma.workoutAssignment.findFirst;
  const originalAssignmentCreate = prisma.workoutAssignment.create;
  const originalAssignmentUpdateMany = prisma.workoutAssignment.updateMany;
  const originalOverrideFindFirst = prisma.clientSessionOverride.findFirst;
  const originalRecordUpdateMany = prisma.workoutRecord.updateMany;
  const originalSessionFindUnique = prisma.workoutSession.findUnique;
  const originalSessionFindFirst = prisma.workoutSession.findFirst;
  const originalSessionCreate = prisma.workoutSession.create;
  const originalSessionExerciseCreate = prisma.workoutSessionExercise.create;
  const originalSetTemplateCreate = (prisma as any).workoutSetTemplate?.create;
  const originalExCreate = prisma.workoutExerciseRecord.create;
  const originalSetCreate = prisma.workoutSetRecord.create;
  const originalSetUpdate = prisma.workoutSetRecord.update;
  const originalSetCount = prisma.workoutSetRecord.count;

  // Shared in-memory mock storage simulating PostgreSQL tables
  const dbSplitStore = new Map<string, any>();
  const dbRecordStore = new Map<string, any>();
  const dbAssignmentStore = new Map<string, any>();
  const dbSessionStore = new Map<string, any>();
  const dbExerciseRecordStore = new Map<string, any>();
  const dbSetRecordStore = new Map<string, any>();

  const clientId = 'client-uuid-001';
  const clientId2 = 'client-uuid-002';
  const adminId = 'admin-uuid-001';

  try {
    // ── Setup Mock Database Handlers ──────────────────────────────────────────
    (prisma.user.findUnique as any) = async ({ where }: any) => {
      if (where.id === clientId || where.email === 'athlete@alphax.test') {
        return { id: clientId, email: 'athlete@alphax.test', name: 'Test Athlete', role: 'CLIENT' };
      }
      if (where.id === clientId2 || where.email === 'athlete2@alphax.test') {
        return { id: clientId2, email: 'athlete2@alphax.test', name: 'Test Athlete 2', role: 'CLIENT' };
      }
      if (where.id === adminId) {
        return { id: adminId, email: 'admin@alphaxgym.com', name: 'Master Admin', role: 'ADMIN' };
      }
      return null;
    };
    (prisma.user.findFirst as any) = (prisma.user.findUnique as any);
    (prisma.clientProfile.findUnique as any) = async ({ where }: any) => {
      if (where.userId === clientId || where.clientId === 'AXG-0001') {
        return { id: 'profile-001', userId: clientId, clientId: 'AXG-0001' };
      }
      return null;
    };

    // WorkoutSplitPlan Mock Handlers
    (prisma as any).workoutSplitPlan = {
      upsert: async ({ where, create, update }: any) => {
        const id = where.id;
        const existing = dbSplitStore.get(id);
        const record = existing ? { ...existing, ...update } : { id, ...create, createdAt: new Date(), updatedAt: new Date() };
        dbSplitStore.set(id, record);
        return record;
      },
      findUnique: async ({ where }: any) => {
        return dbSplitStore.get(where.id) || null;
      },
      findFirst: async ({ where }: any) => {
        for (const plan of dbSplitStore.values()) {
          if (where?.OR) {
            for (const cond of where.OR) {
              if (cond.clientId && plan.clientId === cond.clientId) return plan;
            }
          }
          if (where?.clientId && plan.clientId === where.clientId) return plan;
        }
        return null;
      },
      update: async ({ where, data }: any) => {
        const existing = dbSplitStore.get(where.id);
        if (!existing) throw new Error('Record not found');
        const updated = { ...existing, ...data, updatedAt: new Date() };
        dbSplitStore.set(where.id, updated);
        return updated;
      },
    };

    // WorkoutRecord Mock Handlers
    (prisma.workoutRecord.create as any) = async ({ data, include }: any) => {
      // Enforce database unique constraint on idempotencyKey
      if (data.idempotencyKey) {
        for (const existing of dbRecordStore.values()) {
          if (existing.idempotencyKey === data.idempotencyKey) {
            const p2002Err: any = new Error('Unique constraint failed on the constraint: workout_records_idempotencyKey_key');
            p2002Err.code = 'P2002';
            throw p2002Err;
          }
        }
      }

      const id = data.id || `rec-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`;
      const exRecords: any[] = [];
      if (data.exerciseRecords?.create) {
        for (let i = 0; i < data.exerciseRecords.create.length; i++) {
          const erData = data.exerciseRecords.create[i];
          const erId = `er-${id}-${i + 1}`;
          const setRecords: any[] = [];
          if (erData.setRecords?.create) {
            for (let s = 0; s < erData.setRecords.create.length; s++) {
              const srData = erData.setRecords.create[s];
              const srId = `sr-${erId}-${s + 1}`;
              const srRecord = { id: srId, exerciseRecordId: erId, ...srData };
              dbSetRecordStore.set(srId, srRecord);
              setRecords.push(srRecord);
            }
          }
          const erRecord = { id: erId, recordId: id, ...erData, setRecords };
          dbExerciseRecordStore.set(erId, erRecord);
          exRecords.push(erRecord);
        }
      }
      const record = { id, ...data, exerciseRecords: exRecords };
      dbRecordStore.set(id, record);
      return record;
    };

    (prisma.workoutRecord.findFirst as any) = async ({ where, include }: any) => {
      for (const r of dbRecordStore.values()) {
        let match = true;
        if (where?.idempotencyKey && r.idempotencyKey !== where.idempotencyKey) match = false;
        if (where?.clientId && r.clientId !== where.clientId) match = false;
        if (where?.sessionId && where.sessionId.in && !where.sessionId.in.includes(r.sessionId)) match = false;
        if (where?.scheduledDate && r.scheduledDate !== where.scheduledDate) match = false;
        if (where?.assignmentId && r.assignmentId !== where.assignmentId) match = false;
        if (where?.isCompleted !== undefined && r.isCompleted !== where.isCompleted) match = false;

        if (match) {
          const res = { ...r };
          if (include?.exerciseRecords) {
            res.exerciseRecords = Array.from(dbExerciseRecordStore.values())
              .filter((er) => er.recordId === r.id)
              .map((er) => ({
                ...er,
                setRecords: Array.from(dbSetRecordStore.values()).filter((sr) => sr.exerciseRecordId === er.id),
              }));
          }
          return res;
        }
      }
      return null;
    };

    (prisma.workoutRecord.findMany as any) = async ({ where }: any) => {
      return Array.from(dbRecordStore.values()).filter((r) => {
        if (where?.clientId && r.clientId !== where.clientId) return false;
        if (where?.isCompleted !== undefined && r.isCompleted !== where.isCompleted) return false;
        return true;
      });
    };

    (prisma.workoutRecord.update as any) = async ({ where, data }: any) => {
      const existing = dbRecordStore.get(where.id);
      if (!existing) return null;
      const updated = { ...existing, ...data };
      dbRecordStore.set(where.id, updated);
      return updated;
    };

    (prisma.workoutRecord.deleteMany as any) = async ({ where }: any) => {
      let count = 0;
      for (const [id, r] of dbRecordStore.entries()) {
        if (where?.clientId && r.clientId === where.clientId && where?.isCompleted === false && r.isCompleted === false) {
          dbRecordStore.delete(id);
          count++;
        }
      }
      return { count };
    };

    (prisma.workoutAssignment.findMany as any) = async ({ where }: any) => {
      return Array.from(dbAssignmentStore.values()).filter((a) => {
        if (where?.clientId && a.clientId !== where.clientId) return false;
        if (where?.active !== undefined && a.active !== where.active) return false;
        return true;
      });
    };
    (prisma.workoutAssignment.create as any) = async ({ data }: any) => {
      const id = data.id || `assign-${Date.now()}-${Math.random()}`;
      const record = { id, ...data };
      dbAssignmentStore.set(id, record);
      return record;
    };
    (prisma.clientSessionOverride.findFirst as any) = async () => null;
    (prisma.workoutRecord.updateMany as any) = async () => ({ count: 1 });
    (prisma.workoutAssignment.findFirst as any) = async () => null;
    (prisma.workoutAssignment.updateMany as any) = async ({ where, data }: any) => {
      let count = 0;
      for (const [id, a] of dbAssignmentStore.entries()) {
        if (where?.id && a.id === where.id) {
          dbAssignmentStore.set(id, { ...a, ...data });
          count++;
        }
      }
      return { count };
    };

    (prisma.workoutSession.findUnique as any) = async ({ where }: any) => dbSessionStore.get(where.id) || null;
    (prisma.workoutSession.findFirst as any) = async () => Array.from(dbSessionStore.values())[0] || null;
    (prisma.workoutSession.create as any) = async ({ data }: any) => {
      const id = data.id || `ws-${Date.now()}`;
      const record = { id, ...data };
      dbSessionStore.set(id, record);
      return record;
    };
    (prisma.workoutSessionExercise.create as any) = async ({ data }: any) => ({
      id: data.id || `wse-${Date.now()}-${Math.random()}`,
      ...data,
    });
    (prisma as any).workoutSetTemplate = {
      create: async ({ data }: any) => ({ id: data.id || `wst-${Date.now()}`, ...data }),
    };

    (prisma.workoutExerciseRecord.create as any) = async ({ data }: any) => {
      const id = data.id || `er-${Date.now()}-${Math.random()}`;
      const record = { id, ...data, setRecords: [] };
      dbExerciseRecordStore.set(id, record);
      return record;
    };

    (prisma.workoutSetRecord.create as any) = async ({ data }: any) => {
      const id = data.id || `sr-${Date.now()}-${Math.random()}`;
      const record = { id, ...data };
      dbSetRecordStore.set(id, record);
      return record;
    };

    (prisma.workoutSetRecord.update as any) = async ({ where, data }: any) => {
      const existing = dbSetRecordStore.get(where.id);
      if (!existing) return null;
      const updated = { ...existing, ...data };
      dbSetRecordStore.set(where.id, updated);
      return updated;
    };

    (prisma.workoutSetRecord.count as any) = async ({ where }: any) => {
      let count = 0;
      for (const sr of dbSetRecordStore.values()) {
        if (where?.exerciseRecordId && sr.exerciseRecordId !== where.exerciseRecordId) continue;
        if (where?.isCompleted !== undefined && sr.isCompleted !== where.isCompleted) continue;
        count++;
      }
      return count;
    };

    // Seed a standard workout session in mock DB
    const testSessionId = 'ws_push_day_01';
    dbSessionStore.set(testSessionId, {
      id: testSessionId,
      title: 'Upper Push Hypertrophy',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest • Delts',
      estimatedDurationMinutes: 50,
      difficulty: 'Intermediate',
      isActive: true,
      exercises: [
        {
          id: 'ex-01',
          sessionId: testSessionId,
          exerciseId: 'incline-bench',
          exerciseName: 'Incline Dumbbell Press',
          orderIndex: 0,
          numberOfSets: 3,
          sets: [
            { id: 's1', setNumber: 1, setType: 'Working', targetReps: '10' },
            { id: 's2', setNumber: 2, setType: 'Working', targetReps: '10' },
            { id: 's3', setNumber: 3, setType: 'Working', targetReps: '10' },
          ],
        },
      ],
    });

    // -------------------------------------------------------------
    // TEST 1: Split created on Instance A is readable on Instance B
    // -------------------------------------------------------------
    console.log('\n[TEST 1] Multi-Instance Workout Split Plan Persistence:');
    const splitId = 'split-athlete-hypertrophy-4day';
    const splitData = {
      id: splitId,
      title: 'Hypertrophy 4-Day Split',
      splitType: 'Upper/Lower',
      description: 'Progressive overload chest, back and leg focus',
      frequencyPerWeek: 4,
      clientId,
      days: [
        {
          dayOfWeek: 'Monday',
          dayIndex: 1,
          name: 'Upper Body A',
          workoutType: 'Strength',
          targetMuscleGroup: 'Chest • Back',
          estimatedDurationMinutes: 60,
          isRestDay: false,
          exercises: [{ exerciseId: 'incline-bench', exerciseName: 'Incline Press', numberOfSets: 3 }],
        },
        {
          dayOfWeek: 'Tuesday',
          dayIndex: 2,
          name: 'Lower Body A',
          workoutType: 'Strength',
          targetMuscleGroup: 'Quads • Calves',
          estimatedDurationMinutes: 55,
          isRestDay: false,
          exercises: [{ exerciseId: 'squat', exerciseName: 'Barbell Squat', numberOfSets: 3 }],
        },
        {
          dayOfWeek: 'Wednesday',
          dayIndex: 3,
          name: 'Rest Day',
          isRestDay: true,
          exercises: [],
        },
      ],
    };

    // Save on Instance A
    const savedSplit = await workoutRepository.saveWorkoutSplit(splitData, adminId);
    assertTest(
      'Instance A saves workout split plan and returns valid split object',
      savedSplit.id === splitId && savedSplit.title === 'Hypertrophy 4-Day Split'
    );
    assertTest(
      'Workout split plan is persisted into mock PostgreSQL store',
      dbSplitStore.has(splitId) && dbSplitStore.get(splitId).title === 'Hypertrophy 4-Day Split'
    );

    // Simulate Instance B (completely empty in-memory repository)
    const instanceB = new WorkoutRepository();
    const retrievedOnB = await instanceB.getWorkoutSplitById(splitId);
    assertTest(
      'Instance B (isolated memory) successfully queries and loads split plan from PostgreSQL',
      retrievedOnB !== null &&
        retrievedOnB.id === splitId &&
        retrievedOnB.title === 'Hypertrophy 4-Day Split' &&
        retrievedOnB.splitType === 'Upper/Lower' &&
        retrievedOnB.description === 'Progressive overload chest, back and leg focus'
    );

    // -------------------------------------------------------------
    // TEST 2: Split data survives repository memory wipe (cold start simulation)
    // -------------------------------------------------------------
    console.log('\n[TEST 2] Serverless Cold Start Simulation:');
    workoutRepository.clearMemoryForTesting();
    const postColdStartSplit = await workoutRepository.getWorkoutSplitById(splitId);
    assertTest(
      'Split plan survives repository clearMemoryForTesting (cold start resilience)',
      postColdStartSplit !== null && postColdStartSplit.id === splitId
    );

    // -------------------------------------------------------------
    // TEST 3: Assigned Workout Idempotency, Concurrency & Warm-Memory Integrity
    // -------------------------------------------------------------
    console.log('\n[TEST 3] Assigned Workout Idempotency, Concurrency & Memory Integrity:');
    const targetDate = '2026-11-06';
    const testAssignmentId = 'assign_recurring_push_01';
    const assignedPayload = {
      sessionId: testSessionId,
      assignmentId: testAssignmentId,
      sessionTitle: 'Upper Push Hypertrophy',
      workoutType: 'Strength',
      scheduledDate: targetDate,
      startedAt: new Date(Date.now() - 3600000).toISOString(),
      completedAt: new Date().toISOString(),
      durationSeconds: 3600,
      totalVolume: 4500,
      completedSetsCount: 3,
      skippedSetsCount: 0,
      isCompleted: true,
      personalRecords: [],
      exerciseRecords: [
        {
          exerciseId: 'incline-bench',
          exerciseName: 'Incline Dumbbell Press',
          orderIndex: 0,
          isSkipped: false,
          sets: [
            { setNumber: 1, setType: 'Working', actualWeight: 30, actualReps: 10, isCompleted: true },
            { setNumber: 2, setType: 'Working', actualWeight: 30, actualReps: 10, isCompleted: true },
            { setNumber: 3, setType: 'Working', actualWeight: 30, actualReps: 10, isCompleted: true },
          ],
        },
      ],
    };

    // 1. Concurrent duplicate requests = same canonical record
    const instance1 = new WorkoutRepository();
    const instance2 = new WorkoutRepository();

    const [record1, record2] = await Promise.all([
      instance1.saveWorkoutRecord(clientId, assignedPayload),
      instance2.saveWorkoutRecord(clientId, assignedPayload),
    ]);

    assertTest(
      'Both concurrent calls resolve successfully to a completed record',
      record1.isCompleted === true && record2.isCompleted === true
    );
    assertTest(
      'Both concurrent calls return the exact same canonical record ID (zero duplicates)',
      record1.id === record2.id
    );

    const matchingRecordsInDb = Array.from(dbRecordStore.values()).filter(
      (r) => r.clientId === clientId && r.assignmentId === testAssignmentId && r.scheduledDate === targetDate && r.isCompleted
    );
    assertTest(
      'Database contains exactly ONE completed workout record for this assigned date',
      matchingRecordsInDb.length === 1
    );

    // 2. P2002 failure does not leave ghost records in memory
    const instance2MemRecords = instance2.getMemoryRecordsForTesting();
    const instance2HasGhost = instance2MemRecords.some((r) => r.id !== record1.id);
    assertTest(
      'P2002 failure does not leave unpersisted ghost records in memory',
      instance2MemRecords.length === 1 && !instance2HasGhost && instance2MemRecords[0].id === record1.id
    );

    // 3. Same client + same assignment + same date = one record
    const sequentialDuplicate = await instance1.saveWorkoutRecord(clientId, assignedPayload);
    assertTest(
      'Same client + same assignment + same date sequentially returns existing canonical record',
      sequentialDuplicate.id === record1.id
    );

    // 4. Same client + same assignment + different dates = separate records
    const nextWeekDate = '2026-11-09';
    const nextDateRecord = await instance1.saveWorkoutRecord(clientId, {
      ...assignedPayload,
      scheduledDate: nextWeekDate,
    });
    assertTest(
      'Same client + same assignment + different dates creates distinct records',
      nextDateRecord.id !== record1.id && nextDateRecord.scheduledDate === nextWeekDate
    );
    const clientAssignedInDb = Array.from(dbRecordStore.values()).filter(
      (r) => r.clientId === clientId && r.assignmentId === testAssignmentId
    );
    assertTest(
      'PostgreSQL contains distinct records for different scheduled dates under same assignment',
      clientAssignedInDb.length === 2
    );

    // 5. Different clients + same global assignment + same date = separate records
    const globalAssignmentId = 'assign_push_a_all';
    const globalSessionId = 'ws_global_push_a';
    dbSessionStore.set(globalSessionId, { id: globalSessionId, title: 'Push A (All Clients)' });
    const globalPayloadClient1 = {
      ...assignedPayload,
      sessionId: globalSessionId,
      sessionTitle: 'Push A (All Clients)',
      assignmentId: globalAssignmentId,
      scheduledDate: targetDate,
    };
    const globalPayloadClient2 = {
      ...assignedPayload,
      sessionId: globalSessionId,
      sessionTitle: 'Push A (All Clients)',
      assignmentId: globalAssignmentId,
      scheduledDate: targetDate,
    };
    const client1GlobalRecord = await instance1.saveWorkoutRecord(clientId, globalPayloadClient1);
    const client2GlobalRecord = await instance1.saveWorkoutRecord(clientId2, globalPayloadClient2);
    assertTest(
      'Different clients + same global assignment + same date creates separate records',
      client1GlobalRecord.id !== client2GlobalRecord.id &&
      client1GlobalRecord.clientId === clientId &&
      client2GlobalRecord.clientId === clientId2
    );

    // -------------------------------------------------------------
    // TEST 4: Existing Unassigned Workout Behavior Correctness
    // -------------------------------------------------------------
    console.log('\n[TEST 4] Unassigned Ad-Hoc Workouts Correctness:');
    const adhocPayload = {
      sessionId: 'ws_adhoc_session_01',
      sessionTitle: 'Ad-Hoc Strength Workout',
      workoutType: 'Strength',
      scheduledDate: targetDate,
      startedAt: new Date(Date.now() - 3600000).toISOString(),
      completedAt: new Date().toISOString(),
      durationSeconds: 3600,
      totalVolume: 3000,
      completedSetsCount: 3,
      skippedSetsCount: 0,
      isCompleted: true,
      personalRecords: [],
      exerciseRecords: assignedPayload.exerciseRecords,
    };
    const adhocRecord1 = await workoutRepository.saveWorkoutRecord(clientId, adhocPayload);
    const adhocRecord2 = await workoutRepository.saveWorkoutRecord(clientId, adhocPayload);
    assertTest(
      'Unassigned workout with same sessionId and date returns canonical record (idempotency)',
      adhocRecord1.id === adhocRecord2.id
    );

    const nextDayDate = '2026-11-07';
    const adhocNextDay = await workoutRepository.saveWorkoutRecord(clientId, {
      ...adhocPayload,
      scheduledDate: nextDayDate,
    });
    assertTest(
      'Unassigned workout on different scheduledDate creates distinct record',
      adhocNextDay.id !== adhocRecord1.id && adhocNextDay.scheduledDate === nextDayDate
    );

    const cardioSessionId = 'ws_cardio_hiit_01';
    dbSessionStore.set(cardioSessionId, { id: cardioSessionId, title: 'Cardio HIIT' });
    const cardioRecord = await workoutRepository.saveWorkoutRecord(clientId, {
      ...adhocPayload,
      sessionId: cardioSessionId,
      sessionTitle: 'Cardio HIIT',
      workoutType: 'Cardio',
      scheduledDate: targetDate,
    });
    assertTest(
      'Different unassigned workout session on same scheduledDate creates distinct record',
      cardioRecord.id !== adhocRecord1.id && cardioRecord.sessionId === cardioSessionId
    );

    // -------------------------------------------------------------
    // TEST 5: Durable In-Progress Sets survive memory clearing
    // -------------------------------------------------------------
    console.log('\n[TEST 5] Durable In-Progress Set Tracking:');
    const inProgressSessionId = 'ws_pull_hypertrophy_02';
    dbSessionStore.set(inProgressSessionId, {
      id: inProgressSessionId,
      title: 'Pull Hypertrophy',
      workoutType: 'Strength',
      exercises: [
        {
          id: 'ex-pull-01',
          sessionId: inProgressSessionId,
          exerciseId: 'lat-pulldown',
          exerciseName: 'Lat Pulldown',
          numberOfSets: 3,
        },
      ],
    });

    // Save set 1
    await workoutRepository.saveSetCompletion(clientId, inProgressSessionId, {
      exerciseId: 'lat-pulldown',
      setNumber: 1,
      isCompleted: true,
      actualWeight: 60,
      actualReps: 12,
      actualRpe: 8,
    });

    // Clear all in-memory repository structures (simulating cold start / new instance)
    workoutRepository.clearMemoryForTesting();

    // Query active set completions on a fresh instance
    const freshInstance = new WorkoutRepository();
    const activeSets = await freshInstance.getActiveSetCompletions(clientId, inProgressSessionId);

    assertTest(
      'Active set completions survive memory wipe and are loaded from PostgreSQL',
      activeSets.length === 1 &&
        activeSets[0].exerciseId === 'lat-pulldown' &&
        activeSets[0].setNumber === 1 &&
        activeSets[0].actualWeight === 60
    );

    // -------------------------------------------------------------
    // TEST 6: Fail-Closed / Database Error Propagation
    // -------------------------------------------------------------
    console.log('\n[TEST 6] Database Error Resilience (Never Silently Report Success):');
    const origUserFindFirst = prisma.user.findFirst;
    (prisma.user.findFirst as any) = async () => {
      throw new Error('FATAL: PostgreSQL connection failed');
    };

    let caughtError: any = null;
    try {
      await workoutRepository.saveSetCompletion(clientId, inProgressSessionId, {
        exerciseId: 'lat-pulldown',
        setNumber: 2,
        isCompleted: true,
        actualWeight: 65,
        actualReps: 10,
      });
    } catch (err: any) {
      caughtError = err;
    } finally {
      (prisma.user.findFirst as any) = origUserFindFirst;
    }

    assertTest(
      'Database failure re-throws error and does NOT silently report success',
      caughtError !== null && caughtError.message.includes('FATAL: PostgreSQL connection failed')
    );

    // -------------------------------------------------------------
    // TEST 7: Existing workout flows (history & unlocking) remain intact
    // -------------------------------------------------------------
    console.log('\n[TEST 7] Client History & Admin Unlock Non-Regression:');
    const history = await workoutRepository.getClientWorkoutHistory(clientId);
    assertTest(
      'Client workout history retrieves completed records with full fidelity',
      Array.isArray(history) && history.length >= 2
    );

    const unlockResult = await workoutRepository.unlockSession(adminId, {
      clientId,
      sessionId: testSessionId,
      scheduledDate: targetDate,
      reason: 'Athlete requested extra set adjustments',
    });
    assertTest(
      'Admin unlockSession succeeds and updates records/assignments',
      unlockResult.success === true && unlockResult.reason === 'Athlete requested extra set adjustments'
    );

    console.log('\n================================================================');
    console.log(`✅ ALL ${passedTests}/${totalTests} BUG-02 REGRESSION TESTS PASSED!`);
    console.log('================================================================');
  } finally {
    // Restore all original prisma methods
    prisma.user.findUnique = originalUserFindUnique;
    prisma.user.findFirst = originalUserFindFirst;
    prisma.clientProfile.findUnique = originalProfileFindUnique;
    (prisma as any).workoutSplitPlan.upsert = originalSplitUpsert;
    (prisma as any).workoutSplitPlan.findUnique = originalSplitFindUnique;
    (prisma as any).workoutSplitPlan.findFirst = originalSplitFindFirst;
    (prisma as any).workoutSplitPlan.update = originalSplitUpdate;
    prisma.workoutRecord.create = originalRecordCreate;
    prisma.workoutRecord.findFirst = originalRecordFindFirst;
    prisma.workoutRecord.findMany = originalRecordFindMany;
    prisma.workoutRecord.update = originalRecordUpdate;
    prisma.workoutRecord.updateMany = originalRecordUpdateMany;
    prisma.workoutRecord.deleteMany = originalRecordDeleteMany;
    prisma.clientSessionOverride.findFirst = originalOverrideFindFirst;
    prisma.workoutAssignment.findMany = originalAssignmentFindMany;
    prisma.workoutAssignment.findFirst = originalAssignmentFindFirst;
    prisma.workoutAssignment.create = originalAssignmentCreate;
    prisma.workoutAssignment.updateMany = originalAssignmentUpdateMany;
    prisma.workoutSession.findUnique = originalSessionFindUnique;
    prisma.workoutSession.findFirst = originalSessionFindFirst;
    prisma.workoutSession.create = originalSessionCreate;
    prisma.workoutSessionExercise.create = originalSessionExerciseCreate;
    (prisma as any).workoutSetTemplate = { create: originalSetTemplateCreate };
    prisma.workoutExerciseRecord.create = originalExCreate;
    prisma.workoutSetRecord.create = originalSetCreate;
    prisma.workoutSetRecord.update = originalSetUpdate;
    prisma.workoutSetRecord.count = originalSetCount;
  }
}

runBug02Suite().catch((err) => {
  console.error('Fatal BUG-02 test error:', err);
  process.exit(1);
});
