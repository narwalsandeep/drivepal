import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';
import {
  generateOtp6Digit,
  generateUrlToken,
  hashOtpCode,
  verifyOtpCode,
} from './crypto/otp-crypto';
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
import { AppRole } from './enums/app-role.enum';
import { LoginChallenge } from './entities/login-challenge.entity';
import { PasswordResetToken } from './entities/password-reset-token.entity';
import { RegistrationIntent } from './entities/registration-intent.entity';
import { User } from './entities/user.entity';
import { DriverDocumentStatus } from './enums/driver-document-status.enum';
import { UserStatus } from './enums/user-status.enum';
import { MailService } from './services/mail.service';
import { maskEmail } from './utils/mask-email';
import { resolveAppLoginRole } from './utils/resolve-app-login-role';
import { normalizeToE164 } from './utils/phone.util';

const OTP_TTL_MS = 10 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
const RESET_TTL_MS = 60 * 60 * 1000;
const BCRYPT_ROUNDS = 12;
const MAX_DRIVER_DOCUMENT_BYTES = 8 * 1024 * 1024 * 1024;

const userLoginSelect = {
  id: true,
  email: true,
  phoneE164: true,
  firstName: true,
  lastName: true,
  passwordHash: true,
  status: true,
  emailVerified: true,
  phoneVerified: true,
  isCustomer: true,
  isDriver: true,
  driverProfileCompleted: true,
} as const;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly otpSecret: string;
  private readonly defaultCountry: string;
  private readonly frontendUrl: string;

  constructor(
    @InjectRepository(User)
    private readonly users: Repository<User>,
    @InjectRepository(RegistrationIntent)
    private readonly registrationIntents: Repository<RegistrationIntent>,
    @InjectRepository(LoginChallenge)
    private readonly loginChallenges: Repository<LoginChallenge>,
    @InjectRepository(PasswordResetToken)
    private readonly resetTokens: Repository<PasswordResetToken>,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
  ) {
    this.otpSecret = this.config.getOrThrow<string>('JWT_SECRET');
    this.defaultCountry =
      this.config.get<string>('DEFAULT_PHONE_REGION') ?? 'GB';
    this.frontendUrl =
      this.config.get<string>('FRONTEND_WEB_URL') ?? 'http://localhost:4200';
  }

  async signupStart(dto: SignupStartDto) {
    const firstName = dto.firstName.trim();
    const lastName = dto.lastName.trim();
    const email = dto.email.trim().toLowerCase();
    const { e164 } = normalizeToE164(dto.phone, this.defaultCountry);
    const signupAsEnum =
      dto.signupAs === 'customer' ? AppRole.CUSTOMER : AppRole.DRIVER;

    if (!firstName || !lastName) {
      throw new BadRequestException('First name and last name are required');
    }

    const userByEmail = await this.users.findOne({
      where: { email },
      select: {
        id: true,
        email: true,
        phoneE164: true,
        firstName: true,
        lastName: true,
        passwordHash: true,
        isCustomer: true,
        isDriver: true,
      },
    });

    if (userByEmail) {
      if (userByEmail.phoneE164 !== e164) {
        throw new ConflictException(
          'This email is registered with a different mobile number',
        );
      }
      if (!(await bcrypt.compare(dto.password, userByEmail.passwordHash))) {
        throw new UnauthorizedException('Invalid password for this account');
      }
      if (signupAsEnum === AppRole.CUSTOMER && userByEmail.isCustomer) {
        throw new ConflictException(
          'This account is already registered as a rider',
        );
      }
      if (signupAsEnum === AppRole.DRIVER && userByEmail.isDriver) {
        throw new ConflictException(
          'This account is already registered as a driver',
        );
      }

      await this.registrationIntents
        .createQueryBuilder()
        .delete()
        .where('email = :email OR phone_e164 = :phone', {
          email,
          phone: e164,
        })
        .execute();

      const otp = generateOtp6Digit();
      const otpCodeHash = hashOtpCode(otp, this.otpSecret);
      const expiresAt = new Date(Date.now() + OTP_TTL_MS);

      await this.registrationIntents.save(
        this.registrationIntents.create({
          firstName: userByEmail.firstName,
          lastName: userByEmail.lastName,
          email,
          phoneE164: e164,
          passwordHash: userByEmail.passwordHash,
          otpCodeHash,
          expiresAt,
          attempts: 0,
          existingUserId: userByEmail.id,
          signupAs: signupAsEnum,
        }),
      );

      try {
        await this.mail.sendOtpEmail(email, 'signup', otp);
      } catch (err) {
        this.logger.warn(
          `sendOtpEmail (signup) failed for ${email}: ${(err as Error).message}`,
        );
        await this.registrationIntents.delete({ email });
        throw new BadRequestException(
          'Could not send verification email — check mail configuration',
        );
      }

      return {
        message: 'Verification code sent to your email',
        emailMasked: maskEmail(email),
        signupMode: 'extend' as const,
      };
    }

    const phoneTaken = await this.users.findOne({
      where: { phoneE164: e164 },
    });
    if (phoneTaken) {
      throw new ConflictException('This mobile number is already in use');
    }

    await this.registrationIntents
      .createQueryBuilder()
      .delete()
      .where('email = :email OR phone_e164 = :phone', {
        email,
        phone: e164,
      })
      .execute();

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const otp = generateOtp6Digit();
    const otpCodeHash = hashOtpCode(otp, this.otpSecret);
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    await this.registrationIntents.save(
      this.registrationIntents.create({
        firstName,
        lastName,
        email,
        phoneE164: e164,
        passwordHash,
        otpCodeHash,
        expiresAt,
        attempts: 0,
        existingUserId: null,
        signupAs: signupAsEnum,
      }),
    );

    try {
      await this.mail.sendOtpEmail(email, 'signup', otp);
    } catch (err) {
      this.logger.warn(
        `sendOtpEmail (signup) failed for ${email}: ${(err as Error).message}`,
      );
      await this.registrationIntents.delete({ email });
      throw new BadRequestException(
        'Could not send verification email — check mail configuration',
      );
    }

    return {
      message: 'Verification code sent to your email',
      emailMasked: maskEmail(email),
      signupMode: 'new' as const,
    };
  }

  async signupVerify(dto: SignupVerifyDto) {
    const email = dto.email.trim().toLowerCase();
    const intent = await this.registrationIntents.findOne({
      where: { email },
    });
    if (!intent) {
      throw new BadRequestException(
        'No pending signup for this email — start again',
      );
    }
    if (intent.expiresAt.getTime() < Date.now()) {
      await this.registrationIntents.remove(intent);
      throw new BadRequestException('Code expired — request signup again');
    }
    if (intent.attempts >= MAX_OTP_ATTEMPTS) {
      await this.registrationIntents.remove(intent);
      throw new BadRequestException('Too many attempts — start signup again');
    }

    if (!verifyOtpCode(dto.otp, intent.otpCodeHash, this.otpSecret)) {
      intent.attempts += 1;
      await this.registrationIntents.save(intent);
      throw new UnauthorizedException('Invalid code');
    }

    if (intent.existingUserId) {
      const user = await this.users.findOne({
        where: { id: intent.existingUserId },
      });
      if (!user) {
        await this.registrationIntents.remove(intent);
        throw new NotFoundException();
      }
      if (intent.signupAs === AppRole.CUSTOMER) {
        user.isCustomer = true;
      } else {
        user.isDriver = true;
        user.isCustomer = true;
      }
      await this.users.save(user);
      await this.registrationIntents.remove(intent);

      const tokens = await this.issueTokens(user);
      return {
        message: 'Profile updated',
        signupAs: intent.signupAs === AppRole.CUSTOMER ? 'customer' : 'driver',
        user: this.publicUser(user),
        ...tokens,
      };
    }

    const clash = await this.users.findOne({
      where: [{ email: intent.email }, { phoneE164: intent.phoneE164 }],
    });
    if (clash) {
      await this.registrationIntents.remove(intent);
      throw new ConflictException('Account was already registered');
    }

    const isCustomer =
      intent.signupAs === AppRole.CUSTOMER ||
      intent.signupAs === AppRole.DRIVER;
    const isDriver = intent.signupAs === AppRole.DRIVER;

    const user = this.users.create({
      firstName: intent.firstName,
      lastName: intent.lastName,
      email: intent.email,
      phoneE164: intent.phoneE164,
      passwordHash: intent.passwordHash,
      emailVerified: true,
      phoneVerified: true,
      isCustomer,
      isDriver,
    });
    await this.users.save(user);
    await this.registrationIntents.remove(intent);

    try {
      await this.mail.sendWelcome(user.email);
    } catch (err) {
      this.logger.warn(
        `sendWelcome failed for ${user.email}: ${(err as Error).message}`,
      );
    }

    const tokens = await this.issueTokens(user);
    return {
      message: 'Account created',
      signupAs: intent.signupAs === AppRole.CUSTOMER ? 'customer' : 'driver',
      user: this.publicUser(user),
      ...tokens,
    };
  }

  async loginRequest(dto: LoginRequestDto, opts?: { adminPanel?: boolean }) {
    const user = await this.findUserByIdentifier(dto.identifier);
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException(
        'Invalid email, mobile number, or password',
      );
    }
    if (user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account is not active');
    }

    let appRole: 'customer' | 'driver' | null = null;
    let isAdminPanel = false;

    if (opts?.adminPanel) {
      const adminEmail = this.config
        .get<string>('ADMIN_EMAIL')
        ?.trim()
        .toLowerCase();
      if (!adminEmail) {
        this.logger.warn(
          'ADMIN_EMAIL is not configured — admin web login rejected',
        );
        throw new ForbiddenException(
          'Admin sign-in is not configured (set ADMIN_EMAIL on the API server)',
        );
      }
      if (user.email !== adminEmail) {
        throw new ForbiddenException(
          'Admin access only — sign in with the ADMIN_EMAIL account for this environment',
        );
      }
      isAdminPanel = true;
    } else {
      if (dto.loginAs === 'customer' && user.isDriver && !user.isCustomer) {
        user.isCustomer = true;
        await this.users.save(user);
      }
      appRole = resolveAppLoginRole(user, dto.loginAs);
    }

    await this.loginChallenges.delete({ userId: user.id });

    const otp = generateOtp6Digit();
    const otpCodeHash = hashOtpCode(otp, this.otpSecret);
    const challenge = await this.loginChallenges.save(
      this.loginChallenges.create({
        userId: user.id,
        otpCodeHash,
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
        attempts: 0,
        consumedAt: null,
        appRole,
        isAdminPanel,
      }),
    );

    try {
      await this.mail.sendOtpEmail(user.email, 'login', otp);
    } catch (err) {
      this.logger.warn(
        `sendOtpEmail (login) failed for ${user.email}: ${(err as Error).message}`,
      );
      await this.loginChallenges.remove(challenge);
      throw new BadRequestException(
        'Could not send sign-in code — check mail configuration',
      );
    }

    return {
      challengeId: challenge.id,
      message: 'Verification code sent to your email',
      emailMasked: maskEmail(user.email),
    };
  }

  async loginVerify(dto: LoginVerifyDto) {
    const challenge = await this.loginChallenges.findOne({
      where: { id: dto.challengeId },
      relations: { user: true },
    });

    if (!challenge || challenge.consumedAt) {
      throw new BadRequestException('Invalid or expired login session');
    }
    if (challenge.expiresAt.getTime() < Date.now()) {
      await this.loginChallenges.remove(challenge);
      throw new BadRequestException('Code expired — sign in again');
    }
    if (challenge.attempts >= MAX_OTP_ATTEMPTS) {
      await this.loginChallenges.remove(challenge);
      throw new BadRequestException('Too many attempts — sign in again');
    }

    if (!verifyOtpCode(dto.otp, challenge.otpCodeHash, this.otpSecret)) {
      challenge.attempts += 1;
      await this.loginChallenges.save(challenge);
      throw new UnauthorizedException('Invalid code');
    }

    const user = await this.users.findOne({ where: { id: challenge.userId } });
    if (!user) {
      throw new NotFoundException();
    }

    if (challenge.isAdminPanel) {
      const adminEmail = this.config
        .get<string>('ADMIN_EMAIL')
        ?.trim()
        .toLowerCase();
      if (!adminEmail) {
        await this.loginChallenges.remove(challenge);
        throw new ForbiddenException(
          'Admin sign-in is not configured (set ADMIN_EMAIL on the API server)',
        );
      }
      if (user.email !== adminEmail) {
        await this.loginChallenges.remove(challenge);
        throw new ForbiddenException(
          'Admin access only — sign in with the ADMIN_EMAIL account for this environment',
        );
      }
    }

    challenge.consumedAt = new Date();
    await this.loginChallenges.save(challenge);

    const tokens = await this.issueTokens(user);

    let activeRole: string;
    if (challenge.isAdminPanel) {
      activeRole = 'admin';
    } else if (challenge.appRole) {
      activeRole = challenge.appRole;
    } else {
      activeRole = resolveAppLoginRole(user, undefined);
    }

    return {
      message: 'Signed in',
      user: this.publicUser(user),
      activeRole,
      ...tokens,
    };
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.users.findOne({ where: { email } });
    const generic = {
      message:
        'If an account exists for this email, you will receive reset instructions shortly',
    };
    if (!user) {
      return generic;
    }

    await this.resetTokens.update(
      { email, consumed: false },
      { consumed: true },
    );

    const code = generateUrlToken();
    const codeHash = hashOtpCode(code, this.otpSecret);
    const entity = await this.resetTokens.save(
      this.resetTokens.create({
        email,
        codeHash,
        expiresAt: new Date(Date.now() + RESET_TTL_MS),
        consumed: false,
      }),
    );

    const url = `${this.frontendUrl}/auth/reset-password?kid=${entity.id}&code=${code}`;
    try {
      await this.mail.sendPasswordResetLink(email, url);
    } catch (err) {
      this.logger.warn(
        `sendPasswordResetLink failed for ${email}: ${(err as Error).message}`,
      );
    }
    return generic;
  }

  async resetPassword(dto: ResetPasswordDto) {
    const row = await this.resetTokens.findOne({ where: { id: dto.kid } });
    if (!row || row.consumed || row.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('Invalid or expired reset link');
    }
    if (!verifyOtpCode(dto.code, row.codeHash, this.otpSecret)) {
      throw new UnauthorizedException('Invalid reset code');
    }

    const user = await this.users.findOne({
      where: { email: row.email },
      select: userLoginSelect,
    });
    if (!user) {
      throw new BadRequestException('User no longer exists');
    }

    user.passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);
    await this.users.save(user);
    row.consumed = true;
    await this.resetTokens.save(row);

    try {
      await this.mail.sendPasswordChanged(user.email);
    } catch (err) {
      this.logger.warn(
        `sendPasswordChanged failed for ${user.email}: ${(err as Error).message}`,
      );
    }

    return { message: 'Password updated — you can sign in now' };
  }

  private async findUserByIdentifier(
    raw: string,
  ): Promise<(User & { passwordHash: string }) | null> {
    const trimmed = raw.trim();
    if (!trimmed) {
      return null;
    }

    if (trimmed.includes('@')) {
      const email = trimmed.toLowerCase();
      return this.users.findOne({
        where: { email },
        select: userLoginSelect,
      });
    }

    try {
      const { e164 } = normalizeToE164(trimmed, this.defaultCountry);
      return this.users.findOne({
        where: { phoneE164: e164 },
        select: userLoginSelect,
      });
    } catch (e) {
      if (e instanceof BadRequestException) {
        throw e;
      }
      return null;
    }
  }

  private publicUser(user: User) {
    return {
      id: user.id,
      email: user.email,
      phoneE164: user.phoneE164,
      firstName: user.firstName,
      lastName: user.lastName,
      isCustomer: user.isCustomer,
      isDriver: user.isDriver,
      driverProfileCompleted: user.driverProfileCompleted,
      driverProfilePhotoBase64: user.driverProfilePhotoBase64,
      driverAddress: user.driverAddress,
      driverLocationText: user.driverLocationText,
      driverAge: user.driverAge,
      driverGender: user.driverGender,
      driverVisaStatus: user.driverVisaStatus,
      driverDlImageBase64: user.driverDlImageBase64,
      driverDocumentStatus: user.driverDocumentStatus,
      driverDocumentReviewedAt:
        user.driverDocumentReviewedAt?.toISOString() ?? null,
    };
  }

  private async issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email };
    const accessMinutes = Number(
      this.config.get<string>('JWT_ACCESS_MINUTES') ?? '15',
    );
    const refreshDays = Number(
      this.config.get<string>('JWT_REFRESH_DAYS') ?? '7',
    );
    const accessToken = await this.jwt.signAsync(payload, {
      expiresIn: accessMinutes * 60,
    });
    const refreshToken = await this.jwt.signAsync(
      { ...payload, kind: 'refresh' },
      { expiresIn: refreshDays * 24 * 60 * 60 },
    );
    return { accessToken, refreshToken, tokenType: 'Bearer' as const };
  }

  async refresh(dto: RefreshTokenDto) {
    let payload: { sub: string; email: string; kind?: string };
    try {
      payload = await this.jwt.verifyAsync<{
        sub: string;
        email: string;
        kind?: string;
      }>(dto.refreshToken);
    } catch {
      throw new UnauthorizedException('Invalid session — sign in again');
    }
    if (payload.kind !== 'refresh') {
      throw new UnauthorizedException('Invalid session — sign in again');
    }
    const user = await this.users.findOne({
      where: { id: payload.sub },
      select: userLoginSelect,
    });
    if (!user || user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account unavailable');
    }
    const tokens = await this.issueTokens(user);
    return {
      user: this.publicUser(user),
      ...tokens,
    };
  }

  async updateAuthenticatedProfile(
    authorizationHeader: string | undefined,
    dto: UpdateProfileDto,
  ) {
    const userId = await this.parseAccessTokenSub(authorizationHeader);
    return this.applyProfileUpdate(userId, dto);
  }

  async updateAuthenticatedDriverProfile(
    authorizationHeader: string | undefined,
    dto: UpdateDriverProfileDto,
  ) {
    const userId = await this.parseAccessTokenSub(authorizationHeader);
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status !== UserStatus.ACTIVE || !user.isDriver) {
      throw new UnauthorizedException('Driver account unavailable');
    }
    this.assertBase64PayloadWithinBytes(
      dto.driverProfilePhotoBase64,
      MAX_DRIVER_DOCUMENT_BYTES,
      'Driver profile photo is too large',
    );
    this.assertBase64PayloadWithinBytes(
      dto.driverDlImageBase64,
      MAX_DRIVER_DOCUMENT_BYTES,
      'Driver licence image is too large',
    );
    const documentChanged =
      user.driverDlImageBase64 !== dto.driverDlImageBase64.trim() ||
      user.driverProfilePhotoBase64 !== dto.driverProfilePhotoBase64.trim();
    user.driverProfilePhotoBase64 = dto.driverProfilePhotoBase64.trim();
    user.driverAddress = dto.driverAddress.trim();
    user.driverLocationText = dto.driverLocationText.trim();
    user.driverAge = dto.driverAge;
    user.driverGender = dto.driverGender;
    user.driverVisaStatus = dto.driverVisaStatus.trim();
    user.driverDlImageBase64 = dto.driverDlImageBase64.trim();
    user.driverProfileCompleted = true;
    if (documentChanged) {
      user.driverDocumentStatus = DriverDocumentStatus.PENDING;
      user.driverDocumentReviewedAt = null;
    }
    await this.users.save(user);
    if (documentChanged) {
      const adminEmail = this.config
        .get<string>('ADMIN_EMAIL')
        ?.trim()
        .toLowerCase();
      if (adminEmail) {
        try {
          await this.mail.sendDriverDocumentPendingApproval({
            to: adminEmail,
            driverEmail: user.email,
            driverName: `${user.firstName} ${user.lastName}`.trim(),
          });
        } catch (err) {
          this.logger.warn(
            `sendDriverDocumentPendingApproval failed for ${adminEmail}: ${(err as Error).message}`,
          );
        }
      }
    }
    return { user: this.publicUser(user), message: 'Driver profile completed' };
  }

  async changeAuthenticatedPassword(
    authorizationHeader: string | undefined,
    dto: ChangePasswordDto,
  ) {
    const userId = await this.parseAccessTokenSub(authorizationHeader);
    const user = await this.users.findOne({
      where: { id: userId },
      select: userLoginSelect,
    });
    if (!user || user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account unavailable');
    }

    const currentMatches = await bcrypt.compare(
      dto.currentPassword,
      user.passwordHash,
    );
    if (!currentMatches) {
      throw new UnauthorizedException('Current password is incorrect');
    }
    const sameAsCurrent = await bcrypt.compare(
      dto.newPassword,
      user.passwordHash,
    );
    if (sameAsCurrent) {
      throw new BadRequestException(
        'New password must be different from current password',
      );
    }

    user.passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);
    await this.users.save(user);

    try {
      await this.mail.sendPasswordChanged(user.email);
    } catch (err) {
      this.logger.warn(
        `sendPasswordChanged failed for ${user.email}: ${(err as Error).message}`,
      );
    }
    return { message: 'Password updated successfully' };
  }

  async getAuthenticatedUserId(
    authorizationHeader: string | undefined,
  ): Promise<string> {
    return this.parseAccessTokenSub(authorizationHeader);
  }

  private async parseAccessTokenSub(
    authorizationHeader: string | undefined,
  ): Promise<string> {
    if (!authorizationHeader?.toLowerCase().startsWith('bearer ')) {
      throw new UnauthorizedException('Missing access token');
    }
    const token = authorizationHeader.slice(7).trim();
    if (!token) {
      throw new UnauthorizedException('Missing access token');
    }
    try {
      const payload = await this.jwt.verifyAsync<{
        sub: string;
        kind?: string;
      }>(token);
      if (payload.kind === 'refresh') {
        throw new UnauthorizedException('Invalid token type');
      }
      return payload.sub;
    } catch (e) {
      if (
        e instanceof UnauthorizedException ||
        e instanceof ConflictException
      ) {
        throw e;
      }
      throw new UnauthorizedException('Invalid or expired session');
    }
  }

  private async applyProfileUpdate(userId: string, dto: UpdateProfileDto) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account unavailable');
    }

    if (dto.firstName !== undefined) {
      user.firstName = dto.firstName.trim();
    }
    if (dto.lastName !== undefined) {
      user.lastName = dto.lastName.trim();
    }
    if (dto.email !== undefined) {
      const email = dto.email.trim().toLowerCase();
      if (email !== user.email) {
        const other = await this.users.findOne({
          where: { email },
          select: { id: true },
        });
        if (other && other.id !== user.id) {
          throw new ConflictException('That email is already in use');
        }
        user.email = email;
      }
    }

    await this.users.save(user);
    return { user: this.publicUser(user) };
  }

  private assertBase64PayloadWithinBytes(
    payload: string,
    maxBytes: number,
    errorMessage: string,
  ) {
    const normalized = payload.trim();
    const bytes = Buffer.byteLength(normalized, 'base64');
    if (bytes > maxBytes) {
      throw new BadRequestException(errorMessage);
    }
  }
}
