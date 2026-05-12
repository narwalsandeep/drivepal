import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';

const base = '/api/auth';

@Injectable({ providedIn: 'root' })
export class AuthApiService {
  private readonly http = inject(HttpClient);

  /** Admin web UI only — same OTP flow; user must match `ADMIN_EMAIL`. */
  adminLogin(body: {
    identifier: string;
    password: string;
  }): Observable<{
    challengeId: string;
    message: string;
    emailMasked: string;
  }> {
    return this.http.post<{
      challengeId: string;
      message: string;
      emailMasked: string;
    }>(`${base}/admin/login`, body);
  }

  adminLoginVerify(body: {
    challengeId: string;
    otp: string;
  }): Observable<{
    activeRole: string;
    accessToken: string;
    refreshToken: string;
    tokenType: string;
  }> {
    return this.http.post<{
      activeRole: string;
      accessToken: string;
      refreshToken: string;
      tokenType: string;
    }>(`${base}/admin/login/verify`, body);
  }

  forgotPassword(body: { email: string }): Observable<unknown> {
    return this.http.post(`${base}/forgot-password`, body);
  }

  resetPassword(body: {
    kid: string;
    code: string;
    newPassword: string;
  }): Observable<unknown> {
    return this.http.post(`${base}/reset-password`, body);
  }
}
