#!/usr/bin/env bash
set -euo pipefail

# CLI-first SNS mobile push bootstrap.
# Usage:
#   export AWS_REGION=eu-west-2
#   export ANDROID_FCM_SERVER_KEY="..."
#   export IOS_APNS_TEAM_ID="..."
#   export IOS_APNS_BUNDLE_ID="com.example.app"
#   export IOS_APNS_KEY_ID="..."
#   export IOS_APNS_PRIVATE_KEY_PATH="/abs/path/AuthKey_XXXXXX.p8"
#   ./scripts/aws/bootstrap-sns-push.sh

if [[ -z "${AWS_REGION:-}" ]]; then
  echo "AWS_REGION is required."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required."
  exit 1
fi

if [[ -z "${ANDROID_FCM_SERVER_KEY:-}" ]]; then
  echo "ANDROID_FCM_SERVER_KEY is required."
  exit 1
fi

if [[ -z "${IOS_APNS_TEAM_ID:-}" || -z "${IOS_APNS_BUNDLE_ID:-}" || -z "${IOS_APNS_KEY_ID:-}" || -z "${IOS_APNS_PRIVATE_KEY_PATH:-}" ]]; then
  echo "IOS_APNS_TEAM_ID, IOS_APNS_BUNDLE_ID, IOS_APNS_KEY_ID and IOS_APNS_PRIVATE_KEY_PATH are required."
  exit 1
fi

if [[ ! -f "${IOS_APNS_PRIVATE_KEY_PATH}" ]]; then
  echo "APNS key file not found at ${IOS_APNS_PRIVATE_KEY_PATH}"
  exit 1
fi

ANDROID_APP_NAME="${ANDROID_APP_NAME:-drivepal-android}"
IOS_APP_NAME="${IOS_APP_NAME:-drivepal-ios}"

echo "Creating SNS platform application for Android..."
ANDROID_ARN="$(
  aws sns create-platform-application \
    --region "${AWS_REGION}" \
    --name "${ANDROID_APP_NAME}" \
    --platform GCM \
    --attributes "PlatformCredential=${ANDROID_FCM_SERVER_KEY}" \
    --query 'PlatformApplicationArn' \
    --output text
)"

echo "Creating SNS platform application for iOS..."
IOS_ARN="$(
  aws sns create-platform-application \
    --region "${AWS_REGION}" \
    --name "${IOS_APP_NAME}" \
    --platform APNS \
    --attributes "PlatformPrincipal=${IOS_APNS_TEAM_ID},PlatformCredential=file://${IOS_APNS_PRIVATE_KEY_PATH}" \
    --query 'PlatformApplicationArn' \
    --output text
)"

echo ""
echo "SNS setup complete."
echo "AWS_SNS_PLATFORM_APPLICATION_ARN_ANDROID=${ANDROID_ARN}"
echo "AWS_SNS_PLATFORM_APPLICATION_ARN_IOS=${IOS_ARN}"
echo ""
echo "Recommended API env:"
echo "AWS_REGION=${AWS_REGION}"
echo "AWS_SNS_PLATFORM_APPLICATION_ARN_ANDROID=${ANDROID_ARN}"
echo "AWS_SNS_PLATFORM_APPLICATION_ARN_IOS=${IOS_ARN}"
