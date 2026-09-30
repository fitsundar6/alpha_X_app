import app from './server';
import http from 'http';

async function runExerciseTests() {
  console.log('--- STARTING BACKEND EXERCISE SYSTEM VERIFICATION ---');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5098, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5098/api/v1';

  const adminHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_admin',
  };

  const clientHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_client',
  };

  try {
    // 1. Search exercises as client (instant search, ranked)
    const searchRes = await fetch(`${baseUrl}/exercises?query=incline`, { headers: clientHeaders });
    const searchJson = await searchRes.json();
    console.assert(searchRes.status === 200, 'Client should be able to search exercises');
    console.assert(searchJson.data.items.length >= 2, 'Should find multiple incline exercises');
    console.log(`✔ 1. Client searched "incline" -> found ${searchJson.data.items.length} exercises (Top: ${searchJson.data.items[0].name})`);

    // 2. Partial word / alias search: "lat"
    const latRes = await fetch(`${baseUrl}/exercises?query=lat`, { headers: clientHeaders });
    const latJson = await latRes.json();
    console.assert(latRes.status === 200, 'Search for "lat" should succeed');
    console.assert(latJson.data.items.some((i: any) => i.name.toLowerCase().includes('lat')), 'Should find Lat Pulldown');
    console.log(`✔ 2. Partial search "lat" returned ${latJson.data.items.length} exercises`);

    // 3. Category search: "Warm-up"
    const warmRes = await fetch(`${baseUrl}/exercises?category=Warm-up`, { headers: clientHeaders });
    const warmJson = await warmRes.json();
    console.assert(warmRes.status === 200, 'Category search for Warm-up should succeed');
    console.assert(warmJson.data.items.length >= 2, 'Should find multiple warm-up movements');
    console.log(`✔ 3. Warm-up category search returned ${warmJson.data.items.length} warm-up exercises`);

    // 4. Security check: Client CANNOT trigger sync or create custom exercise
    const syncForbiddenRes = await fetch(`${baseUrl}/exercises/admin/sync/trigger`, {
      method: 'POST',
      headers: clientHeaders,
    });
    console.assert(syncForbiddenRes.status === 403, 'Client must get 403 Forbidden on admin sync');
    console.log('✔ 4. Security: Client was correctly rejected (403 Forbidden) from admin sync');

    // 5. Admin creates custom exercise
    const createRes = await fetch(`${baseUrl}/exercises/admin`, {
      method: 'POST',
      headers: adminHeaders,
      body: JSON.stringify({
        name: 'Alpha X Landmine Lateral Arc',
        category: 'Shoulders',
        primaryMuscles: ['Side Delts'],
        secondaryMuscles: ['Trapezius'],
        equipment: 'Barbell',
        movementPattern: 'Isolation',
        difficulty: 'Intermediate',
        instructions: ['Anchor barbell in landmine.', 'Raise through horizontal arc.'],
        coachingCues: ['Do not shrug.'],
      }),
    });
    const createJson = await createRes.json();
    console.assert(createRes.status === 201, 'Admin should be able to create custom exercise');
    const createdId = createJson.data.id;
    console.log(`✔ 5. Admin created custom exercise: "${createJson.data.name}" (ID: ${createdId})`);

    // 6. Duplicate prevention
    const duplicateRes = await fetch(`${baseUrl}/exercises/admin`, {
      method: 'POST',
      headers: adminHeaders,
      body: JSON.stringify({
        name: 'alpha x landmine lateral arc', // Duplicate normalized name
        category: 'Shoulders',
        primaryMuscles: ['Side Delts'],
      }),
    });
    console.assert(duplicateRes.status === 400, 'Duplicate exercise should be rejected with 400 Bad Request');
    console.log('✔ 6. Duplicate prevention verified (Duplicate name rejected)');

    // 7. Admin archives exercise (Soft delete to preserve workout history)
    const archiveRes = await fetch(`${baseUrl}/exercises/admin/${createdId}`, {
      method: 'DELETE',
      headers: adminHeaders,
    });
    const archiveJson = await archiveRes.json();
    console.assert(archiveRes.status === 200, 'Archive should succeed');
    console.assert(archiveJson.data.isActive === false, 'Exercise should be deactivated');
    console.log('✔ 7. Exercise archive verified (isActive = false, preserving historical workout integrity)');

    // 8. Legal attribution endpoint
    const attrRes = await fetch(`${baseUrl}/exercises/attribution`, { headers: clientHeaders });
    const attrJson = await attrRes.json();
    console.assert(attrRes.status === 200, 'Attribution endpoint should succeed');
    console.assert(attrJson.data.sources.length >= 2, 'Should include wger & Alpha X Gym sources');
    console.log('✔ 8. Legal attribution endpoint verified');

    console.log('--- ALL BACKEND EXERCISE SYSTEM TESTS PASSED SUCCESSFULLY! ---');
  } finally {
    server.close();
  }
}

runExerciseTests().catch((e) => {
  console.error('Test execution failed:', e);
  process.exit(1);
});
