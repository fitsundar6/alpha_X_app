/**
 * Alpha X Notification Policy & Dispatch Service
 *
 * Centralized authority for all push and in-app notifications.
 * Enforces:
 *   1. Persistent Atomic Deduplication via Postgres UNIQUE constraint on dedupKey
 *   2. Two-tier notification priority (ESSENTIAL vs PROACTIVE)
 *   3. Rolling 24-hour limit (Max 2 proactive push notifications per client)
 *   4. Timezone-aware quiet hours (9:00 PM - 7:00 AM local time)
 *   5. Safe deferral for essential plan updates during quiet hours
 *   6. Master opt-out and granular category preference enforcement
 *   7. Deterministic state tracking (PENDING, SENT, FAILED, SUPPRESSED_QUIET_HOURS, DEFERRED, SKIPPED_CAP)
 */

import { prisma } from '../../config/prisma';
import { oneSignalService } from './onesignal.service';
import { Prisma } from '@prisma/client';

export type NotificationTier = 'ESSENTIAL' | 'PROACTIVE';

export type NotificationDeliveryStatus =
  | 'SENT'
  | 'DUPLICATE'
  | 'SUPPRESSED_QUIET_HOURS'
  | 'DEFERRED'
  | 'SKIPPED_CAP'
  | 'OPTED_OUT'
  | 'NO_DEVICE'
  | 'FAILED'
  | 'RECOVERING'
  | 'FAILED_AMBIGUOUS';

export interface DispatchNotificationParams {
  userId: string;
  clientProfileId: string;
  clientId?: string | null;
  title: string;
  message: string;
  type: 'WORKOUT' | 'NUTRITION' | 'CHECK_IN' | 'ACTIVITY' | 'MEMBERSHIP' | 'SYSTEM';
  category?: string;
  priority?: 'LOW' | 'NORMAL' | 'HIGH' | 'URGENT';
  source?: 'AUTOMATION_RULE' | 'AI_COACH' | 'ADMIN' | 'SYSTEM';
  triggerRule?: string;
  tier: NotificationTier;
  preferenceKey?:
    | 'workoutReminders'
    | 'nutritionReminders'
    | 'weeklyCheckInReminders'
    | 'activityReminders'
    | 'membershipAlerts'
    | 'aiEngagementEnabled';
  dedupKey: string;
  data?: Record<string, string>;
  metadata?: Record<string, any>;
  skipPush?: boolean;
  ignoreQuietHours?: boolean;
  ignoreRateLimit?: boolean;
}

export interface DispatchResult {
  success: boolean;
  status: NotificationDeliveryStatus;
  notificationId?: string;
  error?: string;
  scheduledFor?: Date;
}

export class NotificationPolicyService {
  /**
   * Parse local date/time parts in a target IANA timezone (default Asia/Kolkata).
   */
  getLocalTimeParts(timezone: string = 'Asia/Kolkata', date: Date = new Date()): {
    year: number;
    month: number;
    day: number;
    hour: number;
    minute: number;
    dateStr: string; // YYYY-MM-DD
    weekday: string; // e.g. "Monday"
  } {
    const tz = timezone || 'Asia/Kolkata';
    try {
      const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: tz,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        weekday: 'long',
      });

      const parts = formatter.formatToParts(date);
      const getPart = (type: string) => parts.find((p) => p.type === type)?.value || '';

      const year = parseInt(getPart('year'), 10);
      const month = parseInt(getPart('month'), 10);
      const day = parseInt(getPart('day'), 10);
      const hour = parseInt(getPart('hour'), 10) % 24; // Handle 24:00 edge case in some locales
      const minute = parseInt(getPart('minute'), 10);
      const weekday = getPart('weekday');

      const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

