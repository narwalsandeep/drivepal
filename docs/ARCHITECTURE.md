# Architecture (DRIVEPAL monorepo)

This document summarizes layout, contracts, and quality practices. Detailed editing rules live under **`.cursor/rules/`** (apply in Cursor).

## Layout

| Area | Path | Stack |
|------|------|--------|
| API | `api/` | NestJS 11, TypeORM, Postgres, JWT, class-validator |
| Web UI | `ui/` | Angular 19 standalone, Tailwind CSS v4, `proxy.conf.json` → `/api` |
| Mobile | `app/` | Flutter, `go_router`, `http`, shared theme in `lib/theme/` |

## Auth model (product)

- **Users** may be **customer (rider)**, **driver**, or **both** (`isCustomer` / `isDriver`).
- **Sign up** can extend an existing account (same email + phone + password) to add the other role after OTP.
- **Login** accepts `loginAs: customer | driver` (Flutter); web admin uses **`ADMIN_EMAIL`** + `/api/auth/admin/login*`.
- **OTP** is **email-only**; configure **`MAIL_*`** and **`JWT_SECRET`**.

## API conventions

- Feature module: `api/src/auth/` (controller, service, DTOs, entities, crypto, utils).
- **DTOs** validate inputs; **global `ValidationPipe`** (`whitelist`, `forbidNonWhitelisted`) in `main.ts`.
- **Schema**: `TYPEORM_SYNC` is for **dev/bootstrap** only (`.env.example`). Production should use **migrations**, not sync.
- **Pure helpers** (e.g. `mask-email`, `resolve-app-login-role`) stay in `utils/` with unit tests.

## Builds and CI

- **`npm run build`** in `api/` runs **`npm test`** first (`prebuild`), then `nest build`.
- **`npm run build`** in `ui/` runs **Karma headless** first (`prebuild`), then `ng build`.
- **Root shortcuts:** `npm run build:api`, `npm run build:ui`, `npm run build:app` (Flutter: test then `apk`).
- **Docker default (`docker-compose.yml`):** API runs **`nest start --watch`**, UI runs **`ng serve`** with bind mounts — hot reload without rebuilding images. **`docker-compose.prod.yml`** uses **`nest build` + `ng build`** and nginx for static UI (CI / prod-style).

## Testing commands

```bash
npm run test:api    # repo root
npm run test:ui
npm run test:app
```


- **Angular**: HTTP only via `AuthApiService` and similar services; routes lazy-load feature components.
- **Flutter**: API client in `lib/services/auth_api.dart`; prefer `Theme.of(context)` and centralized theme.
