import { Injectable } from '@nestjs/common';

/**
 * SMS provider placeholder — not wired in AuthModule. OTP is sent via email only.
 * Replace with Twilio/MessageBird when `SMS_PROVIDER` is configured.
 */
@Injectable()
export class SmsService {
  async sendOtp(
    phoneE164: string,
    code: string,
    purpose: string,
  ): Promise<void> {
    console.info(
      `[SMS] to ${phoneE164} purpose=${purpose} OTP=${code} (integrate real provider for production)`,
    );
  }
}
