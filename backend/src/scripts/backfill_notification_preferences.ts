import { prisma } from '../config/prisma';

async function backfillNotificationPreferences() {
  console.log('[BACKFILL] Checking for client profiles missing notification preferences...');

  const profilesWithoutPref = await prisma.clientProfile.findMany({
    where: {
      notificationPref: null,
    },
    select: {
      id: true,
      clientId: true,
      user: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
  });

  console.log(`[BACKFILL] Found ${profilesWithoutPref.length} client profiles without notification preferences.`);

  let createdCount = 0;
  for (const profile of profilesWithoutPref) {
    await prisma.notificationPreference.create({
      data: {
        clientProfileId: profile.id,
        workoutReminders: true,
        nutritionReminders: true,
        weeklyCheckInReminders: true,
        activityReminders: true,
        membershipAlerts: true,
        aiEngagementEnabled: true,
        timezone: 'Asia/Kolkata',
        quietHoursStart: 21,
        quietHoursEnd: 7,
      },
    });
    createdCount++;
    console.log(`[BACKFILL] Created default preferences for client "${profile.clientId || profile.id}" (${profile.user?.name})`);
  }

  // Also check existing preferences to make sure timezone and quiet hours are populated
  const totalPrefs = await prisma.notificationPreference.count();
  console.log(`[BACKFILL] Completed. Total notification preferences in DB: ${totalPrefs}`);
}

backfillNotificationPreferences()
  .catch((err) => {
    console.error('[BACKFILL] Error:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
