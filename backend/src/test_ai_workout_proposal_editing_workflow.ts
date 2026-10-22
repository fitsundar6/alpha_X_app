import { prisma } from './config/prisma';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { proposeDietPlanTool } from './modules/ai_coach/tools/definitions/client/propose_diet_plan';
import { aiTools } from './modules/ai_coach/ai_tools';

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

async function runAllRegressionTests() {
  console.log(`${BOLD}========================================================================${RESET}`);
  console.log(`${BOLD}  ALPHA X GYM AI COACH — WORKOUT PROPOSAL EDITING REGRESSION SUITE      ${RESET}`);
  console.log(`${BOLD}========================================================================${RESET}`);

  // Setup test athlete and admin
  const testAdminId = 'admin_reg_coach';
  const testClientId = 'client_reg_athlete_01';
  const testClientName = 'Alex Regression Athlete';

  await prisma.user.upsert({
    where: { id: testAdminId },
    update: {},
    create: {
      id: testAdminId,
      email: 'admin_reg_coach@alphax.local',
      name: 'Head Coach Alex',
      role: 'ADMIN',
      status: 'APPROVED',
    },
  });

  const athleteUser = await prisma.user.upsert({
    where: { id: testClientId },
    update: {},
    create: {
      id: testClientId,
      email: 'alex_regression@alphax.local',
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
      clientId: 'AXG-REG-01',
      primaryGoal: 'Muscle Gain & Hypertrophy',
      fitnessLevel: 'Intermediate',
      weightKg: 78.5,
    },
  });

  const convId = `conv_reg_workout_${Date.now()}`;
  await prisma.aIConversation.create({
    data: {
      id: convId,
      adminId: testAdminId,
      activeClientId: athleteUser.id,
      title: 'Regression AI Coach Session',
    },
  });

  let proposalId: string = '';

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 1: Generate Multi-Day Workout Proposal ("PPL × 2 (5-Day)")
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 1: Generate Multi-Day Workout Proposal (PPL × 2 (5-Day))', async () => {
    const rawProposalData = {
      clientIdentifier: testClientName,
      planTitle: 'PPL × 2 (5-Day) Hypertrophy Protocol',
      reason: 'Progressive overload for intermediate athlete with high recovery capacity.',
      summary: '5-Day Push-Pull-Legs split targeting balanced upper and lower growth.',
      weeklySchedule: [
        {
          day: 'Monday',
          dayName: 'Monday',
          sessionTitle: 'Monday Push A',
          workoutType: 'Strength',
          splitCategory: 'Push',
          targetMuscleGroup: 'Chest, Shoulders, Triceps',
          estimatedDurationMinutes: 60,
          exercises: [
            {
              exerciseId: 'ex_bench_flat',
              name: 'Barbell Flat Bench Press',
              exerciseName: 'Barbell Flat Bench Press',
              category: 'Chest',
              sets: 3,
              reps: '8-12',
              targetReps: '8-12',
              weight: 70.0,
              restSeconds: 90,
              tempo: '3-1-1-0',
              targetRir: 2,
              targetRpe: 8.0,
            },
            {
              exerciseId: 'ex_db_overhead',
              name: 'Dumbbell Overhead Shoulder Press',
              exerciseName: 'Dumbbell Overhead Shoulder Press',
              category: 'Shoulders',
              sets: 3,
              reps: '10-12',
              targetReps: '10-12',
              weight: 22.0,
              restSeconds: 75,
              tempo: '3-0-1-0',
              targetRir: 2,
              targetRpe: 8.0,
            },
          ],
        },
        {
          day: 'Tuesday',
          dayName: 'Tuesday',
          sessionTitle: 'Tuesday Pull A',
          workoutType: 'Strength',
          splitCategory: 'Pull',
          targetMuscleGroup: 'Back, Biceps, Rear Delts',
          estimatedDurationMinutes: 55,
          exercises: [
            {
              exerciseId: 'ex_barbell_row',
              name: 'Bent-Over Barbell Row',
              exerciseName: 'Bent-Over Barbell Row',
              category: 'Back',
              sets: 4,
              reps: '8-10',
              targetReps: '8-10',
              weight: 65.0,
              restSeconds: 90,
              tempo: '3-1-1-0',
              targetRir: 2,
              targetRpe: 8.0,
            },
          ],
        },
        {
          day: 'Wednesday',
          dayName: 'Wednesday',
          sessionTitle: 'Wednesday Legs A',
          workoutType: 'Strength',
          splitCategory: 'Legs',
          targetMuscleGroup: 'Quads, Hamstrings, Calves',
          estimatedDurationMinutes: 65,
          exercises: [
            {
              exerciseId: 'ex_squat_bb',
              name: 'Barbell Back Squat',
              exerciseName: 'Barbell Back Squat',
              category: 'Legs',
              sets: 4,
              reps: '6-8',
              targetReps: '6-8',
              weight: 100.0,
              restSeconds: 150,
              tempo: '3-0-1-0',
              targetRir: 2,
              targetRpe: 8.5,
            },
          ],
        },
        {
          day: 'Thursday',
          dayName: 'Thursday',
          sessionTitle: 'Thursday Push B',
          workoutType: 'Strength',
          splitCategory: 'Push',
          targetMuscleGroup: 'Upper Chest, Lateral Delts',
          estimatedDurationMinutes: 50,
          exercises: [
            {
              exerciseId: 'ex_incline_bb',
              name: 'Incline Barbell Bench Press',
              exerciseName: 'Incline Barbell Bench Press',
              category: 'Chest',
              sets: 3,
              reps: '8-12',
              targetReps: '8-12',
              weight: 60.0,
              restSeconds: 90,
              tempo: '3-1-1-0',
              targetRir: 2,
              targetRpe: 8.0,
            },
          ],
        },
        {
          day: 'Friday',
          dayName: 'Friday',
          sessionTitle: 'Friday Pull B',
          workoutType: 'Strength',
          splitCategory: 'Pull',
          targetMuscleGroup: 'Lats, Upper Back, Arms',
          estimatedDurationMinutes: 50,
          exercises: [
            {
              exerciseId: 'ex_lat_pulldown',
              name: 'Wide-Grip Lat Pulldown',
              exerciseName: 'Wide-Grip Lat Pulldown',
              category: 'Back',
              sets: 4,
              reps: '10-12',
              targetReps: '10-12',
              weight: 55.0,
              restSeconds: 75,
              tempo: '3-1-1-0',
              targetRir: 1,
              targetRpe: 8.5,
            },
          ],
        },
      ],
    };

    const result = await proposeWorkoutPlanTool.handler(rawProposalData, {
      requestId: `req_${Date.now()}`,
      conversationId: convId,
      adminId: testAdminId,
    });

    ok('Proposal creation tool executed successfully', result.success === true);
    ok('Proposal object returned', !!result.proposal);
    ok('Proposal status is PENDING', result.proposal?.status === 'PENDING');
    ok('Weekly schedule contains 5 workout days', result.proposal?.payload?.weeklySchedule?.length === 5);

    proposalId = result.proposal.id;

    // Verify DB record
    const dbRecord = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    ok('Database record created', !!dbRecord);
    ok('Database record status is PENDING', dbRecord?.status === 'PENDING');
    ok('Database record finalDataJson is null before edit', dbRecord?.finalDataJson === null);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 2 & 3 & 4: Admin Edits Sessions, Exercises, Sets, Reps, Drop Sets, Supersets & Saves
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 2-4: Edit Workout Sessions, Exercises, Sets, Reps, Drop Sets & Save', async () => {
    const existing = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    const payload = JSON.parse(existing?.proposedDataJson || '{}');

    // Make deep modifications across days:
    // 1. Rename Day 1 session title
    payload.weeklySchedule[0].sessionTitle = 'Monday Push Alpha (Modified)';
    payload.weeklySchedule[0].estimatedDurationMinutes = 65;

    // 2. Replace exercise 1 on Day 1 (change flat bench to Incline DB Press with drop set and custom notes)
    payload.weeklySchedule[0].exercises[0] = {
      exerciseId: 'ex_incline_db_press',
      exerciseName: 'Incline Dumbbell Press (Admin Edited)',
      category: 'Chest',
      sets: 4,
      targetReps: '6-8',
      weight: 34.0,
      targetWeight: 34.0,
      restSeconds: 120,
      tempo: '4-0-1-0',
      targetRpe: 9.0,
      targetRir: 1,
      supersetTag: 'SS_A',
      isDropSet: true,
      setType: 'DROP_SET',
      notes: 'Drop weight by 25% on final set to failure',
    };

    // 3. Add an extra exercise to Day 2 (Cable Face Pull with superset)
    payload.weeklySchedule[1].exercises.push({
      exerciseId: 'ex_face_pull_cable',
      exerciseName: 'Cable Face Pull',
      category: 'Shoulders',
      sets: 3,
      targetReps: '12-15',
      weight: 25.0,
      targetWeight: 25.0,
      restSeconds: 60,
      tempo: '2-1-1-1',
      targetRpe: 8.0,
      targetRir: 2,
      supersetTag: 'SS_PULL',
      setType: 'WORKING',
      notes: 'External rotation focus at peak',
    });

    // 4. Update overall plan title and description
    payload.title = 'Customized PPL × 2 (5-Day) — Admin Optimized';
    payload.summary = 'Edited by Admin Alex: elevated chest volume and rear delt accessory work.';

    // Execute edit
    const updated = await aiTools.editProposal(proposalId, testAdminId, payload);
    ok('aiTools.editProposal executed without errors', !!updated);
    ok('Updated proposal status is EDITED', updated.status === 'EDITED');
    ok('Database updated title persists', updated.title === 'Customized PPL × 2 (5-Day) — Admin Optimized');
    ok('Database updated summary persists', updated.summary.includes('Admin Alex'));
    ok('Database finalDataJson is populated', !!updated.finalDataJson);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 5: Reopen Proposal and Verify Every Change Persists
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 5: Reopen Proposal & Verify Every Edited Field Persists', async () => {
    const reopened = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
    ok('Reopened record found', !!reopened);
    ok('Reopened status is EDITED', reopened?.status === 'EDITED');

    const reopenedPayload = JSON.parse(reopened?.finalDataJson || '{}');
    const day1 = reopenedPayload.weeklySchedule[0];
    const day2 = reopenedPayload.weeklySchedule[1];

    ok('Day 1 session title matches edit', day1.sessionTitle === 'Monday Push Alpha (Modified)');
    ok('Day 1 duration is 65 min', day1.estimatedDurationMinutes === 65);
    ok('Day 1 ex 1 is Incline Dumbbell Press (Admin Edited)', day1.exercises[0].exerciseName === 'Incline Dumbbell Press (Admin Edited)');
    ok('Day 1 ex 1 has 4 sets', day1.exercises[0].sets === 4);
    ok('Day 1 ex 1 has 6-8 reps', day1.exercises[0].targetReps === '6-8');
    ok('Day 1 ex 1 targetWeight is 34 kg', day1.exercises[0].weight === 34.0);
    ok('Day 1 ex 1 tempo is 4-0-1-0', day1.exercises[0].tempo === '4-0-1-0');
    ok('Day 1 ex 1 targetRpe is 9.0', day1.exercises[0].targetRpe === 9.0);
    ok('Day 1 ex 1 targetRir is 1', day1.exercises[0].targetRir === 1);
    ok('Day 1 ex 1 supersetTag is SS_A', day1.exercises[0].supersetTag === 'SS_A');
    ok('Day 1 ex 1 isDropSet is true', day1.exercises[0].isDropSet === true);
    ok('Day 1 ex 1 setType is DROP_SET', day1.exercises[0].setType === 'DROP_SET');
    ok('Day 1 ex 1 notes match edit', day1.exercises[0].notes.includes('Drop weight by 25%'));

    ok('Day 2 has 2 exercises (1 added)', day2.exercises.length === 2);
    ok('Day 2 ex 2 is Cable Face Pull', day2.exercises[1].exerciseName === 'Cable Face Pull');
    ok('Day 2 ex 2 supersetTag is SS_PULL', day2.exercises[1].supersetTag === 'SS_PULL');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 6 & 7: Approve Edited Proposal & Verify Client Assignment
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 6-7: Approve Proposal & Verify Client Assignment & Schedule', async () => {
    const approved = await aiTools.approveProposal(proposalId, testAdminId, 'Head Coach Alex', {
      assignmentType: 'INDIVIDUAL',
      clientIds: [athleteUser.id],
    });

    ok('Approved proposal status is APPROVED', approved.status === 'APPROVED');
    ok('Approved by ID set', approved.approvedById === testAdminId);

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
      orderBy: { session: { recurringSchedule: 'asc' } },
    });

    ok('Active assignments created for client', assignments.length > 0);
    ok('Day isolation preserved: Exactly 5 sessions created (one per weekday)', assignments.length === 5);

    // Find Monday Push session
    const mondayAssign = assignments.find((a) => a.session.title.includes('Monday Push Alpha (Modified)'));
    ok('Monday edited session found in client assignment', !!mondayAssign);

    const monSession = mondayAssign!.session;
    ok('Monday duration is 65 min', monSession.estimatedDurationMinutes === 65);
    ok('Monday recurring schedule is Monday', monSession.recurringSchedule === 'Monday');
    ok('Monday has 2 exercises', monSession.exercises.length === 2);

    const monEx1 = monSession.exercises[0];
    ok('Monday ex 1 is edited Incline DB Press', monEx1.exerciseName === 'Incline Dumbbell Press (Admin Edited)');
    ok('Monday ex 1 has 4 sets in sessionExercise', monEx1.numberOfSets === 4);
    ok('Monday ex 1 has 6-8 reps', monEx1.targetReps === '6-8');
    ok('Monday ex 1 targetWeight is 34 kg', monEx1.targetWeight === 34.0);
    ok('Monday ex 1 supersetTag is SS_A', monEx1.supersetTag === 'SS_A');
    ok('Monday ex 1 setType is DROP_SET', monEx1.setType === 'DROP_SET');
    ok('Monday ex 1 tempo is 4-0-1-0', monEx1.tempo === '4-0-1-0');
    ok('Monday ex 1 has 4 setTemplates', monEx1.setTemplates.length === 4);
    ok('Monday ex 1 setTemplates setType is DROP_SET', monEx1.setTemplates[0].setType === 'DROP_SET');
    ok('Monday ex 1 setTemplates tempo is 4-0-1-0', monEx1.setTemplates[0].tempo === '4-0-1-0');

    // Find Tuesday Pull session
    const tuesdayAssign = assignments.find((a) => a.session.title.includes('Tuesday Pull A'));
    ok('Tuesday session found in client assignment', !!tuesdayAssign);
    ok('Tuesday has 2 exercises (original + added Face Pull)', tuesdayAssign!.session.exercises.length === 2);
    const tueEx2 = tuesdayAssign!.session.exercises[1];
    ok('Tuesday ex 2 is Cable Face Pull', tueEx2.exerciseName === 'Cable Face Pull');
    ok('Tuesday ex 2 supersetTag is SS_PULL', tueEx2.supersetTag === 'SS_PULL');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 8: Verify Rejection of an EDITED proposal works cleanly
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 8: Rejection of an EDITED proposal', async () => {
    const testProp = await prisma.aIProposal.create({
      data: {
        clientProfileId: clientProfile.id,
        clientId: athleteUser.id,
        clientName: athleteUser.name,
        proposalType: 'WORKOUT',
        title: 'Draft for Reject Test',
        summary: 'To test rejection after editing',
        reason: 'Testing rejection workflow',
        status: 'PENDING',
        proposedDataJson: JSON.stringify({ title: 'Draft for Reject Test', exercises: [] }),
      },
    });

    // Edit it
    await aiTools.editProposal(testProp.id, testAdminId, { title: 'Edited Before Reject', exercises: [] });
    const afterEdit = await prisma.aIProposal.findUnique({ where: { id: testProp.id } });
    ok('Proposal transitioned to EDITED', afterEdit?.status === 'EDITED');

    // Reject it
    const rejected = await aiTools.rejectProposal(testProp.id, testAdminId, 'Admin decided to decline after editing');
    ok('Proposal successfully rejected from EDITED status', rejected.status === 'REJECTED');
    ok('Rejection reason persisted', rejected.rejectionReason === 'Admin decided to decline after editing');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 9: Verify Diet proposals continue to work unaffected
  // ──────────────────────────────────────────────────────────────────────────
  await runSection('STEP 9: Diet Proposal End-to-End Safety Check', async () => {
    const dietResult = await proposeDietPlanTool.handler(
      {
        clientIdentifier: testClientName,
        planTitle: 'High Protein Cutting Diet',
        planKind: 'FULL_DIET',
        dailyCalories: 2400,
        protein: 185,
        carbohydrates: 220,
        fat: 55,
        reason: 'Cutting phase',
        summary: 'High protein 4-meal plan',
        meals: [
          {
            mealType: 'Breakfast',
            timing: '08:00 AM',
            items: [{ foodName: 'Oatmeal & Whey', quantity: 1, unit: 'bowl' }],
          },
        ],
      },
      {
        requestId: `diet_req_${Date.now()}`,
        conversationId: convId,
        adminId: testAdminId,
      }
    );

    ok('Diet proposal created', dietResult.success === true);
    const dietPropId = dietResult.proposal.id;

    // Edit diet proposal
    const editedDiet = await aiTools.editProposal(dietPropId, testAdminId, {
      ...dietResult.proposal.payload,
      dailyCalories: 2350,
      protein: 190,
    });
    ok('Diet proposal edited', editedDiet.status === 'EDITED');

    // Approve diet proposal
    const approvedDiet = await aiTools.approveProposal(dietPropId, testAdminId, 'Head Coach Alex');
    ok('Diet proposal approved', approvedDiet.status === 'APPROVED');
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SUMMARY
  // ──────────────────────────────────────────────────────────────────────────
  console.log(`\n${BOLD}========================================================================${RESET}`);
  console.log(`${BOLD}  TEST SUITE RESULTS: ${passed} PASSED, ${failed} FAILED                 ${RESET}`);
  console.log(`${BOLD}========================================================================${RESET}\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runAllRegressionTests()
  .catch((e) => {
    console.error('Fatal test error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
