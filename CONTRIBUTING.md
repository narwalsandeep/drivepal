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

## Architecture

Read `docs/ARCHITECTURE.md` before making cross-cutting changes.
