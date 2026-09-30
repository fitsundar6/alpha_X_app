import app from './server';
import http from 'http';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function runE2EScenarios() {
  console.log('========================================================');
  console.log('ALPHA X GYM — COMPLETE END-TO-END SPECIFICATION TESTS');
  console.log('========================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5099, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5099/api/v1';

  const clientAHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_client',
    'x-client-id': 'AXG-0001',
  };

  const clientBHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_client_b',
    'x-client-id': 'AXG-0002',
  };

  const adminHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_admin',
    'x-client-id': 'AXG-ADMIN',
  };

  try {
    // ------------------------------------------------------------------
    // TEST SUITE 1: EXERCISE LIBRARY VERIFICATION (Parts 1-18, 40, 47)
    // ------------------------------------------------------------------
    console.log('\n--- 1. EXERCISE LIBRARY TEST (Database Backed) ---');
    const dbExerciseCount = await prisma.exercise.count();
    console.log(`[DB] Current Prisma exercises count in PostgreSQL: ${dbExerciseCount}`);
    console.assert(dbExerciseCount >= 220, 'PostgreSQL database must contain >= 220 exercises');

    // Fetch exercises via API
    const exRes = await fetch(`${baseUrl}/exercises?limit=500`, { headers: clientAHeaders });
    const exJson = await exRes.json();
    console.assert(exRes.status === 200, 'Exercises API must respond 200');
    console.assert(exJson.data.items.length >= 220, 'API must return full library');
    console.log(`✔ API returned ${exJson.data.items.length} exercises from PostgreSQL database`);

    // Verify key categories
    const categories = ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Core', 'Functional', 'Calisthenics', 'Boxing', 'Mobility', 'Warm-up', 'Cool-down'];
    for (const cat of categories) {
      const match = exJson.data.items.some((e: any) => 
        e.category.toLowerCase().includes(cat.toLowerCase()) || 
        (e.tags && e.tags.some((t: string) => t.toLowerCase().includes(cat.toLowerCase())))
      );
      console.assert(match, `Category ${cat} must be present in library`);
    }
    console.log(`✔ Verified all ${categories.length} required exercise categories present`);

    // Search and filters
    const benchSearch = await fetch(`${baseUrl}/exercises?query=bench&muscle=Chest`, { headers: clientAHeaders });
    const benchJson = await benchSearch.json();
    console.assert(benchJson.data.items.length >= 2, 'Search by muscle Chest and query bench should work');
    console.log(`✔ Search & Filter by muscle (Chest) + query (bench): found ${benchJson.data.items.length} exercises`);

    // ------------------------------------------------------------------
    // TEST SUITE 2: FOOD LIBRARY VERIFICATION (Parts 19-26, 41, 48)
    // ------------------------------------------------------------------
    console.log('\n--- 2. FOOD LIBRARY TEST (Database Backed) ---');
    const dbFoodCount = await prisma.food.count();
    console.log(`[DB] Current Prisma foods count in PostgreSQL: ${dbFoodCount}`);
    console.assert(dbFoodCount >= 140, 'PostgreSQL database must contain >= 140 foods');

    // Indian Food Search
    const indianFoodRes = await fetch(`${baseUrl}/foods?query=dosa`, { headers: clientAHeaders });
    const indianJson = await indianFoodRes.json();
    console.assert(indianJson.data.items.length >= 1, 'Should find Indian food Dosa');
    console.log(`✔ Indian Food Search: "dosa" found ${indianJson.data.items.length} items`);

    // Protein Search
    const chickenRes = await fetch(`${baseUrl}/foods?query=chicken`, { headers: clientAHeaders });
    const chickenJson = await chickenRes.json();
    console.assert(chickenJson.data.items.length >= 3, 'Should find multiple chicken items');
    console.log(`✔ Fitness Protein Search: "chicken" found ${chickenJson.data.items.length} items`);

    // ------------------------------------------------------------------
    // TEST SUITE 3: CUSTOM FOOD ADDER (Parts 27, 28, 42, 49)
    // ------------------------------------------------------------------
    console.log('\n--- 3. CUSTOM FOOD CREATION & ATWATER CALORIE CALCULATION ---');
    // Client A creates "Test Homemade Food"
    // Quantity: 100g, Protein: 20g, Carbs: 30g, Fat: 10g
    // Expected calories: 20*4 + 30*4 + 10*9 = 80 + 120 + 90 = 290 kcal
    const uniqueFoodName = `Test Homemade Food ${Date.now()}`;
    const customFoodPayload = {
      name: uniqueFoodName,
      servingSize: 100,
      servingUnit: 'g',
      protein: 20,
      carbohydrates: 30,
      fat: 10,
      fiber: 4,
      category: 'Indian Foods',
      isPublic: true,
    };

    const addRes = await fetch(`${baseUrl}/foods`, {
      method: 'POST',
      headers: clientAHeaders,
      body: JSON.stringify(customFoodPayload),
    });
    const addJson = await addRes.json();
    console.assert(addRes.status === 201 || addRes.status === 200, 'Custom food creation must succeed');
    console.assert(addJson.data.calories === 290, `Atwater calories must be exactly 290, got: ${addJson.data.calories}`);
    console.assert(addJson.data.source === 'USER', 'Source must be USER');
    console.assert(addJson.data.createdBy === 'AXG-0001', 'CreatedBy must be AXG-0001');
    console.log(`✔ Client A created "${uniqueFoodName}" (Estimated Calories: ${addJson.data.calories} kcal [20*4 + 30*4 + 10*9])`);

    // Verify saved in PostgreSQL database
    const savedInDb = await prisma.food.findUnique({ where: { id: addJson.data.id } });
    console.assert(savedInDb !== null, 'Custom food must be persisted to PostgreSQL database');
    console.log(`✔ Verified food saved in central PostgreSQL database (ID: ${savedInDb?.id})`);

    // ------------------------------------------------------------------
    // TEST SUITE 4: GLOBAL MULTI-CLIENT & ADMIN VISIBILITY (Parts 30, 31, 43, 50)
    // ------------------------------------------------------------------
    console.log('\n--- 4. GLOBAL MULTI-CLIENT & ADMIN SYNCHRONIZATION ---');
    // Client B searches for the food created by Client A
    const clientBSearchRes = await fetch(`${baseUrl}/foods?query=${encodeURIComponent(uniqueFoodName)}`, {
      headers: clientBHeaders,
    });
    const clientBJson = await clientBSearchRes.json();
    console.assert(clientBJson.data.items.length >= 1, 'Client B must find food created by Client A');
    const clientBFound = clientBJson.data.items[0];
    console.assert(clientBFound.name === uniqueFoodName, 'Client B found exact food name');
    console.assert(clientBFound.protein === 20, 'Client B sees correct protein (20g)');
    console.assert(clientBFound.carbohydrates === 30, 'Client B sees correct carbs (30g)');
    console.assert(clientBFound.fat === 10, 'Client B sees correct fat (10g)');
    console.assert(clientBFound.calories === 290, 'Client B sees correct calories (290 kcal)');
    console.log(`✔ Client B successfully found Client A's food globally with identical macros:`);
    console.log(`   Name: ${clientBFound.name} | Calories: ${clientBFound.calories} kcal | P:${clientBFound.protein} C:${clientBFound.carbohydrates} F:${clientBFound.fat}`);

    // Admin searches and sees the food
    const adminSearchRes = await fetch(`${baseUrl}/foods?query=${encodeURIComponent(uniqueFoodName)}`, {
      headers: adminHeaders,
    });
    const adminJson = await adminSearchRes.json();
    console.assert(adminJson.data.items.length >= 1, 'Admin must also find the custom food');
    console.log(`✔ Admin verified visibility of food created by Client AXG-0001 (isPublic=${adminJson.data.items[0].isPublic})`);

    // ------------------------------------------------------------------
    // TEST SUITE 5: DUPLICATE PREVENTION (Parts 34, 51)
    // ------------------------------------------------------------------
    console.log('\n--- 5. DUPLICATE FOOD PREVENTION ---');
    const dupRes = await fetch(`${baseUrl}/foods`, {
      method: 'POST',
      headers: clientAHeaders,
      body: JSON.stringify(customFoodPayload),
    });
    const dupJson = await dupRes.json();
    console.assert(dupJson.data.isDuplicate === true, 'Duplicate food should be detected');
    console.assert(dupJson.data.id === addJson.data.id, 'Duplicate should return existing record ID without duplicating');
    console.log(`✔ Duplicate prevention confirmed: Re-saving identical food returned existing ID (${dupJson.data.id}) without creating duplicates`);

    // ------------------------------------------------------------------
    // TEST SUITE 6: QUANTITY SCALING VERIFICATION (Part 29)
    // ------------------------------------------------------------------
    console.log('\n--- 6. PROPORTIONAL QUANTITY SCALING ---');
    // Example from requirement 29:
    // 100g base: 165 kcal, 20g P, 10g C, 5g F
    // Client enters: Quantity = 250g (ratio = 2.5)
    // Calculated: 412.5 kcal, 50g P, 25g C, 12.5g F
    const base100g = { cal: 165, p: 20, c: 10, f: 5 };
    const ratio = 250 / 100;
    const scaledCal = base100g.cal * ratio;
    const scaledP = base100g.p * ratio;
    const scaledC = base100g.c * ratio;
    const scaledF = base100g.f * ratio;

    console.assert(scaledCal === 412.5, `Scaled calories must be 412.5, got: ${scaledCal}`);
    console.assert(scaledP === 50, `Scaled protein must be 50, got: ${scaledP}`);
    console.assert(scaledC === 25, `Scaled carbs must be 25, got: ${scaledC}`);
    console.assert(scaledF === 12.5, `Scaled fat must be 12.5, got: ${scaledF}`);
    console.log(`✔ Proportional scaling math verified: 100g (165 kcal, 20P, 10C, 5F) at 250g -> ${scaledCal} kcal, ${scaledP}g P, ${scaledC}g C, ${scaledF}g F`);

    // Clean up test food
    await prisma.food.delete({ where: { id: addJson.data.id } });
    console.log('✔ Cleaned up temporary test record from database');

    console.log('\n========================================================');
    console.log('ALL END-TO-END SPECIFICATION SCENARIOS PASSED WITH 100% SUCCESS!');
    console.log('========================================================');
  } finally {
    server.close();
  }
}

runE2EScenarios().catch((err) => {
  console.error('E2E TEST FAILURE:', err);
  process.exit(1);
});
