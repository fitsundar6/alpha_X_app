import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';

// Augment Request to include unique request ID and timing
declare global {
  namespace Express {
    interface Request {
      id?: string;
      _startTime?: number;
    }
  }
}

export interface ServerActivityInfo {
  req?: Request;
  method?: string;
  url?: string;
  statusCode?: number;
  activity?: string;
  reason?: string;
  errorMessage?: string;
  errorCode?: string;
  error?: any;
  stack?: string;
  requestId?: string;
  clientId?: string;
  databaseError?: string;
  details?: any;
  explanation?: string;
  resourceId?: string;
  resourceType?: string;
  receivedPayload?: any;
  durationMs?: number;
  timestamp?: string;
}

export type ServerErrorInfo = ServerActivityInfo;

// Log file destinations
const LOGS_DIR = path.resolve(__dirname, '../../logs');
const ERROR_LOG_PATH = path.join(LOGS_DIR, 'server-errors.log');
const ACTIVITY_LOG_PATH = path.join(LOGS_DIR, 'server-activity.log');

/**
 * Safely ensure the logs directory exists
 */
function ensureLogDir(): void {
  try {
    if (!fs.existsSync(LOGS_DIR)) {
      fs.mkdirSync(LOGS_DIR, { recursive: true });
    }
  } catch (_) {
    // Read-only filesystem fallback (e.g. Vercel serverless lambda)
  }
}

/**
 * Extracts the Request ID from request object or incoming headers
 */
export function extractRequestId(req?: Request, res?: Response): string {
  if (!req) return crypto.randomUUID().slice(0, 8);
  if (req.id && typeof req.id === 'string') return req.id;

  const headerId = (req.headers['x-request-id'] || req.headers['request-id']) as string;
  if (headerId && typeof headerId === 'string' && headerId.trim()) {
    req.id = headerId.trim();
    return req.id;
  }

  if (res && typeof res.getHeader === 'function') {
    const resHeader = res.getHeader('x-request-id') as string;
    if (resHeader && typeof resHeader === 'string' && resHeader.trim()) {
      req.id = resHeader.trim();
      return req.id;
    }
  }

  const generated = crypto.randomUUID().slice(0, 8);
  req.id = generated;
  return generated;
}

/**
 * Extracts Client ID / User ID safely from request context, token, body, or headers
 */
export function extractClientId(req?: Request): string | undefined {
  if (!req) return undefined;

  // 1. From authenticated req.user (JWT verified)
  const user = (req as any).user;
  if (user) {
    if (user.clientId && typeof user.clientId === 'string') {
      return user.clientId;
    }
    if (user.id && typeof user.id === 'string') {
      return user.id;
    }
    if (user.email && typeof user.email === 'string') {
      return user.email;
    }
  }

  // 2. From standard Alpha X headers
  const headerClientId = req.headers['x-client-id'] || req.headers['x-user-id'];
  if (headerClientId && typeof headerClientId === 'string' && headerClientId.trim()) {
    return headerClientId.trim();
  }

  // 3. From request body
  if (req.body && typeof req.body === 'object') {
    if (typeof req.body.clientId === 'string' && req.body.clientId.trim()) {
      return req.body.clientId.trim();
    }
    if (typeof req.body.userId === 'string' && req.body.userId.trim()) {
      return req.body.userId.trim();
    }
    if (typeof req.body.clientIdOrEmail === 'string' && req.body.clientIdOrEmail.trim()) {
      return req.body.clientIdOrEmail.trim();
    }
    if (typeof req.body.email === 'string' && req.body.email.trim()) {
      return req.body.email.trim();
    }
  }

  // 4. From params or query string
  if (req.params?.clientId && typeof req.params.clientId === 'string') {
    return req.params.clientId.trim();
  }
  if (req.params?.id && typeof req.params.id === 'string' && (req.baseUrl || '').includes('client')) {
    return req.params.id.trim();
  }
  if (req.query?.clientId && typeof req.query.clientId === 'string') {
    return req.query.clientId.trim();
  }

  return undefined;
}

/**
 * Safely extracts client IP address
 */
export function extractClientIp(req?: Request): string {
  if (!req) return '127.0.0.1';
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || (req.socket && req.socket.remoteAddress) || '127.0.0.1';
}

