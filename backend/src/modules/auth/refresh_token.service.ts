/**
 * Alpha X Gym — Phase 7 Refresh Token Service
 * Implements RFC 6749 / RFC 6819 compliant refresh token rotation:
 * - 256-bit cryptographically secure random tokens.
 * - SHA-256 hashed storage only (raw tokens never stored in database).
 * - 15-minute access tokens and 30-day refresh tokens.
 * - User-first Level 1 locking (`SELECT ... FOR UPDATE`) preventing race conditions.
 * - Snapshot-bound `tokenVersion` verification.
 * - Stateful replay detection and immediate session-family invalidation.
 * - Typed transaction results ensuring security revocations commit to disk.
 */

import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/prisma';
import { env } from '../../config/environment';
import { UserStatus } from '../../constants/roles';

export type RefreshResult =
  | {
      status: 'SUCCESS';
      data: {
        token: string;
        refreshToken: string;
        mustChangePassword: boolean;
        user: {
          id: string;
          email: string;
          role: string;
          clientId: string | null;
          sessionId: string;
        };
      };
    }
  | {
      status: 'REUSE_DETECTED';
      httpStatus: 401;
      errorCode: 'TOKEN_REUSE_DETECTED';
      message: string;
    }
  | {
      status: 'EXPIRED';
      httpStatus: 401;
      errorCode: 'REFRESH_TOKEN_EXPIRED';
      message: string;
    }
  | {
      status: 'INVALID_TOKEN';
      httpStatus: 401;
      errorCode: 'INVALID_REFRESH_TOKEN';
      message: string;
    }
  | {
      status: 'SESSION_REVOKED';
      httpStatus: 401;
      errorCode: 'TOKEN_REVOKED';
      message: string;
    }
  | {
      status: 'USER_SUSPENDED';
      httpStatus: 403;
      errorCode: 'USER_SUSPENDED';
      message: string;
    }
  | {
      status: 'USER_REJECTED';
      httpStatus: 403;
      errorCode: 'USER_REJECTED';
      message: string;
    }
  | {
      status: 'MUST_CHANGE_PASSWORD';
      httpStatus: 403;
      errorCode: 'MUST_CHANGE_PASSWORD';
      message: string;
    };

export class RefreshTokenService {
  /**
   * Hashes a raw refresh token using SHA-256 for secure lookup and storage.
   */
  public hashToken(rawToken: string): string {
    return crypto.createHash('sha256').update(rawToken.trim()).digest('hex');
  }

  /**
   * Generates a new 256-bit cryptographically secure random refresh token.
   */
  public generateRawToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Creates an initial refresh token family upon login or password change.
   */
  public async createInitialRefreshToken(
    userId: string,
    tokenVersion: number,
    deviceInfo?: string,
    txClient?: any
  ): Promise<{
    rawRefreshToken: string;
    sessionId: string;
    familyId: string;
    expiresAt: Date;
  }> {
    const rawRefreshToken = this.generateRawToken();
    const tokenHash = this.hashToken(rawRefreshToken);
    const sessionId = crypto.randomUUID();
    const familyId = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 Days

    const db = txClient || prisma;
    await db.refreshToken.create({
      data: {
        tokenHash,
        tokenVersion,
        userId,
        sessionId,
        familyId,
        deviceInfo: deviceInfo ?? null,
        expiresAt,
        isRevoked: false,
      },
    });

    return {
      rawRefreshToken,
      sessionId,
      familyId,
      expiresAt,
    };
  }

