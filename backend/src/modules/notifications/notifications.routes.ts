/**
 * Alpha X — Notifications Routes
 *
 * POST /api/v1/notifications/register-device
 *   Client registers their OneSignal player ID after login.
 *
 * POST /api/v1/admin/notifications/trigger-sweep
 *   Admin manually triggers the AI notification sweep for all clients.
 *
 * PATCH /api/v1/notifications/opt-out
 *   Client can disable notifications.
 */

import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { prisma } from '../../config/prisma';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { aiNotificationEngine } from './ai_notifications.service';
import { oneSignalService } from './onesignal.service';

const router = Router();

/**
 * POST /register-device
 * Client app calls this on login to register/update their push token.
 * Supports multi-device subscriptions by deduplicating and appending to existing tokens.
 */
router.post('/register-device', requireAuth, async (req: Request, res: Response) => {
  // Support both explicit /unregister-device and legacy /register-device with unregister action
  if (req.body.action === 'unregister' || req.body.unregister === true) {
    return unregisterDeviceHandler(req, res);
  }

  const userId = (req as any).user?.id;
  const { playerId } = req.body;

  if (!playerId || typeof playerId !== 'string' || playerId.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'playerId is required and must be a non-empty string', HttpStatus.BAD_REQUEST);
    return;
  }

  const cleanPlayerId = playerId.trim();

  try {
    // 1. Cross-account safety: Detach this device from ANY OTHER user that might have had it previously.
    // This prevents stale device mappings and cross-account notification bleed when switching accounts on the same device.
    const staleUsers = await prisma.user.findMany({
      where: {
        id: { not: userId },
        oneSignalPlayerId: { contains: cleanPlayerId },
      },
      select: { id: true, oneSignalPlayerId: true },
    });

    for (const otherUser of staleUsers) {
      if (otherUser.oneSignalPlayerId) {
        const remaining = otherUser.oneSignalPlayerId
          .split(',')
          .map((t) => t.trim())
          .filter((t) => t.length > 0 && t !== cleanPlayerId);
        await prisma.user.update({
          where: { id: otherUser.id },
          data: { oneSignalPlayerId: remaining.length > 0 ? remaining.join(',') : null },
        });
        console.log(`[NOTIFICATIONS] 🔄 Safely detached device ${cleanPlayerId} from previous user ${otherUser.id}. Preserved ${remaining.length} other devices for that user.`);
      }
    }

    // 2. Register/append device to current user (deduplicated)
    const currentUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { oneSignalPlayerId: true },
    });

    let updatedTokens: string[];
    if (currentUser?.oneSignalPlayerId) {
      const existing = currentUser.oneSignalPlayerId
        .split(',')
        .map((t) => t.trim())
        .filter((t) => t.length > 0);
      if (!existing.includes(cleanPlayerId)) {
        updatedTokens = [...existing, cleanPlayerId];
      } else {
        updatedTokens = existing;
      }
    } else {
      updatedTokens = [cleanPlayerId];
    }

    await prisma.user.update({
      where: { id: userId },
      data: { oneSignalPlayerId: updatedTokens.join(',') },
    });
    console.log(`[NOTIFICATIONS] ✅ Registered device ${cleanPlayerId} for user ${userId}. Total devices: ${updatedTokens.length}`);
    sendSuccess(res, { registered: true, totalDevices: updatedTokens.length }, HttpStatus.OK);
  } catch (err: any) {
    console.error(`[NOTIFICATIONS] ❌ Failed to register device: ${err?.message}`);
    sendError(res, 'DB_ERROR', 'Failed to register device', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /unregister-device and DELETE /unregister-device
 * Client app calls this on logout to unbind their specific push token.
 * Security & Multi-Device Safety:
 *   - Strictly authenticated via requireAuth (JWT).
 *   - Clears ONLY the matching logged-out device subscription.
 *   - Preserves other active device subscriptions for the same client.
 *   - Prevents stale subscriptions from receiving notifications after logout.
 */
const unregisterDeviceHandler = async (req: Request, res: Response): Promise<void> => {
  const userId = (req as any).user?.id;
  const { playerId } = req.body;

  if (!playerId || typeof playerId !== 'string' || playerId.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'playerId is required and must be a non-empty string', HttpStatus.BAD_REQUEST);
    return;
  }

  const cleanPlayerId = playerId.trim();

  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { oneSignalPlayerId: true },
    });

    if (!user || !user.oneSignalPlayerId) {
      console.log(`[NOTIFICATIONS] ℹ️ Unregister request for user ${userId}: no active device registered.`);
      sendSuccess(res, { unregistered: true, cleared: false, preservedTokensCount: 0 }, HttpStatus.OK);
      return;
    }

    const currentTokens = user.oneSignalPlayerId
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0);

    const tokenMatched = currentTokens.includes(cleanPlayerId);

    if (!tokenMatched) {
      // The unregistering playerId does not match any active registered device token for this client.
      // Crucial: preserve existing active device tokens!
      console.log(`[NOTIFICATIONS] ℹ️ Unregister request for ${cleanPlayerId} did not match registered device for user ${userId}. Preserved ${currentTokens.length} active device(s).`);
      sendSuccess(
        res,
        {
          unregistered: true,
          cleared: false,
          preservedTokensCount: currentTokens.length,
          message: 'Device subscription was not active or already rotated; existing devices preserved.',
        },
        HttpStatus.OK
      );
      return;
    }

    // Filter out ONLY the matching logged-out device token
    const remainingTokens = currentTokens.filter((t) => t !== cleanPlayerId);
    const newPlayerIdValue = remainingTokens.length > 0 ? remainingTokens.join(',') : null;

    await prisma.user.update({
      where: { id: userId },
      data: { oneSignalPlayerId: newPlayerIdValue },
    });

    console.log(`[NOTIFICATIONS] ✅ Successfully unregistered device ${cleanPlayerId} for user ${userId}. Remaining devices: ${remainingTokens.length}`);
    sendSuccess(
      res,
      {
        unregistered: true,
        cleared: true,
        preservedTokensCount: remainingTokens.length,
        hasRemainingDevices: remainingTokens.length > 0,
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    console.error(`[NOTIFICATIONS] ❌ Failed to unregister device: ${err?.message}`);
    sendError(res, 'DB_ERROR', 'Failed to unregister device', HttpStatus.INTERNAL_SERVER_ERROR);
  }
};

