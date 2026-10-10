import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { env } from './config/environment';
import { sendSuccess, sendError } from './utils/responseEnvelope';
import { errorHandler } from './middlewares/errorHandler';
import { HttpStatus } from './constants/httpStatus';
import {
  requestIdMiddleware,
  applyExpressAsyncErrorsPatch,
  logServerError,
  extractDatabaseError,
  serverLogFilePath,
} from './utils/serverLogger';

// Apply Express 4 async promise rejection patch
applyExpressAsyncErrorsPatch();

// Global process-level safety traps to catch any unhandled promise rejections or background exceptions
process.on('unhandledRejection', (reason: any) => {
  logServerError({
    errorMessage: `Unhandled Promise Rejection: ${reason?.message || String(reason)}`,
    error: reason,
    stack: reason instanceof Error ? reason.stack : undefined,
    databaseError: extractDatabaseError(reason),
  });
});

process.on('uncaughtException', (err: Error) => {
  logServerError({
    errorMessage: `Uncaught Exception: ${err.message}`,
    error: err,
    stack: err.stack,
    databaseError: extractDatabaseError(err),
  });
});

import { activityRoutes } from './modules/activity/activity.routes';
import { authRoutes } from './modules/auth/auth.routes';
import { workoutRoutes } from './modules/workout/workout.routes';
import { exerciseRoutes } from './modules/exercise/exercise.routes';
import { exerciseService } from './modules/exercise/exercise.service';
import { foodRoutes } from './modules/food/food.routes';
import { foodService } from './modules/food/food.service';
import { adminRoutes } from './modules/admin/admin.routes';
import { clientRoutes } from './modules/client/client.routes';
import { foodPhotoRoutes } from './modules/food/food.photo.routes';
import { automationRoutes } from './modules/automation/automation.routes';
import { aiCoachRoutes } from './modules/ai_coach/ai_coach.routes';
import { geminiReliability } from './modules/ai_coach/gemini.reliability';
import { aiProposalsRoutes } from './modules/ai_coach/ai_proposals.routes';
import { notificationsRoutes } from './modules/notifications/notifications.routes';
import { aiNotificationEngine } from './modules/notifications/ai_notifications.service';
import { telemetryRoutes } from './modules/telemetry/telemetry.routes';
import { telemetryService } from './modules/telemetry/telemetry.service';
import { workoutRepository } from './modules/workout/workout.repository';
import { prisma } from './config/prisma';
import { foodPhotoCleanupService } from './modules/food/food_photo_cleanup.service';
import cron from 'node-cron';

const app = express();

// Track and assign unique Request IDs to all incoming mobile/client requests
app.use(requestIdMiddleware);


// Security Headers (relaxed for development and cross-origin Flutter Web API access)
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    crossOriginEmbedderPolicy: false,
    crossOriginOpenerPolicy: false,
  })
);

// CORS configuration (supports native mobile apps, web, and production domains)
const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    // 1. Mobile native apps (iOS / Android Flutter) do not send Origin header
    if (!origin) {
      return callback(null, true);
    }
    // 2. Local development & testing
    if (env.NODE_ENV === 'development' || env.NODE_ENV === 'test') {
      return callback(null, true);
    }
    // 3. Whitelist check
    const allowed = env.CORS_ORIGIN.split(',').map((o) => o.trim());
    if (allowed.includes('*') || allowed.includes(origin)) {
      return callback(null, true);
    }
    // 4. Vercel deployment preview / prod URLs and custom domain
    if (origin.endsWith('.vercel.app') || origin.endsWith('.alphaxgym.com')) {
      return callback(null, true);
    }
    return callback(new Error(`CORS policy: Origin ${origin} not allowed`));
  },
  credentials: true,
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Accept',
    'Origin',
    'x-client-id',
    'x-user-id',
  ],
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

// Trust the first proxy hop (Vercel edge / load balancer).
// Required so express-rate-limit can safely read X-Forwarded-For
// to identify real client IPs instead of the proxy's IP.
app.set('trust proxy', 1);

