import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { env } from '../config/environment';
import { prisma } from '../config/prisma';
import { adminAuthService } from '../modules/auth/admin_auth.service';
import { emailService } from './email.service';
import { logActivity } from '../utils/serverLogger';
import { maskEmail } from '../utils/pii_mask';
import { UserRole } from '../constants/roles';

interface ResetTokenPayload {
  userId: string;
  email: string;
  role: string;
  hashSnippet: string;
  jti: string;
  purpose: 'PASSWORD_RESET';
  exp?: number;
}

export interface VerifyTokenResult {
  valid: boolean;
  email?: string;
  role?: string;
  error?: 'TOKEN_EXPIRED' | 'TOKEN_ALREADY_USED' | 'TOKEN_INVALID' | 'USER_NOT_FOUND';
  message?: string;
}

export interface ResetPasswordResult {
  success: boolean;
  message: string;
  error?: string;
}

export interface AdminResetCodeEntry {
  codeId: string;
  userId: string;
  userEmail: string;
  hashedCode: string;
  expiresAt: number;
  attempts: number;
  adminId: string;
  adminEmail: string;
  used: boolean;
  hashSnippet: string;
}

export class PasswordResetService {
  private static instance: PasswordResetService;

  // Single-use token tracking for email-based JWT recovery: map of jti -> expiration timestamp (ms)
  private consumedTokens = new Map<string, number>();

  // In-flight token locks for email-based JWT recovery
  private inFlightTokens = new Set<string>();

  private constructor() {
    // Periodically clean up expired entries in consumedTokens (every 10 minutes)
    const timer = setInterval(() => {
      const now = Date.now();
      for (const [jti, exp] of this.consumedTokens.entries()) {
        if (now > exp) {
          this.consumedTokens.delete(jti);
        }
      }
    }, 10 * 60 * 1000);
    if (timer.unref) {
      timer.unref();
    }
  }

  public static getInstance(): PasswordResetService {
    if (!PasswordResetService.instance) {
      PasswordResetService.instance = new PasswordResetService();
    }
    return PasswordResetService.instance;
  }

  /**
   * Initiates password recovery.
   * Enforces strict anti-enumeration: always returns identical success response.
   */
  public async requestPasswordReset(rawEmail: string): Promise<{ success: boolean; message: string }> {
    const normalizedEmail = (rawEmail || '').trim().toLowerCase();

    // Constant message returned for all requests regardless of user existence
    const antiEnumerationResponse = {
      success: true,
      message: 'If an account exists with this email, a password reset link has been sent.',
    };

    // In production, verify upfront that the email delivery transport is operational.
    // If SMTP is unconfigured in production, fail closed with a uniform service message
    // so no fake "email sent" confirmation is ever generated, preserving strict anti-enumeration.
    if (env.NODE_ENV === 'production' && !emailService.isConfigured()) {
      logActivity({
        statusCode: 503,
        activity: 'PASSWORD_RESET_SERVICE_UNAVAILABLE',
        reason: 'Password reset rejected: SMTP service is not configured in production.',
      });
      return {
        success: false,
        message: 'Password reset service is temporarily unavailable. Please contact your gym administrator.',
      };
    }

    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      return antiEnumerationResponse;
    }

