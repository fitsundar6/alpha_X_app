import { Request, Response } from 'express';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { workoutService } from './workout.service';
import {
  createSessionSchema,
  updateSessionSchema,
  assignSessionSchema,
  createWorkoutRecordSchema,
} from './workout.validation';

export class WorkoutController {
  // --- Admin Endpoints ---
  async getAllAdminSessions(_req: Request, res: Response): Promise<void> {
    const sessions = await workoutService.getAllAdminSessions();
    sendSuccess(res, sessions, HttpStatus.OK);
  }

  async getAdminSessionById(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const session = await workoutService.getSessionById(id);
    if (!session) {
      sendError(res, 'NOT_FOUND', `Workout session "${id}" not found`, HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, session, HttpStatus.OK);
  }

  async createSession(req: Request, res: Response): Promise<void> {
    const parsed = createSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      const errorMsg = parsed.error.errors.map(e => `${e.path.join('.') || 'field'}: ${e.message}`).join('; ');
      sendError(res, 'VALIDATION_ERROR', errorMsg, HttpStatus.BAD_REQUEST, parsed.error.errors);
      return;
    }

    const adminId = req.user!.id;
    const newSession = await workoutService.createSession(parsed.data, adminId);
    sendSuccess(res, newSession, HttpStatus.CREATED);
  }

  async updateSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const parsed = updateSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      const errorMsg = parsed.error.errors.map(e => `${e.path.join('.') || 'field'}: ${e.message}`).join('; ');
      sendError(res, 'VALIDATION_ERROR', errorMsg, HttpStatus.BAD_REQUEST, parsed.error.errors);
      return;
    }

    const updated = await workoutService.updateSession(id, parsed.data);
    if (!updated) {
      sendError(res, 'NOT_FOUND', `Workout session "${id}" not found to update`, HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, updated, HttpStatus.OK);
  }

  async duplicateSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const duplicated = await workoutService.duplicateSession(id);
    if (!duplicated) {
      sendError(res, 'NOT_FOUND', `Workout session "${id}" not found to duplicate`, HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, duplicated, HttpStatus.CREATED);
  }

  async toggleActive(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const updated = await workoutService.toggleActive(id);
    if (!updated) {
      sendError(res, 'NOT_FOUND', `Workout session "${id}" not found`, HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, updated, HttpStatus.OK);
  }

  async deleteSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const success = await workoutService.deleteSession(id);
    if (!success) {
      sendError(res, 'NOT_FOUND', `Workout session "${id}" not found to delete`, HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, { deleted: true, id }, HttpStatus.OK);
  }

  async assignSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const parsed = assignSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      sendError(res, 'VALIDATION_ERROR', parsed.error.errors[0]?.message ?? 'Invalid assignment payload', HttpStatus.BAD_REQUEST);
      return;
    }

    const session = await workoutService.getSessionById(id);
    if (!session) {
      sendError(res, 'NOT_FOUND', `Workout session "${id}" not found to assign`, HttpStatus.NOT_FOUND);
      return;
    }

    const assignments = await workoutService.assignSession({
      sessionId: id,
      assignmentType: parsed.data.assignmentType,
      clientIds: parsed.data.clientIds,
      individualClientId: parsed.data.individualClientId,
      isRecommended: parsed.data.isRecommended,
      assignedById: req.user!.id,
    });

    sendSuccess(res, { assignments }, HttpStatus.OK);
  }

  async unassign(req: Request, res: Response): Promise<void> {
    const assignmentId = String(req.params.assignmentId);
    const success = await workoutService.unassign(assignmentId);
    if (!success) {
      sendError(res, 'NOT_FOUND', `Assignment "${assignmentId}" not found to remove`, HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, { unassigned: true, assignmentId }, HttpStatus.OK);
  }

  async getClientsList(_req: Request, res: Response): Promise<void> {
    const clients = await workoutService.getClientsList();
    sendSuccess(res, clients, HttpStatus.OK);
  }

  async getClientWorkoutResults(req: Request, res: Response): Promise<void> {
    const clientId = String(req.params.clientId);
    const results = await workoutService.getClientWorkoutResults(clientId);
    sendSuccess(res, results, HttpStatus.OK);
  }

  // --- Client Endpoints (Scoped to req.user.id) ---
  async getClientSessions(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const sessions = await workoutService.getClientSessions(clientId);
    sendSuccess(res, sessions, HttpStatus.OK);
  }

  async getClientSessionById(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const id = String(req.params.id);
    const session = await workoutService.getClientSessionById(id, clientId);
    if (!session) {
      sendError(res, 'FORBIDDEN', 'Workout session not available or unauthorized', HttpStatus.FORBIDDEN);
      return;
    }
    sendSuccess(res, session, HttpStatus.OK);
  }

  async getPreviousPerformance(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const exerciseId = req.query.exerciseId as string;
    if (!exerciseId) {
      sendError(res, 'BAD_REQUEST', 'exerciseId query parameter is required', HttpStatus.BAD_REQUEST);
      return;
    }

    const performance = await workoutService.getPreviousPerformance(clientId, exerciseId);
    sendSuccess(res, performance, HttpStatus.OK);
  }

  async recordWorkout(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const parsed = createWorkoutRecordSchema.safeParse(req.body);
    if (!parsed.success) {
      sendError(
        res,
        'VALIDATION_ERROR',
        parsed.error.errors[0]?.message ?? 'Invalid workout record',
        HttpStatus.BAD_REQUEST,
        parsed.error.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
        parsed.error
      );
      return;
    }

    try {
      const record = await workoutService.recordWorkout(clientId, parsed.data);
      sendSuccess(res, record, HttpStatus.CREATED);
    } catch (err: any) {
      sendError(
        res,
        'DATABASE_ERROR',
        err?.message || 'Database query failed',
        HttpStatus.INTERNAL_SERVER_ERROR,
        undefined,
        err
      );
    }
  }

  async getClientHistory(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const history = await workoutService.getClientHistory(clientId);
    sendSuccess(res, history, HttpStatus.OK);
  }

  async getWorkoutRecordById(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const id = String(req.params.id);
    const record = await workoutService.getWorkoutRecordById(id, clientId);
    if (!record) {
      sendError(res, 'NOT_FOUND', 'Workout record not found', HttpStatus.NOT_FOUND);
      return;
    }
    sendSuccess(res, record, HttpStatus.OK);
  }
}

export const workoutController = new WorkoutController();
