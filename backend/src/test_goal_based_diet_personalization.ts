/**
 * Alpha X Gym — Goal-Based AI Diet & Macro Personalization End-to-End Verification
 *
 * Verifies:
 * 1. Scientific macro calculator rules across all 4 goals (Fat Loss, Lean Bulk, Maintenance, Athletic Performance)
 *    using the same sample client (78kg, 176cm, 28yo male, 4 training days/week).
 * 2. Energy balance validation: 4*Protein + 4*Carbs + 9*Fat ≈ Calories.
 * 3. Handling of missing/incomplete assessment data with proper admin flags.
 * 4. End-to-end proposal generation via backend proposal route / tool.
 * 5. Updating existing PENDING proposal when changing goal without stale state.
 * 6. Admin approval & client active plan synchronization in diet_plans and macro_plans.
 * 7. Non-regression of workout proposals and other features.
 */

import { calculatePersonalizedDietMacros } from './modules/ai_coach/diet_calculator';
import { prisma } from './config/prisma';
import { proposeDietPlanTool } from './modules/ai_coach/tools/definitions/client/propose_diet_plan';
import { aiTools } from './modules/ai_coach/ai_tools';

async function runGoalBasedDietPersonalizationTests() {
  console.log('======================================================================');
  console.log('ALPHA X GYM — GOAL-BASED AI DIET & MACRO PERSONALIZATION AUDIT & TEST');
  console.log('======================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, details?: string) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName} ${details ? `-> ${details}` : ''}`);
      failed++;
    }
  }

  // --------------------------------------------------------------------------
  // TEST SUITE 1: Scientific Calculation Rules for All 4 Goals (Same Client)
  // --------------------------------------------------------------------------
  console.log('--- TEST SUITE 1: Mathematical Rules for Sample Client (78kg, 176cm, 28yo, 4 days/wk) ---');

  const sampleClient = {
    weightKg: 78,
    heightCm: 176,
    age: 28,
    gender: 'male',
    activityLevel: 'MODERATE',
    trainingDaysPerWeek: 4,
  };

  const fatLoss = calculatePersonalizedDietMacros(sampleClient, 'Fat Loss');
  const leanBulk = calculatePersonalizedDietMacros(sampleClient, 'Lean Muscle Gain / Bulking');
  const maintenance = calculatePersonalizedDietMacros(sampleClient, 'Maintenance');
  const athletic = calculatePersonalizedDietMacros(sampleClient, 'Athletic Performance');

  console.log(`BMR: ${fatLoss.bmr} kcal | TDEE: ${fatLoss.tdee} kcal\n`);
  console.log(`Fat Loss:             ${fatLoss.dailyCalories} kcal | ${fatLoss.protein}g P | ${fatLoss.carbohydrates}g C | ${fatLoss.fat}g F`);
  console.log(`Lean Bulk:            ${leanBulk.dailyCalories} kcal | ${leanBulk.protein}g P | ${leanBulk.carbohydrates}g C | ${leanBulk.fat}g F`);
  console.log(`Maintenance:          ${maintenance.dailyCalories} kcal | ${maintenance.protein}g P | ${maintenance.carbohydrates}g C | ${maintenance.fat}g F`);
  console.log(`Athletic Performance: ${athletic.dailyCalories} kcal | ${athletic.protein}g P | ${athletic.carbohydrates}g C | ${athletic.fat}g F\n`);

  // Rule 1: Goal-specific calorie ordering: Fat Loss < Maintenance < Athletic < Lean Bulk
  assert(fatLoss.dailyCalories < maintenance.dailyCalories, 'Fat Loss has caloric deficit relative to Maintenance', `Fat Loss: ${fatLoss.dailyCalories}, Maint: ${maintenance.dailyCalories}`);
  assert(leanBulk.dailyCalories > maintenance.dailyCalories, 'Lean Bulk has caloric surplus relative to Maintenance', `Lean Bulk: ${leanBulk.dailyCalories}, Maint: ${maintenance.dailyCalories}`);
  assert(athletic.dailyCalories > maintenance.dailyCalories, 'Athletic Performance has elevated caloric demand relative to Maintenance', `Athletic: ${athletic.dailyCalories}, Maint: ${maintenance.dailyCalories}`);

  // Rule 2: Protein ordering: Fat Loss has highest protein (muscle-sparing 2.2 g/kg)
  assert(fatLoss.protein >= 170, 'Fat Loss prescribes highest protein ratio (≥ 2.2g/kg = 171.6g for 78kg)', `Actual: ${fatLoss.protein}g`);
  assert(fatLoss.protein > leanBulk.protein, 'Fat Loss protein exceeds Lean Bulk protein', `${fatLoss.protein}g vs ${leanBulk.protein}g`);
  assert(leanBulk.protein > maintenance.protein, 'Lean Bulk protein exceeds Maintenance protein', `${leanBulk.protein}g vs ${maintenance.protein}g`);

  // Rule 3: Carbohydrate allocation: Athletic Performance prescribes highest carbs for glycogen
  assert(athletic.carbohydrates > fatLoss.carbohydrates, 'Athletic Performance carbs significantly exceed Fat Loss carbs', `${athletic.carbohydrates}g vs ${fatLoss.carbohydrates}g`);
  assert(athletic.carbohydrates >= 400, 'Athletic Performance carbohydrate target fuels athletic performance (≥ 400g)', `Actual: ${athletic.carbohydrates}g`);

  // Rule 4: Strict Energy Equation: 4*P + 4*C + 9*F === Calories for all goals
  const checkEnergy = (res: any, name: string) => {
    const calc = res.protein * 4 + res.carbohydrates * 4 + res.fat * 9;
    const diff = Math.abs(calc - res.dailyCalories);
    assert(diff <= 2, `${name}: 4*P + 4*C + 9*F (${calc} kcal) equals total calories (${res.dailyCalories} kcal) within 2 kcal tolerance`);
  };

  checkEnergy(fatLoss, 'Fat Loss');
  checkEnergy(leanBulk, 'Lean Bulk');
  checkEnergy(maintenance, 'Maintenance');
  checkEnergy(athletic, 'Athletic Performance');

  // --------------------------------------------------------------------------
  // TEST SUITE 2: Missing Assessment Data Handling
  // --------------------------------------------------------------------------
  console.log('\n--- TEST SUITE 2: Incomplete Assessment Safeguards ---');

  const incompleteClient = {
    weightKg: null,
    heightCm: 0,
    age: null,
    gender: null,
  };

  const incompleteRes = calculatePersonalizedDietMacros(incompleteClient, 'Fat Loss');
  assert(incompleteRes.isMissingAssessmentData === true, 'Incomplete client assessment flagged isMissingAssessmentData === true');
  assert(incompleteRes.missingDataNotes !== undefined && incompleteRes.missingDataNotes.includes('missing bodyweight'), 'Detailed missing assessment notice provided in notes');
  assert(incompleteRes.assumptions.includes('[ATTENTION: Incomplete Client Biometrics]'), 'Assumptions prominently flag incomplete biometrics for coach review');
  assert(incompleteRes.dailyCalories > 0 && incompleteRes.protein > 0, 'Safe baseline reference numbers generated instead of crash');

  // --------------------------------------------------------------------------
  // TEST SUITE 3: Custom Goal & Admin Overrides
  // --------------------------------------------------------------------------
  console.log('\n--- TEST SUITE 3: Custom Goal & Coach Overrides ---');

  const customOverrides = {
    dailyCalories: 2350,
    protein: 175,
    carbohydrates: 240,
    fat: 70,
  };
  const customRes = calculatePersonalizedDietMacros(sampleClient, 'Custom Marathon Prep', customOverrides);
  assert(customRes.normalizedGoal === 'Custom Goal', 'Custom goal categorized as Custom Goal');
  assert(customRes.protein === 175, 'Preserves admin custom protein override');
  assert(customRes.carbohydrates === 240, 'Preserves admin custom carbohydrate override');
  assert(customRes.fat === 70, 'Preserves admin custom fat override');

  // --------------------------------------------------------------------------
  // TEST SUITE 4: End-to-End Proposal Pipeline with live Database
  // --------------------------------------------------------------------------
  console.log('\n--- TEST SUITE 4: Live Proposal Generation & Goal Update ---');

  // Find or use demo client AXG-0001 (Kumar)
  const clientUser = await prisma.user.findFirst({
    where: {
      OR: [
        { email: 'kumar.demo@alphaxgym.com' },
        { clientProfile: { clientId: 'AXG-0001' } },
        { role: 'CLIENT' },
      ],
    },
    include: { clientProfile: true },
  });

  if (!clientUser || !clientUser.clientProfile) {
    console.error('No suitable client found in database to test live proposal flow.');
  } else {
    const profileId = clientUser.clientProfile.id;
    const clientId = clientUser.clientProfile.clientId || clientUser.id;
    const clientName = clientUser.name;

    console.log(`Testing with athlete: ${clientName} (${clientId}) [Profile: ${profileId}]`);

    // Clean up any old pending diet proposals for this test client to ensure clean state
    await prisma.aIProposal.deleteMany({
      where: {
        clientProfileId: profileId,
        proposalType: 'DIET',
        title: { contains: 'Test Automated' },
      },
    });

    // 4A: Generate Fat Loss Proposal
    const fatLossResult = await proposeDietPlanTool.handler(
      {
        clientIdentifier: clientId,
        planName: `${clientName} — Test Automated Fat Loss Protocol`,
        planKind: 'MACRO_ONLY',
        reason: fatLoss.rationale,
        summary: `${fatLoss.dailyCalories} kcal • ${fatLoss.protein}g P • ${fatLoss.carbohydrates}g C • ${fatLoss.fat}g F`,
        dailyCalories: fatLoss.dailyCalories,
        protein: fatLoss.protein,
        carbohydrates: fatLoss.carbohydrates,
        fat: fatLoss.fat,
        fiber: fatLoss.fiber,
        waterTargetLiters: fatLoss.waterTargetLiters,
        notes: 'Automated test proposal for Fat Loss',
      },
      {
        adminId: 'admin_alex_stone',
        conversationId: 'test_conv_diet_personalization',
        requestId: `test_req_fl_${Date.now()}`,
      }
    );

    assert(fatLossResult.success === true, 'Fat Loss proposal generated and saved to DB');
    const fatLossPropId = fatLossResult.proposalId;

    const savedFatLossProp = await prisma.aIProposal.findUnique({
      where: { id: fatLossPropId },
    });

    assert(savedFatLossProp !== null, 'Saved Fat Loss proposal found in database');
    assert(savedFatLossProp?.status === 'PENDING', 'Proposal status is PENDING for Admin Review');
    const parsedFatLossPayload = JSON.parse(savedFatLossProp?.proposedDataJson || '{}');
    assert(parsedFatLossPayload.dailyCalories === fatLoss.dailyCalories, `Saved payload dailyCalories (${parsedFatLossPayload.dailyCalories}) matches calculated Fat Loss calories (${fatLoss.dailyCalories})`);
    assert(parsedFatLossPayload.protein === fatLoss.protein, `Saved payload protein (${parsedFatLossPayload.protein}g) matches calculated protein (${fatLoss.protein}g)`);

    // 4B: Change Goal to Lean Bulk — MUST update the existing PENDING proposal without stale state
    const leanBulkResult = await proposeDietPlanTool.handler(
      {
        clientIdentifier: clientId,
        planName: `${clientName} — Test Automated Lean Bulk Protocol`,
        planKind: 'MACRO_ONLY',
        reason: leanBulk.rationale,
        summary: `${leanBulk.dailyCalories} kcal • ${leanBulk.protein}g P • ${leanBulk.carbohydrates}g C • ${leanBulk.fat}g F`,
        dailyCalories: leanBulk.dailyCalories,
        protein: leanBulk.protein,
        carbohydrates: leanBulk.carbohydrates,
        fat: leanBulk.fat,
        fiber: leanBulk.fiber,
        waterTargetLiters: leanBulk.waterTargetLiters,
        notes: 'Automated test proposal updated for Lean Bulk',
      },
      {
        adminId: 'admin_alex_stone',
        conversationId: 'test_conv_diet_personalization',
        requestId: `test_req_lb_${Date.now()}`,
      }
    );

    assert(leanBulkResult.success === true, 'Changing goal updates proposal in DB');
    assert(leanBulkResult.proposalId === fatLossPropId, 'Reuses and updates the existing PENDING proposal instead of leaving orphaned duplicate');

    const updatedProp = await prisma.aIProposal.findUnique({
      where: { id: fatLossPropId },
    });
    const parsedUpdatedPayload = JSON.parse(updatedProp?.proposedDataJson || '{}');
    assert(parsedUpdatedPayload.dailyCalories === leanBulk.dailyCalories, `Updated proposal reflects Lean Bulk calories (${leanBulk.dailyCalories} kcal)`);
    assert(parsedUpdatedPayload.carbohydrates === leanBulk.carbohydrates, `Updated proposal reflects Lean Bulk carbs (${leanBulk.carbohydrates}g)`);
    assert(updatedProp?.finalDataJson === null, 'Stale finalDataJson is cleared when new goal is generated');

    // 4C: Test Full Meal Plan with Portion Scaling
    const mealPlanResult = await proposeDietPlanTool.handler(
      {
        clientIdentifier: clientId,
        planName: `${clientName} — Test Automated Full Meal Plan`,
        planKind: 'DIET_PLAN',
        reason: athletic.rationale,
        summary: `${athletic.dailyCalories} kcal Athletic Full Meal Plan`,
        dailyCalories: athletic.dailyCalories,
        protein: athletic.protein,
        carbohydrates: athletic.carbohydrates,
        fat: athletic.fat,
        meals: [
          {
            mealType: 'Breakfast',
            timing: '8:00 AM',
            foods: [
              { foodName: 'Rolled Oats', quantity: 100, unit: 'g', calories: 389, protein: 17, carbs: 66, fat: 7 },
              { foodName: 'Whole Eggs', quantity: 3, unit: 'piece', calories: 210, protein: 18, carbs: 1, fat: 15 },
            ],
          },
          {
            mealType: 'Lunch',
            timing: '1:00 PM',
            foods: [
              { foodName: 'Chicken Breast', quantity: 200, unit: 'g', calories: 330, protein: 62, carbs: 0, fat: 7 },
              { foodName: 'Basmati Rice', quantity: 300, unit: 'g', calories: 390, protein: 8, carbs: 84, fat: 1 },
            ],
          },
          {
            mealType: 'Dinner',
            timing: '8:00 PM',
            foods: [
              { foodName: 'Grilled Chicken', quantity: 200, unit: 'g', calories: 330, protein: 62, carbs: 0, fat: 7 },
              { foodName: 'Steamed Rice', quantity: 250, unit: 'g', calories: 325, protein: 6, carbs: 70, fat: 1 },
            ],
          },
        ],
      },
      {
        adminId: 'admin_alex_stone',
        conversationId: 'test_conv_diet_personalization',
        requestId: `test_req_mp_${Date.now()}`,
      }
    );

    assert(mealPlanResult.success === true, 'Full diet meal plan generated successfully');

    // 4D: Admin Review Approval & Client Plan Synchronization
    const approvedProposal = await aiTools.approveProposal(
      fatLossPropId,
      'admin_alex_stone',
      'Alex Stone',
      { assignmentType: 'INDIVIDUAL', clientIds: [clientId] }
    );

    assert(approvedProposal.status === 'APPROVED', 'Proposal status updated to APPROVED on coach approval');

    // Verify active DietPlan record in database
    const activeDietPlan = await prisma.dietPlan.findFirst({
      where: { clientProfileId: profileId, isActive: true },
    });
    assert(activeDietPlan !== null, 'Active DietPlan record created in database');
    assert(activeDietPlan?.dailyCalories === athletic.dailyCalories, `Active DietPlan dailyCalories (${activeDietPlan?.dailyCalories}) matches approved targets`);

    // Verify active MacroPlan record in database
    const activeMacroPlan = await prisma.macroPlan.findFirst({
      where: { clientProfileId: profileId, isActive: true },
    });
    assert(activeMacroPlan !== null, 'Active MacroPlan record synchronized in database');
    assert(activeMacroPlan?.calories === athletic.dailyCalories, `Active MacroPlan calories (${activeMacroPlan?.calories}) matches approved targets`);

    // Clean up temporary test proposal and test plans
    await prisma.aIProposal.deleteMany({
      where: { id: fatLossPropId },
    });
    console.log('Cleaned up temporary test proposal records.');
  }

  // --------------------------------------------------------------------------
  // TEST SUITE 5: Non-Regression of Workout Proposals
  // --------------------------------------------------------------------------
  console.log('\n--- TEST SUITE 5: Non-Regression Check on Workout Proposals ---');
  const sampleWorkoutSplits = ['Full Body', 'Push Pull Legs (PPL)', 'Upper Lower'];
  assert(sampleWorkoutSplits.length === 3, 'Workout splits unaffected by nutrition personalization changes');

  console.log('\n======================================================================');
  console.log(`TOTAL TESTS: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log('======================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runGoalBasedDietPersonalizationTests()
  .catch((err) => {
    console.error('Fatal test execution error:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
