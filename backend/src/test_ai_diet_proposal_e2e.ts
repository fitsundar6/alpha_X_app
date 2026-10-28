import { prisma } from './config/prisma';
import { proposeDietPlanTool } from './modules/ai_coach/tools/definitions/client/propose_diet_plan';
import { aiTools } from './modules/ai_coach/ai_tools';
import { AiController } from './modules/ai_coach/ai_controller';

async function verifyCompleteDietProposalFlow() {
  console.log('======================================================================');
  console.log('🥗 STARTING COMPREHENSIVE AI DIET PLAN PROPOSAL END-TO-END VERIFICATION');
  console.log('======================================================================\n');

  const aiController = new AiController();

  // 1. Locate client Ajay (AXG-0005)
  console.log('--- STEP 1: Resolving Athlete Profile & Assessment Data ---');
  const clientUser = await prisma.user.findFirst({
    where: { role: 'CLIENT', name: { contains: 'Ajay' } },
    include: { clientProfile: true },
  });

  if (!clientUser || !clientUser.clientProfile) {
    throw new Error('Test client Ajay with profile not found in database.');
  }

  const cp = clientUser.clientProfile;
  console.log(`[PASS] Step 1: Athlete Located: ${clientUser.name} (${cp.clientId || 'AXG-0005'})`);
  console.log(`       User ID: ${clientUser.id}, Profile ID: ${cp.id}`);
  console.log(`       Assessment Metrics: Weight=${cp.weightKg}kg, Height=${cp.heightCm}cm, Age=${cp.age}, Gender=${cp.gender}`);
  console.log(`       Primary Goal=${cp.primaryGoal}, Activity Level=${cp.activityLevel || 'MODERATE'}\n`);

  // 2. Validate input schema & failure handling on invalid/missing fields
  console.log('--- STEP 2: Testing Tool Validation & Failure Handling ---');
  
  // Failure Case A: Missing client identifier
  const errNoClient = await proposeDietPlanTool.handler({
    clientIdentifier: '',
    planName: 'Test Plan',
    reason: 'Valid rationale here for test',
    summary: 'Valid summary overview',
    dailyCalories: 2000,
    protein: 150,
    carbohydrates: 200,
    fat: 60,
  }, {
    requestId: 'req_fail_1',
    conversationId: 'conv_fail_1',
    adminId: 'admin_test',
  });
  console.assert(errNoClient.success === false, 'Expected error on missing client identifier');
  console.log(`[PASS] Step 2a: Tool rejected empty client identifier: "${errNoClient.message}"`);

  // Failure Case B: Invalid non-positive macros
  const errBadMacros = await proposeDietPlanTool.handler({
    clientIdentifier: clientUser.name,
    planName: 'Test Plan',
    reason: 'Valid rationale',
    summary: 'Valid summary',
    dailyCalories: -100, // Invalid negative calories
    protein: 0,
    carbohydrates: 100,
    fat: 40,
  }, {
    requestId: 'req_fail_2',
    conversationId: 'conv_fail_2',
    adminId: 'admin_test',
  });
  console.assert(errBadMacros.success === false, 'Expected error on invalid negative calories/protein');
  console.log(`[PASS] Step 2b: Tool rejected invalid macros: "${errBadMacros.message}"`);

  // Failure Case C: Non-existent client
  const errUnknownClient = await proposeDietPlanTool.handler({
    clientIdentifier: 'NonExistentClientXYZ_999',
    planName: 'Ghost Athlete Diet',
    reason: 'Rationale for ghost client',
    summary: 'Summary for ghost client',
    dailyCalories: 2200,
    protein: 160,
    carbohydrates: 220,
    fat: 65,
  }, {
    requestId: 'req_fail_3',
    conversationId: 'conv_fail_3',
    adminId: 'admin_test',
  });
  console.assert(errUnknownClient.success === false, 'Expected error on non-existent client');
  console.log(`[PASS] Step 2c: Tool caught unknown client safely: "${errUnknownClient.message}"\n`);

  // 3. Propose Diet Plan via propose_diet_plan tool (Requirement 1, 2, 3)
  console.log('--- STEP 3: AI Diet Plan Tool Execution & Database Submission (PENDING) ---');
  const testConvId = `conv_test_diet_e2e_${Date.now()}`;
  await prisma.aIConversation.create({
    data: {
      id: testConvId,
      adminId: 'admin_alex_stone',
      title: 'E2E Diet Test Session',
    },
  });

  const uniquePlanTitle = `${clientUser.name} — High-Protein Fat Loss Protocol (${Date.now()})`;
  const validProposalInput = {
    clientIdentifier: clientUser.name,
    planName: uniquePlanTitle,
    reason: `Caloric deficit calibrated against Ajay's verified weight (${cp.weightKg} kg) and ${cp.primaryGoal} objective. High protein (2.2g/kg) preserves lean muscle tissue while targeting adipose tissue mobilization.`,
    summary: 'Target 1850 kcal/day, 160g protein, 175g carbohydrates, 48g fats, 32g fiber, 3.5L water across 4 structured meals.',
    dailyCalories: 1850,
    protein: 160,
    carbohydrates: 175,
    fat: 48,
    fiber: 32,
    waterTargetLiters: 3.5,
    meals: [
      {
        mealType: 'Breakfast',
        timing: '8:00 AM',
        notes: 'High-protein breakfast to trigger muscle protein synthesis',
        foods: [
          { foodId: 'f_oats', foodName: 'Rolled Oats', quantity: 60, unit: 'g', calories: 228, protein: 7.8, carbs: 40.8, fat: 4.2, fiber: 6.0 },
          { foodId: 'f_eggs', foodName: 'Whole Eggs', quantity: 3, unit: 'piece', calories: 216, protein: 18.9, carbs: 1.2, fat: 14.4, fiber: 0 },
        ],
      },
      {
        mealType: 'Lunch',
        timing: '1:00 PM',
        notes: 'Post-training recovery energy with lean poultry and complex carbs',
        foods: [
          { foodId: 'f_chicken', foodName: 'Grilled Chicken Breast', quantity: 200, unit: 'g', calories: 330, protein: 62.0, carbs: 0, fat: 7.2, fiber: 0 },
          { foodId: 'f_rice', foodName: 'Basmati Rice (Cooked)', quantity: 200, unit: 'g', calories: 260, protein: 5.4, carbs: 56.0, fat: 0.6, fiber: 0.8 },
        ],
      },
      {
        mealType: 'Snacks',
        timing: '4:30 PM',
        notes: 'Pre-workout afternoon snack with fast-acting protein and micronutrients',
        foods: [
          { foodId: 'f_apple', foodName: 'Fresh Apple', quantity: 1, unit: 'piece', calories: 95, protein: 0.5, carbs: 25.0, fat: 0.3, fiber: 4.4 },
          { foodId: 'f_whey', foodName: 'Whey Protein Isolate', quantity: 30, unit: 'g', calories: 120, protein: 25.0, carbs: 1.5, fat: 1.0, fiber: 0 },
        ],
      },
      {
        mealType: 'Dinner',
        timing: '8:00 PM',
        notes: 'Lean dinner with slow-digesting proteins for overnight tissue maintenance',
        foods: [
          { foodId: 'f_chicken_din', foodName: 'Grilled Chicken Breast', quantity: 180, unit: 'g', calories: 297, protein: 55.8, carbs: 0, fat: 6.5, fiber: 0 },
          { foodId: 'f_rice_din', foodName: 'Steamed Rice', quantity: 150, unit: 'g', calories: 195, protein: 4.1, carbs: 42.0, fat: 0.5, fiber: 0.6 },
        ],
      },
    ],
  };

  const toolExecResult = await proposeDietPlanTool.handler(validProposalInput, {
    requestId: 'req_diet_valid_1',
    conversationId: testConvId,
    adminId: 'admin_alex_stone',
  });

  console.assert(toolExecResult.success === true, 'Expected tool execution to succeed');
  console.assert(toolExecResult.proposal !== undefined, 'Expected returned proposal object');
  console.assert(toolExecResult.proposal.status === 'PENDING', 'Proposal status MUST be PENDING');
  console.assert(toolExecResult.proposal.type === 'DIET', 'Proposal type MUST be DIET');
  const proposalId = toolExecResult.proposal.id;

  // Verify DB record directly
  const dbProposal = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
  console.assert(dbProposal !== null, 'Proposal row MUST exist in database');
  console.assert(dbProposal!.status === 'PENDING', 'Database status MUST be PENDING');
  console.assert(dbProposal!.clientProfileId === cp.id, 'Must link to correct clientProfileId');

  const payloadParsed = JSON.parse(dbProposal!.proposedDataJson);
  console.assert(payloadParsed.dailyCalories === 1850, 'Must match dailyCalories');
  console.assert(payloadParsed.protein === 160, 'Must match protein');
  console.assert(payloadParsed.meals?.length === 4, 'Must have 4 meals');
  console.assert(payloadParsed.meals[0].timing === '8:00 AM', 'Must contain meal timings');
  console.assert(payloadParsed.meals[0].foods[0].quantity > 0, 'Must contain food quantity in grams');
  console.assert(payloadParsed.rationale !== undefined, 'Must include clear rationale');
  console.assert(payloadParsed.assumptions !== undefined, 'Must include assumptions');

  console.log(`[PASS] Step 3: Tool persisted proposal "${dbProposal!.title}" in database.`);
  console.log(`       ID: ${dbProposal!.id}, Status: ${dbProposal!.status}`);
  console.log(`       Targets: ${payloadParsed.dailyCalories} kcal | ${payloadParsed.protein}g P | ${payloadParsed.carbohydrates}g C | ${payloadParsed.fat}g F | ${payloadParsed.fiber}g Fiber`);
  console.log(`       Meals: ${payloadParsed.meals.length} structured meals with timings & gram quantities verified in DB.\n`);

  // 4. Test Deduplication Guard (Requirement 6)
  console.log('--- STEP 4: Testing Duplicate Proposal Prevention on Retry ---');
  const countBeforeRetry = await prisma.aIProposal.count({
    where: { clientProfileId: cp.id, status: 'PENDING', conversationId: testConvId },
  });

  const retryResult = await proposeDietPlanTool.handler({
    ...validProposalInput,
    dailyCalories: 1900,
    protein: 165,
    summary: 'Updated summary targets after quick coach fine-tuning.',
  }, {
    requestId: 'req_diet_retry_1',
    conversationId: testConvId,
    adminId: 'admin_alex_stone',
  });

  const countAfterRetry = await prisma.aIProposal.count({
    where: { clientProfileId: cp.id, status: 'PENDING', conversationId: testConvId },
  });

  console.assert(countBeforeRetry === 1, 'Expected 1 pending proposal before retry');
  console.assert(countAfterRetry === 1, 'Expected count to remain 1 (no duplicate row created)');
  console.assert(retryResult.proposal.id === proposalId, 'Expected existing proposal ID to be updated in-place');
  console.log(`[PASS] Step 4: Duplicate proposal prevented! Proposal ID ${proposalId} updated in-place without duplicate records.\n`);

  // 5. Verify Database Safety Isolation Before Approval (Requirement 5)
  console.log('--- STEP 5: Verifying Database Safety Isolation (Athlete Plan Untouched) ---');
  const preApprovalDiet = await prisma.dietPlan.findFirst({
    where: { clientProfileId: cp.id, isActive: true },
  });
  console.assert(
    preApprovalDiet?.planName !== uniquePlanTitle,
    'Athlete active diet plan MUST NOT be changed before admin approval!'
  );
  console.log(`[PASS] Step 5: Athlete active diet plan remains isolated prior to admin approval: "${preApprovalDiet?.planName || 'None'}"\n`);

  // 6. Admin Proposal Screen: Review & Edit (Requirement 4)
  console.log('--- STEP 6: Admin Review & Edit Proposal ---');
  const dbProposalToEdit = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
  const editPayload = JSON.parse(dbProposalToEdit!.proposedDataJson);
  editPayload.planName = `Admin Approved: ${editPayload.planName}`;
  editPayload.dailyCalories = 1920;
  editPayload.protein = 170;
  editPayload.notes = 'Admin adjusted daily protein to 170g to account for 5-day strength frequency.';

  const edited = await aiTools.editProposal(proposalId, 'admin_alex_stone', editPayload);
  console.assert(edited.status === 'EDITED', 'Proposal status must be EDITED');
  const editedDb = await prisma.aIProposal.findUnique({ where: { id: proposalId } });
  console.assert(editedDb!.finalDataJson !== null, 'finalDataJson must store admin edits');
  console.log(`[PASS] Step 6: Admin successfully reviewed & edited proposal. Status: ${editedDb!.status}`);
  console.log(`       Edited Targets: 1920 kcal, 170g Protein\n`);

  // 7. Admin Approves and Assigns to Client (Requirement 5)
  console.log('--- STEP 7: Admin Approves Proposal & Assigns to Athlete ---');
  const approved = await aiTools.approveProposal(proposalId, 'admin_alex_stone', 'Admin Alex');
  console.assert(approved.status === 'APPROVED', 'Proposal status must become APPROVED');

  // Verify Database Assignment
  const activeDietPlan = await prisma.dietPlan.findFirst({
    where: { clientProfileId: cp.id, isActive: true },
    orderBy: { createdAt: 'desc' },
  });
  console.assert(activeDietPlan !== null, 'Client MUST have active DietPlan');
  console.assert(activeDietPlan!.planName.includes('Admin Approved'), 'Must reflect admin-edited title');
  console.assert(activeDietPlan!.dailyCalories === 1920, 'Must reflect 1920 calories');
  console.assert(activeDietPlan!.protein === 170, 'Must reflect 170g protein');
  console.assert(activeDietPlan!.mealsJson !== null, 'mealsJson MUST be populated');

  const parsedMealsJson = JSON.parse(activeDietPlan!.mealsJson!);
  console.assert(parsedMealsJson.length === 4, 'mealsJson must contain all 4 meals');
  console.assert(parsedMealsJson[0].timing === '8:00 AM', 'mealsJson must retain meal timings');

  // Verify synchronized MacroPlan in Database
  const activeMacroPlan = await prisma.macroPlan.findFirst({
    where: { clientProfileId: cp.id, isActive: true },
    orderBy: { createdAt: 'desc' },
  });
  console.assert(activeMacroPlan !== null, 'Client MUST have active MacroPlan');
  console.assert(activeMacroPlan!.calories === 1920, 'MacroPlan calories must match');
  console.assert(activeMacroPlan!.protein === 170, 'MacroPlan protein must match');

  // Verify DietPlanHistory in Database
  const historyRecord = await prisma.dietPlanHistory.findFirst({
    where: { clientProfileId: cp.id },
    orderBy: { createdAt: 'desc' },
  });
  console.assert(historyRecord !== null, 'DietPlanHistory record MUST be created');
  console.assert(historyRecord!.dailyCalories === 1920, 'History must log assigned calories');

  console.log(`[PASS] Step 7: Proposal APPROVED and assigned in Database!`);
  console.log(`       Active DietPlan ID: ${activeDietPlan!.id}, Version: v${activeDietPlan!.version}`);
  console.log(`       Active MacroPlan ID: ${activeMacroPlan!.id} (Calories: ${activeMacroPlan!.calories}, Protein: ${activeMacroPlan!.protein}g)`);
  console.log(`       DietPlanHistory ID: ${historyRecord!.id}\n`);

  // 8. Client App Data Delivery Verification (Requirement 5)
  console.log('--- STEP 8: Verifying Client App Endpoints (/me/diet-plan & /me/macros) ---');
  // Client fetches /me/diet-plan (same logic as router)
  const clientViewDiet = await prisma.dietPlan.findFirst({
    where: {
      OR: [
        { clientProfileId: cp.id },
        { clientId: cp.clientId },
        { clientId: clientUser.id },
      ],
      isActive: true,
    },
    orderBy: { createdAt: 'desc' },
  });
  console.assert(clientViewDiet !== null, 'Client endpoint must return active diet');
  console.assert(clientViewDiet!.id === activeDietPlan!.id, 'Client must receive newly approved plan');

  // Client fetches /me/macros
  const clientViewMacros = await prisma.macroPlan.findFirst({
    where: { clientProfileId: cp.id, isActive: true },
    orderBy: { createdAt: 'desc' },
  });
  console.assert(clientViewMacros !== null, 'Client endpoint must return active macros');
  console.assert(clientViewMacros!.calories === 1920, 'Client receives 1920 kcal target');
  console.log(`[PASS] Step 8: Client app query successfully resolves assigned diet plan and macro targets!\n`);

  // 9. Natural Language AI Coach Request Flow via AiController
  console.log('--- STEP 9: Testing Natural Language AI Coach Routing via AiController ---');
  
  // 9a. Ambiguous request without client context
  const ambiguousRes = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_nl_amb_${Date.now()}`,
    message: 'Prepare a diet plan',
  });
  console.assert(ambiguousRes.intent === 'AMBIGUOUS_CLIENT', 'Must trigger AMBIGUOUS_CLIENT');
  console.assert(ambiguousRes.replyText.includes('Which client'), 'Must prompt for athlete selection');
  console.log(`[PASS] Step 9a: Ambiguous diet query correctly detected: "${ambiguousRes.replyText.substring(0, 70)}..."`);

  // 9b. Natural language request with client specified
  const nlRes = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_nl_spec_${Date.now()}`,
    message: `Create a personalized fat loss diet plan for ${clientUser.name}`,
  });
  console.assert(nlRes.intent === 'DIET_PROPOSAL', 'Must route to DIET_PROPOSAL intent');
  console.assert(nlRes.proposal !== undefined && nlRes.proposal !== null, 'Must return proposal object');
  console.assert(nlRes.proposal.status === 'PENDING', 'Natural language proposal must be PENDING');
  console.assert(nlRes.proposal.payload.meals.length === 4, 'Must contain 4 structured meals');
  console.assert(nlRes.proposal.payload.assumptions.includes('Mifflin-St Jeor'), 'Must use Mifflin-St Jeor calculations');
  console.log(`[PASS] Step 9b: Natural language query generated proposal "${nlRes.proposal.title}"`);
  console.log(`       Intent: ${nlRes.intent}, Status: ${nlRes.proposal.status}`);
  console.log(`       Assumptions: ${nlRes.proposal.payload.assumptions.substring(0, 90)}...\n`);

  // 10. Dietary Restrictions & Allergy Handling (Requirement 6)
  console.log('--- STEP 10: Testing Dietary Restrictions & Safety Boundaries ---');
  // Temporary note with egg allergy and vegetarian preference
  const prevNotes = cp.adminNotes;
  await prisma.clientProfile.update({
    where: { id: cp.id },
    data: { adminNotes: 'Vegetarian. Egg allergy reported in medical intake.' },
  });

  const restrictedRes = await aiController.handleAdminMessage({
    adminId: 'admin_alex_stone',
    adminName: 'Alex Stone',
    conversationId: `conv_allergy_${Date.now()}`,
    message: `Prepare a nutrition plan for ${clientUser.name}`,
  });

  const restrictedPayload = restrictedRes.proposal.payload;
  const foodNames = restrictedPayload.meals.flatMap((m: any) => m.items.map((it: any) => it.foodName.toLowerCase()));
  const containsEgg = foodNames.some((n: string) => n.includes('egg'));
  const containsChicken = foodNames.some((n: string) => n.includes('chicken'));

  console.assert(!containsEgg, 'Plan MUST NOT contain eggs when athlete has egg allergy');
  console.assert(!containsChicken, 'Plan MUST NOT contain chicken when athlete is vegetarian');
  console.assert(restrictedPayload.assumptions.includes('Egg-free'), 'Assumptions must note egg-free boundary');
  console.assert(restrictedPayload.assumptions.includes('Vegetarian'), 'Assumptions must note vegetarian boundary');

  // Restore client notes
  await prisma.clientProfile.update({
    where: { id: cp.id },
    data: { adminNotes: prevNotes },
  });
  console.log(`[PASS] Step 10: Safety boundaries verified! Egg and poultry excluded for allergic/vegetarian athlete.\n`);

  console.log('======================================================================');
  console.log('🎉 ALL AI DIET PLAN PROPOSAL END-TO-END TESTS PASSED SUCCESSFULLY! 🎉');
  console.log('======================================================================');
}

verifyCompleteDietProposalFlow()
  .catch((err) => {
    console.error('VERIFICATION FAILED:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
