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
  selector: 'app-forgot-password',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div class="drivepal-page drivepal-page--centered">
      <div class="drivepal-page__inner">
        <a routerLink="/auth/login" class="drivepal-back-link"
          ><span class="msr msr-sm" aria-hidden="true">arrow_back</span>Back</a
        >
        <div class="drivepal-card drivepal-card--raised">
          @if (busyMessage()) {
            <div role="status" aria-live="polite" class="drivepal-busy-overlay">
              <div class="drivepal-spinner" aria-hidden="true"></div>
              <p class="drivepal-busy-overlay__text">{{ busyMessage() }}</p>
            </div>
          }
          <div class="drivepal-card__header">
            <span class="msr msr-lg drivepal-icon-accent" aria-hidden="true">mail</span>
            <h1 class="drivepal-card__title">Forgot password</h1>
          </div>
          <p class="drivepal-card__sub">We’ll email a reset link. No SMS — email only.</p>
          @if (info()) {
            <p class="drivepal-banner-info">{{ info() }}</p>
          }
          @if (error()) {
            <p class="drivepal-banner-error">{{ error() }}</p>
          }
          <form [formGroup]="form" (ngSubmit)="submit()" class="drivepal-form drivepal-form--tight">
            <div class="drivepal-field">
              <label class="drivepal-label" for="fp-email">Email</label>
              <div class="drivepal-input-shell">
                <span class="msr drivepal-input__icon" aria-hidden="true">alternate_email</span>
                <input id="fp-email" type="email" formControlName="email" class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring" />
              </div>
            </div>
            <button type="submit" [disabled]="loading()" class="drivepal-btn-primary">
              @if (loading()) {
                <span>Sending…</span>
              } @else {
                <span class="msr drivepal-msr-btn" aria-hidden="true">send</span>
                <span>Send reset link</span>
              }
            </button>
          </form>
        </div>
      </div>
    </div>
  `,
})
export class ForgotPasswordPageComponent {
  private readonly fb = inject(FormBuilder);
  private readonly authApi = inject(AuthApiService);

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly info = signal<string | null>(null);
  readonly busyMessage = signal<string | null>(null);

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
  });

  submit(): void {
    this.error.set(null);
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.busyMessage.set('Sending reset link…');
    this.loading.set(true);
    this.authApi.forgotPassword(this.form.getRawValue()).subscribe({
      next: (res: unknown) => {
        this.busyMessage.set(null);
        this.loading.set(false);
        const r = res as { message?: string };
        this.info.set(
          r.message ??
            'If an account exists for this email, check your inbox.',
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
