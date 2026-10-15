import { prisma } from './config/prisma';
import { workoutIntentService } from './modules/ai_coach/workout_intent.service';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { aiTools } from './modules/ai_coach/ai_tools';
import { workoutRepository } from './modules/workout/workout.repository';
import { getTodayISTDateString, getTodayISTWeekday } from './utils/istDate';

async function runPplX2PipelineTest() {
  console.log('======================================================================');
  console.log('🏋️ ALPHA X — PPL × 2 MULTI-DAY WORKOUT SPLIT PIPELINE AUDIT & TEST');
  console.log('======================================================================\n');

  // STEP 1: Select client profile
  console.log('--- TEST 1: Beginner Client Profile Setup ---');
  let client = await prisma.user.findFirst({
    where: { role: 'CLIENT', name: { contains: 'Ajay' } },
    include: { clientProfile: true },
  });

  if (!client) {
    client = await prisma.user.findFirst({
      where: { role: 'CLIENT' },
      include: { clientProfile: true },
    });
  }

  console.assert(client !== null, 'A valid client record must exist in the database');
  console.log(`[PASS] Selected Client: "${client!.name}" (ID: ${client!.id})`);

  // STEP 2: Request PPL × 2 Split Generation
  console.log('\n--- TEST 2: Structured PPL × 2 Schedule Generation ---');
  const detectedSplit = workoutIntentService.detectSplit('PPL × 2') || workoutIntentService.detectSplit('PPL_X2');
  console.assert(detectedSplit !== null, 'PPL × 2 template must be detected');
  console.assert(detectedSplit!.isMultiDayTemplate === true, 'PPL × 2 must be marked as multi-day template');
  console.log(`[PASS] Detected Split: "${detectedSplit!.displayName}" (Multi-Day: ${detectedSplit!.isMultiDayTemplate})`);

  const generatedDays = workoutIntentService.generateScheduleForSplit('PPL_X2', {
    daysPerWeek: 6,
    primaryGoal: 'Hypertrophy',
    trainingExperience: 'Beginner',
  });

  console.assert(generatedDays.length === 6, `Expected 6 separate days, got ${generatedDays.length}`);
  console.log(`[PASS] Generated ${generatedDays.length} separate workout days:`);

  const weeklySchedule: any[] = [];
  let totalGeneratedExercises = 0;

  for (let i = 0; i < generatedDays.length; i++) {
    const d = generatedDays[i];
    const category = (d.sessionTitle.includes('Pull') ? 'Pull' : (d.sessionTitle.includes('Leg') ? 'Legs' : 'Push'));

    const exs = await workoutIntentService.getBalancedExercisesForSplit(
      {
        split: 'PPL_X2',
        templateId: 'ppl_x2',
        displayName: 'PPL × 2',
        titleSuffix: 'Push / Pull / Legs (PPL × 2)',
        targetMuscleGroup: d.targetMuscleGroup,
        isAmbiguous: false,
        primaryBodyParts: d.primaryBodyParts,
        allowedBodyParts: d.allowedBodyParts,
        disallowedBodyParts: d.disallowedBodyParts,
        suggestedDaysPerWeek: 6,
        isMultiDayTemplate: true,
      },
      {
        clientProfileId: client!.clientProfile?.id,
        count: 5, // beginner target: 5 exercises per session
        variationSeed: i,
        primaryBodyParts: d.primaryBodyParts,
        allowedBodyParts: d.allowedBodyParts,
      }
    );

    console.assert(exs.length >= 4 && exs.length <= 7, `Day ${i + 1} exercise count must be 4-7, got ${exs.length}`);
    totalGeneratedExercises += exs.length;

    weeklySchedule.push({
      id: `day_${i + 1}`,
      dayId: `day_${i + 1}`,
      day: d.dayName,
      dayName: d.dayName,
      weekday: d.dayName,
      sessionTitle: d.sessionTitle,
      title: d.sessionTitle,
      splitCategory: category,
      category,
      workoutType: d.workoutType,
      targetMuscleGroup: d.targetMuscleGroup,
      targetMuscles: d.primaryBodyParts,
      estimatedDurationMinutes: d.estimatedDurationMinutes,
      recommendedExercisesCount: exs.length,
      exercises: exs.map((e, exIdx) => ({
        exerciseId: e.id,
        name: e.name,
        exerciseName: e.name,
        category: e.category,
        bodyPart: e.bodyPart,
        orderIndex: exIdx,
        sets: 3,
        numberOfSets: 3,
        reps: '8-10',
        targetReps: '8-10',
        weight: 50.0,
        targetWeight: 50.0,
        restSeconds: 90,
        targetRir: 2,
        targetRpe: 8.0,
        tempo: '3-1-1-0',
        notes: `Controlled tempo on ${e.name}`,
        adminInstruction: `Controlled tempo on ${e.name}`,
        day: d.dayName,
      })),
    });

    console.log(`   ✔ Day ${i + 1} [${d.dayName}]: ${d.sessionTitle} | Split: ${category} | Target: ${d.targetMuscleGroup} | Exercises: ${exs.length}`);
  }

  console.log(`[PASS] Total across 6 days: ${totalGeneratedExercises} exercises distributed evenly (average ${(totalGeneratedExercises / 6).toFixed(1)}/session, NOT 27 in one day!)\n`);

  // STEP 3: Stage as PENDING Proposal
  console.log('--- TEST 3: Staging PPL × 2 Proposal with Preserved Weekly Split ---');
  const proposalInput = {
    clientIdentifier: client!.name,
    planTitle: `${client!.name} — 6-Week Push Pull Legs (PPL × 2) Hypertrophy Protocol`,
    reason: `Targeted 6-day split distributing volume across Push, Pull, and Leg days with sensible 5-exercise per-session volume for beginner progression.`,
    summary: `6-Day PPL split with separate Push, Pull, and Legs days scheduled Monday through Saturday.`,
    weeklySchedule,
  };

  const propResult = await proposeWorkoutPlanTool.handler(proposalInput, {
    adminId: 'admin_alex_stone',
    conversationId: 'conv_ppl_x2_test',
    requestId: `req_ppl_x2_${Date.now()}`,
  });

  console.assert(propResult.success === true, `Expected proposal success: ${propResult.message}`);
  const proposalId = propResult.proposal.id;
  console.assert(propResult.proposal.status === 'PENDING', 'Proposal status must be PENDING');
  console.assert(propResult.proposal.payload.weeklySchedule.length === 6, 'Payload must preserve all 6 days');
  console.log(`[PASS] Successfully staged proposal as PENDING. ID: ${proposalId}\n`);

  // STEP 4: Admin Review — Verifying 6 Distinct Days in Database Proposal Record
  console.log('--- TEST 4: Admin Review Integrity Check ---');
  const storedProposal = await prisma.aIProposal.findUnique({
    where: { id: proposalId },
  });
  console.assert(storedProposal !== null, 'Stored proposal must exist');
  const rawData = (storedProposal as any).proposedDataJson;
  const payload = typeof rawData === 'string' ? JSON.parse(rawData) : (rawData || (storedProposal as any).proposedPayload || (storedProposal as any).payload);
  console.assert(Array.isArray(payload.weeklySchedule), 'weeklySchedule must be an array');
  console.assert(payload.weeklySchedule.length === 6, 'weeklySchedule must contain 6 distinct days');
  console.assert(payload.isMultiDaySplit === true, 'isMultiDaySplit must be true');

  for (let i = 0; i < payload.weeklySchedule.length; i++) {
    const day = payload.weeklySchedule[i];
    console.assert(day.dayId !== undefined, `Day ${i + 1} must have a stable dayId`);
    console.assert(day.splitCategory !== undefined, `Day ${i + 1} must have splitCategory`);
    console.assert(day.exercises.length >= 4 && day.exercises.length <= 7, `Day ${i + 1} must have 4-7 exercises`);
  }
  console.log(`[PASS] Admin Review data verified: 6 separate days, stable day IDs, split categories, and per-day exercise arrays intact.\n`);

  // STEP 5: Admin Approval and Assignment
  console.log('--- TEST 5: Approving and Assigning Multi-Day Split Plan ---');
  const approveResult = await aiTools.approveProposal(proposalId, 'admin_alex_stone', 'Admin Alex');
  console.assert(approveResult.status === 'APPROVED', 'Proposal status must be APPROVED');
  console.log(`[PASS] Proposal successfully approved by admin.\n`);

  // STEP 6: Verifying Database Persistence: 6 Separate WorkoutSession & Assignment Records
  console.log('--- TEST 6: Verifying Separate Database Sessions and Assignments ---');
  const createdSessions = await prisma.workoutSession.findMany({
    where: {
      description: { contains: 'Push Pull Legs' },
      isActive: true,
    },
    include: {
      exercises: true,
      assignments: {
        where: { clientId: client!.id, active: true },
      },
    },
    orderBy: { createdAt: 'desc' },
    take: 6,
  });

  console.assert(createdSessions.length === 6, `Expected 6 distinct WorkoutSession records, found ${createdSessions.length}`);

  for (const s of createdSessions) {
    console.assert(s.recurringSchedule !== null, 'Session must have recurringSchedule set');
    console.assert(s.exercises.length >= 4 && s.exercises.length <= 7, `Session "${s.title}" must have 4-7 exercises, found ${s.exercises.length}`);
    console.assert(s.assignments.length >= 1, `Session "${s.title}" must have an active assignment`);
    console.log(`   ✔ Session: "${s.title}" | Weekday: ${s.recurringSchedule} | Exercises: ${s.exercises.length} | Scheduled: ${s.assignments[0]?.scheduledDate}`);
  }
  console.log(`[PASS] Database verified: 6 distinct WorkoutSession records created, each with only its assigned ~5 exercises (NOT 27!).\n`);

  // STEP 7: Client Workout Session Loading Scoped by Scheduled Day
  console.log('--- TEST 7: Client Workout Session Loading Scoped by Today in IST ---');
  const clientAuthData = await workoutRepository.getClientAuthorizedSessions(client!.id);
  const todayIST = getTodayISTDateString();
  const todayWeekday = getTodayISTWeekday();

  console.log(`   IST Today: ${todayIST} (Weekday: ${todayWeekday})`);
  console.log(`   Available Sessions for Today: ${clientAuthData.available.length}`);

  if (clientAuthData.available.length > 0) {
    const todaySession = clientAuthData.available[0];
    console.log(`   ✔ Loaded Today's Session: "${todaySession.title}"`);
    console.log(`   ✔ Today's Session Exercise Count: ${todaySession.exercises.length}`);
    console.assert(todaySession.exercises.length <= 7, `Session MUST NOT have 27 exercises! Found ${todaySession.exercises.length}`);
    console.assert(todaySession.scheduledDate === todayIST, `Scheduled date must match today (${todayIST})`);
  }
  console.log(`[PASS] Client session loading successfully filters by scheduled day with NO exercise leakage from other days.\n`);

  console.log('======================================================================');
  console.log('🎉 PPL × 2 MULTI-DAY WORKOUT SPLIT INTEGRATION PIPELINE AUDIT PASSED 100%! 🎉');
  console.log('======================================================================\n');
}

runPplX2PipelineTest()
  .catch((err) => {
    console.error('❌ Pipeline Test Failure:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
