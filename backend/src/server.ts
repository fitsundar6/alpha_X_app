import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { env } from './config/environment';
import { sendSuccess } from './utils/responseEnvelope';
import { errorHandler } from './middlewares/errorHandler';
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
import { aiProposalsRoutes } from './modules/ai_coach/ai_proposals.routes';
import { notificationsRoutes } from './modules/notifications/notifications.routes';
import { aiNotificationEngine } from './modules/notifications/ai_notifications.service';
import cron from 'node-cron';

const app = express();

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

// Activity Tracking & Daily Step Routes
app.use('/api/v1/activity', activityRoutes);
app.use('/api/activity', activityRoutes);

// Authentication & Role Checking Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/auth', authRoutes);

// Client Self-Service Routes (Strictly scoped to authenticated user)
app.use('/api/v1/client', authRoutes); // Supports /api/v1/client/register, /api/v1/client/login
app.use('/api/client', authRoutes);
app.use('/api/v1/client', clientRoutes); // Supports /api/v1/client/me/workout, diet-plan, macros, progress, attendance
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

// Automation & Engagement Engine Routes
app.use('/api/v1/automation', automationRoutes);
app.use('/api/automation', automationRoutes);

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
    console.log(`=========================================`);
    try {
      const exRes = await exerciseService.seedDatabase();
      const foodRes = await foodService.seedDatabase();
      console.log(`✔ PostgreSQL Database ready (Exercises: ${exRes.total}, Foods: ${foodRes.total})`);
    } catch (e) {
      console.warn('Startup database auto-seed notice:', e);
    }

    // ── AI Push Notification Cron Job ─────────────────────────────────────
    // Fires every day at 6:00 PM local server time
    // Gemini generates a personal message per client, sent via OneSignal
    if (env.ONESIGNAL_APP_ID && env.ONESIGNAL_REST_API_KEY) {
      cron.schedule('0 18 * * *', () => {
        console.log('[CRON] 6:00 PM — Starting AI push notification sweep...');
        aiNotificationEngine.runDailySweep().catch((err) =>
          console.error('[CRON] Notification sweep error:', err?.message)
        );
      });
      console.log('🔔 AI Push Notifications: scheduled daily at 6:00 PM');
    } else {
      console.warn('🔔 AI Push Notifications: ONESIGNAL credentials not set — skipped');
    }
    // ─────────────────────────────────────────────────────────────────────
  });
}

export default app;
