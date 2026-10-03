/**
 * Alpha X — PII Masking Utility
 *
 * Masks sensitive personal data fields before returning them in API responses.
 * All masking is one-way — the original data is never modified in the database.
 *
 * Rules:
 *  - Phone:  +91 9876543210  →  +91 ****3210
 *  - Email:  priya@gmail.com →  p***@gmail.com
 *  - Name:   Priya Sharma    →  Priya S.          (last name initial only)
 *
 * Usage:
 *   import { maskPhone, maskEmail, maskName, maskClientPII } from '../utils/pii_mask';
 *   const safe = maskClientPII({ phone, email, name });
 */

/**
 * Masks a phone number, preserving country code + last 4 digits.
 * Examples:
 *   +919876543210  →  +91 ****3210
 *   9876543210     →  ****3210
 *   null/undefined →  null
 */
export function maskPhone(phone: string | null | undefined): string | null {
  if (!phone) return null;
  const cleaned = phone.replace(/\s+/g, '');

  // International format with country code
  const intlMatch = cleaned.match(/^(\+\d{1,3})(\d+)$/);
  if (intlMatch) {
    const countryCode = intlMatch[1];
    const number = intlMatch[2];
    const last4 = number.slice(-4);
    return `${countryCode} ****${last4}`;
  }

  // Plain number fallback
  const last4 = cleaned.slice(-4);
  return `****${last4}`;
}

/**
 * Masks an email address, showing only the first character + domain.
 * Examples:
 *   priya@gmail.com        →  p***@gmail.com
 *   alex.stone@outlook.com →  a***@outlook.com
 *   null/undefined         →  null
 */
export function maskEmail(email: string | null | undefined): string | null {
  if (!email) return null;
  const atIndex = email.indexOf('@');
  if (atIndex < 0) return email; // Not a valid email — return as-is

  const local = email.substring(0, atIndex);
  const domain = email.substring(atIndex); // Includes the @
  const visiblePart = local.charAt(0) || '';
  return `${visiblePart}***${domain}`;
}

/**
 * Masks a full name, preserving first name and showing last name initial only.
 * Examples:
 *   "Priya Sharma"         →  "Priya S."
 *   "Alex Stone Johnson"   →  "Alex S."
 *   "Priya"                →  "Priya"      (single name, no change)
 *   null/undefined         →  null
 */
export function maskName(name: string | null | undefined): string | null {
  if (!name) return null;
  const parts = name.trim().split(/\s+/);
  if (parts.length <= 1) return name;
  const firstName = parts[0];
  const lastInitial = parts[1].charAt(0).toUpperCase();
  return `${firstName} ${lastInitial}.`;
}

/**
 * Convenience function — masks all PII fields in a client object at once.
 * Pass any object containing phone, email, or name fields.
 * Returns a new object with all PII fields masked. Original object is NOT mutated.
 *
 * @example
 * const safeClient = maskClientPII(client);
 * // safeClient.phone  →  "+91 ****3210"
 * // safeClient.email  →  "p***@gmail.com"
 */
export function maskClientPII<T extends {
  phone?: string | null;
  email?: string | null;
  name?: string | null;
}>(data: T): T {
  return {
    ...data,
    ...(data.phone !== undefined && { phone: maskPhone(data.phone) }),
    ...(data.email !== undefined && { email: maskEmail(data.email) }),
    ...(data.name !== undefined && { name: maskName(data.name) }),
  };
}

/**
 * Masks PII in an array of client objects.
 */
export function maskClientListPII<T extends {
  phone?: string | null;
  email?: string | null;
  name?: string | null;
}>(clients: T[]): T[] {
  return clients.map(maskClientPII);
}
