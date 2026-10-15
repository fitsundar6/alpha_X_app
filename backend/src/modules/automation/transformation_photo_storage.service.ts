import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import os from 'os';
import { Readable } from 'stream';

export interface SavedTransformationPhotoResult {
  storagePath: string;
  fileSizeBytes: number;
  mimeType: string;
  photoId: string;
}

export class TransformationPhotoStorageService {
  private baseStorageDir: string;

  constructor() {
    this.baseStorageDir = this.resolveBaseStorageDir();
    this.ensureBaseDirectory();
  }

  /**
   * Determine safe writable base storage directory depending on environment.
   */
  private resolveBaseStorageDir(): string {
    if (process.env.STORAGE_DIR) {
      return path.resolve(process.env.STORAGE_DIR, 'transformation_photos');
    }

    const isServerless = Boolean(
      process.env.VERCEL ||
      process.env.AWS_LAMBDA_FUNCTION_NAME ||
      process.env.LAMBDA_TASK_ROOT ||
      __dirname.startsWith('/var/task')
    );

    if (isServerless) {
      return path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos');
    }

    return path.resolve(__dirname, '../../../uploads/transformation_photos');
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
      console.warn('[STORAGE SERVICE] Could not initialize default transformation storage, falling back to os.tmpdir():', err);
      try {
        this.baseStorageDir = path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos');
        if (!fs.existsSync(this.baseStorageDir)) {
          fs.mkdirSync(this.baseStorageDir, { recursive: true });
        }
      } catch (fallbackErr) {
        console.error('[STORAGE SERVICE] Failed to initialize fallback temp directory:', fallbackErr);
      }
    }
  }

  /**
   * Save a transformation progress photo buffer to secure storage.
   * Embeds Base64 representation in hybrid storagePath so photos persist reliably
   * across ephemeral serverless container recycles and multi-container instances.
   */
  public async saveTransformationPhoto(
    clientProfileId: string,
    buffer: Buffer,
    mimeType: string = 'image/jpeg',
    angle: string = 'front'
  ): Promise<SavedTransformationPhotoResult> {
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
    const uniqueFileId = `${crypto.randomUUID()}_${angle.toLowerCase()}${ext}`;

    const clientDir = path.join(this.baseStorageDir, safeClientId, year, month);
    const fullFilePath = path.join(clientDir, uniqueFileId);

    // Save to disk
    try {
      if (!fs.existsSync(clientDir)) {
        fs.mkdirSync(clientDir, { recursive: true });
      }
      await fs.promises.writeFile(fullFilePath, buffer);
    } catch (diskErr) {
      console.warn('[STORAGE SERVICE] Primary disk write failed, attempting /tmp fallback:', diskErr);
      try {
        const tmpClientDir = path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos', safeClientId, year, month);
        if (!fs.existsSync(tmpClientDir)) {
          fs.mkdirSync(tmpClientDir, { recursive: true });
        }
        await fs.promises.writeFile(path.join(tmpClientDir, uniqueFileId), buffer);
      } catch (tmpErr) {
        console.warn('[STORAGE SERVICE] Disk caching write failed entirely (persisting via DB):', tmpErr);
      }
    }

    // Relative storage path
    const relativeStoragePath = `${safeClientId}/${year}/${month}/${uniqueFileId}`;

    // Hybrid storage: embeds DB Base64 fallback to ensure photo persists across container recycles
    const cleanBase64 = buffer.toString('base64');
    const hybridStoragePath = `db:${relativeStoragePath}:::data:${mimeType};base64,${cleanBase64}`;

    return {
      storagePath: hybridStoragePath,
      fileSizeBytes: buffer.length,
      mimeType,
      photoId: uniqueFileId,
    };
  }

  /**
   * Helper: Extracts relative file path from storagePath
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
   * Extracts raw Buffer and mimeType from storagePath (either from embedded base64 or disk)
   */
  public extractBuffer(storagePath: string): { buffer: Buffer; mimeType: string } | null {
    if (!storagePath) return null;

    // 1. Embedded base64
    if (storagePath.includes(':::data:')) {
      try {
        const dataPart = storagePath.split(':::data:')[1];
        const mimeMatch = dataPart.match(/^data:([^;]+);base64,/);
        const mimeType = mimeMatch ? mimeMatch[1] : 'image/jpeg';
        const rawBase64 = dataPart.replace(/^data:[^;]+;base64,/, '');
        const buffer = Buffer.from(rawBase64, 'base64');
        return { buffer, mimeType };
      } catch (e) {
        console.warn('[STORAGE SERVICE] Failed to decode embedded base64:', e);
      }
    }

    if (storagePath.startsWith('data:')) {
      try {
        const mimeMatch = storagePath.match(/^data:([^;]+);base64,/);
        const mimeType = mimeMatch ? mimeMatch[1] : 'image/jpeg';
        const rawBase64 = storagePath.replace(/^data:[^;]+;base64,/, '');
        const buffer = Buffer.from(rawBase64, 'base64');
        return { buffer, mimeType };
      } catch (e) {
        console.warn('[STORAGE SERVICE] Failed to decode data URL:', e);
      }
    }

    // 2. Disk file
    const fullPath = this.getAbsoluteFilePath(storagePath);
    if (fs.existsSync(fullPath)) {
      try {
        const buffer = fs.readFileSync(fullPath);
        let mimeType = 'image/jpeg';
        if (fullPath.endsWith('.png')) mimeType = 'image/png';
        else if (fullPath.endsWith('.webp')) mimeType = 'image/webp';
        return { buffer, mimeType };
      } catch (e) {
        console.warn('[STORAGE SERVICE] Failed to read disk file:', e);
      }
    }

    // 3. Fallback /tmp directory
    const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos', this.extractRelativePath(storagePath));
    if (fs.existsSync(tmpFallback)) {
      try {
        const buffer = fs.readFileSync(tmpFallback);
        let mimeType = 'image/jpeg';
        if (tmpFallback.endsWith('.png')) mimeType = 'image/png';
        else if (tmpFallback.endsWith('.webp')) mimeType = 'image/webp';
        return { buffer, mimeType };
      } catch (e) {
        console.warn('[STORAGE SERVICE] Failed to read temp disk file:', e);
      }
    }

    return null;
  }

  /**
   * Resolve absolute file path from relative storage path.
   */
  public getAbsoluteFilePath(relativeStoragePath: string): string {
    const rel = this.extractRelativePath(relativeStoragePath);
    const normalized = path.normalize(rel).replace(/^(\.\.[\/\\])+/, '');
    const candidatePath = path.join(this.baseStorageDir, normalized);

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

    const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos', this.extractRelativePath(relativeStoragePath));
    return fs.existsSync(tmpFallback);
  }

  /**
   * Get readable file stream for streaming to authenticated client/admin.
   */
  public getFileStream(relativeStoragePath: string): Readable {
    if (relativeStoragePath.includes(':::data:')) {
      const base64Part = relativeStoragePath.split(':::data:')[1];
      const commaIdx = base64Part.indexOf(',');
      const rawBase64 = commaIdx >= 0 ? base64Part.substring(commaIdx + 1) : base64Part;
      const buffer = Buffer.from(rawBase64, 'base64');
      return Readable.from(buffer);
    }

    const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
    if (fs.existsSync(fullPath)) {
      return fs.createReadStream(fullPath);
    }

    const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos', this.extractRelativePath(relativeStoragePath));
    if (fs.existsSync(tmpFallback)) {
      return fs.createReadStream(tmpFallback);
    }

    throw new Error(`File not found: ${relativeStoragePath}`);
  }

  /**
   * Delete file from storage.
   */
  public async deleteFile(relativeStoragePath: string): Promise<void> {
    try {
      const fullPath = this.getAbsoluteFilePath(relativeStoragePath);
      if (fs.existsSync(fullPath)) {
        await fs.promises.unlink(fullPath);
      }
    } catch (_) {}

    try {
      const tmpFallback = path.join(os.tmpdir(), 'alpha_x_uploads', 'transformation_photos', this.extractRelativePath(relativeStoragePath));
      if (fs.existsSync(tmpFallback)) {
        await fs.promises.unlink(tmpFallback);
      }
    } catch (_) {}
  }
}

export const transformationPhotoStorageService = new TransformationPhotoStorageService();
