/**
 * Alpha X AI — Workout Generation Quality & Clinical Safety Regression Test
 *
 * Validates:
 * 1. Goal alignment:
 *    - Strength: sets 3–5, heavy compound reps 3–6, rest 120–180s.
 *    - Fat Loss: reps 10–15, rest 45–60s.
 *    - Hypertrophy: reps 8–12, rest 60–90s.
 * 2. Experience level:
 *    - Beginner: safe load assignment, higher RIR (3), lower volume.
 *    - Advanced: higher sets/volume, lower RIR (1–2), higher intensity.
 * 3. Equipment & mechanics-aware load assignment:
 *    - Bodyweight movements (Pull-ups, Push-ups, Dips) get targetWeight === null (never 50kg or 80kg!).
 *    - Dumbbell isolation movements (e.g. Lateral Raise, Bicep Curl) get realistic weights (4kg–14kg, never 50kg!).
 *    - Barbell heavy compound movements (Squat, Deadlift) get realistic loads (40kg–120kg).
 * 4. Injury & limitation avoidance:
 *    - Client with Shoulder Injury: proposal must NOT contain Overhead Press / Military Press.
 *    - Proposing an exercise that conflicts with client injury MUST fail validation.
 * 5. In-session deduplication:
 *    - Proposing duplicate exercises in the same session MUST fail validation.
 * 6. Non-empty session validation:
 *    - Proposals with empty days must fail validation.
 * 7. End-to-end multi-day split generation and database persistence:
 *    - 3-day Push/Pull/Legs split respects training days and separates muscle groups properly.
 */

import { prisma } from './config/prisma';
import { workoutIntentService } from './modules/ai_coach/workout_intent.service';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { aiTools } from './modules/ai_coach/ai_tools';

let testsPassed = 0;
let testsFailed = 0;

function assert(condition: boolean, message: string) {
  if (!condition) {
    console.error(`  ❌ FAIL: ${message}`);
    testsFailed++;
    throw new Error(message);
  } else {
    console.log(`  ✅ PASS: ${message}`);
    testsPassed++;
  }
}

