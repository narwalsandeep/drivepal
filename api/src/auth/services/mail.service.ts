import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

import { buildDrivepalMail } from '../../mail/drivepal-mail-layout';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter: Transporter | null;

  constructor(private readonly config: ConfigService) {
    const host = this.config.get<string>('MAIL_HOST');
    const user = this.config.get<string>('MAIL_USERNAME');
    const pass = this.config.get<string>('MAIL_PASSWORD');
    const port = Number(this.config.get<string>('MAIL_PORT') ?? '587');
    const enc = (this.config.get<string>('MAIL_ENCRYPTION') ?? 'tls')
      .toLowerCase()
      .trim();

    if (!host || !user || !pass) {
      this.transporter = null;
      this.logger.warn(
        'Mail disabled: set MAIL_HOST, MAIL_USERNAME, and MAIL_PASSWORD',
      );
      return;
    }

    const secure = enc === 'ssl' || port === 465;
    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass },
      ...(!secure && enc === 'tls' ? { requireTLS: true as const } : {}),
    });
  }

  private getFrom(): string {
    const rawName = this.config.get<string>('MAIL_NAME') ?? 'DRIVEPAL';
    const name = rawName.replace(/^["']|["']$/g, '').trim() || 'DRIVEPAL';
    const addr = this.config.get<string>('MAIL_FROM') ?? 'noreply@localhost';
    return `"${name}" <${addr}>`;
  }

  private async deliver(
    to: string,
    subject: string,
    html: string,
    text: string,
  ): Promise<void> {
    if (this.transporter) {
      await this.transporter.sendMail({
        to,
        from: this.getFrom(),
        subject,
        text,
        html,
      });
      return;
    }

    this.logger.log(`[MAIL fallback] to=${to} subject=${subject}\n${text}\n`);
  }

  /** 6-digit OTP for signup or sign-in (email is the only delivery channel). */
  async sendOtpEmail(
    to: string,
    purpose: 'signup' | 'login',
    code: string,
  ): Promise<void> {
    const isSignup = purpose === 'signup';
    const { subject, html, text } = buildDrivepalMail({
      subject: isSignup
        ? 'Your DRIVEPAL signup code'
        : 'Your DRIVEPAL sign-in code',
      preheader: `Your code is ${code}. It expires in a few minutes.`,
      title: isSignup ? 'Verify your email' : 'Confirm sign-in',
      paragraphs: isSignup
        ? [
            `Your verification code is: ${code}`,
            'Enter this code in the app or website to complete creating your account. It expires in ten minutes.',
            'If you did not try to sign up, you can ignore this email.',
          ]
        : [
            `Your verification code is: ${code}`,
            'Enter this code to finish signing in. It expires in ten minutes.',
            'If you did not try to sign in, change your password and contact support if this keeps happening.',
          ],
    });
    await this.deliver(to, subject, html, text);
  }

  async sendWelcome(to: string): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Welcome to DRIVEPAL',
      preheader: 'Your account is ready.',
      title: 'You’re in',
      paragraphs: [
        'Your DRIVEPAL account is active. You can sign in with your email or mobile number and password, then enter the code we send to this email.',
        'Keep your credentials private. We will never ask for your password in an email.',
      ],
    });
    await this.deliver(to, subject, html, text);
  }

  async sendPasswordResetLink(to: string, resetUrl: string): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Reset your DRIVEPAL password',
      preheader: 'Use the link below to choose a new password.',
      title: 'Password reset',
      paragraphs: [
        'We received a request to reset the password for your DRIVEPAL account.',
        'The button below expires in one hour and can only be used once.',
        resetUrl,
      ],
      cta: { label: 'Choose a new password', href: resetUrl },
      footnote:
        'If the button does not work, copy and paste this address into your browser: the link is valid for one hour only.',
    });
    await this.deliver(to, subject, html, text);
  }

  async sendPasswordChanged(to: string): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Your DRIVEPAL password was updated',
      preheader: 'Your password change is complete.',
      title: 'Password updated',
      paragraphs: [
        'The password for your DRIVEPAL account was just changed.',
        'If you made this change, no further action is needed. If you did not, reset your password immediately from the app or contact support.',
      ],
    });
    await this.deliver(to, subject, html, text);
  }

  async sendTripAcceptedToCustomer(input: {
    to: string;
    pickupAddress: string;
    dropoffAddress: string;
  }): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Your DRIVEPAL trip was accepted',
      preheader: 'A driver accepted your request.',
      title: 'Driver assigned',
      paragraphs: [
        'A driver has accepted your trip request.',
        `Pickup: ${input.pickupAddress}`,
        `Drop-off: ${input.dropoffAddress}`,
      ],
    });
    await this.deliver(input.to, subject, html, text);
  }

  async sendTripAcceptedToDriver(input: {
    to: string;
    pickupAddress: string;
    dropoffAddress: string;
  }): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'You accepted a DRIVEPAL trip',
      preheader: 'Trip details for your accepted request.',
      title: 'Trip accepted',
      paragraphs: [
        'You successfully accepted a rider trip request.',
        `Pickup: ${input.pickupAddress}`,
        `Drop-off: ${input.dropoffAddress}`,
      ],
    });
    await this.deliver(input.to, subject, html, text);
  }

  async sendTripReopenedToCustomer(input: {
    to: string;
    pickupAddress: string;
    dropoffAddress: string;
    reason: string;
  }): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Your DRIVEPAL trip is being reassigned',
      preheader: 'We are finding another driver for your trip.',
      title: 'Finding another driver',
      paragraphs: [
        input.reason,
        `Pickup: ${input.pickupAddress}`,
        `Drop-off: ${input.dropoffAddress}`,
        'Your trip request remains active and visible to available drivers.',
      ],
    });
    await this.deliver(input.to, subject, html, text);
  }

  async sendTripUnassignedToDriver(input: {
    to: string;
    pickupAddress: string;
    dropoffAddress: string;
    reason: string;
  }): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'A DRIVEPAL trip was unassigned',
      preheader: 'This trip is now available for reassignment.',
      title: 'Trip unassigned',
      paragraphs: [
        input.reason,
        `Pickup: ${input.pickupAddress}`,
        `Drop-off: ${input.dropoffAddress}`,
      ],
    });
    await this.deliver(input.to, subject, html, text);
  }

  async sendScheduledTripReminderToDriver(input: {
    to: string;
    pickupAddress: string;
    dropoffAddress: string;
    scheduledForIso: string;
  }): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Scheduled DRIVEPAL trip starts in 10 minutes',
      preheader: 'Get ready for your scheduled pickup.',
      title: 'Scheduled trip reminder',
      paragraphs: [
        `Ride time: ${input.scheduledForIso}`,
        `Pickup: ${input.pickupAddress}`,
        `Drop-off: ${input.dropoffAddress}`,
        'Please head to pickup on time.',
      ],
    });
    await this.deliver(input.to, subject, html, text);
  }

  async sendDriverDocumentPendingApproval(input: {
    to: string;
    driverEmail: string;
    driverName: string;
  }): Promise<void> {
    const { subject, html, text } = buildDrivepalMail({
      subject: 'Driver documents pending approval',
      preheader: 'A driver uploaded documents and awaits manual verification.',
      title: 'Driver document verification required',
      paragraphs: [
        `Driver: ${input.driverName || 'Unknown driver'}`,
        `Driver email: ${input.driverEmail}`,
        'Documents were uploaded and status is now pending.',
        'Please review and set driver_document_status directly in the database.',
      ],
    });
    await this.deliver(input.to, subject, html, text);
  }
}
