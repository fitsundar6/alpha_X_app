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

      sendSuccess(res, result, HttpStatus.OK, `Found ${result.items.length} exercises matching search criteria`, {
        count: result.items.length,
        total: result.total,
        page: result.page,
      });
    } catch (err: any) {
      sendError(res, 'SEARCH_ERROR', err.message || 'Failed to search exercises', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Search Exercises',
        explanation: 'Database query failed while searching exercise catalog.',
      });
    }
  }

  /**
   * Seed / Sync exercises into PostgreSQL database
   */
  public async seedDatabase(_req: Request, res: Response): Promise<void> {
    try {
      const result = await exerciseService.seedDatabase();
      sendSuccess(res, result, HttpStatus.OK, `Seeded exercise database: ${result.total} exercises active`);
    } catch (err: any) {
      sendError(res, 'SEED_ERROR', err.message || 'Failed to seed exercises', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Seed Exercises Database',
        explanation: 'Database write failed during exercise seeding.',
      });
    }
  }

  /**
   * Get exercise by ID
   */
  public async getExerciseById(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const exercise = await exerciseService.getExerciseById(id);
      if (!exercise) {
        sendError(res, 'NOT_FOUND', `Exercise with ID "${id}" was not found`, HttpStatus.NOT_FOUND, undefined, undefined, {
          activity: 'Get Exercise By ID',
          resourceId: id,
          resourceType: 'Exercise',
          explanation: 'The requested exercise ID was not found in the exercises catalog or database.',
        });
        return;
      }
      sendSuccess(res, exercise, HttpStatus.OK, `Retrieved exercise "${id}" ("${exercise.name}")`);
    } catch (err: any) {
      sendError(res, 'GET_ERROR', err.message || 'Failed to fetch exercise', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Get Exercise By ID',
        resourceId: id,
        resourceType: 'Exercise',
      });
    }
  }

  /**
   * Get alternatives for exercise
   */
  public async getAlternatives(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const alternatives = await exerciseService.getAlternatives(id);
      sendSuccess(res, alternatives, HttpStatus.OK, `Retrieved ${alternatives.length} alternatives for exercise "${id}"`);
    } catch (err: any) {
      sendError(res, 'ALTERNATIVES_ERROR', err.message || 'Failed to fetch alternatives', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Get Exercise Alternatives',
        resourceId: id,
        resourceType: 'Exercise',
      });
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
          HttpStatus.BAD_REQUEST,
          undefined,
          undefined,
          {
            activity: 'Create Custom Exercise',
            explanation: 'Missing one or more required fields (name, category, primaryMuscles).',
            receivedPayload: req.body,
          }
        );
        return;
      }

      const exercise = await exerciseService.createCustomExercise(body);
      sendSuccess(res, exercise, HttpStatus.CREATED, `Created custom exercise "${exercise.id}" ("${exercise.name}")`, {
        id: exercise.id,
        name: exercise.name,
      });
    } catch (err: any) {
      sendError(res, 'CREATE_ERROR', err.message || 'Failed to create exercise', HttpStatus.BAD_REQUEST, undefined, err, {
        activity: 'Create Custom Exercise',
        explanation: 'Database insertion failed while creating custom exercise.',
        receivedPayload: req.body,
      });
    }
  }

  /**
   * Update exercise (Admin only)
   */
  public async updateExercise(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const exercise = await exerciseService.updateExercise(id, req.body);
      sendSuccess(res, exercise, HttpStatus.OK, `Updated exercise "${id}" ("${exercise.name}")`);
    } catch (err: any) {
      sendError(res, 'UPDATE_ERROR', err.message || 'Failed to update exercise', HttpStatus.BAD_REQUEST, undefined, err, {
        activity: 'Update Exercise',
        resourceId: id,
        resourceType: 'Exercise',
        receivedPayload: req.body,
      });
    }
  }

  /**
   * Archive exercise (Admin only - soft delete)
   */
  public async archiveExercise(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const exercise = await exerciseService.archiveExercise(id);
      sendSuccess(res, exercise, HttpStatus.OK, `Archived exercise "${id}" ("${exercise.name}")`);
    } catch (err: any) {
      sendError(res, 'ARCHIVE_ERROR', err.message || 'Failed to archive exercise', HttpStatus.BAD_REQUEST, undefined, err, {
        activity: 'Archive Exercise',
        resourceId: id,
        resourceType: 'Exercise',
      });
    }
  }

  /**
   * Restore exercise (Admin only)
   */
  public async restoreExercise(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const exercise = await exerciseService.restoreExercise(id);
      sendSuccess(res, exercise, HttpStatus.OK, `Restored exercise "${id}" ("${exercise.name}")`);
    } catch (err: any) {
      sendError(res, 'RESTORE_ERROR', err.message || 'Failed to restore exercise', HttpStatus.BAD_REQUEST, undefined, err, {
        activity: 'Restore Exercise',
        resourceId: id,
        resourceType: 'Exercise',
      });
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
