import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AuthService } from './auth.service';
import { User } from './entities/user.entity';
import { RegistrationIntent } from './entities/registration-intent.entity';
import { LoginChallenge } from './entities/login-challenge.entity';
import { PasswordResetToken } from './entities/password-reset-token.entity';
import { MailService } from './services/mail.service';
import { UserStatus } from './enums/user-status.enum';

describe('AuthService', () => {
  let service: AuthService;
  let users: { findOne: jest.Mock; save: jest.Mock };
  let jwt: { signAsync: jest.Mock; verifyAsync: jest.Mock };
  let mail: {
    sendPasswordResetLink: jest.Mock;
    sendPasswordChanged: jest.Mock;
    sendDriverDocumentPendingApproval: jest.Mock;
  };

  beforeEach(async () => {
    users = { findOne: jest.fn(), save: jest.fn() };
    jwt = {
      signAsync: jest.fn().mockResolvedValue('jwt'),
      verifyAsync: jest.fn().mockResolvedValue({ sub: 'user-1' }),
    };
    mail = {
      sendPasswordResetLink: jest.fn(),
      sendPasswordChanged: jest.fn(),
      sendDriverDocumentPendingApproval: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: users },
        {
          provide: getRepositoryToken(RegistrationIntent),
          useValue: {
            findOne: jest.fn(),
            save: jest.fn(),
            remove: jest.fn(),
            delete: jest.fn(),
            create: jest.fn(),
            createQueryBuilder: jest.fn(() => ({
              delete: jest.fn().mockReturnThis(),
              where: jest.fn().mockReturnThis(),
              execute: jest.fn().mockResolvedValue(undefined),
            })),
          },
        },
        {
          provide: getRepositoryToken(LoginChallenge),
          useValue: {
            delete: jest.fn(),
            save: jest.fn(),
            findOne: jest.fn(),
            remove: jest.fn(),
            create: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(PasswordResetToken),
          useValue: {
            update: jest.fn(),
            save: jest.fn(),
            findOne: jest.fn(),
            create: jest.fn(),
          },
        },
        {
          provide: JwtService,
          useValue: jwt,
        },
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn(() => 'test-otp-secret-min-32-chars-long!!'),
            get: jest.fn((key: string) => {
              if (key === 'DEFAULT_PHONE_REGION') return 'GB';
              if (key === 'FRONTEND_WEB_URL') return 'http://localhost:4200';
              if (key === 'ADMIN_EMAIL') return 'team@switchcodes.com';
              return undefined;
            }),
          },
        },
        {
          provide: MailService,
          useValue: mail,
        },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  it('forgotPassword returns generic message when user does not exist', async () => {
    users.findOne.mockResolvedValue(null);

    const res = await service.forgotPassword({
      email: 'missing@example.com',
    });

    expect(res.message).toContain('If an account exists');
  });

  it('changes password for authenticated user', async () => {
    const passwordHash = await bcrypt.hash('OldPassword123', 4);
    users.findOne.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      status: UserStatus.ACTIVE,
      passwordHash,
    });

    await service.changeAuthenticatedPassword('Bearer token', {
      currentPassword: 'OldPassword123',
      newPassword: 'NewPassword456',
    });

    expect(users.save).toHaveBeenCalled();
    const saveCalls = users.save.mock.calls as Array<
      [{ passwordHash: string }]
    >;
    const saved = saveCalls[0][0];
    expect(await bcrypt.compare('NewPassword456', saved.passwordHash)).toBe(
      true,
    );
  });

  it('rejects invalid current password', async () => {
    const passwordHash = await bcrypt.hash('OldPassword123', 4);
    users.findOne.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      status: UserStatus.ACTIVE,
      passwordHash,
    });

    await expect(
      service.changeAuthenticatedPassword('Bearer token', {
        currentPassword: 'WrongPassword123',
        newPassword: 'NewPassword456',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects using same new password', async () => {
    const passwordHash = await bcrypt.hash('SamePassword123', 4);
    users.findOne.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      status: UserStatus.ACTIVE,
      passwordHash,
    });

    await expect(
      service.changeAuthenticatedPassword('Bearer token', {
        currentPassword: 'SamePassword123',
        newPassword: 'SamePassword123',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('sets driver document status to pending and emails admin on document update', async () => {
    users.findOne.mockResolvedValueOnce({
      id: 'user-1',
      email: 'driver@example.com',
      firstName: 'Sam',
      lastName: 'Driver',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfilePhotoBase64: 'oldphoto',
      driverDlImageBase64: 'olddl',
      driverDocumentStatus: 'approved',
    });
    users.save.mockImplementation(async (input: Record<string, unknown>) => input);

    await service.updateAuthenticatedDriverProfile('Bearer token', {
      driverProfilePhotoBase64: 'bmV3LXByb2ZpbGU=',
      driverAddress: '10 Driver Lane',
      driverLocationText: 'London',
      driverAge: 31,
      driverGender: 'male',
      driverVisaStatus: 'Citizen',
      driverDlImageBase64: 'bmV3LWRs',
    });

    expect(users.save).toHaveBeenCalledWith(
      expect.objectContaining({
        driverProfileCompleted: true,
        driverDocumentStatus: 'pending',
        driverDocumentReviewedAt: null,
      }),
    );
    expect(mail.sendDriverDocumentPendingApproval).toHaveBeenCalled();
  });
});
