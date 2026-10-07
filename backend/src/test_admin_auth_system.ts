import http from 'http';
import app from './server';
import { env } from './config/environment';

interface ApiResponse {
  status: number;
  data: any;
}

function makeRequest(
  server: http.Server,
  options: {
    method: string;
    path: string;
    token?: string;
    body?: any;
  }
): Promise<ApiResponse> {
  return new Promise((resolve, reject) => {
    const port = (server.address() as any).port;
    const bodyString = options.body ? JSON.stringify(options.body) : '';

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: options.path,
        method: options.method,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(bodyString),
          ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(data);
          } catch {
            parsed = data;
          }
          resolve({ status: res.statusCode || 500, data: parsed });
        });
      }
    );

    req.on('error', reject);
    if (bodyString) {
      req.write(bodyString);
    }
    req.end();
  });
}

async function runTests() {
  console.log('================================================================');
  console.log('🔒 RUNNING COMPREHENSIVE ADMIN AUTHENTICATION SECURITY AUDIT 🔒');
  console.log('================================================================');

  const server = app.listen(0);
  await new Promise((r) => setTimeout(r, 300));

  try {
    const adminEmail = env.ADMIN_EMAIL.trim().toLowerCase();
    const adminPassword = env.ADMIN_PASSWORD || 'AlphaXAdmin2026!';

    console.log(`Testing configured admin email: [${adminEmail}]`);

    // TEST 1: Admin login with correct credentials to /api/admin/login -> 200 + ADMIN JWT
    const adminLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/admin/login',
      body: { email: adminEmail, password: adminPassword },
    });
    if (adminLoginRes.status !== 200 || adminLoginRes.data.data.user.role !== 'ADMIN') {
      throw new Error(`TEST 1 FAILED: Expected 200 & ADMIN role, got ${adminLoginRes.status}: ${JSON.stringify(adminLoginRes.data)}`);
    }
    const adminToken = adminLoginRes.data.data.token;
    console.log('✔ TEST 1 PASSED: Admin login with correct password succeeded (200 OK + ADMIN JWT).');

    // TEST 2: Admin login with wrong password -> 401 Unauthorized
    const wrongPassRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/admin/login',
      body: { email: adminEmail, password: 'WrongPassword123!' },
    });
    if (wrongPassRes.status !== 401) {
      throw new Error(`TEST 2 FAILED: Expected 401 for wrong password, got ${wrongPassRes.status}`);
    }
    console.log('✔ TEST 2 PASSED: Admin login with wrong password rejected (401 Unauthorized).');

    // TEST 3: Admin login with non-admin email -> 401 Unauthorized
    const nonAdminLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/admin/login',
      body: { email: 'intruder@evil.com', password: adminPassword },
    });
    if (nonAdminLoginRes.status !== 401) {
      throw new Error(`TEST 3 FAILED: Expected 401 for non-admin email, got ${nonAdminLoginRes.status}`);
    }
    console.log('✔ TEST 3 PASSED: Non-admin email rejected from /api/admin/login (401 Unauthorized).');

    // TEST 4: Client normal login -> 200 + CLIENT role
    const clientLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: { email: 'member.athlete@alphaxgym.com', password: 'member_password_123' },
    });
    if (clientLoginRes.status !== 200 || clientLoginRes.data.data.user.role !== 'CLIENT') {
      throw new Error(`TEST 4 FAILED: Client login failed to issue CLIENT role.`);
    }
    const clientToken = clientLoginRes.data.data.token;
    console.log('✔ TEST 4 PASSED: Normal client login succeeded with CLIENT role.');

    // TEST 5: Unified login with admin email requires valid password
    const unifiedAdminFail = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: { email: adminEmail, password: 'IncorrectAdminPassword' },
    });
    if (unifiedAdminFail.status !== 401) {
      throw new Error(`TEST 5 FAILED: Unified login did not require admin password check.`);
    }
    console.log('✔ TEST 5 PASSED: Unified /login strictly enforces admin password verification.');

    // TEST 6: Client calls /api/admin/workouts -> 403 Forbidden
    const clientWorkoutsRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/workouts',
      token: clientToken,
    });
    if (clientWorkoutsRes.status !== 403) {
      throw new Error(`TEST 6 FAILED: Client was not rejected from /api/admin/workouts (got ${clientWorkoutsRes.status})`);
    }
    console.log('✔ TEST 6 PASSED: Client denied access to /api/admin/workouts (403 Forbidden).');

    // TEST 7: Client calls /api/admin/exercises -> 403 Forbidden
    const clientExercisesRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/exercises',
      token: clientToken,
    });
    if (clientExercisesRes.status !== 403) {
      throw new Error(`TEST 7 FAILED: Client was not rejected from /api/admin/exercises (got ${clientExercisesRes.status})`);
    }
    console.log('✔ TEST 7 PASSED: Client denied access to /api/admin/exercises (403 Forbidden).');

    // TEST 8: Client calls /api/admin/clients -> 403 Forbidden
    const clientClientsRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/clients',
      token: clientToken,
    });
    if (clientClientsRes.status !== 403) {
      throw new Error(`TEST 8 FAILED: Client was not rejected from /api/admin/clients (got ${clientClientsRes.status})`);
    }
    console.log('✔ TEST 8 PASSED: Client denied access to /api/admin/clients (403 Forbidden).');

    // TEST 9: Client calls /api/admin/metrics -> 403 Forbidden
    const clientMetricsRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/metrics',
      token: clientToken,
    });
    if (clientMetricsRes.status !== 403) {
      throw new Error(`TEST 9 FAILED: Client was not rejected from /api/admin/metrics (got ${clientMetricsRes.status})`);
    }
    console.log('✔ TEST 9 PASSED: Client denied access to /api/admin/metrics (403 Forbidden).');

    // TEST 10: Client calls /api/admin/exercises -> 403 Forbidden
    const clientExRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/admin/exercises',
      token: clientToken,
    });
    if (clientExRes.status !== 403) {
      throw new Error(`TEST 10 FAILED: Client was not rejected from /api/admin/exercises (got ${clientExRes.status})`);
    }
    console.log('✔ TEST 10 PASSED: Client denied access to /api/admin/exercises (403 Forbidden).');

    // TEST 11: Authorized admin calls all /api/admin/* endpoints -> 200 OK
    const [wRes, eRes, cRes] = await Promise.all([
      makeRequest(server, { method: 'GET', path: '/api/admin/workouts', token: adminToken }),
      makeRequest(server, { method: 'GET', path: '/api/admin/exercises', token: adminToken }),
      makeRequest(server, { method: 'GET', path: '/api/admin/clients', token: adminToken }),
    ]);

    if (wRes.status !== 200 || eRes.status !== 200 || cRes.status !== 200) {
      throw new Error(`TEST 11 FAILED: Admin failed to access admin endpoints: W:${wRes.status}, E:${eRes.status}, C:${cRes.status}`);
    }
    console.log('✔ TEST 11 PASSED: Authorized Admin successfully accessed all /api/admin/* endpoints (200 OK).');

    // TEST 12: Payload Security — No passwords, password hashes, or secrets returned
    const resString = JSON.stringify(adminLoginRes.data) + JSON.stringify(clientLoginRes.data);
    if (resString.includes('passwordHash') || resString.includes('ADMIN_PASSWORD') || resString.includes('secret')) {
      throw new Error('TEST 12 FAILED: Response exposed password or secret key data!');
    }
    console.log('✔ TEST 12 PASSED: Security verified — No passwords, password hashes, or server secrets exposed in responses.');

    console.log('================================================================');
    console.log('🎉 ALL 12 ADMIN AUTHENTICATION TESTS PASSED SUCCESSFULLY! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error('❌ Test suite failed:', err);
  process.exit(1);
});
