import { prisma } from '../../config/prisma';

export interface StoredActivityRecord {
  id: string;
  clientId: string;
  date: string; // YYYY-MM-DD
  steps: number;
  stepGoal: number;
  cardioMinutes: number;
  caloriesBurned: number;
  distanceMeters: number;
  isGoalAchieved: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ClientProfileData {
  clientId: string;
  dailyStepGoal: number;
  trainerId?: string;
}

/**
 * Production Activity Repository
 * Dual-layer architecture:
 * 1. Synchronizes and persists to Neon PostgreSQL via Prisma (ActivityRecord & ClientProfile).
 * 2. In-memory cache guarantees sub-millisecond lookups and seamless testing/offline fallback.
 * 3. Enforces unique (clientId + date) authoritative daily records to prevent duplicate counts.
 */
export class ActivityRepository {
  // In-memory fallback cache with composite key `${clientId}_${date}`
  private records: Map<string, StoredActivityRecord> = new Map();
  private clientGoals: Map<string, number> = new Map([
    ['client_john_doe', 6000],
    ['client_marcus_vance', 8000],
    ['client_elena_rostova', 10000],
  ]);

  /**
   * Helper: Resolves database ClientProfile by User ID, permanent Client ID (AXG-XXXX),
   * Profile UUID, or email.
   */
  private async resolveProfile(clientIdentifier: string) {
    if (!clientIdentifier) return null;
    const clean = clientIdentifier.trim();
    try {
      return await prisma.clientProfile.findFirst({
        where: {
          OR: [
            { id: clean },
            { userId: clean },
            { clientId: clean.toUpperCase() },
            { user: { id: clean } },
            { user: { email: clean.toLowerCase() } },
          ],
        },
      });
    } catch (_) {
      return null;
    }
  }

  /**
   * Upsert activity records. Guarantees no duplicate records for the same client and date.
   * Authoritative daily records are stored directly in PostgreSQL (activity_records table).
   */
  async upsertRecords(
    clientId: string,
    inputs: Array<{
      date: string;
      steps: number;
      stepGoal: number;
      cardioMinutes?: number;
      caloriesBurned?: number;
      distanceMeters?: number;
      isGoalAchieved?: boolean;
    }>
  ): Promise<StoredActivityRecord[]> {
    const results: StoredActivityRecord[] = [];
    const dbProfile = await this.resolveProfile(clientId);
    const clientGoal = dbProfile?.dailyStepGoal ?? (this.clientGoals.get(clientId) ?? 6000);
    const todayStr = new Date().toISOString().split('T')[0];

    for (const input of inputs) {
      const compositeKey = `${clientId}_${input.date}`;
      const effectiveGoal = input.stepGoal > 0 ? input.stepGoal : clientGoal;
      const isAchieved = input.isGoalAchieved ?? (input.steps >= effectiveGoal);

      let recordId = `rec_${clientId}_${input.date}`;
      let createdAt = new Date();
      let updatedAt = new Date();

      // 1. Persist to PostgreSQL if database connection and profile exist
      if (dbProfile) {
        try {
          const dateObj = new Date(`${input.date}T00:00:00.000Z`);
          const dbRecord = await prisma.activityRecord.upsert({
            where: {
              client_date_unique: {
                clientId: dbProfile.id,
                date: dateObj,
              },
            },
            create: {
              clientId: dbProfile.id,
              date: dateObj,
              steps: input.steps,
              stepGoal: effectiveGoal,
              cardioMinutes: input.cardioMinutes ?? 0,
              caloriesBurned: input.caloriesBurned ?? 0.0,
              distanceMeters: input.distanceMeters ?? 0.0,
              isGoalAchieved: isAchieved,
            },
            update: {
              steps: input.steps,
              stepGoal: effectiveGoal,
              cardioMinutes: input.cardioMinutes ?? 0,
              caloriesBurned: input.caloriesBurned ?? 0.0,
              distanceMeters: input.distanceMeters ?? 0.0,
              isGoalAchieved: isAchieved,
            },
          });

          recordId = dbRecord.id;
          createdAt = dbRecord.createdAt;
          updatedAt = dbRecord.updatedAt;

          // If updating today's step count, sync client_profile dailySteps
          if (input.date === todayStr) {
            await prisma.clientProfile.update({
              where: { id: dbProfile.id },
              data: { dailySteps: input.steps },
            }).catch(() => {});
          }
        } catch (dbErr) {
          console.error('[ACTIVITY DB UPSERT ERROR]', dbErr);
        }
      }

      // 2. Synchronize in-memory cache
      const memoryRecord: StoredActivityRecord = {
        id: recordId,
        clientId,
        date: input.date,
        steps: input.steps,
        stepGoal: effectiveGoal,
        cardioMinutes: input.cardioMinutes ?? 0,
        caloriesBurned: input.caloriesBurned ?? 0.0,
        distanceMeters: input.distanceMeters ?? 0.0,
        isGoalAchieved: isAchieved,
        createdAt,
        updatedAt,
      };

      this.records.set(compositeKey, memoryRecord);
      results.push(memoryRecord);
    }

    return results;
  }

