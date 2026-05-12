import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [RouterLink],
  template: `
    <div class="drivepal-page drivepal-page--splash">
      <div class="drivepal-page__inner drivepal-page__inner--wide drivepal-stack">
        <p class="drivepal-kicker">DRIVEPAL</p>
        <h1 class="drivepal-display-title">
          <span class="msr" aria-hidden="true">admin_panel_settings</span>
          <span>Admin</span>
        </h1>
        <p class="drivepal-lede">
          Internal web console. Rider and driver onboarding is in the mobile app
          only — this UI is for staff with the
          <span class="drivepal-lede-strong">ADMIN_EMAIL</span> account.
        </p>
        <div class="drivepal-actions drivepal-actions--center">
          <a routerLink="/auth/login" class="drivepal-btn-primary drivepal-btn-primary--inline">
            <span class="msr drivepal-msr-btn" aria-hidden="true">login</span>
            Staff sign in
          </a>
        </div>
        <a routerLink="/auth/forgot-password" class="drivepal-foot-link">
          <span class="msr msr-sm" aria-hidden="true">lock_reset</span>
          Forgot password?
        </a>
      </div>
    </div>
  `,
})
export class HomeComponent {}
