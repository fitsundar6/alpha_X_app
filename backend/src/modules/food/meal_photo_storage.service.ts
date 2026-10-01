import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

export interface SavedMealPhotoResult {
  storagePath: string;
  fileSizeBytes: number;
  mimeType: string;
}

export class MealPhotoStorageService {
  private baseStorageDir: string;

  constructor() {
    // Stored privately on disk outside of any public web static root
    this.baseStorageDir = process.env.STORAGE_DIR
      ? path.resolve(process.env.STORAGE_DIR)
      : path.resolve(__dirname, '../../../uploads/meal_photos');

    // Ensure root directory exists
    if (!fs.existsSync(this.baseStorageDir)) {
      try {
        fs.mkdirSync(this.baseStorageDir, { recursive: true });
      } catch (err) {
        console.error('[STORAGE SERVICE] Could not initialize storage directory:', err);
      }
    }
  }

  /**
   * Save a confirmed meal photo buffer to secure private storage
   */
  public async saveMealPhoto(
    clientProfileId: string,
    buffer: Buffer,
    mimeType: string = 'image/jpeg'
  ): Promise<SavedMealPhotoResult> {
    if (!buffer || buffer.length === 0) {
      throw new Error('Image payload is empty or invalid.');
    }

    if (buffer.length > 15 * 1024 * 1024) {
      throw new Error('Image exceeds maximum allowable size (15MB).');
    }

    // Determine extension
    let ext = '.jpg';
    if (mimeType.includes('png')) ext = '.png';
    else if (mimeType.includes('webp')) ext = '.webp';

    const now = new Date();
    const year = now.getFullYear().toString();
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const safeClientId = clientProfileId.replace(/[^a-zA-Z0-9_-]/g, '_');
    const uniqueFileId = `${crypto.randomUUID()}${ext}`;

    const clientDir = path.join(this.baseStorageDir, safeClientId, year, month);
    if (!fs.existsSync(clientDir)) {
      fs.mkdirSync(clientDir, { recursive: true });
    }

    const fullFilePath = path.join(clientDir, uniqueFileId);
    await fs.promises.writeFile(fullFilePath, buffer);

    // Compute relative storage path for DB reference
    const relativeStoragePath = path.relative(this.baseStorageDir, fullFilePath).replace(/\\/g, '/');

    return {
      storagePath: relativeStoragePath,
      fileSizeBytes: buffer.length,
      mimeType,
    };
  }

  /**
   * Resolve absolute file path from relative storage path
   */
  public getAbsoluteFilePath(relativeStoragePath: string): string {
    const normalized = path.normalize(relativeStoragePath).replace(/^(\.\.[\/\\])+/, '');
    return path.join(this.baseStorageDir, normalized);
  }

  /**
   * Check if file exists
   */
  public fileExists(relativeStoragePath: string): boolean {
    const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
    return fs.existsSync(fullPath);
  }

  /**
   * Get readable file stream for streaming to authenticated client/admin
   */
  public getFileStream(relativeStoragePath: string): fs.ReadStream {
    const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
    if (!fs.existsSync(fullPath)) {
      throw new Error('Meal photo file not found in storage.');
    }
    return fs.createReadStream(fullPath);
  }

  /**
   * Delete file from storage
   */
  public async deleteFile(relativeStoragePath: string): Promise<void> {
    const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
    if (fs.existsSync(fullPath)) {
      try {
        await fs.promises.unlink(fullPath);
      } catch (err) {
        console.warn(`[STORAGE SERVICE] Failed to delete file ${fullPath}:`, err);
      }
    }
  }
}

export const mealPhotoStorageService = new MealPhotoStorageService();
