import { Request, Response } from 'express';
import { prisma } from '../../config/prisma';
import { automationService } from './automation.service';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';
import { UserRole } from '../../constants/roles';

export class AutomationController {
  /**
   * Run daily automation cycle (Admin or Cron trigger)
   * POST /api/v1/automation/run-daily-check
   */
  public async runDailyCheck(req: Request, res: Response): Promise<void> {
    try {
      const specificClientId = req.body?.clientId ? String(req.body.clientId) : undefined;
      const result = await automationService.runDailyAutomationCycle(specificClientId);
      sendSuccess(res, result, HttpStatus.OK);
    } catch (err: any) {
      console.error('[AUTOMATION CONTROLLER ERROR]', err);
      sendError(res, 'INTERNAL_ERROR', 'Failed to run daily automation cycle', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Client heart-beat ping to record app activity
   * POST /api/v1/client/me/activity-ping
   */
  public async pingActivity(req: Request, res: Response): Promise<void> {
    try {
      if (req.user?.role === UserRole.ADMIN) {
        sendSuccess(res, { success: true, lastAppOpenAt: new Date() });
        return;
      }
      const userId = req.user!.id;
      const updated = await prisma.clientProfile.update({
        where: { userId },
        data: { lastAppOpenAt: new Date() },
        select: { id: true, clientId: true, lastAppOpenAt: true },
      });
      sendSuccess(res, { success: true, lastAppOpenAt: updated.lastAppOpenAt });
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to update activity heartbeat', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Get notifications for authenticated client
   * GET /api/v1/client/me/notifications
   */
  public async getClientNotifications(req: Request, res: Response): Promise<void> {
    try {
      if (req.user?.role === UserRole.ADMIN) {
        sendSuccess(res, {
          notifications: [],
          unreadCount: 0,
          total: 0,
        });
        return;
      }

      const userId = req.user!.id;
      const profile = await prisma.clientProfile.findUnique({
        where: { userId },
        select: { id: true },
      });

      if (!profile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const notifications = await prisma.notification.findMany({
        where: { clientProfileId: profile.id },
        orderBy: { createdAt: 'desc' },
        take: 50,
      });

      const unreadCount = notifications.filter((n) => !n.isRead).length;

      sendSuccess(res, {
        notifications,
        unreadCount,
        total: notifications.length,
      });
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to fetch notifications', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Mark single notification as read
   * PUT /api/v1/client/me/notifications/:id/read
   */
  public async markNotificationRead(req: Request, res: Response): Promise<void> {
    try {
      if (req.user?.role === UserRole.ADMIN) {
        sendSuccess(res, { success: true });
        return;
      }

      const userId = req.user!.id;
      const notifId = String(req.params.id);

      const profile = await prisma.clientProfile.findUnique({
        where: { userId },
        select: { id: true },
      });

      if (!profile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const notif = await prisma.notification.findFirst({
        where: { id: notifId, clientProfileId: profile.id },
      });

      if (!notif) {
        sendError(res, 'NOT_FOUND', 'Notification not found', HttpStatus.NOT_FOUND);
        return;
      }

      const updated = await prisma.notification.update({
        where: { id: notifId },
        data: { isRead: true, readAt: new Date() },
      });

      sendSuccess(res, updated);
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to mark notification read', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Mark all notifications as read for client
   * PUT /api/v1/client/me/notifications/read-all
   */
  public async markAllNotificationsRead(req: Request, res: Response): Promise<void> {
    try {
      if (req.user?.role === UserRole.ADMIN) {
        sendSuccess(res, { markedAllRead: true });
        return;
      }

      const userId = req.user!.id;
      const profile = await prisma.clientProfile.findUnique({
        where: { userId },
        select: { id: true },
      });

      if (!profile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      await prisma.notification.updateMany({
        where: { clientProfileId: profile.id, isRead: false },
        data: { isRead: true, readAt: new Date() },
      });

      sendSuccess(res, { markedAllRead: true });
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to mark all notifications read', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Get notification preferences for client
   * GET /api/v1/client/me/notification-preferences
   */
  public async getNotificationPreferences(req: Request, res: Response): Promise<void> {
    try {
      if (req.user?.role === UserRole.ADMIN) {
        sendSuccess(res, {
          workoutReminders: false,
          nutritionReminders: false,
          weeklyCheckInReminders: false,
          activityReminders: false,
          membershipAlerts: false,
          aiEngagementEnabled: false,
        });
        return;
      }

      const userId = req.user!.id;
      const profile = await prisma.clientProfile.findUnique({
        where: { userId },
        include: { notificationPref: true },
      });

      if (!profile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const prefs = profile.notificationPref || {
        workoutReminders: true,
        nutritionReminders: true,
        weeklyCheckInReminders: true,
        activityReminders: true,
        membershipAlerts: true,
        aiEngagementEnabled: profile.aiEngagementEnabled ?? true,
      };

      sendSuccess(res, prefs);
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to fetch preferences', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Update notification preferences for client
   * PUT /api/v1/client/me/notification-preferences
   */
  public async updateNotificationPreferences(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.user!.id;
      const profile = await prisma.clientProfile.findUnique({
        where: { userId },
      });

      if (!profile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const {
        workoutReminders,
        nutritionReminders,
        weeklyCheckInReminders,
        activityReminders,
        membershipAlerts,
        aiEngagementEnabled,
      } = req.body;

      const updated = await prisma.notificationPreference.upsert({
        where: { clientProfileId: profile.id },
        create: {
          clientProfileId: profile.id,
          workoutReminders: workoutReminders ?? true,
          nutritionReminders: nutritionReminders ?? true,
          weeklyCheckInReminders: weeklyCheckInReminders ?? true,
          activityReminders: activityReminders ?? true,
          membershipAlerts: membershipAlerts ?? true,
          aiEngagementEnabled: aiEngagementEnabled ?? true,
        },
        update: {
          workoutReminders: workoutReminders !== undefined ? Boolean(workoutReminders) : undefined,
          nutritionReminders: nutritionReminders !== undefined ? Boolean(nutritionReminders) : undefined,
          weeklyCheckInReminders: weeklyCheckInReminders !== undefined ? Boolean(weeklyCheckInReminders) : undefined,
          activityReminders: activityReminders !== undefined ? Boolean(activityReminders) : undefined,
          membershipAlerts: membershipAlerts !== undefined ? Boolean(membershipAlerts) : undefined,
          aiEngagementEnabled: aiEngagementEnabled !== undefined ? Boolean(aiEngagementEnabled) : undefined,
        },
      });

      // Synchronize flag on profile as well
      if (aiEngagementEnabled !== undefined) {
        await prisma.clientProfile.update({
          where: { id: profile.id },
          data: { aiEngagementEnabled: Boolean(aiEngagementEnabled) },
        });
      }

      sendSuccess(res, updated);
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to update preferences', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Admin Attention Center query
   * GET /api/v1/admin/attention-center
   */
  public async getAdminAttentionCenter(req: Request, res: Response): Promise<void> {
    try {
      const filterType = req.query.type ? String(req.query.type).trim() : undefined;
      const severity = req.query.severity ? String(req.query.severity).trim() : undefined;
      const isReviewedStr = req.query.isReviewed ? String(req.query.isReviewed).trim() : undefined;
      const search = req.query.search ? String(req.query.search).trim().toLowerCase() : undefined;

      const whereClause: any = {};
      if (filterType && filterType !== 'ALL') {
        whereClause.attentionType = filterType;
      }
      if (severity && severity !== 'ALL') {
        whereClause.severity = severity;
      }
      if (isReviewedStr !== undefined && isReviewedStr !== 'ALL') {
        whereClause.isReviewed = isReviewedStr === 'true';
      }
      if (search) {
        whereClause.OR = [
          { clientName: { contains: search, mode: 'insensitive' } },
          { clientId: { contains: search, mode: 'insensitive' } },
          { title: { contains: search, mode: 'insensitive' } },
        ];
      }

      const items = await prisma.adminAttentionItem.findMany({
        where: whereClause,
        orderBy: [{ isReviewed: 'asc' }, { createdAt: 'desc' }],
        take: 100,
      });

      // Summary counts by category
      const counts = {
        total: items.length,
        unreviewed: items.filter((i) => !i.isReviewed).length,
        critical: items.filter((i) => i.severity === 'CRITICAL' && !i.isReviewed).length,
        pain: items.filter((i) => i.attentionType === 'PAIN_REPORTED' && !i.isReviewed).length,
        inactive: items.filter((i) => i.attentionType === 'INACTIVE' && !i.isReviewed).length,
        missedWorkouts: items.filter((i) => i.attentionType === 'MISSED_WORKOUT' && !i.isReviewed).length,
        missingCheckIns: items.filter((i) => i.attentionType === 'MISSING_CHECKIN' && !i.isReviewed).length,
        expiringMembership: items.filter((i) => i.attentionType === 'MEMBERSHIP_EXPIRING' && !i.isReviewed).length,
      };

      sendSuccess(res, {
        items,
        counts,
      });
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve attention items', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Admin marks attention item as reviewed + optional coach note
   * POST /api/v1/admin/attention-items/:id/review
   */
  public async reviewAttentionItem(req: Request, res: Response): Promise<void> {
    try {
      const itemId = String(req.params.id);
      const { coachNotes } = req.body;

      const existing = await prisma.adminAttentionItem.findUnique({
        where: { id: itemId },
      });

      if (!existing) {
        sendError(res, 'NOT_FOUND', 'Attention item not found', HttpStatus.NOT_FOUND);
        return;
      }

      const updated = await prisma.adminAttentionItem.update({
        where: { id: itemId },
        data: {
          isReviewed: true,
          reviewedById: req.user!.id,
          reviewedAt: new Date(),
          coachNotes: coachNotes ? String(coachNotes).trim() : existing.coachNotes,
        },
      });

      sendSuccess(res, updated);
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to review attention item', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Automatic weekly progress report for Admin
   * GET /api/v1/admin/clients/:id/weekly-report
   */
  public async getWeeklyReport(req: Request, res: Response): Promise<void> {
    try {
      const idOrClientId = String(req.params.id);
      const report = await automationService.generateFactualWeeklyReport(idOrClientId);
      sendSuccess(res, report);
    } catch (err: any) {
      sendError(res, 'NOT_FOUND', err.message || 'Failed to generate weekly report', HttpStatus.NOT_FOUND);
    }
  }

  /**
   * Get transformation timeline for athlete
   * GET /api/v1/client/me/transformation-timeline (Client)
   * GET /api/v1/admin/clients/:id/transformation-timeline (Admin)
   */
  public async getTransformationTimeline(req: Request, res: Response): Promise<void> {
    try {
      let clientProfileId: string | undefined;

      if (req.params.id) {
        // Admin viewing specific client
        const clean = String(req.params.id).trim();
        let profile = await prisma.clientProfile.findFirst({
          where: {
            OR: [
              { id: clean },
              { clientId: clean.toUpperCase() },
              { userId: clean },
            ],
          },
        });

        if (!profile) {
          const user = await prisma.user.findFirst({
            where: {
              OR: [
                { id: clean },
                { email: clean.toLowerCase() },
              ],
            },
            include: { clientProfile: true },
          });
          profile = user?.clientProfile ?? null;
        }

        clientProfileId = profile?.id;
      } else {
        // Client viewing their own
        const profile = await prisma.clientProfile.findUnique({
          where: { userId: req.user!.id },
        });
        clientProfileId = profile?.id;
      }

      if (!clientProfileId) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const milestones = await prisma.transformationMilestone.findMany({
        where: { clientProfileId },
        orderBy: { weekNumber: 'asc' },
      });

      // Format output with clean streaming photo URLs
      const formatted = milestones.map((m) => ({
        id: m.id,
        clientProfileId: m.clientProfileId,
        clientId: m.clientId,
        weekNumber: m.weekNumber,
        date: m.date instanceof Date ? m.date.toISOString() : m.date,
        frontPhotoUrl: m.frontPhotoUrl ? `/api/v1/transformation-photos/${m.id}/front` : null,
        sidePhotoUrl: m.sidePhotoUrl ? `/api/v1/transformation-photos/${m.id}/side` : null,
        backPhotoUrl: m.backPhotoUrl ? `/api/v1/transformation-photos/${m.id}/back` : null,
        hasFrontPhoto: Boolean(m.frontPhotoUrl),
        hasSidePhoto: Boolean(m.sidePhotoUrl),
        hasBackPhoto: Boolean(m.backPhotoUrl),
        weightKg: m.weightKg !== null && m.weightKg !== undefined ? Number(m.weightKg) : null,
        waistCm: m.waistCm !== null && m.waistCm !== undefined ? Number(m.waistCm) : null,
        notes: m.notes || null,
        createdAt: m.createdAt instanceof Date ? m.createdAt.toISOString() : m.createdAt,
        updatedAt: m.updatedAt instanceof Date ? m.updatedAt.toISOString() : m.updatedAt,
      }));

      sendSuccess(res, formatted);
    } catch (err: any) {
      console.error('[GET TRANSFORMATION TIMELINE ERROR]', err);
      sendError(res, 'INTERNAL_ERROR', 'Failed to fetch transformation timeline', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Save or update transformation milestone (Weeks 1, 4, 8, 12)
   * POST /api/v1/client/me/transformation-timeline (Client)
   * POST /api/v1/admin/clients/:id/transformation-timeline (Admin)
   */
  public async saveTransformationMilestone(req: Request, res: Response): Promise<void> {
    try {
      let clientProfile: any = null;

      if (req.params.id) {
        // Admin logging for client
        const clean = String(req.params.id).trim();
        clientProfile = await prisma.clientProfile.findFirst({
          where: {
            OR: [
              { id: clean },
              { clientId: clean.toUpperCase() },
              { userId: clean },
            ],
          },
        });
        if (!clientProfile) {
          const user = await prisma.user.findFirst({
            where: {
              OR: [
                { id: clean },
                { email: clean.toLowerCase() },
              ],
            },
            include: { clientProfile: true },
          });
          clientProfile = user?.clientProfile ?? null;
        }
      } else {
        // Client self-service
        const userId = req.user!.id;
        clientProfile = await prisma.clientProfile.findUnique({
          where: { userId },
        });
      }

      if (!clientProfile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const { weekNumber, frontPhotoUrl, sidePhotoUrl, backPhotoUrl, weightKg, waistCm, notes, date } = req.body;

      if (weekNumber === undefined || weekNumber === null || isNaN(Number(weekNumber))) {
        sendError(res, 'VALIDATION_ERROR', 'Valid week number (e.g. 1, 4, 8, 12) is required', HttpStatus.BAD_REQUEST);
        return;
      }

      const weekNum = Number(weekNumber);
      const existing = await prisma.transformationMilestone.findUnique({
        where: {
          client_milestone_week_unique: {
            clientProfileId: clientProfile.id,
            weekNumber: weekNum,
          },
        },
      });

      const milestoneDate = date ? new Date(date) : (existing?.date || new Date());

      // Helper to process photo values (preserving existing if undefined/empty)
      const resolvePhoto = (newVal: any, existingVal?: string | null) => {
        if (newVal === undefined) return existingVal || null;
        if (newVal === null || newVal === '') return null; // explicit clear
        return String(newVal);
      };

      const milestone = await prisma.transformationMilestone.upsert({
        where: {
          client_milestone_week_unique: {
            clientProfileId: clientProfile.id,
            weekNumber: weekNum,
          },
        },
        create: {
          clientProfileId: clientProfile.id,
          clientId: clientProfile.clientId,
          weekNumber: weekNum,
          date: milestoneDate,
          frontPhotoUrl: resolvePhoto(frontPhotoUrl),
          sidePhotoUrl: resolvePhoto(sidePhotoUrl),
          backPhotoUrl: resolvePhoto(backPhotoUrl),
          weightKg: weightKg !== undefined && weightKg !== null && weightKg !== '' ? Number(weightKg) : null,
          waistCm: waistCm !== undefined && waistCm !== null && waistCm !== '' ? Number(waistCm) : null,
          notes: notes !== undefined && notes !== null ? String(notes).trim() : null,
        },
        update: {
          date: date ? milestoneDate : undefined,
          frontPhotoUrl: frontPhotoUrl !== undefined ? resolvePhoto(frontPhotoUrl, existing?.frontPhotoUrl) : undefined,
          sidePhotoUrl: sidePhotoUrl !== undefined ? resolvePhoto(sidePhotoUrl, existing?.sidePhotoUrl) : undefined,
          backPhotoUrl: backPhotoUrl !== undefined ? resolvePhoto(backPhotoUrl, existing?.backPhotoUrl) : undefined,
          weightKg: weightKg !== undefined && weightKg !== null && weightKg !== '' ? Number(weightKg) : undefined,
          waistCm: waistCm !== undefined && waistCm !== null && waistCm !== '' ? Number(waistCm) : undefined,
          notes: notes !== undefined ? (notes ? String(notes).trim() : null) : undefined,
        },
      });

      const formatted = {
        id: milestone.id,
        clientProfileId: milestone.clientProfileId,
        clientId: milestone.clientId,
        weekNumber: milestone.weekNumber,
        date: milestone.date instanceof Date ? milestone.date.toISOString() : milestone.date,
        frontPhotoUrl: milestone.frontPhotoUrl ? `/api/v1/transformation-photos/${milestone.id}/front` : null,
        sidePhotoUrl: milestone.sidePhotoUrl ? `/api/v1/transformation-photos/${milestone.id}/side` : null,
        backPhotoUrl: milestone.backPhotoUrl ? `/api/v1/transformation-photos/${milestone.id}/back` : null,
        hasFrontPhoto: Boolean(milestone.frontPhotoUrl),
        hasSidePhoto: Boolean(milestone.sidePhotoUrl),
        hasBackPhoto: Boolean(milestone.backPhotoUrl),
        weightKg: milestone.weightKg !== null && milestone.weightKg !== undefined ? Number(milestone.weightKg) : null,
        waistCm: milestone.waistCm !== null && milestone.waistCm !== undefined ? Number(milestone.waistCm) : null,
        notes: milestone.notes || null,
        createdAt: milestone.createdAt instanceof Date ? milestone.createdAt.toISOString() : milestone.createdAt,
        updatedAt: milestone.updatedAt instanceof Date ? milestone.updatedAt.toISOString() : milestone.updatedAt,
      };

      sendSuccess(res, formatted, HttpStatus.CREATED);
    } catch (err: any) {
      console.error('[SAVE TRANSFORMATION MILESTONE ERROR]', err);
      sendError(res, 'INTERNAL_ERROR', 'Failed to save transformation milestone', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}

export const automationController = new AutomationController();
