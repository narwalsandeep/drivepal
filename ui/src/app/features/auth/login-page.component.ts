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
  selector: 'app-login',
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
            <div
              role="status"
              aria-live="polite"
              class="drivepal-busy-overlay"
            >
              <div class="drivepal-spinner" aria-hidden="true"></div>
              <p class="drivepal-busy-overlay__text">
                {{ busyMessage() }}
              </p>
            </div>
          }
          <div class="drivepal-card__header">
            <span
              class="msr msr-lg drivepal-icon-accent"
              aria-hidden="true"
              >account_circle</span
            >
            <h1 class="drivepal-card__title">Sign in</h1>
          </div>

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
              <div class="drivepal-field">
                <label class="drivepal-label" for="login-identifier">Email or mobile</label>
                <div class="drivepal-input-shell">
                  <span
                    class="msr drivepal-input__icon"
                    aria-hidden="true"
                    >contact_mail</span
                  >
                  <input
                    id="login-identifier"
                    type="text"
                    formControlName="identifier"
                    autocomplete="username"
                    placeholder="you@example.com or +44…"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring"
                  />
                </div>
              </div>
              <div class="drivepal-field">
                <label class="drivepal-label" for="login-password">Password</label>
                <div class="drivepal-input-shell">
                  <span
                    class="msr drivepal-input__icon"
                    aria-hidden="true"
                    >lock</span
                  >
                  <input
                    id="login-password"
                    type="password"
                    formControlName="password"
                    autocomplete="current-password"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring"
                  />
                </div>
              </div>
              <button
                type="submit"
                [disabled]="loading()"
                class="drivepal-btn-primary"
              >
                @if (loading()) {
                  <span>Sending…</span>
                } @else {
                  <span class="msr drivepal-msr-btn" aria-hidden="true">arrow_forward</span>
                  <span>Continue</span>
                }
              </button>
            </form>
          } @else {
            <form
              [formGroup]="form2"
              (ngSubmit)="submitStep2()"
              class="drivepal-form drivepal-form--tight"
            >
              @if (loginEmailMasked()) {
                <p class="drivepal-hint-row">
                  <span class="msr msr-sm drivepal-icon-accent" aria-hidden="true">mark_email_read</span>
                  <span
                    >Code sent to
                    <span class="drivepal-hint-row__hl">{{ loginEmailMasked() }}</span></span
                  >
                </p>
              }
              <div class="drivepal-field">
                <label class="drivepal-label" for="login-otp"
                  >Code from email</label
                >
                <div class="drivepal-input-shell">
                  <span
                    class="msr drivepal-input__icon"
                    aria-hidden="true"
                    >pin</span
                  >
                  <input
                    id="login-otp"
                    formControlName="otp"
                    inputmode="numeric"
                    maxlength="6"
                    autocomplete="one-time-code"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--otp drivepal-input--ring"
                  />
                </div>
              </div>
              <button
                type="submit"
                [disabled]="loading()"
                class="drivepal-btn-primary"
              >
                @if (loading()) {
                  <span>Signing in…</span>
                } @else {
                  <span class="msr drivepal-msr-btn" aria-hidden="true">verified</span>
                  <span>Verify & sign in</span>
                }
              </button>
            </form>
          }
        </div>
        <p class="drivepal-muted-footer">
          <a
            routerLink="/auth/forgot-password"
            class="drivepal-muted-footer__link"
            ><span class="msr msr-sm" aria-hidden="true">lock_reset</span>Forgot password?</a
          >
        </p>
      </div>
    </div>
  `,
})
export class LoginPageComponent {
  private readonly fb = inject(FormBuilder);
  private readonly authApi = inject(AuthApiService);

  readonly step = signal<1 | 2>(1);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly info = signal<string | null>(null);
  readonly loginEmailMasked = signal<string | null>(null);
  readonly busyMessage = signal<string | null>(null);
  private challengeId = '';

  readonly form1 = this.fb.nonNullable.group({
    identifier: ['', [Validators.required, Validators.minLength(3)]],
    password: ['', [Validators.required, Validators.minLength(8)]],
  });

  readonly form2 = this.fb.nonNullable.group({
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
    this.authApi.adminLogin(this.form1.getRawValue()).subscribe({
      next: (res) => {
        this.busyMessage.set(null);
        this.loading.set(false);
        this.challengeId = res.challengeId;
        this.loginEmailMasked.set(res.emailMasked);
        this.info.set(null);
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
    if (this.form2.invalid || !this.challengeId) {
      this.form2.markAllAsTouched();
      return;
    }
    this.busyMessage.set('Signing you in…');
    this.loading.set(true);
    this.authApi
      .adminLoginVerify({
        challengeId: this.challengeId,
        otp: this.form2.controls.otp.value,
      })
      .subscribe({
        next: (res) => {
          this.busyMessage.set(null);
          this.loading.set(false);
          this.info.set(
            res.activeRole === 'admin'
              ? 'Signed in as admin. Use accessToken from the API response.'
              : 'Signed in. Use accessToken from API response.',
          );
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