// Rate limiting to protect against brute force and DDoS
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300, // Limit each IP to 300 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many requests from this IP, please try again later.',
    },
    meta: {
      timestamp: new Date().toISOString(),
      version: '1.0.0',
    },
  },
});
app.use(generalLimiter);

// Parse JSON and urlencoded request bodies
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Query / Path Normalizer Middleware (Handles accidental /api?v1 typos or missing slashes)
app.use((req: Request, _res: Response, next) => {
  if (req.url.startsWith('/api?v1')) {
    req.url = req.url.replace('/api?v1', '/api/v1');
  }
  next();
});

// Base Health Check Endpoints (Available on /, /api, /health, /api/health, and /api/v1/health)
const healthHandler = (_req: Request, res: Response) => {
  sendSuccess(res, {
    status: 'healthy',
    service: 'Alpha X Gym REST API',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    environment: env.NODE_ENV,
    host: env.HOST,
    port: env.PORT,
    aiCoach: geminiReliability.hasConfiguredKey()
      ? geminiReliability.isCircuitTripped()
        ? 'degraded'
        : 'available'
      : 'unconfigured',
  });
};

app.get('/', (_req: Request, res: Response) => {
  const accept = _req.headers.accept || '';
  if (accept.includes('text/html')) {
    res.status(200).send(`
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Alpha X Gym API — Online</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0b0f19; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; text-align: center; }
            .card { background: rgba(255,255,255,0.04); padding: 48px 36px; border-radius: 20px; border: 1px solid rgba(255,255,255,0.1); max-width: 480px; box-shadow: 0 12px 40px rgba(0,0,0,0.6); }
            h1 { color: #f59e0b; margin: 0 0 12px; font-size: 26px; letter-spacing: 1px; }
            p { color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 12px 0 24px; }
            .badge { display: inline-flex; align-items: center; gap: 8px; background: #10b981; color: #042f1a; font-weight: 700; padding: 8px 18px; border-radius: 30px; font-size: 13px; letter-spacing: 0.5px; }
            .badge span { display: inline-block; width: 8px; height: 8px; background: #042f1a; border-radius: 50%; }
            .endpoint { margin-top: 24px; padding: 12px; background: rgba(0,0,0,0.4); border-radius: 10px; font-family: monospace; font-size: 13px; color: #38bdf8; word-break: break-all; }
            a { color: #38bdf8; text-decoration: none; font-size: 13px; }
            a:hover { text-decoration: underline; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>ALPHA X GYM API</h1>
            <p>Production serverless REST API & managed PostgreSQL database are running healthy.</p>
            <div class="badge"><span></span> SYSTEM ONLINE</div>
            <div class="endpoint">Base URL: /api/v1</div>
            <p style="margin-top: 20px; margin-bottom: 0;"><a href="/api/v1/health">View JSON Health Check →</a></p>
          </div>
        </body>
      </html>
    `);
    return;
  }
  healthHandler(_req, res);
});
app.get('/api', healthHandler);
app.get('/health', healthHandler);
app.get('/api/health', healthHandler);
app.get('/api/v1/health', healthHandler);
app.get('/favicon.ico', (_req: Request, res: Response) => res.status(204).end());

// Activity Tracking & Daily Step Routes
app.use('/api/v1/activity', activityRoutes);
app.use('/api/activity', activityRoutes);

// Authentication & Role Checking Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes);

// Client Self-Service Routes (Strictly scoped to authenticated user)
app.use('/api/v1/client', authRoutes); // Supports /api/v1/client/register, /api/v1/client/login
app.use('/api/client', authRoutes);
app.use('/api/v1/client', clientRoutes); // Supports /api/v1/client/me/workout, diet-plan, macros, progress
app.use('/api/client', clientRoutes);

// Workout Session Management & Execution Routes
app.use('/api/v1/workout', workoutRoutes);
app.use('/api/workout', workoutRoutes);

