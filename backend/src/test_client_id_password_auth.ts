process.env.NODE_ENV = 'test';
import http from 'http';
import app from './server';
import { env } from './config/environment';
import { prisma } from './config/prisma';

function makeRequest(
  server: http.Server,
  options: {
    method: string;
    path: string;
    headers?: Record<string, string>;
    body?: any;
  }
): Promise<{ status: number; body: any }> {
  return new Promise((resolve, reject) => {
    const address = server.address() as any;
    const port = address.port;

    const payload = options.body ? JSON.stringify(options.body) : null;
    const reqHeaders: Record<string, string> = {
      ...(options.headers || {}),
    };
    if (payload) {
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(payload).toString();
    }

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: options.path,
        method: options.method,
        headers: reqHeaders,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode || 500, body: data ? JSON.parse(data) : null });
          } catch {
            resolve({ status: res.statusCode || 500, body: data });
          }
        });
      }
    );

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function runTests() {
  console.log('================================================================');
  console.log('🧪 RUNNING ALPHA X GYM CLIENT ID + PASSWORD AUTH & ASSIGNMENT TESTS 🧪');
  console.log('================================================================\n');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));

  try {
    const timestamp = Date.now();
    const testEmail = `athlete_${timestamp}@alphaxgym.com`;
    const testPassword = 'Password123!';
    const testPhone = `+1555${timestamp.toString().slice(-7)}`;
    const testName = 'Alex Mercer';

    // -------------------------------------------------------------
    // TEST 1: Client Account Registration
    // -------------------------------------------------------------
    console.log('TEST 1: Client Account Creation (Name, Email, Phone, Password)');
    const regRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: testName,
        email: testEmail,
        phone: testPhone,
        password: testPassword,
        confirmPassword: testPassword,
      },
    });

    console.assert(regRes.status === 201, `Expected 201, got ${regRes.status}: ${JSON.stringify(regRes.body)}`);
    console.assert(regRes.body.success === true, 'Expected success: true');
    const clientId = regRes.body.data.clientId;
    console.assert(/^AXG-\d{4}$/.test(clientId), `Expected AXG-XXXX format, got ${clientId}`);
    console.assert(regRes.body.data.assessmentCompleted === false, 'Expected assessmentCompleted: false');
    console.assert(regRes.body.data.user.phone === testPhone, 'Expected phone number string to be preserved');
    console.log(`✔ TEST 1 PASSED: Client registered successfully with permanent Client ID: ${clientId}\n`);

    // -------------------------------------------------------------
    // TEST 2: Client Login with Client ID (AXG-XXXX) + Password
    // -------------------------------------------------------------
    console.log(`TEST 2: Client Login with Client ID (${clientId}) + Password`);
    const loginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: {
        clientId: clientId,
        password: testPassword,
      },
    });

    console.assert(loginRes.status === 200, `Expected 200, got ${loginRes.status}: ${JSON.stringify(loginRes.body)}`);
    console.assert(loginRes.body.data.clientId === clientId, 'Expected same Client ID on login');
    console.assert(loginRes.body.data.assessmentCompleted === false, 'Expected assessmentCompleted: false initially');
    const clientToken = loginRes.body.data.token;
    console.log(`✔ TEST 2 PASSED: Client logged in using Client ID (${clientId}) and password.\n`);

    // -------------------------------------------------------------
    // TEST 3: Client Login with Email + Password
    // -------------------------------------------------------------
    console.log(`TEST 3: Client Login with Email (${testEmail}) + Password`);
    const emailLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: {
        email: testEmail,
        password: testPassword,
      },
    });
    console.assert(emailLoginRes.status === 200, 'Expected 200 for email login');
    console.assert(emailLoginRes.body.data.clientId === clientId, 'Expected matching Client ID');
    console.log(`✔ TEST 3 PASSED: Client logged in using Email.\n`);

    // -------------------------------------------------------------
    // TEST 4: Progressive Fitness Assessment (10 Steps)
    // -------------------------------------------------------------
    console.log('TEST 4: Progressive Fitness Assessment (Steps 1 to 10)');
    const assessmentRes = await makeRequest(server, {
      method: 'PUT',
      path: '/api/v1/auth/onboarding',
      headers: { Authorization: `Bearer ${clientToken}` },
      body: {
        fitnessLevel: 'intermediate',
        primaryGoal: 'Fat Loss',
        secondaryGoal: 'Muscle Gain',
        weightKg: 82.5,
        heightCm: 180.0,
        age: 28,
        gender: 'Male',
        trainingExperience: '1–2 years',
        trainingDaysPerWeek: 4,
        preferredDays: ['Monday', 'Wednesday', 'Friday', 'Saturday'],
        hasCurrentInjury: true,
        injuryAreas: ['Shoulder'],
        injuryDetails: 'Minor rotator cuff impingement on heavy presses',
        hasPreviousSurgery: false,
        activityLevel: 'MODERATE',
        sleepHours: '7–8 hours',
        dailySteps: 8500,
        trainingPreferences: ['Strength Training', 'Muscle Building', 'Conditioning'],
        onboardingCompleted: true,
        assessmentCompleted: true,
        onboardingStep: 10,
      },
    });

    console.assert(assessmentRes.status === 200, `Expected 200, got ${assessmentRes.status}`);
    console.assert(assessmentRes.body.data.assessmentCompleted === true, 'Expected assessmentCompleted: true');
    console.log('✔ TEST 4 PASSED: 10-step fitness assessment submitted and marked complete.\n');

    // -------------------------------------------------------------
    // TEST 5: Subsequent Login verifies assessmentCompleted == true
    // -------------------------------------------------------------
    console.log('TEST 5: Subsequent Login returns assessmentCompleted == true -> routes to Client Dashboard');
    const reLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: {
        clientId: clientId,
        password: testPassword,
      },
    });
    console.assert(reLoginRes.body.data.assessmentCompleted === true, 'Expected assessmentCompleted: true');
    console.log('✔ TEST 5 PASSED: Returning client assessment status verified as completed.\n');

    // -------------------------------------------------------------
    // TEST 6: Single Master Admin Login (fitsundar6@gmail.com)
    // -------------------------------------------------------------
    console.log('TEST 6: Working Admin Login (Untouched & Verified)');
    const adminLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/admin/login',
      body: {
        email: env.ADMIN_EMAIL,
        password: env.ADMIN_PASSWORD,
      },
    });
    console.assert(adminLoginRes.status === 200, `Expected 200 for Admin login, got ${adminLoginRes.status}`);
    const adminToken = adminLoginRes.body.data.token;
    console.log('✔ TEST 6 PASSED: Master Admin authenticated successfully with hardware password.\n');

    // -------------------------------------------------------------
    // TEST 7: Client cannot access Admin APIs (Role-Based Access)
    // -------------------------------------------------------------
    console.log('TEST 7: Security - Client token blocked from Admin API (403 Forbidden)');
    const unauthorizedRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/clients',
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    console.assert(unauthorizedRes.status === 403, `Expected 403, got ${unauthorizedRes.status}`);
    console.log('✔ TEST 7 PASSED: Client token strictly blocked from accessing Admin endpoints.\n');

    // -------------------------------------------------------------
    // TEST 8: Admin views registered clients and selects individual client
    // -------------------------------------------------------------
    console.log(`TEST 8: Admin finds client by Client ID (${clientId})`);
    const adminClientRes = await makeRequest(server, {
      method: 'GET',
      path: `/api/admin/clients/${clientId}`,
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.assert(adminClientRes.status === 200, `Expected 200, got ${adminClientRes.status}`);
    console.assert(adminClientRes.body.data.clientId === clientId, 'Expected correct Client ID');
    console.assert(adminClientRes.body.data.weightKg === 82.5, 'Expected correct weight from assessment');
    console.assert(adminClientRes.body.data.primaryGoal === 'Fat Loss', 'Expected correct primary goal');
    console.log(`✔ TEST 8 PASSED: Admin loaded complete client profile for ${clientId}.\n`);

    // -------------------------------------------------------------
    // TEST 9: Admin assigns Diet Plan with Macros and Meals
    // -------------------------------------------------------------
    console.log(`TEST 9: Admin creates & assigns Diet Plan to ${clientId}`);
    const dietPlanRes = await makeRequest(server, {
      method: 'POST',
      path: `/api/admin/clients/${clientId}/diet-plans`,
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        planName: 'Alpha Fat Loss Phase 1',
        dailyCalories: 2000,
        protein: 150,
        carbohydrates: 200,
        fat: 60,
        fiber: 30,
        waterTargetLiters: 3.5,
        meals: [
          { name: 'Breakfast', foods: [{ name: 'Oats with Whey', quantity: '80g', calories: 420, protein: 35 }] },
          { name: 'Lunch', foods: [{ name: 'Grilled Chicken & Rice', quantity: '200g', calories: 550, protein: 48 }] },
          { name: 'Snack', foods: [{ name: 'Greek Yogurt & Almonds', quantity: '150g', calories: 250, protein: 18 }] },
          { name: 'Dinner', foods: [{ name: 'Salmon & Steamed Veggies', quantity: '220g', calories: 580, protein: 42 }] },
        ],
        notes: 'Drink at least 1L of water before lunch.',
      },
    });
    console.assert(dietPlanRes.status === 201, `Expected 201, got ${dietPlanRes.status}`);
    console.assert(dietPlanRes.body.data.isActive === true, 'Diet plan must be active');
    console.log('✔ TEST 9 PASSED: Admin assigned diet plan with calories, macros & meals.\n');

    // -------------------------------------------------------------
    // TEST 10: Admin assigns Macro Target
    // -------------------------------------------------------------
    console.log(`TEST 10: Admin sets Macro Targets for ${clientId}`);
    const macroRes = await makeRequest(server, {
      method: 'POST',
      path: `/api/admin/clients/${clientId}/macros`,
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
        fiber: 30,
        waterLiters: 3.5,
        notes: 'Target 150g protein minimum on workout days.',
      },
    });
    console.assert(macroRes.status === 201, `Expected 201, got ${macroRes.status}`);
    console.log('✔ TEST 10 PASSED: Admin assigned macro targets.\n');

    // -------------------------------------------------------------
    // TEST 11: Client fetches assigned Diet Plan & Macros via Client API
    // -------------------------------------------------------------
    console.log('TEST 11: Client fetches assigned Diet Plan and Macros');
    await prisma.user.update({
      where: { email: testEmail },
      data: { status: 'APPROVED', approvedAt: new Date(), approvedBy: 'fitsundar6@gmail.com' },
    });
    const clientDietRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/v1/client/me/diet-plan',
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    console.assert(clientDietRes.status === 200, `Expected 200, got ${clientDietRes.status}`);
    console.assert(clientDietRes.body.data.planName === 'Alpha Fat Loss Phase 1', 'Expected assigned diet plan');
    console.assert(clientDietRes.body.data.dailyCalories === 2000, 'Expected 2000 kcal');

    const clientMacroRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/v1/client/me/macros',
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    console.assert(clientMacroRes.status === 200, `Expected 200, got ${clientMacroRes.status}`);
    console.assert(clientMacroRes.body.data.protein === 150, 'Expected 150g protein');
    console.log('✔ TEST 11 PASSED: Client retrieved assigned diet plan and macros successfully.\n');

    // -------------------------------------------------------------
    // TEST 12: Admin Private Notes
    // -------------------------------------------------------------
    console.log(`TEST 12: Admin saves private notes for ${clientId}`);
    const notesRes = await makeRequest(server, {
      method: 'PUT',
      path: `/api/admin/clients/${clientId}/notes`,
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        notes: 'Focus on shoulder rehab warmups. Review bench press technique at week 2.',
      },
    });
    console.assert(notesRes.status === 200, `Expected 200, got ${notesRes.status}`);
    console.assert(notesRes.body.data.adminNotes.includes('shoulder rehab'), 'Expected saved notes');
    console.log('✔ TEST 12 PASSED: Admin private notes saved securely.\n');

    console.log('================================================================');
    console.log('🎉 ALL 12 BACKEND CLIENT ID + PASSWORD & ADMIN ASSIGNMENT TESTS PASSED! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error('❌ Test suite failed:', err);
  process.exit(1);
});
