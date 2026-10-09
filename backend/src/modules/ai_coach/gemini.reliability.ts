/**
 * Alpha X AI Coach — Gemini Reliability, Error Classification & Recovery Engine
 *
 * Implements:
 * 1. Safe, server-side secret management with zero per-request disk reads (Vercel-native).
 * 2. Strict error classification (Auth, Quota, Rate-limit, Transient, Model).
 * 3. Bounded retries with exponential backoff and jitter strictly for transient errors.
 * 4. Circuit breaker that halts repeated calls on authentication failures to protect server and API limits.
 * 5. Optional GEMINI_API_KEY_BACKUP failover with protection against duplicate/fake backup keys.
 * 6. Lightweight, TTL-cached health-check probe with zero key exposure.
 * 7. Server-side diagnostic reporting and Admin alert logging without secrets.
 */

import { GoogleGenAI } from '@google/genai';
import { env } from '../../config/environment';
import { prisma } from '../../config/prisma';
import { oneSignalService } from '../notifications/onesignal.service';

// ============================================================================
// 1. Error Classification Types & Constants
// ============================================================================

export type GeminiErrorCategory =
  | 'AUTHENTICATION_ERROR'
  | 'QUOTA_EXHAUSTED'
  | 'RATE_LIMIT'
  | 'TRANSIENT_SERVER_ERROR'
  | 'MODEL_ERROR'
  | 'UNKNOWN_ERROR';

export interface ClassifiedGeminiError {
  category: GeminiErrorCategory;
  isTransient: boolean;
  isAuth: boolean;
  isQuota: boolean;
  isRateLimit: boolean;
  isModelError: boolean;
  statusCode?: number;
  sanitizedMessage: string;
  originalError: any;
}

export interface GeminiHealthStatus {
  healthy: boolean;
  status: 'HEALTHY' | 'DEGRADED' | 'UNCONFIGURED' | 'AUTH_FAILED' | 'QUOTA_EXHAUSTED' | 'RATE_LIMITED' | 'UNAVAILABLE';
  activeKeySource: 'PRIMARY' | 'BACKUP' | 'NONE';
  hasBackupKey: boolean;
  isBackupActive: boolean;
  circuitTripped: boolean;
  cooldownRemainingSeconds: number;
  model: string;
  latencyMs?: number;
  lastChecked: string;
  message: string;
}

// ============================================================================
// 2. Secret Redaction Utility
// ============================================================================

/**
 * Sanitizes any string or log message so API keys, tokens, or credentials
 * never leak into logs, responses, or client payloads.
 */
