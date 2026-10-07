import { prisma } from '../../config/prisma';
import { mealPhotoStorageService } from './meal_photo_storage.service';

export interface FoodPhotoCleanupResult {
  totalProcessed: number;
  filesDeleted: number;
  recordsUpdated: number;
  errorsCount: number;
  cleanedPhotoIds: string[];
  cutoffTimestamp: Date;
  retentionDays: number;
  durationMs: number;
}

export class FoodPhotoCleanupService {
  /**
   * Automatically deletes client food journal photos older than the retention threshold (default: 15 days).
   *
   * STRICT GUARANTEES:
   * 1. Evaluates actual upload/creation timestamp (createdAt), NEVER the food-log date.
   * 2. Deletes the physical image file from storage (both primary and tmp fallback).
   * 3. Releases storage references / base64 payload from MealPhoto (isDeleted = true, storagePath = '').
   * 4. Updates linked ClientFoodLog (photoAvailable = false, mealPhotoId = null).
   * 5. Strictly PRESERVES all food-log records, calories, protein, carbs, fat, fiber.
   * 6. Does NOT touch other client photos (transformation milestone photos, avatars).
   * 7. Handles missing/already-deleted storage files safely without crashing.
   * 8. Safe to run repeatedly (idempotent).
   */
  public async cleanupExpiredFoodPhotos(retentionDays: number = 15): Promise<FoodPhotoCleanupResult> {
    const startTime = Date.now();
    const retentionMs = retentionDays * 24 * 60 * 60 * 1000;
    const cutoffTimestamp = new Date(Date.now() - retentionMs);

    console.log(`[FOOD PHOTO CLEANUP] Starting 15-day storage cleanup sweep. Cutoff: ${cutoffTimestamp.toISOString()} (Retention: ${retentionDays} days)`);

    // Find all meal photos created on or before the cutoff timestamp that have not yet had their storage cleaned
    const expiredPhotos = await prisma.mealPhoto.findMany({
      where: {
        createdAt: { lte: cutoffTimestamp },
        OR: [
          { isDeleted: false },
          { storagePath: { not: '' } },
        ],
      },
      select: {
        id: true,
        storagePath: true,
        clientProfileId: true,
        clientId: true,
        createdAt: true,
        dateString: true,
        mealType: true,
      },
    });

    console.log(`[FOOD PHOTO CLEANUP] Found ${expiredPhotos.length} expired food photos eligible for file deletion`);

    let filesDeletedCount = 0;
    let recordsUpdatedCount = 0;
    let errorsCount = 0;
    const cleanedPhotoIds: string[] = [];

    for (const photo of expiredPhotos) {
      try {
        // 1. Delete physical file from storage
        let fileWasDeleted = false;
        if (photo.storagePath && photo.storagePath.trim()) {
          fileWasDeleted = await mealPhotoStorageService.deleteFile(photo.storagePath);
          if (fileWasDeleted) {
            filesDeletedCount++;
          }
        }

        // 2. Mark photo as deleted in database and wipe storage path to free embedded storage/base64
        await prisma.mealPhoto.update({
          where: { id: photo.id },
          data: {
            isDeleted: true,
            deletedAt: new Date(),
            storagePath: '', // Releases storage reference & base64 memory
          },
        });

        // 3. Update linked food logs: set photoAvailable to false, keep all food log & macro records 100% intact
        await prisma.clientFoodLog.updateMany({
          where: { mealPhotoId: photo.id },
          data: {
            photoAvailable: false,
            mealPhotoId: null,
          },
        });

        recordsUpdatedCount++;
        cleanedPhotoIds.push(photo.id);
      } catch (err: any) {
        errorsCount++;
        console.error(`[FOOD PHOTO CLEANUP] Error cleaning photo ${photo.id}:`, err?.message || err);
      }
    }

    const durationMs = Date.now() - startTime;
    console.log(
      `[FOOD PHOTO CLEANUP] Sweep finished in ${durationMs}ms: ` +
      `Processed ${expiredPhotos.length}, Physical files removed: ${filesDeletedCount}, ` +
      `DB records updated: ${recordsUpdatedCount}, Errors: ${errorsCount}`
    );

    return {
      totalProcessed: expiredPhotos.length,
      filesDeleted: filesDeletedCount,
      recordsUpdated: recordsUpdatedCount,
      errorsCount,
      cleanedPhotoIds,
      cutoffTimestamp,
      retentionDays,
      durationMs,
    };
  }

  /**
   * Helper to check if a specific photo upload timestamp is older than retention threshold
   */
  public isPhotoExpired(createdAt: Date, retentionDays: number = 15): boolean {
    const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
    return new Date(createdAt).getTime() <= cutoff;
  }

  /**
   * Retrieve storage and retention health metrics
   */
  public async getStorageStatistics() {
    const activePhotosCount = await prisma.mealPhoto.count({
      where: { isDeleted: false },
    });

    const deletedPhotosCount = await prisma.mealPhoto.count({
      where: { isDeleted: true },
    });

    const cutoff15Days = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000);
    const expiredPendingCleanup = await prisma.mealPhoto.count({
      where: {
        createdAt: { lte: cutoff15Days },
        isDeleted: false,
      },
    });

    return {
      activePhotosCount,
      deletedPhotosCount,
      expiredPendingCleanup,
      retentionPolicyDays: 15,
    };
  }
}

export const foodPhotoCleanupService = new FoodPhotoCleanupService();
