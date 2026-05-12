import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  const port = config.get<number>('PORT', 3000);

  const nodeEnv = config.get<string>('NODE_ENV') ?? process.env.NODE_ENV;
  const isProduction = nodeEnv === 'production';
  const corsRelaxed = config.get<string>('CORS_RELAXED') !== 'false';

  /** Flutter web uses a random port; fixed lists miss it unless we reflect Origin. */
  const staticCorsOrigins = [
    'http://localhost:4200',
    'http://127.0.0.1:4200',
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'http://localhost:4201',
    'http://127.0.0.1:4201',
  ];

  const useReflectedOrigin = !isProduction || corsRelaxed;

  /** Before global pipes — avoids edge cases where preflight/options interact with validation. */
  app.enableCors({
    origin: useReflectedOrigin ? true : staticCorsOrigins,
    credentials: false,
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin'],
  });

  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  await app.listen(port, '0.0.0.0');
}
bootstrap();
