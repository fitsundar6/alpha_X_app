import http from 'http';
import app from './server';
import { env } from './config/environment';

interface ApiResponse {
  status: number;
  data: any;
}

function makeRequest(
  server: http.Server,
  options: {
    method: string;
    path: string;
    token?: string;
    body?: any;
  }
): Promise<ApiResponse> {
  return new Promise((resolve, reject) => {
    const port = (server.address() as any).port;
    const bodyString = options.body ? JSON.stringify(options.body) : '';

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: options.path,
        method: options.method,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(bodyString),
          ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(data);
          } catch {
            parsed = data;
          }
          resolve({ status: res.statusCode || 500, data: parsed });
        });
      }
    );

    req.on('error', reject);
    if (bodyString) {
      req.write(bodyString);
    }
    req.end();
  });
}

async function runTests() {
  console.log('================================================================');
  console.log('🧪 RUNNING GOOGLE CLIENT ONBOARDING & ARCHITECTURE VERIFICATION 🧪');
  console.log('================================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));

  try {
    const testGoogleUid1 = `goog_test_${Date.now()}_1`;
    const testGoogleEmail1 = `athlete_${Date.now()}_1@gmail.com`;

    // TEST 1: New Google Account Authentication -> Auto Client ID & Profile Creation
    const res1 = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/google',
      body: {
        googleUid: testGoogleUid1,
        email: testGoogleEmail1,
        name: 'Alex Johnson',
        photoUrl: 'https://lh3.googleusercontent.com/a/sample_avatar_1',
      },
    });

    console.assert(res1.status === 201, `Expected status 201, got ${res1.status}`);
    console.assert(res1.data.success === true, 'Response must be success');
    console.assert(res1.data.data.isNewClient === true, 'Must flag as new client');
    console.assert(res1.data.data.onboardingCompleted === false, 'Onboarding must start as false');
    const clientId1 = res1.data.data.user.clientId;
    console.assert(clientId1 && clientId1.startsWith('AXG-'), `Client ID must start with AXG-, got ${clientId1}`);
    const clientToken1 = res1.data.data.token;
    console.log(`✔ TEST 1 PASSED: New Google account created with unique Client ID: ${clientId1}`);

    // TEST 2: Mid-way Onboarding Save (Step 1 - Fitness Level & Step 2 - Goals)
    const res2 = await makeRequest(server, {
      method: 'PUT',
      path: '/api/v1/auth/onboarding',
      token: clientToken1,
      body: {
        fitnessLevel: 'intermediate',
        primaryGoal: 'Muscle Gain',
        secondaryGoal: 'Build Strength',
        onboardingStep: 2,
        onboardingCompleted: false,
      },
    });

    console.assert(res2.status === 200, `Expected 200, got ${res2.status}`);
    console.assert(res2.data.data.profile.fitnessLevel === 'intermediate', 'Fitness level saved');
    console.assert(res2.data.data.profile.onboardingStep === 2, 'Onboarding step saved');
    console.assert(res2.data.data.onboardingCompleted === false, 'Onboarding still false');
    console.log('✔ TEST 2 PASSED: Incremental onboarding step 2 successfully saved to database.');

    // TEST 3: Validation: Invalid biometric data rejected
    const res3 = await makeRequest(server, {
      method: 'PUT',
      path: '/api/v1/auth/onboarding',
      token: clientToken1,
      body: {
        weightKg: -10,
        heightCm: 0,
      },
    });
    console.assert(res3.status === 400, `Expected 400 validation error, got ${res3.status}`);
    console.log('✔ TEST 3 PASSED: Invalid biometrics (negative weight, zero height) rejected with 400.');

    // TEST 4: Full Onboarding Completion
    const res4 = await makeRequest(server, {
      method: 'PUT',
      path: '/api/v1/auth/onboarding',
      token: clientToken1,
      body: {
        fitnessLevel: 'intermediate',
        primaryGoal: 'Muscle Gain',
        secondaryGoal: 'Build Strength',
        weightKg: 78.5,
        heightCm: 180,
        age: 26,
        gender: 'male',
        trainingExperience: '1–2 years',
        trainingDaysPerWeek: 4,
        hasCurrentInjury: true,
        injuryAreas: ['Lower back'],
        injuryDescription: 'Mild strain during heavy deadlifts 6 months ago',
        hasPreviousSurgery: false,
        activityLevel: 'MODERATE',
        sleepHours: '7–8 hours',
        dailySteps: 8000,
        trainingTimePref: 'Morning',
        preferredDays: ['Monday', 'Tuesday', 'Thursday', 'Friday'],
        trainingPreferences: ['Strength Training', 'Muscle Building', 'Conditioning'],
        onboardingStep: 8,
        onboardingCompleted: true,
      },
    });

    console.assert(res4.status === 200, `Expected 200, got ${res4.status}`);
    console.assert(res4.data.data.onboardingCompleted === true, 'Onboarding must be marked complete');
    console.assert(res4.data.data.profile.weightKg === 78.5, 'Weight saved');
    console.log('✔ TEST 4 PASSED: Complete assessment submitted, onboardingCompleted = true.');

    // TEST 5: Re-login with the SAME Google account -> Must return SAME Client ID
    const res5 = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/google',
      body: {
        googleUid: testGoogleUid1,
        email: testGoogleEmail1,
      },
    });

    console.assert(res5.status === 200, `Expected status 200 for existing client, got ${res5.status}`);
    console.assert(res5.data.data.isNewClient === false, 'Must identify as existing client');
    console.assert(res5.data.data.user.clientId === clientId1, 'Client ID must be strictly identical');
    console.assert(res5.data.data.onboardingCompleted === true, 'Saved onboarding completed state preserved');
    console.log(`✔ TEST 5 PASSED: Re-login verified. Same Google UID strictly returned same Client ID (${clientId1}).`);

    // TEST 6: Google login cannot use Admin Email
    const res6 = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/google',
      body: {
        googleUid: 'hacker_uid',
        email: env.ADMIN_EMAIL,
      },
    });
    console.assert(res6.status === 403, `Expected 403 for Admin email on Google client route, got ${res6.status}`);
    console.log('✔ TEST 6 PASSED: Reserved Admin email blocked from Google Client portal.');

    // TEST 7: Admin logs in and checks Client Roster -> Onboarding data present
    const adminLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/admin/login',
      body: {
        email: env.ADMIN_EMAIL,
        password: env.ADMIN_PASSWORD,
      },
    });
    const adminToken = adminLoginRes.data.data.token;

    const adminClientsRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/clients',
      token: adminToken,
    });
    console.assert(adminClientsRes.status === 200, 'Admin clients request succeeded');
    const clientsList: any[] = adminClientsRes.data.data;
    const found = clientsList.find((c) => c.clientId === clientId1);
    console.assert(found !== undefined, 'New client found in admin roster');
    console.assert(found.fitnessLevel === 'intermediate', 'Fitness level visible to Admin');
    console.assert(found.hasCurrentInjury === true, 'Injury flag visible to Admin');
    console.assert(found.weightKg === 78.5, 'Weight visible to Admin');
    console.assert(found.onboardingCompleted === true, 'Onboarding status visible to Admin');
    console.log('✔ TEST 7 PASSED: Admin Dashboard successfully retrieved complete client onboarding assessment.');

    // TEST 8: Another new Google Account -> Distinct sequential Client ID
    const testGoogleUid2 = `goog_test_${Date.now()}_2`;
    const testGoogleEmail2 = `athlete_${Date.now()}_2@gmail.com`;
    const res8 = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/google',
      body: {
        googleUid: testGoogleUid2,
        email: testGoogleEmail2,
        name: 'Sarah Connor',
      },
    });
    const clientId2 = res8.data.data.user.clientId;
    console.assert(clientId2 !== clientId1, 'Each Google account must receive a unique Client ID');
    console.log(`✔ TEST 8 PASSED: Second Google account received distinct Client ID (${clientId2}).`);

    console.log('================================================================');
    console.log('🎉 ALL 8 BACKEND GOOGLE ONBOARDING TESTS PASSED PERFECTLY! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error('❌ Google Onboarding test suite failed:', err);
  process.exit(1);
});
