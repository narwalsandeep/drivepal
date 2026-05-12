import { BadRequestException } from '@nestjs/common';
import { normalizeToE164 } from './phone.util';

describe('normalizeToE164 (GB)', () => {
  it('normalizes a valid UK national number', () => {
    const r = normalizeToE164('07911123456', 'GB');
    expect(r.e164).toMatch(/^\+447/);
  });

  it('accepts E.164 input', () => {
    const r = normalizeToE164('+44 7911 123456', 'GB');
    expect(r.e164.startsWith('+447')).toBe(true);
  });

  it('throws BadRequestException for invalid numbers', () => {
    expect(() => normalizeToE164('not-a-phone', 'GB')).toThrow(
      BadRequestException,
    );
  });
});
