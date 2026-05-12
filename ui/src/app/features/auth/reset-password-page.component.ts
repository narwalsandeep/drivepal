import { CommonModule } from '@angular/common';
import { Component, inject, OnInit, signal } from '@angular/core';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators,
} from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { AuthApiService } from '../../core/auth-api.service';

@Component({
  selector: 'app-reset-password',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  template: `
    <div class="drivepal-page drivepal-page--centered">
      <div class="drivepal-page__inner">
        <a routerLink="/auth/login" class="drivepal-back-link"
          ><span class="msr msr-sm" aria-hidden="true">arrow_back</span>Sign in</a
        >
        <div class="drivepal-card drivepal-card--raised">
          <div class="drivepal-card__header">
            <span class="msr msr-lg drivepal-icon-accent" aria-hidden="true">vpn_key</span>
            <h1 class="drivepal-card__title">New password</h1>
          </div>
          @if (missingParams()) {
            <p class="drivepal-banner-error">Invalid link — use the URL from your email.</p>
          } @else {
            <p class="drivepal-card__sub">At least 8 characters.</p>
            @if (info()) {
              <p class="drivepal-banner-info">{{ info() }}</p>
            }
            @if (error()) {
              <p class="drivepal-banner-error">{{ error() }}</p>
            }
            <form [formGroup]="form" (ngSubmit)="submit()" class="drivepal-form drivepal-form--tight">
              <div class="drivepal-field">
                <label class="drivepal-label" for="rp-pw">New password</label>
                <div class="drivepal-input-shell">
                  <span class="msr drivepal-input__icon" aria-hidden="true">lock</span>
                  <input
                    id="rp-pw"
                    type="password"
                    formControlName="newPassword"
                    class="drivepal-input drivepal-input--pad-icon-md drivepal-input--ring"
                  />
                </div>
              </div>
              <button type="submit" [disabled]="loading()" class="drivepal-btn-primary">
                @if (loading()) {
                  <span>Saving…</span>
                } @else {
                  <span class="msr drivepal-msr-btn" aria-hidden="true">save</span>
                  <span>Update password</span>
                }
              </button>
            </form>
          }
        </div>
      </div>
    </div>
  `,
})
export class ResetPasswordPageComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly authApi = inject(AuthApiService);
  private readonly route = inject(ActivatedRoute);

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly info = signal<string | null>(null);
  readonly missingParams = signal(true);
  private kid = '';
  private code = '';

  readonly form = this.fb.nonNullable.group({
    newPassword: [
      '',
      [
        Validators.required,
        Validators.minLength(8),
        Validators.maxLength(128),
      ],
    ],
  });

  ngOnInit(): void {
    this.route.queryParamMap.subscribe((q) => {
      const kid = q.get('kid') ?? '';
      const code = q.get('code') ?? '';
      this.kid = kid;
      this.code = code;
      this.missingParams.set(!kid || !code);
    });
  }

  submit(): void {
    if (this.missingParams()) return;
    this.error.set(null);
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.loading.set(true);
    this.authApi
      .resetPassword({
        kid: this.kid,
        code: this.code,
        newPassword: this.form.controls.newPassword.value,
      })
      .subscribe({
        next: () => {
          this.loading.set(false);
          this.info.set('Password updated. You can sign in now.');
        },
        error: (err: { error?: { message?: string | string[] } }) => {
          this.loading.set(false);
          const m = err.error?.message;
          this.error.set(
            Array.isArray(m) ? m.join(', ') : m ?? 'Request failed',
          );
        },
      });
  }
}
