import { Request, Response, NextFunction } from 'express';
import { activityService } from './activity.service';
import { syncActivityPayloadSchema, updateStepGoalSchema } from './activity.validation';
import { sendSuccess } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';
import { AppError } from '../../middlewares/errorHandler';

export class ActivityController {
  /**
   * POST /api/v1/activity/sync
   * Client-authenticated batch synchronization
   */
  async syncActivity(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const clientId = req.user?.id;
      if (!clientId) {
        throw new AppError('Authentication required', HttpStatus.UNAUTHORIZED);
      }

      const validatedInput = syncActivityPayloadSchema.parse(req.body);
      const result = await activityService.syncClientActivity(clientId, validatedInput);

      sendSuccess(res, result, HttpStatus.OK);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/activity/today
   */
  async getToday(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const clientId = req.user?.id;
      if (!clientId) {
        throw new AppError('Authentication required', HttpStatus.UNAUTHORIZED);
      }

      const result = await activityService.getTodayActivity(clientId);
      sendSuccess(res, result, HttpStatus.OK);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/activity/history
   */
  async getHistory(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const clientId = req.user?.id;
      if (!clientId) {
        throw new AppError('Authentication required', HttpStatus.UNAUTHORIZED);
      }

      const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 30;
      const history = await activityService.getClientHistory(clientId, limit);

      sendSuccess(res, { history }, HttpStatus.OK);
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/v1/activity/client/:clientId
   * Admin inspects client activity
   */
  async inspectClient(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const adminId = req.user?.id;
      const clientId = Array.isArray(req.params.clientId) ? req.params.clientId[0] : req.params.clientId;

      if (!adminId) {
        throw new AppError('Authentication required', HttpStatus.UNAUTHORIZED);
      }

      const result = await activityService.inspectClientActivityAsAdmin(adminId, clientId);
      sendSuccess(res, result, HttpStatus.OK);
    } catch (err) {
      next(err);
    }
  }

  /**
   * PUT /api/v1/activity/client/:clientId/goal
   * Admin updates client step goal
   */
  async updateGoal(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const adminId = req.user?.id;
      const clientId = Array.isArray(req.params.clientId) ? req.params.clientId[0] : req.params.clientId;

      if (!adminId) {
        throw new AppError('Authentication required', HttpStatus.UNAUTHORIZED);
      }

      const validatedInput = updateStepGoalSchema.parse(req.body);
      const result = await activityService.updateClientStepGoal(
        adminId,
        clientId,
        validatedInput.stepGoal
      );

      sendSuccess(res, result, HttpStatus.OK);
    } catch (err) {
      next(err);
    }
  }
}

export const activityController = new ActivityController();
