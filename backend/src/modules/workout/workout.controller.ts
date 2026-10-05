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
    sendSuccess(
      res,
      sessions,
      HttpStatus.OK,
      `Fetched ${sessions.length} admin workout sessions from database`,
      { count: sessions.length }
    );
  }

  async getAdminSessionById(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const session = await workoutService.getSessionById(id);
    if (!session) {
      sendError(
        res,
        'NOT_FOUND',
        `Workout session "${id}" does not exist in the database or cache`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Get Workout Session By ID',
          resourceId: id,
          resourceType: 'WorkoutSession',
          explanation: 'The requested workout session ID was not found in PostgreSQL table "workout_sessions".',
        }
      );
      return;
    }
    sendSuccess(
      res,
      session,
      HttpStatus.OK,
      `Retrieved workout session "${id}" ("${session.title}")`,
      { id: session.id, title: session.title, exercisesCount: session.exercises.length }
    );
  }

  async createSession(req: Request, res: Response): Promise<void> {
    const parsed = createSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      const errorMsg = parsed.error.errors.map((e) => `${e.path.join('.') || 'field'}: ${e.message}`).join('; ');
      sendError(
        res,
        'VALIDATION_ERROR',
        `Workout session creation validation failed: ${errorMsg}`,
        HttpStatus.BAD_REQUEST,
        parsed.error.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
        parsed.error,
        {
          activity: 'Create Workout Session',
          explanation: 'Request body failed validation constraints. Verify field values listed in details.',
          receivedPayload: req.body,
        }
      );
      return;
    }

    const adminId = req.user!.id;
    const newSession = await workoutService.createSession(parsed.data, adminId);
    sendSuccess(
      res,
      newSession,
      HttpStatus.CREATED,
      `Created workout session "${newSession.id}" ("${newSession.title}") with ${newSession.exercises.length} exercises`,
      {
        id: newSession.id,
        title: newSession.title,
        workoutType: newSession.workoutType,
        exercisesCount: newSession.exercises.length,
        durationMinutes: newSession.estimatedDurationMinutes,
      }
    );
  }

  async updateSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const parsed = updateSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      const errorMsg = parsed.error.errors.map((e) => `${e.path.join('.') || 'field'}: ${e.message}`).join('; ');
      sendError(
        res,
        'VALIDATION_ERROR',
        `Workout session update validation failed: ${errorMsg}`,
        HttpStatus.BAD_REQUEST,
        parsed.error.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
        parsed.error,
        {
          activity: 'Update Workout Session',
          resourceId: id,
          resourceType: 'WorkoutSession',
          receivedPayload: req.body,
        }
      );
      return;
    }

    const updated = await workoutService.updateSession(id, parsed.data);
    if (!updated) {
      sendError(
        res,
        'NOT_FOUND',
        `Workout session "${id}" does not exist in database to update`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Update Workout Session',
          resourceId: id,
          resourceType: 'WorkoutSession',
          explanation: 'Cannot apply updates because the target workout session was not found in PostgreSQL.',
        }
      );
      return;
    }
    sendSuccess(
      res,
      updated,
      HttpStatus.OK,
      `Updated workout session "${id}" ("${updated.title}")`,
      { id: updated.id, title: updated.title, isActive: updated.isActive }
    );
  }

  async duplicateSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const duplicated = await workoutService.duplicateSession(id);
    if (!duplicated) {
      sendError(
        res,
        'NOT_FOUND',
        `Source workout session "${id}" does not exist to duplicate`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Duplicate Workout Session',
          resourceId: id,
          resourceType: 'WorkoutSession',
          explanation: 'Cannot duplicate because the original workout session was not found in the database.',
        }
      );
      return;
    }
    sendSuccess(
      res,
      duplicated,
      HttpStatus.CREATED,
      `Duplicated workout session "${id}" as "${duplicated.id}" ("${duplicated.title}")`,
      { sourceId: id, newId: duplicated.id, title: duplicated.title }
    );
  }

  async toggleActive(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const updated = await workoutService.toggleActive(id);
    if (!updated) {
      sendError(
        res,
        'NOT_FOUND',
        `Workout session "${id}" not found to toggle active status`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Toggle Workout Session Active Status',
          resourceId: id,
          resourceType: 'WorkoutSession',
        }
      );
      return;
    }
    sendSuccess(
      res,
      updated,
      HttpStatus.OK,
      `Toggled workout session "${id}" active state to ${updated.isActive}`,
      { id: updated.id, isActive: updated.isActive }
    );
  }

  async deleteSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const success = await workoutService.deleteSession(id);
    if (!success) {
      sendError(
        res,
        'NOT_FOUND',
        `Workout session "${id}" was not found to delete`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Delete Workout Session',
          resourceId: id,
          resourceType: 'WorkoutSession',
          explanation: 'The session was already deleted or was never persisted to the PostgreSQL database.',
        }
      );
      return;
    }
    sendSuccess(
      res,
      { deleted: true, id },
      HttpStatus.OK,
      `Deleted workout session "${id}" and removed all related assignments from database`,
      { deletedSessionId: id }
    );
  }

  async assignSession(req: Request, res: Response): Promise<void> {
    const id = String(req.params.id);
    const parsed = assignSessionSchema.safeParse(req.body);
    if (!parsed.success) {
      const errorMsg = parsed.error.errors.map((e) => `${e.path.join('.') || 'field'}: ${e.message}`).join('; ');
      sendError(
        res,
        'VALIDATION_ERROR',
        `Assignment payload validation failed: ${errorMsg}`,
        HttpStatus.BAD_REQUEST,
        parsed.error.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
        parsed.error,
        {
          activity: 'Assign Workout Session',
          resourceId: id,
          resourceType: 'WorkoutSession',
          receivedPayload: req.body,
        }
      );
      return;
    }

    const session = await workoutService.getSessionById(id);
    if (!session) {
      sendError(
        res,
        'NOT_FOUND',
        `Cannot assign workout: Workout session "${id}" does not exist in database`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Assign Workout Session',
          resourceId: id,
          resourceType: 'WorkoutSession',
          explanation: 'The workout session must be saved before it can be assigned to clients. It may only exist locally on the device.',
        }
      );
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

    sendSuccess(
      res,
      { assignments },
      HttpStatus.OK,
      `Assigned workout session "${id}" (${parsed.data.assignmentType}) to ${assignments.length} client target(s)`,
      { sessionId: id, assignmentType: parsed.data.assignmentType, assignedCount: assignments.length }
    );
  }

  async unassign(req: Request, res: Response): Promise<void> {
    const assignmentId = String(req.params.assignmentId);
    const success = await workoutService.unassign(assignmentId);
    if (!success) {
      sendError(
        res,
        'NOT_FOUND',
        `Assignment "${assignmentId}" not found in database to remove`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Unassign Workout Session',
          resourceId: assignmentId,
          resourceType: 'WorkoutAssignment',
          explanation: 'The assignment record does not exist or was already removed.',
        }
      );
      return;
    }
    sendSuccess(
      res,
      { unassigned: true, assignmentId },
      HttpStatus.OK,
      `Removed workout assignment "${assignmentId}"`,
      { assignmentId }
    );
  }

  async getClientsList(_req: Request, res: Response): Promise<void> {
    const clients = await workoutService.getClientsList();
    sendSuccess(
      res,
      clients,
      HttpStatus.OK,
      `Retrieved ${clients.length} clients for workout assignment overview`,
      { count: clients.length }
    );
  }

  async getClientWorkoutResults(req: Request, res: Response): Promise<void> {
    const clientId = String(req.params.clientId);
    const results = await workoutService.getClientWorkoutResults(clientId);
    const historyCount = results.history ? results.history.length : 0;
    sendSuccess(
      res,
      results,
      HttpStatus.OK,
      `Retrieved workout history (${historyCount} records) for client "${clientId}"`,
      { clientId, recordsCount: historyCount }
    );
  }

  // --- Client Endpoints (Scoped to req.user.id) ---
  async getClientSessions(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const sessions = await workoutService.getClientSessions(clientId);
    sendSuccess(
      res,
      sessions,
      HttpStatus.OK,
      `Retrieved assigned workout sessions for athlete "${clientId}"`,
      { availableCount: sessions.available.length }
    );
  }

  async getClientSessionById(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const id = String(req.params.id);
    const session = await workoutService.getClientSessionById(id, clientId);
    if (!session) {
      sendError(
        res,
        'FORBIDDEN',
        `Workout session "${id}" is not available or unauthorized for client "${clientId}"`,
        HttpStatus.FORBIDDEN,
        undefined,
        undefined,
        {
          activity: 'Get Client Session By ID',
          resourceId: id,
          resourceType: 'WorkoutSession',
          explanation: 'This workout session is either inactive, unassigned to this athlete, or does not exist.',
        }
      );
      return;
    }
    sendSuccess(
      res,
      session,
      HttpStatus.OK,
      `Loaded workout session "${id}" ("${session.title}") for client "${clientId}"`
    );
  }

  async getPreviousPerformance(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const exerciseId = req.query.exerciseId as string;
    if (!exerciseId) {
      sendError(
        res,
        'BAD_REQUEST',
        'Missing required query parameter "exerciseId"',
        HttpStatus.BAD_REQUEST,
        undefined,
        undefined,
        {
          activity: 'Get Previous Performance',
          explanation: 'The request must supply ?exerciseId=<id> to look up historical set performance.',
        }
      );
      return;
    }

    const performance = await workoutService.getPreviousPerformance(clientId, exerciseId);
    sendSuccess(
      res,
      performance,
      HttpStatus.OK,
      `Retrieved previous performance on exercise "${exerciseId}" for client "${clientId}"`
    );
  }

  async recordWorkout(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const parsed = createWorkoutRecordSchema.safeParse(req.body);
    if (!parsed.success) {
      const errorMsg = parsed.error.errors.map((e) => `${e.path.join('.') || 'field'}: ${e.message}`).join('; ');
      sendError(
        res,
        'VALIDATION_ERROR',
        `Workout record validation failed: ${errorMsg}`,
        HttpStatus.BAD_REQUEST,
        parsed.error.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
        parsed.error,
        {
          activity: 'Record Completed Workout',
          explanation: 'The submitted workout telemetry failed validation constraints.',
          receivedPayload: req.body,
        }
      );
      return;
    }

    try {
      const record = await workoutService.recordWorkout(clientId, parsed.data);
      sendSuccess(
        res,
        record,
        HttpStatus.CREATED,
        `Saved workout record "${record.sessionTitle}" for client "${record.clientId}" (Sets: ${record.completedSetsCount}, Volume: ${record.totalVolume} kg)`,
        {
          recordId: record.id,
          sessionTitle: record.sessionTitle,
          completedSets: record.completedSetsCount,
          totalVolumeKg: record.totalVolume,
        }
      );
    } catch (err: any) {
      sendError(
        res,
        'DATABASE_ERROR',
        err?.message || 'Database query failed saving workout record',
        HttpStatus.INTERNAL_SERVER_ERROR,
        undefined,
        err,
        {
          activity: 'Record Completed Workout',
          explanation: 'Database insertion failed while persisting completed workout session record.',
        }
      );
    }
  }

  async getClientHistory(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const history = await workoutService.getClientHistory(clientId);
    sendSuccess(
      res,
      history,
      HttpStatus.OK,
      `Retrieved completed workout history (${history.length} records) for client "${clientId}"`,
      { recordsCount: history.length }
    );
  }

  async getWorkoutRecordById(req: Request, res: Response): Promise<void> {
    const clientId = req.user!.id;
    const id = String(req.params.id);
    const record = await workoutService.getWorkoutRecordById(id, clientId);
    if (!record) {
      sendError(
        res,
        'NOT_FOUND',
        `Workout record "${id}" was not found for client "${clientId}"`,
        HttpStatus.NOT_FOUND,
        undefined,
        undefined,
        {
          activity: 'Get Workout Record By ID',
          resourceId: id,
          resourceType: 'WorkoutRecord',
          explanation: 'No completed workout record matching this ID exists for the current user.',
        }
      );
      return;
    }
    sendSuccess(
      res,
      record,
      HttpStatus.OK,
      `Retrieved workout record "${id}" ("${record.sessionTitle}")`
    );
  }
}

export const workoutController = new WorkoutController();
