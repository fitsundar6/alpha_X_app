import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';

// Augment Request to include unique request ID
declare global {
  namespace Express {
    interface Request {
      id?: string;
    }
  }
}

export interface ServerErrorInfo {
  req?: Request;
  method?: string;
  url?: string;
  statusCode?: number;
  errorCode?: string;
  errorMessage: string;
  error?: any;
  stack?: string;
  requestId?: string;
  clientId?: string;
  databaseError?: string;
  details?: any;
  timestamp?: string;
}

// Log file destination: <backend>/logs/server-errors.log
const LOGS_DIR = path.resolve(__dirname, '../../logs');
const LOG_FILE_PATH = path.join(LOGS_DIR, 'server-errors.log');

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
  if (req.user) {
    if ((req.user as any).clientId && typeof (req.user as any).clientId === 'string') {
      return (req.user as any).clientId;
    }
    if (req.user.id && typeof req.user.id === 'string') {
      return req.user.id;
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
 */
export function formatServerErrorLog(info: ServerErrorInfo): string {
  const timestamp = info.timestamp || new Date().toISOString();
  const method = info.method || info.req?.method || 'ERROR';
  const url = info.url || info.req?.originalUrl || info.req?.url || '/';
  const statusStr = info.statusCode ? ` (Status ${info.statusCode})` : '';

  const lines: string[] = [
    '======================================================================',
    `ERROR`,
    `${method} ${url}${statusStr}`,
    `Time: ${timestamp}`,
  ];

  if (info.requestId) {
    lines.push(`Request ID: ${info.requestId}`);
  }

  if (info.clientId) {
    lines.push(`Client ID: ${info.clientId}`);
  }

  if (info.errorCode && info.errorCode !== 'INTERNAL_ERROR') {
    lines.push(`Error Code: ${info.errorCode}`);
  }

  lines.push(`Error: ${info.errorMessage}`);

  if (info.databaseError) {
    lines.push(`Database Error: ${info.databaseError}`);
  }

  if (info.details) {
    if (Array.isArray(info.details) && info.details.length > 0) {
      const detailsText = info.details
        .map((d: any) => (d.field ? `${d.field}: ${d.message}` : d.message))
        .join('; ');
      lines.push(`Validation Details: ${detailsText}`);
    } else if (typeof info.details === 'object') {
      try {
        lines.push(`Details: ${JSON.stringify(info.details)}`);
      } catch (_) {}
    }
  }

  if (info.stack) {
    lines.push('Stack trace:');
    lines.push(info.stack);
  }

  lines.push('======================================================================');
  return lines.join('\n');
}

/**
 * Primary server logger:
 * 1. Outputs structured error block to console.error (visible in terminal, Docker, PM2, Vercel logs)
 * 2. Persists to backend/logs/server-errors.log file for inspection
 */
export function logServerError(info: ServerErrorInfo): void {
  // Fill missing fields from req if available
  const req = info.req;
  const method = info.method || req?.method || 'UNKNOWN';
  const url = info.url || req?.originalUrl || req?.url || '/';
  const requestId = info.requestId || (req ? extractRequestId(req) : undefined);
  const clientId = info.clientId || (req ? extractClientId(req) : undefined);
  const databaseError = info.databaseError || (info.error ? extractDatabaseError(info.error) : undefined);
  const timestamp = info.timestamp || new Date().toISOString();

  let stack = info.stack;
  if (!stack && info.error instanceof Error) {
    stack = info.error.stack;
  }

  const formatted = formatServerErrorLog({
    ...info,
    method,
    url,
    requestId,
    clientId,
    databaseError,
    timestamp,
    stack,
  });

  // 1. Write to standard error console (server stdout/stderr)
  console.error(formatted);

  // 2. Persist to server log file
  try {
    ensureLogDir();
    fs.appendFileSync(LOG_FILE_PATH, formatted + '\n\n', 'utf8');
  } catch (_) {
    // Non-blocking in serverless/read-only filesystem
  }
}

/**
 * Express middleware that initializes unique Request ID on every incoming request
 * and binds response tracking.
 */
export const requestIdMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  const reqId = extractRequestId(req, res);
  res.setHeader('X-Request-Id', reqId);

  // Fallback response finish hook:
  // If request finishes with status >= 400 and was not already logged, record it
  res.on('finish', () => {
    if (res.statusCode >= 400 && !(res.locals && res.locals.__errorLogged)) {
      logServerError({
        req,
        statusCode: res.statusCode,
        errorMessage: `HTTP ${res.statusCode} Error returned to client`,
        requestId: reqId,
        clientId: extractClientId(req),
      });
    }
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

export const serverLogFilePath = LOG_FILE_PATH;
