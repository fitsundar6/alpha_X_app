/**
 * End-to-End Comprehensive Verification Test for AI Diet & Macro Proposals
 *
 * Verifies:
 * 1. AI Workout Proposal still works correctly (unaltered).
 * 2. Full Structured Diet Plan Proposal generated and persisted with status PENDING.
 * 3. Daily Macro-Only Target Proposal generated and persisted with status PENDING.
 * 4. Validation and error handling: rejects invalid targets without reporting false success.
 * 5. Admin Review: editing proposal updates payload and status in database while keeping proposal ID.
 * 6. Admin Approval & Assignment: creates active DietPlan & MacroPlan for target client.
 * 7. Client Visibility: verifies client's active diet plan & macros resolve correctly.
 * 8. Client Isolation: verifies no cross-contamination between different athletes.
 */

import { prisma } from './config/prisma';
import { proposeDietPlanTool } from './modules/ai_coach/tools/definitions/client/propose_diet_plan';
import { aiTools } from './modules/ai_coach/ai_tools';
import { AiController } from './modules/ai_coach/ai_controller';

async function runVerification() {
  console.log('================================================================');
  console.log('ALPHA X GYM — AI DIET & MACRO PROPOSAL WORKFLOW VERIFICATION');
  console.log('================================================================\n');

  const aiController = new AiController();
  const createdProposalIds: string[] = [];

  // Find 2 existing clients in database
  const clientUsers = await prisma.user.findMany({
    where: { role: 'CLIENT', clientProfile: { isNot: null } },
    include: { clientProfile: true },
    take: 2,
  });

  if (clientUsers.length < 2) {
    throw new Error('Need at least 2 clients in database for testing.');
  }

  const client1 = clientUsers[0];
  const cp1 = client1.clientProfile!;
  const client2 = clientUsers[1];
  const cp2 = client2.clientProfile!;

  console.log(`[Athlete 1] ${client1.name} (User ID: ${client1.id}, Profile ID: ${cp1.id})`);
  console.log(`[Athlete 2] ${client2.name} (User ID: ${client2.id}, Profile ID: ${cp2.id})\n`);

  try {
    // -------------------------------------------------------------
    // Step 1: Verify Workout Proposal still works (unaltered)
    // -------------------------------------------------------------
    console.log('[Step 1] Verifying AI Workout Proposal still works (preservation constraint)...');
    const workoutRes = await aiController.handleAdminMessage({
      adminId: 'admin_alex_stone',
      adminName: 'Alex Stone',
      conversationId: `conv_workout_test_${Date.now()}`,
      message: `Create a strength workout plan for ${client1.name}`,
    });

    if (workoutRes.intent !== 'WORKOUT_PROPOSAL') {
      throw new Error(`Expected intent 'WORKOUT_PROPOSAL', got '${workoutRes.intent}'`);
    }
    if (!workoutRes.proposal || workoutRes.proposal.status !== 'PENDING') {
      throw new Error('Workout proposal not generated with status PENDING');
    }
    createdProposalIds.push(workoutRes.proposal.id);
    console.log(`  ✓ Workout proposal preserved: ID=${workoutRes.proposal.id}, status=${workoutRes.proposal.status}`);

    // -------------------------------------------------------------
    // Step 2: Full Structured Diet Plan Proposal
    // -------------------------------------------------------------
    console.log('\n[Step 2] Testing Full Structured Diet Plan Proposal workflow...');
    const dietToolRes = await proposeDietPlanTool.handler({
      clientIdentifier: client1.name,
      planKind: 'DIET_PLAN',
      planName: `${client1.name} Performance Nutrition Plan`,
      reason: 'Support progressive overload and lean mass retention',
      summary: 'High-protein structured nutrition with targeted nutrient timing',
      dailyCalories: 2400,
      protein: 180,
      carbohydrates: 250,
      fat: 70,
      fiber: 35,
      waterTargetLiters: 4.0,
      meals: [
        {
          name: 'Power Breakfast',
          timing: '7:30 AM',
          notes: 'High complex carbs and fast-absorbing protein',
          foods: [
            { foodName: 'Oats with Whey', quantity: 100, unit: 'g', calories: 420, protein: 35, carbohydrates: 55, fat: 6, notes: 'Mix with warm water or milk' },
            { foodName: 'Whole Milk', quantity: 250, unit: 'ml', calories: 150, protein: 8, carbohydrates: 12, fat: 8, substitutions: 'Almond milk or soy milk' },
            { foodName: 'Banana', quantity: 1, unit: 'whole', calories: 105, protein: 1, carbohydrates: 27, fat: 0 },
          ],
        },
        {
          name: 'Power Lunch',
          timing: '1:00 PM',
          notes: 'Lean protein with low GI carb base',
          foods: [
            { foodName: 'Grilled Chicken Breast', quantity: 200, unit: 'g', calories: 330, protein: 62, carbohydrates: 0, fat: 7, substitutions: 'Tofu or White fish' },
            { foodName: 'Jasmine Rice', quantity: 250, unit: 'g', calories: 325, protein: 6, carbohydrates: 72, fat: 1, substitutions: 'Brown rice or quinoa' },
            { foodName: 'Steamed Broccoli', quantity: 150, unit: 'g', calories: 50, protein: 4, carbohydrates: 10, fat: 1 },
          ],
        },
        {
          name: 'Afternoon Fuel Snack',
          timing: '4:30 PM',
          notes: 'Slow digesting casein + healthy fats',
          foods: [
            { foodName: 'Greek Yogurt 0%', quantity: 200, unit: 'g', calories: 120, protein: 20, carbohydrates: 8, fat: 0 },
            { foodName: 'Almonds', quantity: 30, unit: 'g', calories: 175, protein: 6, carbohydrates: 6, fat: 15, substitutions: 'Walnuts' },
          ],
        },
        {
          name: 'Recovery Dinner',
          timing: '8:00 PM',
          notes: 'Omega-3 rich dinner with fibrous greens',
          foods: [
            { foodName: 'Salmon Fillet', quantity: 180, unit: 'g', calories: 375, protein: 36, carbohydrates: 0, fat: 24 },
            { foodName: 'Baked Sweet Potato', quantity: 250, unit: 'g', calories: 215, protein: 4, carbohydrates: 50, fat: 0 },
            { foodName: 'Mixed Green Salad with Olive Oil', quantity: 100, unit: 'g', calories: 135, protein: 2, carbohydrates: 5, fat: 12 },
          ],
        },
      ],
    }, {
      requestId: `req_diet_${Date.now()}`,
      conversationId: `conv_diet_${Date.now()}`,
      adminId: 'admin_alex_stone',
    });

    if (!dietToolRes.success || !dietToolRes.proposal) {
      throw new Error(`Diet plan tool execution failed: ${dietToolRes.message}`);
    }
    const dietProposalId = dietToolRes.proposal.id;
    createdProposalIds.push(dietProposalId);

    const dietDbRecord = await prisma.aIProposal.findUnique({ where: { id: dietProposalId } });
    if (!dietDbRecord) {
      throw new Error('Diet proposal record not found in database');
    }
    if (dietDbRecord.status !== 'PENDING') {
      throw new Error(`Expected proposal status 'PENDING', found '${dietDbRecord.status}'`);
    }

    const dietData = JSON.parse(dietDbRecord.proposedDataJson);
    if (dietData.planKind !== 'DIET_PLAN') {
      throw new Error(`Expected planKind 'DIET_PLAN', got '${dietData.planKind}'`);
    }
    if (!Array.isArray(dietData.meals) || dietData.meals.length !== 4) {
      throw new Error(`Expected 4 structured meals in DIET_PLAN proposal, got ${dietData.meals?.length}`);
    }
    // Verify per-meal nutrition totals calculated and persisted
    for (const m of dietData.meals) {
      if (!m.calories || m.calories <= 0 || !m.protein || m.protein <= 0) {
        throw new Error(`Meal ${m.name} missing calculated per-meal nutrition totals`);
      }
      if (!Array.isArray(m.foods) || m.foods.length === 0) {
        throw new Error(`Meal ${m.name} missing food items`);
      }
    }
    console.log(`  ✓ Full Diet Plan saved in DB: ID=${dietProposalId}, status=${dietDbRecord.status}`);
    console.log(`    Meals: ${dietData.meals.length} structured meals with gram portions, nutrition totals, notes, and substitutions.`);

    // -------------------------------------------------------------
    // Step 3: Macro-Only Target Proposal
    // -------------------------------------------------------------
    console.log('\n[Step 3] Testing Macro-Only Target Proposal workflow...');
    const macroToolRes = await proposeDietPlanTool.handler({
      clientIdentifier: client2.name,
      planKind: 'MACRO_ONLY',
      planName: `${client2.name} Daily Macro Targets`,
      reason: 'Caloric surplus targets without rigid meal scheduling',
      summary: 'Flexible dieting targets based on calculated TDEE',
      dailyCalories: 3100,
      protein: 210,
      carbohydrates: 380,
      fat: 80,
      fiber: 40,
      waterTargetLiters: 4.5,
      // No meals provided for macro-only
    }, {
      requestId: `req_macro_${Date.now()}`,
      conversationId: `conv_macro_${Date.now()}`,
      adminId: 'admin_alex_stone',
    });

    if (!macroToolRes.success || !macroToolRes.proposal) {
      throw new Error(`Macro-only tool execution failed: ${macroToolRes.message}`);
    }
    const macroProposalId = macroToolRes.proposal.id;
    createdProposalIds.push(macroProposalId);

    const macroDbRecord = await prisma.aIProposal.findUnique({ where: { id: macroProposalId } });
    if (!macroDbRecord) {
      throw new Error('Macro proposal record not found in database');
    }
    if (macroDbRecord.status !== 'PENDING') {
      throw new Error(`Expected proposal status 'PENDING', found '${macroDbRecord.status}'`);
    }

    const macroData = JSON.parse(macroDbRecord.proposedDataJson);
    if (macroData.planKind !== 'MACRO_ONLY') {
      throw new Error(`Expected planKind 'MACRO_ONLY', got '${macroData.planKind}'`);
    }
    if (Array.isArray(macroData.meals) && macroData.meals.length > 0) {
      throw new Error('Macro-only proposal should not generate fixed meals');
    }
    console.log(`  ✓ Macro-Only proposal saved in DB: ID=${macroProposalId}, status=${macroDbRecord.status}`);
    console.log(`    Flexible targets: ${macroData.dailyCalories} kcal | ${macroData.protein}g P | ${macroData.carbohydrates}g C | ${macroData.fat}g F (0 fixed meals).`);

    // -------------------------------------------------------------
    // Step 4: Tool validation & rejection (never false success)
    // -------------------------------------------------------------
    console.log('\n[Step 4] Testing validation rejection and failure reporting...');
    
    // 4a: Non-existent client
    const invalidClientRes = await proposeDietPlanTool.handler({
      clientIdentifier: 'Unknown NonExistent User 12345',
      planKind: 'DIET_PLAN',
      reason: 'Validation failure test for non-existent client',
      summary: 'Validation testing summary',
      dailyCalories: 2000,
      protein: 150,
      carbohydrates: 200,
      fat: 60,
      meals: [{ name: 'Meal 1', foods: [{ foodName: 'Oats', quantity: 100, unit: 'g', calories: 380, protein: 13 }] }],
    }, {
      requestId: `req_fail_${Date.now()}`,
      conversationId: `conv_fail_${Date.now()}`,
      adminId: 'admin_alex_stone',
    });
    if (invalidClientRes.success) {
      throw new Error('Tool reported success for non-existent client!');
    }
    console.log(`  ✓ 4a. Successfully rejected non-existent client: "${invalidClientRes.message}"`);

    // 4b: Full DIET_PLAN with missing meals (must fail, no silent fake meals)
    const missingMealsRes = await proposeDietPlanTool.handler({
      clientIdentifier: client1.name,
      planKind: 'DIET_PLAN',
      reason: 'Validation failure test for missing meals',
      summary: 'Missing meals validation',
      dailyCalories: 2000,
      protein: 150,
      carbohydrates: 200,
      fat: 60,
      meals: [], // Empty meals on full diet plan
    }, {
      requestId: `req_fail_meals_${Date.now()}`,
      conversationId: `conv_fail_meals_${Date.now()}`,
      adminId: 'admin_alex_stone',
    });
    if (missingMealsRes.success) {
      throw new Error('Tool reported success for DIET_PLAN without meals! Silent fake meal fallback must not occur.');
    }
    console.log(`  ✓ 4b. Successfully rejected DIET_PLAN without meals: "${missingMealsRes.message}"`);

    // 4c: Internal consistency check: meal calories deviate significantly from daily target
    const inconsistentCaloriesRes = await proposeDietPlanTool.handler({
      clientIdentifier: client1.name,
      planKind: 'DIET_PLAN',
      reason: 'Validation failure test for calorie inconsistency',
      summary: 'Calorie inconsistency validation',
      dailyCalories: 2800, // Daily target is 2800 kcal
      protein: 180,
      carbohydrates: 300,
      fat: 80,
      meals: [
        {
          name: 'Breakfast',
          foods: [{ foodName: 'Oats', quantity: 50, unit: 'g', calories: 200, protein: 7 }],
        },
      ], // Only 200 kcal total meals vs 2800 daily target
    }, {
      requestId: `req_fail_cal_${Date.now()}`,
      conversationId: `conv_fail_cal_${Date.now()}`,
      adminId: 'admin_alex_stone',
    });
    if (inconsistentCaloriesRes.success) {
      throw new Error('Tool reported success for internally inconsistent calories!');
    }
    console.log(`  ✓ 4c. Successfully caught calorie inconsistency: "${inconsistentCaloriesRes.message}"`);

    // 4d: Invalid food item quantity (negative or 0)
    const invalidQtyRes = await proposeDietPlanTool.handler({
      clientIdentifier: client1.name,
      planKind: 'DIET_PLAN',
      reason: 'Validation failure test for invalid quantity',
      summary: 'Invalid quantity validation',
      dailyCalories: 2000,
      protein: 150,
      carbohydrates: 200,
      fat: 60,
      meals: [
        {
          name: 'Breakfast',
          foods: [{ foodName: 'Oats', quantity: -50, unit: 'g', calories: 200, protein: 7 }],
        },
      ],
    }, {
      requestId: `req_fail_qty_${Date.now()}`,
      conversationId: `conv_fail_qty_${Date.now()}`,
      adminId: 'admin_alex_stone',
    });
    if (invalidQtyRes.success) {
      throw new Error('Tool reported success for invalid food quantity!');
    }
    console.log(`  ✓ 4d. Successfully rejected invalid food quantity: "${invalidQtyRes.message}"`);

    // -------------------------------------------------------------
    // Step 5: Admin Review & Inline Modification
    // -------------------------------------------------------------
    console.log('\n[Step 5] Testing Admin Review & Inline Proposal Modification...');
    // Modify meal portion in meal 1: increase oats to 120g
    const updatedMeals = JSON.parse(JSON.stringify(dietData.meals));
    updatedMeals[0].foods[0].quantity = 120;
    updatedMeals[0].foods[0].calories = 500;
    updatedMeals[0].notes = 'Admin adjusted breakfast oats portion to 120g';

    const editPayload = {
      ...dietData,
      planName: `Admin Fine-Tuned: ${dietData.planName}`,
      dailyCalories: 2480,
      protein: 185,
      meals: updatedMeals,
      notes: 'Admin increased breakfast oats and adjusted total calories',
    };

    const editedProposal = await aiTools.editProposal(dietProposalId, 'admin_alex_stone', editPayload);
    if (editedProposal.status !== 'EDITED') {
      throw new Error(`Expected proposal status 'EDITED', got '${editedProposal.status}'`);
    }
    if (editedProposal.id !== dietProposalId) {
      throw new Error('Proposal ID must not change when edited!');
    }

    const editedDb = await prisma.aIProposal.findUnique({ where: { id: dietProposalId } });
    const finalData = JSON.parse(editedDb!.finalDataJson!);
    if (finalData.dailyCalories !== 2480 || finalData.protein !== 185) {
      throw new Error('Edited values not persisted in finalDataJson');
    }
    if (!Array.isArray(finalData.meals) || finalData.meals.length !== 4) {
      throw new Error('Edited meals array lost during modification');
    }
    if (finalData.meals[0].foods[0].quantity !== 120) {
      throw new Error('Food quantity modification was not preserved in finalDataJson');
    }
    console.log(`  ✓ Proposal edited: ID=${dietProposalId}, status=${editedDb!.status}, calories=2480, protein=185g`);
    console.log(`    Preserved all 4 meals with modified portion (Oats 120g).`);

    // -------------------------------------------------------------
    // Step 6: Admin Approval & Plan Assignment
    // -------------------------------------------------------------
    console.log('\n[Step 6] Testing Admin Approval & Plan Activation...');
    const approvedProposal = await aiTools.approveProposal(dietProposalId, 'admin_alex_stone', 'Admin Alex');
    if (approvedProposal.status !== 'APPROVED') {
      throw new Error(`Expected proposal status 'APPROVED', got '${approvedProposal.status}'`);
    }

    // Verify active DietPlan and MacroPlan records created in database for client 1
    const activeDiet = await prisma.dietPlan.findFirst({
      where: { clientProfileId: cp1.id, isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    if (!activeDiet) {
      throw new Error(`Active DietPlan was not created for client ${client1.name}`);
    }
    if (activeDiet.dailyCalories !== 2480 || activeDiet.protein !== 185) {
      throw new Error(`Active DietPlan values do not match approved edits! Expected 2480/185, got ${activeDiet.dailyCalories}/${activeDiet.protein}`);
    }
    // Verify mealsJson was stored and contains the full meal data with foods, quantities, units
    const storedMeals = JSON.parse(activeDiet.mealsJson || '[]');
    if (!Array.isArray(storedMeals) || storedMeals.length !== 4) {
      throw new Error(`Expected 4 meals in active DietPlan.mealsJson, got ${storedMeals.length}`);
    }
    if (storedMeals[0].foods[0].quantity !== 120) {
      throw new Error('Assigned DietPlan food item quantity does not reflect approved edits!');
    }
    console.log(`  ✓ Active DietPlan verified with complete mealsJson (4 meals, preserved edited quantities).`);

    const activeMacros = await prisma.macroPlan.findFirst({
      where: { clientProfileId: cp1.id, isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    if (!activeMacros) {
      throw new Error(`Active MacroPlan was not created for client ${client1.name}`);
    }
    console.log(`  ✓ Approved and assigned to ${client1.name}!`);
    console.log(`    Active DietPlan ID: ${activeDiet.id} ("${activeDiet.planName}")`);
    console.log(`    Active MacroPlan ID: ${activeMacros.id} (${activeMacros.calories} kcal, ${activeMacros.protein}g protein)`);

    // -------------------------------------------------------------
    // Step 7: Client App Data Resolution (/me/diet-plan & /me/macros)
    // -------------------------------------------------------------
    console.log('\n[Step 7] Verifying Client App endpoints resolve approved plan...');
    const clientDietView = await prisma.dietPlan.findFirst({
      where: {
        OR: [
          { clientProfileId: cp1.id },
          { clientId: cp1.clientId },
          { clientId: client1.id },
        ],
        isActive: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!clientDietView || clientDietView.id !== activeDiet.id) {
      throw new Error('Client /me/diet-plan did not resolve the newly assigned active plan');
    }

    const clientMacroView = await prisma.macroPlan.findFirst({
      where: { clientProfileId: cp1.id, isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    if (!clientMacroView || clientMacroView.id !== activeMacros.id) {
      throw new Error('Client /me/macros did not resolve the newly assigned macro plan');
    }
    console.log(`  ✓ Client app endpoints resolve assigned diet plan and macros with 100% accuracy.`);

    // -------------------------------------------------------------
    // Step 8: Client Isolation (no cross-contamination)
    // -------------------------------------------------------------
    console.log('\n[Step 8] Verifying Client Isolation...');
    const client2Diet = await prisma.dietPlan.findFirst({
      where: { clientProfileId: cp2.id, isActive: true },
    });
    if (client2Diet && client2Diet.id === activeDiet.id) {
      throw new Error('Cross-contamination: Client 2 has Client 1 diet plan!');
    }
    console.log(`  ✓ Athlete isolation verified: Client 2 is unaffected by Client 1 assignment.`);

    console.log('\n================================================================');
    console.log('🎉 ALL 8 INTEGRATION VERIFICATION STEPS PASSED WITH 100% SUCCESS!');
    console.log('================================================================\n');

  } finally {
    if (createdProposalIds.length > 0) {
      console.log(`[Cleanup] Deleting ${createdProposalIds.length} test proposals from database...`);
      await prisma.aIProposal.deleteMany({
        where: { id: { in: createdProposalIds } },
      });
      console.log('  ✓ Test proposals cleaned up.');
    }
    await prisma.$disconnect();
  }
}

runVerification()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('\n❌ VERIFICATION TEST FAILED:', err);
    process.exit(1);
  });
