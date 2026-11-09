import express from 'express';
import jwt from 'jsonwebtoken';
import http from 'http';
import { env } from './config/environment';
import { prisma } from './config/prisma';
import { authRoutes } from './modules/auth/auth.routes';
import { passwordResetService } from './services/password_reset.service';
import { UserRole } from './constants/roles';

async function runEndpointsSuite() {
  console.log('================================================================');
  console.log('TEST SUITE: BACKEND FORCED PASSWORD /me & /refresh CONTRACTS');
  console.log('================================================================');

  let passedTests = 0;
  let totalTests = 0;

  function assertTest(name: string, condition: boolean, details?: string) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  [PASS] Test ${totalTests}: ${name}`);
    } else {
      console.error(`  [FAIL] Test ${totalTests}: ${name}`);
      if (details) console.error(`         Details: ${details}`);
      throw new Error(`Test failed: ${name}`);
    }
  }

  // Setup express test server mounting actual authRoutes
  const app = express();
  app.use(express.json());
  app.use('/api/v1/auth', authRoutes);

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}/api/v1/auth`;

  // Preserve original prisma methods
  const originalUserFindUnique = prisma.user.findUnique;
  const originalUserUpdate = prisma.user.update;
  const originalProfileFindUnique = prisma.clientProfile.findUnique;

  try {
    const forcedUserId = 'test-forced-user-uuid-123';
    const normalUserId = 'test-normal-user-uuid-456';
    const adminUserId = 'test-admin-user-uuid-789';

    const forcedToken = jwt.sign(
      { id: forcedUserId, email: 'forced@alphax.test', role: UserRole.CLIENT },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const normalToken = jwt.sign(
      { id: normalUserId, email: 'normal@alphax.test', role: UserRole.CLIENT },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    const adminToken = jwt.sign(
      { id: adminUserId, email: env.ADMIN_EMAIL.toLowerCase(), role: UserRole.ADMIN },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '1h' }
    );

    // Mock prisma responses
    (prisma.user.findUnique as any) = async ({ where }: any) => {
      if (where.id === forcedUserId || where.email === 'forced@alphax.test') {
        return {
          id: forcedUserId,
          email: 'forced@alphax.test',
          role: UserRole.CLIENT,
          status: 'APPROVED',
          rejectionReason: null,
          rejectedAt: null,
          approvedAt: new Date(),
          mustChangePassword: true,
          passwordHash: '$2b$10$abcdefghijklmnopqrstuvwxyz123456',
          clientProfile: {
            clientId: 'AXG-0002',
            onboardingCompleted: true,
            onboardingStep: 3,
          },
        };
      }
      if (where.id === normalUserId || where.email === 'normal@alphax.test') {
        return {
          id: normalUserId,
          email: 'normal@alphax.test',
          role: UserRole.CLIENT,
          status: 'APPROVED',
          rejectionReason: null,
          rejectedAt: null,
          approvedAt: new Date(),
          mustChangePassword: false,
          passwordHash: '$2b$10$abcdefghijklmnopqrstuvwxyz123456',
          clientProfile: {
            clientId: 'AXG-0003',
            onboardingCompleted: true,
            onboardingStep: 3,
          },
        };
      }
      if (where.id === adminUserId || where.email === env.ADMIN_EMAIL.toLowerCase()) {
        return {
          id: adminUserId,
          email: env.ADMIN_EMAIL.toLowerCase(),
          role: UserRole.ADMIN,
          status: 'APPROVED',
          rejectionReason: null,
          rejectedAt: null,
          approvedAt: new Date(),
          mustChangePassword: false,
          passwordHash: '$2b$10$abcdefghijklmnopqrstuvwxyz123456',
        };
      }
      return null;
    };

    (prisma.clientProfile.findUnique as any) = async ({ where }: any) => {
      if (where.userId === forcedUserId) {
        return {
          clientId: 'AXG-0002',
          onboardingCompleted: true,
          onboardingStep: 3,
        };
      }
      if (where.userId === normalUserId) {
        return {
          clientId: 'AXG-0003',
          onboardingCompleted: true,
          onboardingStep: 3,
        };
      }
      return null;
    };

    let updatedUserId: string | null = null;
    let updatedData: any = null;
    (prisma.user.update as any) = async ({ where, data }: any) => {
      updatedUserId = where.id;
      updatedData = data;
      return { id: where.id, ...data };
    };

    // -------------------------------------------------------------
    // TEST 1: GET /api/v1/auth/me returns mustChangePassword = true
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${forcedToken}` },
      });
      const body: any = await res.json();

      assertTest(
        'GET /api/v1/auth/me returns 200 with mustChangePassword = true',
        res.status === 200 && body.success === true && body.data?.mustChangePassword === true,
        `Expected mustChangePassword = true, got: ${JSON.stringify(body.data)}`
      );
      assertTest(
        'GET /api/v1/auth/me returns correct client profile metadata',
        body.data?.clientId === 'AXG-0002' && body.data?.role === 'CLIENT',
        `Expected clientId AXG-0002 and role CLIENT, got: ${JSON.stringify(body.data)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 2: GET /api/v1/auth/me returns mustChangePassword = false for normal account
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/me`, {
        headers: { Authorization: `Bearer ${normalToken}` },
      });
      const body: any = await res.json();

      assertTest(
        'GET /api/v1/auth/me returns 200 with mustChangePassword = false for normal user',
        res.status === 200 && body.success === true && body.data?.mustChangePassword === false,
        `Expected mustChangePassword = false, got: ${JSON.stringify(body.data)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 3: POST /api/v1/auth/refresh returns mustChangePassword in envelope & user
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${forcedToken}`,
        },
      });
      const body: any = await res.json();

      assertTest(
        'POST /api/v1/auth/refresh returns 200 with mustChangePassword in data and data.user',
        res.status === 200 &&
          body.success === true &&
          body.data?.mustChangePassword === true &&
          body.data?.user?.mustChangePassword === true,
        `Expected mustChangePassword = true on refresh, got: ${JSON.stringify(body.data)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 4: POST /api/v1/auth/refresh returns mustChangePassword = false for normal user
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${normalToken}`,
        },
      });
      const body: any = await res.json();

      assertTest(
        'POST /api/v1/auth/refresh returns mustChangePassword = false for normal user',
        res.status === 200 &&
          body.success === true &&
          body.data?.mustChangePassword === false &&
          body.data?.user?.mustChangePassword === false,
        `Expected mustChangePassword = false, got: ${JSON.stringify(body.data)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 5: POST /api/v1/auth/refresh returns mustChangePassword = false for master admin
    // -------------------------------------------------------------
    {
      const res = await fetch(`${baseUrl}/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
      });
      const body: any = await res.json();

      assertTest(
        'POST /api/v1/auth/refresh returns mustChangePassword = false for admin',
        res.status === 200 &&
          body.success === true &&
          body.data?.mustChangePassword === false &&
          body.data?.user?.mustChangePassword === false,
        `Expected mustChangePassword = false for admin, got: ${JSON.stringify(body.data)}`
      );
    }

    // -------------------------------------------------------------
    // TEST 6: passwordResetService.changePassword sets mustChangePassword = false in DB
    // -------------------------------------------------------------
    {
      const bcrypt = require('bcryptjs');
      const origCompare = bcrypt.compare;
      const origHash = bcrypt.hash;
      bcrypt.compare = async () => true;
      bcrypt.hash = async () => '$2b$10$newlyHashedPassword999';

      try {
        const changeRes = await passwordResetService.changePassword(
          forcedUserId,
          'TempPass123!',
          'NewPermanentPass456!'
        );

        assertTest(
          'passwordResetService.changePassword succeeds',
          changeRes.success === true,
          `Expected success = true, got: ${JSON.stringify(changeRes)}`
        );
        assertTest(
          'passwordResetService.changePassword updates mustChangePassword to false',
          updatedUserId === forcedUserId && updatedData?.mustChangePassword === false,
          `Expected updatedData.mustChangePassword === false, got: ${JSON.stringify(updatedData)}`
        );
      } finally {
        bcrypt.compare = origCompare;
        bcrypt.hash = origHash;
      }
    }

    console.log('\n================================================================');
    console.log(`✅ ALL ${passedTests}/${totalTests} BACKEND CONTRACT TESTS PASSED!`);
    console.log('================================================================');
  } finally {
    prisma.user.findUnique = originalUserFindUnique;
    prisma.user.update = originalUserUpdate;
    prisma.clientProfile.findUnique = originalProfileFindUnique;
    server.close();
  }
}

runEndpointsSuite().catch((err) => {
  console.error('Fatal backend test error:', err);
  process.exit(1);
});
