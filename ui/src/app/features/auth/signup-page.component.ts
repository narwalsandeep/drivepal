import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AuthApiService } from '../../core/auth-api.service';

@Component({
  selector: 'app-signup',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div class="drivepal-page drivepal-page--centered">
      <div class="drivepal-page__inner">
        <a
          routerLink="/"
          class="drivepal-back-link drivepal-back-link--brand"
          ><span class="msr msr-sm" aria-hidden="true">arrow_back</span
          >DRIVEPAL</a
        >
        <div class="drivepal-card drivepal-card--raised">
          @if (busyMessage()) {
            <div role="status" aria-live="polite" class="drivepal-busy-overlay">
              <div class="drivepal-spinner" aria-hidden="true"></div>
              <p class="drivepal-busy-overlay__text">{{ busyMessage() }}</p>
            </div>
          }
          <div class="drivepal-card__header">
            <span class="msr msr-lg drivepal-icon-accent" aria-hidden="true">person_add</span>
            <h1 class="drivepal-card__title">Create account</h1>
          </div>
          <p class="drivepal-card__sub">
            Enter your name, email, and mobile. We’ll send a 6-digit code to your email.
          </p>

          @if (error()) {
            <p class="drivepal-banner-error">{{ error() }}</p>
          }
          @if (info()) {
            <p class="drivepal-banner-info">{{ info() }}</p>
          }

          @if (step() === 1) {
            <form
              [formGroup]="form1"
              (ngSubmit)="submitStep1()"
              class="drivepal-form drivepal-form--tight"
            >
              <div class="drivepal-field drivepal-field--inline-grid">
                <div>
                  <label class="drivepal-label" for="su-fn">First name</label>
                  <div class="drivepal-input-shell drivepal-input-shell--icon-sm">
                    <span class="msr drivepal-input__icon" aria-hidden="true">person</span>
                    <input
                      id="su-fn"
                      type="text"
                      formControlName="firstName"
                      autocomplete="given-name"
                      class="drivepal-input drivepal-input--pad-icon-sm drivepal-input--ring"
                    />
                  </div>
                </div>
                <div>
                  <label class="drivepal-label" for="su-ln">Last name</label>
                  <div class="drivepal-input-shell drivepal-input-shell--icon-sm">
                    <span class="msr drivepal-input__icon" aria-hidden="true">person</span>
                    <input
                      id="su-ln"
                      type="text"
                      formControlName="lastName"
                      autocomplete="family-name"
                      class="drivepal-input drivepal-input--pad-icon-sm drivepal-input--ring"
                    />
                  </div>
                </div>
              </div>
              <div class="drivepal-field">
                <label class="drivepal-label" for="su-email">Email</label>
                <div class="drivepal-input-shell">
                  <span class="msr drivepal-input__icon" aria-hidden="true">alternate_email</span>
                  <input
                    id="su-email"
                    type="email"
                    formControlName="email"
                    autocomplete="email"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring"
                  />
                </div>
              </div>
              <div class="drivepal-field">
                <label class="drivepal-label" for="su-phone">Mobile (UK)</label>
                <div class="drivepal-input-shell">
                  <span class="msr drivepal-input__icon" aria-hidden="true">smartphone</span>
                  <input
                    id="su-phone"
                    type="tel"
                    formControlName="phone"
                    placeholder="+44…"
                    autocomplete="tel"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring"
                  />
                </div>
              </div>
              <div class="drivepal-field">
                <label class="drivepal-label" for="su-pw">Password</label>
                <div class="drivepal-input-shell">
                  <span class="msr drivepal-input__icon" aria-hidden="true">lock</span>
                  <input
                    id="su-pw"
                    type="password"
                    formControlName="password"
                    autocomplete="new-password"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring"
                  />
                </div>
                <p class="drivepal-helper">At least 8 characters.</p>
              </div>
              <button type="submit" [disabled]="loading()" class="drivepal-btn-primary">
                @if (loading()) {
                  <span>Sending…</span>
                } @else {
                  <span class="msr drivepal-msr-btn" aria-hidden="true">outgoing_mail</span>
                  <span>Send code</span>
                }
              </button>
            </form>
          } @else {
            <form
              [formGroup]="form2"
              (ngSubmit)="submitStep2()"
              class="drivepal-form drivepal-form--tight"
            >
              <p class="drivepal-hint-row">
                <span class="msr msr-sm drivepal-icon-accent" aria-hidden="true">mark_email_read</span>
                <span
                  >Check your inbox — code sent to
                  <span class="drivepal-hint-row__hl">{{ emailForStep2() }}</span></span
                >
              </p>
              <div class="drivepal-field">
                <label class="drivepal-label" for="su-otp">Code from email</label>
                <div class="drivepal-input-shell">
                  <span class="msr drivepal-input__icon" aria-hidden="true">pin</span>
                  <input
                    id="su-otp"
                    formControlName="otp"
                    inputmode="numeric"
                    maxlength="6"
                    autocomplete="one-time-code"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--otp drivepal-input--ring"
                  />
                </div>
              </div>
              <input type="hidden" formControlName="email" />
              <button type="submit" [disabled]="loading()" class="drivepal-btn-primary">
                @if (loading()) {
                  <span>Verifying…</span>
                } @else {
                  <span class="msr drivepal-msr-btn" aria-hidden="true">verified</span>
                  <span>Verify & create account</span>
                }
              </button>
            </form>
          }
        </div>
        <p class="drivepal-muted-footer">
          Already have an account?
          <a routerLink="/auth/login" class="drivepal-muted-footer__link"
            ><span class="msr msr-sm" aria-hidden="true">login</span>Sign in</a
          >
        </p>
      </div>
    </div>
  `,
})
export class SignupPageComponent {
  private readonly fb = inject(FormBuilder);
  private readonly authApi = inject(AuthApiService);

  readonly step = signal<1 | 2>(1);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly info = signal<string | null>(null);
  readonly emailForStep2 = signal('');
  readonly busyMessage = signal<string | null>(null);

  readonly form1 = this.fb.nonNullable.group({
    firstName: ['', [Validators.required, Validators.maxLength(80)]],
    lastName: ['', [Validators.required, Validators.maxLength(80)]],
    email: ['', [Validators.required, Validators.email]],
    phone: ['', Validators.required],
    password: [
      '',
      [
        Validators.required,
        Validators.minLength(8),
        Validators.maxLength(128),
      ],
    ],
  });

  readonly form2 = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    otp: ['', [Validators.required, Validators.pattern(/^\d{6}$/)]],
  });

  submitStep1(): void {
    this.error.set(null);
    if (this.form1.invalid) {
      this.form1.markAllAsTouched();
      return;
    }
    this.busyMessage.set('Sending verification code to your email…');
    this.loading.set(true);
    this.authApi.signupStart(this.form1.getRawValue()).subscribe({
      next: (res) => {
        this.busyMessage.set(null);
        this.loading.set(false);
        const em = this.form1.controls.email.value.trim();
        this.emailForStep2.set(res.emailMasked ?? em);
        this.info.set(res.message ?? 'Verification code sent to your email.');
        this.form2.patchValue({ email: em });
        this.step.set(2);
      },
      error: (err: { error?: { message?: string | string[] } }) => {
        this.busyMessage.set(null);
        this.loading.set(false);
        const m = err.error?.message;
        this.error.set(
          Array.isArray(m) ? m.join(', ') : m ?? 'Request failed',
        );
      },
    });
  }

  submitStep2(): void {
    this.error.set(null);
    if (this.form2.invalid) {
      this.form2.markAllAsTouched();
      return;
    }
    this.busyMessage.set('Creating your account…');
    this.loading.set(true);
    this.authApi.signupVerify(this.form2.getRawValue()).subscribe({
      next: () => {
        this.busyMessage.set(null);
        this.loading.set(false);
        this.info.set('Welcome — account created. Store tokens securely for API access.');
      },
      error: (err: { error?: { message?: string | string[] } }) => {
        this.busyMessage.set(null);
        this.loading.set(false);
        const m = err.error?.message;
        this.error.set(
          Array.isArray(m) ? m.join(', ') : m ?? 'Request failed',
        );
      },
    });
  }
}
