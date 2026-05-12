import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { LoginChallenge } from './entities/login-challenge.entity';
import { PasswordResetToken } from './entities/password-reset-token.entity';
import { RegistrationIntent } from './entities/registration-intent.entity';
import { User } from './entities/user.entity';
import { MailService } from './services/mail.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      RegistrationIntent,
      LoginChallenge,
      PasswordResetToken,
    ]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          issuer: 'drivepal-api',
          audience: 'drivepal-clients',
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, MailService],
  exports: [AuthService, MailService, JwtModule],
})
export class AuthModule {}
