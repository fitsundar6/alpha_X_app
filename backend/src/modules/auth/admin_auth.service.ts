import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { env, isProduction } from '../../config/environment';
import { UserRole } from '../../constants/roles';
import { prisma } from '../../config/prisma';

/**
 * Service managing secure single-administrator authentication & verification.
 *
 * Security Guarantees:
 * 1. Exactly ONE administrator account identified by env.ADMIN_EMAIL.
 * 2. Password verified using bcrypt with constant-time comparison.
 * 3. Never logs, prints, or exposes plain-text passwords or hashes.
 * 4. Supports pre-computed bcrypt hash (ADMIN_PASSWORD_HASH) or secure env password (ADMIN_PASSWORD).
 * 5. BUG-04: Durable PostgreSQL-backed session revocation across Vercel serverless containers.
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
   * Resets the singleton instance (strictly for testing cold starts / serverless recycling).
   */
  public static resetInstanceForTesting(): void {
    (AdminAuthService as any).instance = undefined;
  }

  /**
   * Computes SHA-256 hash of a raw token for storage in the revocation blacklist.
   */
  public hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /**
   * Durably revokes an active master administrator session in PostgreSQL.
   * Uses actual JWT expiry (from exp claim) or 30-day default fallback.
   */
  public async revokeAdminSession(
    sessionId?: string,
    rawToken?: string,
    customExpiresAt?: Date,
    reason = 'LOGOUT'
  ): Promise<void> {
    if (!sessionId && !rawToken) return;

    let expiresAt = customExpiresAt;
    if (!expiresAt && rawToken) {
      try {
        const decoded = jwt.decode(rawToken) as any;
        if (decoded && typeof decoded.exp === 'number') {
          expiresAt = new Date(decoded.exp * 1000);
        }
      } catch (_) {
        // fallback to default below
      }
    }
    if (!expiresAt) {
      expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    }

    const tokenHash = rawToken ? this.hashToken(rawToken) : null;
    const adminEmail = this.getAdminEmail();

    try {
      await prisma.revokedAdminSession.create({
        data: {
          sessionId: sessionId || null,
          tokenHash,
          adminEmail,
          reason,
          expiresAt,
        },
      });
    } catch (err: any) {
      // If already revoked (Prisma unique constraint P2002), treat as success
      if (err?.code === 'P2002') {
        return;
      }
      throw err;
    }
  }

  /**
   * Revokes a specific admin JWT by its cryptographic hash.
   */
  public async revokeAdminToken(rawToken: string, customExpiresAt?: Date): Promise<void> {
    await this.revokeAdminSession(undefined, rawToken, customExpiresAt);
  }

  /**
   * Checks whether a given admin session ID or raw token hash has been revoked in PostgreSQL.
   * Throws if database is unreachable, enabling callers to FAIL CLOSED.
   */
  public async isRevoked(sessionId?: string, rawToken?: string): Promise<boolean> {
    const tokenHash = rawToken ? this.hashToken(rawToken) : undefined;
    const orConditions: any[] = [];
    if (sessionId && typeof sessionId === 'string' && sessionId.trim().length > 0) {
      orConditions.push({ sessionId: sessionId.trim() });
    }
    if (tokenHash) {
      orConditions.push({ tokenHash });
    }
    if (orConditions.length === 0) {
      return false;
    }

    const revoked = await prisma.revokedAdminSession.findFirst({
      where: {
        OR: orConditions,
      },
      select: { id: true },
    });
    return Boolean(revoked);
  }

  /**
   * Clears the revocation registry (strictly for testing).
   */
  public async clearRevocationsForTesting(): Promise<void> {
    try {
      await prisma.revokedAdminSession.deleteMany({});
    } catch (_) {
      // ignore if table does not exist or test environment mock handles it
    }
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
    if (isProduction()) {
      console.error('❌ CRITICAL SECURITY ERROR: Neither ADMIN_PASSWORD_HASH nor ADMIN_PASSWORD is set in production environment!');
      process.exit(1);
    } else {
      // Fail safely: do not set a static default password hash. Require explicit configuration.
      this.activePasswordHash = null;
      console.warn('⚠️  [SECURITY NOTICE]: ADMIN_PASSWORD or ADMIN_PASSWORD_HASH not detected in environment.');
      console.warn('⚠️  Admin authentication is disabled until ADMIN_PASSWORD or ADMIN_PASSWORD_HASH is explicitly configured.');
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
  public generateAdminSession(customSessionId?: string): {
    token: string;
    user: {
      id: string;
      email: string;
      name: string;
      role: UserRole;
      sessionId: string;
    };
  } {
    const adminEmail = this.getAdminEmail();
    const id = env.ADMIN_ID || `admin_${adminEmail.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '_')}`.toLowerCase();
    const name = 'Alpha X Administrator';
    const role = UserRole.ADMIN;
    const sessionId = customSessionId || crypto.randomUUID();

    const token = jwt.sign(
      {
        id,
        email: adminEmail,
        role,
        sessionId,
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
        sessionId,
      },
    };
  }

  /**
   * Returns a cryptographic snippet of the active password hash (used for single-use token binding).
   */
  public async getActivePasswordHashSnippet(): Promise<string> {
    if (!this.activePasswordHash) {
      await this.initializePasswordHash();
    }
    return (this.activePasswordHash || '').slice(-10);
  }

  /**
   * Updates the in-memory active master administrator password hash using bcrypt (12 rounds).
   */
  public async updateAdminPassword(newPassword: string): Promise<void> {
    this.activePasswordHash = await bcrypt.hash(newPassword, 12);
  }
}

export const adminAuthService = AdminAuthService.getInstance();
