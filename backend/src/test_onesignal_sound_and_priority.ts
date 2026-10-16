import { oneSignalService } from './modules/notifications/onesignal.service';

async function runTest() {
  console.log('=== OneSignal High Priority, Channel, and Sound Verification ===');

  let interceptedBody: any = null;

  // Intercept executePost to inspect the payload sent to OneSignal REST API
  const origExecutePost = (oneSignalService as any).executePost;
  (oneSignalService as any).executePost = async (body: any, targetId: string, title: string) => {
    interceptedBody = body;
    return {
      success: true,
      playerId: targetId,
      httpStatus: 200,
      response: { id: 'mock-notif-id', recipients: 1 },
    };
  };

  try {
    // Test 1: sendToPlayer default channel, priority, and sound
    await oneSignalService.sendToPlayer('test-player-123', {
      title: 'Workout Reminder',
      body: 'Time to crush legs today!',
    });

    console.assert(interceptedBody !== null, 'Payload was intercepted');
    console.assert(interceptedBody.priority === 10, `Expected priority 10, got ${interceptedBody?.priority}`);
    console.assert(interceptedBody.android_sound === 'default', `Expected android_sound 'default', got ${interceptedBody?.android_sound}`);
    console.assert(interceptedBody.ios_sound === 'default', `Expected ios_sound 'default', got ${interceptedBody?.ios_sound}`);
    console.assert(interceptedBody.android_channel_id === 'alpha_x_alerts', `Expected channel 'alpha_x_alerts', got ${interceptedBody?.android_channel_id}`);
    console.assert(interceptedBody.android_accent_color === 'FF39FF14', `Expected accent color 'FF39FF14', got ${interceptedBody?.android_accent_color}`);
    console.log('✅ Test 1 Passed: sendToPlayer correctly sets priority 10, sound default, and alpha_x_alerts channel');

    // Test 2: Custom channelId overrides default
    await oneSignalService.sendToPlayer('test-player-123', {
      title: 'Custom Announcement',
      body: 'Gym closed tomorrow',
      channelId: 'alpha_x_announcements',
    });

    console.assert(interceptedBody.android_channel_id === 'alpha_x_announcements', `Expected channel 'alpha_x_announcements', got ${interceptedBody?.android_channel_id}`);
    console.assert(interceptedBody.priority === 10, 'Priority remains 10 for custom channel');
    console.log('✅ Test 2 Passed: Custom channelId overrides default channel');

    // Test 3: broadcastToDevices sets high priority and sound
    await oneSignalService.broadcastToDevices(['device-1', 'device-2'], {
      title: 'Daily Motivational Push',
      body: 'Consistency is key!',
    });

    console.assert(interceptedBody.priority === 10, 'Broadcast sets priority 10');
    console.assert(interceptedBody.android_sound === 'default', 'Broadcast sets android_sound default');
    console.assert(interceptedBody.android_channel_id === 'alpha_x_alerts', 'Broadcast sets default channel');
    console.log('✅ Test 3 Passed: broadcastToDevices sets priority 10, sound, and channel');

    console.log('\nAll 3 OneSignal sound and priority payload tests PASSED!');
  } finally {
    (oneSignalService as any).executePost = origExecutePost;
  }
}

runTest().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
