# AWS Push Notifications Plan (Mobile + Web)

## Objective

Implement a production-grade push notification system for DRIVEPAL that works across:

- Flutter Android app
- Flutter iOS app
- Flutter Web (Chrome/Edge/Safari support where available)

The system must preserve existing polling behavior as fallback, avoid regressions in booking flows, and be safe for phased rollout.

---

## Product Scope

### In scope (phase rollout)

- Push delivery for rider and driver transactional events.
- Device registration lifecycle (register, refresh, deactivate, logout cleanup).
- Mobile and web token support.
- Deep-link navigation from notification payloads.
- Operational visibility and retry/error handling.

### Out of scope (initial release)

- Marketing/broadcast campaigns.
- Multi-language push localization service.
- Advanced user preference center per notification category (can be added later).

---

## High-Level Architecture

###[Client]
- App/Web obtains push token.
- App/Web calls API to register token and platform.
- App/Web handles foreground/background/tap-open behavior.

###[API]
- Stores token + platform + endpoint metadata.
- Resolves recipients on domain events.
- Publishes push payload.
- Marks invalid endpoints/tokens inactive.

###[AWS]
- Amazon SNS platform applications for Android/iOS.
- FCM web path for browser tokens.
- CloudWatch metrics/alarms for delivery failures.

---

## Delivery Strategy by Platform

- **Android:** SNS -> FCM
- **iOS:** SNS -> APNs
- **Web:** FCM Web Push (service worker + VAPID)

Notes:
- Keep a single domain payload contract for all platforms.
- Use a routing layer in API to dispatch by platform type.
- Polling remains enabled as reliability fallback.

---

## Domain Events to Push

Initial transactional events:

- `trip_requested`
- `trip_accepted`
- `trip_driver_arriving`
- `trip_started`
- `trip_completed`
- `trip_reopened`
- `trip_unassigned`
- `trip_cancelled`
- `trip_schedule_reminder`

Payload shape (contract):

```json
{
  "kind": "trip_accepted",
  "title": "Driver accepted your trip",
  "body": "Your driver is on the way.",
  "bookingId": "uuid",
  "metadata": {
    "screen": "active_trip"
  },
  "sentAt": "ISO-8601"
}
```

---

## Data Model Plan (API)

Create a new entity/table for user push devices, for example `user_push_devices`:

- `id` (uuid)
- `user_id` (uuid, indexed)
- `platform` (`android | ios | web`)
- `device_token` (text)
- `sns_endpoint_arn` (nullable, mobile)
- `is_active` (boolean, default true)
- `last_seen_at` (timestamptz)
- `last_error` (nullable text)
- `app_version` (nullable)
- `device_label` (nullable)
- `created_at`, `updated_at`

Constraints/indexing:

- Unique index on `(platform, device_token)`
- Index on `(user_id, is_active)`

---

## API Contract Plan

### 1) Register/refresh device

- `POST /api/notifications/devices`
- Auth required.
- Body:
  - `platform`
  - `deviceToken`
  - optional `appVersion`, `deviceLabel`

Behavior:
- Upsert token.
- For mobile: create/update SNS endpoint ARN.
- For web: store token for FCM web dispatch path.

### 2) Deactivate device

- `DELETE /api/notifications/devices/:id`
- Auth required.
- Marks inactive and deletes SNS endpoint if present.

### 3) Logout cleanup

- On logout flow, call deactivate endpoint for current device/session token.

---

## AWS Infrastructure Plan

### SNS setup

- Create SNS Platform Applications:
  - `drivepal-android` (FCM credentials)
  - `drivepal-ios` (APNs credentials)

CLI-first bootstrap files in this repository:

- `scripts/aws/bootstrap-sns-push.sh`
- `scripts/aws/push-iam-policy.json`

Example IAM policy attach:

```bash
aws iam put-user-policy \
  --user-name drivepal-push-user \
  --policy-name DrivepalPushPolicy \
  --policy-document file://scripts/aws/push-iam-policy.json
```

Example SNS bootstrap run:

```bash
export AWS_ACCESS_KEY_ID=replace-me
export AWS_SECRET_ACCESS_KEY=replace-me
export AWS_REGION=eu-west-2
export ANDROID_FCM_SERVER_KEY=replace-me
export IOS_APNS_TEAM_ID=replace-me
export IOS_APNS_BUNDLE_ID=replace-me
export IOS_APNS_KEY_ID=replace-me
export IOS_APNS_PRIVATE_KEY_PATH=/absolute/path/AuthKey_XXXXXX.p8

./scripts/aws/bootstrap-sns-push.sh
```

### IAM policy (least privilege)

- `sns:CreatePlatformEndpoint`
- `sns:SetEndpointAttributes`
- `sns:GetEndpointAttributes`
- `sns:DeleteEndpoint`
- `sns:Publish`

### Secrets/config

Store credentials in AWS Secrets Manager or SSM Parameter Store.

Required API env keys (planned):

- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SNS_PLATFORM_APPLICATION_ARN_ANDROID`
- `AWS_SNS_PLATFORM_APPLICATION_ARN_IOS`
- `PUSH_ENABLED`
- `PUSH_WEB_ENABLED`
- `FCM_SERVER_KEY` or equivalent secure FCM web auth source

---

## Flutter App/Web Integration Plan

###[Common]
- Add messaging dependencies (`firebase_core`, `firebase_messaging`).
- Add push coordinator service and attach to authenticated session lifecycle.
- Register token on sign-in/restore.
- Refresh registration on token rotation.
- Deactivate on logout.

###[Android]
- Add notification permission handling for Android 13+.
- Configure Firebase messaging metadata/channels.

###[iOS]
- Enable push capabilities.
- Configure APNs integration.
- Add background remote notification mode where required.

###[Web]
- Configure Firebase web app + service worker (`firebase-messaging-sw.js`).
- Request browser notification permission with graceful UX for denied state.
- Handle foreground messages and click-open routing.

---

## Backend Integration Points in Current Codebase

Primary approach:

- Keep existing in-app notification write path as source-of-truth.
- Extend notification creation flow to also trigger push dispatch asynchronously.

Likely integration points:

- `api/src/notifications/notifications.service.ts`
- `api/src/bookings/bookings.service.ts` event emit points
- new push adapter service under `api/src/notifications/services/`

---

## Rollout Plan

### Phase 0: Preparation
- Infra setup, secrets, feature flags, schema migration.

### Phase 1: API foundation
- Device endpoints, persistence, SNS adapter, no user-visible behavior yet.

### Phase 2: Mobile push
- Android+iOS token registration and message handling.
- Enable for internal testers.

### Phase 3: Web push
- Browser token lifecycle + service worker.
- Progressive rollout in web environments.

### Phase 4: Full production
- Enable for all users.
- Keep polling fallback active.

---

## Reliability and Failure Handling

- If push publish fails, do not fail booking transaction.
- Mark invalid endpoint/token inactive based on provider response.
- Retry transient failures with bounded backoff.
- Use polling as fallback for unread badge and active-trip consistency.

---

## Security Plan

- Never log full push tokens (mask in logs).
- Auth required for all device registration/deactivation endpoints.
- Enforce user ownership on device records.
- Protect credentials in managed secret store.
- Rate limit device registration endpoints.

---

## Observability Plan

Track and alert on:

- total publish attempts
- success/failure rates by platform
- invalid token/endpoint count
- queue latency (if queue introduced)
- registration churn (new, refreshed, deactivated)

Use structured logs with:

- `userId`, `platform`, `kind`, `bookingId`, `messageId`, `result`

---

## Testing Plan

### API
- Unit: token upsert, endpoint create/update/deactivate, routing by platform.
- Integration/e2e: auth + device registration + event-triggered push publish.
- Failure tests: invalid endpoint, provider transient errors.

### Flutter
- Unit/widget: register on sign-in, refresh on token change, logout deactivation.
- Foreground message handling tests.
- Deep-link route tests from payload.

### Manual QA
- Rider/driver real-device checks for each lifecycle event.
- Browser permission denied/allowed behavior.
- Background/opened-from-notification routing.

---

## Definition of Done

- Mobile + web token registration works and is persisted.
- All in-scope trip events publish push on enabled platforms.
- Invalid tokens are deactivated automatically.
- App/web deep-link behavior works for push taps.
- Tests pass (API + Flutter) with added push coverage.
- Docs/config examples updated for open-source setup.

---

## Implementation status in repository

Completed implementation paths:

- API persistence: `api/src/notifications/entities/push-device.entity.ts`
- API migration: `api/src/migrations/1760000013000-CreatePushDevices.ts`
- API transports:
  - `api/src/notifications/push/sns-mobile-push.service.ts`
  - `api/src/notifications/push/fcm-web-push.service.ts`
  - `api/src/notifications/push/push-dispatcher.service.ts`
- API device endpoints:
  - `POST /api/notifications/devices/register`
  - `POST /api/notifications/devices/unregister`
  - `DELETE /api/notifications/devices/:deviceId`
- Event wiring: push dispatch triggered from `NotificationsService.createForUser()` with non-blocking behavior.
- Flutter integration:
  - `app/lib/services/push_notification_manager.dart`
  - `app/lib/services/push_firebase_bootstrap.dart`
  - `app/web/firebase-messaging-sw.js`

---

## Operations runbook

1) Enable push flags and credentials in `.env`.
2) Restart Docker API service (`docker compose up --build`).
3) Start Flutter app with required `--dart-define` Firebase values.
4) Sign in rider/driver to trigger token registration.
5) Verify DB rows in `push_devices` table (`is_active=true`, `last_error=null`).
6) Trigger booking lifecycle event and validate delivery on device/browser.

---

## Troubleshooting quick map

- `PUSH_ENABLED=true` startup failure:
  - Check required env validation keys in `api/src/config/env.validation.ts`.
- Mobile not receiving:
  - Validate SNS platform app ARNs and AWS IAM policy (`scripts/aws/push-iam-policy.json`).
- Web not receiving:
  - Validate `FCM_WEB_SERVICE_ACCOUNT_JSON`, Firebase web config, and VAPID key.
- Device stopped receiving:
  - Inspect `push_devices.last_error`; invalid token/endpoint failures auto-deactivate.
- Booking still succeeds while push fails:
  - Expected behavior; push is intentionally non-blocking and polling remains fallback.

---

## Open Decisions (to confirm before implementation)

1. Use direct publish from `NotificationsService` vs domain-event worker pattern.
2. Web dispatch path exact mechanism (direct FCM server API vs dedicated push worker).
3. Notification preference policy at launch (global on/off vs per-kind categories).

