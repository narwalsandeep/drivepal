import {
  IsBase64,
  IsEmail,
  IsInt,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class SignupStartDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  firstName: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  lastName: string;

  @IsEmail()
  email: string;

  @IsString()
  @IsNotEmpty()
  phone: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password: string;

  /** First signup as rider, or first/signup extension as driver (same email+phone+password). */
  @IsIn(['customer', 'driver'])
  signupAs: 'customer' | 'driver';
}

export class SignupVerifyDto {
  @IsEmail()
  email: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'OTP must be 6 digits' })
  otp: string;
}

export class LoginRequestDto {
  /** Email address or mobile number (national or E.164). */
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(320)
  identifier: string;

  @IsString()
  @MinLength(8)
  password: string;

  /** Flutter: sign in as rider or driver (must have completed that profile). */
  @IsOptional()
  @IsIn(['customer', 'driver'])
  loginAs?: 'customer' | 'driver';
}

export class LoginVerifyDto {
  @IsUUID('4')
  challengeId: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'OTP must be 6 digits' })
  otp: string;
}

export class ForgotPasswordDto {
  @IsEmail()
  email: string;
}

export class ResetPasswordDto {
  @IsUUID('4')
  kid: string;

  @IsString()
  @IsNotEmpty()
  code: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  newPassword: string;
}

export class RefreshTokenDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class ChangePasswordDto {
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  currentPassword: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  newPassword: string;
}

/** Authenticated profile update — all fields optional; omit means “leave unchanged”. */
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  lastName?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}

export class UpdateDriverProfileDto {
  @IsString()
  @IsNotEmpty()
  @IsBase64()
  driverProfilePhotoBase64: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  driverAddress: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  driverLocationText: string;

  @IsInt()
  @Min(18)
  @Max(90)
  driverAge: number;

  @IsIn(['male', 'female', 'other', 'prefer_not_to_say'])
  driverGender: 'male' | 'female' | 'other' | 'prefer_not_to_say';

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  driverVisaStatus: string;

  @IsString()
  @IsNotEmpty()
  @IsBase64()
  driverDlImageBase64: string;
}
