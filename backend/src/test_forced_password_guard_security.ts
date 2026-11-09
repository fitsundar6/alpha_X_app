import express from 'express';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';
import { requireAuth } from './middlewares/auth';
import { passwordResetService } from './services/password_reset.service';
import { HttpStatus } from './constants/httpStatus';
import { UserRole } from './constants/roles';
import { prisma } from './config/prisma';

interface MockResponse {
  statusCode: number | null;
  body: any;
  status: (code: number) => MockResponse;
  json: (payload: any) => MockResponse;
  setHeader: (name: string, value: string) => MockResponse;
}

function createMockRes(): MockResponse {
  const res: any = {
    statusCode: null,
    body: null,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(payload: any) {
      this.body = payload;
      return this;
    },
    setHeader() {
      return this;
    },
  };
  return res;
}

async function testMiddlewareDirect(params: {
  method: string;
  baseUrl?: string;
  path?: string;
  originalUrl?: string;
  token: string;
}): Promise<{ statusCode: number | null; errorCode?: string; nextCalled: boolean }> {
  let nextCalled = false;
  const fullUrl = params.originalUrl || `${params.baseUrl || ''}${params.path || ''}`;
  const req: any = {
    method: params.method,
    baseUrl: params.baseUrl,
    path: params.path,
    originalUrl: fullUrl,
    url: params.path || fullUrl,
    headers: {
      authorization: `Bearer ${params.token}`,
    },
  };
  const res = createMockRes();
  const next = () => {
    nextCalled = true;
  };

  await requireAuth(req, res as any, next);

  return {
    statusCode: res.statusCode,
    errorCode: res.body?.error?.code,
    nextCalled,
  };
}

