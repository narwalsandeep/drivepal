# DRIVEPAL API (`api/`)

NestJS backend for authentication, bookings, trips, payments, driver operations, and alerts.

## Run (Docker-first)

From repository root:

```bash
cp .env.example .env
docker compose up --build
```

API endpoints:

- Base URL: `http://localhost:3000/api`
- Health: `http://localhost:3000/api/health`

## Local package commands

From `api/`:

```bash
npm install
npm run test
npm run test:cov
npm run build
```

`npm run build` executes tests first via `prebuild`.

## Key environment variables

- Auth: `JWT_SECRET`, `DEFAULT_PHONE_REGION`
- Mail: `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`, `MAIL_NAME`, `ADMIN_EMAIL`
- Stripe: `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET`
- Data: `DATABASE_URL`, `TYPEORM_SYNC`, `TYPEORM_MIGRATIONS_RUN`
- Reliability: `SECURITY_HEADERS_ENABLED`, `API_THROTTLE_TTL_SECONDS`, `API_THROTTLE_LIMIT`
- Push: `PUSH_ENABLED`, `PUSH_WEB_ENABLED`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SNS_PLATFORM_APPLICATION_ARN_ANDROID`, `AWS_SNS_PLATFORM_APPLICATION_ARN_IOS`, `FCM_WEB_SERVICE_ACCOUNT_JSON`

## Fare engine

Fare calculation is centralized in `src/bookings/bookings.service.ts`.

Formula:

```text
distanceFare = distanceKm * car.pricePerKmGbp * FARE_PER_KM_MULTIPLIER
timeFare = durationMinutes * FARE_PER_MINUTE_GBP
subtotal = FARE_BASE_GBP + distanceFare + timeFare + scheduledSurcharge
surged = subtotal * FARE_SURGE_MULTIPLIER
finalFare = max(FARE_MIN_GBP, surged)
chargedMinor = round(finalFare * 100)
```

Configurable knobs:

- `FARE_BASE_GBP`
- `FARE_PER_KM_MULTIPLIER`
- `FARE_PER_MINUTE_GBP`
- `FARE_MIN_GBP`
- `FARE_SCHEDULED_SURCHARGE_GBP`
- `FARE_SURGE_MULTIPLIER`

Per-car base distance rates are defined in `src/bookings/constants/car-options.constant.ts`.

## Runtime reliability safeguards

- Security headers: enabled by default via `helmet` (`SECURITY_HEADERS_ENABLED` to disable explicitly).
- Global throttling: controlled by `API_THROTTLE_TTL_SECONDS` and `API_THROTTLE_LIMIT`.
- Environment validation: startup fails fast on invalid env formats, missing production-critical secrets, or `TYPEORM_SYNC=true` in production.

## Push notifications

API push flow:

- Device register/upsert: `POST /api/notifications/devices/register`
- Device deactivate by token: `POST /api/notifications/devices/unregister`
- Device deactivate by id: `DELETE /api/notifications/devices/:deviceId`

Dispatch behavior:

- Notification DB write happens first.
- Push send happens asynchronously and does not block booking writes.
- Mobile routes through SNS endpoint ARNs; web routes through FCM HTTP v1.
- Invalid token/endpoint errors mark device inactive.

## Migrations

Use migrations for shared environments:

```bash
npm run migration:run
```

Avoid relying on `TYPEORM_SYNC` outside local bootstrap/development.
