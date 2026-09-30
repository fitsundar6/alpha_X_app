import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/environment';
import { UserRole } from '../../constants/roles';

/**
 * Service managing secure single-administrator authentication & verification.
 *
 * Security Guarantees:
 * 1. Exactly ONE administrator account identified by env.ADMIN_EMAIL.
 * 2. Password verified using bcrypt with constant-time comparison.
 * 3. Never logs, prints, or exposes plain-text passwords or hashes.
 * 4. Supports pre-computed bcrypt hash (ADMIN_PASSWORD_HASH) or secure env password (ADMIN_PASSWORD).
 */
export class AdminAuthService {
  private static instance: AdminAuthService;
  private activePasswordHash: string | null = null;

  private constructor() {
    this.initializePasswordHash();
  }

  public static getInstance(): AdminAuthService {
    if (!AdminAuthService.instance) {
      AdminAuthService.instance = new AdminAuthService();
    }
    return AdminAuthService.instance;
  }

  /**
   * Initializes the secure bcrypt password hash from environment variables.
   * Priority:
   *   1. env.ADMIN_PASSWORD_HASH (recommended production standard)
   *   2. env.ADMIN_PASSWORD (plain password hashed with bcrypt 12 rounds on boot)
   *   3. Fallback dev hash for local offline development (logged with warning)
   */
  private async initializePasswordHash(): Promise<void> {
    if (env.ADMIN_PASSWORD_HASH && env.ADMIN_PASSWORD_HASH.trim().length > 0) {
      this.activePasswordHash = env.ADMIN_PASSWORD_HASH.trim();
      return;
    }

    if (env.ADMIN_PASSWORD && env.ADMIN_PASSWORD.trim().length > 0) {
      // Pre-compute bcrypt hash on startup with cost factor 12
      this.activePasswordHash = await bcrypt.hash(env.ADMIN_PASSWORD.trim(), 12);
      return;
    }

    // If neither is set:
    if (env.NODE_ENV === 'production') {
      console.error('❌ CRITICAL SECURITY ERROR: Neither ADMIN_PASSWORD_HASH nor ADMIN_PASSWORD is set in production environment!');
      process.exit(1);
    } else {
      // In development only: fallback to a known dev hash for 'AlphaXAdmin2026!'
      // Generated with bcrypt salt rounds 12
      this.activePasswordHash = '$2b$12$e0lXq9aVqG0Ew8w8oKqjVu4pI29nS/jR/qVl32h7jF7Q4D4y8eYCe';
      console.warn('⚠️  [SECURITY NOTICE]: ADMIN_PASSWORD or ADMIN_PASSWORD_HASH not detected in .env.');
      console.warn('⚠️  Using development admin hash. In production, configure ADMIN_PASSWORD_HASH in environment variables.');
    }
  }

  /**
   * Returns the normalized Master Admin email address.
   */
  public getAdminEmail(): string {
    return env.ADMIN_EMAIL.trim().toLowerCase();
  }

  /**
   * Validates whether candidate email matches master admin email.
   */
  public isMasterAdminEmail(candidateEmail: string): boolean {
    if (!candidateEmail || typeof candidateEmail !== 'string') return false;
    return candidateEmail.trim().toLowerCase() === this.getAdminEmail();
  }

  /**
   * Cryptographically verifies administrator credentials using bcrypt.
   * Does NOT reveal whether email or password was incorrect.
   */
  public async verifyAdminCredentials(email: string, candidatePassword: string): Promise<boolean> {
    if (!this.isMasterAdminEmail(email)) {
      return false;
    }

    if (!candidatePassword || typeof candidatePassword !== 'string' || candidatePassword.length === 0) {
      return false;
    }

    if (!this.activePasswordHash) {
      await this.initializePasswordHash();
    }

    if (!this.activePasswordHash) {
      return false;
    }

    // Cryptographic constant-time comparison via bcrypt
    try {
      return await bcrypt.compare(candidatePassword, this.activePasswordHash);
    } catch (_) {
      return false;
    }
  }

  /**
   * Generates a signed JWT session token for the authorized administrator.
   */
  public generateAdminSession(): {
    token: string;
    user: {
      id: string;
      email: string;
      name: string;
      role: UserRole;
    };
  } {
    const adminEmail = this.getAdminEmail();
    const id = 'admin_alex_stone';
    const name = 'Alpha X Administrator';
    const role = UserRole.ADMIN;

    const token = jwt.sign(
      {
        id,
        email: adminEmail,
        role,
      },
      env.JWT_ACCESS_SECRET,
      {
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );

    return {
      token,
      user: {
        id,
        email: adminEmail,
        name,
        role,
      },
    };
  }
}

export const adminAuthService = AdminAuthService.getInstance();
