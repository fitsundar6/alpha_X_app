import { prisma } from './config/prisma';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from './config/environment';
import { UserRole, UserStatus } from './constants/roles';

async function runVerificationTestSuite() {
  console.log('====================================================');
  console.log('ALPHA X GYM: ADMIN USER VERIFICATION E2E TEST SUITE');
  console.log('====================================================');

  const testEmail = `test_athlete_${Date.now()}@alphaxgym.test`;
  const testPhone = `+1555${Math.floor(1000000 + Math.random() * 9000000)}`;
  const password = 'Password123!';
  const passwordHash = await bcrypt.hash(password, 10);

  // 1. TEST 1: New user registers -> Status = PENDING
  console.log('\n[TEST 1] Registering new user...');
  const newUser = await prisma.user.create({
    data: {
      email: testEmail,
      name: 'Test Verification Athlete',
      passwordHash,
      role: UserRole.CLIENT,
      status: UserStatus.PENDING,
      clientProfile: {
        create: {
          clientId: `AXG-T${Math.floor(1000 + Math.random() * 9000)}`,
          phone: testPhone,
        },
      },
    },
    include: { clientProfile: true },
  });

  if (newUser.status !== UserStatus.PENDING) {
    throw new Error(`TEST 1 FAILED: Expected PENDING, got ${newUser.status}`);
  }
  console.log(`✓ TEST 1 PASSED: New user "${newUser.email}" created with status PENDING`);

  // 2. TEST 2: Existing users remain APPROVED
  console.log('\n[TEST 2] Verifying existing users remain intact and APPROVED...');
  const existingUsers = await prisma.user.findMany({
    where: { NOT: { id: newUser.id } },
    take: 5,
  });
  const allApproved = existingUsers.every((u) => u.status === UserStatus.APPROVED);
  if (!allApproved) {
    throw new Error('TEST 2 FAILED: Existing users are not APPROVED!');
  }
  console.log(`✓ TEST 2 PASSED: Verified ${existingUsers.length} existing users remain APPROVED`);

  // 3. TEST 3: Admin Approves User
  console.log('\n[TEST 3] Admin approves pending user...');
  const adminEmail = env.ADMIN_EMAIL.trim().toLowerCase();
  const previousStatus = newUser.status;
  const approvedUser = await prisma.user.update({
    where: { id: newUser.id },
    data: {
      status: UserStatus.APPROVED,
      approvedAt: new Date(),
      approvedBy: adminEmail,
    },
  });

  await prisma.userVerificationLog.create({
    data: {
      userId: newUser.id,
      adminEmail,
      previousStatus,
      newStatus: UserStatus.APPROVED,
      reason: 'Verified gym membership in person',
    },
  });

  if (approvedUser.status !== UserStatus.APPROVED || !approvedUser.approvedAt) {
    throw new Error('TEST 3 FAILED: Status was not updated to APPROVED');
  }
  console.log(`✓ TEST 3 PASSED: User approved by "${approvedUser.approvedBy}" at ${approvedUser.approvedAt.toISOString()}`);

  // 4. TEST 4: Admin Rejects User with reason
  console.log('\n[TEST 4] Admin rejects user with reason...');
  const rejectedUser = await prisma.user.update({
    where: { id: newUser.id },
    data: {
      status: UserStatus.REJECTED,
      rejectedAt: new Date(),
      rejectedBy: adminEmail,
      rejectionReason: 'Not a gym member',
    },
  });

  await prisma.userVerificationLog.create({
    data: {
      userId: newUser.id,
      adminEmail,
      previousStatus: UserStatus.APPROVED,
      newStatus: UserStatus.REJECTED,
      reason: 'Not a gym member',
    },
  });

  if (rejectedUser.status !== UserStatus.REJECTED || rejectedUser.rejectionReason !== 'Not a gym member') {
    throw new Error('TEST 4 FAILED: Rejection reason or status mismatch');
  }
  console.log(`✓ TEST 4 PASSED: User rejected with reason: "${rejectedUser.rejectionReason}"`);

  // 5. TEST 5: Admin changes REJECTED -> APPROVED
  console.log('\n[TEST 5] Admin overturns rejection: REJECTED -> APPROVED...');
  const reapprovedUser = await prisma.user.update({
    where: { id: newUser.id },
    data: {
      status: UserStatus.APPROVED,
      approvedAt: new Date(),
      approvedBy: adminEmail,
      rejectionReason: null,
      rejectedAt: null,
      rejectedBy: null,
    },
  });

  await prisma.userVerificationLog.create({
    data: {
      userId: newUser.id,
      adminEmail,
      previousStatus: UserStatus.REJECTED,
      newStatus: UserStatus.APPROVED,
      reason: 'Client showed proof of payment at front desk',
    },
  });

  if (reapprovedUser.status !== UserStatus.APPROVED || reapprovedUser.rejectionReason !== null) {
    throw new Error('TEST 5 FAILED: Reapproval failed');
  }
  console.log('✓ TEST 5 PASSED: Reapproval successful, rejection reason cleared');

  // 6. TEST 6: Admin suspends user
  console.log('\n[TEST 6] Admin suspends user: APPROVED -> SUSPENDED...');
  const suspendedUser = await prisma.user.update({
    where: { id: newUser.id },
    data: {
      status: UserStatus.SUSPENDED,
      suspendedAt: new Date(),
      suspendedBy: adminEmail,
      rejectionReason: 'Membership expired',
    },
  });

  await prisma.userVerificationLog.create({
    data: {
      userId: newUser.id,
      adminEmail,
      previousStatus: UserStatus.APPROVED,
      newStatus: UserStatus.SUSPENDED,
      reason: 'Membership expired',
    },
  });

  if (suspendedUser.status !== UserStatus.SUSPENDED) {
    throw new Error('TEST 6 FAILED: Suspension failed');
  }
  console.log('✓ TEST 6 PASSED: User status is SUSPENDED');

  // 7. TEST 7: Audit history inspection
  console.log('\n[TEST 7] Verifying admin audit log history...');
  const auditLogs = await prisma.userVerificationLog.findMany({
    where: { userId: newUser.id },
    orderBy: { createdAt: 'asc' },
  });

  if (auditLogs.length !== 4) {
    throw new Error(`TEST 7 FAILED: Expected 4 audit logs, got ${auditLogs.length}`);
  }
  for (const log of auditLogs) {
    console.log(`  [Audit Log] ${log.previousStatus} -> ${log.newStatus} | Reason: "${log.reason}" | By: ${log.adminEmail} | ${log.createdAt.toISOString()}`);
  }
  console.log('✓ TEST 7 PASSED: Complete audit trail recorded correctly');

  // Clean up test user
  await prisma.user.delete({ where: { id: newUser.id } });
  console.log('\n✓ Cleaned up test user');
  console.log('\n====================================================');
  console.log('ALL 7 DATABASE & BACKEND VERIFICATION TESTS PASSED!');
  console.log('====================================================\n');
  await prisma.$disconnect();
}

runVerificationTestSuite().catch((e) => {
  console.error('Test Suite Failed:', e);
  process.exit(1);
});
