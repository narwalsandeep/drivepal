import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { AuthApiService } from '../../core/auth-api.service';
import { LoginPageComponent } from './login-page.component';

describe('LoginPageComponent', () => {
  let fixture: ComponentFixture<LoginPageComponent>;
  let authApi: jasmine.SpyObj<Pick<AuthApiService, 'adminLogin' | 'adminLoginVerify'>>;

  beforeEach(async () => {
    authApi = jasmine.createSpyObj<Pick<AuthApiService, 'adminLogin' | 'adminLoginVerify'>>(
      ['adminLogin', 'adminLoginVerify'],
    );

    await TestBed.configureTestingModule({
      imports: [LoginPageComponent],
      providers: [
        provideRouter([]),
        { provide: AuthApiService, useValue: authApi },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(LoginPageComponent);
  });

  it('shows Sign in title', () => {
    fixture.detectChanges();
    const h1 = fixture.debugElement.query(By.css('h1'));
    expect(h1?.nativeElement.textContent).toContain('Sign in');
  });

  it('calls adminLogin on step 1 submit', () => {
    authApi.adminLogin.and.returnValue(
      of({
        challengeId: 'c1',
        message: 'ok',
        emailMasked: 'a***e@x.com',
      }),
    );

    fixture.detectChanges();
    const page = fixture.componentInstance;
    page.form1.patchValue({
      identifier: 'admin@example.com',
      password: 'Password12345',
    });

    const btn = fixture.debugElement.query(By.css('button[type="submit"]'));
    btn.nativeElement.click();
    fixture.detectChanges();

    expect(authApi.adminLogin).toHaveBeenCalled();
  });

  it('shows error when adminLogin fails', () => {
    authApi.adminLogin.and.returnValue(
      throwError(() => ({ error: { message: 'Admin access only' } })),
    );

    fixture.detectChanges();
    const page = fixture.componentInstance;
    page.form1.patchValue({
      identifier: 'x@y.com',
      password: 'Password12345',
    });

    fixture.debugElement.query(By.css('button[type="submit"]')).nativeElement.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Admin access only');
  });
});
