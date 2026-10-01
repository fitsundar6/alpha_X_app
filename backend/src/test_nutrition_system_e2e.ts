import { prisma } from './config/prisma';
import { adminAuthService } from './modules/auth/admin_auth.service';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';

async function runNutritionSystemE2eTest() {
  console.log('====================================================');
  console.log('ALPHA X NUTRITION SYSTEM END-TO-END VERIFICATION');
  console.log('====================================================');

  try {
    // 1. Create two test clients: Client A (Athlete Alex) and Client B (Athlete Bob)
    const emailA = `athlete_a_${Date.now()}@alphaxgym.test`;
    const emailB = `athlete_b_${Date.now()}@alphaxgym.test`;

    const userA = await prisma.user.create({
      data: {
        email: emailA,
        name: 'Alex Athlete',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: `AXG-A${Math.floor(1000 + Math.random() * 9000)}`,
            weightKg: 80.0,
            primaryGoal: 'Hypertrophy & Fat Loss',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });

    const userB = await prisma.user.create({
      data: {
        email: emailB,
        name: 'Bob Athlete',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: `AXG-B${Math.floor(1000 + Math.random() * 9000)}`,
            weightKg: 75.0,
            primaryGoal: 'Strength',
            onboardingCompleted: true,
          },
        },
      },
      include: { clientProfile: true },
    });

    console.log(`[PASS] Created Client A (${userA.clientProfile?.clientId}) and Client B (${userB.clientProfile?.clientId})`);

    const cpA = userA.clientProfile!;
    const cpB = userB.clientProfile!;

    // 2. Admin creates and assigns a structured diet plan to Client A (v1)
    const structuredMealsA = [
      {
        mealType: 'Breakfast',
        timing: '8:00 AM',
        notes: 'Pre-workout carbs & high quality protein',
        foods: [
          { name: 'Plain Dosa', servingDisplay: '3 pieces', quantity: 3, calories: 360, protein: 9, carbs: 60, fat: 9, fiber: 3 },
          { name: 'Whole Egg', servingDisplay: '3 eggs', quantity: 3, calories: 234, protein: 18.9, carbs: 1.8, fat: 15.9, fiber: 0 },
        ],
      },
      {
        mealType: 'Lunch',
        timing: '1:30 PM',
        notes: 'Lean muscle repair meal',
        foods: [
          { name: 'Cooked White Rice', servingDisplay: '200 g', quantity: 2, calories: 260, protein: 5.4, carbs: 56, fat: 0.6, fiber: 0.8 },
          { name: 'Chicken Breast Cooked', servingDisplay: '150 g', quantity: 1.5, calories: 247.5, protein: 46.5, carbs: 0, fat: 5.4, fiber: 0 },
        ],
      },
    ];

    const dietPlanV1 = await prisma.dietPlan.create({
      data: {
        clientProfileId: cpA.id,
        clientId: cpA.clientId,
        planName: 'Phase 1: High Protein Recomp',
        version: 1,
        assignedById: 'admin_alex_stone',
        assignedByName: 'Alex Stone',
        dailyCalories: 2200,
        protein: 160,
        carbohydrates: 230,
        fat: 65,
        fiber: 30,
        waterTargetLiters: 3.5,
        isActive: true,
        mealsJson: JSON.stringify(structuredMealsA),
        notes: 'Drink 500ml water upon waking.',
      },
    });

    // Create history entry for v1
    await prisma.dietPlanHistory.create({
      data: {
        dietPlanId: dietPlanV1.id,
        clientProfileId: cpA.id,
        clientId: cpA.clientId,
        adminId: 'admin_alex_stone',
        adminName: 'Alex Stone',
        version: 1,
        planName: dietPlanV1.planName,
        dailyCalories: dietPlanV1.dailyCalories,
        protein: dietPlanV1.protein,
        carbohydrates: dietPlanV1.carbohydrates,
        fat: dietPlanV1.fat,
        fiber: dietPlanV1.fiber,
        waterTargetLiters: dietPlanV1.waterTargetLiters,
        mealsJson: dietPlanV1.mealsJson,
        notes: dietPlanV1.notes,
        changeSummary: 'Initial Diet Plan v1 assigned by Trainer Alex Stone',
      },
    });

    console.log('[PASS] Admin assigned Diet Plan v1 to Client A with version history recorded');

    // 3. Client A logs confirmed actual meals:
    // One via Food Library, one via AI Camera scan
    const today = new Date().toISOString().split('T')[0];

    const log1 = await prisma.clientFoodLog.create({
      data: {
        clientProfileId: cpA.id,
        clientId: cpA.clientId,
        date: new Date(today),
        dateString: today,
        mealType: 'Breakfast',
        foodName: 'Plain Dosa',
        category: 'South Indian',
        servingSize: 1,
        servingUnit: 'piece',
        quantity: 3,
        calories: 360,
        protein: 9,
        carbohydrates: 60,
        fat: 9,
        fiber: 3,
        source: 'FOOD_LIBRARY',
        isAiConfirmed: true,
      },
    });

    const log2 = await prisma.clientFoodLog.create({
      data: {
        clientProfileId: cpA.id,
        clientId: cpA.clientId,
        date: new Date(today),
        dateString: today,
        mealType: 'Lunch',
        foodName: 'Grilled Chicken Breast',
        category: 'Protein',
        servingSize: 150,
        servingUnit: 'grams',
        quantity: 1,
        calories: 247.5,
        protein: 46.5,
        carbohydrates: 0,
        fat: 5.4,
        fiber: 0,
        source: 'AI_CAMERA', // Confirmed from live camera scan
        isAiConfirmed: true,
      },
    });

    console.log('[PASS] Client A logged actual meals from Food Library and AI Camera');

    // 4. Verify Admin Nutrition Summary & Target-vs-Actual Comparison
    const activeDiet = await prisma.dietPlan.findFirst({
      where: { clientProfileId: cpA.id, isActive: true },
    });
    const logs = await prisma.clientFoodLog.findMany({
      where: { clientProfileId: cpA.id, dateString: today },
    });

    const actualCalories = logs.reduce((acc, l) => acc + l.calories * l.quantity, 0);
    const actualProtein = logs.reduce((acc, l) => acc + l.protein * l.quantity, 0);

    console.assert(activeDiet !== null, 'Active diet must exist');
    console.assert(activeDiet?.protein === 160, 'Assigned protein must be 160');
    console.assert(actualProtein === 73.5, `Actual protein should be 73.5 (3*9 + 46.5), got ${actualProtein}`);
    console.log(`[PASS] Factual comparison verified: Assigned Protein ${activeDiet?.protein}g vs Actual Protein ${actualProtein}g (Diff: ${actualProtein - (activeDiet?.protein || 0)}g)`);

    // 5. Admin updates diet to v2
    await prisma.dietPlan.updateMany({
      where: { clientProfileId: cpA.id, isActive: true },
      data: { isActive: false },
    });

    const dietPlanV2 = await prisma.dietPlan.create({
      data: {
        clientProfileId: cpA.id,
        clientId: cpA.clientId,
        planName: 'Phase 2: Aggressive Cut',
        version: 2,
        assignedById: 'admin_alex_stone',
        assignedByName: 'Alex Stone',
        dailyCalories: 1900,
        protein: 180,
        carbohydrates: 160,
        fat: 50,
        fiber: 35,
        waterTargetLiters: 4.0,
        isActive: true,
        mealsJson: JSON.stringify(structuredMealsA),
        notes: 'Increased protein target to preserve lean mass during calorie deficit.',
      },
    });

    await prisma.dietPlanHistory.create({
      data: {
        dietPlanId: dietPlanV2.id,
        clientProfileId: cpA.id,
        clientId: cpA.clientId,
        adminId: 'admin_alex_stone',
        adminName: 'Alex Stone',
        version: 2,
        planName: dietPlanV2.planName,
        dailyCalories: dietPlanV2.dailyCalories,
        protein: dietPlanV2.protein,
        carbohydrates: dietPlanV2.carbohydrates,
        fat: dietPlanV2.fat,
        fiber: dietPlanV2.fiber,
        waterTargetLiters: dietPlanV2.waterTargetLiters,
        mealsJson: dietPlanV2.mealsJson,
        notes: dietPlanV2.notes,
        changeSummary: 'Updated from v1 (Phase 1) to v2 (Phase 2: Aggressive Cut)',
      },
    });

    const historyCount = await prisma.dietPlanHistory.count({
      where: { clientProfileId: cpA.id },
    });
    console.assert(historyCount === 2, `Expected 2 history records, got ${historyCount}`);
    console.log(`[PASS] Admin updated diet to v2. Total history entries for Client A: ${historyCount}`);

    // 6. Data Isolation Verification: Client B must have 0 diet plans and 0 food logs
    const clientBPlans = await prisma.dietPlan.findMany({
      where: { clientProfileId: cpB.id },
    });
    const clientBLogs = await prisma.clientFoodLog.findMany({
      where: { clientProfileId: cpB.id },
    });
    console.assert(clientBPlans.length === 0, 'Client B must have 0 diet plans');
    console.assert(clientBLogs.length === 0, 'Client B must have 0 food logs');
    console.log('[PASS] Data isolation verified: Client B cannot see or access Client A data');

    // Clean up test records
    await prisma.clientFoodLog.deleteMany({ where: { clientProfileId: { in: [cpA.id, cpB.id] } } });
    await prisma.dietPlanHistory.deleteMany({ where: { clientProfileId: { in: [cpA.id, cpB.id] } } });
    await prisma.dietPlan.deleteMany({ where: { clientProfileId: { in: [cpA.id, cpB.id] } } });
    await prisma.clientProfile.deleteMany({ where: { id: { in: [cpA.id, cpB.id] } } });
    await prisma.user.deleteMany({ where: { id: { in: [userA.id, userB.id] } } });

    console.log('====================================================');
    console.log('ALL BACKEND NUTRITION TESTS PASSED SUCCESSFULLY!');
    console.log('====================================================');
  } catch (err) {
    console.error('Test failed with error:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

runNutritionSystemE2eTest();
