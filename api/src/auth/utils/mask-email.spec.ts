import { maskEmail } from './mask-email';

describe('maskEmail', () => {
  it('masks a typical address', () => {
    expect(maskEmail('alice@example.com')).toBe('a***e@example.com');
  });

  it('masks two-character local part', () => {
    expect(maskEmail('ab@example.com')).toBe('**@example.com');
  });

  it('returns *** when @ is missing', () => {
    expect(maskEmail('not-an-email')).toBe('***');
  });

  it('returns *** for empty local', () => {
    expect(maskEmail('@example.com')).toBe('***');
  });

  it('returns *** for empty domain', () => {
    expect(maskEmail('user@')).toBe('***');
  });
});