/**
 * Inspects any thrown error or exception and extracts underlying Prisma / PostgreSQL database errors
 */
export function extractDatabaseError(err: any): string | undefined {
  if (!err) return undefined;

  // 1. Prisma Client Errors
  if (err.name?.startsWith('Prisma') || err.code?.startsWith('P') || err.clientVersion) {
    const parts: string[] = [];
    if (err.code) parts.push(`Code: ${err.code}`);
    if (err.name) parts.push(`Type: ${err.name}`);

    if (err.meta) {
      try {
        parts.push(`Meta: ${JSON.stringify(err.meta)}`);
      } catch (_) {}
    }

    // Clean message: strip verbose prisma internal lines
    const rawMsg = err.message || '';
    const cleanLines = rawMsg
      .split('\n')
      .map((l: string) => l.trim())
      .filter((l: string) => l.length > 0 && !l.startsWith('-->') && !l.startsWith('prisma:'));

    if (cleanLines.length > 0) {
      parts.push(cleanLines.slice(0, 3).join('; '));
    }

    return parts.join(' | ');
  }

  // 2. Network / TCP database failures (e.g. database host unreachable or timeout)
  if (err.code === 'ECONNREFUSED' || err.code === 'ETIMEDOUT' || err.code === 'ENOTFOUND') {
    return `Database connection failed (${err.code}: ${err.message || 'connection refused'})`;
  }

  // 3. Native Postgres error fields
  if (err.table || err.constraint || err.detail) {
    const parts: string[] = [];
    if (err.detail) parts.push(`Detail: ${err.detail}`);
    if (err.table) parts.push(`Table: ${err.table}`);
    if (err.constraint) parts.push(`Constraint: ${err.constraint}`);
    return parts.join(' | ');
  }

  // 4. String error message mentioning database operations
  const msg = typeof err === 'string' ? err : err.message;
  if (typeof msg === 'string') {
    const lower = msg.toLowerCase();
    if (
      lower.includes('database') ||
      lower.includes('prisma') ||
      lower.includes('postgres') ||
      lower.includes('connection failed') ||
      lower.includes('can\'t reach database server') ||
      lower.includes('query failed') ||
      lower.includes('unique constraint') ||
      lower.includes('foreign key')
    ) {
      return msg;
    }
  }

  return undefined;
}

/**
 * Standardized block formatter matching the required Alpha X Gym server log specification
 * Provides crystal-clear visual banners, status codes, actual reasons, queried IDs, and failed fields.
 */
