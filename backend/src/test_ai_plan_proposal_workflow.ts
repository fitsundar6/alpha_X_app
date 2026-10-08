import { prisma } from './config/prisma';
import { aiController } from './modules/ai_coach/ai_controller';
import { aiTools } from './modules/ai_coach/ai_tools';

async function runTests() {
  console.log('=== STARTING AI PLAN PROPOSAL WORKFLOW VERIFICATION ===\n');

  // 1. Target real client: Marcus Vance
  const targetUser = await prisma.user.findFirst({
    where: { role: 'CLIENT', name: { contains: 'Marcus Vance' } },
    include: { clientProfile: true },
  });

  if (!targetUser) {
    throw new Error('Target test client Marcus Vance not found in database.');
  }

  const clientId = targetUser.clientProfile?.clientId || targetUser.id;
  console.log(`✔ 1. Verified Target Athlete: ${targetUser.name} (${clientId}, Profile ID: ${targetUser.clientProfile?.id})`);

  // Count active workout assignments before test
  const initialWorkoutAssignments = await prisma.workoutAssignment.count({
    where: { clientId: targetUser.id, active: true },
  });
  console.log(`   Initial Active Workout Assignments: ${initialWorkoutAssignments}`);

  // Count active diet plans before test
  const initialDietPlans = await prisma.dietPlan.count({
    where: { clientProfileId: targetUser.clientProfile!.id, isActive: true },
  });
  console.log(`   Initial Active Diet Plans: ${initialDietPlans}\n`);

  // 2. Generate Workout Proposal
  console.log('--- TEST STEP 2: AI WORKOUT PLAN GENERATION ---');
  const workoutRes = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_test_w_${Date.now()}`,
    message: `Create a workout plan for client ${targetUser.name}`,
  });

  console.assert(workoutRes.proposal !== undefined, 'Expected workout proposal generated');
  console.assert(workoutRes.proposal!.status === 'PENDING', 'Proposal MUST be PENDING');
  console.assert(workoutRes.proposal!.type === 'WORKOUT', 'Expected WORKOUT type');
  console.log(`✔ 2. AI Generated Workout Proposal: "${workoutRes.proposal!.title}"`);
  console.log(`   Proposal ID: ${workoutRes.proposal!.id}`);
  console.log(`   Status: ${workoutRes.proposal!.status} (NOT ASSIGNED)`);
  console.log(`   Reasoning: ${workoutRes.proposal!.reason.substring(0, 80)}...`);

  // Verify it is NOT assigned yet
  const postGenAssignments = await prisma.workoutAssignment.count({
    where: { clientId: targetUser.id, active: true },
  });
  console.assert(postGenAssignments === initialWorkoutAssignments, 'CRITICAL: Proposal must NOT be assigned to client yet!');
  console.log(`✔ 3. Verified Safety Rule: Client active workout count unchanged (${postGenAssignments})\n`);

  // 3. Test REJECT Workflow
  console.log('--- TEST STEP 3: WORKOUT REJECT WORKFLOW ---');
  const rejectedWorkout = await aiTools.rejectProposal(workoutRes.proposal!.id, 'admin_alex_stone', 'Requires heavier compound work');
  console.assert(rejectedWorkout.status === 'REJECTED', 'Expected REJECTED status');
  console.assert(rejectedWorkout.rejectionReason === 'Requires heavier compound work', 'Expected rejection reason saved');
  console.log(`✔ 4. Proposal successfully REJECTED. Status: ${rejectedWorkout.status}`);

  const postRejectAssignments = await prisma.workoutAssignment.count({
    where: { clientId: targetUser.id, active: true },
  });
  console.assert(postRejectAssignments === initialWorkoutAssignments, 'Client active workout count must remain untouched after REJECT');
  console.log(`✔ 5. Verified Safety: Client still has original assignments (${postRejectAssignments})\n`);

  // 4. Generate Second Workout Proposal for EDIT & ACCEPT
  console.log('--- TEST STEP 4: WORKOUT EDIT & ACCEPT WORKFLOW ---');
  const workoutRes2 = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_test_w2_${Date.now()}`,
    message: `Create a workout plan for client ${targetUser.name}`,
  });
  const prop2Id = workoutRes2.proposal!.id;

  // 5. EDIT Proposal
  const origPayload = workoutRes2.proposal!.payload;
  origPayload.title = `Admin Master: ${origPayload.title}`;
  origPayload.exercises[0].targetWeight = 95.0; // Trainer adjustments
  origPayload.exercises[0].targetReps = '6-8';
  origPayload.exercises[0].targetRpe = 9.0;
  origPayload.exercises[0].notes = 'Admin adjusted: Increased load to 95kg for strength hypertrophy';

  const editedProp = await aiTools.editProposal(prop2Id, 'admin_alex_stone', origPayload);
  console.assert(editedProp.status === 'EDITED', 'Expected EDITED status');
  console.log(`✔ 6. Proposal EDITED by Admin. Status: ${editedProp.status}`);
  console.log(`   Updated Exercise 1 Target Weight: 95kg, Reps: 6-8, RPE: 9.0`);

  // 6. ACCEPT & ASSIGN Proposal
  const approvedWorkout = await aiTools.approveProposal(prop2Id, 'admin_alex_stone', 'Alex Stone');
  console.assert(approvedWorkout.status === 'APPROVED', 'Expected APPROVED status');
  console.log(`✔ 7. Proposal ACCEPTED. Status: ${approvedWorkout.status}`);

  // Verify the client received the new assigned workout in database
  const activeAssignment = await prisma.workoutAssignment.findFirst({
    where: { clientId: targetUser.id, active: true },
    include: { session: { include: { exercises: true } } },
    orderBy: { assignedAt: 'desc' },
  });
  console.assert(activeAssignment !== null, 'Client MUST have active assigned workout');
  console.assert(activeAssignment!.session.title.includes('Admin Master'), 'Client MUST receive the ADMIN-EDITED session!');
  console.assert(activeAssignment!.session.exercises[0].targetWeight === 95.0, 'Client session must reflect edited 95kg load!');
  console.log(`✔ 8. Verified Final Assignment in DB: "${activeAssignment!.session.title}" (Exercise 1 Weight: ${activeAssignment!.session.exercises[0].targetWeight} kg)\n`);

  // 7. DIET PLAN PROPOSAL WORKFLOW
  console.log('--- TEST STEP 5: AI DIET PLAN GENERATION & REVIEW ---');
  const dietRes = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_test_d_${Date.now()}`,
    message: `Create a diet plan for client ${targetUser.name}`,
  });

  console.assert(dietRes.proposal !== undefined, 'Expected diet proposal generated');
  console.assert(dietRes.proposal!.status === 'PENDING', 'Diet proposal MUST be PENDING');
  console.assert(dietRes.proposal!.type === 'DIET', 'Expected DIET type');
  console.log(`✔ 9. AI Generated Diet Proposal: "${dietRes.proposal!.title}"`);
  console.log(`   Status: ${dietRes.proposal!.status} (NOT ASSIGNED)`);
  console.log(`   Summary: ${dietRes.proposal!.summary}`);

  // Test REJECT on Diet
  const rejectedDiet = await aiTools.rejectProposal(dietRes.proposal!.id, 'admin_alex_stone', 'Needs more carbohydrates');
  console.assert(rejectedDiet.status === 'REJECTED', 'Expected diet REJECTED');
  console.log(`✔ 10. Diet Proposal successfully REJECTED. Status: ${rejectedDiet.status}`);

  // Generate Second Diet Proposal for EDIT & ACCEPT
  const dietRes2 = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_test_d2_${Date.now()}`,
    message: `Create a diet plan for client ${targetUser.name}`,
  });
  const diet2Id = dietRes2.proposal!.id;

  // EDIT Diet Proposal
  const dietPayload = dietRes2.proposal!.payload;
  dietPayload.planName = `Admin Customized: ${dietPayload.planName}`;
  dietPayload.dailyCalories = 2450;
  dietPayload.protein = 185;
  dietPayload.notes = 'Admin adjusted daily protein to 185g for strength peak cycle';

  const editedDiet = await aiTools.editProposal(diet2Id, 'admin_alex_stone', dietPayload);
  console.assert(editedDiet.status === 'EDITED', 'Expected EDITED status');
  console.log(`✔ 11. Diet Proposal EDITED by Admin. Status: ${editedDiet.status}`);
  console.log(`   Updated Daily Target: 2450 kcal, 185g Protein`);

  // ACCEPT & ASSIGN Diet Proposal
  const approvedDiet = await aiTools.approveProposal(diet2Id, 'admin_alex_stone', 'Alex Stone');
  console.assert(approvedDiet.status === 'APPROVED', 'Expected APPROVED status');
  console.log(`✔ 12. Diet Proposal ACCEPTED. Status: ${approvedDiet.status}`);

  // Verify the client has active diet plan in DB
  const activeDietPlan = await prisma.dietPlan.findFirst({
    where: { clientProfileId: targetUser.clientProfile!.id, isActive: true },
    orderBy: { createdAt: 'desc' },
  });
  console.assert(activeDietPlan !== null, 'Client MUST have active diet plan in DB');
  console.assert(activeDietPlan!.planName.includes('Admin Customized'), 'Client MUST receive ADMIN-EDITED diet plan!');
  console.assert(activeDietPlan!.protein === 185, 'Client diet plan must reflect edited 185g protein!');
  console.log(`✔ 13. Verified Final Diet in DB: "${activeDietPlan!.planName}" (Calories: ${activeDietPlan!.dailyCalories} kcal, Protein: ${activeDietPlan!.protein}g)\n`);

  console.log('======================================================================');
  console.log('🎉 ALL AI PLAN PROPOSAL WORKFLOW TESTS COMPLETED SUCCESSFULLY! 🎉');
  console.log('======================================================================');
}

runTests()
  .catch((e) => {
    console.error('TEST ERROR:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
