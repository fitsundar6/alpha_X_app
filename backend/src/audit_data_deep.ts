import { prisma } from './config/prisma';

async function auditData() {
  try {
    // Let's check which clients have workout assignments
    const clientAssignments = await prisma.$queryRaw<any[]>`
      SELECT u.id, u.email, u.name, cp."clientId" as gym_id, cp.phone, count(wa.id)::int as assignment_count
      FROM users u
      LEFT JOIN client_profiles cp ON cp."userId" = u.id
      LEFT JOIN workout_assignments wa ON wa."clientId" = u.id
      GROUP BY u.id, u.email, u.name, cp."clientId", cp.phone
      ORDER BY count(wa.id) DESC
    `;
    console.log('--- Users and their Workout Assignments count ---');
    console.table(clientAssignments);

    // Check workout records by user
    const clientRecords = await prisma.$queryRaw<any[]>`
      SELECT u.id, u.email, u.name, cp."clientId" as gym_id, count(wr.id)::int as record_count
      FROM users u
      LEFT JOIN client_profiles cp ON cp."userId" = u.id
      LEFT JOIN workout_records wr ON wr."clientId" = u.id
      GROUP BY u.id, u.email, u.name, cp."clientId"
      ORDER BY count(wr.id) DESC
    `;
    console.log('--- Users and their Workout Records count ---');
    console.table(clientRecords);

    // Who has assignments to admin_alex_stone sessions?
    const alexAssignments = await prisma.$queryRaw<any[]>`
      SELECT u.email, cp."clientId" as gym_id, count(wa.id)::int as count
      FROM workout_assignments wa
      JOIN workout_sessions ws ON ws.id = wa."sessionId"
      JOIN users u ON u.id = wa."clientId"
      LEFT JOIN client_profiles cp ON cp."userId" = u.id
      WHERE ws."createdById" = 'admin_alex_stone'
      GROUP BY u.email, cp."clientId"
    `;
    console.log('--- Who has assignments to admin_alex_stone sessions? ---');
    console.table(alexAssignments);

    // Who has assignments to admin_editing_test sessions?
    const editAssignments = await prisma.$queryRaw<any[]>`
      SELECT u.email, cp."clientId" as gym_id, count(wa.id)::int as count
      FROM workout_assignments wa
      JOIN workout_sessions ws ON ws.id = wa."sessionId"
      JOIN users u ON u.id = wa."clientId"
      LEFT JOIN client_profiles cp ON cp."userId" = u.id
      WHERE ws."createdById" = 'admin_editing_test'
      GROUP BY u.email, cp."clientId"
    `;
    console.log('--- Who has assignments to admin_editing_test sessions? ---');
    console.table(editAssignments);

    // Check all sessions createdById breakdown and who their assignments belong to
    const sessionAssignments = await prisma.$queryRaw<any[]>`
      SELECT ws."createdById", u.email as client_email, count(wa.id)::int as assignment_count
      FROM workout_sessions ws
      LEFT JOIN workout_assignments wa ON wa."sessionId" = ws.id
      LEFT JOIN users u ON u.id = wa."clientId"
      GROUP BY ws."createdById", u.email
      ORDER BY ws."createdById", count(wa.id) DESC
    `;
    console.log('--- Session Creator vs Client Assignments ---');
    console.table(sessionAssignments);

  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}

auditData();
