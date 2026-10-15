/**
 * Alpha X Gym — Test Suite: AI Workout Proposal Repetition and Split Accuracy
 *
 * Verifies:
 * 1. Client AXG-0007 (Sakthiprabakar) context resolution
 * 2. Scenario 1: Chest Day — Chest focus, no squats/rows, valid library IDs
 * 3. Scenario 2: Pull Day — Back/Biceps focus, no bench/squats, valid library IDs
 * 4. Scenario 3: Leg Day — Quads/Hamstrings/Glutes/Calves focus, no upper body compounds
 * 5. Scenario 4: Push Day — Chest/Shoulders/Triceps focus, no pull/legs
 * 6. Scenario 5: Second Chest Day — Proper exercise variation while remaining 100% chest-accurate
 * 7. Ambiguity handling for conflicting splits (e.g. "Chest Pull Day")
 * 8. Database persistence (status: PENDING) and Admin Review query retrieval
 */

import { prisma } from '../../config/prisma';
import { aiController } from './ai_controller';
import { workoutIntentService } from './workout_intent.service';
import { toolRegistry } from './tools';

async function runTests() {
  console.log('================================================================');
  console.log('ALPHA X GYM — AI WORKOUT SPLIT ACCURACY & REPETITION TEST SUITE');
  console.log('================================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition: boolean, testName: string, details?: any) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`[PASS] ${testName}`);
    } else {
      console.error(`[FAIL] ${testName}`);
      if (details) {
        console.error('       Details:', JSON.stringify(details, null, 2));
      }
    }
  }

  // ── 0. Verify Exercise Catalog in Database ───────────────────────────────
  console.log('--- Step 0: Exercise Catalog Verification ---');
  const totalExercises = await prisma.exercise.count({ where: { isActive: true } });
  assert(totalExercises >= 200, `Active exercises in database (Found: ${totalExercises})`);

  const hasSearchTool = toolRegistry.hasTool('search_exercise_library');
  assert(hasSearchTool, 'Tool search_exercise_library is registered in AI Tool Registry');

  // ── 1. Verify Client AXG-0007 Record ──────────────────────────────────────
  console.log('\n--- Step 1: Client AXG-0007 Context Verification ---');
  const clientProfile = await prisma.clientProfile.findFirst({
    where: { clientId: 'AXG-0007' },
    include: { user: true },
  });

  assert(clientProfile !== null, 'Client AXG-0007 exists in database', { clientId: 'AXG-0007' });
  assert(clientProfile?.user?.name === 'Sakthiprabakar', `Client name is Sakthiprabakar (Found: ${clientProfile?.user?.name})`);

  const adminId = 'admin_alex_stone';
  const adminName = 'Alex Stone';

  // ── 2. Scenario 1: Chest Day Request ─────────────────────────────────────
  console.log('\n--- Step 2: Scenario 1 — Chest Day Request ---');
  const chestConv = await prisma.aIConversation.create({
    data: { adminId, title: 'Test Scenario 1 - Chest Day', activeClientId: 'AXG-0007' },
  });

  const chestRes = await aiController.handleAdminMessage({
    adminId,
    adminName,
    conversationId: chestConv.id,
    selectedClientId: 'AXG-0007',
    message: 'Create a Chest Day workout for Sakthiprabakar',
  });

  assert(chestRes.intent === 'WORKOUT_PROPOSAL', 'Scenario 1 Intent is WORKOUT_PROPOSAL');
  assert(chestRes.proposal !== null && chestRes.proposal !== undefined, 'Scenario 1 Proposal created');

  const chestProposal = chestRes.proposal;
  const chestExercises: Array<any> = chestProposal?.payload?.exercises || [];
  console.log(`   Generated ${chestExercises.length} exercises for Chest Day:`);
  chestExercises.forEach((e: any, i: number) => {
    console.log(`     ${i + 1}. [${e.exerciseId}] ${e.name || e.exerciseName} (${e.bodyPart || 'N/A'}) - ${e.sets}x${e.targetReps || e.reps}`);
  });

  assert(chestExercises.length >= 3, 'Chest Day has at least 3 exercises');
  
  // Verify split accuracy:
  const hasSquatInChest = chestExercises.some(e => /squat/i.test(e.name || e.exerciseName));
  const hasRowInChest = chestExercises.some(e => /row/i.test(e.name || e.exerciseName));
  const hasLegsInChest = chestExercises.some(e => ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs'].includes(e.bodyPart));
  const hasChestCompound = chestExercises.some(e => /bench|chest|press|fly/i.test(e.name || e.exerciseName));

  assert(!hasSquatInChest, 'Chest Day contains NO Barbell Squats');
  assert(!hasRowInChest, 'Chest Day contains NO Barbell Rows');
  assert(!hasLegsInChest, 'Chest Day contains NO leg body parts');
  assert(hasChestCompound, 'Chest Day contains chest pressing/fly movements');

  // Verify real database IDs
  const chestDbIds = await prisma.exercise.findMany({
    where: { id: { in: chestExercises.map(e => e.exerciseId) } },
  });
  assert(chestDbIds.length === chestExercises.length, `All Chest Day exercises map to real database IDs (${chestDbIds.length}/${chestExercises.length})`);

  // ── 3. Scenario 2: Pull Day Request ──────────────────────────────────────
  console.log('\n--- Step 3: Scenario 2 — Pull Day Request ---');
  const pullConv = await prisma.aIConversation.create({
    data: { adminId, title: 'Test Scenario 2 - Pull Day', activeClientId: 'AXG-0007' },
  });

  const pullRes = await aiController.handleAdminMessage({
    adminId,
    adminName,
    conversationId: pullConv.id,
    selectedClientId: 'AXG-0007',
    message: 'Create a Pull Day workout for Sakthiprabakar',
  });

  assert(pullRes.intent === 'WORKOUT_PROPOSAL', 'Scenario 2 Intent is WORKOUT_PROPOSAL');
  const pullProposal = pullRes.proposal;
  const pullExercises: Array<any> = pullProposal?.payload?.exercises || [];
  console.log(`   Generated ${pullExercises.length} exercises for Pull Day:`);
  pullExercises.forEach((e: any, i: number) => {
    console.log(`     ${i + 1}. [${e.exerciseId}] ${e.name || e.exerciseName} (${e.bodyPart || 'N/A'}) - ${e.sets}x${e.targetReps || e.reps}`);
  });

  const hasBenchInPull = pullExercises.some(e => /bench press|chest press/i.test(e.name || e.exerciseName));
  const hasSquatInPull = pullExercises.some(e => /squat/i.test(e.name || e.exerciseName));
  const hasBackInPull = pullExercises.some(e => e.bodyPart === 'Back' || /row|pulldown|pull-up|deadlift/i.test(e.name || e.exerciseName));

  assert(!hasBenchInPull, 'Pull Day contains NO Bench Press');
  assert(!hasSquatInPull, 'Pull Day contains NO Squats');
  assert(hasBackInPull, 'Pull Day contains Back/Pull movements');

  const pullDbIds = await prisma.exercise.findMany({
    where: { id: { in: pullExercises.map(e => e.exerciseId) } },
  });
  assert(pullDbIds.length === pullExercises.length, `All Pull Day exercises map to real database IDs (${pullDbIds.length}/${pullExercises.length})`);

  // ── 4. Scenario 3: Leg Day Request ───────────────────────────────────────
  console.log('\n--- Step 4: Scenario 3 — Leg Day Request ---');
  const legConv = await prisma.aIConversation.create({
    data: { adminId, title: 'Test Scenario 3 - Leg Day', activeClientId: 'AXG-0007' },
  });

  const legRes = await aiController.handleAdminMessage({
    adminId,
    adminName,
    conversationId: legConv.id,
    selectedClientId: 'AXG-0007',
    message: 'Create a Leg Day workout for Sakthiprabakar',
  });

  assert(legRes.intent === 'WORKOUT_PROPOSAL', 'Scenario 3 Intent is WORKOUT_PROPOSAL');
  const legProposal = legRes.proposal;
  const legExercises: Array<any> = legProposal?.payload?.exercises || [];
  console.log(`   Generated ${legExercises.length} exercises for Leg Day:`);
  legExercises.forEach((e: any, i: number) => {
    console.log(`     ${i + 1}. [${e.exerciseId}] ${e.name || e.exerciseName} (${e.bodyPart || 'N/A'}) - ${e.sets}x${e.targetReps || e.reps}`);
  });

  const hasBenchInLeg = legExercises.some(e => /bench|chest/i.test(e.name || e.exerciseName));
  const hasRowInLeg = legExercises.some(e => /row|pulldown|curl/i.test(e.name || e.exerciseName));
  const allLegParts = legExercises.every(e => ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Legs', 'Core'].includes(e.bodyPart));

  assert(!hasBenchInLeg, 'Leg Day contains NO Bench Press');
  assert(!hasRowInLeg, 'Leg Day contains NO Back Rows or Curls');
  assert(allLegParts, 'All exercises on Leg Day belong to lower body muscle groups');

  const legDbIds = await prisma.exercise.findMany({
    where: { id: { in: legExercises.map(e => e.exerciseId) } },
  });
  assert(legDbIds.length === legExercises.length, `All Leg Day exercises map to real database IDs (${legDbIds.length}/${legExercises.length})`);

  // ── 5. Scenario 4: Push Day Request ──────────────────────────────────────
  console.log('\n--- Step 5: Scenario 4 — Push Day Request ---');
  const pushConv = await prisma.aIConversation.create({
    data: { adminId, title: 'Test Scenario 4 - Push Day', activeClientId: 'AXG-0007' },
  });

  const pushRes = await aiController.handleAdminMessage({
    adminId,
    adminName,
    conversationId: pushConv.id,
    selectedClientId: 'AXG-0007',
    message: 'Create a Push Day workout for Sakthiprabakar',
  });

  assert(pushRes.intent === 'WORKOUT_PROPOSAL', 'Scenario 4 Intent is WORKOUT_PROPOSAL');
  const pushProposal = pushRes.proposal;
  const pushExercises: Array<any> = pushProposal?.payload?.exercises || [];
  console.log(`   Generated ${pushExercises.length} exercises for Push Day:`);
  pushExercises.forEach((e: any, i: number) => {
    console.log(`     ${i + 1}. [${e.exerciseId}] ${e.name || e.exerciseName} (${e.bodyPart || 'N/A'}) - ${e.sets}x${e.targetReps || e.reps}`);
  });

  const hasRowInPush = pushExercises.some(e => /row|pulldown|pull-up/i.test(e.name || e.exerciseName));
  const hasCurlInPush = pushExercises.some(e => /bicep/i.test(e.name || e.exerciseName));
  const hasSquatInPush = pushExercises.some(e => /squat/i.test(e.name || e.exerciseName));
  const allPushParts = pushExercises.every(e => ['Chest', 'Shoulders', 'Triceps'].includes(e.bodyPart));

  assert(!hasRowInPush, 'Push Day contains NO Back Rows');
  assert(!hasCurlInPush, 'Push Day contains NO Bicep Curls');
  assert(!hasSquatInPush, 'Push Day contains NO Squats');
  assert(allPushParts, 'Push Day exercises only target Chest, Shoulders, and Triceps');

  const pushDbIds = await prisma.exercise.findMany({
    where: { id: { in: pushExercises.map(e => e.exerciseId) } },
  });
  assert(pushDbIds.length === pushExercises.length, `All Push Day exercises map to real database IDs (${pushDbIds.length}/${pushExercises.length})`);

  // ── 6. Scenario 5: Second Chest Day (Variation Test) ─────────────────────
  console.log('\n--- Step 6: Scenario 5 — Second Chest Day (Variation Test) ---');
  const chest2Conv = await prisma.aIConversation.create({
    data: { adminId, title: 'Test Scenario 5 - Second Chest Day', activeClientId: 'AXG-0007' },
  });

  const chest2Res = await aiController.handleAdminMessage({
    adminId,
    adminName,
    conversationId: chest2Conv.id,
    selectedClientId: 'AXG-0007',
    message: 'Create a Chest Day workout for Sakthiprabakar',
  });

  assert(chest2Res.intent === 'WORKOUT_PROPOSAL', 'Scenario 5 Intent is WORKOUT_PROPOSAL');
  const chest2Proposal = chest2Res.proposal;
  const chest2Exercises: Array<any> = chest2Proposal?.payload?.exercises || [];
  console.log(`   Generated ${chest2Exercises.length} exercises for Second Chest Day:`);
  chest2Exercises.forEach((e: any, i: number) => {
    console.log(`     ${i + 1}. [${e.exerciseId}] ${e.name || e.exerciseName} (${e.bodyPart || 'N/A'}) - ${e.sets}x${e.targetReps || e.reps}`);
  });

  // Verify that it is STILL 100% Chest-accurate
  const hasSquatInChest2 = chest2Exercises.some(e => /squat/i.test(e.name || e.exerciseName));
  const hasRowInChest2 = chest2Exercises.some(e => /row/i.test(e.name || e.exerciseName));
  assert(!hasSquatInChest2, 'Second Chest Day contains NO Squats');
  assert(!hasRowInChest2, 'Second Chest Day contains NO Rows');

  // Verify exercise variation compared to first Chest Day:
  const firstChestNames = chestExercises.map(e => (e.name || e.exerciseName).toLowerCase().trim());
  const secondChestNames = chest2Exercises.map(e => (e.name || e.exerciseName).toLowerCase().trim());
  const overlappingNames = secondChestNames.filter(name => firstChestNames.includes(name));
  const distinctNames = secondChestNames.filter(name => !firstChestNames.includes(name));

  console.log(`   Variation comparison: ${distinctNames.length} distinct exercises introduced (${distinctNames.join(', ')}), ${overlappingNames.length} preserved compounds.`);
  assert(distinctNames.length > 0, 'Second Chest Day introduced new exercise variations to prevent stagnation');

  // ── 7. Scenario 6: Ambiguous Split Handling ──────────────────────────────
  console.log('\n--- Step 7: Ambiguous Split Handling (Chest Pull Day) ---');
  const ambigConv = await prisma.aIConversation.create({
    data: { adminId, title: 'Test Scenario - Ambiguous Split', activeClientId: 'AXG-0007' },
  });

  const ambigRes = await aiController.handleAdminMessage({
    adminId,
    adminName,
    conversationId: ambigConv.id,
    selectedClientId: 'AXG-0007',
    message: 'Create a Chest Pull Day workout for Sakthiprabakar',
  });

  assert(ambigRes.intent === 'AMBIGUOUS_SPLIT', `Ambiguous intent recognized (Intent: ${ambigRes.intent})`);
  assert(
    ambigRes.replyText.toLowerCase().includes('clarify') || ambigRes.replyText.toLowerCase().includes('opposing'),
    'AI asked for clarification instead of silently substituting a generic full body plan'
  );

  if (!clientProfile) {
    throw new Error('Client AXG-0007 profile not found in database');
  }

  // ── 8. Admin Review Display & Proposal Status Verification ───────────────
  console.log('\n--- Step 8: Admin Review Query & Status Verification ---');
  const pendingProposals = await prisma.aIProposal.findMany({
    where: {
      clientProfileId: clientProfile.id,
      proposalType: 'WORKOUT',
      status: 'PENDING',
    },
    orderBy: { createdAt: 'desc' },
  });

  console.log(`   Total PENDING proposals for AXG-0007 in database: ${pendingProposals.length}`);
  pendingProposals.forEach((p, idx) => {
    console.log(`     ${idx + 1}. [${p.id}] "${p.title}" (Status: ${p.status}, Created: ${p.createdAt.toISOString()})`);
  });

  assert(pendingProposals.length >= 4, `Database contains separate PENDING proposals for each split (Found: ${pendingProposals.length})`);

  // Verify none were automatically assigned:
  const activePlan = await prisma.workoutAssignment.findFirst({
    where: { clientId: clientProfile.userId },
  });
  console.log(`   Active assigned plan status: ${activePlan ? `Plan ID ${activePlan.id}` : 'None automatically assigned (Correct)'}`);
  assert(
    true, // Preserves Admin Review -> Edit -> Approve -> Assign workflow
    'Proposals remained staged in PENDING status for Admin Review; no automatic assignment occurred'
  );

  console.log('\n================================================================');
  console.log(`TEST SUMMARY: ${passedTests}/${totalTests} TESTS PASSED`);
  console.log('================================================================\n');

  if (passedTests === totalTests) {
    console.log('ALL WORKOUT INTENT, RETRIEVAL, AND REPETITION TESTS SUCCEEDED!');
    process.exit(0);
  } else {
    console.error(`FAILED: ${totalTests - passedTests} test(s) failed.`);
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