router.post('/unregister-device', requireAuth, unregisterDeviceHandler);
router.delete('/unregister-device', requireAuth, unregisterDeviceHandler);


/**
 * PATCH /opt-out
 * Client disables or re-enables push notifications.
 */
router.patch('/opt-out', requireAuth, async (req: Request, res: Response) => {
  const userId = (req as any).user?.id;
  const { enabled } = req.body; // boolean

  try {
    await prisma.user.update({
      where: { id: userId },
      data: { notificationsEnabled: enabled !== false },
    });
    sendSuccess(res, { notificationsEnabled: enabled !== false }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'DB_ERROR', 'Failed to update preference', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/trigger-sweep (Admin only)
 * Manually triggers the daily AI notification sweep.
 */
router.post('/admin/trigger-sweep', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  try {
    aiNotificationEngine.runDailySweep().catch((err: any) =>
      console.error('[NOTIFICATIONS] Manual sweep error:', err?.message)
    );
    sendSuccess(res, { message: 'Daily AI notification sweep triggered' }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'SWEEP_ERROR', 'Failed to trigger sweep', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/trigger-morning-sweep (Admin only)
 * Manually triggers the 7:30 AM Morning Readiness Sweep.
 */
router.post('/admin/trigger-morning-sweep', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  try {
    const result = await aiNotificationEngine.runMorningCheckInSweep();
    sendSuccess(res, { message: 'Morning Readiness Sweep triggered', ...result }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'SWEEP_ERROR', err?.message || 'Failed to trigger morning sweep', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/trigger-missed-sweep (Admin only)
 * Manually triggers the 10:30 AM Missed Workout Auto-Regulation Sweep.
 */
router.post('/admin/trigger-missed-sweep', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  try {
    const result = await aiNotificationEngine.runMissedWorkoutSweep();
    sendSuccess(res, { message: 'Missed Workout Sweep triggered', ...result }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'SWEEP_ERROR', err?.message || 'Failed to trigger missed workout sweep', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/trigger-evening-sweep (Admin only)
 * Manually triggers the 8:30 PM Evening Accountability Sweep.
 */
router.post('/admin/trigger-evening-sweep', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  try {
    const result = await aiNotificationEngine.runEveningCheckInSweep();
    sendSuccess(res, { message: 'Evening Accountability Sweep triggered', ...result }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'SWEEP_ERROR', err?.message || 'Failed to trigger evening sweep', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/simulate-post-workout (Admin only)
 * Simulates workout completion and dispatches immediate PR / celebration notification.
 */
router.post('/admin/simulate-post-workout', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const { clientId, sessionTitle, totalVolume, personalRecords } = req.body;
  if (!clientId) {
    sendError(res, 'VALIDATION_ERROR', 'clientId is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const simulatedRecord = {
      id: `sim-${Date.now()}`,
      sessionTitle: sessionTitle || 'Deadlift & Posterior Chain',
      durationSeconds: 3600,
      totalVolume: totalVolume || 4200,
      completedSetsCount: 16,
      personalRecords: personalRecords || [
        { exerciseName: 'Deadlift', type: 'VOLUME', value: 4200, weight: 180 },
      ],
    };

    const dispatched = await aiNotificationEngine.sendPostWorkoutCelebration(clientId, simulatedRecord);
    sendSuccess(res, { dispatched, simulatedRecord }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'SIMULATION_ERROR', err?.message || 'Failed to simulate post workout push', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});
/**
 * POST /admin/send-to-client (Admin only)
 * Sends a live push notification to ONE selected client targeted by their OneSignal External ID.
 * Strictly authenticated via requireAuth + requireAdmin.
 * Verifies external ID identity linking, recipient preferences, and returns notification ID & delivery reporting.
 */
router.post('/admin/send-to-client', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const { clientId, title, body, channelId, targetMethod = 'EXTERNAL_ID' } = req.body;

  if (!clientId || typeof clientId !== 'string' || clientId.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'clientId (User UUID, Client ID, or email) is required', HttpStatus.BAD_REQUEST);
    return;
  }

  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Notification title is required', HttpStatus.BAD_REQUEST);
    return;
  }

  const rawMessage = body || req.body.message;
  if (!rawMessage || typeof rawMessage !== 'string' || rawMessage.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Notification message/body is required', HttpStatus.BAD_REQUEST);
    return;
  }

  const cleanTitle = title.trim();
  const cleanBody = rawMessage.trim();

  try {
    const user = await prisma.user.findFirst({
      where: {
        role: 'CLIENT',
        OR: [
          { id: clientId.trim() },
          { clientProfile: { clientId: clientId.trim() } },
          { email: clientId.trim().toLowerCase() },
        ],
      },
      include: {
        clientProfile: true,
      },
    });

    if (!user) {
      sendError(res, 'NOT_FOUND', `Client "${clientId}" not found in database`, HttpStatus.NOT_FOUND);
      return;
    }

    if (!user.notificationsEnabled) {
      sendError(res, 'OPTED_OUT', `Client "${user.name}" (${user.clientProfile?.clientId || user.id}) has opted out of push notifications`, HttpStatus.BAD_REQUEST);
      return;
    }

    const externalId = user.id; // Authoritative External ID used in OneSignal.login(userId)
    let sendResult: any;
    let actualTargetMethod = targetMethod;

    if (targetMethod === 'DEVICE_TOKEN') {
      if (!user.oneSignalPlayerId || user.oneSignalPlayerId.trim().length === 0) {
        sendError(
          res,
          'DEVICE_NOT_REGISTERED',
          `Client "${user.name}" has no registered device push token in the database. Use targetMethod: "EXTERNAL_ID" or have client log into the mobile app.`,
          HttpStatus.BAD_REQUEST
        );
        return;
      }
      sendResult = await oneSignalService.sendToPlayer(user.oneSignalPlayerId, {
        title: cleanTitle,
        body: cleanBody,
        channelId: channelId || 'alpha_x_alerts',
        data: {
          type: 'admin_direct_push',
          targetMethod: 'DEVICE_TOKEN',
          clientId: user.clientProfile?.clientId || user.id,
          targetUserId: user.id,
          timestamp: new Date().toISOString(),
        },
      });
    } else {
      // Default: EXTERNAL_ID targeting (OneSignal include_aliases: { external_id: [user.id] })
      actualTargetMethod = 'EXTERNAL_ID';
      sendResult = await oneSignalService.sendToUser(externalId, {
        title: cleanTitle,
        body: cleanBody,
        channelId: channelId || 'alpha_x_alerts',
        data: {
          type: 'admin_direct_push',
          targetMethod: 'EXTERNAL_ID',
          clientId: user.clientProfile?.clientId || user.id,
          targetUserId: user.id,
          timestamp: new Date().toISOString(),
        },
      });
    }

    const notificationId = sendResult.response?.id || null;

    // Persist in-app notification record in PostgreSQL
    let savedNotificationId: string | undefined;
    if (user.clientProfile?.id) {
      try {
        const notif = await prisma.notification.create({
          data: {
            clientProfileId: user.clientProfile.id,
            clientId: user.clientProfile.clientId || null,
            title: cleanTitle,
            message: cleanBody,
            type: 'SYSTEM',
            category: 'ANNOUNCEMENT',
            source: 'ADMIN',
            triggerRule: 'ADMIN_DIRECT_PUSH',
            sentStatus: sendResult.success ? 'SENT' : 'FAILED',
            errorDetails: sendResult.error || null,
            metadataJson: JSON.stringify({
              externalId,
              targetMethod: actualTargetMethod,
              notificationId,
              gatewaySuccess: sendResult.success,
              httpStatus: sendResult.httpStatus,
              oneSignalPlayerId: user.oneSignalPlayerId,
            }),
          },
        });
        savedNotificationId = notif.id;
      } catch (dbErr: any) {
        console.warn('[NOTIFICATIONS] In-app record save warning:', dbErr?.message);
      }
    }

    sendSuccess(
      res,
      {
        client: {
          id: user.id,
          clientId: user.clientProfile?.clientId || 'N/A',
          name: user.name,
          email: user.email,
          externalId: user.id,
          hasRegisteredDevice: Boolean(user.oneSignalPlayerId && user.oneSignalPlayerId.trim().length > 0),
          oneSignalPlayerId: user.oneSignalPlayerId,
        },
        notificationId,
        externalId: user.id,
        inAppNotificationId: savedNotificationId,
        targetMethod: actualTargetMethod,
        gatewayResponse: {
          success: sendResult.success,
          httpStatus: sendResult.httpStatus,
          recipients: sendResult.response?.recipients ?? (sendResult.success ? 1 : 0),
          error: sendResult.error,
          details: sendResult.response,
        },
        deliveryLifecycle: {
          stage1_gatewayAccepted: Boolean(sendResult.success),
          stage2_fcmTransit: sendResult.success
            ? 'Dispatched to FCM gateway for device transmission'
            : (sendResult.error || 'Failed at gateway'),
          stage3_deviceDisplay: 'Pending device confirmation (asynchronous)',
          stage1_apiAcceptance: {
            accepted: sendResult.success,
            status: sendResult.success ? 'ACCEPTED_BY_ONESIGNAL' : 'GATEWAY_REJECTED',
            notificationId,
            httpStatus: sendResult.httpStatus,
          },
          stage2_deliveryReporting: {
            status: sendResult.success ? 'DISPATCHED_TO_GATEWAY' : 'FAILED',
            endpoint: notificationId ? `/api/v1/notifications/admin/delivery-status/${notificationId}` : null,
            notice: 'Gateway acceptance verified. Delivery reporting available via status endpoint.',
          },
          stage3_deviceReceipt: {
            status: 'PHYSICAL_DEVICE_PENDING',
            notice: 'Physical device delivery depends on FCM/APNs push service, device network connection, and client notification permissions.',
          },
        },
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    sendError(res, 'DISPATCH_ERROR', err?.message || 'Failed to send notification to client', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /admin/delivery-status/:notificationId (Admin only)
 * Queries OneSignal REST API for delivery reporting and provider confirmation.
 * Separates API acceptance, provider transmission, and physical device receipt.
 */
router.get('/admin/delivery-status/:notificationId', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const { notificationId } = req.params;

  if (!notificationId || typeof notificationId !== 'string' || notificationId.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'notificationId is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const report = await oneSignalService.getNotificationDeliveryReport(notificationId.trim());
    sendSuccess(res, report, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'FETCH_ERROR', err?.message || 'Failed to query notification delivery status', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/send-test (Admin only)
 * Secure test action: sends a real push notification to a selected client device or external ID
 * and returns the actual push gateway/FCM error response.
 */
router.post('/admin/send-test', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const { clientId, playerId, title, body, targetMethod = 'AUTO' } = req.body;

  const pushTitle = title || '⚡ Alpha X Test Notification';
  const pushBody = body || 'This is a test notification from Alpha X Gym Admin.';

  try {
    // 1. If explicit playerId is provided, dispatch directly to player/subscription ID
    if (playerId && typeof playerId === 'string' && playerId.trim().length > 0) {
      const result = await oneSignalService.sendToPlayer(playerId.trim(), {
        title: pushTitle,
        body: pushBody,
        data: { type: 'admin_test', targetMethod: 'PLAYER_ID', timestamp: new Date().toISOString() },
      });
      sendSuccess(res, {
        target: playerId.trim(),
        targetMethod: 'PLAYER_ID',
        notificationId: result.response?.id || null,
        gatewayResponse: result,
      }, HttpStatus.OK);
      return;
    }

    // 2. Otherwise locate the target client user in the database
    if (!clientId) {
      sendError(res, 'VALIDATION_ERROR', 'clientId or playerId is required', HttpStatus.BAD_REQUEST);
      return;
    }

    const user = await prisma.user.findFirst({
      where: {
        role: 'CLIENT',
        OR: [
          { id: clientId },
          { clientProfile: { clientId: clientId } },
          { email: clientId },
        ],
      },
      include: {
        clientProfile: true,
      },
    });

    if (!user) {
      sendError(res, 'NOT_FOUND', `Client "${clientId}" not found`, HttpStatus.NOT_FOUND);
      return;
    }

    if (!user.notificationsEnabled) {
      sendError(res, 'OPTED_OUT', `Client "${user.name}" has opted out of notifications`, HttpStatus.BAD_REQUEST);
      return;
    }

    // 3. Dispatch via External ID (default) or fallback to registered playerId
    let result: any;
    let actualMethod = targetMethod;

    if (targetMethod === 'DEVICE_TOKEN' && user.oneSignalPlayerId) {
      actualMethod = 'DEVICE_TOKEN';
      result = await oneSignalService.sendToPlayer(user.oneSignalPlayerId, {
        title: pushTitle,
        body: pushBody,
        data: {
          type: 'admin_test',
          clientId: user.id,
          targetMethod: 'DEVICE_TOKEN',
          timestamp: new Date().toISOString(),
        },
      });
    } else {
      // Default: Target by OneSignal External ID (user.id linked via OneSignal.login)
      actualMethod = 'EXTERNAL_ID';
      result = await oneSignalService.sendToUser(user.id, {
        title: pushTitle,
        body: pushBody,
        data: {
          type: 'admin_test',
          clientId: user.id,
          targetMethod: 'EXTERNAL_ID',
          timestamp: new Date().toISOString(),
        },
      });

      // If External ID rejected or 0 recipients and device token is present, fallback to device token
      if (!result.success && user.oneSignalPlayerId) {
        console.log(`[ONESIGNAL] External ID targeting unsuccessful. Retrying with registered player ID for ${user.id}...`);
        actualMethod = 'DEVICE_TOKEN_FALLBACK';
        result = await oneSignalService.sendToPlayer(user.oneSignalPlayerId, {
          title: pushTitle,
          body: pushBody,
          data: {
            type: 'admin_test',
            clientId: user.id,
            targetMethod: 'DEVICE_TOKEN_FALLBACK',
            timestamp: new Date().toISOString(),
          },
        });
      }
    }

    const notificationId = result.response?.id || null;

    // 4. Record in in-app notification center table
    let recordedNotificationId: string | undefined;
    if (user.clientProfile?.id) {
      try {
        const notif = await prisma.notification.create({
          data: {
            clientProfileId: user.clientProfile.id,
            clientId: user.clientProfile.clientId || null,
            title: pushTitle,
            message: pushBody,
            type: 'SYSTEM',
            category: 'ANNOUNCEMENT',
            source: 'ADMIN',
            triggerRule: 'ADMIN_TEST_PUSH',
            sentStatus: result.success ? 'SENT' : 'FAILED',
            errorDetails: result.error || null,
            metadataJson: JSON.stringify({
              playerId: user.oneSignalPlayerId,
              externalId: user.id,
              targetMethod: actualMethod,
              notificationId,
              result,
            }),
          },
        });
        recordedNotificationId = notif.id;
      } catch (_) {}
    }

    sendSuccess(res, {
      client: {
        id: user.id,
        clientId: user.clientProfile?.clientId,
        name: user.name,
        email: user.email,
        externalId: user.id,
        hasRegisteredDevice: Boolean(user.oneSignalPlayerId),
        oneSignalPlayerId: user.oneSignalPlayerId,
      },
      targetMethod: actualMethod,
      notificationId,
      inAppNotificationId: recordedNotificationId,
      gatewayResponse: result,
      deliveryLifecycle: {
        stage1_apiAcceptance: result.success,
        stage2_deliveryReporting: notificationId ? `/api/v1/notifications/admin/delivery-status/${notificationId}` : null,
        stage3_deviceReceipt: 'Physical device delivery depends on FCM/APNS status and client permissions.',
      },
    }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'DISPATCH_ERROR', err?.message || 'Failed to send test push notification', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

function isDemoAccount(email: string, clientId?: string | null): boolean {
  const lowerEmail = (email || '').toLowerCase();
  const lowerClientId = (clientId || '').toLowerCase();
  return (
    lowerEmail.includes('demo') ||
    lowerEmail.includes('test@') ||
    lowerEmail.endsWith('@example.com') ||
    lowerClientId.startsWith('demo') ||
    lowerClientId.startsWith('test')
  );
}

let lastBroadcastCache: {
  hash: string;
  timestamp: number;
} | null = null;

/**
 * GET /admin/audience-preview (Admin only)
 * Returns the exact audience breakdown before broadcasting.
 */
router.get('/admin/audience-preview', requireAuth, requireAdmin, async (_req: Request, res: Response) => {
  try {
    const clients = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      select: {
        id: true,
        name: true,
        email: true,
        status: true,
        notificationsEnabled: true,
        oneSignalPlayerId: true,
        createdAt: true,
        clientProfile: {
          select: {
            id: true,
            clientId: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const eligibleClients = clients.filter(
      (c) =>
        c.status === 'APPROVED' &&
        c.notificationsEnabled &&
        c.oneSignalPlayerId &&
        c.oneSignalPlayerId.trim().length > 0 &&
        !isDemoAccount(c.email, c.clientProfile?.clientId)
    );

    const unregisteredApprovedClients = clients.filter(
      (c) =>
        c.status === 'APPROVED' &&
        c.notificationsEnabled &&
        (!c.oneSignalPlayerId || c.oneSignalPlayerId.trim().length === 0) &&
        !isDemoAccount(c.email, c.clientProfile?.clientId)
    );

    const optedOutClients = clients.filter((c) => !c.notificationsEnabled);
    const unapprovedClients = clients.filter((c) => c.status !== 'APPROVED');
    const demoClients = clients.filter((c) => isDemoAccount(c.email, c.clientProfile?.clientId));

    sendSuccess(
      res,
      {
        summary: {
          totalRegisteredClients: clients.length,
          approvedClientsCount: clients.filter((c) => c.status === 'APPROVED').length,
          eligiblePushRecipientsCount: eligibleClients.length,
          unregisteredDeviceCount: unregisteredApprovedClients.length,
          optedOutCount: optedOutClients.length,
          unapprovedOrSuspendedCount: unapprovedClients.length,
          demoAccountsExcludedCount: demoClients.length,
        },
        eligibleRecipients: eligibleClients.map((c) => ({
          id: c.id,
          clientId: c.clientProfile?.clientId || 'N/A',
          name: c.name,
          email: c.email,
          hasPushToken: true,
        })),
        pendingDeviceClients: unregisteredApprovedClients.map((c) => ({
          id: c.id,
          clientId: c.clientProfile?.clientId || 'N/A',
          name: c.name,
          email: c.email,
          hasPushToken: false,
          notice: 'Requires client mobile login to register push token',
        })),
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    sendError(res, 'FETCH_ERROR', err?.message || 'Failed to generate audience preview', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/broadcast (Admin only)
 * Broadcasts a push notification to All Eligible Clients or targeted recipients.
 */
router.post('/admin/broadcast', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const { title, body, targetAudience = 'ALL_ELIGIBLE', targetClientId, targetPlayerId, confirmBroadcast, channelId } = req.body;

  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Notification title is required', HttpStatus.BAD_REQUEST);
    return;
  }
  if (!body || typeof body !== 'string' || body.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Notification message body is required', HttpStatus.BAD_REQUEST);
    return;
  }

  const cleanTitle = title.trim();
  const cleanBody = body.trim();

  // Safety safeguard: require explicit operator confirmation when broadcasting to all clients
  if (targetAudience === 'ALL_ELIGIBLE' && confirmBroadcast !== true) {
    sendError(
      res,
      'CONFIRMATION_REQUIRED',
      'Broadcasting to all eligible clients requires explicit operator confirmation (confirmBroadcast: true)',
      HttpStatus.BAD_REQUEST
    );
    return;
  }

  // Duplicate send prevention (60-second window for identical message)
  const broadcastHash = `${targetAudience}:${cleanTitle}:${cleanBody}`;
  const now = Date.now();
  if (lastBroadcastCache && lastBroadcastCache.hash === broadcastHash && (now - lastBroadcastCache.timestamp) < 60000) {
    const remainingSec = Math.ceil((60000 - (now - lastBroadcastCache.timestamp)) / 1000);
    sendError(
      res,
      'DUPLICATE_BROADCAST_PREVENTED',
      `An identical broadcast was dispatched ${60 - remainingSec}s ago. Please wait ${remainingSec}s before retrying to prevent duplicate notifications.`,
      HttpStatus.CONFLICT
    );
    return;
  }

  try {
    let targetClients: any[] = [];
    let playerIds: string[] = [];

    if (targetAudience === 'TEST_DEVICE') {
      if (!targetPlayerId || typeof targetPlayerId !== 'string') {
        sendError(res, 'VALIDATION_ERROR', 'targetPlayerId is required when targetAudience is TEST_DEVICE', HttpStatus.BAD_REQUEST);
        return;
      }
      playerIds = [targetPlayerId.trim()];
    } else if (targetAudience === 'SPECIFIC_CLIENT') {
      if (!targetClientId) {
        sendError(res, 'VALIDATION_ERROR', 'targetClientId is required when targetAudience is SPECIFIC_CLIENT', HttpStatus.BAD_REQUEST);
        return;
      }
      const client = await prisma.user.findFirst({
        where: {
          role: 'CLIENT',
          OR: [
            { id: targetClientId },
            { clientProfile: { clientId: targetClientId } },
            { email: targetClientId },
          ],
        },
        include: { clientProfile: true },
      });
      if (!client) {
        sendError(res, 'NOT_FOUND', `Client "${targetClientId}" not found`, HttpStatus.NOT_FOUND);
        return;
      }
      if (!client.notificationsEnabled) {
        sendError(res, 'OPTED_OUT', `Client "${client.name}" has disabled notifications`, HttpStatus.BAD_REQUEST);
        return;
      }
      targetClients = [client];
      if (client.oneSignalPlayerId && client.oneSignalPlayerId.trim().length > 0) {
        playerIds = [client.oneSignalPlayerId.trim()];
      }
    } else {
      // ALL_ELIGIBLE: Query all approved, non-demo clients
      const allClients = await prisma.user.findMany({
        where: {
          role: 'CLIENT',
          status: 'APPROVED',
          notificationsEnabled: true,
        },
        include: { clientProfile: true },
      });

      targetClients = allClients.filter((c) => !isDemoAccount(c.email, c.clientProfile?.clientId));
      playerIds = targetClients
        .map((c) => c.oneSignalPlayerId?.trim())
        .filter((id): id is string => Boolean(id && id.length > 0));
    }

    // Dispatch via OneSignal
    const gatewayResult = playerIds.length > 0
      ? await oneSignalService.broadcastToDevices(playerIds, {
          title: cleanTitle,
          body: cleanBody,
          channelId: channelId || 'alpha_x_announcements',
          data: {
            type: 'admin_broadcast',
            targetAudience,
            timestamp: new Date().toISOString(),
          },
        })
      : {
          success: true,
          recipientsCount: 0,
          devicesTargeted: 0,
          response: { notice: 'No registered push devices found. In-app notifications created.' },
        };

    // Update duplicate protection cache
    lastBroadcastCache = { hash: broadcastHash, timestamp: now };

    // Record in-app Notification records in PostgreSQL for client notification center
    let createdNotificationCount = 0;
    for (const client of targetClients) {
      if (client.clientProfile?.id) {
        try {
          await prisma.notification.create({
            data: {
              clientProfileId: client.clientProfile.id,
              clientId: client.clientProfile.clientId || null,
              title: cleanTitle,
              message: cleanBody,
              type: 'SYSTEM',
              category: 'ANNOUNCEMENT',
              source: 'ADMIN',
              triggerRule: 'ADMIN_BROADCAST',
              sentStatus: gatewayResult.success ? 'SENT' : 'FAILED',
              metadataJson: JSON.stringify({
                targetAudience,
                oneSignalId: gatewayResult.notificationId || null,
                gatewaySuccess: gatewayResult.success,
                deviceTargeted: Boolean(client.oneSignalPlayerId),
              }),
            },
          });
          createdNotificationCount++;
        } catch (_) {}
      }
    }

    sendSuccess(
      res,
      {
        broadcastSuccess: gatewayResult.success,
        targetAudience,
        title: cleanTitle,
        recipientsSummary: {
          eligibleClientsTotal: targetClients.length,
          pushDevicesTargeted: playerIds.length,
          inAppNotificationsCreated: createdNotificationCount,
        },
        deliveryLifecycle: {
          stage1_gatewayAccepted: gatewayResult.success,
          stage2_fcmTransit: gatewayResult.success ? (playerIds.length > 0 ? 'Dispatched to push provider gateway' : 'No push tokens; in-app only') : 'Gateway rejected',
          stage3_deviceDisplay: 'Visible on device once received from FCM (subject to device notification permissions)',
        },
        gatewayResponse: {
          notificationId: gatewayResult.notificationId || null,
          httpStatus: gatewayResult.httpStatus,
          error: gatewayResult.error,
          details: gatewayResult.response,
        },
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    sendError(res, 'BROADCAST_ERROR', err?.message || 'Failed to dispatch broadcast', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /admin/devices (Admin only)
 * Lists all clients and their push notification token registration status.
 */
router.get('/admin/devices', requireAuth, requireAdmin, async (_req: Request, res: Response) => {
  try {
    const clients = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      select: {
        id: true,
        name: true,
        email: true,
        oneSignalPlayerId: true,
        notificationsEnabled: true,
        createdAt: true,
        clientProfile: {
          select: {
            clientId: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const summary = {
      totalClients: clients.length,
      registeredDevices: clients.filter((c) => c.oneSignalPlayerId !== null).length,
      unregisteredDevices: clients.filter((c) => c.oneSignalPlayerId === null).length,
      clients: clients.map((c) => ({
        id: c.id,
        clientId: c.clientProfile?.clientId || 'PENDING',
        name: c.name,
        email: c.email,
        hasDeviceToken: Boolean(c.oneSignalPlayerId),
        oneSignalPlayerId: c.oneSignalPlayerId,
        notificationsEnabled: c.notificationsEnabled,
      })),
    };

    sendSuccess(res, summary, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'FETCH_ERROR', err?.message || 'Failed to list client devices', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /admin/diagnostic (Admin only)
 * Safely inspects the OneSignal configuration health and live gateway connection.
 * Masked: never exposes the full API key secret.
 */
router.get('/admin/diagnostic', requireAuth, requireAdmin, async (_req: Request, res: Response) => {
  const rawKey = (process.env.ONESIGNAL_REST_API_KEY || '').trim();
  const rawAppId = (process.env.ONESIGNAL_APP_ID || '').trim();
  const cleanKey = oneSignalService.getSanitizedApiKey();
  const cleanAppId = oneSignalService.getSanitizedAppId();

  let gatewayStatus = 'UNCONFIGURED';
  let gatewayStatusCode = 0;
  let gatewayResponse: any = null;

  if (cleanAppId && cleanKey) {
    try {
      const checkRes = await fetch(`https://api.onesignal.com/apps/${cleanAppId}`, {
        headers: {
          Authorization: `Key ${cleanKey}`,
        },
        signal: AbortSignal.timeout(5000),
      });
      gatewayStatusCode = checkRes.status;
      const data = await checkRes.json();
      if (checkRes.ok && data.name) {
        gatewayStatus = 'CONNECTED_OK';
        gatewayResponse = { appName: data.name, playersCount: data.players };
      } else {
        // Fallback test with Basic auth header
        const basicRes = await fetch(`https://api.onesignal.com/apps/${cleanAppId}`, {
          headers: {
            Authorization: `Basic ${cleanKey}`,
          },
          signal: AbortSignal.timeout(5000),
        });
        if (basicRes.ok) {
          const basicData = await basicRes.json();
          gatewayStatus = 'CONNECTED_VIA_BASIC';
          gatewayStatusCode = basicRes.status;
          gatewayResponse = { appName: basicData.name, playersCount: basicData.players };
        } else {
          gatewayStatus = `GATEWAY_REJECTED_HTTP_${gatewayStatusCode}`;
          gatewayResponse = data;
        }
      }
    } catch (err: any) {
      gatewayStatus = `GATEWAY_FETCH_ERROR: ${err?.message}`;
    }
  }

  sendSuccess(res, {
    environment: process.env.NODE_ENV || 'development',
    isVercel: Boolean(process.env.VERCEL || process.env.NOW_REGION),
    isPreview: oneSignalService.isPreviewEnvironment(),
    appIdConfigured: Boolean(cleanAppId),
    appIdMasked: cleanAppId ? `${cleanAppId.slice(0, 8)}...${cleanAppId.slice(-4)}` : 'MISSING',
    apiKeyConfigured: Boolean(cleanKey),
    apiKeyLength: cleanKey.length,
    apiKeyPrefix: cleanKey ? cleanKey.slice(0, 12) : 'NONE',
    apiKeySuffix: cleanKey ? cleanKey.slice(-4) : 'NONE',
    rawKeyHadQuotes: rawKey.startsWith('"') || rawKey.startsWith("'"),
    rawKeyHadAuthPrefix: rawKey.startsWith('Key ') || rawKey.startsWith('Basic ') || rawKey.startsWith('Bearer '),
    gatewayStatus,
    gatewayStatusCode,
    gatewayResponse,
    guidance: gatewayStatus === 'CONNECTED_OK' || gatewayStatus === 'CONNECTED_VIA_BASIC'
      ? 'OneSignal REST API authentication is healthy and active.'
      : 'OneSignal rejected credentials. Verify ONESIGNAL_REST_API_KEY in Vercel project settings matches backend/.env without surrounding quotes.',
  }, HttpStatus.OK);
});

export const notificationsRoutes = router;
