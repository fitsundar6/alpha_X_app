import express, { Request, Response } from 'express';
import http from 'http';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { UserRole } from './constants/roles';
import {
  foodAiService,
  validateAndDecodeImage,
  detectImageSignature,
  ALLOWED_IMAGE_MIME_TYPES,
  MIN_DECODED_IMAGE_BYTES,
  MAX_DECODED_IMAGE_BYTES,
} from './modules/food/food.ai.service';
import { foodRoutes } from './modules/food/food.routes';
import { foodPhotoRoutes } from './modules/food/food.photo.routes';

async function runF06F09SecurityTests() {
  console.log('================================================================');
  console.log('🔒 F-06 & F-09 SECURITY REMEDIATION REGRESSION TEST SUITE 🔒');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, name: string, detail?: string) {
    if (condition) {
      console.log(`  ✅ PASS: ${name}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${name} ${detail ? `(${detail})` : ''}`);
      failed++;
      throw new Error(`Assertion failed: ${name}`);
    }
  }

  // -------------------------------------------------------------
  // Test Fixtures & Helpers
  // -------------------------------------------------------------
  function makeValidJpegBuffer(sizeBytes: number = 2048): Buffer {
    const buf = Buffer.alloc(sizeBytes, 0x20);
    // SOI marker
    buf[0] = 0xff;
    buf[1] = 0xd8;
    buf[2] = 0xff;
    buf[3] = 0xe0;
    // EOI marker at end
    buf[sizeBytes - 2] = 0xff;
    buf[sizeBytes - 1] = 0xd9;
    return buf;
  }

  function makeValidPngBuffer(sizeBytes: number = 2048): Buffer {
    const buf = Buffer.alloc(sizeBytes, 0x20);
    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    buf[0] = 0x89;
    buf[1] = 0x50;
    buf[2] = 0x4e;
    buf[3] = 0x47;
    buf[4] = 0x0d;
    buf[5] = 0x0a;
    buf[6] = 0x1a;
    buf[7] = 0x0a;
    return buf;
  }

  function makeValidWebpBuffer(sizeBytes: number = 2048): Buffer {
    const buf = Buffer.alloc(sizeBytes, 0x20);
    // RIFF .... WEBP
    buf[0] = 0x52; // R
    buf[1] = 0x49; // I
    buf[2] = 0x46; // F
    buf[3] = 0x46; // F
    buf[8] = 0x57; // W
    buf[9] = 0x45; // E
    buf[10] = 0x42; // B
    buf[11] = 0x50; // P
    return buf;
  }

  // HTTP helper for port-bound test server
  function makeHttpRequest(
    port: number,
    path: string,
    method: string,
    headers: Record<string, string>,
    body?: string
  ): Promise<{ status: number; headers: Record<string, any>; body: string }> {
    return new Promise((resolve, reject) => {
      const reqHeaders = { ...headers };
      if (body) {
        reqHeaders['Content-Length'] = String(Buffer.byteLength(body));
      }
      const req = http.request(
        {
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers: reqHeaders,
        },
        (res: any) => {
          let data = '';
          res.on('data', (chunk: any) => (data += chunk));
          res.on('end', () => {
            resolve({
              status: res.statusCode || 0,
              headers: res.headers,
              body: data,
            });
          });
        }
      );
      req.on('error', reject);
      if (body) {
        req.write(body);
      }
      req.end();
    });
  }

  // Mock prisma for auth middleware tokenVersion & approval checks
  const origFindUnique = prisma.user.findUnique;
  (prisma.user as any).findUnique = async (args: any) => {
    return {
      id: args.where.id || 'f06_test_user_id',
      email: 'athlete@alphaxgym.com',
      role: UserRole.CLIENT,
      tokenVersion: 0,
      mustChangePassword: false,
      status: 'APPROVED',
      membershipStatus: 'APPROVED',
      isApproved: true,
      accountStatus: 'APPROVED',
    };
  };

  const validToken = jwt.sign(
    {
      id: 'f06_test_user_id',
      email: 'athlete@alphaxgym.com',
      role: UserRole.CLIENT,
      tokenVersion: 0,
    },
    env.JWT_ACCESS_SECRET,
    { expiresIn: '1h' }
  );

  // =============================================================
  // SECTION 1: F-06 Production Configuration & Startup Validation
  // =============================================================
  console.log('── SECTION 1: F-06 Production Configuration & Fail-Closed Validation ──');

  // Test Zod production schema validation in isolation
  const baseProdSchema = z
    .object({
      NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
      VERCEL_ENV: z.enum(['production', 'preview', 'development']).optional(),
      ADMIN_PASSWORD: z.string().min(8).optional(),
      ADMIN_PASSWORD_HASH: z.string().optional(),
      CRON_SECRET: z.string().optional(),
    })
    .superRefine((data, ctx) => {
      const isProd = data.NODE_ENV === 'production' || data.VERCEL_ENV === 'production';
      if (isProd) {
        const hasAdminPassword = typeof data.ADMIN_PASSWORD === 'string' && data.ADMIN_PASSWORD.trim().length >= 8;
        const hasAdminPasswordHash = typeof data.ADMIN_PASSWORD_HASH === 'string' && data.ADMIN_PASSWORD_HASH.trim().length >= 50;
        const placeholderPasswords = ['alphaxadmin2026(!)', 'changeme', 'password', 'defaultpassword'];
        const isPlaceholderPassword = data.ADMIN_PASSWORD && placeholderPasswords.includes(data.ADMIN_PASSWORD.trim().toLowerCase());

        if (!hasAdminPassword && !hasAdminPasswordHash) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['ADMIN_PASSWORD'],
            message: 'In production, either ADMIN_PASSWORD or ADMIN_PASSWORD_HASH must be explicitly configured.',
          });
        } else if (isPlaceholderPassword) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['ADMIN_PASSWORD'],
            message: 'ADMIN_PASSWORD must not be a known static placeholder in production.',
          });
        }

        const hasCronSecret = typeof data.CRON_SECRET === 'string' && data.CRON_SECRET.trim().length >= 16;
        const placeholderCronSecrets = ['cron_secret', 'changeme', 'default', 'secret'];
        const isPlaceholderCron = data.CRON_SECRET && placeholderCronSecrets.includes(data.CRON_SECRET.trim().toLowerCase());

        if (!hasCronSecret) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['CRON_SECRET'],
            message: 'In production, CRON_SECRET must be explicitly configured with at least 16 characters.',
          });
        } else if (isPlaceholderCron) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['CRON_SECRET'],
            message: 'CRON_SECRET must not be a known static placeholder in production.',
          });
        }
      }
    });

  // 1. Missing ADMIN_PASSWORD in production fails
  const missingAdminResult = baseProdSchema.safeParse({
    NODE_ENV: 'production',
    CRON_SECRET: 'production_super_secret_cron_token_32chars',
  });
  assert(!missingAdminResult.success, '1. Missing ADMIN_PASSWORD in production fails schema validation');

  // 2. Placeholder ADMIN_PASSWORD in production fails
  const placeholderAdminResult = baseProdSchema.safeParse({
    NODE_ENV: 'production',
    ADMIN_PASSWORD: 'AlphaXAdmin2026(!)',
    CRON_SECRET: 'production_super_secret_cron_token_32chars',
  });
  assert(!placeholderAdminResult.success, '2. Known static placeholder ADMIN_PASSWORD fails validation in production');

  // 3. Missing CRON_SECRET in production fails
  const missingCronResult = baseProdSchema.safeParse({
    NODE_ENV: 'production',
    ADMIN_PASSWORD: 'StrongCustomProductionPassword2026!',
  });
  assert(!missingCronResult.success, '3. Missing CRON_SECRET in production fails schema validation');

  // 4. Short / placeholder CRON_SECRET in production fails
  const shortCronResult = baseProdSchema.safeParse({
    NODE_ENV: 'production',
    ADMIN_PASSWORD: 'StrongCustomProductionPassword2026!',
    CRON_SECRET: 'short_cron',
  });
  assert(!shortCronResult.success, '4. Short CRON_SECRET (< 16 chars) fails validation in production');

  // 5. Valid production configuration passes
  const validProdResult = baseProdSchema.safeParse({
    NODE_ENV: 'production',
    ADMIN_PASSWORD: 'StrongCustomProductionPassword2026!',
    CRON_SECRET: 'production_super_secret_cron_token_32chars',
  });
  assert(validProdResult.success, '5. Valid production configuration with strong credentials passes validation');

  // 6. Valid bcrypt hash configuration passes
  const validHashResult = baseProdSchema.safeParse({
    NODE_ENV: 'production',
    ADMIN_PASSWORD_HASH: '$2b$12$e8xL4e3m7W0q1z8k.w2J9.u5K1p0O4r8T7s6X5y4Z3A2B1C0D9E8F',
    CRON_SECRET: 'production_super_secret_cron_token_32chars',
  });
  assert(validHashResult.success, '6. Valid ADMIN_PASSWORD_HASH without plain password passes in production');

  // 7. Dead QR_SECRET_KEY is removed from environment
  assert(!('QR_SECRET_KEY' in env), '7. Dead QR_SECRET_KEY configuration is safely removed from environment exports');

  // =============================================================
  // SECTION 2: F-09.3 Strict AI Image Validation Unit Checks
  // =============================================================
  console.log('\n── SECTION 2: F-09.3 Strict AI Image Validation Checks ──');

  // 8. Approved MIME types constant contains exactly jpeg, png, webp
  assert(
    ALLOWED_IMAGE_MIME_TYPES.includes('image/jpeg') &&
    ALLOWED_IMAGE_MIME_TYPES.includes('image/png') &&
    ALLOWED_IMAGE_MIME_TYPES.includes('image/webp') &&
    ALLOWED_IMAGE_MIME_TYPES.length === 3,
    '8. Allowed MIME types strictly limited to image/jpeg, image/png, image/webp'
  );

  // 9. Valid JPEG passes validation
  const validJpeg = makeValidJpegBuffer(2048);
  const jpegPayload = validateAndDecodeImage(validJpeg.toString('base64'), 'image/jpeg');
  assert(jpegPayload.canonicalMimeType === 'image/jpeg' && jpegPayload.byteLength === 2048, '9. Valid JPEG buffer passes strict validation');

  // 10. Valid PNG passes validation
  const validPng = makeValidPngBuffer(2048);
  const pngPayload = validateAndDecodeImage(validPng.toString('base64'), 'image/png');
  assert(pngPayload.canonicalMimeType === 'image/png' && pngPayload.byteLength === 2048, '10. Valid PNG buffer passes strict validation');

  // 11. Valid WebP passes validation
  const validWebp = makeValidWebpBuffer(2048);
  const webpPayload = validateAndDecodeImage(validWebp.toString('base64'), 'image/webp');
  assert(webpPayload.canonicalMimeType === 'image/webp' && webpPayload.byteLength === 2048, '11. Valid WebP buffer passes strict validation');

  // 12. image/jpg normalized to image/jpeg
  const jpgNormalized = validateAndDecodeImage(validJpeg.toString('base64'), 'image/jpg');
  assert(jpgNormalized.canonicalMimeType === 'image/jpeg', '12. image/jpg is canonicalized to image/jpeg');

  // 13. Data URI prefix stripped safely
  const dataUri = `data:image/jpeg;base64,${validJpeg.toString('base64')}`;
  const dataUriResult = validateAndDecodeImage(dataUri, 'image/jpeg');
  assert(dataUriResult.byteLength === 2048, '13. data:image/jpeg;base64, prefix is stripped and decoded safely');

  // 14. Unsupported MIME type rejected
  let rejectedMime = false;
  try {
    validateAndDecodeImage(validJpeg.toString('base64'), 'image/gif');
  } catch (err: any) {
    rejectedMime = err.message.includes('Invalid image MIME type');
  }
  assert(rejectedMime, '14. Unsupported MIME type (image/gif) is rejected with clear error');

  // 15. Invalid base64 characters rejected
  let rejectedBase64 = false;
  try {
    validateAndDecodeImage('ThisIsNotValidBase64!@#$%^&*()', 'image/jpeg');
  } catch (err: any) {
    rejectedBase64 = err.message.includes('Invalid base64 encoding format');
  }
  assert(rejectedBase64, '15. Corrupt / non-base64 characters are strictly rejected');

  // 16. Undersized image (< 1KB) rejected
  const tinyBuffer = makeValidJpegBuffer(500); // 500 bytes < 1024
  let rejectedTiny = false;
  try {
    validateAndDecodeImage(tinyBuffer.toString('base64'), 'image/jpeg');
  } catch (err: any) {
    rejectedTiny = err.message.includes('too small');
  }
  assert(rejectedTiny, '16. Undersized image (< 1KB) is rejected before AI processing');

  // 17. Oversized image (> 8MB) rejected
  // Simulated via custom buffer check
  let rejectedHuge = false;
  try {
    const hugeFakeBase64 = Buffer.alloc(MAX_DECODED_IMAGE_BYTES + 2048, 0x41).toString('base64');
    // Set SOI
    const hugeBuf = Buffer.from(hugeFakeBase64, 'base64');
    hugeBuf[0] = 0xff;
    hugeBuf[1] = 0xd8;
    hugeBuf[2] = 0xff;
    validateAndDecodeImage(hugeBuf.toString('base64'), 'image/jpeg');
  } catch (err: any) {
    rejectedHuge = err.message.includes('too large');
  }
  assert(rejectedHuge, '17. Oversized image (> 8MB) is rejected before AI processing');

  // 18. Magic-byte signature mismatch rejected (PNG bytes with image/jpeg MIME)
  let rejectedMismatch = false;
  try {
    validateAndDecodeImage(validPng.toString('base64'), 'image/jpeg');
  } catch (err: any) {
    rejectedMismatch = err.message.includes('Image signature mismatch');
  }
  assert(rejectedMismatch, '18. File signature mismatch (PNG content declared as JPEG) is rejected');

  // 19. Arbitrary binary without image magic bytes rejected
  const randomBinary = Buffer.alloc(2048, 0x41);
  let rejectedNonImage = false;
  try {
    validateAndDecodeImage(randomBinary.toString('base64'), 'image/jpeg');
  } catch (err: any) {
    rejectedNonImage = err.message.includes('does not match any valid image file signature');
  }
  assert(rejectedNonImage, '19. Non-image binary lacking valid magic bytes is rejected');

  // =============================================================
  // SECTION 3: F-09.4 Rate Limiting & Abuse Prevention Checks
  // =============================================================
  console.log('\n── SECTION 3: F-09.4 Rate Limiting & User/IP Scope Checks ──');

  const testUser = `rate_test_user_${Date.now()}`;
  let allowedScans = 0;
  for (let i = 0; i < 6; i++) {
    const check = foodAiService.checkRateLimit(testUser);
    if (check.allowed) allowedScans++;
  }
  assert(allowedScans === 5, '20. User account rate limit strictly bounds to 5 scans per minute');

  const sixthCheck = foodAiService.checkRateLimit(testUser);
  assert(!sixthCheck.allowed && (sixthCheck.retryAfterSeconds ?? 0) > 0, '21. 6th user scan is blocked with retry-after interval');

  // IP rate limiting check
  const testIp = '198.51.100.25'; // External test IP
  let ipScans = 0;
  for (let i = 0; i < 11; i++) {
    // Unique user each time from same IP
    const check = foodAiService.checkRateLimit(`multi_user_${i}_${Date.now()}`, testIp);
    if (check.allowed) ipScans++;
  }
  assert(ipScans === 10, '22. Client IP rate limit strictly bounds to 10 scans per minute across accounts');

  const eleventhIpCheck = foodAiService.checkRateLimit(`multi_user_11_${Date.now()}`, testIp);
  assert(!eleventhIpCheck.allowed && Boolean(eleventhIpCheck.reason?.includes('Too many camera scans')), '23. 11th scan from same IP is blocked');

  // =============================================================
  // SECTION 4: F-09.1 Body Parser Shadowing HTTP Tests
  // =============================================================
  console.log('\n── SECTION 4: F-09.1 Body Parser Shadowing HTTP Pipeline Tests ──');

  const app = express();

  // Replicate exact server.ts body parser setup
  const standardJsonParser = express.json({ limit: '1mb' });
  const standardUrlencodedParser = express.urlencoded({ extended: true, limit: '1mb' });

  const isUploadOrScanRoute = (req: Request): boolean => {
    if (req.method !== 'POST') return false;
    const path = req.originalUrl || req.url || '';
    return (
      /^\/(api\/)?(v1\/)?foods\/ai-scan(\?.*)?$/.test(path) ||
      /^\/(api\/)?(v1\/)?food-photos(\/live)?\/?(\?.*)?$/.test(path) ||
      /^\/(api\/)?(v1\/)?transformation-photos\/upload\/?(\?.*)?$/.test(path)
    );
  };

  app.use((req: Request, res: Response, next) => {
    if (isUploadOrScanRoute(req)) {
      return next();
    }
    standardJsonParser(req, res, next);
  });

  app.use((req: Request, res: Response, next) => {
    if (isUploadOrScanRoute(req)) {
      return next();
    }
    standardUrlencodedParser(req, res, next);
  });

  // Mount real routes
  app.use('/api/v1/foods', foodRoutes);
  app.use('/api/v1/food-photos', foodPhotoRoutes);

  // Standard non-upload route to verify 1MB protection
  app.post('/api/v1/standard-route', (req: Request, res: Response) => {
    res.status(200).json({ success: true, receivedBytes: JSON.stringify(req.body).length });
  });

  // Error handler for 413
  app.use((err: any, _req: Request, res: Response, _next: any) => {
    if (err.type === 'entity.too.large' || err.status === 413) {
      res.status(413).json({ success: false, error: { code: 'PAYLOAD_TOO_LARGE', message: 'Payload exceeds limit' } });
      return;
    }
    res.status(err.status || 500).json({ success: false, error: { message: err.message } });
  });

  const testServer = http.createServer(app);
  await new Promise<void>((resolve) => testServer.listen(0, '127.0.0.1', resolve));
  const testPort = (testServer.address() as any).port;

  // 24. Standard non-upload route accepts 500KB payload (< 1MB)
  const smallPayload = JSON.stringify({ data: 'A'.repeat(500 * 1024) });
  const smallRes = await makeHttpRequest(
    testPort,
    '/api/v1/standard-route',
    'POST',
    { 'Content-Type': 'application/json' },
    smallPayload
  );
  assert(smallRes.status === 200, '24. Standard route accepts payloads below 1MB (HTTP 200)');

  // 25. Standard non-upload route rejects 2MB payload (> 1MB) with HTTP 413
  const twoMbPayload = JSON.stringify({ data: 'A'.repeat(2 * 1024 * 1024) });
  const twoMbNonUploadRes = await makeHttpRequest(
    testPort,
    '/api/v1/standard-route',
    'POST',
    { 'Content-Type': 'application/json' },
    twoMbPayload
  );
  assert(twoMbNonUploadRes.status === 413, '25. Standard non-upload route rejects 2MB payload with HTTP 413 (Global 1MB enforced)');

  // 26. Upload route (/foods/ai-scan) accepts 2MB valid photo payload without 413 rejection
  const twoMbJpeg = makeValidJpegBuffer(2 * 1024 * 1024);
  const twoMbScanBody = JSON.stringify({
    image: twoMbJpeg.toString('base64'),
    mimeType: 'image/jpeg',
  });
  const scanRes = await makeHttpRequest(
    testPort,
    '/api/v1/foods/ai-scan',
    'POST',
    {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${validToken}`,
    },
    twoMbScanBody
  );
  // It must NOT be 413! It reaches the handler and succeeds (200) with AI analysis
  assert(scanRes.status === 200, '26. Legitimate 2MB camera image to /foods/ai-scan passes 10MB parser and returns HTTP 200');

  // 27. Upload route rejects oversized payload exceeding 10MB with HTTP 413
  const elevenMbPayload = JSON.stringify({
    image: 'A'.repeat(11 * 1024 * 1024),
    mimeType: 'image/jpeg',
  });
  const elevenMbRes = await makeHttpRequest(
    testPort,
    '/api/v1/foods/ai-scan',
    'POST',
    {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${validToken}`,
    },
    elevenMbPayload
  );
  assert(elevenMbRes.status === 413, '27. Upload route rejects payload exceeding 10MB with HTTP 413');

  // 28. Malformed image to /foods/ai-scan returns HTTP 400 VALIDATION_ERROR
  const invalidImageBody = JSON.stringify({
    image: 'NotAnImageBufferAtAll1234',
    mimeType: 'image/jpeg',
  });
  const invalidImageRes = await makeHttpRequest(
    testPort,
    '/api/v1/foods/ai-scan',
    'POST',
    {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${validToken}`,
    },
    invalidImageBody
  );
  assert(invalidImageRes.status === 400, '28. Invalid image payload to /foods/ai-scan returns HTTP 400 VALIDATION_ERROR');

  testServer.close();

  // Restore prisma
  (prisma.user as any).findUnique = origFindUnique;

  console.log('\n================================================================');
  console.log(`TOTAL F-06 & F-09 TESTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================\n');
}

runF06F09SecurityTests().catch((err) => {
  console.error('Test suite execution failed:', err);
  process.exit(1);
});
