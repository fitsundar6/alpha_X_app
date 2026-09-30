import { Request, Response } from 'express';
import { foodService } from './food.service';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';

export class FoodController {
  /**
   * Search and list foods with filters and pagination
   */
  public async searchFoods(req: Request, res: Response): Promise<void> {
    try {
      const {
        query,
        category,
        source,
        isCustom,
        page,
        limit,
      } = req.query;
      const user = (req as any).user || {};
      const userId = user.clientId || user.id || (req.query.userId as string | undefined);

      const result = await foodService.searchFoods({
        query: query as string | undefined,
        category: category as string | undefined,
        source: source as string | undefined,
        isCustom: isCustom !== undefined ? isCustom === 'true' : undefined,
        userId: userId || undefined,
        page: page ? parseInt(page as string, 10) : 1,
        limit: limit ? parseInt(limit as string, 10) : 100,
      });

      sendSuccess(res, result);
    } catch (err: any) {
      sendError(res, 'FOOD_SEARCH_ERROR', err.message || 'Failed to search foods', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Get single food by ID
   */
  public async getFoodById(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const food = await foodService.getFoodById(id);
      if (!food) {
        sendError(res, 'NOT_FOUND', `Food with ID "${id}" was not found`, HttpStatus.NOT_FOUND);
        return;
      }
      sendSuccess(res, food);
    } catch (err: any) {
      sendError(res, 'FOOD_FETCH_ERROR', err.message || 'Failed to fetch food', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Create a new custom food item (saves globally to central PostgreSQL)
   */
  public async createCustomFood(req: Request, res: Response): Promise<void> {
    try {
      const {
        name,
        category,
        servingSize,
        servingUnit,
        calories,
        protein,
        carbohydrates,
        fat,
        fiber,
        sugar,
        sodium,
        isPublic,
      } = req.body;

      if (!name || typeof name !== 'string' || !name.trim()) {
        sendError(res, 'VALIDATION_ERROR', 'Food name is required', HttpStatus.BAD_REQUEST);
        return;
      }

      if (protein === undefined || carbohydrates === undefined || fat === undefined) {
        sendError(res, 'VALIDATION_ERROR', 'Protein, carbohydrates, and fat are required', HttpStatus.BAD_REQUEST);
        return;
      }

      const user = (req as any).user || {};
      const clientIdHeader = (req.headers['x-client-id'] || req.headers['x-user-id'] || req.body.createdBy) as string | undefined;
      if (clientIdHeader && !user.clientId) {
        user.clientId = clientIdHeader;
      }

      const result = await foodService.createCustomFood(
        {
          name,
          category,
          servingSize,
          servingUnit,
          calories,
          protein: Number(protein),
          carbohydrates: Number(carbohydrates),
          fat: Number(fat),
          fiber: fiber !== undefined ? Number(fiber) : undefined,
          sugar: sugar !== undefined ? Number(sugar) : undefined,
          sodium: sodium !== undefined ? Number(sodium) : undefined,
          isPublic,
        },
        user
      );

      sendSuccess(
        res,
        { ...result.food, isDuplicate: result.isDuplicate },
        result.isDuplicate ? HttpStatus.OK : HttpStatus.CREATED
      );
    } catch (err: any) {
      sendError(res, 'CREATE_FOOD_ERROR', err.message || 'Failed to create custom food', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * Delete food item
   */
  public async deleteFood(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const user = (req as any).user || {};
      const deleted = await foodService.deleteFood(id, user);

      if (!deleted) {
        sendError(res, 'NOT_FOUND', `Food with ID "${id}" was not found`, HttpStatus.NOT_FOUND);
        return;
      }

      sendSuccess(res, { deleted: true, id });
    } catch (err: any) {
      sendError(res, 'DELETE_FOOD_ERROR', err.message || 'Failed to delete food', HttpStatus.BAD_REQUEST);
    }
  }

  /**
   * Seed / Sync initial foods into database
   */
  public async seedDatabase(_req: Request, res: Response): Promise<void> {
    try {
      const stats = await foodService.seedDatabase();
      sendSuccess(res, stats);
    } catch (err: any) {
      sendError(res, 'SEED_ERROR', err.message || 'Failed to seed foods', HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }
}

export const foodController = new FoodController();
