import * as crypto from 'crypto';

/** OTP codes must match across hash/compare; use HMAC with app secret. */
export function hashOtpCode(plain: string, secret: string): string {
  return crypto.createHmac('sha256', secret).update(plain).digest('hex');
}

export function verifyOtpCode(
  plain: string,
  hash: string,
  secret: string,
): boolean {
  const expected = hashOtpCode(plain, secret);
  try {
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(hash));
  } catch {
    return false;
  }
}

export function hashResetToken(rawToken: string, secret: string): string {
  return hashOtpCode(rawToken, secret);
}

export function generateOtp6Digit(): string {
  const n = crypto.randomInt(0, 1_000_000);
  return n.toString().padStart(6, '0');
}

export function generateUrlToken(): string {
  return crypto.randomBytes(32).toString('hex');
}
