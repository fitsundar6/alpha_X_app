import bcrypt from 'bcryptjs';

/**
 * CLI Utility to generate production bcrypt password hashes.
 * Usage:
 *   npx ts-node src/utils/hash_password.ts "YourSecurePassword"
 *   npm run hash-password "YourSecurePassword"
 */
async function main() {
  const plainPassword = process.argv[2];

  if (!plainPassword || plainPassword.trim().length < 8) {
    console.error('❌ Error: Please provide a password of at least 8 characters.');
    console.error('Usage: npx ts-node src/utils/hash_password.ts "<your_password>"');
    process.exit(1);
  }

  const saltRounds = 12;
  console.log('Generating secure bcrypt password hash (salt rounds: 12)...');
  const hash = await bcrypt.hash(plainPassword, saltRounds);

  console.log('================================================================');
  console.log('🔒 ALPHA X GYM — SECURE ADMIN PASSWORD HASH GENERATOR (bcrypt)');
  console.log('================================================================');
  console.log('Algorithm:   bcrypt ($2a$ / $2b$)');
  console.log('Cost Factor: 12');
  console.log(`Password:    ${'*'.repeat(plainPassword.length)} (length: ${plainPassword.length})`);
  console.log('----------------------------------------------------------------');
  console.log('Generated Hash:');
  console.log(hash);
  console.log('----------------------------------------------------------------');
  console.log('Copy and paste into your backend/.env or Render environment:');
  console.log(`ADMIN_PASSWORD_HASH="${hash}"`);
  console.log('================================================================');
}

main().catch((err) => {
  console.error('Failed to hash password:', err);
  process.exit(1);
});
