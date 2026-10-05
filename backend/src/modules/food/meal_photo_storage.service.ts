import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import os from 'os';
import { Readable } from 'stream';

export interface SavedMealPhotoResult {
  storagePath: string;
  fileSizeBytes: number;
  mimeType: string;
}

export class MealPhotoStorageService {
  private baseStorageDir: string;

  constructor() {
    this.baseStorageDir = this.resolveBaseStorageDir();
    this.ensureBaseDirectory();
  }

  /**
   * Determine safe, writable base storage directory depending on environment.
   * In Vercel, AWS Lambda, or serverless environments, root is strictly read-only,
   * so os.tmpdir() is used.
   */
  private resolveBaseStorageDir(): string {
    if (process.env.STORAGE_DIR) {
      return path.resolve(process.env.STORAGE_DIR);
    }

    const isServerless = Boolean(
      process.env.VERCEL ||
      process.env.AWS_LAMBDA_FUNCTION_NAME ||
      process.env.LAMBDA_TASK_ROOT ||
      __dirname.startsWith('/var/task')
    );

    if (isServerless) {
      return path.join(os.tmpdir(), 'alpha_x_uploads', 'meal_photos');
    }

    return path.resolve(__dirname, '../../../uploads/meal_photos');
  }

  /**
   * Ensure directory exists, falling back to os.tmpdir() if filesystem permissions fail.
   */
  private ensureBaseDirectory(): void {
    try {
      if (!fs.existsSync(this.baseStorageDir)) {
        fs.mkdirSync(this.baseStorageDir, { recursive: true });
      }
    } catch (err) {
      console.warn('[STORAGE SERVICE] Could not initialize default storage directory, falling back to os.tmpdir():', err);
      try {
        this.baseStorageDir = path.join(os.tmpdir(), 'alpha_x_uploads', 'meal_photos');
        if (!fs.existsSync(this.baseStorageDir)) {
          fs.mkdirSync(this.baseStorageDir, { recursive: true });
        }
      } catch (fallbackErr) {
        console.error('[STORAGE SERVICE] Failed to initialize fallback temp directory:', fallbackErr);
      }
    }
  }

  /**
   * Save a confirmed meal photo buffer to secure storage.
   * Embeds Base64 representation in hybrid storagePath so photos are permanently available
   * across ephemeral serverless container recycles and multi-container serverless instances.
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
    const fullFilePath = path.join(clientDir, uniqueFileId);

    // Save to disk (persisted in traditional hosting, acts as instant fast cache in serverless)
    try {
      if (!fs.existsSync(clientDir)) {
        fs.mkdirSync(clientDir, { recursive: true });
      }
      await fs.promises.writeFile(fullFilePath, buffer);
    } catch (diskErr) {
      console.warn('[STORAGE SERVICE] Primary disk write failed, attempting /tmp fallback:', diskErr);
      try {
        const tmpClientDir = path.join(os.tmpdir(), 'alpha_x_uploads', 'meal_photos', safeClientId, year, month);
        if (!fs.existsSync(tmpClientDir)) {
          fs.mkdirSync(tmpClientDir, { recursive: true });
        }
        await fs.promises.writeFile(path.join(tmpClientDir, uniqueFileId), buffer);
      } catch (tmpErr) {
        console.warn('[STORAGE SERVICE] Disk caching write failed entirely (persisting via DB):', tmpErr);
      }
    }

    // Relative storage path for DB reference and legacy file matching
    const relativeStoragePath = `${safeClientId}/${year}/${month}/${uniqueFileId}`;

    // Hybrid storage: embeds DB Base64 fallback to ensure photo persists across serverless container recycles
    const cleanBase64 = buffer.toString('base64');
    const hybridStoragePath = `db:${relativeStoragePath}:::data:${mimeType};base64,${cleanBase64}`;

    return {
      storagePath: hybridStoragePath,
      fileSizeBytes: buffer.length,
      mimeType,
    };
  }

  /**
   * Helper: Extracts relative file path from storagePath (handles hybrid and legacy formats)
   */
  public extractRelativePath(storagePath: string): string {
    if (!storagePath) return '';
    if (storagePath.includes(':::data:')) {
      const dbPart = storagePath.split(':::data:')[0];
      return dbPart.replace(/^db:/, '');
    }
    if (storagePath.startsWith('data:') || storagePath.startsWith('base64:')) {
      return 'embedded_image.jpg';
    }
    return storagePath;
  }

