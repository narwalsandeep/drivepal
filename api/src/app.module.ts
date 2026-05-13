import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { BookingsModule } from './bookings/bookings.module';
import { validateEnvironment } from './config/env.validation';
import { DriverCarsModule } from './driver-cars/driver-cars.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PaymentsModule } from './payments/payments.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env', '../.env'],
      validate: validateEnvironment,
    }),
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const ttlSeconds = Number.parseInt(
          config.get<string>('API_THROTTLE_TTL_SECONDS') ?? '60',
          10,
        );
        const limit = Number.parseInt(
          config.get<string>('API_THROTTLE_LIMIT') ?? '120',
          10,
        );

        return [{ ttl: ttlSeconds * 1000, limit }];
      },
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        type: 'postgres' as const,
        url:
          config.get<string>('DATABASE_URL') ??
          'postgresql://drivepal:drivepal@127.0.0.1:5432/drivepal',
        autoLoadEntities: true,
        migrations: [__dirname + '/migrations/*{.ts,.js}'],
        migrationsRun: config.get<string>('TYPEORM_MIGRATIONS_RUN') === 'true',
        synchronize: config.get<string>('TYPEORM_SYNC') !== 'false',
        logging: config.get<string>('NODE_ENV') !== 'production',
      }),
      inject: [ConfigService],
    }),
    AuthModule,
    BookingsModule,
    DriverCarsModule,
    NotificationsModule,
    PaymentsModule,
  ],
  controllers: [AppController, HealthController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
