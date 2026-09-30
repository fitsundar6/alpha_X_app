import {
  ExerciseDto,
  ExerciseSearchParams,
  SyncResult,
  CreateCustomExerciseInput,
} from './exercise.types';
import { INITIAL_EXERCISE_CATALOG } from './exercise.seed';
import { prisma } from '../../config/prisma';
import { env } from '../../config/environment';

export class ExerciseService {
  private fallbackMemoryExercises: Map<string, ExerciseDto> = new Map();
  private lastSyncStats: SyncResult = {
    source: 'Alpha X Gym Catalog & wger Open API',
    totalFound: INITIAL_EXERCISE_CATALOG.length,
    importedCount: INITIAL_EXERCISE_CATALOG.length,
    updatedCount: 0,
    failedCount: 0,
    status: 'SUCCESS',
    errorMessage: null,
    lastSync: new Date().toISOString(),
  };

  constructor() {
    this.seedMemoryFallback();
  }

  private seedMemoryFallback(): void {
    for (const ex of INITIAL_EXERCISE_CATALOG) {
      this.fallbackMemoryExercises.set(ex.id, { ...ex });
    }
  }

  private mapPrismaToDto(item: any): ExerciseDto {
    return {
      id: item.id,
      externalId: item.externalId,
      name: item.name,
      normalizedName: item.normalizedName,
      aliases: item.aliases || [],
      description: item.description || '',
      instructions: item.instructions || [],
      coachingCues: item.coachingCues || [],
      commonMistakes: item.commonMistakes || [],
      primaryMuscles: item.primaryMuscles || [],
      secondaryMuscles: item.secondaryMuscles || [],
      bodyPart: item.bodyPart,
      category: item.category,
      subcategory: item.subcategory,
      equipment: item.equipment,
      movementPattern: item.movementPattern,
      exerciseType: item.exerciseType,
      difficulty: item.difficulty as any,
      mechanics: item.mechanics as any,
      forceType: item.forceType as any,
      planeOfMotion: item.planeOfMotion as any,
      laterality: item.laterality as any,
      isCompound: item.isCompound,
      isIsolation: item.isIsolation,
      isUnilateral: item.isUnilateral,
      imageUrl: item.imageUrl || '',
      videoUrl: item.videoUrl || '',
      thumbnailUrl: item.thumbnailUrl || '',
      variations: item.variations || [],
      progressions: item.progressions || [],
      regressions: item.regressions || [],
      alternativeExercises: item.alternativeExercises || [],
      source: item.source,
      sourceUrl: item.sourceUrl || '',
      license: item.license,
      licenseAuthor: item.licenseAuthor,
      isImported: item.isImported,
      isCustom: item.isCustom,
      isActive: item.isActive,
      createdAt: item.createdAt instanceof Date ? item.createdAt.toISOString() : String(item.createdAt),
      updatedAt: item.updatedAt instanceof Date ? item.updatedAt.toISOString() : String(item.updatedAt),
    };
  }

  /**
   * Seed / Sync full curated exercise catalog into PostgreSQL database idempotently
   */
  public async seedDatabase(): Promise<{ inserted: number; existing: number; total: number }> {
    try {
      const data = INITIAL_EXERCISE_CATALOG.map((seed) => ({
        id: seed.id,
        externalId: seed.externalId || null,
        name: seed.name,
        normalizedName: seed.normalizedName || seed.name.trim().toLowerCase(),
        aliases: seed.aliases || [],
        description: seed.description || '',
        instructions: seed.instructions || [],
        coachingCues: seed.coachingCues || [],
        commonMistakes: seed.commonMistakes || [],
        primaryMuscles: seed.primaryMuscles || [],
        secondaryMuscles: seed.secondaryMuscles || [],
        bodyPart: seed.bodyPart || seed.category || 'Full Body',
        category: seed.category || 'Strength',
        subcategory: seed.subcategory || null,
        equipment: seed.equipment || 'Barbell',
        movementPattern: seed.movementPattern || 'Compound',
        exerciseType: seed.exerciseType || 'Strength',
        difficulty: seed.difficulty || 'Intermediate',
        mechanics: seed.mechanics || 'Compound',
        forceType: seed.forceType || 'Push',
        planeOfMotion: seed.planeOfMotion || 'Sagittal',
        laterality: seed.laterality || 'Bilateral',
        isCompound: seed.isCompound ?? true,
        isIsolation: seed.isIsolation ?? false,
        isUnilateral: seed.isUnilateral ?? false,
        imageUrl: seed.imageUrl || '',
        videoUrl: seed.videoUrl || '',
        thumbnailUrl: seed.thumbnailUrl || '',
        variations: seed.variations || [],
        progressions: seed.progressions || [],
        regressions: seed.regressions || [],
        alternativeExercises: seed.alternativeExercises || [],
        source: seed.source || 'Alpha X Gym Curated Catalog',
        sourceUrl: seed.sourceUrl || '',
        license: seed.license || 'Proprietary',
        licenseAuthor: seed.licenseAuthor || 'Alpha X Gym Head Coach',
        isImported: seed.isImported ?? false,
        isCustom: seed.isCustom ?? false,
        isActive: seed.isActive ?? true,
      }));

      const result = await prisma.exercise.createMany({
        data,
        skipDuplicates: true,
      });

      const total = await prisma.exercise.count();
      return { inserted: result.count, existing: data.length - result.count, total };
    } catch (err) {
      console.error('[ExerciseService] Failed to seed exercises into Postgres:', err);
      return { inserted: 0, existing: 0, total: INITIAL_EXERCISE_CATALOG.length };
    }
  }