  /**
   * Resolve absolute file path from relative storage path.
   * If file is not present on disk but embedded data is available, materializes it to disk cache.
   */
  public getAbsoluteFilePath(relativeStoragePath: string): string {
    const rel = this.extractRelativePath(relativeStoragePath);
    const normalized = path.normalize(rel).replace(/^(\.\.[\/\\])+/, '');
    const candidatePath = path.join(this.baseStorageDir, normalized);

    // If file doesn't exist on disk but we have embedded data, materialize it to disk cache
    if (!fs.existsSync(candidatePath) && relativeStoragePath.includes(':::data:')) {
      try {
        const base64Part = relativeStoragePath.split(':::data:')[1];
        const commaIdx = base64Part.indexOf(',');
        const rawBase64 = commaIdx >= 0 ? base64Part.substring(commaIdx + 1) : base64Part;
        const buf = Buffer.from(rawBase64, 'base64');
        const parentDir = path.dirname(candidatePath);
        if (!fs.existsSync(parentDir)) {
          fs.mkdirSync(parentDir, { recursive: true });
        }
        fs.writeFileSync(candidatePath, buf);
      } catch (err) {
        console.warn('[STORAGE SERVICE] Could not materialize cached file to disk:', err);
      }
    }

    return candidatePath;
  }

  /**
   * Check if file exists (either in filesystem or embedded in storagePath)
   */
  public fileExists(relativeStoragePath: string): boolean {
    if (!relativeStoragePath) return false;
    if (relativeStoragePath.includes(':::data:') || relativeStoragePath.startsWith('data:') || relativeStoragePath.startsWith('base64:')) {
      return true;
    }
    const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
    if (fs.existsSync(fullPath)) return true;

    // Check temp directory fallback
    const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'meal_photos', this.extractRelativePath(relativeStoragePath));
    return fs.existsSync(tmpFallback);
  }

  /**
   * Get readable file stream for streaming to authenticated client/admin.
   * If embedded in DB, streams directly from memory buffer (instant, 0 disk I/O, serverless-safe).
   */
  public getFileStream(relativeStoragePath: string): Readable {
    // If embedded data is available, stream directly from buffer (instant & 100% reliable across serverless nodes)
    if (relativeStoragePath.includes(':::data:') || relativeStoragePath.startsWith('data:')) {
      const dataUri = relativeStoragePath.includes(':::data:')
        ? relativeStoragePath.split(':::data:')[1]
        : relativeStoragePath;
      const commaIdx = dataUri.indexOf(',');
      const rawBase64 = commaIdx >= 0 ? dataUri.substring(commaIdx + 1) : dataUri;
      const buffer = Buffer.from(rawBase64, 'base64');
      return Readable.from(buffer);
    }

    const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
    if (fs.existsSync(fullPath)) {
      return fs.createReadStream(fullPath);
    }

    // Try temp directory fallback
    const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'meal_photos', this.extractRelativePath(relativeStoragePath));
    if (fs.existsSync(tmpFallback)) {
      return fs.createReadStream(tmpFallback);
    }

    throw new Error('Meal photo file not found in storage.');
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
    const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'meal_photos', this.extractRelativePath(relativeStoragePath));
    if (fs.existsSync(tmpFallback)) {
      try {
        await fs.promises.unlink(tmpFallback);
      } catch (_) {}
    }
  }
}

export const mealPhotoStorageService = new MealPhotoStorageService();