export function redactSecrets(text: string, knownSecrets: string[] = []): string {
  if (!text || typeof text !== 'string') return '';
  let sanitized = text;

  // Redact standard Google API Key formats (e.g. AIzaSy...)
  sanitized = sanitized.replace(/AIza[0-9A-Za-z\-_]{35}/g, '[REDACTED_API_KEY]');

  // Redact query parameter credentials: ?key=... or &key=...
  sanitized = sanitized.replace(/([?&]key=)[^&\s"'`]+/gi, '$1[REDACTED_API_KEY]');

  // Redact Bearer tokens and Authorization headers
  sanitized = sanitized.replace(/(Bearer\s+)[A-Za-z0-9\-._~+/]+=*/gi, '$1[REDACTED_TOKEN]');

  // Redact any explicitly registered runtime secrets
  for (const s of knownSecrets) {
    if (s && typeof s === 'string' && s.trim().length >= 8) {
      const clean = s.trim().replace(/^["']|["']$/g, '').trim();
      if (clean.length >= 8) {
        const escaped = clean.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        sanitized = sanitized.replace(new RegExp(escaped, 'g'), '[REDACTED_SECRET]');
      }
    }
  }

  return sanitized;
}

// ============================================================================
// 3. Error Classification
// ============================================================================

/**
 * Classifies any thrown error from Google Gemini / @google/genai into distinct categories.
 * Never retry auth or quota errors; only retry transient server/network errors.
 */
export function classifyGeminiError(error: any): ClassifiedGeminiError {
  const rawMsg = error?.message || (typeof error === 'string' ? error : JSON.stringify(error || ''));
  const sanitizedMsg = redactSecrets(rawMsg);

  // Extract status code if available (SDK errors provide error.status or error.error.code)
  const statusNum =
    typeof error?.status === 'number'
      ? error.status
      : typeof error?.statusCode === 'number'
      ? error.statusCode
      : typeof error?.response?.status === 'number'
      ? error.response.status
      : typeof error?.error?.code === 'number'
      ? error.error.code
      : undefined;

  const msgLower = rawMsg.toLowerCase();

  // 1. Authentication & Permission Errors (HTTP 401, 403, API_KEY_INVALID, PERMISSION_DENIED)
  const isAuth =
    statusNum === 401 ||
    statusNum === 403 ||
    error?.status === 'UNAUTHENTICATED' ||
    error?.status === 'PERMISSION_DENIED' ||
    error?.error?.status === 'UNAUTHENTICATED' ||
    error?.error?.status === 'PERMISSION_DENIED' ||
    msgLower.includes('api key not valid') ||
    msgLower.includes('api_key_invalid') ||
    msgLower.includes('permission_denied') ||
    msgLower.includes('unauthenticated') ||
    msgLower.includes('invalid authentication') ||
    msgLower.includes('credentials were rejected') ||
    msgLower.includes('api key expired');

  if (isAuth) {
    return {
      category: 'AUTHENTICATION_ERROR',
      isTransient: false,
      isAuth: true,
      isQuota: false,
      isRateLimit: false,
      isModelError: false,
      statusCode: statusNum || 401,
      sanitizedMessage: sanitizedMsg,
      originalError: error,
    };
  }

  // 2. Differentiate Quota Exhaustion vs Rate Limit on 429
  // Quota exhaustion represents depleted account/project balance or daily limits requiring billing action
  const isExplicitQuotaExhausted =
    msgLower.includes('exceeded your current quota') ||
    msgLower.includes('check your plan and billing') ||
    msgLower.includes('billing not enabled') ||
    msgLower.includes('free quota limit') ||
    msgLower.includes('daily quota') ||
    msgLower.includes('requests per day') ||
    msgLower.includes('insufficient quota');

  // Rate limit represents concurrency or short-term per-minute throttling
  const isRateLimitThrottling =
    msgLower.includes('rate limit') ||
    msgLower.includes('too many requests') ||
    msgLower.includes('requests per minute') ||
    msgLower.includes('tokens per minute') ||
    msgLower.includes('concurrency limit') ||
    (statusNum === 429 && !isExplicitQuotaExhausted);

  if (isExplicitQuotaExhausted) {
    return {
      category: 'QUOTA_EXHAUSTED',
      isTransient: false,
      isAuth: false,
      isQuota: true,
      isRateLimit: true,
      isModelError: false,
      statusCode: statusNum || 429,
      sanitizedMessage: sanitizedMsg,
      originalError: error,
    };
  }

  if (isRateLimitThrottling) {
    return {
      category: 'RATE_LIMIT',
      isTransient: false, // Rate limits should not be pounded blindly in immediate loops
      isAuth: false,
      isQuota: false,
      isRateLimit: true,
      isModelError: false,
      statusCode: statusNum || 429,
      sanitizedMessage: sanitizedMsg,
      originalError: error,
    };
  }

  // 4. Model Configuration Errors (model not found, thought_signature, unsupported params)
  const isModelError =
    statusNum === 404 ||
    msgLower.includes('not found') ||
    msgLower.includes('models/') ||
    msgLower.includes('invalid_argument') ||
    msgLower.includes('thought_signature') ||
    msgLower.includes('unsupported model');

  if (isModelError) {
    return {
      category: 'MODEL_ERROR',
      isTransient: false,
      isAuth: false,
      isQuota: false,
      isRateLimit: false,
      isModelError: true,
      statusCode: statusNum || 400,
      sanitizedMessage: sanitizedMsg,
      originalError: error,
    };
  }

  // 5. Transient Server Errors (HTTP 500, 502, 503, 504, UNAVAILABLE, network timeouts, connection resets)
  const isTransient =
    statusNum === 503 ||
    statusNum === 502 ||
    statusNum === 504 ||
    statusNum === 500 ||
    msgLower.includes('503') ||
    msgLower.includes('502') ||
    msgLower.includes('504') ||
    msgLower.includes('unavailable') ||
    msgLower.includes('high demand') ||
    msgLower.includes('overloaded') ||
    msgLower.includes('timed out') ||
    msgLower.includes('timeout') ||
    msgLower.includes('econnreset') ||
    msgLower.includes('etimedout') ||
    msgLower.includes('enotfound') ||
    msgLower.includes('und_err_connect_timeout') ||
    msgLower.includes('socket hang up') ||
    msgLower.includes('fetch failed');

  if (isTransient) {
    return {
      category: 'TRANSIENT_SERVER_ERROR',
      isTransient: true,
      isAuth: false,
      isQuota: false,
      isRateLimit: false,
      isModelError: false,
      statusCode: statusNum || 503,
      sanitizedMessage: sanitizedMsg,
      originalError: error,
    };
  }

  return {
    category: 'UNKNOWN_ERROR',
    isTransient: false,
    isAuth: false,
    isQuota: false,
    isRateLimit: false,
    isModelError: false,
    statusCode: statusNum,
    sanitizedMessage: sanitizedMsg,
    originalError: error,
  };
}

// ============================================================================
// 4. Custom Error Classes
// ============================================================================

export class GeminiAuthCircuitError extends Error {
  public readonly code = 'GEMINI_AUTH_CIRCUIT_OPEN';
  constructor(message: string = 'Gemini authentication circuit breaker is active. Requests are temporarily halted to protect server integrity.') {
    super(message);
    this.name = 'GeminiAuthCircuitError';
  }
}

// ============================================================================
// 5. Credential & Reliability Manager (Singleton)
// ============================================================================

export class GeminiReliabilityManager {
  private activeKeySource: 'PRIMARY' | 'BACKUP' = 'PRIMARY';

  // Circuit breaker state on authentication failure
  private circuitTrippedUntil: number | null = null;
  private readonly CIRCUIT_COOLDOWN_MS = 10 * 60 * 1000; // 10 minutes lockout

  // Tracking failures
  private primaryAuthFailed: boolean = false;
  private backupAuthFailed: boolean = false;
  private primaryQuotaFailed: boolean = false;
  private backupQuotaFailed: boolean = false;

  // Cached health probe state
  private lastHealthCheck: GeminiHealthStatus | null = null;
  private lastHealthCheckTimestamp: number = 0;
  private readonly HEALTH_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes cache

  /**
   * Safe in-memory credential resolution with zero per-request disk reads.
   * Works seamlessly on Vercel serverless environments and local development.
   */
  public getResolvedCredentials(): { primaryKey: string; backupKey: string | null } {
    let rawPrimary = '';
    if (process.env.GEMINI_API_KEY !== undefined && process.env.GEMINI_API_KEY.trim() !== '') {
      rawPrimary = process.env.GEMINI_API_KEY;
    } else if (process.env.GOOGLE_API_KEY !== undefined && process.env.GOOGLE_API_KEY.trim() !== '') {
      rawPrimary = process.env.GOOGLE_API_KEY;
    } else if (process.env.GOOGLE_GENAI_API_KEY !== undefined && process.env.GOOGLE_GENAI_API_KEY.trim() !== '') {
      rawPrimary = process.env.GOOGLE_GENAI_API_KEY;
    } else if (process.env.GEMINI_API_KEY !== undefined) {
      rawPrimary = process.env.GEMINI_API_KEY;
    } else {
      rawPrimary = env.GEMINI_API_KEY || '';
    }

    let cleanPrimary = rawPrimary.trim().replace(/^["']|["']$/g, '').trim();
    if (cleanPrimary === 'undefined' || cleanPrimary === 'null') {
      cleanPrimary = '';
    }

    let rawBackup = '';
    if (process.env.GEMINI_API_KEY_BACKUP !== undefined) {
      rawBackup = process.env.GEMINI_API_KEY_BACKUP;
    } else {
      rawBackup = env.GEMINI_API_KEY_BACKUP || '';
    }

    let cleanBackup = rawBackup.trim().replace(/^["']|["']$/g, '').trim();
    if (cleanBackup === 'undefined' || cleanBackup === 'null') {
      cleanBackup = '';
    }

    // Guard against fake/duplicate backup: never use the exact same key as backup
    let validBackup: string | null = null;
    if (cleanBackup.length >= 10 && cleanBackup !== cleanPrimary) {
      validBackup = cleanBackup;
    }

    return {
      primaryKey: cleanPrimary,
      backupKey: validBackup,
    };
  }

  /**
   * Returns list of loaded secret values for the redactor.
   */
  public getSecretsList(): string[] {
    const { primaryKey, backupKey } = this.getResolvedCredentials();
    const list: string[] = [];
    if (primaryKey) list.push(primaryKey);
    if (backupKey) list.push(backupKey);
    return list;
  }

  /**
   * Indicates whether any valid Gemini API key is configured.
   */
  public hasConfiguredKey(): boolean {
    const { primaryKey, backupKey } = this.getResolvedCredentials();
    return Boolean(
      (primaryKey && primaryKey.length >= 10) ||
      (backupKey && backupKey.length >= 10)
    );
  }

  /**
   * Returns current active key source ('PRIMARY' | 'BACKUP').
   */
  public getActiveSource(): 'PRIMARY' | 'BACKUP' {
    return this.activeKeySource;
  }

  /**
   * Check if circuit breaker is open.
   */
  public isCircuitTripped(): boolean {
    if (!this.circuitTrippedUntil) return false;
    const now = Date.now();
    if (now < this.circuitTrippedUntil) {
      return true;
    }
    // Cooldown elapsed, reset circuit
    this.circuitTrippedUntil = null;
    return false;
  }

  public getCircuitCooldownRemainingSeconds(): number {
    if (!this.circuitTrippedUntil) return 0;
    const remainingMs = this.circuitTrippedUntil - Date.now();
    return remainingMs > 0 ? Math.ceil(remainingMs / 1000) : 0;
  }

  /**
   * Retrieves an initialized GoogleGenAI SDK client with active credentials.
   * Throws GeminiAuthCircuitError if circuit breaker is open.
   */
  public getClient(): { client: GoogleGenAI; source: 'PRIMARY' | 'BACKUP' } {
    if (this.isCircuitTripped()) {
      const remainingSec = this.getCircuitCooldownRemainingSeconds();
      throw new GeminiAuthCircuitError(
        `Gemini authentication is temporarily suspended due to recent invalid credentials (${remainingSec}s remaining). Server in degraded safe mode.`
      );
    }

    const { primaryKey, backupKey } = this.getResolvedCredentials();

    // Check if we should use backup
    if (this.activeKeySource === 'BACKUP') {
      if (backupKey && !this.backupAuthFailed) {
        return { client: new GoogleGenAI({ apiKey: backupKey }), source: 'BACKUP' };
      }
      // Backup not available, revert to primary if primary hasn't failed auth
      if (primaryKey && !this.primaryAuthFailed) {
        this.activeKeySource = 'PRIMARY';
        return { client: new GoogleGenAI({ apiKey: primaryKey }), source: 'PRIMARY' };
      }
    }

    // Default: use primary
    if (primaryKey && !this.primaryAuthFailed) {
      return { client: new GoogleGenAI({ apiKey: primaryKey }), source: 'PRIMARY' };
    }

    // If primary failed auth, check if backup exists
    if (backupKey && !this.backupAuthFailed) {
      this.activeKeySource = 'BACKUP';
      console.warn('[GEMINI RELIABILITY] Primary key unavailable; utilizing configured backup key.');
      return { client: new GoogleGenAI({ apiKey: backupKey }), source: 'BACKUP' };
    }

    if (!primaryKey && !backupKey) {
      throw new Error('AI service is temporarily unavailable: GEMINI_API_KEY is not configured on the server.');
    }

    // Both failed
    throw new GeminiAuthCircuitError('All configured Gemini credentials have failed authentication. Halting calls.');
  }

  /**
   * Handles failure on a specific key source and evaluates failover or circuit trip.
   */
  public handleFailure(classified: ClassifiedGeminiError, sourceUsed: 'PRIMARY' | 'BACKUP'): {
    canFailover: boolean;
    circuitTripped: boolean;
  } {
    const { primaryKey, backupKey } = this.getResolvedCredentials();
    const hasDistinctBackup = Boolean(backupKey && backupKey !== primaryKey);

    if (classified.isAuth) {
      if (sourceUsed === 'PRIMARY') {
        this.primaryAuthFailed = true;
        if (hasDistinctBackup && !this.backupAuthFailed) {
          // Safe failover to backup
          this.activeKeySource = 'BACKUP';
          console.warn('[GEMINI RELIABILITY ⚠️] Primary key authentication failed. Safely failing over to GEMINI_API_KEY_BACKUP.');
          return { canFailover: true, circuitTripped: false };
        } else {
          // No backup available — trip circuit breaker
          this.tripCircuitBreaker('Primary key rejected authentication and no valid backup configured.');
          return { canFailover: false, circuitTripped: true };
        }
      } else {
        // Backup failed auth
        this.backupAuthFailed = true;
        this.tripCircuitBreaker('Backup key rejected authentication.');
        return { canFailover: false, circuitTripped: true };
      }
    }

    if (classified.isQuota) {
      if (sourceUsed === 'PRIMARY') {
        this.primaryQuotaFailed = true;
        if (hasDistinctBackup && !this.backupQuotaFailed) {
          this.activeKeySource = 'BACKUP';
          console.warn('[GEMINI RELIABILITY ⚠️] Primary key quota exhausted. Safely failing over to GEMINI_API_KEY_BACKUP.');
          return { canFailover: true, circuitTripped: false };
        }
      }
    }

    return { canFailover: false, circuitTripped: false };
  }

  /**
   * Trips the authentication circuit breaker and triggers asynchronous admin alert.
   */
  public tripCircuitBreaker(reason: string): void {
    this.circuitTrippedUntil = Date.now() + this.CIRCUIT_COOLDOWN_MS;
    console.error(`[ALPHA X GEMINI AUTH DIAGNOSTIC 🚨] Authentication circuit breaker tripped for 10m: ${reason}`);

    // Asynchronously notify admin without holding up request
    this.notifyAdminOfAuthFailure(reason).catch((err) => {
      console.warn('[GEMINI RELIABILITY] Failed to dispatch admin alert:', err?.message);
    });
  }

  /**
   * Resets failure flags and circuit breaker (e.g. after health check or env reload).
   */
  public resetState(): void {
    this.circuitTrippedUntil = null;
    this.primaryAuthFailed = false;
    this.backupAuthFailed = false;
    this.primaryQuotaFailed = false;
    this.backupQuotaFailed = false;
    this.activeKeySource = 'PRIMARY';
    this.lastHealthCheck = null;
    this.lastHealthCheckTimestamp = 0;
  }

  /**
   * Server-side diagnostic reporting and Admin alert logging without secrets.
   */
  public async notifyAdminOfAuthFailure(diagnosticDetails: string): Promise<void> {
    const sanitizedDetails = redactSecrets(diagnosticDetails, this.getSecretsList());

    // 1. Record diagnostic event in AIAuditLog
    try {
      await prisma.aIAuditLog.create({
        data: {
          adminId: 'SYSTEM',
          adminName: 'Alpha X Reliability Engine',
          action: 'GEMINI_AUTH_FAILURE',
          details: `Gemini authentication failure: ${sanitizedDetails}`,
          metadataJson: JSON.stringify({
            timestamp: new Date().toISOString(),
            activeSource: this.activeKeySource,
            circuitCooldownMinutes: 10,
          }),
        },
      });
    } catch (auditErr: any) {
      console.warn('[GEMINI RELIABILITY] Could not write audit log:', auditErr?.message);
    }

    // 2. Dispatch push notification to Admin device if OneSignal is configured
    try {
      const admins = await prisma.user.findMany({
        where: {
          role: 'ADMIN',
          oneSignalPlayerId: { not: null },
        },
        select: { oneSignalPlayerId: true },
      });

      for (const admin of admins) {
        if (admin.oneSignalPlayerId) {
          await oneSignalService.sendToPlayer(admin.oneSignalPlayerId, {
            title: '⚠️ AI COACH ALERT: Gemini Authentication Failure',
            body: 'Gemini API rejected server credentials. AI Coach entered degraded fallback mode. Please verify GEMINI_API_KEY.',
            data: { type: 'ai_auth_failure', timestamp: new Date().toISOString() },
          });
        }
      }
    } catch (pushErr: any) {
      console.warn('[GEMINI RELIABILITY] Could not send admin push notification:', pushErr?.message);
    }
  }

  /**
   * Lightweight health check probe.
   * Uses a 10-minute cache TTL so ordinary user requests never incur extra API latency or cost.
   */
  public async checkHealth(forceRefresh: boolean = false): Promise<GeminiHealthStatus> {
    const now = Date.now();
    if (!forceRefresh && this.lastHealthCheck && now - this.lastHealthCheckTimestamp < this.HEALTH_CACHE_TTL_MS) {
      return {
        ...this.lastHealthCheck,
        cooldownRemainingSeconds: this.getCircuitCooldownRemainingSeconds(),
      };
    }

    const { primaryKey, backupKey } = this.getResolvedCredentials();
    const hasBackupKey = Boolean(backupKey);

    if (!primaryKey && !backupKey) {
      const unconfigured: GeminiHealthStatus = {
        healthy: false,
        status: 'UNCONFIGURED',
        activeKeySource: 'NONE',
        hasBackupKey: false,
        isBackupActive: false,
        circuitTripped: false,
        cooldownRemainingSeconds: 0,
        model: 'none',
        lastChecked: new Date().toISOString(),
        message: 'GEMINI_API_KEY is not configured on the server.',
      };
      this.lastHealthCheck = unconfigured;
      this.lastHealthCheckTimestamp = now;
      return unconfigured;
    }

    if (this.isCircuitTripped()) {
      const circuitStatus: GeminiHealthStatus = {
        healthy: false,
        status: 'AUTH_FAILED',
        activeKeySource: this.activeKeySource,
        hasBackupKey,
        isBackupActive: this.activeKeySource === 'BACKUP',
        circuitTripped: true,
        cooldownRemainingSeconds: this.getCircuitCooldownRemainingSeconds(),
        model: 'none',
        lastChecked: new Date().toISOString(),
        message: 'Gemini authentication circuit breaker is active due to invalid credentials.',
      };
      this.lastHealthCheck = circuitStatus;
      this.lastHealthCheckTimestamp = now;
      return circuitStatus;
    }

    // Perform minimal, lightweight ping (1-token output) with 5s timeout
    const startTime = Date.now();
    try {
      const { client, source } = this.getClient();
      const testModel = 'gemini-flash-lite-latest';

      await Promise.race([
        client.models.generateContent({
          model: testModel,
          contents: 'ping',
          config: {
            maxOutputTokens: 1,
          },
        }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Health probe timed out after 5000ms')), 5000)),
      ]);

      const latencyMs = Date.now() - startTime;
      const healthyStatus: GeminiHealthStatus = {
        healthy: true,
        status: 'HEALTHY',
        activeKeySource: source,
        hasBackupKey,
        isBackupActive: source === 'BACKUP',
        circuitTripped: false,
        cooldownRemainingSeconds: 0,
        model: testModel,
        latencyMs,
        lastChecked: new Date().toISOString(),
        message: `Gemini API responding normally (${latencyMs}ms).`,
      };

      this.lastHealthCheck = healthyStatus;
      this.lastHealthCheckTimestamp = now;
      return healthyStatus;
    } catch (err: any) {
      const latencyMs = Date.now() - startTime;
      const classified = classifyGeminiError(err);

      let statusCategory: GeminiHealthStatus['status'] = 'UNAVAILABLE';
      if (classified.isAuth) statusCategory = 'AUTH_FAILED';
      else if (classified.isQuota) statusCategory = 'QUOTA_EXHAUSTED';
      else if (classified.isRateLimit) statusCategory = 'RATE_LIMITED';

      const unhealthyStatus: GeminiHealthStatus = {
        healthy: false,
        status: statusCategory,
        activeKeySource: this.activeKeySource,
        hasBackupKey,
        isBackupActive: this.activeKeySource === 'BACKUP',
        circuitTripped: this.isCircuitTripped(),
        cooldownRemainingSeconds: this.getCircuitCooldownRemainingSeconds(),
        model: 'gemini-flash-lite-latest',
        latencyMs,
        lastChecked: new Date().toISOString(),
        message: classified.sanitizedMessage.substring(0, 150),
      };

      this.lastHealthCheck = unhealthyStatus;
      this.lastHealthCheckTimestamp = now;
      return unhealthyStatus;
    }
  }

  /**
   * Executes an operation with bounded retries, exponential backoff, jitter, and safe backup failover.
   */
  public async executeWithReliability<T>(
    operation: (client: GoogleGenAI, source: 'PRIMARY' | 'BACKUP') => Promise<T>,
    options: {
      operationName?: string;
      maxRetries?: number;
      baseDelayMs?: number;
      maxDelayMs?: number;
    } = {}
  ): Promise<T> {
    const maxRetries = options.maxRetries ?? 2; // Maximum 2 retries (3 total attempts)
    const baseDelayMs = options.baseDelayMs ?? 1000;
    const maxDelayMs = options.maxDelayMs ?? 6000;
    const opName = options.operationName || 'GeminiCall';

    let attempt = 0;

    while (attempt <= maxRetries) {
      attempt++;
      let currentSource: 'PRIMARY' | 'BACKUP' = this.activeKeySource;

      try {
        const { client, source } = this.getClient();
        currentSource = source;
        return await operation(client, source);
      } catch (err: any) {
        if (err instanceof GeminiAuthCircuitError) {
          throw err;
        }

        const classified = classifyGeminiError(err);
        const secrets = this.getSecretsList();
        const safeErrorMsg = redactSecrets(classified.sanitizedMessage, secrets);

        // 1. Check for Authentication or Quota failures
        if (classified.isAuth || classified.isQuota) {
          const { canFailover, circuitTripped } = this.handleFailure(classified, currentSource);

          if (canFailover) {
            // Immediate retry with the backup key (reset attempt counter for the backup key)
            console.warn(`[GEMINI RELIABILITY] Failover activated for ${opName}: retrying with GEMINI_API_KEY_BACKUP.`);
            attempt = 0; // Fresh attempt for backup key
            continue;
          }

          if (circuitTripped) {
            throw new GeminiAuthCircuitError(
              'AI service authentication failed. Invalid API credentials on server. Admin has been notified.'
            );
          }

          if (classified.isQuota) {
            throw new Error('AI service quota has been reached. Please try again later.');
          }

          throw new Error('AI service authentication failed. Please verify server API key configuration.');
        }

        // 2. Transient server / network errors (503, high demand, timeouts)
        if (classified.isTransient && attempt <= maxRetries) {
          // Bounded exponential backoff + jitter
          const expDelay = Math.min(baseDelayMs * Math.pow(2, attempt - 1), maxDelayMs);
          const jitter = Math.random() * (expDelay * 0.4); // 0-40% jitter
          const delayMs = Math.round(expDelay + jitter);

          console.warn(
            `[GEMINI RETRY] [${opName}] Transient error (${classified.category}): ${safeErrorMsg.substring(0, 80)}. Retrying in ${delayMs}ms (attempt ${attempt}/${maxRetries})...`
          );
          await new Promise((resolve) => setTimeout(resolve, delayMs));
          continue;
        }

        // Non-transient errors or retries exhausted — rethrow with sanitized message
        const cleanedErr = new Error(safeErrorMsg);
        (cleanedErr as any).category = classified.category;
        (cleanedErr as any).statusCode = classified.statusCode;
        throw cleanedErr;
      }
    }

    throw new Error(`[${opName}] Gemini request failed after ${maxRetries} retry attempts.`);
  }
}

export const geminiReliability = new GeminiReliabilityManager();