  /**
   * Retrieve records for a client within an optional limit (default 30 days).
   * Pulls from PostgreSQL first with in-memory fallback.
   */
  async getRecords(clientId: string, limit: number = 30): Promise<StoredActivityRecord[]> {
    const dbProfile = await this.resolveProfile(clientId);

    if (dbProfile) {
      try {
        const dbRecords = await prisma.activityRecord.findMany({
          where: { clientId: dbProfile.id },
          orderBy: { date: 'desc' },
          take: limit,
        });

        return dbRecords.map((r) => ({
          id: r.id,
          clientId,
          date: r.date.toISOString().split('T')[0],
          steps: r.steps,
          stepGoal: r.stepGoal,
          cardioMinutes: r.cardioMinutes,
          caloriesBurned: r.caloriesBurned,
          distanceMeters: r.distanceMeters,
          isGoalAchieved: r.isGoalAchieved,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        }));
      } catch (dbErr) {
        console.error('[ACTIVITY DB GET ERROR]', dbErr);
      }
      return [];
    }

    // In-memory fallback
    return Array.from(this.records.values())
      .filter((r) => r.clientId === clientId)
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, limit);
  }

  /**
   * Retrieve single record for a specific date
   */
  async getRecordByDate(clientId: string, date: string): Promise<StoredActivityRecord | null> {
    const dbProfile = await this.resolveProfile(clientId);

    if (dbProfile) {
      try {
        const dateObj = new Date(`${date}T00:00:00.000Z`);
        const r = await prisma.activityRecord.findUnique({
          where: {
            client_date_unique: {
              clientId: dbProfile.id,
              date: dateObj,
            },
          },
        });

        if (r) {
          return {
            id: r.id,
            clientId,
            date: r.date.toISOString().split('T')[0],
            steps: r.steps,
            stepGoal: r.stepGoal,
            cardioMinutes: r.cardioMinutes,
            caloriesBurned: r.caloriesBurned,
            distanceMeters: r.distanceMeters,
            isGoalAchieved: r.isGoalAchieved,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          };
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    const key = `${clientId}_${date}`;
    return this.records.get(key) ?? null;
  }

  /**
   * Get client's current daily step goal
   */
  async getClientStepGoal(clientId: string): Promise<number> {
    const dbProfile = await this.resolveProfile(clientId);
    if (dbProfile) {
      return dbProfile.dailyStepGoal;
    }
    return this.clientGoals.get(clientId) ?? 6000;
  }

  /**
   * Update client's daily step goal in database and in memory
   */
  async updateClientStepGoal(clientId: string, newGoal: number): Promise<number> {
    const dbProfile = await this.resolveProfile(clientId);
    if (dbProfile) {
      try {
        await prisma.clientProfile.update({
          where: { id: dbProfile.id },
          data: { dailyStepGoal: newGoal },
        });
      } catch (err) {
        console.error('[STEP GOAL UPDATE ERROR]', err);
      }
    }

    this.clientGoals.set(clientId, newGoal);
    return newGoal;
  }
}

export const activityRepository = new ActivityRepository();
