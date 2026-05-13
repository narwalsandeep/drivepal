# Contributing

Thanks for helping improve DRIVEPAL.

## Development Setup

Use Docker for API + UI development:

```bash
cp .env.example .env
docker compose up --build
```

Flutter setup:

```bash
cd app
flutter pub get
flutter run
```

## Quality Gates

Run the relevant checks before opening a pull request:

```bash
npm run test:api
npm run test:ui
npm run test:app
```

For release-facing API/UI changes:

```bash
npm run build:api
npm run build:ui
```

For Flutter release builds:

```bash
npm run build:app
```

## Pull Request Guidelines

- Keep changes focused and explain the product reason.
- Add or update tests for new behavior and bug fixes.
- Preserve public API contracts unless the PR clearly documents a breaking change.
- Do not commit secrets, local `.env` files, generated build output, or private credentials.
- Keep UI changes aligned with the shared DRIVEPAL design tokens and components.
- For pricing changes, prefer env-based fare tuning over hardcoding values in feature code.

## Pricing / Fare Changes

DRIVEPAL uses a centralized fare engine in the API:

- Algorithm: `api/src/bookings/bookings.service.ts`
- Car per-km base rates: `api/src/bookings/constants/car-options.constant.ts`
- Env knobs: `FARE_BASE_GBP`, `FARE_PER_KM_MULTIPLIER`, `FARE_PER_MINUTE_GBP`, `FARE_MIN_GBP`, `FARE_SCHEDULED_SURCHARGE_GBP`, `FARE_SURGE_MULTIPLIER`

When submitting fare PRs:

1. Document expected customer-facing pricing behavior in the PR summary.
2. Update `.env.example` / `api/.env.example` if adding new knobs.
3. Add or update API tests for fare outcomes.

## Architecture

Read `docs/ARCHITECTURE.md` before making cross-cutting changes.
