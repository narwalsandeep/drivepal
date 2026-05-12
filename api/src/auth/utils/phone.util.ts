import { BadRequestException } from '@nestjs/common';
import { parsePhoneNumberWithError } from 'libphonenumber-js';

export function normalizeToE164(
  input: string,
  defaultCountry: string,
): { e164: string; display: string } {
  try {
    const parsed = parsePhoneNumberWithError(
      input.trim(),
      defaultCountry as never,
    );
    if (!parsed.isValid()) {
      throw new BadRequestException('Invalid phone number');
    }
    return {
      e164: parsed.number,
      display: parsed.formatInternational(),
    };
  } catch {
    throw new BadRequestException('Invalid phone number');
  }
}