// Exercise Database & Sync Engine Routes
app.use('/api/v1/exercises', exerciseRoutes);
app.use('/api/exercises', exerciseRoutes);

// Food Database & Global Custom Food Catalog Routes
app.use('/api/v1/foods', foodRoutes);
app.use('/api/foods', foodRoutes);

// Confirmed Meal Photos & Secure Streaming Routes
app.use('/api/v1/food-photos', foodPhotoRoutes);
app.use('/api/food-photos', foodPhotoRoutes);

// Master Administrator Operations & Authentication (requireAdmin)
app.use('/api/admin', adminRoutes);
app.use('/api/v1/admin', adminRoutes);

// Master Alpha X AI Coach Operations
app.use('/api/admin/ai-coach', aiCoachRoutes);
app.use('/api/v1/admin/ai-coach', aiCoachRoutes);
app.use('/api/ai', aiCoachRoutes);
app.use('/api/v1/ai', aiCoachRoutes);

// AI Plan Proposals — Admin review & approve generated plans
app.use('/api/admin/ai-proposals', aiProposalsRoutes);
app.use('/api/v1/admin/ai-proposals', aiProposalsRoutes);

// Push Notifications — Device registration & AI daily sweep routes
app.use('/api/v1/notifications', notificationsRoutes);
app.use('/api/notifications', notificationsRoutes);

// Weekly Alpha Telemetry — Sunday "Spotify-Wrapped for Lifting"
app.use('/api/v1/telemetry', telemetryRoutes);
app.use('/api/telemetry', telemetryRoutes);

// Automation & Engagement Engine Routes
app.use('/api/v1/automation', automationRoutes);
app.use('/api/automation', automationRoutes);

// Diagnostic error simulation route (strictly enabled only in development/test environments)
if (env.NODE_ENV !== 'production') {
  app.get(['/api/v1/simulate-error', '/api/simulate-error'], async (_req, _res) => {
    throw new Error('Intentional unexpected server exception: failed to calculate telemetry vector');
  });
}

// 404 handler for unmatched routes (ensures non-existent endpoints are properly recorded in server logs)
app.use((req: Request, res: Response) => {
  sendError(
    res,
    'NOT_FOUND',
    `Endpoint not found: ${req.method} ${req.originalUrl}`,
    HttpStatus.NOT_FOUND,
    undefined,
    undefined,
    {
      resourceType: 'API Route',
      resourceId: `${req.method} ${req.originalUrl}`,
      explanation: 'No registered Express route matches this HTTP method and URL path on the server.',
    }
  );
});

// Centralized error handler
app.use(errorHandler);

// Start server if executed directly and not running in test mode or Vercel serverless
const isTestRun =
  env.NODE_ENV === 'test' ||
  process.env.NODE_ENV === 'test' ||
  process.argv.some((arg) => arg.includes('test_') || arg.includes('.test.') || arg.includes('.spec.'));

const isVercel = Boolean(process.env.VERCEL || process.env.NOW_REGION);

const isDirectRun =
  require.main === module ||
  process.argv.some((arg) => arg.includes('server') || arg.endsWith('server.ts') || arg.endsWith('server.js')) ||
  process.env.npm_lifecycle_event === 'dev' ||
  process.env.npm_lifecycle_event === 'start';