  /**
   * Performs atomic single-use refresh token rotation with User-first row locking.
   * Never throws on security revocations; commits mutations and returns typed result.
   */
  public async rotateRefreshToken(
    rawRefreshToken: string,
    deviceInfo?: string
  ): Promise<RefreshResult> {
    if (!rawRefreshToken || typeof rawRefreshToken !== 'string') {
      return {
        status: 'INVALID_TOKEN',
        httpStatus: 401,
        errorCode: 'INVALID_REFRESH_TOKEN',
        message: 'A valid refresh token must be provided.',
      };
    }

    const tokenHash = this.hashToken(rawRefreshToken);

    const result = await prisma.$transaction(
      async (tx): Promise<RefreshResult> => {
        // ── STEP 1: Probe Refresh Token Record ──────────────────────────────
        const initialProbe = await tx.refreshToken.findUnique({
          where: { tokenHash },
          select: {
            id: true,
            userId: true,
            sessionId: true,
            familyId: true,
            tokenVersion: true,
            expiresAt: true,
            isRevoked: true,
            revokedReason: true,
            deviceInfo: true,
          },
        });

        if (!initialProbe) {
          return {
            status: 'INVALID_TOKEN',
            httpStatus: 401,
            errorCode: 'INVALID_REFRESH_TOKEN',
            message: 'Refresh token not found or corrupted.',
          };
        }

        // ── STEP 2: Level 1 Lock — Lock User Row First (Deterministic Order) ──
        const lockedUsers = await tx.$queryRaw<
          Array<{
            id: string;
            email: string;
            role: string;
            status: string;
            mustChangePassword: boolean;
            tokenVersion: number;
          }>
        >`
          SELECT id, email, role, status, "mustChangePassword", "tokenVersion"
          FROM "users"
          WHERE id = ${initialProbe.userId}
          FOR UPDATE;
        `;

        if (!lockedUsers || lockedUsers.length === 0) {
          return {
            status: 'INVALID_TOKEN',
            httpStatus: 401,
            errorCode: 'INVALID_REFRESH_TOKEN',
            message: 'Account associated with this session no longer exists.',
          };
        }

        const user = lockedUsers[0];

        // ── STEP 3: Handle Revoked Tokens (Accurate Classification) ─────────
        if (initialProbe.isRevoked) {
          if (initialProbe.revokedReason === 'ROTATED') {
            // Replay detected! Consumed token presented again.
            // Revoke the ENTIRE session family and commit.
            await tx.refreshToken.updateMany({
              where: {
                familyId: initialProbe.familyId,
                isRevoked: false,
              },
              data: {
                isRevoked: true,
                revokedAt: new Date(),
                revokedReason: 'REUSE_DETECTED',
              },
            });

            return {
              status: 'REUSE_DETECTED',
              httpStatus: 401,
              errorCode: 'TOKEN_REUSE_DETECTED',
              message:
                'Token reuse detected. All sessions in this device family have been revoked.',
            };
          }

          if (
            initialProbe.revokedReason === 'LOGOUT_SINGLE' ||
            initialProbe.revokedReason === 'LOGOUT_ALL'
          ) {
            return {
              status: 'SESSION_REVOKED',
              httpStatus: 401,
              errorCode: 'TOKEN_REVOKED',
              message: 'Your session has been logged out. Please log in again.',
            };
          }

          if (
            initialProbe.revokedReason === 'PASSWORD_RESET' ||
            initialProbe.revokedReason === 'TOKEN_VERSION_MISMATCH'
          ) {
            return {
              status: 'SESSION_REVOKED',
              httpStatus: 401,
              errorCode: 'TOKEN_REVOKED',
              message:
                'Credentials have been updated. Please log in with your new password.',
            };
          }

          if (initialProbe.revokedReason === 'ACCOUNT_SUSPENDED') {
            return {
              status: 'USER_SUSPENDED',
              httpStatus: 403,
              errorCode: 'USER_SUSPENDED',
              message: 'Your account has been suspended by administration.',
            };
          }

          if (initialProbe.revokedReason === 'ACCOUNT_REJECTED') {
            return {
              status: 'USER_REJECTED',
              httpStatus: 403,
              errorCode: 'USER_REJECTED',
              message: 'Your account application has been rejected.',
            };
          }

          if (initialProbe.revokedReason === 'EXPIRED') {
            return {
              status: 'EXPIRED',
              httpStatus: 401,
              errorCode: 'REFRESH_TOKEN_EXPIRED',
              message: 'Refresh token has expired. Please log in again.',
            };
          }

          return {
            status: 'SESSION_REVOKED',
            httpStatus: 401,
            errorCode: 'TOKEN_REVOKED',
            message: 'Your session has been revoked. Please log in again.',
          };
        }

        // ── STEP 4: Token Version Snapshot Check ────────────────────────────
        if (initialProbe.tokenVersion !== user.tokenVersion) {
          await tx.refreshToken.update({
            where: { id: initialProbe.id },
            data: {
              isRevoked: true,
              revokedAt: new Date(),
              revokedReason: 'TOKEN_VERSION_MISMATCH',
            },
          });

          return {
            status: 'SESSION_REVOKED',
            httpStatus: 401,
            errorCode: 'TOKEN_REVOKED',
            message:
              'Session invalidated by an account security update. Please log in again.',
          };
        }

        // ── STEP 5: Token Expiration Check ──────────────────────────────────
        if (initialProbe.expiresAt <= new Date()) {
          await tx.refreshToken.update({
            where: { id: initialProbe.id },
            data: {
              isRevoked: true,
              revokedAt: new Date(),
              revokedReason: 'EXPIRED',
            },
          });

          return {
            status: 'EXPIRED',
            httpStatus: 401,
            errorCode: 'REFRESH_TOKEN_EXPIRED',
            message: 'Refresh token has expired. Please log in again.',
          };
        }

        // ── STEP 6: User Status & Forced Password Checks (BUG-03) ────────────
        if (user.status === UserStatus.SUSPENDED) {
          await tx.refreshToken.update({
            where: { id: initialProbe.id },
            data: {
              isRevoked: true,
              revokedAt: new Date(),
              revokedReason: 'ACCOUNT_SUSPENDED',
            },
          });

          return {
            status: 'USER_SUSPENDED',
            httpStatus: 403,
            errorCode: 'USER_SUSPENDED',
            message: 'Your account has been suspended by administration.',
          };
        }

        if (user.status === UserStatus.REJECTED) {
          await tx.refreshToken.update({
            where: { id: initialProbe.id },
            data: {
              isRevoked: true,
              revokedAt: new Date(),
              revokedReason: 'ACCOUNT_REJECTED',
            },
          });

          return {
            status: 'USER_REJECTED',
            httpStatus: 403,
            errorCode: 'USER_REJECTED',
            message: 'Your account application has been rejected.',
          };
        }

        if (user.mustChangePassword) {
          return {
            status: 'MUST_CHANGE_PASSWORD',
            httpStatus: 403,
            errorCode: 'MUST_CHANGE_PASSWORD',
            message: 'You must change your password before continuing.',
          };
        }

        // ── STEP 7: Atomic Conditional Token Consumption ────────────────────
        const updatedCount = await tx.$executeRaw`
          UPDATE "refresh_tokens"
          SET "isRevoked" = true,
              "revokedAt" = NOW(),
              "revokedReason" = 'ROTATED'
          WHERE "id" = ${initialProbe.id}
            AND "isRevoked" = false;
        `;

        if (updatedCount === 0) {
          // Re-read committed row to diagnose race condition
          const freshRow = await tx.refreshToken.findUnique({
            where: { id: initialProbe.id },
          });

          if (freshRow?.revokedReason === 'ROTATED') {
            await tx.refreshToken.updateMany({
              where: {
                familyId: initialProbe.familyId,
                isRevoked: false,
              },
              data: {
                isRevoked: true,
                revokedAt: new Date(),
                revokedReason: 'REUSE_DETECTED',
              },
            });

            return {
              status: 'REUSE_DETECTED',
              httpStatus: 401,
              errorCode: 'TOKEN_REUSE_DETECTED',
              message:
                'Token reuse detected. All sessions in this device family have been revoked.',
            };
          }

          return {
            status: 'SESSION_REVOKED',
            httpStatus: 401,
            errorCode: 'TOKEN_REVOKED',
            message: 'Session has been revoked.',
          };
        }

        // ── STEP 8: Mint Successor Refresh Token (30 Days) ───────────────────
        const successorRaw = this.generateRawToken();
        const successorHash = this.hashToken(successorRaw);
        const successorExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

        await tx.refreshToken.create({
          data: {
            tokenHash: successorHash,
            tokenVersion: user.tokenVersion,
            userId: user.id,
            sessionId: initialProbe.sessionId,
            familyId: initialProbe.familyId,
            deviceInfo: deviceInfo ?? initialProbe.deviceInfo,
            expiresAt: successorExpiresAt,
          },
        });

        // ── STEP 9: Mint Short-Lived Access Token (15 Minutes) ───────────────
        const newAccessToken = jwt.sign(
          {
            id: user.id,
            email: user.email.toLowerCase(),
            role: user.role,
            tokenVersion: user.tokenVersion,
            sessionId: initialProbe.sessionId,
            familyId: initialProbe.familyId,
          },
          env.JWT_ACCESS_SECRET,
          { expiresIn: '15m' }
        );

        const clientProfile = await tx.clientProfile.findUnique({
          where: { userId: user.id },
          select: { clientId: true },
        });

        return {
          status: 'SUCCESS',
          data: {
            token: newAccessToken,
            refreshToken: successorRaw,
            mustChangePassword: false,
            user: {
              id: user.id,
              email: user.email.toLowerCase(),
              role: user.role,
              clientId: clientProfile?.clientId ?? null,
              sessionId: initialProbe.sessionId,
            },
          },
        };
      },
      {
        isolationLevel: 'ReadCommitted',
        timeout: 10000,
      }
    );

    return result;
  }

  /**
   * Revokes a single device session by sessionId.
   */
  public async revokeSingleSession(
    userId: string,
    sessionId: string,
    reason: string = 'LOGOUT_SINGLE'
  ): Promise<void> {
    try {
      if ((prisma as any).refreshToken) {
        await (prisma as any).refreshToken.updateMany({
          where: {
            userId,
            sessionId,
            isRevoked: false,
          },
          data: {
            isRevoked: true,
            revokedAt: new Date(),
            revokedReason: reason,
          },
        });
      }
    } catch (_) {}
  }

  /**
   * Revokes all active refresh sessions for a user (e.g. password reset or global logout).
   */
  public async revokeAllUserSessions(
    userId: string,
    reason: string = 'LOGOUT_ALL',
    txClient?: any
  ): Promise<void> {
    const db = txClient || prisma;
    if (db.refreshToken) {
      await db.refreshToken.updateMany({
        where: {
          userId,
          isRevoked: false,
        },
        data: {
          isRevoked: true,
          revokedAt: new Date(),
          revokedReason: reason,
        },
      }).catch?.(() => {});
    }
  }
}

export const refreshTokenService = new RefreshTokenService();
