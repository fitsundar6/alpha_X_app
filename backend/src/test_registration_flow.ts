import http from 'http';
import app from './server';
import { prisma } from './config/prisma';
import { env } from './config/environment';

interface RequestOptions {
  method: string;
  path: string;
  headers?: Record<string, string>;
  body?: any;
}

function makeRequest(server: http.Server, options: RequestOptions): Promise<{ status: number; body: any }> {
  return new Promise((resolve, reject) => {
    const addr = server.address();
    if (!addr || typeof addr === 'string') {
      return reject(new Error('Server address not available'));
    }
    const req = http.request(
      {
        host: '127.0.0.1',
        port: addr.port,
        method: options.method,
        path: options.path,
        headers: {
          'Content-Type': 'application/json',
          ...(options.headers || {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            resolve({ status: res.statusCode || 500, body: parsed });
          } catch {
            resolve({ status: res.statusCode || 500, body: data });
          }
        });
      }
    );
    req.on('error', reject);
    if (options.body) {
      req.write(JSON.stringify(options.body));
    }
    req.end();
  });
}

async function runRegistrationIntegrationTests() {
  console.log('========================================================');
  console.log('ALPHA X BACKEND — CLIENT REGISTRATION INTEGRATION TESTS');
  console.log('========================================================\n');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));

  const testSuffix = Date.now().toString().slice(-6);
  const testEmail = `athlete_${testSuffix}@alphaxgym.test`;
  const testPhone = `+1555${testSuffix}`;
  const testPassword = 'SecurePassword123!';

  try {
    // -----------------------------------------------------------------
    // TEST 1: Register client with all 5 required fields
    // -----------------------------------------------------------------
    console.log('TEST 1: Client registration with Name, Email, Phone, Password, Confirm Password');
    const regRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: 'Jordan Alpha',
        email: testEmail,
        phone: testPhone,
        password: testPassword,
        confirmPassword: testPassword,
      },
    });

    console.assert(regRes.status === 201, `Expected 201, got ${regRes.status}: ${JSON.stringify(regRes.body)}`);
    console.assert(regRes.body.success === true, 'Expected success: true');
    console.assert(regRes.body.data.clientId.startsWith('AXG-'), 'Expected AXG-XXXX Client ID');
    console.assert(regRes.body.data.user.email === testEmail.toLowerCase(), 'Expected lowercased email');
    console.assert(regRes.body.data.user.phone === testPhone, 'Expected phone number string');
    console.assert(regRes.body.data.assessmentCompleted === false, 'Expected assessmentCompleted: false initially');
    console.log(`✔ TEST 1 PASSED: Client registered successfully with Client ID: ${regRes.body.data.clientId}\n`);

    // -----------------------------------------------------------------
    // TEST 2: Duplicate Email Rejection
    // -----------------------------------------------------------------
    console.log('TEST 2: Duplicate Email Rejection (Must return "This email is already registered. Please login.")');
    const dupEmailRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: 'Another User',
        email: testEmail.toUpperCase(), // Test case-insensitivity
        phone: `+1999${testSuffix}`,
        password: testPassword,
        confirmPassword: testPassword,
      },
    });

    console.assert(dupEmailRes.status === 409, `Expected 409, got ${dupEmailRes.status}`);
    const errorMsg = dupEmailRes.body.error?.message || dupEmailRes.body.message;
    console.assert(
      errorMsg.includes('This email is already registered. Please login.'),
      `Expected 'This email is already registered. Please login.', got: ${errorMsg}`
    );
    console.log(`✔ TEST 2 PASSED: Duplicate email correctly rejected with 409 Conflict: "${errorMsg}"\n`);

    // -----------------------------------------------------------------
    // TEST 3: Duplicate Phone Rejection
    // -----------------------------------------------------------------
    console.log('TEST 3: Duplicate Phone Rejection (Must return "This phone number is already registered.")');
    const dupPhoneRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: 'Third User',
        email: `new_unique_${testSuffix}@alphaxgym.test`,
        phone: testPhone, // Same phone number
        password: testPassword,
        confirmPassword: testPassword,
      },
    });

    console.assert(dupPhoneRes.status === 409, `Expected 409, got ${dupPhoneRes.status}`);
    const phoneErrorMsg = dupPhoneRes.body.error?.message || dupPhoneRes.body.message;
    console.assert(
      phoneErrorMsg.includes('This phone number is already registered.'),
      `Expected 'This phone number is already registered.', got: ${phoneErrorMsg}`
    );
    console.log(`✔ TEST 3 PASSED: Duplicate phone correctly rejected with 409 Conflict: "${phoneErrorMsg}"\n`);

    // -----------------------------------------------------------------
    // TEST 4: Password Mismatch Rejection
    // -----------------------------------------------------------------
    console.log('TEST 4: Password Mismatch Validation');
    const mismatchRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: 'Fourth User',
        email: `mismatch_${testSuffix}@alphaxgym.test`,
        phone: `+1888${testSuffix}`,
        password: 'Password123!',
        confirmPassword: 'DifferentPassword456!',
      },
    });

    console.assert(mismatchRes.status === 400, `Expected 400, got ${mismatchRes.status}`);
    console.log('✔ TEST 4 PASSED: Password mismatch rejected with 400 Bad Request\n');

    // -----------------------------------------------------------------
    // TEST 5: Admin Email Reservation Protection
    // -----------------------------------------------------------------
    console.log('TEST 5: Admin Email Protection');
    const adminEmailRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: 'Fake Admin',
        email: env.ADMIN_EMAIL,
        phone: `+1777${testSuffix}`,
        password: 'Password123!',
        confirmPassword: 'Password123!',
      },
    });

    console.assert(adminEmailRes.status === 403, `Expected 403, got ${adminEmailRes.status}`);
    console.log('✔ TEST 5 PASSED: Admin email registration rejected with 403 Forbidden\n');

    console.log('========================================================');
    console.log('ALL 5 BACKEND REGISTRATION INTEGRATION TESTS PASSED!');
    console.log('========================================================\n');
  } finally {
    // Clean up created test user
    try {
      await prisma.user.deleteMany({
        where: { email: { in: [testEmail.toLowerCase()] } },
      });
    } catch (_) {}
    server.close();
    await prisma.$disconnect();
  }
}

runRegistrationIntegrationTests().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
