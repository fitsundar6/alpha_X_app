import app from './server';
import http from 'http';

async function runTests() {
  console.log('--- STARTING BACKEND WORKOUT SYSTEM VERIFICATION ---');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5099, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5099/api/v1';

  const adminHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_admin',
  };

  const clientHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_client',
  };

  let createdSessionId = '';

  try {
    // 1. Health check
    const healthRes = await fetch(`${baseUrl}/health`);
    console.assert(healthRes.status === 200, 'Health check failed');
    console.log('✔ 1. Health check passed');

    // 2. Auth /me test
    const adminMeRes = await fetch(`${baseUrl}/auth/me`, { headers: adminHeaders });
    const adminMe = await adminMeRes.json();
    console.assert(adminMe.data.role === 'ADMIN', 'Admin role verification failed');

    const clientMeRes = await fetch(`${baseUrl}/auth/me`, { headers: clientHeaders });
    const clientMe = await clientMeRes.json();
    console.assert(clientMe.data.role === 'CLIENT', 'Client role verification failed');
    console.log('✔ 2. Role-based Auth check passed (Admin & Client)');

    // 3. Security: Client CANNOT access admin sessions endpoint
    const forbiddenRes = await fetch(`${baseUrl}/workout/admin/sessions`, { headers: clientHeaders });
    console.assert(forbiddenRes.status === 403, `Expected 403 Forbidden for client on admin route, got ${forbiddenRes.status}`);
    console.log('✔ 3. Security Check: Client denied access to Admin workout routes (403 Forbidden)');

    // 4. Admin lists sessions
    const adminSessionsRes = await fetch(`${baseUrl}/workout/admin/sessions`, { headers: adminHeaders });
    const adminSessionsJson = await adminSessionsRes.json();
    console.assert(adminSessionsRes.status === 200, 'Failed to fetch admin sessions');
    console.assert(adminSessionsJson.data.length >= 3, 'Expected seeded sessions');
    console.log(`✔ 4. Admin listed ${adminSessionsJson.data.length} workout sessions`);

    // 5. Admin creates new workout session with supersets
    const newSessionPayload = {
      title: 'Upper Hypertrophy B',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest • Back • Arms',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      description: 'Upper body hypertrophy with antagonist supersets.',
      isActive: true,
      availabilityType: 'ALL',
      exercises: [
        {
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Machine Press',
          category: 'Chest',
          orderIndex: 0,
          supersetTag: 'A1',
          numberOfSets: 3,
          targetReps: '10',
          targetWeight: 75.0,
          restSeconds: 30,
          targetRir: 2,
          targetRpe: 8.0,
          setType: 'Working',
          adminInstruction: 'Superset with Cable Row',
        },
        {
          exerciseId: 'ex_seated_cable_row',
          exerciseName: 'Seated Cable Row',
          category: 'Back',
          orderIndex: 1,
          supersetTag: 'A2',
          numberOfSets: 3,
          targetReps: '10',
          targetWeight: 65.0,
          restSeconds: 90,
          targetRir: 2,
          targetRpe: 8.5,
          setType: 'Working',
          adminInstruction: 'Rest after superset A2',
        },
      ],
    };

    const createRes = await fetch(`${baseUrl}/workout/admin/sessions`, {
      method: 'POST',
      headers: adminHeaders,
      body: JSON.stringify(newSessionPayload),
    });
    const createJson = await createRes.json();
    console.assert(createRes.status === 201, `Failed to create session: ${JSON.stringify(createJson)}`);
    createdSessionId = createJson.data.id;
    console.assert(createJson.data.exercises[0].supersetTag === 'A1', 'Superset tag A1 mismatch');
    console.assert(createJson.data.exercises[1].supersetTag === 'A2', 'Superset tag A2 mismatch');
    console.log('✔ 5. Admin created session with Superset A (A1 + A2)');

    // 6. Admin assigns session to Individual Client with isRecommended
    const assignRes = await fetch(`${baseUrl}/workout/admin/sessions/${createdSessionId}/assign`, {
      method: 'POST',
      headers: adminHeaders,
      body: JSON.stringify({
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_john_doe',
        isRecommended: true,
      }),
    });
    const assignJson = await assignRes.json();
    console.assert(assignRes.status === 200, 'Failed to assign session');
    console.log('✔ 6. Admin assigned session to client_john_doe as Recommended');

    // 7. Client queries authorized sessions
    const clientSessionsRes = await fetch(`${baseUrl}/workout/client/sessions`, { headers: clientHeaders });
    const clientSessionsJson = await clientSessionsRes.json();
    console.assert(clientSessionsRes.status === 200, 'Failed to fetch client sessions');
    console.assert(clientSessionsJson.data.recommended !== null, 'Client should have recommended session');
    console.assert(
      clientSessionsJson.data.recommended.id === createdSessionId,
      'Recommended session should match newly assigned session'
    );
    console.log(`✔ 7. Client fetched authorized sessions. Recommended: "${clientSessionsJson.data.recommended.title}"`);

    // 8. Client checks previous performance for Incline Smith Press
    const prevPerfRes = await fetch(`${baseUrl}/workout/client/previous-performance?exerciseId=ex_incline_smith`, {
      headers: clientHeaders,
    });
    const prevPerfJson = await prevPerfRes.json();
    console.assert(prevPerfRes.status === 200, 'Failed to fetch previous performance');
    console.assert(prevPerfJson.data.lastWeight === 80.0, 'Expected previous performance weight 80.0');
    console.log('✔ 8. Client retrieved previous performance: 80 kg × 8');

    // 9. Client records workout execution
    const recordPayload = {
      sessionId: createdSessionId,
      sessionTitle: 'Upper Hypertrophy B',
      workoutType: 'Hypertrophy',
      startedAt: new Date(Date.now() - 50 * 60000).toISOString(),
      completedAt: new Date().toISOString(),
      durationSeconds: 50 * 60,
      totalVolume: 4200.0,
      completedSetsCount: 6,
      skippedSetsCount: 0,
      averageRpe: 8.2,
      averageRir: 1.8,
      isCompleted: true,
      notes: 'Great pump, completed all supersets on time.',
      exerciseRecords: [
        {
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Machine Press',
          orderIndex: 0,
          supersetTag: 'A1',
          isSkipped: false,
          clientNote: 'Felt strong today.',
          adminNote: 'Superset with Cable Row',
          sets: [
            {
              setNumber: 1,
              setType: 'Working',
              targetReps: '10',
              targetWeight: 75.0,
              actualWeight: 75.0,
              actualReps: 10,
              actualRir: 2,
              actualRpe: 8.0,
              isCompleted: true,
            },
            {
              setNumber: 2,
              setType: 'Working',
              targetReps: '10',
              targetWeight: 75.0,
              actualWeight: 75.0,
              actualReps: 10,
              actualRir: 2,
              actualRpe: 8.0,
              isCompleted: true,
            },
            {
              setNumber: 3,
              setType: 'Working',
              targetReps: '10',
              targetWeight: 75.0,
              actualWeight: 75.0,
              actualReps: 10,
              actualRir: 2,
              actualRpe: 8.5,
              isCompleted: true,
            },
          ],
        },
      ],
    };

    const recordRes = await fetch(`${baseUrl}/workout/client/records`, {
      method: 'POST',
      headers: clientHeaders,
      body: JSON.stringify(recordPayload),
    });
    const recordJson = await recordRes.json();
    console.assert(recordRes.status === 201, 'Failed to save client workout record');
    console.log('✔ 9. Client completed and saved workout record successfully');

    // 10. Admin reviews client workout history
    const clientResultsRes = await fetch(`${baseUrl}/workout/admin/clients/client_john_doe/workout-history`, {
      headers: adminHeaders,
    });
    const clientResultsJson = await clientResultsRes.json();
    console.assert(clientResultsRes.status === 200, 'Failed to fetch client workout results for admin');
    console.assert(clientResultsJson.data.history.length >= 2, 'Expected at least 2 historical records for John');
    console.log(`✔ 10. Admin reviewed client workout history (${clientResultsJson.data.history.length} records found)`);

    console.log('\n=========================================');
    console.log('🎉 ALL BACKEND WORKOUT SYSTEM TESTS PASSED!');
    console.log('=========================================\n');
    server.close();
    process.exit(0);
  } catch (e) {
    console.error('Test assertion failed:', e);
    server.close();
    process.exit(1);
  }
}

runTests();
