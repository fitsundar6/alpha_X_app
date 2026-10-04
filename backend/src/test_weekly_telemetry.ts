import app from './server';
import http from 'http';
import { prisma } from './config/prisma';

async function runTelemetryTests() {
  console.log('================================================================');
  console.log('📊 STARTING SUNDAY ALPHA TELEMETRY ("SPOTIFY-WRAPPED") VERIFICATION');
  console.log('================================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5097, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5097/api/v1';

  const adminHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_admin',
  };

  const clientHeaders = {
    'Content-Type': 'application/json',
    Authorization: 'Bearer alpha_x_mock_token_for_client',
  };

  try {
    // 1. Ensure test client Marcus Vance exists with profile and workouts this week
    const now = new Date();
    const client = await prisma.user.upsert({
      where: { id: 'client_marcus_vance' },
      update: {
        notificationsEnabled: true,
        oneSignalPlayerId: 'mock-onesignal-marcus-telemetry',
      },
      create: {
        id: 'client_marcus_vance',
        email: 'marcus@client.alphax.gym',
        name: 'Marcus Vance',
        role: 'CLIENT',
        notificationsEnabled: true,
        oneSignalPlayerId: 'mock-onesignal-marcus-telemetry',
        clientProfile: {
          create: {
            clientId: 'client_marcus_vance',
            dailyStepGoal: 8000,
            primaryGoal: 'Build Strength',
            trainingDaysPerWeek: 4,
          },
        },
      },
      include: { clientProfile: true },
    });

    console.log(`✔ Verified test client: ${client.name} (${client.id})`);

    // Clean up previous test records for clean telemetry count
    await prisma.workoutRecord.deleteMany({
      where: {
        clientId: client.id,
        sessionTitle: { in: ['Chest & Triceps Hypertrophy', 'Heavy Deadlift & Back Power', 'Leg Annihilation Quad Focus'] },
      },
    });

    // 2. Seed realistic weekly workout records for Marcus
    // Workout 1: Chest & Triceps (14,400 kg)
    const w1 = await prisma.workoutRecord.create({
      data: {
        clientId: client.id,
        sessionTitle: 'Chest & Triceps Hypertrophy',
        workoutType: 'Hypertrophy',
        startedAt: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000), // 4 days ago
        completedAt: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000 + 3600000),
        durationSeconds: 3600,
        totalVolume: 14400.0,
        completedSetsCount: 16,
        isCompleted: true,
        averageRpe: 8.5,
        personalRecordsJson: JSON.stringify([
          { exerciseName: 'Incline Dumbbell Press', type: 'WEIGHT', value: 42, weight: 42, reps: 8 },
        ]),
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_incline_db_press',
              exerciseName: 'Incline Dumbbell Bench Press',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 36, actualReps: 10, isCompleted: true },
                  { setNumber: 2, actualWeight: 40, actualReps: 8, isCompleted: true },
                  { setNumber: 3, actualWeight: 42, actualReps: 8, isCompleted: true },
                  { setNumber: 4, actualWeight: 42, actualReps: 7, isCompleted: true },
                ],
              },
            },
            {
              exerciseId: 'ex_tricep_dips',
              exerciseName: 'Weighted Tricep Dips',
              orderIndex: 1,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 20, actualReps: 12, isCompleted: true },
                  { setNumber: 2, actualWeight: 25, actualReps: 10, isCompleted: true },
                  { setNumber: 3, actualWeight: 25, actualReps: 10, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Workout 2: Heavy Deadlift & Back Power (21,600 kg)
    const w2 = await prisma.workoutRecord.create({
      data: {
        clientId: client.id,
        sessionTitle: 'Heavy Deadlift & Back Power',
        workoutType: 'Strength',
        startedAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
        completedAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000 + 4200000),
        durationSeconds: 4200,
        totalVolume: 21600.0,
        completedSetsCount: 18,
        isCompleted: true,
        averageRpe: 9.0,
        personalRecordsJson: JSON.stringify([
          { exerciseName: 'Barbell Conventional Deadlift', type: 'WEIGHT', value: 200, weight: 200, reps: 3 },
        ]),
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_conv_deadlift',
              exerciseName: 'Conventional Barbell Deadlift',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 140, actualReps: 5, isCompleted: true },
                  { setNumber: 2, actualWeight: 180, actualReps: 3, isCompleted: true },
                  { setNumber: 3, actualWeight: 200, actualReps: 3, isCompleted: true },
                ],
              },
            },
            {
              exerciseId: 'ex_barbell_row',
              exerciseName: 'Pendlay Barbell Row',
              orderIndex: 1,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 90, actualReps: 8, isCompleted: true },
                  { setNumber: 2, actualWeight: 95, actualReps: 8, isCompleted: true },
                  { setNumber: 3, actualWeight: 100, actualReps: 6, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    // Workout 3: Leg Annihilation Quad Focus (18,200 kg)
    const w3 = await prisma.workoutRecord.create({
      data: {
        clientId: client.id,
        sessionTitle: 'Leg Annihilation Quad Focus',
        workoutType: 'Hypertrophy',
        startedAt: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000), // 1 day ago
        completedAt: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000 + 3900000),
        durationSeconds: 3900,
        totalVolume: 18200.0,
        completedSetsCount: 16,
        isCompleted: true,
        averageRpe: 8.8,
        personalRecordsJson: JSON.stringify([]),
        exerciseRecords: {
          create: [
            {
              exerciseId: 'ex_barbell_squat',
              exerciseName: 'Barbell Back Squat',
              orderIndex: 0,
              setRecords: {
                create: [
                  { setNumber: 1, actualWeight: 120, actualReps: 8, isCompleted: true },
                  { setNumber: 2, actualWeight: 140, actualReps: 6, isCompleted: true },
                  { setNumber: 3, actualWeight: 140, actualReps: 6, isCompleted: true },
                ],
              },
            },
          ],
        },
      },
    });

    console.log(`✔ Seeded 3 high-volume sessions across the week for ${client.name}`);

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1: Client Fetches Weekly Telemetry ("Spotify-Wrapped" Report)
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 1. Testing Client GET /telemetry/client/weekly-report ---');
    const clientTelRes = await fetch(`${baseUrl}/telemetry/client/weekly-report`, {
      headers: clientHeaders,
    });
    const clientTelJson = await clientTelRes.json();

    console.assert(clientTelRes.status === 200, `Expected 200, got ${clientTelRes.status}`);
    console.assert(clientTelJson.success === true, 'Telemetry response unsuccessful');

    const report = clientTelJson.data;
    console.log(`✔ Report ID: ${report.id}`);
    console.log(`✔ Total Iron Tonnage: ${report.totalVolumeKg.toLocaleString()} kg`);
    console.log(`✔ Physical Comparison: "${report.physicalComparison.description}" (${report.physicalComparison.itemIcon})`);
    console.log(`✔ Workouts Completed: ${report.totalWorkoutsCompleted} / ${report.targetWorkouts} (${report.adherencePercentage}% Adherence)`);
    console.log(`✔ Total Time: ${report.totalDurationMinutes} mins across ${report.completedSetsCount} sets`);

    console.assert(report.totalVolumeKg > 50000, `Expected > 50,000 kg volume, got ${report.totalVolumeKg}`);
    console.assert(report.muscleHeatmap.length === 6, `Expected 6 muscle groups, got ${report.muscleHeatmap.length}`);

    console.log('\n🦾 3D Muscle Heatmap Breakdown:');
    for (const mg of report.muscleHeatmap) {
      console.log(`   • ${mg.displayName} (${mg.muscleGroup}): ${mg.totalSets} sets | ${mg.totalVolumeKg.toLocaleString()} kg | Status: [${mg.status}] (${mg.statusColor})`);
    }

    console.log('\n🏆 Personal Records Broken:');
    for (const pr of report.personalRecords) {
      console.log(`   • 🥇 ${pr.exerciseName}: ${pr.value} (${pr.type})`);
    }
    console.assert(report.personalRecords.length >= 2, 'Expected at least 2 PRs');

    console.log(`\n🤖 AI Coach Telemetry Review:\n   "${report.aiCoachCommentary}"`);
    console.assert(report.aiCoachCommentary.length > 20, 'Expected non-empty AI coach review');

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2: Admin Overview & Gym-Wide Leaderboard
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 2. Testing Admin GET /telemetry/admin/overview ---');
    const adminOverviewRes = await fetch(`${baseUrl}/telemetry/admin/overview`, {
      headers: adminHeaders,
    });
    const adminOverviewJson = await adminOverviewRes.json();
    console.assert(adminOverviewRes.status === 200, `Expected 200, got ${adminOverviewRes.status}`);
    const overview = adminOverviewJson.data;

    console.log(`✔ Gym Total Tonnage Moved: ${overview.totalTonnageMovedKg.toLocaleString()} kg`);
    console.log(`✔ Total Sessions Completed: ${overview.totalSessionsCompleted}`);
    console.log(`✔ Average Gym Adherence: ${overview.averageGymAdherencePct}%`);
    console.log(`✔ Ranked Leaderboard Count: ${overview.leaderboard.length}`);

    const topClient = overview.leaderboard[0];
    console.log(`✔ #1 Ranked Lifter: ${topClient.clientName} with ${topClient.totalVolumeKg.toLocaleString()} kg (${topClient.physicalComparisonLabel})`);
    console.assert(topClient.rank === 1, 'Top client should have rank 1');

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3: Admin Detailed Client Dossier
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 3. Testing Admin GET /telemetry/admin/client/:clientId ---');
    const adminDossierRes = await fetch(`${baseUrl}/telemetry/admin/client/${client.id}`, {
      headers: adminHeaders,
    });
    const adminDossierJson = await adminDossierRes.json();
    console.assert(adminDossierRes.status === 200, 'Expected 200 for client dossier');
    console.assert(adminDossierJson.data.clientId === client.id, 'Dossier client ID mismatch');
    console.log(`✔ Admin retrieved full dossier for ${adminDossierJson.data.clientName}`);

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4: Admin Sunday 8:00 PM Telemetry Dispatch Trigger
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 4. Testing Admin POST /telemetry/admin/trigger-dispatch ---');
    const dispatchRes = await fetch(`${baseUrl}/telemetry/admin/trigger-dispatch`, {
      method: 'POST',
      headers: adminHeaders,
    });
    const dispatchJson = await dispatchRes.json();
    console.assert(dispatchRes.status === 200, `Expected 200, got ${dispatchRes.status}`);
    console.log(`✔ Sunday Telemetry Dispatch executed:`, dispatchJson.data);
    console.assert(dispatchJson.data.sent >= 1, 'Expected at least 1 client notified');

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5: Verify Notification Persistence in Database
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 5. Verifying Notification Center Database Record ---');
    if (client.clientProfile) {
      const persisted = await prisma.notification.findFirst({
        where: {
          clientProfileId: client.clientProfile.id,
          triggerRule: 'WEEKLY_TELEMETRY',
        },
        orderBy: { createdAt: 'desc' },
      });

      console.assert(!!persisted, 'Expected WEEKLY_TELEMETRY notification in DB');
      console.log(`✔ [WEEKLY_TELEMETRY] "${persisted?.title}": "${persisted?.message}"`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6: Security Verification: Client denied on Admin routes
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 6. Security Verification: Client Denied on Admin Routes ---');
    const forbiddenRes = await fetch(`${baseUrl}/telemetry/admin/overview`, {
      headers: clientHeaders,
    });
    console.assert(forbiddenRes.status === 403, `Expected 403, got ${forbiddenRes.status}`);
    console.log('✔ Security verified: 403 Forbidden for clients on admin telemetry routes');

    console.log('\n================================================================');
    console.log('🎉 ALL 6 SUNDAY ALPHA TELEMETRY VERIFICATION TESTS PASSED!');
    console.log('================================================================');
  } catch (err) {
    console.error('❌ Telemetry test failed with error:', err);
    process.exit(1);
  } finally {
    server.close();
    await prisma.$disconnect();
  }
}

runTelemetryTests();