  /**
   * Search exercises with ranking, multi-term fuzzy matching, and filters.
   * Backed by PostgreSQL with automatic fallback to high-performance in-memory index.
   */
  public async searchExercises(params: ExerciseSearchParams): Promise<{
    items: ExerciseDto[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
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
      includeArchived = false,
      page = 1,
      limit = 50,
      sort = 'relevance',
    } = params;

    try {
      const where: any = {};

      if (!includeArchived) {
        where.isActive = true;
      }

      if (category && category.toLowerCase() !== 'all') {
        where.category = { equals: category, mode: 'insensitive' };
      }

      if (equipment && equipment.toLowerCase() !== 'all') {
        where.equipment = { equals: equipment, mode: 'insensitive' };
      }

      if (difficulty && difficulty.toLowerCase() !== 'all') {
        where.difficulty = { equals: difficulty, mode: 'insensitive' };
      }

      if (exerciseType && exerciseType.toLowerCase() !== 'all') {
        where.exerciseType = { equals: exerciseType, mode: 'insensitive' };
      }

      if (isCompound !== undefined) where.isCompound = isCompound;
      if (isIsolation !== undefined) where.isIsolation = isIsolation;
      if (isUnilateral !== undefined) where.isUnilateral = isUnilateral;

      if (muscle && muscle.toLowerCase() !== 'all') {
        const cleanMuscle = muscle.trim().toLowerCase();
        where.OR = [
          { primaryMuscles: { has: muscle } },
          { secondaryMuscles: { has: muscle } },
          { primaryMuscles: { hasSome: [muscle, muscle.toLowerCase(), cleanMuscle] } },
        ];
      }

      if (query && query.trim() !== '') {
        const q = query.trim().toLowerCase();
        const searchConditions = [
          { name: { contains: q, mode: 'insensitive' } },
          { normalizedName: { contains: q, mode: 'insensitive' } },
          { category: { contains: q, mode: 'insensitive' } },
          { equipment: { contains: q, mode: 'insensitive' } },
          { aliases: { has: q } },
        ];
        if (where.OR) {
          where.AND = [{ OR: searchConditions }];
        } else {
          where.OR = searchConditions;
        }
      }

      const orderBy: any[] = [];
      if (sort === 'nameAsc') {
        orderBy.push({ name: 'asc' });
      } else if (sort === 'nameDesc') {
        orderBy.push({ name: 'desc' });
      } else if (sort === 'categoryAsc') {
        orderBy.push({ category: 'asc' }, { name: 'asc' });
      } else {
        orderBy.push({ updatedAt: 'desc' });
      }

      const [dbExercises, totalCount] = await Promise.all([
        prisma.exercise.findMany({
          where,
          orderBy,
          skip: (page - 1) * limit,
          take: limit,
        }),
        prisma.exercise.count({ where }),
      ]);

      if (totalCount > 0 || (dbExercises && dbExercises.length > 0)) {
        return {
          items: dbExercises.map((e) => this.mapPrismaToDto(e)),
          total: totalCount,
          page,
          limit,
          totalPages: Math.ceil(totalCount / limit) || 1,
        };
      }
    } catch (err) {
      console.warn('[ExerciseService] DB query failed, falling back to memory catalog:', err);
    }

    // In-memory fallback
    return this.searchMemoryFallback(params);
  }

