/**
 * Masks an email for display after OTP send (privacy + user confirmation).
 * Edge cases: missing `@`, empty parts → `"***"`.
 */
export function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!domain || !local) {
    return '***';
  }
  if (local.length <= 2) {
    return `**@${domain}`;
  }
  return `${local[0]}***${local[local.length - 1]}@${domain}`;
}
