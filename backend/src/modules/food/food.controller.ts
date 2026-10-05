import { Request, Response } from 'express';
import { foodService } from './food.service';
import { foodAiService } from './food.ai.service';
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

      sendSuccess(res, result, HttpStatus.OK, `Found ${result.items.length} food items matching search criteria`, {
        count: result.items.length,
        total: result.total,
        page: result.page,
      });
    } catch (err: any) {
      sendError(res, 'FOOD_SEARCH_ERROR', err.message || 'Failed to search foods', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Search Foods',
        explanation: 'Database query failed while searching food catalog.',
      });
    }
  }

  /**
   * Get single food by ID
   */
  public async getFoodById(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const food = await foodService.getFoodById(id);
      if (!food) {
        sendError(res, 'NOT_FOUND', `Food with ID "${id}" was not found`, HttpStatus.NOT_FOUND, undefined, undefined, {
          activity: 'Get Food By ID',
          resourceId: id,
          resourceType: 'FoodItem',
          explanation: 'The requested food ID was not found in database or catalog.',
        });
        return;
      }
      sendSuccess(res, food, HttpStatus.OK, `Retrieved food item "${id}" ("${food.name}")`);
    } catch (err: any) {
      sendError(res, 'FOOD_FETCH_ERROR', err.message || 'Failed to fetch food', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Get Food By ID',
        resourceId: id,
        resourceType: 'FoodItem',
      });
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
        sendError(res, 'VALIDATION_ERROR', 'Food name is required', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Create Custom Food',
          explanation: 'The food name field was missing or empty.',
          receivedPayload: req.body,
        });
        return;
      }

      if (protein === undefined || carbohydrates === undefined || fat === undefined) {
        sendError(res, 'VALIDATION_ERROR', 'Protein, carbohydrates, and fat are required', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Create Custom Food',
          explanation: 'One or more required macronutrient fields (protein, carbohydrates, fat) were missing.',
          receivedPayload: req.body,
        });
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
        result.isDuplicate ? HttpStatus.OK : HttpStatus.CREATED,
        `Saved custom food item "${result.food.id}" ("${result.food.name}")`,
        { id: result.food.id, name: result.food.name, isDuplicate: result.isDuplicate }
      );
    } catch (err: any) {
      sendError(res, 'CREATE_FOOD_ERROR', err.message || 'Failed to create custom food', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
        activity: 'Create Custom Food',
        explanation: 'Database insertion failed while creating custom food.',
        receivedPayload: req.body,
      });
    }
  }

  /**
   * Delete food item
   */
  public async deleteFood(req: Request, res: Response): Promise<void> {
    const id = req.params.id as string;
    try {
      const user = (req as any).user || {};
      const deleted = await foodService.deleteFood(id, user);

      if (!deleted) {
        sendError(res, 'NOT_FOUND', `Food with ID "${id}" was not found or already deleted`, HttpStatus.NOT_FOUND, undefined, undefined, {
          activity: 'Delete Food Item',
          resourceId: id,
          resourceType: 'FoodItem',
          explanation: 'The food item record does not exist or user lacks permission to delete.',
        });
        return;
      }

      sendSuccess(res, { deleted: true, id }, HttpStatus.OK, `Deleted food item "${id}" from database`);
    } catch (err: any) {
      sendError(res, 'DELETE_FOOD_ERROR', err.message || 'Failed to delete food', HttpStatus.BAD_REQUEST, undefined, err, {
        activity: 'Delete Food Item',
        resourceId: id,
        resourceType: 'FoodItem',
      });
    }
  }

  /**
   * Analyze food photo from live camera using AI vision
   */
  public async analyzeFoodImage(req: Request, res: Response): Promise<void> {
    try {
      const { image, imageBase64, mimeType } = req.body;
      const rawImage = imageBase64 || image;

      if (!rawImage || typeof rawImage !== 'string' || !rawImage.trim()) {
        sendError(
          res,
          'VALIDATION_ERROR',
          'Live camera image payload (Base64) is required for AI food scanning',
          HttpStatus.BAD_REQUEST
        );
        return;
      }

      const user = (req as any).user || {};
      const userId = user.clientId || user.id || (req.headers['x-client-id'] as string) || req.ip || 'client_athlete';

      const scanResult = await foodAiService.analyzeFoodImage(
        rawImage,
        mimeType || 'image/jpeg',
        userId
      );

      sendSuccess(res, scanResult);
    } catch (err: any) {
      const message = err.message || 'Food analysis is temporarily unavailable. Please check your internet connection and try again.';
      const isRateLimit = message.includes('limit') || message.includes('Too many camera scans');
      sendError(
        res,
        isRateLimit ? 'RATE_LIMIT_EXCEEDED' : 'AI_SCAN_ERROR',
        message,
        isRateLimit ? HttpStatus.TOO_MANY_REQUESTS : HttpStatus.INTERNAL_SERVER_ERROR
      );
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