    try {
      const isMasterAdmin = adminAuthService.isMasterAdminEmail(normalizedEmail);

      let targetUser: { id: string; email: string; name: string; role: string; passwordHashSnippet: string } | null = null;

      if (isMasterAdmin) {
        const hashSnippet = await adminAuthService.getActivePasswordHashSnippet();
        targetUser = {
          id: 'admin_alex_stone',
          email: normalizedEmail,
          name: 'Alpha X Administrator',
          role: UserRole.ADMIN,
          passwordHashSnippet: hashSnippet,
        };
      } else {
        const dbUser = await prisma.user.findUnique({
          where: { email: normalizedEmail },
          select: {
            id: true,
            email: true,
            name: true,
            role: true,
            passwordHash: true,
          },
        });

        if (dbUser) {
          targetUser = {
            id: dbUser.id,
            email: dbUser.email,
            name: dbUser.name,
            role: dbUser.role,
            passwordHashSnippet: (dbUser.passwordHash || '').slice(-10),
          };
        }
      }

      if (!targetUser) {
        // User does not exist: simulate realistic hashing/dispatch latency to prevent timing attacks
        await new Promise((resolve) => setTimeout(resolve, 250 + Math.random() * 150));
        logActivity({
          statusCode: 200,
          activity: 'PASSWORD_RESET_NON_EXISTENT_EMAIL',
          reason: `Password reset requested for non-existent email: ${maskEmail(normalizedEmail)}. Suppressed via anti-enumeration.`,
        });
        return antiEnumerationResponse;
      }

      // Generate cryptographically secure single-use token (valid for 15 minutes)
      const jti = crypto.randomUUID();
      const tokenPayload: ResetTokenPayload = {
        userId: targetUser.id,
        email: targetUser.email,
        role: targetUser.role,
        hashSnippet: targetUser.passwordHashSnippet,
        jti,
        purpose: 'PASSWORD_RESET',
      };

      const resetToken = jwt.sign(tokenPayload, env.JWT_ACCESS_SECRET, {
        expiresIn: '15m',
      });

      // Dispatch recovery email
      const deliveryResult = await emailService.sendPasswordResetEmail({
        toEmail: targetUser.email,
        resetToken,
        recipientName: targetUser.name,
      });

      if (!deliveryResult.delivered) {
        logActivity({
          statusCode: 500,
          activity: 'PASSWORD_RESET_DELIVERY_FAILED',
          reason: `Password reset email could not be delivered to ${maskEmail(targetUser.email)}: ${deliveryResult.error}`,
        });
        if (env.NODE_ENV === 'production') {
          return {
            success: false,
            message: 'Unable to deliver password reset email. Please try again later or contact your gym administrator.',
          };
        }
      }

      logActivity({
        statusCode: 200,
        activity: 'PASSWORD_RESET_TOKEN_ISSUED',
        reason: `Password reset token generated and dispatched for ${maskEmail(targetUser.email)} (${targetUser.role})`,
        details: {
          recipient: maskEmail(targetUser.email),
          role: targetUser.role,
          jti,
        },
      });

      return antiEnumerationResponse;
    } catch (err: any) {
      logActivity({
        statusCode: 500,
        activity: 'PASSWORD_RESET_REQUEST_ERROR',
        reason: `Error during password reset request for ${maskEmail(normalizedEmail)}: ${err?.message || err}`,
        error: err,
      });
      if (env.NODE_ENV === 'production') {
        return {
          success: false,
          message: 'Unable to process password reset request at this time. Please try again later.',
        };
      }
      return antiEnumerationResponse;
    }
  }

  /**
   * Cryptographically verifies the validity of a reset token without consuming it.
   */
  public async verifyResetToken(token: string): Promise<VerifyTokenResult> {
    if (!token || typeof token !== 'string' || token.trim().length === 0) {
      return {
        valid: false,
        error: 'TOKEN_INVALID',
        message: 'Password reset token is missing or malformed.',
      };
    }

    try {
      const decoded = jwt.verify(token.trim(), env.JWT_ACCESS_SECRET) as ResetTokenPayload;

      if (decoded.purpose !== 'PASSWORD_RESET') {
        return {
          valid: false,
          error: 'TOKEN_INVALID',
          message: 'The provided token is not valid for password recovery.',
        };
      }

      // 1. Check if token JTI has already been consumed
      if (this.consumedTokens.has(decoded.jti)) {
        return {
          valid: false,
          error: 'TOKEN_ALREADY_USED',
          message: 'This password reset link has already been used. Please request a new one.',
        };
      }

      // 2. Validate current password hash snippet against token
      const isMasterAdmin = adminAuthService.isMasterAdminEmail(decoded.email);

      if (isMasterAdmin) {
        const currentSnippet = await adminAuthService.getActivePasswordHashSnippet();
        if (currentSnippet !== decoded.hashSnippet) {
          return {
            valid: false,
            error: 'TOKEN_ALREADY_USED',
            message: 'This reset link has expired because the password was already changed.',
          };
        }
      } else {
        const dbUser = await prisma.user.findUnique({
          where: { id: decoded.userId },
          select: { id: true, passwordHash: true },
        });

        if (!dbUser) {
          return {
            valid: false,
            error: 'USER_NOT_FOUND',
            message: 'User account not found.',
          };
        }

        const currentSnippet = (dbUser.passwordHash || '').slice(-10);
        if (currentSnippet !== decoded.hashSnippet) {
          return {
            valid: false,
            error: 'TOKEN_ALREADY_USED',
            message: 'This reset link has expired because the password was already changed.',
          };
        }
      }

      return {
        valid: true,
        email: decoded.email,
        role: decoded.role,
      };
    } catch (err: any) {
      if (err instanceof jwt.TokenExpiredError) {
        return {
          valid: false,
          error: 'TOKEN_EXPIRED',
          message: 'This password reset link has expired. Please request a new one.',
        };
      }
      return {
        valid: false,
        error: 'TOKEN_INVALID',
        message: 'This password reset link is invalid or corrupted.',
      };
    }
  }

  /**
   * Securely saves the new password using bcrypt, consumes the single-use token atomically,
   * and invalidates all prior reset tokens for this user.
   * Multi-instance safe via atomic database conditional update.
   * Concurrent-request safe via in-flight token locks.
   */
  public async resetPassword(token: string, newPassword: string): Promise<ResetPasswordResult> {
    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      return {
        success: false,
        error: 'VALIDATION_ERROR',
        message: 'Password must be at least 6 characters.',
      };
    }

    if (!token || typeof token !== 'string') {
      return {
        success: false,
        error: 'TOKEN_INVALID',
        message: 'Password reset token is missing or malformed.',
      };
    }

    let decoded: ResetTokenPayload;
    try {
      decoded = jwt.decode(token.trim()) as ResetTokenPayload;
      if (!decoded || !decoded.jti || decoded.purpose !== 'PASSWORD_RESET') {
        return {
          success: false,
          error: 'TOKEN_INVALID',
          message: 'The provided token is not valid for password recovery.',
        };
      }
    } catch (_) {
      return {
        success: false,
        error: 'TOKEN_INVALID',
        message: 'Password reset token is missing or malformed.',
      };
    }

    // Atomic in-flight reservation: prevent concurrent race conditions
    if (this.consumedTokens.has(decoded.jti) || this.inFlightTokens.has(decoded.jti)) {
      return {
        success: false,
        error: 'TOKEN_ALREADY_USED',
        message: 'This password reset link has already been used. Please request a new one.',
      };
    }

    // Acquire in-flight lock for this token JTI
    this.inFlightTokens.add(decoded.jti);

    try {
      // Cryptographically verify token validity & hash snippet
      const verification = await this.verifyResetToken(token);
      if (!verification.valid) {
        return {
          success: false,
          error: verification.error,
          message: verification.message || 'Invalid or expired password reset token.',
        };
      }

      // Mark token as consumed in local memory (TTL: 30 minutes)
      const expiryMs = (decoded.exp ? decoded.exp * 1000 : Date.now() + 15 * 60 * 1000) + 15 * 60 * 1000;
      this.consumedTokens.set(decoded.jti, expiryMs);

      const isMasterAdmin = adminAuthService.isMasterAdminEmail(decoded.email);

      if (isMasterAdmin) {
        // Update administrator credentials in memory
        await adminAuthService.updateAdminPassword(newPassword);

        // Also update admin DB record if present
        const dbAdminUser = await prisma.user.findUnique({
          where: { email: decoded.email },
        });
        if (dbAdminUser) {
          const newHash = await bcrypt.hash(newPassword, 12);
          await prisma.user.update({
            where: { id: dbAdminUser.id },
            data: { passwordHash: newHash },
          });
        }

        logActivity({
          statusCode: 200,
          activity: 'ADMIN_PASSWORD_RESET_SUCCESS',
          reason: `Master Administrator password successfully reset for ${maskEmail(decoded.email)}`,
        });
      } else {
        // Hash client password with bcrypt (10 rounds) matching standard registration
        const newHash = await bcrypt.hash(newPassword, 10);

        // Atomic conditional update ensuring token has not been consumed by a concurrent instance
        const updateResult = await prisma.user.updateMany({
          where: {
            id: decoded.userId,
            passwordHash: {
              endsWith: decoded.hashSnippet,
            },
          },
          data: {
            passwordHash: newHash,
          },
        });

        if (updateResult.count === 0) {
          return {
            success: false,
            error: 'TOKEN_ALREADY_USED',
            message: 'This password reset link has already been used. Please request a new one.',
          };
        }

        logActivity({
          statusCode: 200,
          activity: 'CLIENT_PASSWORD_RESET_SUCCESS',
          reason: `Client password successfully reset for ${maskEmail(decoded.email)} (${decoded.userId})`,
        });
      }

      return {
        success: true,
        message: 'Password has been successfully reset. You can now log in with your new password.',
      };
    } catch (err: any) {
      logActivity({
        statusCode: 500,
        activity: 'PASSWORD_RESET_EXECUTION_FAILED',
        reason: `Failed to execute password reset: ${err?.message || err}`,
        error: err,
      });
      return {
        success: false,
        error: 'INTERNAL_ERROR',
        message: 'Failed to update password. Please try again or contact support.',
      };
    } finally {
      // Release in-flight lock
      this.inFlightTokens.delete(decoded.jti);
    }
  }

  /**
   * Generates a secure, short-lived (15 min), single-use 6-digit reset code
   * initiated and authorized by an authenticated administrator after verifying athlete identity.
   */
  public async adminIssueResetCode(
    adminId: string,
    adminEmail: string,
    targetUserId: string,
    reason?: string
  ): Promise<{ success: boolean; code?: string; expiresInMinutes?: number; message?: string; error?: string }> {
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      include: { clientProfile: true },
    });

    if (!user) {
      return {
        success: false,
        error: 'USER_NOT_FOUND',
        message: `Athlete with ID "${targetUserId}" not found.`,
      };
    }

    if (user.role === UserRole.ADMIN) {
      return {
        success: false,
        error: 'INVALID_TARGET_ROLE',
        message: 'Administrator accounts cannot be reset via client code flow.',
      };
    }

    // Generate 6-digit cryptographically secure numeric code
    const rawCode = crypto.randomInt(100000, 1000000).toString();
    const codeId = crypto.randomUUID();
    const hashedCode = crypto.createHmac('sha256', env.JWT_ACCESS_SECRET).update(rawCode).digest('hex');
    const hashSnippet = (user.passwordHash || '').slice(-10);

    const entry: AdminResetCodeEntry = {
      codeId,
      userId: user.id,
      userEmail: user.email,
      hashedCode,
      expiresAt: Date.now() + 15 * 60 * 1000, // 15 minutes TTL
      attempts: 0,
      adminId,
      adminEmail,
      used: false,
      hashSnippet,
    };

    // Invalidate any active unconsumed codes for this user in DB
    await prisma.passwordResetCode.updateMany({
      where: { userId: user.id, usedAt: null },
      data: { usedAt: new Date() },
    });

    // Persist new reset code in PostgreSQL (store ONLY HMAC-SHA256 hash)
    const codeRecord = await prisma.passwordResetCode.create({
      data: {
        userId: user.id,
        codeHash: hashedCode,
        attempts: 0,
        expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15 minutes TTL
        adminId,
        adminEmail,
        reason: reason || 'In-person / admin verification',
      },
    });

    logActivity({
      statusCode: 200,
      activity: 'ADMIN_ISSUED_RESET_CODE',
      reason: `Admin ${maskEmail(adminEmail)} issued single-use reset code for athlete ${maskEmail(user.email)}`,
      details: {
        adminEmail: maskEmail(adminEmail),
        recipient: maskEmail(user.email),
        targetUserId: user.id,
        clientId: user.clientProfile?.clientId,
        codeId: codeRecord.id,
        reason: reason || 'In-person / admin verification',
      },
    });

    return {
      success: true,
      code: rawCode,
      expiresInMinutes: 15,
      message: 'Single-use reset code generated. Share this 6-digit code with the verified athlete.',
    };
  }

  /**
   * Sets a temporary password for an athlete, requiring forced password change on next login.
   * Persisted directly in PostgreSQL (User.mustChangePassword = true).
   */
  public async adminSetTemporaryPassword(
    adminId: string,
    adminEmail: string,
    targetUserId: string,
    customTempPassword?: string
  ): Promise<{ success: boolean; temporaryPassword?: string; message?: string; error?: string }> {
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      include: { clientProfile: true },
    });

    if (!user) {
      return {
        success: false,
        error: 'USER_NOT_FOUND',
        message: `Athlete with ID "${targetUserId}" not found.`,
      };
    }

    if (user.role === UserRole.ADMIN) {
      return {
        success: false,
        error: 'INVALID_TARGET_ROLE',
        message: 'Administrator accounts cannot be modified via this flow.',
      };
    }

    const tempPassword = customTempPassword || `AXG#${crypto.randomBytes(4).toString('hex')}!`;
    if (tempPassword.length < 8) {
      return {
        success: false,
        error: 'VALIDATION_ERROR',
        message: 'Temporary password must be at least 8 characters long.',
      };
    }

    const newHash = await bcrypt.hash(tempPassword, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: newHash,
        mustChangePassword: true,
      },
    });

    // Invalidate any active reset codes in DB
    await prisma.passwordResetCode.updateMany({
      where: { userId: user.id, usedAt: null },
      data: { usedAt: new Date() },
    });

    logActivity({
      statusCode: 200,
      activity: 'ADMIN_SET_TEMPORARY_PASSWORD',
      reason: `Admin ${maskEmail(adminEmail)} set temporary password for athlete ${maskEmail(user.email)} with forced change on login`,
      details: {
        adminEmail: maskEmail(adminEmail),
        recipient: maskEmail(user.email),
        targetUserId: user.id,
        clientId: user.clientProfile?.clientId,
      },
    });

    return {
      success: true,
      temporaryPassword: tempPassword,
      message: 'Temporary password assigned. Athlete will be forced to change password upon next login.',
    };
  }

  /**
   * Resets password using an admin-issued single-use 6-digit verification code.
   * Identifier can be athlete's email or permanent Client ID (AXG-XXXX).
   * Executes inside an atomic PostgreSQL transaction with row-level locks
   * to guarantee multi-instance and concurrency safety across serverless instances.
   */
  public async resetPasswordWithAdminCode(
    identifier: string,
    code: string,
    newPassword: string
  ): Promise<ResetPasswordResult> {
    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      return {
        success: false,
        error: 'VALIDATION_ERROR',
        message: 'Password must be at least 6 characters.',
      };
    }

    const cleanIdentifier = (identifier || '').trim().toLowerCase();
    const cleanCode = (code || '').trim();

    if (!cleanIdentifier || !cleanCode) {
      return {
        success: false,
        error: 'VALIDATION_ERROR',
        message: 'Athlete identifier and 6-digit reset code are required.',
      };
    }

    // Look up user by email, clientId, or ID
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: cleanIdentifier },
          { clientProfile: { clientId: cleanIdentifier.toUpperCase() } },
          { id: cleanIdentifier },
        ],
      },
      select: {
        id: true,
        email: true,
        role: true,
        passwordHash: true,
      },
    });

    if (!user) {
      // Simulate cryptographic hash latency to prevent timing attacks
      await new Promise((resolve) => setTimeout(resolve, 250 + Math.random() * 150));
      return {
        success: false,
        error: 'INVALID_CODE',
        message: 'Invalid or expired verification reset code.',
      };
    }

    const computedHash = crypto.createHmac('sha256', env.JWT_ACCESS_SECRET).update(cleanCode).digest('hex');

    try {
      const result = await prisma.$transaction(async (tx) => {
        // Query active code with FOR UPDATE row lock to serialize concurrent attempts across all backend instances
        const activeCodes = await tx.$queryRaw<
          Array<{
            id: string;
            codeHash: string;
            attempts: number;
            expiresAt: Date;
            usedAt: Date | null;
          }>
        >`
          SELECT id, "codeHash", attempts, "expiresAt", "usedAt"
          FROM password_reset_codes
          WHERE "userId" = ${user.id} AND "usedAt" IS NULL
          ORDER BY "createdAt" DESC
          LIMIT 1
          FOR UPDATE
        `;

        if (!activeCodes || activeCodes.length === 0) {
          return {
            success: false,
            error: 'CODE_ALREADY_USED',
            message: 'This reset code has already been used or expired. Please contact your admin for a new code.',
          };
        }

        const activeCode = activeCodes[0];

        // 1. Check expiration (15 minutes)
        if (Date.now() > new Date(activeCode.expiresAt).getTime()) {
          await tx.passwordResetCode.update({
            where: { id: activeCode.id },
            data: { usedAt: new Date() },
          });
          return {
            success: false,
            error: 'CODE_EXPIRED',
            message: 'This reset code has expired. Reset codes are valid for 15 minutes. Please contact your admin for a new code.',
          };
        }

        // 2. Check failed attempts (max 5)
        if (activeCode.attempts >= 5) {
          await tx.passwordResetCode.update({
            where: { id: activeCode.id },
            data: { usedAt: new Date() },
          });
          return {
            success: false,
            error: 'MAX_ATTEMPTS_EXCEEDED',
            message: 'Maximum verification attempts exceeded. For security, this reset code has been deactivated. Please contact your administrator.',
          };
        }

        // 3. Timing-safe cryptographic comparison
        const isMatch =
          computedHash.length === activeCode.codeHash.length &&
          crypto.timingSafeEqual(Buffer.from(computedHash, 'hex'), Buffer.from(activeCode.codeHash, 'hex'));

        if (!isMatch) {
          const newAttempts = activeCode.attempts + 1;
          const isDeactivated = newAttempts >= 5;
          await tx.passwordResetCode.update({
            where: { id: activeCode.id },
            data: {
              attempts: newAttempts,
              ...(isDeactivated ? { usedAt: new Date() } : {}),
            },
          });

          if (isDeactivated) {
            return {
              success: false,
              error: 'MAX_ATTEMPTS_EXCEEDED',
              message: 'Maximum verification attempts exceeded. For security, this reset code has been deactivated. Please contact your administrator.',
            };
          }

          return {
            success: false,
            error: 'INVALID_CODE',
            message: 'Invalid reset code. Please check the 6-digit code provided by your administrator.',
          };
        }

        // 4. Code MATCHES: Atomically consume code and update password
        await tx.passwordResetCode.update({
          where: { id: activeCode.id },
          data: { usedAt: new Date() },
        });

        const newHash = await bcrypt.hash(newPassword, 10);
        await tx.user.update({
          where: { id: user.id },
          data: {
            passwordHash: newHash,
            mustChangePassword: false,
          },
        });

        return {
          success: true,
          message: 'Password has been successfully reset. You can now log in with your new password.',
        };
      });

      if (result.success) {
        logActivity({
          statusCode: 200,
          activity: 'CLIENT_PASSWORD_RESET_VIA_ADMIN_CODE_SUCCESS',
          reason: `Client password successfully reset for ${maskEmail(user.email)} via admin-issued code`,
          details: {
            recipient: maskEmail(user.email),
          },
        });
      }

      return result;
    } catch (err: any) {
      logActivity({
        statusCode: 500,
        activity: 'PASSWORD_RESET_EXECUTION_FAILED',
        reason: `Failed to execute password reset via code: ${err?.message || err}`,
        error: err,
      });
      return {
        success: false,
        error: 'INTERNAL_ERROR',
        message: 'Failed to update password. Please try again or contact support.',
      };
    }
  }

  /**
   * Checks if user is required to change password on login.
   * Persisted in PostgreSQL (User.mustChangePassword).
   */
  public async isForcedPasswordChangeRequired(userId: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { mustChangePassword: true },
    });
    return user?.mustChangePassword === true;
  }

  /**
   * Clears forced password change requirement in PostgreSQL.
   */
  public async clearForcedPasswordChange(userId: string): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: { mustChangePassword: false },
    }).catch(() => {});
  }

  /**
   * Authenticated password change (e.g. for forced change or user settings).
   * Persisted directly in PostgreSQL.
   */
  public async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string
  ): Promise<ResetPasswordResult> {
    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      return {
        success: false,
        error: 'VALIDATION_ERROR',
        message: 'New password must be at least 6 characters.',
      };
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, passwordHash: true },
    });

    if (!user || !user.passwordHash) {
      return {
        success: false,
        error: 'USER_NOT_FOUND',
        message: 'User account not found.',
      };
    }

    const isMatch = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isMatch) {
      return {
        success: false,
        error: 'INVALID_CREDENTIALS',
        message: 'Current password is incorrect.',
      };
    }

    const newHash = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: newHash,
        mustChangePassword: false,
      },
    });

    logActivity({
      statusCode: 200,
      activity: 'USER_PASSWORD_CHANGED_SUCCESS',
      reason: `Password successfully updated by user ${maskEmail(user.email)}`,
      details: {
        recipient: maskEmail(user.email),
        userId: user.id,
      },
    });

    return {
      success: true,
      message: 'Password has been successfully updated.',
    };
  }
}

export const passwordResetService = PasswordResetService.getInstance();
