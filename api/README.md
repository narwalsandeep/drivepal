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

## Migrations

Use migrations for shared environments:

```bash
npm run migration:run
```

Avoid relying on `TYPEORM_SYNC` outside local bootstrap/development.