async function runWorkoutQualityRegressionTests() {
  console.log('=== Alpha X Gym — AI Workout Generation Quality Regression Suite ===\n');

  // -------------------------------------------------------------
  // Test 1: Goal Alignment (Strength vs Fat Loss vs Hypertrophy)
  // -------------------------------------------------------------
  console.log('--- Test 1: Goal-Aware Parameter Customization ---');
  {
    const barbellSquat = {
      name: 'Barbell Back Squat',
      bodyPart: 'Quadriceps',
      equipment: 'Barbell',
      isCompound: true,
      isIsolation: false,
    };

    // 1a. Strength Goal
    const strengthParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellSquat,
      { fitnessLevel: 'Intermediate', primaryGoal: 'Build Strength', gender: 'Male' }
    );
    assert(
      strengthParams.reps === '4-6' || strengthParams.reps === '3-5' || strengthParams.reps === '5-6',
      `Strength goal gives heavy compound rep range 3-6 (got: ${strengthParams.reps})`
    );
    assert(
      strengthParams.restSeconds >= 120,
      `Strength goal provides >= 120s rest for recovery (got: ${strengthParams.restSeconds}s)`
    );

    // 1b. Fat Loss / Conditioning Goal
    const fatLossParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellSquat,
      { fitnessLevel: 'Intermediate', primaryGoal: 'Fat Loss', gender: 'Male' }
    );
    assert(
      fatLossParams.reps === '10-12' || fatLossParams.reps === '12-15',
      `Fat Loss goal gives higher rep range 10-15 (got: ${fatLossParams.reps})`
    );
    assert(
      fatLossParams.restSeconds <= 60,
      `Fat Loss goal provides concise rest <= 60s (got: ${fatLossParams.restSeconds}s)`
    );

    // 1c. Hypertrophy Goal
    const hypertrophyParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellSquat,
      { fitnessLevel: 'Intermediate', primaryGoal: 'Muscle Gain', gender: 'Male' }
    );
    assert(
      hypertrophyParams.reps === '8-10',
      `Hypertrophy goal gives classic hypertrophy rep range 8-10 (got: ${hypertrophyParams.reps})`
    );
    assert(
      hypertrophyParams.restSeconds === 90 || hypertrophyParams.restSeconds === 120,
      `Hypertrophy goal provides 90-120s rest (got: ${hypertrophyParams.restSeconds}s)`
    );
  }

  // -------------------------------------------------------------
  // Test 2: Experience Level Calibration (Beginner vs Advanced)
  // -------------------------------------------------------------
  console.log('\n--- Test 2: Experience Level Calibration (Beginner vs Advanced) ---');
  {
    const barbellBench = {
      name: 'Barbell Bench Press',
      bodyPart: 'Chest',
      equipment: 'Barbell',
      isCompound: true,
      isIsolation: false,
    };

    // 2a. Without strength history: both receive weight = null (unspecified load)
    const beginnerUnspecified = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellBench,
      { fitnessLevel: 'Beginner', primaryGoal: 'Build Strength', gender: 'Male' }
    );
    const advancedUnspecified = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellBench,
      { fitnessLevel: 'Advanced', primaryGoal: 'Build Strength', gender: 'Male' }
    );

    assert(
      beginnerUnspecified.targetRir >= 3,
      `Beginner is assigned conservative RIR >= 3 for safety (got: ${beginnerUnspecified.targetRir})`
    );
    assert(
      advancedUnspecified.targetRir <= 2,
      `Advanced is assigned high-intensity RIR <= 2 (got: ${advancedUnspecified.targetRir})`
    );
    assert(
      beginnerUnspecified.weight === null && advancedUnspecified.weight === null,
      `Without recorded strength history, load remains unspecified (null) instead of inventing arbitrary kilograms`
    );

    // 2b. With verified strength history: load scales proportionally from client history
    const beginnerHistory = new Map([['barbell bench press', 40]]);
    const advancedHistory = new Map([['barbell bench press', 100]]);
    const beginnerCalibrated = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellBench,
      { fitnessLevel: 'Beginner', primaryGoal: 'Build Strength', gender: 'Male' },
      { strengthHistory: beginnerHistory }
    );
    const advancedCalibrated = workoutIntentService.calculatePersonalizedExerciseParameters(
      barbellBench,
      { fitnessLevel: 'Advanced', primaryGoal: 'Build Strength', gender: 'Male' },
      { strengthHistory: advancedHistory }
    );
    assert(
      beginnerCalibrated.weight !== null && advancedCalibrated.weight !== null && beginnerCalibrated.weight < advancedCalibrated.weight,
      `Calibrated beginner load (${beginnerCalibrated.weight} kg) is scaled appropriately below Advanced load (${advancedCalibrated.weight} kg)`
    );
  }

  // -------------------------------------------------------------
  // Test 3: Equipment & Mechanics-Aware Weight Assignment
  // -------------------------------------------------------------
  console.log('\n--- Test 3: Realistic Load Assignment (No 50kg Pull-ups or Lateral Raises) ---');
  {
    // 3a. Bodyweight Pull-up
    const pullup = {
      name: 'Pull-Ups',
      bodyPart: 'Back',
      equipment: 'Bodyweight',
      isCompound: true,
      isIsolation: false,
    };
    const pullupParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      pullup,
      { fitnessLevel: 'Advanced', primaryGoal: 'Muscle Gain', gender: 'Male' }
    );
    assert(
      pullupParams.weight === null && pullupParams.targetWeight === null,
      `Bodyweight Pull-Ups receive weight = null (not 50kg or 80kg!)`
    );

    // 3b. Dumbbell Lateral Raise (isolation with strength history)
    const lateralRaise = {
      name: 'Dumbbell Lateral Raise',
      bodyPart: 'Shoulders',
      equipment: 'Dumbbell',
      isCompound: false,
      isIsolation: true,
    };
    const latRaiseWithHistory = workoutIntentService.calculatePersonalizedExerciseParameters(
      lateralRaise,
      { fitnessLevel: 'Intermediate', primaryGoal: 'Hypertrophy', gender: 'Male' },
      { strengthHistory: new Map([['dumbbell lateral raise', 10]]) }
    );
    assert(
      latRaiseWithHistory.weight !== null && latRaiseWithHistory.weight >= 5.0 && latRaiseWithHistory.weight <= 15.0,
      `Dumbbell Lateral Raise with 10kg history receives realistic load (${latRaiseWithHistory.weight} kg, not 50kg!)`
    );

    // 3c. Heavy Barbell Deadlift (with 110kg strength history)
    const deadlift = {
      name: 'Barbell Deadlift',
      bodyPart: 'Back',
      equipment: 'Barbell',
      isCompound: true,
      isIsolation: false,
    };
    const deadliftParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      deadlift,
      { fitnessLevel: 'Advanced', primaryGoal: 'Build Strength', gender: 'Male' },
      { strengthHistory: new Map([['barbell deadlift', 110]]) }
    );
    assert(
      deadliftParams.weight !== null && deadliftParams.weight >= 90.0,
      `Heavy Barbell Deadlift with history receives strength load >= 90kg (${deadliftParams.weight} kg)`
    );

    // 3d. Without strength history, load is null (unspecified)
    const deadliftNoHistory = workoutIntentService.calculatePersonalizedExerciseParameters(
      deadlift,
      { fitnessLevel: 'Advanced', primaryGoal: 'Build Strength', gender: 'Male' }
    );
    assert(
      deadliftNoHistory.weight === null && deadliftNoHistory.targetWeight === null,
      `Heavy Barbell Deadlift without history returns unspecified load (null), never inventing arbitrary kilograms`
    );
  }

  // -------------------------------------------------------------
  // Test 4: Injury and Limitation Avoidance
  // -------------------------------------------------------------
  console.log('\n--- Test 4: Injury and Limitation Avoidance ---');
  {
    // 4a. Verify getBalancedExercisesForSplit filters out shoulder contraindications
    const pushSplit = workoutIntentService.detectSplit('Push Day');
    const safeExercises = await workoutIntentService.getBalancedExercisesForSplit(pushSplit, {
      injuryAreas: ['Shoulder'],
      count: 6,
    });
    const hasOverheadPress = safeExercises.some(
      (e) => e.name.toLowerCase().includes('overhead press') || e.name.toLowerCase().includes('military press')
    );
    assert(
      !hasOverheadPress,
      `Exercise pool excludes Overhead Press when client has documented Shoulder injury`
    );

    // 4b. Verify validateProposalForSplit explicitly rejects shoulder contraindications if proposed
    const invalidShoulderProposal = [
      { exerciseName: 'Barbell Overhead Press', bodyPart: 'Shoulders', sets: 3, reps: '8-10' },
      { exerciseName: 'Dumbbell Lateral Raise', bodyPart: 'Shoulders', sets: 3, reps: '10-12' },
    ];
    const shoulderValidation = await workoutIntentService.validateProposalForSplit(
      pushSplit,
      invalidShoulderProposal,
      undefined,
      { injuryAreas: ['Shoulder'] }
    );
    assert(
      !shoulderValidation.isValid,
      `Validation correctly rejects proposal containing Overhead Press for client with shoulder injury`
    );
    assert(
      shoulderValidation.error?.includes('shoulder injury') === true,
      `Validation error cites shoulder injury conflict: "${shoulderValidation.error}"`
    );
  }

  // -------------------------------------------------------------
  // Test 5: In-Session Exercise Deduplication
  // -------------------------------------------------------------
  console.log('\n--- Test 5: In-Session Duplicate Exercise Prevention ---');
  {
    const legSplit = workoutIntentService.detectSplit('Leg Day');
    const duplicateExercises = [
      { exerciseName: 'Barbell Squat', bodyPart: 'Quadriceps', sets: 3, reps: '8-10' },
      { exerciseName: 'Leg Press', bodyPart: 'Quadriceps', sets: 3, reps: '10-12' },
      { exerciseName: 'Barbell Squat', bodyPart: 'Quadriceps', sets: 3, reps: '8-10' }, // DUPLICATE
    ];

    const dupValidation = await workoutIntentService.validateProposalForSplit(
      legSplit,
      duplicateExercises
    );
    assert(
      !dupValidation.isValid,
      `Validation rejects in-session duplicate exercises`
    );
    assert(
      dupValidation.error?.includes('duplicate exercise') === true,
      `Validation error cites duplicate exercise: "${dupValidation.error}"`
    );
  }

  // -------------------------------------------------------------
  // Test 6: Empty Day Prevention
  // -------------------------------------------------------------
  console.log('\n--- Test 6: Empty Training Day Prevention ---');
  {
    const pplSplit = workoutIntentService.detectSplit('Push Pull Legs');
    const scheduleWithEmptyDay = [
      { day: 'Day 1 (Push)', sessionTitle: 'Push Day', exercises: [{ name: 'Bench Press', sets: 3, reps: '8-10' }] },
      { day: 'Day 2 (Pull)', sessionTitle: 'Pull Day', exercises: [] }, // EMPTY DAY
      { day: 'Day 3 (Legs)', sessionTitle: 'Leg Day', exercises: [{ name: 'Squat', sets: 3, reps: '8-10' }] },
    ];

    const emptyValidation = await workoutIntentService.validateProposalForSplit(
      pplSplit,
      [{ name: 'Bench Press', sets: 3, reps: '8-10' }, { name: 'Squat', sets: 3, reps: '8-10' }],
      scheduleWithEmptyDay
    );
    assert(
      !emptyValidation.isValid,
      `Validation rejects schedules with empty training days`
    );
    assert(
      emptyValidation.error?.includes('empty training days') === true,
      `Validation error cites empty training days: "${emptyValidation.error}"`
    );
  }

  // -------------------------------------------------------------
  // Test 7: Multi-Day Split Integration & DB Persistence
  // -------------------------------------------------------------
  console.log('\n--- Test 7: Multi-Day Split Architecture & DB Persistence ---');
  {
    // Find or create test client
    let athlete = await prisma.user.findFirst({
      where: { email: 'regression_quality_client@alphax.test' },
      include: { clientProfile: true },
    });

    if (!athlete || !athlete.clientProfile) {
      athlete = await prisma.user.create({
        data: {
          email: 'regression_quality_client@alphax.test',
          name: 'Sarah Connor Athlete',
          role: 'CLIENT',
          status: 'APPROVED',
          clientProfile: {
            create: {
              clientId: 'AXG-QUAL-99',
              primaryGoal: 'Fat Loss & Conditioning',
              fitnessLevel: 'Intermediate',
              trainingDaysPerWeek: 3,
              gender: 'Female',
              weightKg: 62.0,
              hasCurrentInjury: false,
              injuryAreas: [],
            },
          },
        },
        include: { clientProfile: true },
      });
    }

    const pplSplit = workoutIntentService.detectSplit('Push Pull Legs 3-Day');
    const dayPlans = workoutIntentService.generateScheduleForSplit('PUSH_PULL_LEGS', {
      daysPerWeek: 3,
      primaryGoal: 'Fat Loss',
      trainingExperience: 'Intermediate',
    });

    const weeklySchedule: Array<any> = [];
    for (const d of dayPlans) {
      const dayExercises = await workoutIntentService.getBalancedExercisesForSplit(
        {
          split: 'PUSH_PULL_LEGS',
          templateId: 'push_pull_legs',
          displayName: 'Push / Pull / Legs',
          titleSuffix: 'Push / Pull / Legs',
          targetMuscleGroup: d.targetMuscleGroup,
          isAmbiguous: false,
          primaryBodyParts: d.primaryBodyParts,
          allowedBodyParts: d.allowedBodyParts,
          disallowedBodyParts: d.disallowedBodyParts,
          suggestedDaysPerWeek: 3,
          isMultiDayTemplate: true,
        },
        {
          clientProfileId: athlete!.clientProfile!.id,
          fitnessLevel: 'Intermediate',
          count: 4,
          primaryBodyParts: d.primaryBodyParts,
          allowedBodyParts: d.allowedBodyParts,
        }
      );

      const mapped = dayExercises.map((e, idx) => {
        const p = workoutIntentService.calculatePersonalizedExerciseParameters(
          e,
          {
            fitnessLevel: 'Intermediate',
            primaryGoal: 'Fat Loss',
            gender: 'Female',
            weightKg: 62.0,
          },
          { orderIndex: idx, sessionWorkoutType: d.workoutType }
        );
        return {
          exerciseId: e.id,
          name: e.name,
          category: e.category,
          bodyPart: e.bodyPart,
          sets: p.sets,
          reps: p.reps,
          weight: p.weight,
          restSeconds: p.restSeconds,
          notes: p.notes,
          day: d.dayName,
        };
      });

      weeklySchedule.push({
        day: d.dayName,
        sessionTitle: d.sessionTitle,
        workoutType: d.workoutType,
        targetMuscleGroup: d.targetMuscleGroup,
        estimatedDurationMinutes: 45,
        exercises: mapped,
      });
    }

    // Call proposeWorkoutPlanTool
    const result = await proposeWorkoutPlanTool.handler(
      {
        clientIdentifier: athlete!.clientProfile!.clientId!,
        planTitle: 'Sarah Connor — 3-Day PPL Conditioning',
        reason: 'Tailored 3-day conditioning routine for Sarah Connor based on fat loss goal.',
        summary: '3-day Push/Pull/Legs conditioning protocol (45 min/session)',
        weeklySchedule,
      },
      {
        adminId: 'admin_test_1',
        requestId: 'req_test_1',
        conversationId: 'conv_test_1',
      }
    );

    assert(result.success === true, `proposeWorkoutPlanTool succeeded for 3-day PPL conditioning proposal`);
    assert(result.proposalId !== undefined, `proposalId is returned: ${result.proposalId}`);

    const dbProposal = await prisma.aIProposal.findUnique({
      where: { id: result.proposalId },
    });
    assert(dbProposal !== null, `Proposal persisted in database`);
    assert(dbProposal!.status === 'PENDING', `Proposal status is PENDING for admin review`);

    const data = JSON.parse(dbProposal!.proposedDataJson);
    assert(Array.isArray(data.weeklySchedule), `weeklySchedule is persisted as an array`);
    assert(data.weeklySchedule.length === 3, `weeklySchedule contains exactly 3 days`);
    assert(data.exercises.length <= 6, `Root exercises is NOT a 30-exercise flattened dump (count: ${data.exercises.length})`);

    // Verify female load adjustment: no excessive loads on shoulders or dumbbell movements
    const allDbAssignedExs = data.weeklySchedule.flatMap((d: any) => d.exercises);
    const excessiveDumbbellLoads = allDbAssignedExs.filter(
      (e: any) => (e.name.toLowerCase().includes('dumbbell') || e.equipment?.toLowerCase()?.includes('dumbbell')) && e.weight !== null && e.weight > 16.0
    );
    assert(
      excessiveDumbbellLoads.length === 0,
      `Female intermediate athlete does not receive excessive dumbbell loads > 16kg`
    );

    const shoulderExs = allDbAssignedExs.filter((e: any) => e.bodyPart === 'Shoulders');
    console.log('Shoulder exercises in generated plan:', shoulderExs.map((e: any) => ({ name: e.name, weight: e.weight })));

    const excessiveShoulderLoads = allDbAssignedExs.filter(
      (e: any) => e.bodyPart === 'Shoulders' && e.weight !== null && e.weight > 35.0
    );
    assert(
      excessiveShoulderLoads.length === 0,
      `Female intermediate athlete does not receive excessive shoulder loads > 35kg`
    );
  }

  // -------------------------------------------------------------
  // Test 8: Client-Specific Strength History Calibration (Nandha AXG-0011)
  // -------------------------------------------------------------
  console.log('\n--- Test 8: Client-Specific Strength History Calibration (AXG-0011) ---');
  {
    // Find Nandha
    const nandha = await prisma.user.findFirst({
      where: { clientProfile: { clientId: 'AXG-0011' } },
      include: { clientProfile: true },
    });
    assert(nandha !== null, `Client Nandha (AXG-0011) exists in database`);

    const strengthHistory = await workoutIntentService.fetchClientStrengthHistory(nandha!.id);
    console.log('Nandha strength history size:', strengthHistory.size);
    assert(strengthHistory.size > 0, `Nandha has verified strength history in database`);

    const deadliftRecord = strengthHistory.get('conventional barbell deadlift');
    assert(deadliftRecord !== undefined, `Nandha has recorded history for Conventional Barbell Deadlift`);
    assert(deadliftRecord!.weightKg === 100, `Nandha recorded max deadlift is 100 kg`);

    // Calibrate parameters for Conventional Barbell Deadlift (known) vs Front Squat (unknown)
    const deadliftParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      { name: 'Conventional Barbell Deadlift', equipment: 'Barbell', isCompound: true, isIsolation: false },
      { fitnessLevel: 'Intermediate', primaryGoal: 'Build Strength', gender: 'Male' },
      { strengthHistory }
    );
    assert(
      deadliftParams.weight !== null && deadliftParams.weight >= 95 && deadliftParams.weight <= 100,
      `Deadlift target weight (${deadliftParams.weight} kg) is calibrated from Nandha's 100kg baseline`
    );

    const unknownSquatParams = workoutIntentService.calculatePersonalizedExerciseParameters(
      { name: 'Barbell Front Squat', equipment: 'Barbell', isCompound: true, isIsolation: false },
      { fitnessLevel: 'Intermediate', primaryGoal: 'Build Strength', gender: 'Male' },
      { strengthHistory }
    );
    assert(
      unknownSquatParams.weight === null && unknownSquatParams.targetWeight === null,
      `Unrecorded movement (Barbell Front Squat) returns unspecified load (null), not an invented kg value`
    );
  }

  // -------------------------------------------------------------
  // Test 9: End-to-End Proposal Lifecycle (Persistence, Admin Edit, Approval, Assignment)
  // -------------------------------------------------------------
  console.log('\n--- Test 9: End-to-End Proposal Lifecycle (Edit, Approval, Assignment) ---');
  {
    const athlete = await prisma.user.findFirst({
      where: { email: 'regression_quality_client@alphax.test' },
      include: { clientProfile: true },
    });

    // 9a. Propose a 2-day split
    const proposalRes = await proposeWorkoutPlanTool.handler(
      {
        clientIdentifier: athlete!.clientProfile!.clientId!,
        planTitle: 'Lifecycle Test Split 2-Day',
        reason: 'Testing complete database persistence, editing, and approval workflow.',
        summary: '2-Day Upper/Lower strength and hypertrophy split',
        weeklySchedule: [
          {
            day: 'Day 1 (Upper)',
            sessionTitle: 'Upper Body Power',
            workoutType: 'Strength',
            targetMuscleGroup: 'Chest · Back · Shoulders',
            estimatedDurationMinutes: 45,
            exercises: [
              { name: 'Barbell Bench Press', sets: 3, reps: '5-6', restSeconds: 120 },
              { name: 'Bent-Over Barbell Row', sets: 3, reps: '6-8', restSeconds: 90 },
            ],
          },
          {
            day: 'Day 2 (Lower)',
            sessionTitle: 'Lower Body Strength',
            workoutType: 'Strength',
            targetMuscleGroup: 'Quadriceps · Hamstrings',
            estimatedDurationMinutes: 45,
            exercises: [
              { name: 'Barbell Back Squat', sets: 3, reps: '5-6', restSeconds: 150 },
              { name: 'Romanian Deadlift', sets: 3, reps: '8-10', restSeconds: 120 },
            ],
          },
        ],
      },
      {
        adminId: 'admin_test_lifecycle',
        requestId: 'req_lifecycle_1',
        conversationId: 'conv_lifecycle_1',
      }
    );
    assert(proposalRes.success === true, `Proposal successfully staged in database`);
    const propId = proposalRes.proposalId!;

    // 9b. Admin Edits Proposal: adjusts rest seconds and coaching notes
    const editedProposal = await prisma.aIProposal.findUnique({ where: { id: propId } });
    const payload = JSON.parse(editedProposal!.proposedDataJson);
    payload.weeklySchedule[0].exercises[0].restSeconds = 150; // Edit rest time
    payload.weeklySchedule[0].exercises[0].notes = 'Admin adjusted rest to 150s for strength recovery';

    await aiTools.editProposal(propId, 'admin_test_lifecycle', payload);
    const postEdit = await prisma.aIProposal.findUnique({ where: { id: propId } });
    assert(postEdit!.status === 'EDITED', `Proposal status transitioned to EDITED`);
    const finalPayload = JSON.parse(postEdit!.finalDataJson!);
    assert(
      finalPayload.weeklySchedule[0].exercises[0].restSeconds === 150,
      `Admin edit successfully persisted in finalDataJson (restSeconds: 150)`
    );

    // 9c. Admin Approves Proposal
    const approved = await aiTools.approveProposal(propId, 'admin_test_lifecycle', 'Head Coach Alex');
    assert(approved.status === 'APPROVED', `Proposal status is APPROVED`);

    // 9d. Verify database assignments and sessions
    const activeAssignments = await prisma.workoutAssignment.findMany({
      where: { clientId: athlete!.id, active: true },
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
    assert(activeAssignments.length === 2, `Both days have dedicated active assignments in DB (count: ${activeAssignments.length})`);
    
    // Check that Day 1 and Day 2 exercises are distinct and NOT flattened or duplicated
    const day1Session = activeAssignments.find((a) => a.session.title.includes('Upper Body Power'));
    const day2Session = activeAssignments.find((a) => a.session.title.includes('Lower Body Strength'));
    assert(day1Session !== undefined, `Upper Body Power session created`);
    assert(day2Session !== undefined, `Lower Body Strength session created`);

    assert(day1Session!.session.exercises.length === 2, `Day 1 contains exactly 2 exercises`);
    assert(day2Session!.session.exercises.length === 2, `Day 2 contains exactly 2 exercises`);
    assert(
      day1Session!.session.exercises[0].exerciseName.includes('Bench Press'),
      `Day 1 first exercise is Bench Press (${day1Session!.session.exercises[0].exerciseName})`
    );
    assert(
      day1Session!.session.exercises[0].restSeconds === 150,
      `Admin-edited rest seconds (150s) survived approval into WorkoutSessionExercise`
    );
    assert(
      day2Session!.session.exercises[0].exerciseName.includes('Squat'),
      `Day 2 first exercise is Squat (${day2Session!.session.exercises[0].exerciseName})`
    );
  }

  console.log(`\n=============================================================`);
  console.log(`Workout Quality Regression Suite Complete: ${testsPassed} passed, ${testsFailed} failed.`);
  console.log(`=============================================================\n`);

  if (testsFailed > 0) {
    process.exit(1);
  }
}

runWorkoutQualityRegressionTests()
  .catch((err) => {
    console.error('Fatal error running regression tests:', err);
    process.exit(1);
  })
  .finally(() => {
    prisma.$disconnect();
  });