      return { year, month, day, hour, minute, dateStr, weekday };
    } catch {
      // Fallback to UTC if timezone is invalid
      const year = date.getUTCFullYear();
      const month = date.getUTCMonth() + 1;
      const day = date.getUTCDate();
      const hour = date.getUTCHours();
      const minute = date.getUTCMinutes();
      const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      const weekday = weekdays[date.getUTCDay()];
      const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      return { year, month, day, hour, minute, dateStr, weekday };
    }
  }

  /**
   * Get exact UTC Date boundaries for a local day (00:00:00.000 to 23:59:59.999)
   * in the specified IANA timezone (default Asia/Kolkata).
   */
  getDayBoundaries(dateStr: string, timezone: string = 'Asia/Kolkata'): { start: Date; end: Date } {
    const tz = timezone || 'Asia/Kolkata';
    if (tz === 'Asia/Kolkata' || tz === 'IST') {
      return {
        start: new Date(`${dateStr}T00:00:00.000+05:30`),
        end: new Date(`${dateStr}T23:59:59.999+05:30`),
      };
    }
    try {
      const tempDate = new Date(`${dateStr}T12:00:00Z`);
      const invDate = new Date(tempDate.toLocaleString('en-US', { timeZone: tz }));
      const diff = tempDate.getTime() - invDate.getTime();
      const start = new Date(new Date(`${dateStr}T00:00:00.000Z`).getTime() + diff);
      const end = new Date(new Date(`${dateStr}T23:59:59.999Z`).getTime() + diff);
      return { start, end };
    } catch {
      return {
        start: new Date(`${dateStr}T00:00:00.000+05:30`),
        end: new Date(`${dateStr}T23:59:59.999+05:30`),
      };
    }
  }

  /**
   * Check if current time falls within quiet hours (default 9 PM to 7 AM local).
   * quietStart: 21, quietEnd: 7 crosses midnight.
   */
  isInQuietHours(
    timezone: string = 'Asia/Kolkata',
    quietStart: number = 21,
    quietEnd: number = 7,
    date: Date = new Date()
  ): boolean {
    const { hour } = this.getLocalTimeParts(timezone, date);
    if (quietStart > quietEnd) {
      // Crosses midnight, e.g. 21:00 to 07:00
      return hour >= quietStart || hour < quietEnd;
    }
    return hour >= quietStart && hour < quietEnd;
  }

  /**
   * Calculate next permitted delivery time (7:00 AM local time).
   */
  getNextPermittedDeliveryTime(
    timezone: string = 'Asia/Kolkata',
    quietEnd: number = 7,
    date: Date = new Date()
  ): Date {
    const local = this.getLocalTimeParts(timezone, date);
    // If it's late night (>= 21), permitted time is tomorrow at quietEnd:00
    // If it's early morning (< quietEnd), permitted time is today at quietEnd:00
    const targetDate = new Date(date);
    if (local.hour >= 12) {
      targetDate.setDate(targetDate.getDate() + 1);
    }
    // We approximate the UTC moment corresponding to quietEnd:00 local time
    // For Asia/Kolkata (UTC+5:30), 07:00 local = 01:30 UTC
    // More generally, use offset difference
    const diffHours = 7 - local.hour;
    const diffMs = (diffHours * 60 - local.minute) * 60 * 1000;
    return new Date(date.getTime() + (diffMs > 0 ? diffMs : diffMs + 24 * 60 * 60 * 1000));
  }

  /**
   * Count push notifications delivered to this client in a rolling 24-hour window.
   */
  async getRolling24HourPushCount(clientProfileId: string): Promise<number> {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    return prisma.notification.count({
      where: {
        clientProfileId,
        sentStatus: 'SENT',
        sentAt: { gte: twentyFourHoursAgo },
      },
    });
  }

  /**
   * Central Dispatch Method:
   * Atomically reserves event in DB via unique dedupKey, verifies policy constraints,
   * dispatches push via OneSignal, and records final delivery state.
   */
  async dispatch(params: DispatchNotificationParams): Promise<DispatchResult> {
    const {
      userId,
      clientProfileId,
      clientId,
      title,
      message,
      type,
      category = 'GENERAL',
      priority = 'NORMAL',
      source = 'AUTOMATION_RULE',
      triggerRule,
      tier,
      preferenceKey,
      dedupKey,
      data = {},
      metadata = {},
      skipPush = false,
      ignoreQuietHours = false,
      ignoreRateLimit = false,
    } = params;

    // 1. Check if this dedupKey already exists
    const existing = await prisma.notification.findUnique({
      where: { dedupKey },
    });

    if (existing) {
      if (existing.sentStatus !== 'FAILED') {
        // Already processed (SENT, DEFERRED, SUPPRESSED_QUIET_HOURS, or SKIPPED_CAP)
        return {
          success: false,
          status: 'DUPLICATE',
          notificationId: existing.id,
          error: `Event with dedupKey "${dedupKey}" was already processed with status ${existing.sentStatus}.`,
        };
      }
      // If previously FAILED, we will allow retry by continuing with this reservation
    }

    // 2. Fetch user and preferences
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        clientProfile: {
          include: { notificationPref: true },
        },
      },
    });

    if (!user) {
      return { success: false, status: 'FAILED', error: `User with id "${userId}" not found.` };
    }

    const pref = user.clientProfile?.notificationPref || null;
    const clientTimezone = pref?.timezone || 'Asia/Kolkata';
    const quietStart = pref?.quietHoursStart ?? 21;
    const quietEnd = pref?.quietHoursEnd ?? 7;

    // 3. ATOMIC RESERVATION in DB
    // Reserve the record with 'PENDING' status before touching OneSignal
    let reservationId: string;
    if (existing && existing.sentStatus === 'FAILED') {
      // Retry previously failed reservation
      const updated = await prisma.notification.update({
        where: { id: existing.id },
        data: {
          title,
          message,
          type,
          category,
          priority,
          source,
          triggerRule,
          sentStatus: 'PENDING',
          errorDetails: null,
          metadataJson: JSON.stringify(metadata),
        },
      });
      reservationId = updated.id;
    } else {
      try {
        const created = await prisma.notification.create({
          data: {
            clientProfileId,
            clientId: clientId || user.clientProfile?.clientId || null,
            title,
            message,
            type,
            category,
            priority,
            source,
            triggerRule,
            sentStatus: 'PENDING',
            dedupKey,
            metadataJson: JSON.stringify(metadata),
          },
        });
        reservationId = created.id;
      } catch (err: any) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          // Unique constraint violation on dedupKey: another concurrent request just won the race!
          return {
            success: false,
            status: 'DUPLICATE',
            error: `Atomic race resolved: dedupKey "${dedupKey}" already claimed concurrently.`,
          };
        }
        throw err;
      }
    }

    // 4. POLICY CHECK: Master notification opt-out
    // Neither proactive nor essential push is sent if user disabled master notifications.
    if (!user.notificationsEnabled) {
      await prisma.notification.update({
        where: { id: reservationId },
        data: { sentStatus: 'OPTED_OUT', errorDetails: 'Client disabled master notifications toggle.' },
      });
      return { success: false, status: 'OPTED_OUT', notificationId: reservationId };
    }

    // 5. POLICY CHECK: Category preferences (applies to both tiers if specific key provided)
    if (preferenceKey && pref && pref[preferenceKey] === false) {
      await prisma.notification.update({
        where: { id: reservationId },
        data: { sentStatus: 'OPTED_OUT', errorDetails: `Client opted out of category "${preferenceKey}".` },
      });
      return { success: false, status: 'OPTED_OUT', notificationId: reservationId };
    }

    // 6. POLICY CHECK: Quiet Hours
    const isQuiet = !params.ignoreQuietHours && this.isInQuietHours(clientTimezone, quietStart, quietEnd);
    if (isQuiet) {
      if (tier === 'ESSENTIAL') {
        // Essential event (e.g. plan update assigned late at night):
        // Record immediately in in-app notification center, and DEFER push until next permitted morning time.
        const scheduledFor = this.getNextPermittedDeliveryTime(clientTimezone, quietEnd);
        await prisma.notification.update({
          where: { id: reservationId },
          data: {
            sentStatus: 'DEFERRED',
            scheduledFor,
            errorDetails: `Deferred during quiet hours (${quietStart}:00-${quietEnd}:00 local). Scheduled for ${scheduledFor.toISOString()}`,
          },
        });
        return {
          success: true,
          status: 'DEFERRED',
          notificationId: reservationId,
          scheduledFor,
        };
      } else {
        // Proactive event (morning/missed/evening sweep or late workout celebration):
        // Suppress push alert. For workout celebration, keep visible in in-app notification center.
        await prisma.notification.update({
          where: { id: reservationId },
          data: {
            sentStatus: 'SUPPRESSED_QUIET_HOURS',
            errorDetails: `Suppressed push during client quiet hours (${quietStart}:00-${quietEnd}:00 ${clientTimezone}).`,
          },
        });
        return {
          success: false,
          status: 'SUPPRESSED_QUIET_HOURS',
          notificationId: reservationId,
        };
      }
    }

    // 7. POLICY CHECK: Rolling 24-Hour Push Cap (Max 2 for PROACTIVE tier)
    // Admin test dispatches and explicit ignoreRateLimit bypass the rolling cap
    if (tier === 'PROACTIVE' && !ignoreRateLimit && source !== 'ADMIN') {
      const recentCount = await this.getRolling24HourPushCount(clientProfileId);
      if (recentCount >= 2) {
        await prisma.notification.update({
          where: { id: reservationId },
          data: {
            sentStatus: 'SKIPPED_CAP',
            errorDetails: `Client already received ${recentCount} push notifications in rolling 24h window (limit: 2).`,
          },
        });
        return {
          success: false,
          status: 'SKIPPED_CAP',
          notificationId: reservationId,
        };
      }
    }

    // 8. DEVICE TARGET CHECK: Check if OneSignal player ID exists
    if (skipPush) {
      // In-app notification is recorded as SENT, but push delivery was intentionally skipped
      await prisma.notification.update({
        where: { id: reservationId },
        data: {
          sentStatus: 'SENT',
          sentAt: new Date(),
          errorDetails: 'Push intentionally skipped by request',
        },
      });
      return {
        success: true,
        status: 'SENT',
        notificationId: reservationId,
      };
    }

    // 9. DISPATCH TO ONESIGNAL
    try {
      // Mark provider dispatch stage so crash recovery knows OneSignal call was initiated
      await prisma.notification.update({
        where: { id: reservationId },
        data: {
          metadataJson: JSON.stringify({
            ...metadata,
            dispatchStage: 'CALLING_PROVIDER',
            dispatchStartedAt: new Date().toISOString(),
          }),
        },
      });

      const hasPlayerToken = Boolean(user.oneSignalPlayerId && user.oneSignalPlayerId.trim().length > 0);
      const sendResult = hasPlayerToken
        ? await oneSignalService.sendToPlayer(user.oneSignalPlayerId!, {
            title,
            body: message,
            channelId: 'alpha_x_alerts',
            data: { ...data, notificationId: reservationId, dedupKey, targetUserId: user.id },
          })
        : await oneSignalService.sendToUser(user.id, {
            title,
            body: message,
            channelId: 'alpha_x_alerts',
            data: { ...data, notificationId: reservationId, dedupKey, targetUserId: user.id },
          });

      if (sendResult.success) {
        const oneSignalId = sendResult.response?.id || null;
        await prisma.notification.update({
          where: { id: reservationId },
          data: {
            sentStatus: 'SENT',
            sentAt: new Date(),
            errorDetails: null,
            metadataJson: JSON.stringify({
              ...metadata,
              dispatchStage: 'COMPLETED',
              oneSignalId,
              providerAcceptedAt: new Date().toISOString(),
            }),
          },
        });
        return {
          success: true,
          status: 'SENT',
          notificationId: reservationId,
        };
      } else {
        await prisma.notification.update({
          where: { id: reservationId },
          data: {
            sentStatus: 'FAILED',
            errorDetails: sendResult.error || 'OneSignal rejected push delivery',
            metadataJson: JSON.stringify({
              ...metadata,
              dispatchStage: 'PROVIDER_FAILED',
              failedAt: new Date().toISOString(),
            }),
          },
        });
        return {
          success: false,
          status: 'FAILED',
          notificationId: reservationId,
          error: sendResult.error,
        };
      }
    } catch (err: any) {
      await prisma.notification.update({
        where: { id: reservationId },
        data: {
          sentStatus: 'FAILED',
          errorDetails: err?.message || 'Unexpected exception during OneSignal dispatch',
          metadataJson: JSON.stringify({
            ...metadata,
            dispatchStage: 'EXCEPTION',
            error: err?.message,
          }),
        },
      });
      return {
        success: false,
        status: 'FAILED',
        notificationId: reservationId,
        error: err?.message,
      };
    }
  }

  /**
   * Process deferred notifications whose scheduledFor time has arrived.
   * Concurrency-safe: atomically claims notifications from DEFERRED to PENDING.
   * Re-verifies quiet hours, opt-outs, and category preferences before OneSignal dispatch.
   */
  async processDeferredQueue(): Promise<{ processed: number; sent: number }> {
    const now = new Date();
    const deferredList = await prisma.notification.findMany({
      where: {
        sentStatus: 'DEFERRED',
        scheduledFor: { lte: now },
      },
      include: {
        clientProfile: {
          include: {
            user: true,
            notificationPref: true,
          },
        },
      },
      take: 50,
    });

    let sent = 0;
    for (const notif of deferredList) {
      // 1. Atomic claim: transition DEFERRED -> PENDING so no other concurrent worker processes it
      const claimed = await prisma.notification.updateMany({
        where: { id: notif.id, sentStatus: 'DEFERRED' },
        data: { sentStatus: 'PENDING' },
      });
      if (claimed.count === 0) {
        continue;
      }

      const user = notif.clientProfile?.user;
      if (!user || !user.notificationsEnabled || !user.oneSignalPlayerId) {
        await prisma.notification.update({
          where: { id: notif.id },
          data: {
            sentStatus: 'OPTED_OUT',
            errorDetails: !user
              ? 'User profile not found'
              : !user.notificationsEnabled
              ? 'Client disabled master notifications toggle.'
              : 'No OneSignal player ID registered on client account',
          },
        });
        continue;
      }

      // Check category preferences
      const pref = notif.clientProfile.notificationPref;
      if (pref) {
        if (notif.type === 'WORKOUT' && pref.workoutReminders === false) {
          await prisma.notification.update({
            where: { id: notif.id },
            data: { sentStatus: 'OPTED_OUT', errorDetails: 'Client opted out of workoutReminders' },
          });
          continue;
        }
        if (notif.type === 'NUTRITION' && pref.nutritionReminders === false) {
          await prisma.notification.update({
            where: { id: notif.id },
            data: { sentStatus: 'OPTED_OUT', errorDetails: 'Client opted out of nutritionReminders' },
          });
          continue;
        }
      }

      // Check quiet hours again at current execution time
      const tz = pref?.timezone || 'Asia/Kolkata';
      const quietStart = pref?.quietHoursStart ?? 21;
      const quietEnd = pref?.quietHoursEnd ?? 7;

      if (this.isInQuietHours(tz, quietStart, quietEnd, now)) {
        // Still in quiet hours, put back to DEFERRED until next morning
        const nextTime = this.getNextPermittedDeliveryTime(tz, quietEnd, now);
        await prisma.notification.update({
          where: { id: notif.id },
          data: { sentStatus: 'DEFERRED', scheduledFor: nextTime },
        });
        continue;
      }

      // Mark stage before dispatching
      await prisma.notification.update({
        where: { id: notif.id },
        data: {
          metadataJson: JSON.stringify({
            dispatchStage: 'CALLING_PROVIDER',
            dispatchStartedAt: new Date().toISOString(),
          }),
        },
      });

      // Dispatch to OneSignal
      try {
        const hasPlayerToken = Boolean(user.oneSignalPlayerId && user.oneSignalPlayerId.trim().length > 0);
        const sendResult = hasPlayerToken
          ? await oneSignalService.sendToPlayer(user.oneSignalPlayerId!, {
              title: notif.title,
              body: notif.message,
              channelId: 'alpha_x_alerts',
              data: { notificationId: notif.id, dedupKey: notif.dedupKey || '', targetUserId: user.id },
            })
          : await oneSignalService.sendToUser(user.id, {
              title: notif.title,
              body: notif.message,
              channelId: 'alpha_x_alerts',
              data: { notificationId: notif.id, dedupKey: notif.dedupKey || '', targetUserId: user.id },
            });

        if (sendResult.success) {
          await prisma.notification.update({
            where: { id: notif.id },
            data: {
              sentStatus: 'SENT',
              sentAt: new Date(),
              scheduledFor: null,
              errorDetails: null,
              metadataJson: JSON.stringify({
                dispatchStage: 'COMPLETED',
                oneSignalId: sendResult.response?.id || null,
                deliveredFromDeferred: true,
              }),
            },
          });
          sent++;
        } else {
          await prisma.notification.update({
            where: { id: notif.id },
            data: {
              sentStatus: 'FAILED',
              errorDetails: sendResult.error || 'OneSignal rejected push delivery',
            },
          });
        }
      } catch (err: any) {
        await prisma.notification.update({
          where: { id: notif.id },
          data: {
            sentStatus: 'FAILED',
            errorDetails: err?.message || 'Unexpected exception during deferred push',
          },
        });
      }
    }

    return { processed: deferredList.length, sent };
  }

  /**
   * Recovers notifications that have been stuck in 'PENDING' for more than olderThanMs (default 5 minutes).
   * Prevents permanently locked events while protecting against duplicate sends:
   *   1. Atomically claims the record via PENDING -> RECOVERING transition.
   *   2. Inspects OneSignal provider evidence to reconcile pushes accepted by OneSignal.
   *   3. Retries only when proven safe (OneSignal never received/accepted the push).
   *   4. Marks ambiguous states as FAILED_AMBIGUOUS with structured diagnostic logs.
   */
  async recoverStalePendingNotifications(olderThanMs: number = 5 * 60 * 1000): Promise<{
    scanned: number;
    claimed: number;
    reconciledSent: number;
    retriedSent: number;
    markedFailed: number;
    ambiguous: number;
  }> {
    const threshold = new Date(Date.now() - olderThanMs);
    const staleList = await prisma.notification.findMany({
      where: {
        sentStatus: 'PENDING',
        updatedAt: { lte: threshold },
      },
      include: {
        clientProfile: {
          include: {
            user: true,
          },
        },
      },
      take: 50,
    });

    let claimed = 0;
    let reconciledSent = 0;
    let retriedSent = 0;
    let markedFailed = 0;
    let ambiguous = 0;

    for (const notif of staleList) {
      // 1. Concurrency-safe atomic claim
      const claimResult = await prisma.notification.updateMany({
        where: { id: notif.id, sentStatus: 'PENDING' },
        data: { sentStatus: 'RECOVERING' },
      });

      if (claimResult.count === 0) {
        // Another recovery worker claimed it concurrently
        continue;
      }
      claimed++;

      // 2. Parse metadata
      let meta: Record<string, any> = {};
      try {
        if (notif.metadataJson) {
          meta = JSON.parse(notif.metadataJson);
        }
      } catch (_) {}

      const user = notif.clientProfile?.user;
      const oneSignalId = meta.oneSignalId;
      const dispatchStage = meta.dispatchStage;

      // 3. Provider reconciliation: Check if OneSignal already accepted it
      let wasAcceptedByProvider = false;
      let verifiedOneSignalId = oneSignalId;

      if (oneSignalId) {
        // Check specific OneSignal notification
        const providerCheck = await oneSignalService.getNotification(oneSignalId);
        if (providerCheck.success) {
          wasAcceptedByProvider = true;
        }
      } else if (dispatchStage === 'CALLING_PROVIDER' && notif.dedupKey) {
        // We started calling OneSignal before crashing. Check recent notifications
        const findResult = await oneSignalService.findNotificationByDedupKey(notif.dedupKey);
        if (findResult.found) {
          wasAcceptedByProvider = true;
          verifiedOneSignalId = findResult.notification?.id;
        }
      }

      if (wasAcceptedByProvider) {
        // Provider accepted the push! Reconcile to SENT without duplicate dispatch
        await prisma.notification.update({
          where: { id: notif.id },
          data: {
            sentStatus: 'SENT',
            sentAt: new Date(),
            errorDetails: 'Reconciled: Confirmed accepted by OneSignal provider API',
            metadataJson: JSON.stringify({
              ...meta,
              dispatchStage: 'COMPLETED',
              reconciled: true,
              oneSignalId: verifiedOneSignalId,
            }),
          },
        });
        reconciledSent++;
        console.log(`[STALE_RECOVERY] Reconciled stale notification ${notif.id} to SENT (OneSignal accepted)`);
        continue;
      }

      // If dispatchStage was CALLING_PROVIDER, but OneSignal check was inconclusive or failed
      if (dispatchStage === 'CALLING_PROVIDER') {
        // Provider state ambiguous: mark FAILED_AMBIGUOUS to prevent duplicate push alerts
        await prisma.notification.update({
          where: { id: notif.id },
          data: {
            sentStatus: 'FAILED_AMBIGUOUS',
            errorDetails: 'Stale recovery: Provider dispatch state ambiguous. Marked to prevent duplicate push.',
            metadataJson: JSON.stringify({
              ...meta,
              dispatchStage: 'AMBIGUOUS_RECOVERY',
            }),
          },
        });
        ambiguous++;
        console.warn(`[STALE_RECOVERY] Ambiguous provider state for notification ${notif.id}; marked FAILED_AMBIGUOUS`);
        continue;
      }

      // If dispatchStage was NOT 'CALLING_PROVIDER', the crash occurred before network call.
      // OneSignal was never called. Mark as FAILED so that the dedupKey is cleanly unlocked for retry.
      await prisma.notification.update({
        where: { id: notif.id },
        data: {
          sentStatus: 'FAILED',
          errorDetails: 'Stale reservation recovered: Server crashed before provider call was made.',
          metadataJson: JSON.stringify({
            ...meta,
            dispatchStage: 'RECOVERED_BEFORE_DISPATCH',
            recoveredAt: new Date().toISOString(),
          }),
        },
      });
      markedFailed++;
      console.log(`[STALE_RECOVERY] Stale reservation ${notif.id} marked FAILED (pre-dispatch crash recovered)`);
    }

    return {
      scanned: staleList.length,
      claimed,
      reconciledSent,
      retriedSent,
      markedFailed,
      ambiguous,
    };
  }
}

export const notificationPolicyService = new NotificationPolicyService();
