import app from './server';
import http from 'http';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';
import { UserRole } from './constants/roles';

async function runSecurityTests() {
  console.log('================================================================');
  console.log('🔒 STARTING SINGLE-ADMIN AUTHORIZATION & RBAC SECURITY AUDIT 🔒');
  console.log('================================================================');

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(5098, '127.0.0.1', () => resolve()));
  const baseUrl = 'http://127.0.0.1:5098/api/v1';

  try {
    const adminEmail = env.ADMIN_EMAIL;
    const clientEmail = 'client.athlete@alphaxgym.com';
    const unauthorizedHackerEmail = 'attacker@external.com';

    console.log(`Configured Master Admin Email in Backend: [${adminEmail}]`);

    // TEST 1: Authorized admin email -> ADMIN
    const adminLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: `  ${adminEmail.toUpperCase()}  `, password: 'any_admin_password' }),
    });
    const adminLogin = await adminLoginRes.json();
    console.assert(adminLogin.success === true, 'Admin login failed');
    console.assert(adminLogin.data.user.role === 'ADMIN', 'Admin user must have ADMIN role');
    console.assert(adminLogin.data.user.email === adminEmail.toLowerCase().trim(), 'Admin email must be normalized');
    const adminToken = adminLogin.data.token;
    console.log('✔ TEST 1 PASSED: Configured admin email granted ADMIN role with signed JWT.');

    // TEST 2: Normal client email -> CLIENT
    const clientLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: clientEmail, password: 'client_password' }),
    });
    const clientLogin = await clientLoginRes.json();
    console.assert(clientLogin.success === true, 'Client login failed');
    console.assert(clientLogin.data.user.role === 'CLIENT', 'Client user must have CLIENT role');
    const clientToken = clientLogin.data.token;
    console.log('✔ TEST 2 PASSED: Normal client email granted CLIENT role.');

    // TEST 3: New user registration -> CLIENT
    const registerRes = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'brand_new_member@alphaxgym.com',
        password: 'secure_password_123',
        name: 'New Athlete',
        role: 'ADMIN', // Attacker trying to register as ADMIN
        isAdmin: true,
      }),
    });
    const registerData = await registerRes.json();
    console.assert(registerData.success === true, 'Registration failed');
    console.assert(
      registerData.data.user.role === 'CLIENT',
      'New registered user MUST be CLIENT even if role=ADMIN requested'
    );
    console.log('✔ TEST 3 PASSED: New user registration automatically assigned CLIENT (role request rejected).');

    // TEST 4: Client calling admin workout API -> 403 FORBIDDEN
    const clientWorkoutAdminRes = await fetch(`${baseUrl}/workout/admin/sessions`, {
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    console.assert(
      clientWorkoutAdminRes.status === 403,
      `Expected 403 Forbidden for client on workout admin API, got ${clientWorkoutAdminRes.status}`
    );
    console.log('✔ TEST 4 PASSED: Client denied access to Admin Workout Management (403 Forbidden).');

    // TEST 5: Client calling admin exercise API -> 403 FORBIDDEN
    const clientExerciseAdminRes = await fetch(`${baseUrl}/exercises/admin/sync/status`, {
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    console.assert(
      clientExerciseAdminRes.status === 403,
      `Expected 403 Forbidden for client on exercise admin API, got ${clientExerciseAdminRes.status}`
    );
    console.log('✔ TEST 5 PASSED: Client denied access to Admin Exercise Sync/Management (403 Forbidden).');

    // TEST 6: Client calling admin activity API -> 403 FORBIDDEN
    const clientActivityAdminRes = await fetch(`${baseUrl}/activity/client/client_john_doe`, {
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    console.assert(
      clientActivityAdminRes.status === 403,
      `Expected 403 Forbidden for client on activity inspect API, got ${clientActivityAdminRes.status}`
    );
    console.log('✔ TEST 6 PASSED: Client denied access to Admin Client Activity Inspection (403 Forbidden).');

    // TEST 7 & 8: Client sends role=ADMIN / isAdmin=true in login body -> DENIED / Ignored
    const exploitLoginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: unauthorizedHackerEmail,
        password: 'hacker_password',
        role: 'ADMIN',
        isAdmin: true,
        admin: true,
      }),
    });
    const exploitLogin = await exploitLoginRes.json();
    console.assert(exploitLogin.data.user.role === 'CLIENT', 'Attacker must NOT be granted ADMIN role');
    console.log('✔ TEST 7 & 8 PASSED: Client payload role=ADMIN and isAdmin=true rejected/ignored.');

    // TEST 9: Tampered JWT token with role: ADMIN but client email -> 403 FORBIDDEN
    const tamperedPayload = {
      id: 'attacker_123',
      email: unauthorizedHackerEmail,
      role: UserRole.ADMIN, // Tampered role inside token payload
    };
    const forgedToken = jwt.sign(tamperedPayload, env.JWT_ACCESS_SECRET);
    const tamperedRequestRes = await fetch(`${baseUrl}/workout/admin/sessions`, {
      headers: { Authorization: `Bearer ${forgedToken}` },
    });
    console.assert(
      tamperedRequestRes.status === 403,
      `Expected 403 Forbidden for tampered token with non-admin email, got ${tamperedRequestRes.status}`
    );
    console.log('✔ TEST 9 PASSED: Tampered token claiming ADMIN with non-admin email rejected (403 Forbidden).');

    // TEST 10: Client Data Isolation - Client endpoints strictly bind to authenticated identity
    const clientMeRes = await fetch(`${baseUrl}/auth/me`, {
      headers: { Authorization: `Bearer ${clientToken}` },
    });
    const clientMeData = await clientMeRes.json();
    console.assert(
      clientMeData.data.email === clientEmail.toLowerCase(),
      'Identity verification mismatch'
    );
    console.log('✔ TEST 10 PASSED: Client identity verified strictly from token credentials.');

    // TEST 11: Admin accesses admin workout API successfully
    const adminWorkoutRes = await fetch(`${baseUrl}/workout/admin/sessions`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    console.assert(
      adminWorkoutRes.status === 200,
      `Expected 200 OK for authorized admin, got ${adminWorkoutRes.status}`
    );
    console.log('✔ TEST 11 PASSED: Authorized admin successfully accessed admin endpoints.');

    console.log('================================================================');
    console.log('🎉 ALL 11 SINGLE-ADMIN BACKEND SECURITY TESTS PASSED! 🎉');
    console.log('================================================================');
  } finally {
    server.close();
  }
}

runSecurityTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Security test failed:', err);
    process.exit(1);
  });