export function formatActivityLog(info: ServerActivityInfo): string {
  const timestamp = info.timestamp || new Date().toISOString();
  const method = (info.method || info.req?.method || 'GET').toUpperCase();
  const url = info.url || info.req?.originalUrl || info.req?.url || '/';
  const status = info.statusCode || 200;
  const isSuccess = status >= 200 && status < 400;

  // Banner categorization
  let banner = '[ACTION SUCCESS]';
  if (status === 400) banner = '[ACTION BAD REQUEST]';
  else if (status === 401) banner = '[ACTION AUTH FAILURE - UNAUTHORIZED]';
  else if (status === 403) banner = '[ACTION FORBIDDEN - ACCESS DENIED]';
  else if (status === 404) banner = '[ACTION NOT FOUND]';
  else if (status === 409) banner = '[ACTION CONFLICT]';
  else if (status === 422) banner = '[ACTION UNPROCESSABLE ENTITY]';
  else if (status >= 500) banner = info.databaseError ? '[ACTION DATABASE FAILURE]' : '[ACTION SYSTEM FAILURE]';

  const separator = isSuccess
    ? '----------------------------------------------------------------------'
    : '======================================================================';

  const durationStr = info.durationMs !== undefined ? ` | Latency: ${info.durationMs}ms` : '';

  const lines: string[] = [
    separator,
    isSuccess ? banner : `ERROR ${banner} (Status ${status})`,
    `${method} ${url}`,
    `Status: ${status} ${isSuccess ? 'SUCCESS' : 'FAILED'}${durationStr}`,
    `Time: ${timestamp}`,
  ];

  if (info.requestId) {
    lines.push(`Request ID: ${info.requestId}`);
  }

  if (info.clientId) {
    lines.push(`Client ID: ${info.clientId}`);
  }

  if (info.activity) {
    lines.push(`Activity: ${info.activity}`);
  }

  // The primary, accurate reason
  const actualReason = info.reason || info.errorMessage;
  if (actualReason) {
    if (isSuccess) {
      lines.push(`Result: ${actualReason}`);
    } else {
      lines.push(`Error: ${actualReason}`);
      lines.push(`Actual Reason: ${actualReason}`);
    }
  } else if (!isSuccess) {
    lines.push(`Error: HTTP ${status} error returned`);
  }

  // Queried resource details (Crucial for 404 diagnostics)
  if (info.resourceId || info.resourceType) {
    const resName = info.resourceType ? `${info.resourceType} ` : 'Resource ';
    lines.push(`Queried ${resName}: "${info.resourceId || 'unknown'}"`);
  }

  // Explanation context to eliminate ambiguity
  if (info.explanation) {
    lines.push(`Explanation: ${info.explanation}`);
  }

  if (info.errorCode && info.errorCode !== 'INTERNAL_ERROR') {
    lines.push(`Error Code: ${info.errorCode}`);
  }

  if (info.databaseError) {
    lines.push(`Database Error: ${info.databaseError}`);
  }

  // Detailed validation failure breakdown
  if (info.details) {
    if (Array.isArray(info.details) && info.details.length > 0) {
      lines.push('Failed Fields / Details:');
      for (const d of info.details) {
        if (typeof d === 'object' && d !== null) {
          const path = (d as any).path
            ? (Array.isArray((d as any).path) ? (d as any).path.join('.') : String((d as any).path))
            : (d as any).field || '';
          const msg = (d as any).message || JSON.stringify(d);
          lines.push(`  • ${path ? `${path}: ` : ''}${msg}`);
        } else {
          lines.push(`  • ${String(d)}`);
        }
      }
    } else if (typeof info.details === 'object') {
      try {
        lines.push(`Details: ${JSON.stringify(info.details)}`);
      } catch (_) {}
    }
  }

  // Received payload summary (if bad request or validation error)
  if (info.receivedPayload && status === 400) {
    try {
      const scrubSensitive = (obj: any): any => {
        if (!obj || typeof obj !== 'object') return obj;
        if (Array.isArray(obj)) return obj.map(scrubSensitive);
        const sensitiveKeys = [
          'password',
          'newpassword',
          'confirmpassword',
          'oldpassword',
          'currentpassword',
          'temppassword',
          'temporarypassword',
          'token',
          'resettoken',
          'refreshtoken',
          'accesstoken',
          'code',
          'resetcode',
          'hash',
          'passwordhash',
          'secret',
          'jwt',
          'credential',
          'authorization',
        ];
        const res: Record<string, any> = {};
        for (const [k, v] of Object.entries(obj)) {
          const lk = k.toLowerCase();
          if (sensitiveKeys.some((sk) => lk.includes(sk))) {
            res[k] = '***REDACTED***';
          } else if (typeof v === 'object' && v !== null) {
            res[k] = scrubSensitive(v);
          } else {
            res[k] = v;
          }
        }
        return res;
      };
      const sanitized = scrubSensitive(info.receivedPayload);
      lines.push(`Received Payload: ${JSON.stringify(sanitized)}`);
    } catch (_) {}
  }

  // Stack trace (for 500 errors)
  if (info.stack) {
    lines.push('Stack trace:');
    lines.push(info.stack);
  }

  lines.push(separator);
  return lines.join('\n');
}

export function formatServerErrorLog(info: ServerErrorInfo): string {
  return formatActivityLog(info);
}

/**
 * Primary Activity Logger:
 * 1. Outputs structured log block to console (stdout for success, warn for 4xx, error for 5xx)
 * 2. Persists to backend/logs/server-activity.log (All actions)
 * 3. Persists errors (4xx & 5xx) to backend/logs/server-errors.log
 */
