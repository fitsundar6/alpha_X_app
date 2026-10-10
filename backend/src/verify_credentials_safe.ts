import path from 'path';
import fs from 'fs';
import { spawnSync } from 'child_process';
import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

// Load backend .env
dotenv.config({ path: path.resolve(__dirname, '../.env') });
dotenv.config();

async function verifyAllCredentials() {
  console.log('================================================================');
  console.log('🔐 ALPHA X GYM — SAFE CREDENTIAL & RELEASE VERIFICATION TOOL 🔐');
  console.log('================================================================\n');

  let smtpReady = false;
  let signingReady = false;

  // 1. SMTP Verification
  console.log('--- 1. BACKEND SMTP CONFIGURATION ---');
  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = parseInt(process.env.SMTP_PORT || '587', 10);
  const smtpSecure = process.env.SMTP_SECURE === 'true';
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpFrom = process.env.SMTP_FROM || 'Alpha X Gym <noreply@alphaxgym.com>';

  if (smtpHost && smtpUser && smtpPass) {
    console.log(`  Target Host: ${smtpHost}:${smtpPort} (secure: ${smtpSecure})`);
    console.log(`  Sender Address: ${smtpFrom}`);
    console.log('  Testing connection & authentication with mail server...');
    try {
      const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure: smtpSecure,
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
      });
      await transporter.verify();
      console.log('  ✔ SUCCESS: SMTP server connected and credentials authenticated successfully!\n');
      smtpReady = true;
    } catch (err: any) {
      console.log(`  ❌ FAILURE: SMTP authentication or connection failed: ${err?.message || err}\n`);
    }
  } else {
    console.log('  ⚠️ STATUS: SMTP credentials (SMTP_HOST, SMTP_USER, SMTP_PASS) not found in backend/.env');
    console.log('  Password reset email delivery remains in fail-closed / blocked mode.\n');
  }

  // 2. Android Keystore & key.properties Verification
  console.log('--- 2. ANDROID PRODUCTION SIGNING CONFIGURATION ---');
  const keyPropertiesPath = path.resolve(__dirname, '../../apps/mobile/android/key.properties');
  const keytoolPath = 'C:\\Program Files\\Android\\Android Studio\\jbr\\bin\\keytool.exe';

  if (!fs.existsSync(keyPropertiesPath)) {
    console.log(`  ⚠️ STATUS: 'apps/mobile/android/key.properties' is not present.`);
    console.log('  Release compilation fails closed as intended to prevent accidental debug signing.\n');
  } else {
    console.log(`  Found 'key.properties'. Parsing signing properties...`);
    const content = fs.readFileSync(keyPropertiesPath, 'utf8');
    const props: Record<string, string> = {};
    content.split(/\r?\n/).forEach((line) => {
      const match = line.match(/^\s*([^=\s]+)\s*=\s*(.*)$/);
      if (match) {
        props[match[1]] = match[2].trim();
      }
    });

    const storeFile = props.storeFile;
    const keyAlias = props.keyAlias;
    const storePassword = props.storePassword;
    const keyPassword = props.keyPassword || storePassword;

    if (!storeFile || !keyAlias || !storePassword) {
      console.log('  ❌ key.properties is incomplete (must include storeFile, keyAlias, storePassword).\n');
    } else {
      let resolvedKeystore = path.resolve(__dirname, '../../apps/mobile/android', storeFile);
      if (!fs.existsSync(resolvedKeystore)) {
        resolvedKeystore = path.resolve(__dirname, '../../apps/mobile/android/app', storeFile);
      }

      if (!fs.existsSync(resolvedKeystore)) {
        console.log(`  ❌ Keystore file does not exist at: ${resolvedKeystore}\n`);
      } else {
        console.log(`  Keystore found: ${path.basename(resolvedKeystore)}`);
        console.log(`  Checking keystore integrity & certificate with keytool...`);

        if (fs.existsSync(keytoolPath)) {
          const res = spawnSync(keytoolPath, [
            '-list',
            '-v',
            '-keystore',
            resolvedKeystore,
            '-storepass',
            storePassword,
            '-alias',
            keyAlias,
          ], { encoding: 'utf8' });

          if (res.status === 0) {
            console.log('  ✔ SUCCESS: Keystore unlocked and key entry verified!');
            // Extract public certificate details without printing passwords
            const lines = res.stdout.split('\n');
            lines.forEach((l) => {
              if (
                l.includes('Alias name:') ||
                l.includes('Entry type:') ||
                l.includes('Owner:') ||
                l.includes('Issuer:') ||
                l.includes('Valid from:') ||
                l.includes('Certificate fingerprints:') ||
                l.includes('SHA1:') ||
                l.includes('SHA256:')
              ) {
                console.log(`    ${l.trim()}`);
              }
            });
            console.log('');
            signingReady = true;
          } else {
            console.log('  ❌ FAILURE: Keytool failed to unlock keystore or alias not found.');
            const errSummary = (res.stderr || res.stdout || '').split('\n').filter(Boolean).slice(0, 2).join(' ');
            console.log(`    Reason: ${errSummary}\n`);
          }
        } else {
          console.log(`  ⚠️ keytool executable not found at: ${keytoolPath}\n`);
        }
      }
    }
  }

  console.log('================================================================');
  console.log(`SUMMARY: SMTP Ready: ${smtpReady ? 'YES' : 'NO'} | Release Signing Ready: ${signingReady ? 'YES' : 'NO'}`);
  console.log('================================================================\n');

  return { smtpReady, signingReady };
}

verifyAllCredentials().catch((e) => {
  console.error('Verification error:', e);
  process.exit(1);
});
