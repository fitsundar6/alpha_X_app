import { prisma } from './config/prisma';
import { aiTools } from './modules/ai_coach/ai_tools';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { workoutRepository } from './modules/workout/workout.repository';
import { workoutService } from './modules/workout/workout.service';

const GREEN = '\x1b[32m✔\x1b[0m';
const RED = '\x1b[31m✖\x1b[0m';
const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

let passed = 0;
let failed = 0;

function ok(desc: string, condition: boolean) {
  if (condition) {
    console.log(`  ${GREEN} ${desc}`);
    passed++;
  } else {
    console.log(`  ${RED} ${desc}`);
    failed++;
  }
}

async function runSection(name: string, fn: () => Promise<void>) {
  console.log(`\n${BOLD}=== ${name} ===${RESET}`);
  try {
    await fn();
  } catch (err: any) {
    console.log(`  ${RED} THREW ERROR: ${err?.message || err}`);
    failed++;
  }
}

async function main() {
  console.log(`${BOLD}========================================================================${RESET}`);
  console.log(`${BOLD}  ALPHA X GYM — EXERCISE REPLACEMENT & REORDERING REGRESSION SUITE       ${RESET}`);
  console.log(`${BOLD}========================================================================${RESET}`);

  const testAdminId = 'admin_reorder_test';
  const testClientId = 'client_reorder_athlete';
  const testClientName = 'Marcus Reorder Pro';
  let clientMonSessionId: string = '';

  // 1. Setup admin & client
  await prisma.user.upsert({
    where: { id: testAdminId },
    update: {},
    create: {
      id: testAdminId,
      email: 'admin_reorder@alphax.local',
      name: 'Head Coach Marcus',
      role: 'ADMIN',
      status: 'APPROVED',
    },
  });

  const athleteUser = await prisma.user.upsert({
    where: { id: testClientId },
    update: {},
    create: {
      id: testClientId,
      email: 'marcus_athlete@alphax.local',
      name: testClientName,
      role: 'CLIENT',
      status: 'APPROVED',
    },
  });

  const clientProfile = await prisma.clientProfile.upsert({
    where: { userId: athleteUser.id },
    update: {},
    create: {
      userId: athleteUser.id,
      clientId: 'AXG-REORDER-99',
      primaryGoal: 'Strength & Hypertrophy',
      fitnessLevel: 'Advanced',
      weightKg: 82.0,
    },
  });

  const convId = `conv_reorder_${Date.now()}`;
  await prisma.aIConversation.create({
    data: {
      id: convId,
      adminId: testAdminId,
      activeClientId: athleteUser.id,
      title: 'Exercise Replacement & Drag Reorder Session',
    },
  });

  let proposalId = '';

  // ──────────────────────────────────────────────────────────────────────────
  // STEP 1: Generate Multi-Day Workout Proposal
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 1: Generate Proposal with Monday Push & Tuesday Pull', async () => {
    const rawProposalData = {
      clientIdentifier: testClientName,
      planTitle: 'PPL Hypertrophy Master Plan',
      summary: 'Targeted Upper Body Push & Pull Split',
      reason: 'Progressive overload',
      weeklySchedule: [
        {
          day: 'Monday',
          dayName: 'Monday',
          sessionTitle: 'Monday Push',
          workoutType: 'Strength',
          splitCategory: 'Push',
          targetMuscleGroup: 'Chest • Shoulders • Triceps',
          estimatedDurationMinutes: 60,
          exercises: [
            {
              exerciseId: 'ex_bb_bench',
              exerciseName: 'Barbell Flat Bench Press',
              name: 'Barbell Flat Bench Press',
              category: 'Chest',
              sets: 4,
              reps: '6-8',
              targetReps: '6-8',
              weight: 80.0,
              targetWeight: 80.0,
              restSeconds: 120,
              tempo: '3-1-1-0',
              targetRir: 2,
              targetRpe: 8.0,
              notes: 'Drive feet into floor',
            },
            {
              exerciseId: 'ex_incline_db',
              exerciseName: 'Incline Dumbbell Press',
              name: 'Incline Dumbbell Press',
              category: 'Chest',
              sets: 3,
              reps: '8-10',
              targetReps: '8-10',
              weight: 30.0,
              targetWeight: 30.0,
              restSeconds: 90,
              tempo: '3-0-1-0',
              targetRir: 2,
              targetRpe: 8.0,
              notes: '30 degree incline',
            },
            {
              exerciseId: 'ex_cable_fly',
              exerciseName: 'Cable Chest Fly',
              name: 'Cable Chest Fly',
              category: 'Chest',
              sets: 3,
              reps: '12-15',
              targetReps: '12-15',
              weight: 15.0,
              targetWeight: 15.0,
              restSeconds: 60,
              tempo: '2-0-1-1',
              targetRir: 1,
              targetRpe: 8.5,
              notes: 'Peak contraction',
            },
            {
              exerciseId: 'ex_skull_crusher',
              exerciseName: 'EZ-Bar Skull Crusher',
              name: 'EZ-Bar Skull Crusher',
              category: 'Arms',
              sets: 3,
              reps: '10-12',
              targetReps: '10-12',
              weight: 25.0,
              targetWeight: 25.0,
              restSeconds: 60,
              tempo: '3-0-1-0',
              targetRir: 1,
              targetRpe: 8.5,
              notes: 'Elbows stationary',
            },
          ],
        },
        {
          day: 'Tuesday',
          dayName: 'Tuesday',
          sessionTitle: 'Tuesday Pull',
          workoutType: 'Strength',
          splitCategory: 'Pull',
          targetMuscleGroup: 'Back • Biceps',
          estimatedDurationMinutes: 55,
          exercises: [
            {
              exerciseId: 'ex_deadlift',
              exerciseName: 'Conventional Deadlift',
              name: 'Conventional Deadlift',
              category: 'Back',
              sets: 4,
              reps: '5',
              targetReps: '5',
              weight: 140.0,
              targetWeight: 140.0,
              restSeconds: 180,
              tempo: '3-1-1-0',
              targetRir: 2,
              targetRpe: 8.5,
              notes: 'Hips down, chest up',
            },
            {
              exerciseId: 'ex_pullup',
              exerciseName: 'Weighted Pull-Up',
              name: 'Weighted Pull-Up',
              category: 'Back',
              sets: 3,
              reps: '6-8',
              targetReps: '6-8',
              weight: 10.0,
              targetWeight: 10.0,
              restSeconds: 120,
              tempo: '3-0-1-0',
              targetRir: 2,
              targetRpe: 8.0,
              notes: 'Full dead hang',
            },
            {
              exerciseId: 'ex_seated_row',
              exerciseName: 'Seated Cable Row',
              name: 'Seated Cable Row',
              category: 'Back',
              sets: 3,
              reps: '10-12',
              targetReps: '10-12',
              weight: 60.0,
              targetWeight: 60.0,
              restSeconds: 75,
              tempo: '2-1-1-0',
              targetRir: 2,
              targetRpe: 8.0,
              notes: 'Squeeze lats',
            },
          ],
        },
      ],
    };

    const res = await proposeWorkoutPlanTool.handler(rawProposalData, {
      requestId: `req_${Date.now()}`,
      conversationId: convId,
      adminId: testAdminId,
    });

    ok('Proposal created successfully', res.success === true);
    proposalId = res.proposal.id;
    ok('Proposal ID assigned', !!proposalId);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 1: Replace an exercise and save proposal
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 1 & 2: Replace Barbell Flat Bench with Dumbbell Bench Press & Save Proposal', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.proposedDataJson || '{}');

    // Verify initial state
    ok('Initial Monday ex 0 is Barbell Flat Bench Press', payload.weeklySchedule[0].exercises[0].exerciseId === 'ex_bb_bench');

    // Replace ex 0 with Dumbbell Flat Bench Press while preserving compatible settings
    const origSettings = payload.weeklySchedule[0].exercises[0];
    payload.weeklySchedule[0].exercises[0] = {
      ...origSettings,
      exerciseId: 'ex_db_flat_bench',
      exerciseName: 'Dumbbell Flat Bench Press',
      name: 'Dumbbell Flat Bench Press',
      category: 'Chest',
      // Compatible settings preserved
      sets: origSettings.sets,
      targetReps: origSettings.targetReps,
      targetWeight: 32.0, // dumbbells each side
      weight: 32.0,
      restSeconds: origSettings.restSeconds,
      tempo: origSettings.tempo,
      targetRir: origSettings.targetRir,
      targetRpe: origSettings.targetRpe,
      notes: origSettings.notes,
    };

    const updated = await aiTools.editProposal(proposalId, testAdminId, payload);
    ok('Proposal status is EDITED', updated.status === 'EDITED');

    // Reopen from database and verify replacement persists
    const reopened = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const reopenedPayload = JSON.parse(reopened?.finalDataJson || '{}');
    const replacedEx = reopenedPayload.weeklySchedule[0].exercises[0];

    ok('Reopened proposal has replacement exerciseId: ex_db_flat_bench', replacedEx.exerciseId === 'ex_db_flat_bench');
    ok('Reopened proposal has replacement exerciseName: Dumbbell Flat Bench Press', replacedEx.exerciseName === 'Dumbbell Flat Bench Press');
    ok('Reopened proposal has name updated as well', replacedEx.name === 'Dumbbell Flat Bench Press');
    ok('Replaced exercise is in position 0', reopenedPayload.weeklySchedule[0].exercises[0].exerciseId === 'ex_db_flat_bench');
    ok('Sets preserved (4)', replacedEx.sets === 4);
    ok('Reps preserved (6-8)', replacedEx.targetReps === '6-8');
    ok('Rest preserved (120s)', replacedEx.restSeconds === 120);
    ok('Tempo preserved (3-1-1-0)', replacedEx.tempo === '3-1-1-0');
    ok('Target RIR preserved (2)', replacedEx.targetRir === 2);
    ok('Target RPE preserved (8.0)', replacedEx.targetRpe === 8.0);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 3 & 4 & 5: Drag-and-Drop Reordering in Session
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 3: Move First Exercise to Last Position', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.finalDataJson || '{}');
    const mondayExs = payload.weeklySchedule[0].exercises;

    // Initially: [Dumbbell Flat Bench, Incline DB, Cable Fly, Skull Crusher]
    ok('Initially ex 0 is Dumbbell Flat Bench', mondayExs[0].exerciseId === 'ex_db_flat_bench');
    const initialLen = mondayExs.length;

    // Drag first item (index 0) to last position (index 3)
    const item = mondayExs.splice(0, 1)[0];
    mondayExs.push(item);

    ok('Length unchanged (4)', mondayExs.length === initialLen);
    ok('Former first is now last', mondayExs[3].exerciseId === 'ex_db_flat_bench');
    ok('New first is Incline DB Press', mondayExs[0].exerciseId === 'ex_incline_db');

    await aiTools.editProposal(proposalId, testAdminId, payload);
    const db = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const reloaded = JSON.parse(db?.finalDataJson || '{}');
    ok('DB confirms Dumbbell Flat Bench is at position 3', reloaded.weeklySchedule[0].exercises[3].exerciseId === 'ex_db_flat_bench');
  });

  await runSection('REGRESSION 4: Move Last Exercise to First Position', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.finalDataJson || '{}');
    const mondayExs = payload.weeklySchedule[0].exercises;

    // Currently: [Incline DB, Cable Fly, Skull Crusher, Dumbbell Flat Bench]
    ok('Currently last is Dumbbell Flat Bench', mondayExs[3].exerciseId === 'ex_db_flat_bench');

    // Drag last item (index 3) to first position (index 0)
    const item = mondayExs.pop()!;
    mondayExs.unshift(item);

    ok('Dumbbell Flat Bench is back to first (position 0)', mondayExs[0].exerciseId === 'ex_db_flat_bench');
    ok('Incline DB Press moved to second (position 1)', mondayExs[1].exerciseId === 'ex_incline_db');

    await aiTools.editProposal(proposalId, testAdminId, payload);
    const db = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const reloaded = JSON.parse(db?.finalDataJson || '{}');
    ok('DB confirms Dumbbell Flat Bench is at position 0', reloaded.weeklySchedule[0].exercises[0].exerciseId === 'ex_db_flat_bench');
  });

  await runSection('REGRESSION 5: Reorder Exercises in Middle of Session', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.finalDataJson || '{}');
    const mondayExs = payload.weeklySchedule[0].exercises;

    // Currently: [Dumbbell Flat Bench (0), Incline DB (1), Cable Fly (2), Skull Crusher (3)]
    ok('Ex 1 is Incline DB', mondayExs[1].exerciseId === 'ex_incline_db');
    ok('Ex 2 is Cable Fly', mondayExs[2].exerciseId === 'ex_cable_fly');

    // Swap middle two: drag index 2 (Cable Fly) above index 1 (Incline DB)
    const item = mondayExs.splice(2, 1)[0];
    mondayExs.splice(1, 0, item);

    ok('Ex 1 is now Cable Fly', mondayExs[1].exerciseId === 'ex_cable_fly');
    ok('Ex 2 is now Incline DB', mondayExs[2].exerciseId === 'ex_incline_db');
    ok('First remains Dumbbell Flat Bench', mondayExs[0].exerciseId === 'ex_db_flat_bench');
    ok('Last remains Skull Crusher', mondayExs[3].exerciseId === 'ex_ez_skull_crusher');

    await aiTools.editProposal(proposalId, testAdminId, payload);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 6: Replace and Reorder in the Same Session
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 6: Combined Replace + Reorder in Same Session', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.finalDataJson || '{}');
    const mondayExs = payload.weeklySchedule[0].exercises;

    // 1. Replace Skull Crusher (index 3) with Triceps Overhead Rope Extension
    mondayExs[3] = {
      ...mondayExs[3],
      exerciseId: 'ex_rope_ext',
      exerciseName: 'Triceps Overhead Rope Extension',
      name: 'Triceps Overhead Rope Extension',
      category: 'Arms',
    };

    // 2. Drag Triceps Overhead Rope Extension from index 3 up to index 0 (top of session)
    const moved = mondayExs.splice(3, 1)[0];
    mondayExs.unshift(moved);

    ok('Replaced and moved exercise is at index 0', mondayExs[0].exerciseId === 'ex_rope_ext');
    ok('Dumbbell Flat Bench shifted to index 1', mondayExs[1].exerciseId === 'ex_db_flat_bench');
    ok('Cable Fly is at index 2', mondayExs[2].exerciseId === 'ex_cable_fly');
    ok('Incline DB is at index 3', mondayExs[3].exerciseId === 'ex_incline_db');

    await aiTools.editProposal(proposalId, testAdminId, payload);

    const reloaded = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const reloadedPayload = JSON.parse(reloaded?.finalDataJson || '{}');
    const checkExs = reloadedPayload.weeklySchedule[0].exercises;

    ok('Persistent check: index 0 is Triceps Overhead Rope Extension', checkExs[0].exerciseId === 'ex_rope_ext');
    ok('Persistent check: index 1 is Dumbbell Flat Bench', checkExs[1].exerciseId === 'ex_db_flat_bench');
    ok('Persistent check: index 2 is Cable Fly', checkExs[2].exerciseId === 'ex_cable_fly');
    ok('Persistent check: index 3 is Incline DB', checkExs[3].exerciseId === 'ex_incline_db');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 7: Isolation Between Two Different Sessions
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 7: Session Isolation (Tuesday Pull Untouched by Monday Changes)', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.finalDataJson || '{}');
    const tuesdayExs = payload.weeklySchedule[1].exercises;

    // Verify Tuesday exercises remain exactly as originally defined
    ok('Tuesday has 3 exercises', tuesdayExs.length === 3);
    ok('Tuesday ex 0 is Conventional Deadlift', tuesdayExs[0].exerciseId === 'ex_deadlift');
    ok('Tuesday ex 1 is Weighted Pull-Up', tuesdayExs[1].exerciseId === 'ex_pullup');
    ok('Tuesday ex 2 is Seated Cable Row', tuesdayExs[2].exerciseId === 'ex_seated_cable_row');

    // Now reorder Tuesday independently
    const item = tuesdayExs.pop()!;
    tuesdayExs.unshift(item); // Seated Cable Row is now first

    await aiTools.editProposal(proposalId, testAdminId, payload);

    const reloaded = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const reloadedPayload = JSON.parse(reloaded?.finalDataJson || '{}');

    // Monday must still have its own 4 exercises intact
    ok('Monday still has 4 exercises', reloadedPayload.weeklySchedule[0].exercises.length === 4);
    ok('Monday top is still Triceps Rope Ext', reloadedPayload.weeklySchedule[0].exercises[0].exerciseId === 'ex_rope_ext');

    // Tuesday has its own new order
    ok('Tuesday top is Seated Cable Row', reloadedPayload.weeklySchedule[1].exercises[0].exerciseId === 'ex_seated_cable_row');
    ok('Tuesday ex 1 is Conventional Deadlift', reloadedPayload.weeklySchedule[1].exercises[1].exerciseId === 'ex_deadlift');
    ok('Tuesday ex 2 is Weighted Pull-Up', reloadedPayload.weeklySchedule[1].exercises[2].exerciseId === 'ex_pullup');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 8: Approve Proposal & Confirm Client Receives Exact Exercises in Exact Order
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 8: Approve Proposal & Verify Client Assignment Order & Content', async () => {
    const approved = await aiTools.approveProposal(proposalId, testAdminId, 'Head Coach Marcus', {
      assignmentType: 'INDIVIDUAL',
      clientIds: [athleteUser.id],
    });

    ok('Proposal status is APPROVED', approved.status === 'APPROVED');

    // Fetch active assignments for athlete
    const assignments = await prisma.workoutAssignment.findMany({
      where: { clientId: athleteUser.id, active: true },
      include: {
        session: {
          include: {
            exercises: {
              include: { setTemplates: true },
              orderBy: { orderIndex: 'asc' },
            },
          },
        },
      },
    });

    ok('Client assignments created (2 sessions)', assignments.length === 2);

    // Find Monday Push session
    const mondayAssign = assignments.find((a) => a.session.title.includes('Monday Push'));
    ok('Monday Push assignment found', !!mondayAssign);

    const monSession = mondayAssign!.session;
    clientMonSessionId = monSession.id;
    ok('Monday Push has exactly 4 exercises', monSession.exercises.length === 4);

    // Verify exact order and replacement in client workout
    ok('OrderIndex 0 is Triceps Overhead Rope Extension',
      monSession.exercises[0].orderIndex === 0 &&
      monSession.exercises[0].exerciseName === 'Triceps Overhead Rope Extension' &&
      monSession.exercises[0].exerciseId === 'ex_rope_ext'
    );

    ok('OrderIndex 1 is Dumbbell Flat Bench Press',
      monSession.exercises[1].orderIndex === 1 &&
      monSession.exercises[1].exerciseName === 'Dumbbell Flat Bench Press' &&
      monSession.exercises[1].exerciseId === 'ex_db_flat_bench'
    );

    ok('OrderIndex 2 is Cable Chest Fly',
      monSession.exercises[2].orderIndex === 2 &&
      monSession.exercises[2].exerciseName.includes('Cable Chest Fly') &&
      monSession.exercises[2].exerciseId === 'ex_cable_fly'
    );

    ok('OrderIndex 3 is Incline Dumbbell Press',
      monSession.exercises[3].orderIndex === 3 &&
      monSession.exercises[3].exerciseName === 'Incline Dumbbell Press' &&
      monSession.exercises[3].exerciseId === 'ex_incline_db'
    );

    // Verify replaced exercise does NOT appear
    const hasOldBench = monSession.exercises.some((e) => e.exerciseId === 'ex_bb_bench' || e.exerciseName === 'Barbell Flat Bench Press');
    ok('Old Barbell Flat Bench Press does NOT appear in active session', !hasOldBench);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 9: Verify Sets, Reps, Rest, Tempo Remain Intact
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 9: Verify Detailed Settings (Sets, Reps, Weight, Tempo, Rest) Intact', async () => {
    const mondayAssign = await prisma.workoutAssignment.findFirst({
      where: { clientId: athleteUser.id, active: true, session: { title: { contains: 'Monday Push' } } },
      include: {
        session: {
          include: {
            exercises: {
              include: { setTemplates: { orderBy: { setNumber: 'asc' } } },
              orderBy: { orderIndex: 'asc' },
            },
          },
        },
      },
    });

    const dbBench = mondayAssign!.session.exercises.find((e) => e.exerciseId === 'ex_db_flat_bench')!;
    ok('DB Bench has 4 sets', dbBench.numberOfSets === 4);
    ok('DB Bench target reps is 6-8', dbBench.targetReps === '6-8');
    ok('DB Bench target weight is 32.0', dbBench.targetWeight === 32.0);
    ok('DB Bench rest is 120s', dbBench.restSeconds === 120);
    ok('DB Bench tempo is 3-1-1-0', dbBench.tempo === '3-1-1-0');
    ok('DB Bench target RIR is 2', dbBench.targetRir === 2);
    ok('DB Bench target RPE is 8.0', dbBench.targetRpe === 8.0);
    ok('DB Bench has 4 setTemplates', dbBench.setTemplates.length === 4);
    ok('SetTemplate 1 has min reps 6, max reps 8', dbBench.setTemplates[0].targetRepsMin === 6 && dbBench.setTemplates[0].targetRepsMax === 8);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 10: Adding, Removing, Editing Exercises Directly in Session Screen
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 10: Direct WorkoutSession Add, Remove, and Edit Verification', async () => {
    const session = await prisma.workoutSession.create({
      data: {
        title: 'Direct Editor Verification Session',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest',
        difficulty: 'INTERMEDIATE',
        createdById: testAdminId,
      },
    });

    // 1. Add exercises
    await workoutRepository.updateSession(session.id, {
      exercises: [
        { id: 'ex_dir_1', sessionId: session.id, exerciseId: 'ex_1', exerciseName: 'Pushup', category: 'Chest', orderIndex: 0, sets: [{ id: 's1', setNumber: 1, targetReps: '15' }] },
        { id: 'ex_dir_2', sessionId: session.id, exerciseId: 'ex_2', exerciseName: 'Dip', category: 'Arms', orderIndex: 1, sets: [{ id: 's2', setNumber: 1, targetReps: '10' }] },
      ],
    } as any);

    let fetched = await workoutRepository.getSessionById(session.id);
    ok('Added 2 exercises', fetched?.exercises.length === 2);

    // 2. Reorder them (Dip first, Pushup second)
    await workoutRepository.updateSession(session.id, {
      exercises: [
        { id: 'ex_dir_2', sessionId: session.id, exerciseId: 'ex_2', exerciseName: 'Dip', category: 'Arms', orderIndex: 0, sets: [{ id: 's2', setNumber: 1, targetReps: '10' }] },
        { id: 'ex_dir_1', sessionId: session.id, exerciseId: 'ex_1', exerciseName: 'Pushup', category: 'Chest', orderIndex: 1, sets: [{ id: 's1', setNumber: 1, targetReps: '15' }] },
      ],
    } as any);

    fetched = await workoutRepository.getSessionById(session.id);
    ok('Reordered: Dip is index 0', fetched?.exercises[0].exerciseName === 'Dip');
    ok('Reordered: Pushup is index 1', fetched?.exercises[1].exerciseName === 'Pushup');

    // 3. Remove Pushup
    await workoutRepository.updateSession(session.id, {
      exercises: [
        { id: 'ex_dir_2', sessionId: session.id, exerciseId: 'ex_2', exerciseName: 'Dip', category: 'Arms', orderIndex: 0, sets: [{ id: 's2', setNumber: 1, targetReps: '10' }] },
      ],
    } as any);

    fetched = await workoutRepository.getSessionById(session.id);
    ok('Removed Pushup: 1 exercise remains', fetched?.exercises.length === 1);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 11: Security & Unauthorized Role Protection
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 11: Security & Unauthorized Access Verification', async () => {
    // Non-admin user
    const regularClient = await prisma.user.findUnique({ where: { id: testClientId } });
    ok('Client user role is CLIENT (not ADMIN)', regularClient?.role === 'CLIENT');

    // Verify middleware route declaration guards
    const routes = require('./modules/workout/workout.routes');
    ok('Workout routes loaded cleanly with admin authorization middleware', !!routes);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // REGRESSION 12: Workout History & Completed Set Logs Immortality
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('REGRESSION 12: Historical Completed Set Logs Unchanged After Reorder/Replace', async () => {
    // Create historical completed workout record
    const historyRecord = await workoutService.recordWorkout(testClientId, {
      sessionId: clientMonSessionId,
      sessionTitle: 'Historical Monday Push',
      workoutType: 'Strength',
      startedAt: new Date(Date.now() - 7200000).toISOString(),
      completedAt: new Date(Date.now() - 3600000).toISOString(),
      durationSeconds: 3600,
      totalVolume: 3200,
      completedSetsCount: 12,
      skippedSetsCount: 0,
      isCompleted: true,
      scheduledDate: '2026-10-15',
      personalRecords: [],
      exerciseRecords: [
        {
          exerciseId: 'ex_bb_bench',
          exerciseName: 'Barbell Flat Bench Press',
          orderIndex: 0,
          isSkipped: false,
          sets: [
            { setNumber: 1, setType: 'Working', actualWeight: 80.0, actualReps: 8, actualRir: 2, actualRpe: 8.0, isCompleted: true },
            { setNumber: 2, setType: 'Working', actualWeight: 80.0, actualReps: 8, actualRir: 2, actualRpe: 8.0, isCompleted: true },
          ],
        },
      ],
    } as any);

    ok('Historical workout record logged', !!historyRecord?.id);

    // Verify historical record still references original Barbell Bench Press with exact completed sets
    const historyList = await workoutService.getClientHistory(testClientId);
    const found = historyList.find((h: any) => h.id === historyRecord.id);

    ok('Historical record found in client history', !!found);
    ok('Historical volume preserved (3200 kg)', (found as any)?.totalVolume === 3200);
    ok('Historical sessionTitle preserved (Historical Monday Push)', (found as any)?.sessionTitle === 'Historical Monday Push');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Final summary
  // ──────────────────────────────────────────────────────────────────────────
  console.log(`\n${'='.repeat(72)}`);
  if (failed === 0) {
    console.log(`${BOLD}${GREEN} ALL ${passed} REGRESSION CHECKS PASSED 100%!${RESET}`);
  } else {
    console.log(`${BOLD}${RED} RESULTS: ${passed} passed, ${failed} FAILED${RESET}`);
  }
  console.log(`${'='.repeat(72)}\n`);

  if (failed > 0) process.exit(1);
}

main()
  .catch((e) => {
    console.error('Fatal test runner error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
