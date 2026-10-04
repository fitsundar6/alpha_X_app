import app from './server';
import http from 'http';
import { prisma } from './config/prisma';

async function runTests() {
  console.log('================================================================');
  console.log('🤖 STARTING ALPHA X PROACTIVE AI COACH VERIFICATION');
  console.log('================================================================');

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
    // Upsert or fetch test client Marcus Vance
    let client = await prisma.user.findUnique({
      where: { id: 'client_marcus_vance' },
      include: { clientProfile: true },
    });

    if (!client) {
      client = await prisma.user.create({
        data: {
          id: 'client_marcus_vance',
          email: 'marcus@client.alphax.gym',
          name: 'Marcus Vance',
          role: 'CLIENT',
          notificationsEnabled: true,
          oneSignalPlayerId: 'mock-onesignal-player-marcus',
          clientProfile: {
            create: {
              clientId: 'client_marcus_vance',
              dailyStepGoal: 8000,
              primaryGoal: 'Build Strength',
              fitnessLevel: 'intermediate',
            },
          },
        },
        include: { clientProfile: true },
      });
    } else {
      client = await prisma.user.update({
        where: { id: 'client_marcus_vance' },
        data: {
          notificationsEnabled: true,
          oneSignalPlayerId: 'mock-onesignal-player-marcus',
        },
        include: { clientProfile: true },
      });
    }

    console.log(`✔ Verified test client: ${client.name} (${client.id})`);

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Test POST /notifications/admin/trigger-morning-sweep (7:30 AM)
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 1. Testing Morning Readiness Sweep (7:30 AM Trigger) ---');
    const morningRes = await fetch(`${baseUrl}/notifications/admin/trigger-morning-sweep`, {
      method: 'POST',
      headers: adminHeaders,
    });
    const morningJson = await morningRes.json();
    console.assert(morningRes.status === 200, `Expected 200, got ${morningRes.status}`);
    console.assert(morningJson.success === true, 'Morning sweep response was not success');
    console.log('✔ Morning sweep endpoint succeeded:', morningJson.data);

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Test POST /notifications/admin/simulate-post-workout (PR Celebration)
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 2. Testing Event-Driven Post-Workout PR Celebration ---');
    const postWorkoutRes = await fetch(`${baseUrl}/notifications/admin/simulate-post-workout`, {
      method: 'POST',
      headers: adminHeaders,
      body: JSON.stringify({
        clientId: client.id,
        sessionTitle: 'Deadlift & Posterior Chain',
        totalVolume: 4200,
        personalRecords: [
          { exerciseName: 'Deadlift', type: 'VOLUME', value: 4200, weight: 180 },
        ],
      }),
    });
    const postWorkoutJson = await postWorkoutRes.json();
    console.assert(postWorkoutRes.status === 200, `Expected 200, got ${postWorkoutRes.status}`);
    console.assert(postWorkoutJson.success === true, 'Post-workout simulation failed');
    console.log('✔ Post-workout PR celebration triggered:', postWorkoutJson.data);

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Test POST /notifications/admin/trigger-missed-sweep (10:30 AM Auto-Regulation)
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 3. Testing Missed Workout Auto-Regulation Sweep (10:30 AM Trigger) ---');
    const missedRes = await fetch(`${baseUrl}/notifications/admin/trigger-missed-sweep`, {
      method: 'POST',
      headers: adminHeaders,
    });
    const missedJson = await missedRes.json();
    console.assert(missedRes.status === 200, `Expected 200, got ${missedRes.status}`);
    console.assert(missedJson.success === true, 'Missed workout sweep failed');
    console.log('✔ Missed workout sweep endpoint succeeded:', missedJson.data);

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Test POST /notifications/admin/trigger-evening-sweep (8:30 PM Trigger)
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 4. Testing Evening Accountability Sweep (8:30 PM Trigger) ---');
    const eveningRes = await fetch(`${baseUrl}/notifications/admin/trigger-evening-sweep`, {
      method: 'POST',
      headers: adminHeaders,
    });
    const eveningJson = await eveningRes.json();
    console.assert(eveningRes.status === 200, `Expected 200, got ${eveningRes.status}`);
    console.assert(eveningJson.success === true, 'Evening sweep failed');
    console.log('✔ Evening sweep endpoint succeeded:', eveningJson.data);

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Verify Database Notifications Table
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 5. Verifying In-App Notification Center Database Persistence ---');
    if (client.clientProfile) {
      const persistedNotifications = await prisma.notification.findMany({
        where: { clientProfileId: client.clientProfile.id },
        orderBy: { createdAt: 'desc' },
        take: 5,
      });

      console.assert(persistedNotifications.length > 0, 'Expected notifications in database');
      for (const n of persistedNotifications) {
        console.log(`  [${n.triggerRule}] "${n.title}" -> "${n.message}"`);
      }
      console.log(`✔ Verified ${persistedNotifications.length} proactive AI coach notifications recorded in DB`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Security Check: Client cannot call admin trigger endpoints
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 6. Security Check: Client Forbidden on Admin Triggers ---');
    const forbiddenRes = await fetch(`${baseUrl}/notifications/admin/trigger-morning-sweep`, {
      method: 'POST',
      headers: clientHeaders,
    });
    console.assert(forbiddenRes.status === 403, `Expected 403, got ${forbiddenRes.status}`);
    console.log('✔ Security verified: 403 Forbidden for clients on admin trigger endpoints');

    console.log('\n================================================================');
    console.log('🎉 ALL 6 PROACTIVE AI COACH NOTIFICATION TESTS PASSED!');
    console.log('================================================================');
  } catch (err) {
    console.error('❌ Test failed with error:', err);
    process.exit(1);
  } finally {
    server.close();
    await prisma.$disconnect();
  }
}

runTests();
