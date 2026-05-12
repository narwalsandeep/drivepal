import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginRequestDto,
  LoginVerifyDto,
  RefreshTokenDto,
  ResetPasswordDto,
  SignupStartDto,
  SignupVerifyDto,
  UpdateDriverProfileDto,
  UpdateProfileDto,
} from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('signup/start')
  @HttpCode(HttpStatus.OK)
  signupStart(@Body() dto: SignupStartDto) {
    return this.auth.signupStart(dto);
  }

  @Post('signup/verify')
  @HttpCode(HttpStatus.CREATED)
  signupVerify(@Body() dto: SignupVerifyDto) {
    return this.auth.signupVerify(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  loginRequest(@Body() dto: LoginRequestDto) {
    return this.auth.loginRequest(dto);
  }

  @Post('login/verify')
  @HttpCode(HttpStatus.OK)
  loginVerify(@Body() dto: LoginVerifyDto) {
    return this.auth.loginVerify(dto);
  }

  /** Web admin UI only — `ADMIN_EMAIL` in env; OTP still by email. */
  @Post('admin/login')
  @HttpCode(HttpStatus.OK)
  adminLogin(@Body() dto: LoginRequestDto) {
    return this.auth.loginRequest(dto, { adminPanel: true });
  }

  @Post('admin/login/verify')
  @HttpCode(HttpStatus.OK)
  adminLoginVerify(@Body() dto: LoginVerifyDto) {
    return this.auth.loginVerify(dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.auth.refresh(dto);
  }

  @Patch('profile')
  @HttpCode(HttpStatus.OK)
  updateProfile(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.auth.updateAuthenticatedProfile(authorization, dto);
  }

  @Patch('driver-profile')
  @HttpCode(HttpStatus.OK)
  updateDriverProfile(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: UpdateDriverProfileDto,
  ) {
    return this.auth.updateAuthenticatedDriverProfile(authorization, dto);
  }

  @Patch('password')
  @HttpCode(HttpStatus.OK)
  changePassword(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.auth.changeAuthenticatedPassword(authorization, dto);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }
}
