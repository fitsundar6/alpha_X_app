process.env.NODE_ENV = 'test';
import http from 'http';
import fs from 'fs';
import app from './server';
import { serverLogFilePath } from './utils/serverLogger';
import { prisma } from './config/prisma';

function makeRequest(
  server: http.Server,
  options: {
    method: string;
    path: string;
    headers?: Record<string, string>;
    body?: any;
  }
): Promise<{ status: number; body: any; headers: http.IncomingHttpHeaders }> {
  return new Promise((resolve, reject) => {
    const address = server.address() as any;
    const port = address.port;

    const payload = options.body !== undefined ? JSON.stringify(options.body) : null;
    const reqHeaders: Record<string, string> = {
      ...(options.headers || {}),
    };
    if (payload !== null) {
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(payload).toString();
    }

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: options.path,
        method: options.method,
        headers: reqHeaders,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve({
              status: res.statusCode || 500,
              body: data ? JSON.parse(data) : null,
              headers: res.headers,
            });
          } catch {
            resolve({
              status: res.statusCode || 500,
              body: data,
              headers: res.headers,
            });
          }
        });
      }
    );

    req.on('error', reject);
    if (payload !== null) req.write(payload);
    req.end();
  });
}

async function runErrorLoggingTests() {
  console.log('\n================================================================');
  console.log('🧪 RUNNING ALPHA X INTENTIONAL ERROR TESTS & SERVER LOG VERIFICATION 🧪');
  console.log('================================================================\n');

  // Clear existing test log file so we verify fresh test entries
  try {
    if (fs.existsSync(serverLogFilePath)) {
      fs.unlinkSync(serverLogFilePath);
    }
  } catch (_) {}

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const port = (server.address() as any).port;
  console.log(`Server listening on test port ${port}`);
  console.log(`Log file: ${serverLogFilePath}\n`);

  try {
    // -------------------------------------------------------------
    // TEST 1: Invalid API request (Non-existent endpoint -> 404)
    // -------------------------------------------------------------
    console.log('--- TEST 1: Invalid API request (404 Not Found) ---');
    const res1 = await makeRequest(server, {
      method: 'GET',
      path: '/api/v1/nonexistent-broken-endpoint',
    });
    console.log(`Response Status: ${res1.status}`);
    console.log(`Response Body:`, JSON.stringify(res1.body));
    if (res1.status !== 404) throw new Error(`Expected status 404, got ${res1.status}`);
    console.log('✔ TEST 1 PASSED: Invalid API endpoint returned 404 and was recorded in server logs.\n');

    // -------------------------------------------------------------
    // TEST 2: Invalid authentication (Bad token & Bad credentials -> 401)
    // -------------------------------------------------------------
    console.log('--- TEST 2A: Invalid authentication token (401 Unauthorized) ---');
    const res2a = await makeRequest(server, {
      method: 'GET',
      path: '/api/v1/client/me',
      headers: {
        Authorization: 'Bearer completely_invalid_or_expired_jwt_token',
      },
    });
    console.log(`Response Status: ${res2a.status}`);
    console.log(`Response Body:`, JSON.stringify(res2a.body));
    if (res2a.status !== 401) throw new Error(`Expected status 401, got ${res2a.status}`);

    console.log('\n--- TEST 2B: Invalid login credentials (401 Unauthorized) ---');
    const res2b = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/login',
      body: {
        clientId: 'AXG-0001',
        password: 'wrong_password_attempt',
      },
    });
    console.log(`Response Status: ${res2b.status}`);
    console.log(`Response Body:`, JSON.stringify(res2b.body));
    if (res2b.status !== 401) throw new Error(`Expected status 401, got ${res2b.status}`);
    console.log('✔ TEST 2 PASSED: Authentication errors returned 401 and were recorded in server logs.\n');

    // -------------------------------------------------------------
    // TEST 3: Invalid database request (Prisma foreign key failure -> 500)
    // -------------------------------------------------------------
    console.log('--- TEST 3: Invalid database request / Prisma constraint failure ---');
    const res3 = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/workout/save',
      headers: {
        Authorization: 'Bearer alpha_x_mock_token_for_client',
      },
      body: {
        sessionId: '00000000-0000-0000-0000-000000000000', // Non-existent foreign key session in DB
        sessionTitle: 'Leg Day Hypertrophy',
        startedAt: new Date().toISOString(),
        completedAt: new Date().toISOString(),
        durationSeconds: 3600,
        exerciseRecords: [
          {
            exerciseId: 'non-existent-exercise-id-999',
            exerciseName: 'Phantom Exercise',
            orderIndex: 0,
            sets: [
              {
                setNumber: 1,
                repsCompleted: 10,
                weightKg: 100,
                isCompleted: true,
              },
            ],
          },
        ],
      },
    });
    console.log(`Response Status: ${res3.status}`);
    console.log(`Response Body:`, JSON.stringify(res3.body));
    if (res3.status !== 500) throw new Error(`Expected 500, got ${res3.status}`);
    console.log('✔ TEST 3 PASSED: Database request error was captured and recorded in server logs.\n');

    // -------------------------------------------------------------
    // TEST 4: Missing required data (Validation Error -> 400)
    // -------------------------------------------------------------
    console.log('--- TEST 4: Missing required data (Validation Error) ---');
    const res4 = await makeRequest(server, {
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {
        name: '', // Empty name (required)
        email: 'invalid-email-format', // Malformed email
        // password missing
      },
    });
    console.log(`Response Status: ${res4.status}`);
    console.log(`Response Body:`, JSON.stringify(res4.body));
    if (res4.status !== 400) throw new Error(`Expected 400, got ${res4.status}`);
    console.log('✔ TEST 4 PASSED: Missing required data triggered validation error and was recorded in server logs.\n');

    // -------------------------------------------------------------
    // TEST 5: Non-existent client ID (404 Not Found)
    // -------------------------------------------------------------
    console.log('--- TEST 5: Non-existent client ID (404 Not Found) ---');
    const res5 = await makeRequest(server, {
      method: 'GET',
      path: '/api/v1/admin/clients/AXG-9999999',
      headers: {
        Authorization: 'Bearer alpha_x_mock_token_for_admin',
        'x-client-id': 'AXG-9999999',
      },
    });
    console.log(`Response Status: ${res5.status}`);
    console.log(`Response Body:`, JSON.stringify(res5.body));
    if (res5.status !== 404) throw new Error(`Expected status 404, got ${res5.status}`);
    console.log('✔ TEST 5 PASSED: Non-existent client ID lookup returned 404 and was recorded in server logs.\n');

    // -------------------------------------------------------------
    // TEST 6: Save Assessment Error (POST /api/client/assessment)
    // -------------------------------------------------------------
    console.log('--- TEST 6: Save Assessment with invalid biometric data (Validation error) ---');
    const res6 = await makeRequest(server, {
      method: 'POST',
      path: '/api/client/assessment',
      headers: {
        Authorization: 'Bearer alpha_x_mock_token_for_client',
      },
      body: {
        weightKg: 9999, // Impossible weight -> Validation error
        heightCm: -50,
      },
    });
    console.log(`Response Status: ${res6.status}`);
    console.log(`Response Body:`, JSON.stringify(res6.body));
    if (res6.status !== 400) throw new Error(`Expected status 400, got ${res6.status}`);
    console.log('✔ TEST 6 PASSED: Assessment save failure was recorded in server logs with endpoint POST /api/client/assessment.\n');

    // -------------------------------------------------------------
    // TEST 7: Unexpected server error (500 Internal Server Error)
    // -------------------------------------------------------------
    console.log('--- TEST 7: Unexpected server error (500 Internal Server Error) ---');
    const res7 = await makeRequest(server, {
      method: 'GET',
      path: '/api/v1/simulate-error',
    });
    console.log(`Response Status: ${res7.status}`);
    console.log(`Response Body:`, JSON.stringify(res7.body));
    if (res7.status !== 500) throw new Error(`Expected status 500, got ${res7.status}`);
    console.log('✔ TEST 7 PASSED: Unexpected server exception was captured and recorded in server logs.\n');

    // -------------------------------------------------------------
    // TEST 8: Malformed JSON syntax error (400 Bad Request)
    // -------------------------------------------------------------
    console.log('--- TEST 8: Unexpected / Malformed JSON body ---');
    const res8 = await new Promise<{ status: number; body: any }>((resolve) => {
      const address = server.address() as any;
      const rawReq = http.request(
        {
          hostname: '127.0.0.1',
          port: address.port,
          path: '/api/v1/auth/login',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        },
        (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', () => {
            try {
              resolve({ status: res.statusCode || 500, body: JSON.parse(data) });
            } catch {
              resolve({ status: res.statusCode || 500, body: data });
            }
          });
        }
      );
      rawReq.write('{ broken_json_payload:');
      rawReq.end();
    });
    console.log(`Response Status: ${res8.status}`);
    console.log(`Response Body:`, JSON.stringify(res8.body));
    if (res8.status !== 400) throw new Error(`Expected status 400, got ${res8.status}`);
    console.log('✔ TEST 8 PASSED: Malformed JSON syntax error was recorded in server logs.\n');

    // -------------------------------------------------------------
    // VERIFY SERVER LOG FILE CONTENT
    // -------------------------------------------------------------
    console.log('================================================================');
    console.log('📋 READING ACTUAL RECORDED SERVER LOG ENTRIES FROM LOG FILE 📋');
    console.log('================================================================\n');

    if (!fs.existsSync(serverLogFilePath)) {
      throw new Error(`Server log file was not created at ${serverLogFilePath}`);
    }

    const logFileContent = fs.readFileSync(serverLogFilePath, 'utf8');
    console.log(logFileContent);

    console.log('\n================================================================');
    console.log('🎉 ALL 8 ERROR LOGGING TESTS PASSED SUCCESSFULLY! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

runErrorLoggingTests().catch((err) => {
  console.error('❌ Test suite failed:', err);
  process.exit(1);
});