async function runSecurityRegressionSuite() {
  console.log('================================================================');
  console.log('🔒 FORCED PASSWORD GUARD SECURITY REGRESSION TEST SUITE 🔒');
  console.log('================================================================');

  const FORCED_USER_ID = 'forced_password_test_user_uuid';
  const NORMAL_USER_ID = 'normal_account_test_user_uuid';

  // Sign realistic JWT tokens for both test profiles
  const forcedUserToken = jwt.sign(
    { id: FORCED_USER_ID, email: 'forced_temp_client@alphax.test', role: UserRole.CLIENT },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  const normalUserToken = jwt.sign(
    { id: NORMAL_USER_ID, email: 'active_client@alphax.test', role: UserRole.CLIENT },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  // Isolate and stub passwordResetService.isForcedPasswordChangeRequired in-memory
  const originalIsForced = passwordResetService.isForcedPasswordChangeRequired;
  passwordResetService.isForcedPasswordChangeRequired = async (userId: string): Promise<boolean> => {
    if (userId === FORCED_USER_ID) return true;
    if (userId === NORMAL_USER_ID) return false;
    return originalIsForced.call(passwordResetService, userId);
  };

  // F-04: Mock prisma.user.findUnique so the tokenVersion DB check succeeds
  // without a real database connection. Test tokens have no tokenVersion claim,
  // so requireAuth defaults to claimedVersion=0; return tokenVersion:0 to match.
  const originalFindUnique = prisma.user.findUnique;
  (prisma.user.findUnique as any) = async (args: any) => {
    const id = args?.where?.id;
    if (id === FORCED_USER_ID || id === NORMAL_USER_ID) {
      return { tokenVersion: 0 };
    }
    return null;
  };

  let totalTests = 0;
  let passedTests = 0;

  function assertCase(desc: string, condition: boolean, detail: string) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  ✔ PASS [${totalTests}]: ${desc}`);
    } else {
      console.error(`  ❌ FAIL [${totalTests}]: ${desc} -> ${detail}`);
      throw new Error(`Test assertion failed: ${desc}`);
    }
  }

  try {
    // -------------------------------------------------------------
    // CATEGORY 1: Query-String Bypass Blocked (mustChangePassword = true)
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 1] Query-String Bypass Blocked:');

    // 1. GET /api/v1/workout?next=/auth/me
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/workout',
        path: '/',
        originalUrl: '/api/v1/workout?next=/auth/me',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/workout?next=/auth/me blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && res.errorCode === 'FORCED_PASSWORD_CHANGE_REQUIRED' && !res.nextCalled,
        `Expected 403 FORCED_PASSWORD_CHANGE_REQUIRED, got status ${res.statusCode}, error ${res.errorCode}`
      );
    }

    // 2. GET /api/v1/workout?next=/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/workout',
        path: '/',
        originalUrl: '/api/v1/workout?next=/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/workout?next=/change-password blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && res.errorCode === 'FORCED_PASSWORD_CHANGE_REQUIRED' && !res.nextCalled,
        `Expected 403 FORCED_PASSWORD_CHANGE_REQUIRED, got status ${res.statusCode}, error ${res.errorCode}`
      );
    }

    // 3. GET /api/v1/client/profile?foo=/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/client',
        path: '/profile',
        originalUrl: '/api/v1/client/profile?foo=/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/client/profile?foo=/change-password blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && res.errorCode === 'FORCED_PASSWORD_CHANGE_REQUIRED' && !res.nextCalled,
        `Expected 403 FORCED_PASSWORD_CHANGE_REQUIRED, got status ${res.statusCode}, error ${res.errorCode}`
      );
    }

    // 4. POST /api/v1/workout?next=/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/workout',
        path: '/',
        originalUrl: '/api/v1/workout?next=/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/workout?next=/change-password blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && res.errorCode === 'FORCED_PASSWORD_CHANGE_REQUIRED' && !res.nextCalled,
        `Expected 403 FORCED_PASSWORD_CHANGE_REQUIRED, got status ${res.statusCode}, error ${res.errorCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 2: Wrong HTTP Methods Blocked
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 2] Wrong HTTP Methods Blocked:');

    // 5. GET /api/v1/auth/change-password (wrong method GET)
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/auth/change-password (wrong method GET) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && res.errorCode === 'FORCED_PASSWORD_CHANGE_REQUIRED' && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 6. POST /api/v1/auth/me (wrong method POST)
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/auth',
        path: '/me',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/auth/me (wrong method POST) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && res.errorCode === 'FORCED_PASSWORD_CHANGE_REQUIRED' && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 7. PUT /api/v1/auth/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'PUT',
        baseUrl: '/api/v1/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'PUT /api/v1/auth/change-password blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 8. DELETE /api/v1/auth/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'DELETE',
        baseUrl: '/api/v1/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'DELETE /api/v1/auth/change-password blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 3: Semicolon-Suffixed Paths Cannot Become Exempt
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 3] Semicolon-Suffixed Paths Cannot Become Exempt:');

    // 9. GET /api/v1/workout;/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/workout',
        path: '/;change-password',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/workout;/change-password (semicolon in workout path) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 10. POST /api/v1/auth/change-password;admin
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/auth',
        path: '/change-password;admin',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/auth/change-password;admin (semicolon appended) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 11. GET /api/v1/auth/me;bypass
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/auth',
        path: '/me;bypass',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/auth/me;bypass (semicolon appended) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 4: Unexpected Aliases Remain Blocked
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 4] Unexpected & Speculative Aliases Remain Blocked:');

    // 12. GET /api/v1/client/me
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/client',
        path: '/me',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/client/me blocked with 403 (speculative alias removed)',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 13. POST /api/v1/client/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/client',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/client/change-password blocked with 403 (non-existent route)',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 14. GET /api/client/me
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/client',
        path: '/me',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/client/me blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 15. POST /api/client/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/client',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/client/change-password blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 5: Path Suffixes and Prefixes Remain Blocked
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 5] Path Suffixes and Prefixes Remain Blocked:');

    // 16. GET /api/v1/auth/me/workout
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/auth',
        path: '/me/workout',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/auth/me/workout (suffix under me) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 17. POST /api/v1/auth/change-password/leak
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/auth',
        path: '/change-password/leak',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/auth/change-password/leak (suffix) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 18. GET /api/v1/auth/me_extra
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/auth',
        path: '/me_extra',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/auth/me_extra (string extension) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // 19. POST /prefix/api/v1/auth/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/prefix/api/v1/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /prefix/api/v1/auth/change-password (prefix spoofing) blocked with 403',
        res.statusCode === HttpStatus.FORBIDDEN && !res.nextCalled,
        `Expected 403, got status ${res.statusCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 6: Legitimate Recovery Routes Remain Accessible
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 6] Legitimate Recovery Routes Remain Accessible:');

    // 20. GET /api/v1/auth/me
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/auth',
        path: '/me',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/auth/me allowed through to handler',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 21. GET /api/v1/auth/me?format=json
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/v1/auth',
        path: '/me',
        originalUrl: '/api/v1/auth/me?format=json',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/v1/auth/me?format=json allowed through',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 22. GET /api/auth/me
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/api/auth',
        path: '/me',
        token: forcedUserToken,
      });
      assertCase(
        'GET /api/auth/me (compat mount) allowed through',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 23. GET /auth/me
    {
      const res = await testMiddlewareDirect({
        method: 'GET',
        baseUrl: '/auth',
        path: '/me',
        token: forcedUserToken,
      });
      assertCase(
        'GET /auth/me (root compat mount) allowed through',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 24. POST /api/v1/auth/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/auth/change-password allowed through to handler',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 25. POST /api/v1/auth/change-password?ref=login
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/v1/auth',
        path: '/change-password',
        originalUrl: '/api/v1/auth/change-password?ref=login',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/v1/auth/change-password?ref=login allowed through',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 26. POST /api/auth/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/api/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /api/auth/change-password (compat mount) allowed through',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // 27. POST /auth/change-password
    {
      const res = await testMiddlewareDirect({
        method: 'POST',
        baseUrl: '/auth',
        path: '/change-password',
        token: forcedUserToken,
      });
      assertCase(
        'POST /auth/change-password (root compat mount) allowed through',
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 7: Normal Accounts Continue to Work (Zero Regressions)
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 7] Normal Accounts Continue to Work (Zero Regressions):');

    const normalRoutes = [
      { method: 'GET', baseUrl: '/api/v1/workout', path: '/' },
      { method: 'GET', baseUrl: '/api/v1/workout', path: '/', originalUrl: '/api/v1/workout?next=/auth/me' },
      { method: 'GET', baseUrl: '/api/v1/client', path: '/profile', originalUrl: '/api/v1/client/profile?foo=/change-password' },
      { method: 'POST', baseUrl: '/api/v1/workout', path: '/' },
      { method: 'GET', baseUrl: '/api/v1/auth', path: '/me' },
      { method: 'POST', baseUrl: '/api/v1/auth', path: '/change-password' },
      { method: 'GET', baseUrl: '/api/v1/client', path: '/me/workout' },
      { method: 'GET', baseUrl: '/api/v1/foods', path: '/' },
    ];

    for (const r of normalRoutes) {
      const res = await testMiddlewareDirect({
        method: r.method,
        baseUrl: r.baseUrl,
        path: r.path,
        originalUrl: r.originalUrl,
        token: normalUserToken,
      });
      assertCase(
        `${r.method} ${r.baseUrl}${r.path} for normal account allowed with zero blocking`,
        res.nextCalled && res.statusCode === null,
        `Expected next() called, got status ${res.statusCode}`
      );
    }

    // -------------------------------------------------------------
    // CATEGORY 8: Real Express App & Router End-to-End Pipeline
    // -------------------------------------------------------------
    console.log('\n[CATEGORY 8] Real Express App & Router End-to-End Pipeline:');

    const testApp = express();
    testApp.use(express.json());

    // Mount an auth router with requireAuth
    const testAuthRouter = express.Router();
    testAuthRouter.get('/me', requireAuth, (_req, res) => {
      res.status(200).json({ success: true, endpoint: 'me' });
    });
    testAuthRouter.post('/change-password', requireAuth, (_req, res) => {
      res.status(200).json({ success: true, endpoint: 'change-password' });
    });
    testApp.use('/api/v1/auth', testAuthRouter);

    // Mount a workout router with requireAuth
    const testWorkoutRouter = express.Router();
    testWorkoutRouter.use(requireAuth);
    testWorkoutRouter.get('/', (_req, res) => {
      res.status(200).json({ success: true, endpoint: 'workout' });
    });
    testApp.use('/api/v1/workout', testWorkoutRouter);

    // Helper to dispatch request through express testApp
    async function dispatchExpressRequest(method: string, url: string, token: string): Promise<{ status: number; body: any }> {
      return new Promise((resolve) => {
        const http = require('http');
        const req = new http.IncomingMessage({} as any);
        req.method = method;
        req.url = url;
        req.headers = {
          host: 'localhost',
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        };

        const resBodyChunks: Buffer[] = [];
        const res: any = {
          statusCode: 200,
          headers: {},
          setHeader(k: string, v: string) {
            this.headers[k] = v;
          },
          getHeader(k: string) {
            return this.headers[k];
          },
          status(code: number) {
            this.statusCode = code;
            return this;
          },
          write(chunk: any) {
            if (chunk) resBodyChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
          },
          end(chunk?: any) {
            if (chunk) resBodyChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
            const rawBody = Buffer.concat(resBodyChunks).toString('utf8');
            let parsed: any = null;
            try {
              parsed = JSON.parse(rawBody);
            } catch {
              parsed = rawBody;
            }
            resolve({ status: this.statusCode, body: parsed });
          },
          json(payload: any) {
            this.statusCode = this.statusCode || 200;
            this.setHeader('content-type', 'application/json');
            this.end(JSON.stringify(payload));
          },
        };

        (testApp as any).handle(req, res);
      });
    }

    // Test 36: Express pipeline blocks /api/v1/workout?next=/auth/me
    {
      const resp = await dispatchExpressRequest('GET', '/api/v1/workout?next=/auth/me', forcedUserToken);
      assertCase(
        'Express dispatch: GET /api/v1/workout?next=/auth/me returns 403',
        resp.status === 403 && resp.body?.error?.code === 'FORCED_PASSWORD_CHANGE_REQUIRED',
        `Expected 403, got status ${resp.status}, body: ${JSON.stringify(resp.body)}`
      );
    }

    // Test 37: Express pipeline allows legitimate GET /api/v1/auth/me
    {
      const resp = await dispatchExpressRequest('GET', '/api/v1/auth/me', forcedUserToken);
      assertCase(
        'Express dispatch: GET /api/v1/auth/me returns 200 SUCCESS',
        resp.status === 200 && resp.body?.endpoint === 'me',
        `Expected 200, got status ${resp.status}, body: ${JSON.stringify(resp.body)}`
      );
    }

    // Test 38: Express pipeline allows legitimate POST /api/v1/auth/change-password
    {
      const resp = await dispatchExpressRequest('POST', '/api/v1/auth/change-password', forcedUserToken);
      assertCase(
        'Express dispatch: POST /api/v1/auth/change-password returns 200 SUCCESS',
        resp.status === 200 && resp.body?.endpoint === 'change-password',
        `Expected 200, got status ${resp.status}, body: ${JSON.stringify(resp.body)}`
      );
    }

    // Test 39: Express pipeline allows normal account on /api/v1/workout
    {
      const resp = await dispatchExpressRequest('GET', '/api/v1/workout', normalUserToken);
      assertCase(
        'Express dispatch: GET /api/v1/workout for normal user returns 200 SUCCESS',
        resp.status === 200 && resp.body?.endpoint === 'workout',
        `Expected 200, got status ${resp.status}, body: ${JSON.stringify(resp.body)}`
      );
    }

    console.log('\n================================================================');
    console.log(`✅ ALL ${passedTests}/${totalTests} SECURITY REGRESSION CHECKS PASSED SUCCESSFULLY!`);
    console.log('================================================================');
  } finally {
    // Restore original service method and Prisma mock
    passwordResetService.isForcedPasswordChangeRequired = originalIsForced;
    prisma.user.findUnique = originalFindUnique;
  }
}

runSecurityRegressionSuite().catch((err) => {
  console.error('Fatal test failure:', err);
  process.exit(1);
});
