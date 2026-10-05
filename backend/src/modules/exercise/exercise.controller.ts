import { Request, Response } from 'express';
import { exerciseService } from './exercise.service';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';

export class ExerciseController {
  /**
   * Search and list exercises with filters and pagination
   */
  public async searchExercises(req: Request, res: Response): Promise<void> {
    try {
      const {
        query,
        category,
        muscle,
        equipment,
        difficulty,
        exerciseType,
        isCompound,
        isIsolation,
        isUnilateral,
        includeArchived,
        page,
        limit,
        sort,
      } = req.query;

      const result = await exerciseService.searchExercises({
        query: query as string | undefined,
        category: category as string | undefined,
        muscle: muscle as string | undefined,
        equipment: equipment as string | undefined,
        difficulty: difficulty as string | undefined,
        exerciseType: exerciseType as string | undefined,
        isCompound: isCompound !== undefined ? isCompound === 'true' : undefined,
        isIsolation: isIsolation !== undefined ? isIsolation === 'true' : undefined,
        isUnilateral: isUnilateral !== undefined ? isUnilateral === 'true' : undefined,
        includeArchived: includeArchived === 'true',
        page: page ? parseInt(page as string, 10) : 1,
        limit: limit ? parseInt(limit as string, 10) : 50,
        sort: sort as any,
      });

      sendSuccess(res, result);
    } catch (err: any) {
      sendError(res, 'SEARCH_ERROR', err.message || 'Failed to search exercises', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
    }
  }

  /**
   * Seed / Sync exercises into PostgreSQL database
   */
  public async seedDatabase(_req: Request, res: Response): Promise<void> {
    try {
      const result = await exerciseService.seedDatabase();
      sendSuccess(res, result);
    } catch (err: any) {
      sendError(res, 'SEED_ERROR', err.message || 'Failed to seed exercises', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
    }
  }

  /**
   * Get exercise by ID
   */
  public async getExerciseById(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const exercise = await exerciseService.getExerciseById(id);
      if (!exercise) {
        sendError(res, 'NOT_FOUND', `Exercise with ID "${id}" was not found`, HttpStatus.NOT_FOUND);
        return;
      }
      sendSuccess(res, exercise);
    } catch (err: any) {
      sendError(res, 'GET_ERROR', err.message || 'Failed to fetch exercise', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
    }
  }

  /**
   * Get alternatives for exercise
   */
  public async getAlternatives(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const alternatives = await exerciseService.getAlternatives(id);
      sendSuccess(res, alternatives);
    } catch (err: any) {
      sendError(res, 'ALTERNATIVES_ERROR', err.message || 'Failed to fetch alternatives', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
    }
  }

  /**
   * Create custom exercise (Admin only)
   */
  public async createCustomExercise(req: Request, res: Response): Promise<void> {
    try {
      const body = req.body;
      if (!body.name || !body.category || !body.primaryMuscles) {
        sendError(
          res,
          'VALIDATION_ERROR',
          'Exercise name, category, and primary muscles are required.',
          HttpStatus.BAD_REQUEST
        );
        return;
      }

      const exercise = await exerciseService.createCustomExercise(body);
      sendSuccess(res, exercise, HttpStatus.CREATED);
    } catch (err: any) {
      sendError(res, 'CREATE_ERROR', err.message || 'Failed to create exercise', HttpStatus.BAD_REQUEST);
    }
  }

  /**
   * Update exercise (Admin only)
   */
  public async updateExercise(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const exercise = await exerciseService.updateExercise(id, req.body);
      sendSuccess(res, exercise);
    } catch (err: any) {
      sendError(res, 'UPDATE_ERROR', err.message || 'Failed to update exercise', HttpStatus.BAD_REQUEST);
    }
  }

  /**
   * Archive exercise (Admin only - soft delete)
   */
  public async archiveExercise(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const exercise = await exerciseService.archiveExercise(id);
      sendSuccess(res, exercise);
    } catch (err: any) {
      sendError(res, 'ARCHIVE_ERROR', err.message || 'Failed to archive exercise', HttpStatus.BAD_REQUEST);
    }
  }

  /**
   * Restore exercise (Admin only)
   */
  public async restoreExercise(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const exercise = await exerciseService.restoreExercise(id);
      sendSuccess(res, exercise);
    } catch (err: any) {
      sendError(res, 'RESTORE_ERROR', err.message || 'Failed to restore exercise', HttpStatus.BAD_REQUEST);
    }
  }

  /**
   * Trigger sync (Admin only)
   */
  public async syncExercises(_req: Request, res: Response): Promise<void> {
    try {
      const syncResult = await exerciseService.syncFromExternalSources();
      sendSuccess(res, syncResult);
    } catch (err: any) {
      sendError(res, 'SYNC_ERROR', err.message || 'Exercise sync failed', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Get sync status (Admin only)
   */
  public getSyncStatus(_req: Request, res: Response): void {
    try {
      const status = exerciseService.getSyncStatus();
      sendSuccess(res, status);
    } catch (err: any) {
      sendError(res, 'STATUS_ERROR', err.message || 'Failed to get sync status', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Legal attribution metadata
   */
  public getAttributionInfo(_req: Request, res: Response): void {
    try {
      const info = exerciseService.getAttributionInfo();
      sendSuccess(res, info);
    } catch (err: any) {
      sendError(res, 'ATTRIBUTION_ERROR', err.message || 'Failed to fetch attribution', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}

export const exerciseController = new ExerciseController();