if (!isTestRun && !isVercel && isDirectRun) {
  app.listen(env.PORT, env.HOST, async () => {
    console.log(`=========================================`);
    console.log(`🚀 ALPHA X GYM REST API running on http://${env.HOST}:${env.PORT}`);
    console.log(`🛡️  Environment: ${env.NODE_ENV}`);
    console.log(`🩺 Health check: http://localhost:${env.PORT}/api/v1/health`);
    console.log(`📱 Physical Phone (iPhone / Android) URL: http://<WINDOWS-PC-LAN-IP>:${env.PORT}/api/v1`);
    console.log(`🤖 Android Emulator URL: http://10.0.2.2:${env.PORT}/api/v1`);
    console.log(`📁 Server Error Log File: ${serverLogFilePath}`);
    console.log(`=========================================`);

    try {
      // Warm up connection to cloud PostgreSQL if it was idle/sleeping
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          await prisma.$queryRaw`SELECT 1`;
          break;
        } catch {
          if (attempt < 3) {
            console.log(`[Database] Warming up cloud database (attempt ${attempt}/3)...`);
            await new Promise((r) => setTimeout(r, 2000));
          }
        }
      }

      const exRes = await exerciseService.seedDatabase();
      const foodRes = await foodService.seedDatabase();
      console.log(`✔ PostgreSQL Database ready (Exercises: ${exRes.total}, Foods: ${foodRes.total})`);
    } catch (e) {
      console.warn('Startup database reference seed notice:', e);
    }

    // ── Proactive AI Coach Push Notification Schedulers ───────────────────
    // Autonomous scheduled triggers:
    // 1. Morning Readiness Check-in at 7:30 AM ("Leg Day today at 6 PM. Drink water...")
    // 2. Missed Workout Auto-Regulation at 10:30 AM ("Missed yesterday? Swap to today...")
    // 3. Evening Accountability & Nutrition Sweep at 8:30 PM (Protein & recovery sleep)
    if (env.ONESIGNAL_APP_ID && env.ONESIGNAL_REST_API_KEY) {
      // 1. 7:30 AM — Morning Readiness Check-in
      cron.schedule('30 7 * * *', () => {
        console.log('[CRON] 7:30 AM — Starting AI Morning Readiness Check-in sweep...');
        aiNotificationEngine.runMorningCheckInSweep().catch((err) =>
          console.error('[CRON] Morning check-in sweep error:', err?.message)
        );
      });

      // 2. 10:30 AM — Missed Workout Auto-Regulation Sweep
      cron.schedule('30 10 * * *', () => {
        console.log('[CRON] 10:30 AM — Starting AI Missed Workout Auto-Regulation sweep...');
        aiNotificationEngine.runMissedWorkoutSweep().catch((err) =>
          console.error('[CRON] Missed workout sweep error:', err?.message)
        );
      });

      // 3. 8:30 PM — Evening Accountability & Recovery Sleep Sweep
      cron.schedule('30 20 * * *', () => {
        console.log('[CRON] 8:30 PM — Starting AI Evening Accountability sweep...');
        aiNotificationEngine.runEveningCheckInSweep().catch((err) =>
          console.error('[CRON] Evening check-in sweep error:', err?.message)
        );
      });

      // 4. 8:00 PM Sunday — "Spotify-Wrapped for Lifting" Alpha Telemetry Report
      cron.schedule('0 20 * * 0', () => {
        console.log('[CRON] Sunday 8:00 PM — Starting Sunday Alpha Telemetry sweep...');
        telemetryService.dispatchSundayTelemetrySweep().catch((err) =>
          console.error('[CRON] Sunday Telemetry sweep error:', err?.message)
        );
      });

      console.log('🔔 Proactive AI Coach & Sunday Telemetry: Autonomous Push Crons active (7:30 AM, 10:30 AM, 8:30 PM, Sun 8:00 PM)');
    } else {
      console.warn('🔔 Proactive AI Coach: ONESIGNAL credentials not set — push notifications skipped');
    }
    // ─────────────────────────────────────────────────────────────────────

    // ── 15-Day Client Food Journal Photo Storage Auto-Cleanup Cron ────────
    // Runs daily at 2:00 AM UTC
    // Purges physical food photo files older than 15 days from storage
    // strictly preserving food log records, nutrition, and macros.
    cron.schedule('0 2 * * *', () => {
      console.log('[CRON] 2:00 AM — Starting 15-day client food journal photo cleanup sweep...');
      foodPhotoCleanupService.cleanupExpiredFoodPhotos(15).catch((err) =>
        console.error('[CRON] Food photo cleanup sweep error:', err?.message)
      );
    });
    console.log('🧹 Food Photo Storage: 15-day auto-cleanup cron active (daily at 2:00 AM UTC)');
  });
}

export default app;
