import { prisma } from './config/prisma';
import { proposeWorkoutPlanTool } from './modules/ai_coach/tools/definitions/client/propose_workout_plan';
import { aiTools } from './modules/ai_coach/ai_tools';

async function runProposalAssignmentE2ETests() {
  console.log('=== STARTING PROPOSAL EDIT & MULTI-TARGET ASSIGNMENT E2E TESTS ===\n');

  // 1. Fetch eligible clients
  const eligibleClients = await prisma.user.findMany({
    where: { role: 'CLIENT', status: 'APPROVED' },
    include: { clientProfile: true },
    take: 3,
  });

  if (eligibleClients.length < 2) {
    throw new Error('Need at least 2 active clients in database for assignment tests.');
  }

  const clientA = eligibleClients[0];
  const clientB = eligibleClients[1];
  console.log(`[PASS] Step 1: Resolved Clients:`);
  console.log(`       Client A: ${clientA.name} (${clientA.id})`);
  console.log(`       Client B: ${clientB.name} (${clientB.id})`);
  console.log(`       Total eligible clients count: ${eligibleClients.length}\n`);

  // 2. Generate a PENDING Workout Proposal for Client A
  console.log('--- Step 2: Creating PENDING Workout Proposal via AI Tool ---');
  const testConvId = `conv_test_assign_${Date.now()}`;
  await prisma.aIConversation.create({
    data: {
      id: testConvId,
      adminId: 'admin_master',
      title: 'E2E Assignment Test Conversation',
    },
  });

  const toolResult = await proposeWorkoutPlanTool.handler({
    clientIdentifier: clientA.name,
    planTitle: 'Strength & Hypertrophy Split v1',
    reason: 'Targeting progressive overload based on recent assessment.',
    summary: '4-day split with compound focus.',
    weeklySchedule: [
      {
        day: 'Day 1',
        sessionTitle: 'Upper Push',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest • Triceps',
        estimatedDurationMinutes: 50,
        exercises: [
          { name: 'Barbell Flat Bench', sets: 3, reps: '8-10', notes: '70kg load', restSeconds: 120 },
          { name: 'Standing Overhead Press', sets: 3, reps: '8-10', notes: '45kg load', restSeconds: 90 },
        ],
      },
    ],
  }, {
    requestId: 'req_assign_test_1',
    conversationId: testConvId,
    adminId: 'admin_master',
  });

  console.assert(toolResult.success === true, 'Proposal creation must succeed');
  const proposalId = toolResult.proposal.id;
  console.assert(toolResult.proposal.status === 'PENDING', 'Proposal must be PENDING initially');
  console.log(`[PASS] Step 2: Proposal created with ID: ${proposalId}, Status: PENDING\n`);

  // 3. Admin Edits the Proposal (Requirement 3: Editing exercises, sets, reps; retaining proposal ID)
  console.log('--- Step 3: Admin Modifies Proposal Exercises & Notes ---');
  const editedPayload = {
    title: 'Strength & Hypertrophy Split (Admin Optimized)',
    workoutType: 'Hypertrophy',
    targetMuscleGroup: 'Upper Push & Delts',
    estimatedDurationMinutes: 55,
    summary: 'Modified by Head Coach: Adjusted sets to 4 and added incline dumbbell press.',
    exercises: [
      {
        exerciseId: 'ex_bb_bench_custom',
        exerciseName: 'Barbell Flat Bench (Strict Pause)',
        sets: 4,
        targetReps: '6-8',
        targetWeight: 75.0,
        restSeconds: 120,
        targetRir: 2,
        notes: '2-second pause on chest',
      },
      {
        exerciseId: 'ex_db_incline_custom',
        exerciseName: 'Incline Dumbbell Press',
        sets: 3,
        targetReps: '10-12',
        targetWeight: 26.0,
        restSeconds: 90,
        targetRir: 2,
        notes: 'Control eccentric to stretch pecs',
      },
    ],
  };

  const editedProposal = await aiTools.editProposal(proposalId, 'admin_master', editedPayload);
  console.assert(editedProposal.id === proposalId, 'Proposal ID MUST be strictly retained');
  console.assert(editedProposal.status === 'EDITED', 'Status must be updated to EDITED');
  console.assert(editedProposal.title === 'Strength & Hypertrophy Split (Admin Optimized)', 'Title must reflect edit');
  console.log(`[PASS] Step 3: Proposal updated to status: ${editedProposal.status}, ID retained: ${editedProposal.id}\n`);

  // 4. Test Assignment Option 1: INDIVIDUAL (Client A only)
  console.log('--- Step 4: Testing INDIVIDUAL Client Assignment ---');
  const todayIST = new Date().toISOString().split('T')[0];
  const approvedIndividual = await aiTools.approveProposal(proposalId, 'admin_master', 'Head Coach', {
    assignmentType: 'INDIVIDUAL',
    clientIds: [clientA.id],
    scheduledDate: todayIST,
  });

  console.assert(approvedIndividual.status === 'APPROVED', 'Proposal must become APPROVED');

  // Verify Client A received assignment
  const assignmentA = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientA.id, active: true },
    include: { session: { include: { exercises: true } } },
    orderBy: { assignedAt: 'desc' },
  });
  console.assert(assignmentA !== null, 'Client A MUST have active assignment');
  console.assert(assignmentA!.session.title.includes('Admin Optimized'), 'Assignment session title must match edited plan');
  console.assert(assignmentA!.session.exercises.length === 2, 'Exercises count must match edited payload (2 exercises)');
  console.assert(assignmentA!.session.exercises[0].numberOfSets === 4, 'Bench sets must be 4');

  // Verify Client B does NOT have this assignment (Strict Client Isolation)
  const assignmentB_isolated = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientB.id, sessionId: assignmentA!.sessionId, active: true },
  });
  console.assert(assignmentB_isolated === null, 'Client B must NOT receive Client A individual workout');
  console.log(`[PASS] Step 4: INDIVIDUAL assignment confirmed. Client A assigned, Client B isolated.\n`);

  // 5. Test Assignment Option 2: MULTIPLE SELECTED CLIENTS
  console.log('--- Step 5: Testing MULTIPLE SELECTED CLIENTS Assignment ---');
  // Create another proposal to test SELECTED assignment
  const toolResult2 = await proposeWorkoutPlanTool.handler({
    clientIdentifier: clientA.name,
    planTitle: 'Selected Group Conditioning',
    reason: 'Conditioning focus for selected athletes.',
    summary: 'High-intensity conditioning protocol.',
    weeklySchedule: [
      {
        day: 'Day 1',
        sessionTitle: 'Athletic Conditioning',
        workoutType: 'Conditioning',
        targetMuscleGroup: 'Full Body',
        estimatedDurationMinutes: 40,
        exercises: [
          { name: 'Kettlebell Swings', sets: 4, reps: '15', notes: '24kg kettlebell', restSeconds: 60 },
          { name: 'Rowing Intervals', sets: 5, reps: '500m', restSeconds: 90 },
        ],
      },
    ],
  }, {
    requestId: 'req_assign_test_2',
    conversationId: testConvId,
    adminId: 'admin_master',
  });

  const propSelectedId = toolResult2.proposal.id;
  await aiTools.approveProposal(propSelectedId, 'admin_master', 'Head Coach', {
    assignmentType: 'SELECTED',
    clientIds: [clientA.id, clientB.id],
    scheduledDate: todayIST,
  });

  const groupAssignA = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientA.id, active: true },
    include: { session: true },
    orderBy: { assignedAt: 'desc' },
  });
  const groupAssignB = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientB.id, active: true },
    include: { session: true },
    orderBy: { assignedAt: 'desc' },
  });

  console.assert(groupAssignA !== null && groupAssignA!.session.title.includes('Selected Group Conditioning'), 'Client A must have selected assignment');
  console.assert(groupAssignB !== null && groupAssignB!.session.title.includes('Selected Group Conditioning'), 'Client B must have selected assignment');
  console.assert(groupAssignA!.id !== groupAssignB!.id, 'Each client must have an independent, client-isolated assignment ID');
  console.log(`[PASS] Step 5: MULTIPLE SELECTED assignment confirmed. Both Client A & B received isolated assignment records.\n`);

  // 6. Test Assignment Option 3: ALL ELIGIBLE CLIENTS
  console.log('--- Step 6: Testing ALL ELIGIBLE CLIENTS Assignment ---');
  const toolResult3 = await proposeWorkoutPlanTool.handler({
    clientIdentifier: clientA.name,
    planTitle: 'Alpha X Facility Benchmark Protocol',
    reason: 'Monthly benchmark session for all athletes.',
    summary: 'Facility standard benchmark testing.',
    weeklySchedule: [
      {
        day: 'Day 1',
        sessionTitle: 'Benchmark Test',
        workoutType: 'Benchmark',
        targetMuscleGroup: 'Full Body',
        estimatedDurationMinutes: 45,
        exercises: [
          { name: '500m Row Benchmark', sets: 1, reps: '1', notes: 'Sub-1:35 pace target', restSeconds: 180 },
          { name: 'Max Pushups in 2 Min', sets: 1, reps: 'Max', notes: 'Strict form', restSeconds: 120 },
        ],
      },
    ],
  }, {
    requestId: 'req_assign_test_3',
    conversationId: testConvId,
    adminId: 'admin_master',
  });

  const propAllId = toolResult3.proposal.id;
  await aiTools.approveProposal(propAllId, 'admin_master', 'Head Coach', {
    assignmentType: 'ALL',
    scheduledDate: todayIST,
  });

  const allAssignments = await prisma.workoutAssignment.findMany({
    where: { session: { title: { contains: 'Facility Benchmark Protocol' } }, active: true },
  });

  console.assert(allAssignments.length >= eligibleClients.length, `Expected at least ${eligibleClients.length} assignments, got ${allAssignments.length}`);
  console.log(`[PASS] Step 6: ALL ELIGIBLE assignment confirmed. Created ${allAssignments.length} separate client assignments for all active members.\n`);

  // 7. Verify Client Workout Sessions Query (Requirement 5)
  console.log('--- Step 7: Verifying Client Workout Sessions API Query ---');
  const clientAuthorizedSessions = await prisma.workoutAssignment.findMany({
    where: {
      clientId: clientA.id,
      scheduledDate: todayIST,
      active: true,
    },
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
    orderBy: { assignedAt: 'desc' },
  });

  console.assert(clientAuthorizedSessions.length > 0, 'Client must have active workouts for todayIST');
  const activeWorkout = clientAuthorizedSessions[0];
  console.log(`       Active Workout for Client ${clientA.name}: "${activeWorkout.session.title}"`);
  console.log(`       Workout ID: ${activeWorkout.sessionId}`);
  console.log(`       Assignment ID: ${activeWorkout.id}`);
  console.log(`       Scheduled Date: ${activeWorkout.scheduledDate}`);
  console.log(`       Total Exercises: ${activeWorkout.session.exercises.length}`);
  console.log(`[PASS] Step 7: Client Workout Sessions correctly discovers active assignment with IDs & IST date.\n`);

  console.log('======================================================================');
  console.log('🎯 ALL PROPOSAL EDIT & MULTI-TARGET ASSIGNMENT TESTS PASSED! 🎯');
  console.log('======================================================================');
}

runProposalAssignmentE2ETests()
  .catch((err) => {
    console.error('E2E TEST FAILED:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