export function logActivity(info: ServerActivityInfo): void {
  const req = info.req;
  const method = info.method || req?.method || 'UNKNOWN';
  const url = info.url || req?.originalUrl || req?.url || '/';
  const requestId = info.requestId || (req ? extractRequestId(req) : undefined);
  const clientId = info.clientId || (req ? extractClientId(req) : undefined);
  const databaseError = info.databaseError || (info.error ? extractDatabaseError(info.error) : undefined);
  const timestamp = info.timestamp || new Date().toISOString();

  let durationMs = info.durationMs;
  if (durationMs === undefined && req?._startTime) {
    durationMs = Date.now() - req._startTime;
  }

  let stack = info.stack;
  if (!stack && info.error instanceof Error) {
    stack = info.error.stack;
  }

  const formatted = formatActivityLog({
    ...info,
    method,
    url,
    requestId,
    clientId,
    databaseError,
    durationMs,
    timestamp,
    stack,
  });

  // 1. Output to console with proper severity level
  const status = info.statusCode || 200;
  if (status >= 500) {
    console.error(formatted);
  } else if (status >= 400) {
    console.warn(formatted);
  } else {
    console.log(formatted);
  }

  // 2. Persist to activity log (all requests) and error log (failures only)
  try {
    ensureLogDir();
    fs.appendFileSync(ACTIVITY_LOG_PATH, formatted + '\n\n', 'utf8');
    if (status >= 400) {
      fs.appendFileSync(ERROR_LOG_PATH, formatted + '\n\n', 'utf8');
    }
  } catch (_) {
    // Non-blocking in serverless environments
  }
}

/**
 * Backwards-compatible server error logging function
 */
export function logServerError(info: ServerErrorInfo): void {
  logActivity({
    ...info,
    statusCode: info.statusCode || 500,
  });
}

/**
 * Universal Request Tracking & Activity Logger Middleware:
 * - Initializes X-Request-Id header.
 * - Records start timestamp for latency calculation.
 * - Captures response completion on 'finish'.
 * - If not explicitly logged by controller or responseEnvelope, logs action automatically!
 */
export const requestIdMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  const reqId = extractRequestId(req, res);
  res.setHeader('X-Request-Id', reqId);
  req._startTime = Date.now();

  res.on('finish', () => {
    // Check if this response was already logged by sendSuccess, sendError, or route handler
    if ((res as any).locals && (res as any).locals.__logged) {
      return;
    }

    const durationMs = req._startTime ? Date.now() - req._startTime : undefined;
    const statusCode = res.statusCode;
    const method = req.method;
    const url = req.originalUrl || req.url;

    // Build intelligent accurate reason based on route and status
    let reason = `HTTP ${statusCode} response returned`;
    let explanation: string | undefined;

    if (statusCode === 404) {
      reason = `Endpoint "${method} ${url}" was not found`;
      explanation = 'No registered Express route matched this HTTP method and URL path.';
    } else if (statusCode === 401) {
      reason = 'Unauthorized request: Missing or invalid authentication token';
    } else if (statusCode === 403) {
      reason = 'Forbidden: Access credentials do not have required permissions for this action';
    } else if (statusCode === 400) {
      reason = 'Bad Request: Client provided an invalid or malformed request payload';
    } else if (statusCode >= 200 && statusCode < 300) {
      reason = `Action completed successfully (${statusCode})`;
    }

    logActivity({
      req,
      statusCode,
      activity: `${method} ${url}`,
      reason,
      explanation,
      durationMs,
      requestId: reqId,
      clientId: extractClientId(req),
    });
  });

  next();
};

/**
 * Patch Express 4 Layer to automatically forward unhandled Promise rejections
 * from async route handlers to next(err).
 */
export function applyExpressAsyncErrorsPatch(): void {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const Layer = require('express/lib/router/layer');
    if (Layer && Layer.prototype && !Layer.prototype.__asyncPatched) {
      const originalHandle = Layer.prototype.handle_request;
      Layer.prototype.__asyncPatched = true;
      Layer.prototype.handle_request = function (req: any, res: any, next: any) {
        const fn = this.handle;
        if (fn.length > 3) {
          // Error handler (err, req, res, next)
          return originalHandle.apply(this, arguments);
        }
        try {
          const result = fn(req, res, next);
          if (result && typeof result.then === 'function') {
            result.catch(next);
          }
        } catch (err) {
          next(err);
        }
      };
    }
  } catch (e) {
    console.warn('[ServerLogger] Notice: Express async layer patch skipped:', e);
  }
}

export const serverLogFilePath = ERROR_LOG_PATH;
export const serverActivityLogFilePath = ACTIVITY_LOG_PATH;
