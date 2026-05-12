import { hashOtpCode, verifyOtpCode } from './otp-crypto';

describe('otp-crypto', () => {
  const secret = 'test-secret';

  it('verifies matching OTP', () => {
    const code = '123456';
    const h = hashOtpCode(code, secret);
    expect(verifyOtpCode(code, h, secret)).toBe(true);
  });

  it('rejects wrong OTP', () => {
    const h = hashOtpCode('123456', secret);
    expect(verifyOtpCode('000000', h, secret)).toBe(false);
  });
});
