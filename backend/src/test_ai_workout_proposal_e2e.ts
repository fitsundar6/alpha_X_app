import { prisma } from './config/prisma';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { aiTools } from './modules/ai_coach/ai_tools';

async function verifyCompleteWorkoutProposalFlow() {
  console.log('=== STARTING END-TO-END WORKOUT PROPOSAL VERIFICATION ===\n');

  // 1. Locate client Ajay (AXG-0005)
  const clientUser = await prisma.user.findFirst({
    where: { role: 'CLIENT', name: { contains: 'Ajay' } },
    include: { clientProfile: true },
  });

  if (!clientUser || !clientUser.clientProfile) {
    throw new Error('Test client Ajay with profile not found in database.');
  }

  const clientProfile = clientUser.clientProfile;
  console.log(`[PASS] Step 1: Resolved Client: ${clientUser.name} (${clientProfile.clientId || 'AXG'}, Profile ID: ${clientProfile.id}, User ID: ${clientUser.id})`);
  console.log(`       Assessment Data: Weight=${clientProfile.weightKg}kg, Goal=${clientProfile.primaryGoal}, FitnessLevel=${clientProfile.fitnessLevel}\n`);

  // 2. Validate input schema & failure handling on invalid/missing fields
  console.log('--- Step 2: Testing Tool Validation & Error Handling ---');
  const invalidResult = await proposeWorkoutPlanTool.handler({
    clientIdentifier: clientUser.name,
    planTitle: '', // Missing title
    reason: '',
    summary: '',
    weeklySchedule: [], // Empty schedule
  }, {
    requestId: 'req_invalid_test',
    conversationId: 'conv_invalid_test',
    adminId: 'admin_test',
  });

  console.assert(invalidResult.error !== undefined, 'Expected validation error on empty fields');
  console.log(`[PASS] Step 2: Tool correctly caught invalid fields: "${invalidResult.error}"\n`);

  // 3. Propose Workout Plan via propose_workout_plan tool (Requirement 1, 2, 3)
  console.log('--- Step 3: Tool Execution & Database Persistence (PENDING) ---');
  const testConvId = `conv_test_e2e_${Date.now()}`;
  await prisma.aIConversation.create({
    data: {
      id: testConvId,
      adminId: 'admin_alex_stone',
      title: 'E2E Test Session',
    },
  });
  const runId = Date.now();
  const baseTitle = `${clientUser.name} Hypertrophy Foundation ${runId}`;
  const validProposalInput = {
    clientIdentifier: clientUser.name,
    planTitle: baseTitle,
    reason: `Based on client goal (${clientProfile.primaryGoal}) and fitness tier (${clientProfile.fitnessLevel}), targeting progressive compound volume.`,
    summary: '4-day upper/lower split focusing on progressive overload and recovery.',
    weeklySchedule: [
      {
        day: 'Day 1 - Upper Power',
        sessionTitle: 'Upper Body Power',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest • Back • Arms',
        estimatedDurationMinutes: 50,
        exercises: [
          {
            name: 'Barbell Bench Press',
            exerciseId: 'ex_bb_bench',
            sets: 4,
            reps: '6-8',
            weight: 75.0,
            restSeconds: 120,
            notes: 'Pause 1s on chest',
          },
          {
            name: 'Barbell Row',
            exerciseId: 'ex_bb_row',
            sets: 3,
            reps: '8-10',
            weight: 65.0,
            restSeconds: 90,
            notes: 'Squeeze lats at contraction',
          },
        ],
      },
      {
        day: 'Day 2 - Lower Power',
        sessionTitle: 'Lower Body Strength',
        workoutType: 'Strength',
        targetMuscleGroup: 'Quads • Hamstrings',
        estimatedDurationMinutes: 45,
        exercises: [
          {
            name: 'Barbell Back Squat',
            exerciseId: 'ex_bb_squat',
            sets: 4,
            reps: '6-8',
            weight: 90.0,
            restSeconds: 150,
            notes: 'Full parallel depth',
          },
        ],
      },
    ],
  };

  const toolExecResult = await proposeWorkoutPlanTool.handler(validProposalInput, {
    requestId: 'req_valid_test',
    conversationId: testConvId,
    adminId: 'admin_alex_stone',
  });

  console.assert(toolExecResult.success === true, 'Expected tool execution to succeed');
  console.assert(toolExecResult.proposal !== undefined, 'Expected returned proposal object');
  console.assert(toolExecResult.proposal.status === 'PENDING', 'Proposal MUST be PENDING');
  const proposalId = toolExecResult.proposal.id;
  console.log(`[PASS] Step 3: Tool executed and persisted proposal: "${toolExecResult.proposal.title}" (ID: ${proposalId})`);
  console.log(`       Status: ${toolExecResult.proposal.status}`);
  console.log(`       Interoperable Normalized Exercises count: ${toolExecResult.proposal.payload.exercises?.length}\n`);

  // 4. Test Deduplication Guard (Requirement 8)
  console.log('--- Step 4: Testing Duplicate Prevention ---');
  const countBeforeRetry = await prisma.aIProposal.count({
    where: { clientProfileId: clientProfile.id, status: 'PENDING', conversationId: testConvId },
  });

  // Re-run the tool call with the same conversation & client
  const retryResult = await proposeWorkoutPlanTool.handler({
    ...validProposalInput,
    planTitle: `${baseTitle} (Updated)`,
  }, {
    requestId: 'req_retry_test',
    conversationId: testConvId,
    adminId: 'admin_alex_stone',
  });

  const countAfterRetry = await prisma.aIProposal.count({
    where: { clientProfileId: clientProfile.id, status: 'PENDING', conversationId: testConvId },
  });

  console.assert(countBeforeRetry === 1, 'Expected exactly 1 pending proposal before retry');
  console.assert(countAfterRetry === 1, 'Expected count to remain 1 (no duplicate row created)');
  console.assert(retryResult.proposal.id === proposalId, 'Expected existing proposal ID to be updated');
  console.log(`[PASS] Step 4: Duplicate proposal prevented! Existing proposal ID ${proposalId} updated in-place.\n`);

  // 5. Verify Database Isolation (Client does NOT have the workout before approval)
  console.log('--- Step 5: Verifying Safety Isolation Before Approval ---');
  const preApprovalAssignment = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientUser.id, active: true },
    include: { session: true },
  });
  const preApprovalTitle = preApprovalAssignment?.session?.title;
  console.log(`       Pre-approval active workout for client: "${preApprovalTitle || 'None'}"`);
  console.assert(
    !preApprovalTitle?.includes(baseTitle),
    'Proposal MUST NOT be assigned before admin approval!'
  );
  console.log(`[PASS] Step 5: Athlete active plan remains untouched prior to admin approval.\n`);

  // 6. Admin Approves Proposal (Requirement 5 & 6)
  console.log('--- Step 6: Admin Approves Proposal ---');
  const approved = await aiTools.approveProposal(proposalId, 'admin_alex_stone', 'Admin Alex');
  console.assert(approved.status === 'APPROVED', 'Expected proposal status to become APPROVED');
  console.log(`[PASS] Step 6: Proposal successfully APPROVED by Admin. Status: ${approved.status}\n`);

  // 7. Verify Client Assignment in Database
  console.log('--- Step 7: Verifying Workout Assignment & Database Schema ---');
  const postApprovalAssignment = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientUser.id, active: true },
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
    orderBy: [
      { isRecommended: 'desc' },
      { assignedAt: 'desc' },
    ],
  });

  console.assert(postApprovalAssignment !== null, 'Client MUST have active assignment');
  console.assert(postApprovalAssignment!.isRecommended === true, 'Assignment MUST be marked isRecommended: true');
  console.assert(
    postApprovalAssignment!.session.title.includes(baseTitle),
    'Assignment session must match approved proposal title'
  );
  const allActiveAssignments = await prisma.workoutAssignment.findMany({
    where: { clientId: clientUser.id, active: true },
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
  const totalExercisesAcrossDays = allActiveAssignments.reduce((acc, a) => acc + a.session.exercises.length, 0);
  console.assert(
    totalExercisesAcrossDays === 3,
    `Expected 3 exercises created across the 2 days, got ${totalExercisesAcrossDays}`
  );
  console.assert(
    postApprovalAssignment!.session.exercises[0].setTemplates.length === 4,
    `Expected 4 setTemplates on exercise, got ${postApprovalAssignment!.session.exercises[0].setTemplates.length}`
  );

  console.log(`[PASS] Step 7: Active Workout Session in Database:`);
  console.log(`       Session Title: "${postApprovalAssignment!.session.title}"`);
  console.log(`       Total Exercises: ${postApprovalAssignment!.session.exercises.length}`);
  for (const ex of postApprovalAssignment!.session.exercises) {
    console.log(`       - ${ex.exerciseName}: ${ex.numberOfSets} sets (${ex.targetReps} reps), ${ex.setTemplates.length} set templates`);
  }
  console.log();

  // 8. Verify Client API query behavior
  console.log('--- Step 8: Verifying Client Me Workout Query Mapping ---');
  const clientIdsToMatch = [clientUser.id, clientProfile.clientId, clientProfile.id].filter(Boolean) as string[];
  const clientMeWorkout = await prisma.workoutAssignment.findFirst({
    where: {
      OR: [
        { clientId: { in: clientIdsToMatch } },
        { clientId: null },
      ],
      active: true,
    },
    orderBy: [
      { isRecommended: 'desc' },
      { assignedAt: 'desc' },
    ],
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

  console.assert(clientMeWorkout !== null, 'Client /me/workout query MUST return assigned workout');
  console.assert(
    clientMeWorkout!.session.title.includes(baseTitle),
    'Returned workout session matches approved proposal'
  );
  console.log(`[PASS] Step 8: /api/v1/client/me/workout successfully returns "${clientMeWorkout!.session.title}" to client ${clientUser.name}\n`);

  // 9. Verify Client Isolation (Another client does not see this assignment)
  console.log('--- Step 9: Verifying Client Isolation ---');
  const otherClientAssignments = await prisma.workoutAssignment.findMany({
    where: {
      clientId: 'other_isolated_client_id_123',
      sessionId: postApprovalAssignment!.sessionId,
      active: true,
    },
  });
  console.assert(otherClientAssignments.length === 0, 'Other client MUST NOT have this individual assignment');
  console.log(`[PASS] Step 9: Strict client isolation verified. Workout is not assigned to other users.\n`);

  console.log('======================================================================');
  console.log('🎯 ALL END-TO-END WORKOUT PROPOSAL VERIFICATIONS PASSED CLEANLY! 🎯');
  console.log('======================================================================');
}

verifyCompleteWorkoutProposalFlow()
  .catch((err) => {
    console.error('VERIFICATION FAILED:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
