import http from 'http';
import app from './server';
import { prisma } from './config/prisma';
import { adminAuthService } from './modules/auth/admin_auth.service';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';

async function runTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING ALPHA X AUTOMATION & AI SYSTEM TESTS');
  console.log('====================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}`;
  console.log(`📡 Test server running at ${baseUrl}`);

  try {
    // 1. Setup Test Athletes
    const emailA = `athlete_auto_a_${Date.now()}@alphaxgym.com`;
    const userA = await prisma.user.create({
      data: {
        email: emailA,
        name: 'Arjun Automation',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-AUTO1',
            weightKg: 82.5,
            dailyStepGoal: 8000,
            primaryGoal: 'Muscle Gain',
            lastAppOpenAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000), // 4 days inactive
            membershipPlan: 'ELITE_ANNUAL',
            membershipStatus: 'ACTIVE',
            membershipExpiresAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), // Expires in 5 days
          },
        },
      },
      include: { clientProfile: true },
    });
    const profileA = userA.clientProfile!;
    const tokenA = jwt.sign({ id: userA.id, email: userA.email, role: 'CLIENT' }, env.JWT_ACCESS_SECRET, { expiresIn: '1h' });

    // Athlete B with pain reported
    const emailB = `athlete_auto_b_${Date.now()}@alphaxgym.com`;
    const userB = await prisma.user.create({
      data: {
        email: emailB,
        name: 'Priya Performance',
        role: 'CLIENT',
        clientProfile: {
          create: {
            clientId: 'AXG-AUTO2',
            weightKg: 61.0,
            dailyStepGoal: 10000,
            primaryGoal: 'Fat Loss',
            lastAppOpenAt: new Date(),
          },
        },
      },
      include: { clientProfile: true },
    });
    const profileB = userB.clientProfile!;
    const tokenB = jwt.sign({ id: userB.id, email: userB.email, role: 'CLIENT' }, env.JWT_ACCESS_SECRET, { expiresIn: '1h' });

    // Add check-in with pain reported for Athlete B
    await prisma.weeklyCheckIn.create({
      data: {
        clientProfileId: profileB.id,
        clientId: profileB.clientId,
        weekNumber: 1,
        year: 2026,
        nextCheckInDate: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000),
        weightKg: 61.0,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 7.5,
        recoveryQuality: 'Average',
        workoutCompletion: 'All',
        workoutFeeling: 'Good',
        energyLevel: 'High',
        hasPain: true,
        painLocation: 'Right Knee',
        painExercise: 'Barbell Back Squat',
        painLevel: 7,
        painDescription: 'Sharp pinch in anterior knee during bottom of squat',
      },
    });

    const adminSession = adminAuthService.generateAdminSession();
    const adminToken = adminSession.token;

    console.log('✔ Test athletes and Admin session initialized');

    // --- TEST 1: Trigger Daily Automation Cycle ---
    console.log('\n--- TEST 1: Daily Automation Engine Cycle ---');
    const autoRes = await fetch(`${baseUrl}/api/v1/automation/run-daily-check`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({}),
    });
    const autoJson: any = await autoRes.json();
    if (!autoRes.ok || !autoJson.success) {
      throw new Error(`Automation cycle failed: ${JSON.stringify(autoJson)}`);
    }
    console.log(`✔ Daily cycle executed: Evaluated ${autoJson.data.clientsEvaluated} clients, Created ${autoJson.data.notificationsCreated} notifications, ${autoJson.data.attentionItemsCreated} attention items`);

    // --- TEST 2: Inactive Athlete Attention & Notification ---
    console.log('\n--- TEST 2: Inactive Athlete Notification & Attention Item ---');
    const notifsRes = await fetch(`${baseUrl}/api/v1/client/me/notifications`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    const notifsJson: any = await notifsRes.json();
    if (!notifsRes.ok || !notifsJson.success || notifsJson.data.notifications.length === 0) {
      throw new Error(`Expected notification for inactive athlete A: ${JSON.stringify(notifsJson)}`);
    }
    const notifA = notifsJson.data.notifications[0];
    console.log(`✔ Client A received notification: "${notifA.title}" - "${notifA.message}" (Trigger: ${notifA.triggerRule})`);

    // --- TEST 3: Deduplication & Cooldown Rule ---
    console.log('\n--- TEST 3: Deduplication & Cooldown Enforcement ---');
    const duplicateRes = await fetch(`${baseUrl}/api/v1/automation/run-daily-check`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ clientId: userA.id }),
    });
    const duplicateJson: any = await duplicateRes.json();
    // Should NOT create duplicate notifications on immediate second run
    if (duplicateJson.data.notificationsCreated !== 0) {
      throw new Error(`Cooldown failed: Created duplicate notification (${duplicateJson.data.notificationsCreated})`);
    }
    console.log('✔ Cooldown verified: 0 duplicate notifications generated on immediate rerun');

    // --- TEST 4: Admin Attention Center Query & Severity Flags ---
    console.log('\n--- TEST 4: Admin Attention Center Query ---');
    const attentionRes = await fetch(`${baseUrl}/api/v1/admin/attention-center`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const attentionJson: any = await attentionRes.json();
    if (!attentionRes.ok || !attentionJson.success) {
      throw new Error(`Attention center query failed: ${JSON.stringify(attentionJson)}`);
    }
    const items = attentionJson.data.items;
    const painItem = items.find((i: any) => i.attentionType === 'PAIN_REPORTED');
    const inactiveItem = items.find((i: any) => i.attentionType === 'INACTIVE');
    if (!painItem) {
      throw new Error('Expected PAIN_REPORTED attention item for Client B');
    }
    if (!inactiveItem) {
      throw new Error('Expected INACTIVE attention item for Client A');
    }
    console.log(`✔ Admin Attention Center identified ${items.length} items (Critical Pain: ${attentionJson.data.counts.pain}, Inactive: ${attentionJson.data.counts.inactive})`);
    console.log(`✔ Pain Item: [${painItem.severity}] ${painItem.title} - ${painItem.details}`);

    // --- TEST 5: Admin Review Attention Item with Coach Note ---
    console.log('\n--- TEST 5: Admin Review Attention Item ---');
    const reviewRes = await fetch(`${baseUrl}/api/v1/admin/attention-items/${painItem.id}/review`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`,
      },
      body: JSON.stringify({ coachNotes: 'Advised athlete to pause heavy squats; assigned leg press and mobility protocol.' }),
    });
    const reviewJson: any = await reviewRes.json();
    if (!reviewRes.ok || !reviewJson.success || !reviewJson.data.isReviewed) {
      throw new Error(`Failed to review attention item: ${JSON.stringify(reviewJson)}`);
    }
    console.log(`✔ Attention item marked reviewed by Admin with coach note: "${reviewJson.data.coachNotes}"`);

    // --- TEST 6: Client Read Notification & Preferences ---
    console.log('\n--- TEST 6: Client Notification Read Status & Preferences ---');
    const markReadRes = await fetch(`${baseUrl}/api/v1/client/me/notifications/${notifA.id}/read`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    const markReadJson: any = await markReadRes.json();
    if (!markReadRes.ok || !markReadJson.data.isRead) {
      throw new Error('Failed to mark notification read');
    }

    const prefUpdateRes = await fetch(`${baseUrl}/api/v1/client/me/notification-preferences`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ workoutReminders: false, aiEngagementEnabled: true }),
    });
    const prefJson: any = await prefUpdateRes.json();
    if (!prefUpdateRes.ok || prefJson.data.workoutReminders !== false) {
      throw new Error('Failed to update notification preferences');
    }
    console.log('✔ Notification marked read and client preferences saved');

    // --- TEST 7: Automated Factual Weekly Report ---
    console.log('\n--- TEST 7: Factual Weekly Progress Report ---');
    const reportRes = await fetch(`${baseUrl}/api/v1/admin/clients/${userB.id}/weekly-report`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const reportJson: any = await reportRes.json();
    if (!reportRes.ok || !reportJson.success) {
      throw new Error(`Weekly report failed: ${JSON.stringify(reportJson)}`);
    }
    const report = reportJson.data;
    if (report.metrics.weightKg !== 61.0 || report.checkInSummary?.hasPain !== true) {
      throw new Error(`Report mismatch: ${JSON.stringify(report)}`);
    }
    console.log(`✔ Weekly report verified for ${report.client.name}: Weight ${report.metrics.weightKg}kg, Pain Details: "${report.checkInSummary.painDetails}"`);

    // --- TEST 8: Transformation Timeline (Weeks 1, 4, 8, 12) ---
    console.log('\n--- TEST 8: Transformation Timeline Milestones ---');
    const milestoneRes = await fetch(`${baseUrl}/api/v1/client/me/transformation-timeline`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        weekNumber: 1,
        weightKg: 82.5,
        waistCm: 88.0,
        notes: 'Baseline photos and measurements taken before Week 1 protocol.',
      }),
    });
    const milestoneJson: any = await milestoneRes.json();
    if (!milestoneRes.ok || !milestoneJson.success || milestoneJson.data.weekNumber !== 1) {
      throw new Error(`Failed to save milestone: ${JSON.stringify(milestoneJson)}`);
    }

    // Verify Admin can view timeline
    const adminTimelineRes = await fetch(`${baseUrl}/api/v1/admin/clients/${userA.id}/transformation-timeline`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const adminTimelineJson: any = await adminTimelineRes.json();
    if (!adminTimelineRes.ok || adminTimelineJson.data.length !== 1) {
      throw new Error('Admin could not view athlete transformation timeline');
    }
    console.log(`✔ Transformation milestone (Week 1, ${milestoneJson.data.weightKg}kg, ${milestoneJson.data.waistCm}cm) created and verified by Admin`);

    // Cleanup test data
    await prisma.notification.deleteMany({ where: { clientProfileId: { in: [profileA.id, profileB.id] } } });
    await prisma.adminAttentionItem.deleteMany({ where: { clientProfileId: { in: [profileA.id, profileB.id] } } });
    await prisma.transformationMilestone.deleteMany({ where: { clientProfileId: profileA.id } });
    await prisma.weeklyCheckIn.deleteMany({ where: { clientProfileId: profileB.id } });
    await prisma.user.deleteMany({ where: { id: { in: [userA.id, userB.id] } } });

    console.log('\n====================================================');
    console.log('🎉 ALL AUTOMATION & AI SYSTEM TESTS PASSED!');
    console.log('====================================================\n');
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error('❌ AUTOMATION TEST RUNNER FAILED:', err);
  process.exit(1);
});
