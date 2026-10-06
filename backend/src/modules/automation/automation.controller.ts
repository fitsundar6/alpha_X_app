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
        const user = await prisma.user.findFirst({
          where: {
            OR: [
              { id: clean },
              { clientProfile: { clientId: clean.toUpperCase() } },
              { clientProfile: { id: clean } },
            ],
          },
          include: { clientProfile: true },
        });
        clientProfileId = user?.clientProfile?.id;
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

      sendSuccess(res, milestones);
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to fetch transformation timeline', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Save or update transformation milestone (Weeks 1, 4, 8, 12)
   * POST /api/v1/client/me/transformation-timeline
   */
  public async saveTransformationMilestone(req: Request, res: Response): Promise<void> {
    try {
      const userId = req.user!.id;
      const profile = await prisma.clientProfile.findUnique({
        where: { userId },
      });

      if (!profile) {
        sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
        return;
      }

      const { weekNumber, frontPhotoUrl, sidePhotoUrl, backPhotoUrl, weightKg, waistCm, notes } = req.body;

      if (!weekNumber || isNaN(Number(weekNumber))) {
        sendError(res, 'VALIDATION_ERROR', 'Valid week number (e.g. 1, 4, 8, 12) is required', HttpStatus.BAD_REQUEST);
        return;
      }

      const milestone = await prisma.transformationMilestone.upsert({
        where: {
          client_milestone_week_unique: {
            clientProfileId: profile.id,
            weekNumber: Number(weekNumber),
          },
        },
        create: {
          clientProfileId: profile.id,
          clientId: profile.clientId,
          weekNumber: Number(weekNumber),
          frontPhotoUrl: frontPhotoUrl || null,
          sidePhotoUrl: sidePhotoUrl || null,
          backPhotoUrl: backPhotoUrl || null,
          weightKg: weightKg ? Number(weightKg) : null,
          waistCm: waistCm ? Number(waistCm) : null,
          notes: notes || null,
          date: new Date(),
        },
        update: {
          frontPhotoUrl: frontPhotoUrl !== undefined ? frontPhotoUrl : undefined,
          sidePhotoUrl: sidePhotoUrl !== undefined ? sidePhotoUrl : undefined,
          backPhotoUrl: backPhotoUrl !== undefined ? backPhotoUrl : undefined,
          weightKg: weightKg ? Number(weightKg) : undefined,
          waistCm: waistCm ? Number(waistCm) : undefined,
          notes: notes !== undefined ? notes : undefined,
        },
      });

      sendSuccess(res, milestone, HttpStatus.CREATED);
    } catch (err: any) {
      sendError(res, 'INTERNAL_ERROR', 'Failed to save transformation milestone', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}

export const automationController = new AutomationController();
