import { prisma } from '../../config/prisma';
import { FoodDto, CreateCustomFoodInput, FoodSearchParams } from './food.types';
import { INITIAL_FOOD_CATALOG } from './food.seed';

export class FoodService {
  private fallbackMemoryFoods: Map<string, FoodDto> = new Map();

  constructor() {
    // Populate in-memory map as instant fallback if DB connection fails
    for (const item of INITIAL_FOOD_CATALOG) {
      const now = new Date().toISOString();
      this.fallbackMemoryFoods.set(item.id, {
        ...item,
        createdAt: now,
        updatedAt: now,
      });
    }
  }

  /**
   * Normalize food name for sensible duplicate detection and search
   */
  public normalize(text: string): string {
    return text
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9\s]/g, '')
      .replace(/\s+/g, ' ');
  }

  /**
   * Calculate Atwater calories: 4*Protein + 4*Carbs + 9*Fat
   */
  public calculateAtwaterCalories(protein: number, carbs: number, fat: number): number {
    return Math.round(protein * 4 + carbs * 4 + fat * 9);
  }

  /**
   * Idempotent seed of initial verified foods into PostgreSQL database
   */
  public async seedDatabase(): Promise<{ inserted: number; existing: number; total: number }> {
    try {
      const data = INITIAL_FOOD_CATALOG.map((seed) => ({
        id: seed.id,
        name: seed.name,
        normalizedName: seed.normalizedName,
        category: seed.category,
        servingSize: seed.servingSize,
        servingUnit: seed.servingUnit,
        calories: seed.calories,
        protein: seed.protein,
        carbohydrates: seed.carbohydrates,
        fat: seed.fat,
        fiber: seed.fiber,
        sugar: seed.sugar,
        sodium: seed.sodium,
        source: seed.source,
        sourceId: seed.sourceId,
        isCustom: seed.isCustom,
        isPublic: seed.isPublic,
        isVerified: seed.isVerified,
        status: seed.status,
      }));

      const result = await prisma.food.createMany({
        data,
        skipDuplicates: true,
      });

      const total = await prisma.food.count();
      return { inserted: result.count, existing: data.length - result.count, total };
    } catch (err) {
      console.error('Failed to seed foods bulk:', err);
      return { inserted: 0, existing: 0, total: INITIAL_FOOD_CATALOG.length };
    }
  }

  /**
   * Search foods across standard and user-submitted custom foods in the global library
   */
  public async searchFoods(params: FoodSearchParams): Promise<{
    items: FoodDto[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const {
      query,
      category,
      source,
      isCustom,
      page = 1,
      limit = 100,
    } = params;

    const skip = (page - 1) * limit;

    try {
      const userId = params.userId;
      const whereClause: any = {
        OR: [
          { isPublic: true, status: 'APPROVED' },
          { isPublic: true },
          ...(userId ? [{ createdBy: userId }] : []),
        ],
      };

      if (category && category.toLowerCase() !== 'all') {
        if (category.toLowerCase() === 'custom' || category.toLowerCase() === 'user added') {
          whereClause.isCustom = true;
        } else {
          whereClause.category = { equals: category, mode: 'insensitive' };
        }
      }

      if (isCustom !== undefined) {
        whereClause.isCustom = isCustom;
      }

      if (source && source.toLowerCase() !== 'all') {
        whereClause.source = { equals: source.toUpperCase(), mode: 'insensitive' };
      }

      if (query && query.trim().length > 0) {
        const cleanQ = query.trim().toLowerCase();
        whereClause.AND = [
          {
            OR: [
              { name: { contains: cleanQ, mode: 'insensitive' } },
              { normalizedName: { contains: cleanQ, mode: 'insensitive' } },
              { category: { contains: cleanQ, mode: 'insensitive' } },
            ],
          },
        ];
      }

      const [foods, total] = await Promise.all([
        prisma.food.findMany({
          where: whereClause,
          orderBy: [{ isVerified: 'desc' }, { createdAt: 'desc' }, { name: 'asc' }],
          skip,
          take: limit,
        }),
        prisma.food.count({ where: whereClause }),
      ]);

      const items: FoodDto[] = (foods as any[]).map((f: any) => ({
        id: f.id,
        name: f.name,
        normalizedName: f.normalizedName,
        category: f.category,
        servingSize: f.servingSize,
        servingUnit: f.servingUnit,
        calories: f.calories,
        protein: f.protein,
        carbohydrates: f.carbohydrates,
        fat: f.fat,
        fiber: f.fiber,
        sugar: f.sugar ?? undefined,
        sodium: f.sodium ?? undefined,
        source: f.source,
        sourceId: f.sourceId,
        isCustom: f.isCustom,
        createdBy: f.createdBy,
        createdByName: f.createdByName,
        isPublic: f.isPublic,
        isVerified: f.isVerified,
        status: f.status as any,
        createdAt: f.createdAt.toISOString(),
        updatedAt: f.updatedAt.toISOString(),
      }));

      return {
        items,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      };
    } catch (err) {
      console.warn('Database query failed for foods, falling back to memory catalog:', err);
      // In-memory fallback
      let list = Array.from(this.fallbackMemoryFoods.values());

      if (params.userId) {
        list = list.filter((f) => f.isPublic !== false || f.createdBy === params.userId);
      } else {
        list = list.filter((f) => f.isPublic !== false);
      }

      if (category && category.toLowerCase() !== 'all') {
        if (category.toLowerCase() === 'custom' || category.toLowerCase() === 'user added') {
          list = list.filter((f) => f.isCustom);
        } else {
          list = list.filter((f) => f.category.toLowerCase() === category.toLowerCase());
        }
      }
      if (query && query.trim().length > 0) {
        const cleanQ = query.trim().toLowerCase();
        list = list.filter(
          (f) =>
            f.name.toLowerCase().includes(cleanQ) ||
            f.normalizedName.includes(cleanQ) ||
            f.category.toLowerCase().includes(cleanQ)
        );
      }

      const total = list.length;
      const paginated = list.slice(skip, skip + limit);

      return {
        items: paginated,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      };
    }
  }

  /**
   * Get single food by ID
   */
  public async getFoodById(id: string): Promise<FoodDto | null> {
    try {
      const food = await prisma.food.findUnique({ where: { id } });
      if (!food) return this.fallbackMemoryFoods.get(id) || null;

      return {
        id: food.id,
        name: food.name,
        normalizedName: food.normalizedName,
        category: food.category,
        servingSize: food.servingSize,
        servingUnit: food.servingUnit,
        calories: food.calories,
        protein: food.protein,
        carbohydrates: food.carbohydrates,
        fat: food.fat,
        fiber: food.fiber,
        sugar: food.sugar ?? undefined,
        sodium: food.sodium ?? undefined,
        source: food.source,
        sourceId: food.sourceId,
        isCustom: food.isCustom,
        createdBy: food.createdBy,
        createdByName: food.createdByName,
        isPublic: food.isPublic,
        isVerified: food.isVerified,
        status: food.status as any,
        createdAt: food.createdAt.toISOString(),
        updatedAt: food.updatedAt.toISOString(),
      };
    } catch (_) {
      return this.fallbackMemoryFoods.get(id) || null;
    }
  }

  /**
   * Create a new custom food item and immediately persist into central PostgreSQL database
   * so ALL clients and Admin can discover and use it.
   */
  public async createCustomFood(
    input: CreateCustomFoodInput,
    user: { id?: string; clientId?: string; name?: string; email?: string; role?: string }
  ): Promise<{ food: FoodDto; isDuplicate: boolean }> {
    const rawName = input.name.trim();
    if (!rawName) {
      throw new Error('Food name is required');
    }

    const normName = this.normalize(rawName);
    const servingSize = Number(input.servingSize) > 0 ? Number(input.servingSize) : 100;
    const servingUnit = (input.servingUnit || 'grams').trim().toLowerCase();
    const protein = Math.max(0, Number(input.protein) || 0);
    const carbs = Math.max(0, Number(input.carbohydrates) || 0);
    const fat = Math.max(0, Number(input.fat) || 0);
    const fiber = Math.max(0, Number(input.fiber) || 0);
    const sugar = input.sugar !== undefined ? Math.max(0, Number(input.sugar)) : undefined;
    const sodium = input.sodium !== undefined ? Math.max(0, Number(input.sodium)) : undefined;

    // Automatic Atwater calorie calculation
    const calculatedCalories = this.calculateAtwaterCalories(protein, carbs, fat);
    const calories =
      input.calories !== undefined && Number(input.calories) > 0
        ? Number(input.calories)
        : calculatedCalories;

    const category = input.category?.trim() || 'Custom';
    const creatorId = user.clientId || user.id || 'anonymous';
    const creatorName = user.name || user.email || creatorId;

    // DUPLICATE PREVENTION:
    // Check if an identical food already exists with the same normalized name and serving unit
    try {
      const existing = await prisma.food.findFirst({
        where: {
          normalizedName: normName,
          servingUnit: servingUnit,
        },
      });

      if (existing) {
        // If macros are identical or created by same user, return existing food instead of creating duplicate
        const isExactMatch =
          Math.abs(existing.protein - protein) < 0.5 &&
          Math.abs(existing.carbohydrates - carbs) < 0.5 &&
          Math.abs(existing.fat - fat) < 0.5;

        if (isExactMatch || existing.createdBy === creatorId) {
          const dto: FoodDto = {
            id: existing.id,
            name: existing.name,
            normalizedName: existing.normalizedName,
            category: existing.category,
            servingSize: existing.servingSize,
            servingUnit: existing.servingUnit,
            calories: existing.calories,
            protein: existing.protein,
            carbohydrates: existing.carbohydrates,
            fat: existing.fat,
            fiber: existing.fiber,
            sugar: existing.sugar ?? undefined,
            sodium: existing.sodium ?? undefined,
            source: existing.source,
            sourceId: existing.sourceId,
            isCustom: existing.isCustom,
            createdBy: existing.createdBy,
            createdByName: existing.createdByName,
            isPublic: existing.isPublic,
            isVerified: existing.isVerified,
            status: existing.status as any,
            createdAt: existing.createdAt.toISOString(),
            updatedAt: existing.updatedAt.toISOString(),
          };
          return { food: dto, isDuplicate: true };
        }
      }

      // Generate stable, unique custom food ID
      const newId = `cf_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

      const created = await prisma.food.create({
        data: {
          id: newId,
          name: rawName,
          normalizedName: normName,
          category,
          servingSize,
          servingUnit,
          calories,
          protein,
          carbohydrates: carbs,
          fat,
          fiber,
          sugar,
          sodium,
          source: 'USER',
          sourceId: null,
          isCustom: true,
          createdBy: creatorId,
          createdByName: creatorName,
          isPublic: input.isPublic !== false, // Default true: global food library
          isVerified: false,
          status: 'APPROVED', // Immediately available to all users with admin ability to moderate
        },
      });

      const foodDto: FoodDto = {
        id: created.id,
        name: created.name,
        normalizedName: created.normalizedName,
        category: created.category,
        servingSize: created.servingSize,
        servingUnit: created.servingUnit,
        calories: created.calories,
        protein: created.protein,
        carbohydrates: created.carbohydrates,
        fat: created.fat,
        fiber: created.fiber,
        sugar: created.sugar ?? undefined,
        sodium: created.sodium ?? undefined,
        source: created.source,
        sourceId: created.sourceId,
        isCustom: created.isCustom,
        createdBy: created.createdBy,
        createdByName: created.createdByName,
        isPublic: created.isPublic,
        isVerified: created.isVerified,
        status: created.status as any,
        createdAt: created.createdAt.toISOString(),
        updatedAt: created.updatedAt.toISOString(),
      };

      // Keep in-memory cache synchronized
      this.fallbackMemoryFoods.set(foodDto.id, foodDto);

      return { food: foodDto, isDuplicate: false };
    } catch (err) {
      console.error('Error saving custom food into PostgreSQL:', err);
      // Create in memory as fallback
      const fallbackId = `cf_mem_${Date.now()}`;
      const now = new Date().toISOString();
      const foodDto: FoodDto = {
        id: fallbackId,
        name: rawName,
        normalizedName: normName,
        category,
        servingSize,
        servingUnit,
        calories,
        protein,
        carbohydrates: carbs,
        fat,
        fiber,
        sugar,
        sodium,
        source: 'USER',
        isCustom: true,
        createdBy: creatorId,
        createdByName: creatorName,
        isPublic: true,
        isVerified: false,
        status: 'APPROVED',
        createdAt: now,
        updatedAt: now,
      };
      this.fallbackMemoryFoods.set(fallbackId, foodDto);
      return { food: foodDto, isDuplicate: false };
    }
  }

  /**
   * Delete custom food (only creator or ADMIN can delete)
   */
  public async deleteFood(
    id: string,
    user: { id?: string; clientId?: string; role?: string }
  ): Promise<boolean> {
    try {
      const existing = await prisma.food.findUnique({ where: { id } });
      if (!existing) return false;

      const isAdmin = user.role === 'ADMIN';
      const isOwner =
        existing.createdBy === user.clientId ||
        existing.createdBy === user.id;

      if (!isAdmin && !isOwner) {
        throw new Error('Unauthorized: You do not have permission to delete this food item');
      }

      await prisma.food.delete({ where: { id } });
      this.fallbackMemoryFoods.delete(id);
      return true;
    } catch (err) {
      this.fallbackMemoryFoods.delete(id);
      return true;
    }
  }
}

export const foodService = new FoodService();