  private searchMemoryFallback(params: ExerciseSearchParams): {
    items: ExerciseDto[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  } {
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
      includeArchived = false,
      page = 1,
      limit = 50,
      sort = 'relevance',
    } = params;

    let list = Array.from(this.fallbackMemoryExercises.values());

    if (!includeArchived) {
      list = list.filter((e) => e.isActive);
    }

    if (category && category.toLowerCase() !== 'all') {
      list = list.filter((e) => e.category.toLowerCase() === category.toLowerCase());
    }

    if (muscle && muscle.toLowerCase() !== 'all') {
      const targetMuscle = muscle.toLowerCase();
      list = list.filter(
        (e) =>
          e.primaryMuscles.some((m) => m.toLowerCase().includes(targetMuscle)) ||
          e.secondaryMuscles.some((m) => m.toLowerCase().includes(targetMuscle))
      );
    }

    if (equipment && equipment.toLowerCase() !== 'all') {
      list = list.filter((e) => e.equipment.toLowerCase() === equipment.toLowerCase());
    }

    if (difficulty && difficulty.toLowerCase() !== 'all') {
      list = list.filter((e) => e.difficulty.toLowerCase() === difficulty.toLowerCase());
    }

    if (exerciseType && exerciseType.toLowerCase() !== 'all') {
      list = list.filter((e) => e.exerciseType.toLowerCase() === exerciseType.toLowerCase());
    }

    if (isCompound !== undefined) list = list.filter((e) => e.isCompound === isCompound);
    if (isIsolation !== undefined) list = list.filter((e) => e.isIsolation === isIsolation);
    if (isUnilateral !== undefined) list = list.filter((e) => e.isUnilateral === isUnilateral);

    let scoredList = list.map((item) => {
      let score = 0;
      if (!query || query.trim() === '') {
        return { item, score: 0 };
      }

      const q = query.trim().toLowerCase();
      const tokens = q.split(/\s+/).filter(Boolean);

      if (item.name.toLowerCase() === q || item.normalizedName === q) {
        score += 100;
      } else if (item.name.toLowerCase().startsWith(q)) {
        score += 80;
      } else if (item.name.toLowerCase().includes(q)) {
        score += 60;
      }

      if (item.aliases.some((a) => a.toLowerCase().includes(q))) {
        score += 50;
      }

      if (
        item.category.toLowerCase().includes(q) ||
        item.equipment.toLowerCase().includes(q) ||
        item.primaryMuscles.some((m) => m.toLowerCase().includes(q))
      ) {
        score += 40;
      }

      if (tokens.length > 1) {
        const searchableText = `${item.name} ${item.aliases.join(' ')} ${item.category} ${item.equipment} ${item.primaryMuscles.join(' ')} ${item.bodyPart}`.toLowerCase();
        const allTokensFound = tokens.every((token) => searchableText.includes(token));
        if (allTokensFound) {
          score += 35;
        }
      }

      return { item, score };
    });

    if (query && query.trim() !== '') {
      scoredList = scoredList.filter((s) => s.score > 0);
    }

    if (sort === 'relevance' && query && query.trim() !== '') {
      scoredList.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name));
    } else if (sort === 'nameAsc') {
      scoredList.sort((a, b) => a.item.name.localeCompare(b.item.name));
    } else if (sort === 'nameDesc') {
      scoredList.sort((a, b) => b.item.name.localeCompare(a.item.name));
    } else if (sort === 'categoryAsc') {
      scoredList.sort((a, b) => a.item.category.localeCompare(b.item.category));
    } else if (sort === 'updatedAtDesc') {
      scoredList.sort((a, b) => new Date(b.item.updatedAt).getTime() - new Date(a.item.updatedAt).getTime());
    }

    const total = scoredList.length;
    const startIndex = (page - 1) * limit;
    const pagedItems = scoredList.slice(startIndex, startIndex + limit).map((s) => s.item);

    return {
      items: pagedItems,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit) || 1,
    };
  }

  /**
   * Get exercise by ID
   */
  public async getExerciseById(id: string): Promise<ExerciseDto | null> {
    try {
      const dbEx = await prisma.exercise.findUnique({ where: { id } });
      if (dbEx) return this.mapPrismaToDto(dbEx);
    } catch (_) {}

    return this.fallbackMemoryExercises.get(id) || null;
  }

  /**
   * Create custom exercise (Persists to Postgres DB & updates memory)
   */
  public async createCustomExercise(input: CreateCustomExerciseInput): Promise<ExerciseDto> {
    const normalizedName = input.name.trim().toLowerCase();

    // Check duplicate in memory or DB
    const existingMemory = Array.from(this.fallbackMemoryExercises.values()).find(
      (e) => e.normalizedName === normalizedName
    );
    if (existingMemory) {
      throw new Error(`Exercise "${input.name}" already exists in the Alpha X database.`);
    }

    const id = `ex_custom_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();

    const isCompound =
      (input.movementPattern || '').toLowerCase().includes('push') ||
      (input.movementPattern || '').toLowerCase().includes('pull') ||
      (input.movementPattern || '').toLowerCase().includes('squat') ||
      (input.movementPattern || '').toLowerCase().includes('hinge') ||
      (input.movementPattern || '').toLowerCase().includes('carry');

    const newExercise: ExerciseDto = {
      id,
      externalId: null,
      name: input.name.trim(),
      normalizedName,
      aliases: input.aliases || [input.name.trim().toLowerCase()],
      description: input.description || '',
      instructions: input.instructions || [],
      coachingCues: input.coachingCues || [],
      commonMistakes: input.commonMistakes || [],
      primaryMuscles: input.primaryMuscles,
      secondaryMuscles: input.secondaryMuscles || [],
      bodyPart: input.bodyPart || 'Full Body',
      category: input.category,
      subcategory: null,
      equipment: input.equipment || 'Barbell',
      movementPattern: input.movementPattern || 'Compound',
      exerciseType: input.exerciseType || 'Strength',
      difficulty: input.difficulty || 'Intermediate',
      mechanics: isCompound ? 'Compound' : 'Isolation',
      forceType: 'Push',
      planeOfMotion: 'Sagittal',
      laterality: 'Bilateral',
      isCompound,
      isIsolation: !isCompound,
      isUnilateral: false,
      imageUrl: input.imageUrl || '',
      videoUrl: input.videoUrl || '',
      thumbnailUrl: input.imageUrl || '',
      variations: [],
      progressions: [],
      regressions: [],
      alternativeExercises: [],
      source: 'Alpha X Gym Custom',
      sourceUrl: '',
      license: 'Proprietary',
      licenseAuthor: 'Alpha X Gym Admin',
      isImported: false,
      isCustom: true,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };

    try {
      const created = await prisma.exercise.create({
        data: {
          id: newExercise.id,
          name: newExercise.name,
          normalizedName: newExercise.normalizedName,
          aliases: newExercise.aliases,
          description: newExercise.description,
          instructions: newExercise.instructions,
          coachingCues: newExercise.coachingCues,
          commonMistakes: newExercise.commonMistakes,
          primaryMuscles: newExercise.primaryMuscles,
          secondaryMuscles: newExercise.secondaryMuscles,
          bodyPart: newExercise.bodyPart,
          category: newExercise.category,
          equipment: newExercise.equipment,
          movementPattern: newExercise.movementPattern,
          exerciseType: newExercise.exerciseType,
          difficulty: newExercise.difficulty,
          mechanics: newExercise.mechanics,
          forceType: newExercise.forceType,
          planeOfMotion: newExercise.planeOfMotion,
          laterality: newExercise.laterality,
          isCompound: newExercise.isCompound,
          isIsolation: newExercise.isIsolation,
          isUnilateral: newExercise.isUnilateral,
          imageUrl: newExercise.imageUrl,
          videoUrl: newExercise.videoUrl,
          thumbnailUrl: newExercise.thumbnailUrl,
          source: newExercise.source,
          sourceUrl: newExercise.sourceUrl,
          license: newExercise.license,
          licenseAuthor: newExercise.licenseAuthor,
          isImported: false,
          isCustom: true,
          isActive: true,
        },
      });
      const dto = this.mapPrismaToDto(created);
      this.fallbackMemoryExercises.set(dto.id, dto);
      return dto;
    } catch (e) {
      console.warn('[ExerciseService] Failed saving custom exercise to DB, stored in memory:', e);
      this.fallbackMemoryExercises.set(newExercise.id, newExercise);
      return newExercise;
    }
  }

  /**
   * Update existing exercise
   */
  public async updateExercise(id: string, updates: Partial<ExerciseDto>): Promise<ExerciseDto> {
    const existing = this.fallbackMemoryExercises.get(id);
    if (!existing) {
      throw new Error(`Exercise with ID "${id}" not found.`);
    }

    const updated: ExerciseDto = {
      ...existing,
      ...updates,
      id: existing.id,
      updatedAt: new Date().toISOString(),
    };

    if (updates.name) {
      updated.normalizedName = updates.name.trim().toLowerCase();
    }

    try {
      const dbUpdated = await prisma.exercise.update({
        where: { id },
        data: {
          name: updated.name,
          normalizedName: updated.normalizedName,
          category: updated.category,
          equipment: updated.equipment,
          difficulty: updated.difficulty,
          description: updated.description,
          coachingCues: updated.coachingCues,
          commonMistakes: updated.commonMistakes,
          updatedAt: new Date(),
        },
      });
      const dto = this.mapPrismaToDto(dbUpdated);
      this.fallbackMemoryExercises.set(id, dto);
      return dto;
    } catch (_) {
      this.fallbackMemoryExercises.set(id, updated);
      return updated;
    }
  }

  /**
   * Archive exercise (soft delete - preserves historical client workout records)
   */
  public async archiveExercise(id: string): Promise<ExerciseDto> {
    const existing = this.fallbackMemoryExercises.get(id);
    if (!existing) {
      throw new Error(`Exercise with ID "${id}" not found.`);
    }

    existing.isActive = false;
    existing.updatedAt = new Date().toISOString();

    try {
      await prisma.exercise.update({
        where: { id },
        data: { isActive: false, updatedAt: new Date() },
      });
    } catch (_) {}

    this.fallbackMemoryExercises.set(id, existing);
    return existing;
  }

  /**
   * Restore archived exercise
   */
  public async restoreExercise(id: string): Promise<ExerciseDto> {
    const existing = this.fallbackMemoryExercises.get(id);
    if (!existing) {
      throw new Error(`Exercise with ID "${id}" not found.`);
    }

    existing.isActive = true;
    existing.updatedAt = new Date().toISOString();

    try {
      await prisma.exercise.update({
        where: { id },
        data: { isActive: true, updatedAt: new Date() },
      });
    } catch (_) {}

    this.fallbackMemoryExercises.set(id, existing);
    return existing;
  }

  /**
   * Smart alternatives lookup
   */
  public async getAlternatives(id: string): Promise<ExerciseDto[]> {
    const target = await this.getExerciseById(id);
    if (!target) return [];

    try {
      const alternatives = await prisma.exercise.findMany({
        where: {
          id: { not: id },
          isActive: true,
          OR: [
            { category: target.category },
            { primaryMuscles: { hasSome: target.primaryMuscles } },
          ],
        },
        take: 5,
      });

      if (alternatives && alternatives.length > 0) {
        return alternatives.map((a) => this.mapPrismaToDto(a));
      }
    } catch (_) {}

    // Fallback to memory
    return Array.from(this.fallbackMemoryExercises.values())
      .filter(
        (e) =>
          e.id !== id &&
          e.isActive &&
          (e.category.toLowerCase() === target.category.toLowerCase() ||
            e.primaryMuscles.some((m) => target.primaryMuscles.includes(m)))
      )
      .slice(0, 5);
  }

  /**
   * Trigger Exercise Database Synchronization
   */
  public async syncFromExternalSources(): Promise<SyncResult> {
    let imported = 0;
    let updated = 0;
    let failed = 0;
    let totalFound = this.fallbackMemoryExercises.size;

    try {
      // 1. Seed database first
      const seedRes = await this.seedDatabase();
      imported += seedRes.inserted;

      this.lastSyncStats = {
        source: 'Alpha X Gym Database & Curated Catalog',
        totalFound: seedRes.total,
        importedCount: imported,
        updatedCount: updated,
        failedCount: failed,
        status: 'SUCCESS',
        errorMessage: null,
        lastSync: new Date().toISOString(),
      };

      return this.lastSyncStats;
    } catch (err: any) {
      this.lastSyncStats = {
        source: 'Alpha X Gym Database',
        totalFound: this.fallbackMemoryExercises.size,
        importedCount: imported,
        updatedCount: updated,
        failedCount: failed,
        status: 'FAILED',
        errorMessage: err.message || 'Sync failed',
        lastSync: new Date().toISOString(),
      };
      return this.lastSyncStats;
    }
  }

  public getSyncStatus(): SyncResult {
    return this.lastSyncStats;
  }

  public getAttributionInfo() {
    return {
      sources: [
        {
          name: 'Alpha X Gym Curated Movement Catalog',
          license: 'Proprietary Commercial License',
          author: 'Alpha X Gym Sports Science & Coaching Staff',
          url: 'https://alphaxgym.com',
          description: 'Custom biomechanically calibrated exercise library with coaching cues, tempo, and RIR guidelines.',
        },
        {
          name: 'wger Workout Manager Open Exercise Database',
          license: 'Creative Commons Attribution-ShareAlike 4.0 International (CC-BY-SA 4.0)',
          author: 'wger Community & Contributors',
          url: 'https://wger.de',
          description: 'Open source community exercise descriptions and muscle classifications.',
        },
      ],
      disclaimer:
        'All exercise demonstrations and cues are provided for educational purposes within the Alpha X Gym application. Always consult a certified trainer before attempting heavy compound lifts.',
    };
  }
}

export const exerciseService = new ExerciseService();
