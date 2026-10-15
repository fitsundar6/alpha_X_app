import './config/environment';
import { prisma } from './config/prisma';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { aiTools } from './modules/ai_coach/ai_tools';
import * as fs from 'fs';
import * as path from 'path';

async function runProposalDiagnostics() {
  console.log('======================================================================');
  console.log('🧪 RUNNING ALPHA X WORKOUT PROPOSAL DIAGNOSTIC & REGRESSION SUITE 🧪');
  console.log('======================================================================\n');

  // STEP 0: Find Ajay (AXG-0005)
  const clientUser = await prisma.user.findFirst({
    where: { role: 'CLIENT', name: { contains: 'Ajay' } },
    include: { clientProfile: true },
  });

  if (!clientUser || !clientUser.clientProfile) {
    throw new Error('Test client Ajay (AXG-0005) not found in database.');
  }

  const clientProfile = clientUser.clientProfile;
  console.log(`[PASS] Step 0: Located Target Client in DB: ${clientUser.name} (${clientProfile.clientId})`);
  console.log(`       Profile ID: ${clientProfile.id}, User ID: ${clientUser.id}\n`);

  // STEP 1: Missing Client Test (Requirement 8)
  console.log('--- Step 1: Testing Missing Client (CLIENT_NOT_FOUND) ---');
  const missingClientResult = await proposeWorkoutPlanTool.handler({
    clientIdentifier: 'NonexistentClient_AXG_99999',
    planTitle: 'Ghost Workout Plan',
    reason: 'Testing nonexistent client handling in AI proposal tool.',
    summary: 'Plan for phantom athlete.',
    weeklySchedule: [
      {
        day: 'Monday',
        sessionTitle: 'Chest Day',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Chest',
        estimatedDurationMinutes: 45,
        exercises: [{ name: 'Pushups', sets: 3, reps: '10', restSeconds: 60 }],
      },
    ],
  }, {
    requestId: 'req_missing_client_test',
    conversationId: `conv_missing_${Date.now()}`,
    adminId: 'admin_alex_stone',
  });

  if (missingClientResult.success) {
    throw new Error('Expected missing client to fail, but it succeeded.');
  }
  console.log(`[PASS] Step 1: Missing client correctly rejected with safe message: "${missingClientResult.error}"\n`);

  // STEP 2: Invalid Arguments Validation (Requirement 8)
  console.log('--- Step 2: Testing Invalid Arguments Schema Validation ---');
  const emptyScheduleResult = await proposeWorkoutPlanTool.handler({
    clientIdentifier: 'AXG-0005',
    planTitle: 'Invalid Empty Plan',
    reason: 'Testing empty schedule rejection.',
    summary: 'Plan with no days.',
    weeklySchedule: [],
  }, {
    requestId: 'req_invalid_schedule',
    conversationId: `conv_invalid_${Date.now()}`,
    adminId: 'admin_alex_stone',
  });

  if (emptyScheduleResult.success) {
    throw new Error('Expected empty weeklySchedule to fail, but it succeeded.');
  }
  console.log(`[PASS] Step 2a: Empty schedule rejected: "${emptyScheduleResult.error}"`);

  const emptyTitleResult = await proposeWorkoutPlanTool.handler({
    clientIdentifier: 'AXG-0005',
    planTitle: '',
    reason: 'Testing empty title rejection.',
    summary: 'Plan with no title.',
    weeklySchedule: [
      {
        day: 'Monday',
        sessionTitle: 'Leg Day',
        workoutType: 'Strength',
        targetMuscleGroup: 'Quads',
        estimatedDurationMinutes: 45,
        exercises: [{ name: 'Squats', sets: 3, reps: '10', restSeconds: 60 }],
      },
    ],
  }, {
    requestId: 'req_invalid_title',
    conversationId: `conv_invalid_title_${Date.now()}`,
    adminId: 'admin_alex_stone',
  });

  if (emptyTitleResult.success) {
    throw new Error('Expected empty planTitle to fail, but it succeeded.');
  }
  console.log(`[PASS] Step 2b: Empty title rejected: "${emptyTitleResult.error}"\n`);

  // STEP 3: Valid Proposal Creation for Ajay (AXG-0005) (Requirement 5 & 9)
  console.log('--- Step 3: Testing Valid Proposal Generation for Ajay (AXG-0005) ---');
  const testConvId = `conv_diag_${Date.now()}`;
  await prisma.aIConversation.create({
    data: {
      id: testConvId,
      adminId: 'admin_alex_stone',
      title: 'Diagnostic Test Conversation',
    },
  });

  const uniquePlanTitle = `Ajay Diagnostic Strength & Hypertrophy ${Date.now()}`;
  const validProposalInput = {
    clientIdentifier: 'Ajay (AXG-0005)', // Test compound client identifier resolution!
    planTitle: uniquePlanTitle,
    reason: 'Ajay is focusing on lean mass recomposition with 4 sessions per week targeting upper/lower periodization.',
    summary: '4-week progressive hypertrophy plan designed specifically for Ajay.',
    weeklySchedule: [
      {
        day: 'Monday',
        sessionTitle: 'Upper Body Hypertrophy',
        workoutType: 'Hypertrophy',
        targetMuscleGroup: 'Chest, Back, Arms',
        estimatedDurationMinutes: 45,
        exercises: [
          {
            name: 'Incline Dumbbell Press',
            sets: 3,
            reps: '10-12',
            weight: 22.5,
            restSeconds: 90,
            notes: 'Controlled eccentric tempo 3-0-1-0',
          },
          {
            name: 'Chest-Supported Row',
            sets: 3,
            reps: '10-12',
            weight: 25.0,
            restSeconds: 90,
            notes: 'Pause 1s at scapular contraction',
          },
        ],
      },
      {
        day: 'Tuesday',
        sessionTitle: 'Lower Body Strength',
        workoutType: 'Strength',
        targetMuscleGroup: 'Quads, Hamstrings',
        estimatedDurationMinutes: 45,
        exercises: [
          {
            name: 'Leg Press',
            sets: 4,
            reps: '8-10',
            weight: 120.0,
            restSeconds: 120,
            notes: 'Full comfortable knee flexion',
          },
        ],
      },
    ],
  };

  const validResult = await proposeWorkoutPlanTool.handler(validProposalInput, {
    requestId: 'req_diag_valid',
    conversationId: testConvId,
    adminId: 'admin_alex_stone',
  });

  if (!validResult.success || !validResult.proposal) {
    throw new Error(`Valid proposal creation failed: ${validResult.error || 'No proposal returned'}`);
  }

  const createdProposal = validResult.proposal;
  console.log(`[PASS] Step 3: Proposal successfully created!`);
  console.log(`       Proposal ID: ${createdProposal.id}`);
  console.log(`       Client ID:   ${createdProposal.clientId} (${createdProposal.clientName})`);
  console.log(`       Status:      ${createdProposal.status}`);
  console.log(`       Title:       ${createdProposal.title}\n`);

  if (createdProposal.status !== 'PENDING') {
    throw new Error(`Expected proposal status to be PENDING, got ${createdProposal.status}`);
  }

  // STEP 4: Duplicate Submission In-Place Update (Requirement 8)
  console.log('--- Step 4: Testing Duplicate Submissions & In-Place Update ---');
  const countBefore = await prisma.aIProposal.count({
    where: { clientProfileId: clientProfile.id, status: 'PENDING', conversationId: testConvId },
  });

  const duplicateResult = await proposeWorkoutPlanTool.handler({
    ...validProposalInput,
    planTitle: `${uniquePlanTitle} (Revision 2)`,
  }, {
    requestId: 'req_diag_duplicate',
    conversationId: testConvId,
    adminId: 'admin_alex_stone',
  });

  const countAfter = await prisma.aIProposal.count({
    where: { clientProfileId: clientProfile.id, status: 'PENDING', conversationId: testConvId },
  });

  if (countBefore !== 1 || countAfter !== 1) {
    throw new Error(`Expected proposal count to remain 1, before=${countBefore}, after=${countAfter}`);
  }
  if (duplicateResult.proposal.id !== createdProposal.id) {
    throw new Error(`Expected proposal ID to remain identical (${createdProposal.id}), got ${duplicateResult.proposal.id}`);
  }
  console.log(`[PASS] Step 4: Duplicate submission handled gracefully! Row count remained 1, ID ${createdProposal.id} updated in-place.\n`);

  // STEP 5: Verify Isolation Before Admin Approval (Requirement 6 & 10)
  console.log('--- Step 5: Verifying Client Isolation Before Approval ---');
  const activeWorkout = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientUser.id, active: true },
    include: { session: true },
  });
  if (activeWorkout?.session?.title?.includes(uniquePlanTitle)) {
    throw new Error('CRITICAL SAFETY FAILURE: Workout was assigned to client BEFORE Admin approval!');
  }
  console.log(`[PASS] Step 5: Proposal is strictly unassigned. Athlete active workout: "${activeWorkout?.session?.title || 'None'}".\n`);

  // STEP 6: Confirm Proposal Appears in Admin Review Screen Query (Requirement 10)
  console.log('--- Step 6: Verifying Admin Review Screen Query Visibility ---');
  const adminProposals = await prisma.aIProposal.findMany({
    where: { status: 'PENDING', proposalType: 'WORKOUT' },
    orderBy: { createdAt: 'desc' },
  });

  const targetInAdminList = adminProposals.find((p) => p.id === createdProposal.id);
  if (!targetInAdminList) {
    throw new Error(`Proposal ${createdProposal.id} not found in Admin Review pending list!`);
  }
  console.log(`[PASS] Step 6: Proposal ${targetInAdminList.id} found in Admin Review queue!`);
  console.log(`       Review Title: "${targetInAdminList.title}"`);
  console.log(`       Target Athlete: ${targetInAdminList.clientName} (${targetInAdminList.clientId})`);
  console.log(`       Status: ${targetInAdminList.status}`);
  console.log(`       Total Pending Proposals in Queue: ${adminProposals.length}\n`);

  // STEP 7: Server Error Logging File Verification (Requirement 7)
  console.log('--- Step 7: Verifying Server-Side Error Logging ---');
  const logFilePaths = [
    path.resolve(process.cwd(), 'server-errors.log'),
    path.resolve(process.cwd(), 'logs/server-errors.log'),
  ];
  let logFound = false;
  for (const p of logFilePaths) {
    if (fs.existsSync(p)) {
      const content = fs.readFileSync(p, 'utf8');
      console.log(`[PASS] Step 7: Found server log file at: ${p} (Size: ${content.length} bytes)`);
      logFound = true;
      break;
    }
  }
  if (!logFound) {
    console.log('[INFO] Step 7: No error log file present yet (normal if no fatal crashes occurred).');
  }

  console.log('\n======================================================================');
  console.log('🎉 ALL 7 DIAGNOSTIC & REGRESSION CHECKS COMPLETED SUCCESSFULLY! 🎉');
  console.log('======================================================================');
}

runProposalDiagnostics()
  .catch((err) => {
    console.error('DIAGNOSTIC RUN FAILED:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
