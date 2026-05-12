# DRIVEPAL

[![CI](https://github.com/<owner>/<repo>/actions/workflows/ci.yml/badge.svg)](https://github.com/<owner>/<repo>/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![API coverage >=90%](https://img.shields.io/badge/API%20coverage-%E2%89%A590%25-brightgreen?logo=jest)
![UI coverage >=90%](https://img.shields.io/badge/UI%20coverage-%E2%89%A590%25-brightgreen?logo=angular)
![Flutter coverage >=90%](https://img.shields.io/badge/Flutter%20coverage-%E2%89%A590%25-brightgreen?logo=flutter)
![Docker ready](https://img.shields.io/badge/docker-ready-2496ED?logo=docker&logoColor=white)
![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

DRIVEPAL is an open-source ride-booking platform in one repository: a NestJS API, Angular web UI, and Flutter customer/driver app. It is built to demonstrate production-grade patterns for authentication, bookings, maps, payments, driver workflows, notifications, Docker, and CI coverage gates.

Replace `<owner>/<repo>` in the badge URLs after publishing this repository to GitHub.

## Contents

- [Highlights](#highlights)
- [Stack](#stack)
- [Feature List](#feature-list)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Testing and Coverage](#testing-and-coverage)
- [Open Source Health](#open-source-health)
- [Documentation](#documentation)

## Highlights

- Single monorepo for backend, web, and mobile.
- Docker Compose development stack with Postgres, pgAdmin, API, and web UI.
- Strict CI workflow with API, Angular, and Flutter coverage gates.
- Cross-platform customer and driver flows.
- Stripe card setup and booking charge flow.
- Google Maps route preview and Directions API proxying.
- Driver cars, request matching, scheduled rides, and earnings.

## Stack

![NestJS](https://img.shields.io/badge/NestJS-E0234E?logo=nestjs&logoColor=white)
![Angular](https://img.shields.io/badge/Angular-DD0031?logo=angular&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)
![Stripe](https://img.shields.io/badge/Stripe-635BFF?logo=stripe&logoColor=white)
![Google Maps](https://img.shields.io/badge/Google_Maps-4285F4?logo=googlemaps&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)

| Area | Path | Main Technologies |
| --- | --- | --- |
| API | `api/` | NestJS, TypeORM, PostgreSQL, JWT, Stripe, Nodemailer |
| Web UI | `ui/` | Angular, Karma, Tailwind/PostCSS |
| App | `app/` | Flutter, Provider, go_router, Google Maps, Stripe |
| DevOps | `docker/`, `.github/` | Docker Compose, GitHub Actions, coverage gates |

## Feature List

### Authentication and Accounts

- Email OTP signup and login.
- Email or mobile login identifier.
- Password reset by email link.
- JWT access control.
- Customer and driver roles on the same user account.
- Driver onboarding/profile completion checks.
- Profile update, profile image, password change, and logout confirmation.

### Customer Booking

- Map-backed multi-step booking flow.
- Pickup and drop-off search/reverse geocoding.
- Current-location pickup support with permission and accuracy handling.
- Google Directions route preview with real road paths.
- API-driven car options with per-km GBP pricing.
- Fare estimate before booking.
- Saved card selection at checkout.
- Confirm-and-pay modal before finishing booking.
- Background Stripe charge with non-dismissible progress state.
- Payment retry/error handling.
- Booking reset after successful request.

### Scheduled Rides

- Customer can request now or schedule 10, 20, 30, 60, or 120 minutes ahead.
- Scheduled requests are visible to drivers immediately.
- Driver request card clearly labels scheduled pickup time.
- API sends driver alert/email 10 minutes before scheduled pickup.

### Trips and Cancellations

- Customer trip history.
- Driver trip history.
- Driver lifecycle: accept, pick up, finish.
- Driver can release an assigned trip back to the requested pool.
- Customer reassignment flow for assigned trips.
- Completed and cancelled trip status styling.

### Driver Operations

- Driver "New Trip" screen with map background and route.
- One active driver trip at a time.
- Driver cars module with one active car.
- Request filtering by driver's active car type.
- Driver account/profile tab.
- Driver alerts and chat placeholder.

### Payments and Earnings

- Stripe setup for saved cards.
- Card listing and removal with confirmation.
- Off-session ride charge.
- Payment attempt logging and refund fallback.
- Driver earning record calculated only after completed trips.
- Driver "My Earning" page with total and per-trip details.
- Current driver earning share: 10% of charged ride amount.

### Alerts and Notifications

- API-backed alerts screen.
- Unread alert filtering and badge states.
- Individual mark-as-read.
- Background unread polling.
- Trip acceptance, reassignment, scheduled reminder, started, completed alerts.

### Admin and Infrastructure

- Angular web UI shell.
- Postgres and pgAdmin in Docker Compose.
- API health endpoint.
- TypeORM migrations.
- Production-style Docker stack with compiled API and static Angular UI.

## Repository Structure

```text
.
|- api/                       # NestJS API
|- app/                       # Flutter customer/driver app
|- ui/                        # Angular web UI
|- docker/                    # Dockerfiles and entrypoints
|- docs/                      # Architecture notes
|- scripts/                   # Utility scripts, including coverage threshold check
|- .github/workflows/         # GitHub Actions CI
|- .github/ISSUE_TEMPLATE/    # Issue templates
|- README.md                  # Project landing page
|- CONTRIBUTING.md            # Contribution guide
|- SECURITY.md                # Vulnerability reporting policy
|- CODE_OF_CONDUCT.md         # Community standards
|- CHANGELOG.md               # Release notes
|- LICENSE                    # MIT license
```

## Quick Start

### Docker Development Stack

Prerequisites:

- Git
- Docker
- Docker Compose v2

```bash
cp .env.example .env
docker compose up --build
```

Default local services:

| Service | URL |
| --- | --- |
| Angular web UI | `http://localhost:4200` |
| Nest API | `http://localhost:3000/api` |
| API health | `http://localhost:3000/api/health` |
| pgAdmin | `http://localhost:5050` |
| Postgres | `localhost:5432` |

Stop the stack:

```bash
docker compose down
```

### Production-Style Local Stack

```bash
cp .env.example .env
docker compose -f docker-compose.prod.yml up -d --build
```

The production-style stack compiles the API and serves Angular as static assets through nginx.

### Flutter App (run outside Docker)

API and Angular UI run in Docker. Run Flutter directly from `app/`:

```bash
cd app
flutter pub get
flutter run
```

Useful root scripts:

| Command | Purpose |
| --- | --- |
| `npm run dev:db` | Start Postgres only |
| `npm run test:api` | API tests |
| `npm run test:ui` | Angular tests |
| `npm run test:app` | Flutter tests |
| `npm run build:api` | API tests + build |
| `npm run build:ui` | UI tests + build |
| `npm run build:app` | Flutter tests + APK build |

## Configuration

Copy environment examples:

```bash
cp .env.example .env
```

Important settings:

| Group | Variables |
| --- | --- |
| Database | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DATABASE_URL` |
| Auth | `JWT_SECRET`, `DEFAULT_PHONE_REGION` |
| Mail | `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`, `MAIL_NAME` |
| Stripe | `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY` |
| Maps | `GOOGLE_MAPS_API_KEY` |
| TypeORM | `TYPEORM_SYNC`, `TYPEORM_MIGRATIONS_RUN` |
| Ports | `POSTGRES_PORT`, `PGADMIN_PORT`, `API_PORT`, `UI_PORT` |

Notes:

- Use strong secrets outside local development.
- `TYPEORM_SYNC=true` is only for local bootstrap. Use migrations for shared environments.
- Flutter Android emulator usually reaches Docker API via `http://10.0.2.2:3000`.
- Stripe and Google Maps features require valid keys.

## Testing and Coverage

Run tests locally:

```bash
npm run test:api
npm run test:ui
npm run test:app
```

Generate coverage:

```bash
npm run test:cov --prefix api
npm run test --prefix ui -- --watch=false --browsers=ChromeHeadless --code-coverage
flutter test --directory app --coverage
```

CI enforces the project quality bar:

| Area | Coverage file | Minimum |
| --- | --- | --- |
| API | `api/coverage/lcov.info` | 90% lines |
| UI | `ui/coverage/ui/lcov.info` | 90% lines |
| Flutter | `app/coverage/lcov.info` | 90% lines |

The gate is implemented by:

- `.github/workflows/ci.yml`
- `scripts/check-lcov-threshold.sh`
- `ui/karma.conf.js`

Coverage reports are uploaded as GitHub Actions artifacts. For a live public coverage badge/history, connect Codecov or Coveralls and upload the same LCOV files.

## Open Source Health

This repo includes the files GitHub users expect on public projects:

- [MIT License](LICENSE)
- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Changelog](CHANGELOG.md)
- Pull request template: `.github/pull_request_template.md`
- Bug and feature issue templates: `.github/ISSUE_TEMPLATE/`
- CI workflow: `.github/workflows/ci.yml`

Recommended GitHub settings after publishing:

1. Replace `<owner>/<repo>` in the CI badge URL.
2. Enable branch protection on `main`.
3. Require the `CI` status check before merge.
4. Require pull request review before merge.
5. Enable Dependabot alerts and secret scanning.
6. Connect Codecov/Coveralls if you want live coverage trend badges.
7. Add screenshots or a demo video under `docs/` or `.github/assets/` and link them from this README.

## Documentation

- Architecture: `docs/ARCHITECTURE.md`
- Flutter runtime notes: `app/README.md`
- Contribution workflow: `CONTRIBUTING.md`
- Security reporting: `SECURITY.md`

## Known Development Notes

- The product currently assumes UK phone normalization (`DEFAULT_PHONE_REGION=GB`).
- Docker development uses bind mounts and named `node_modules` volumes.
- If Docker dependencies get stale, recreate the node module volumes:

```bash
docker compose down
docker volume rm drivepal_api_node_modules drivepal_ui_node_modules 2>/dev/null || true
docker compose up --build
```

## License

DRIVEPAL is released under the [MIT License](LICENSE).
