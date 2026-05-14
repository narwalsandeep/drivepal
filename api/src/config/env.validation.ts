const BOOLEAN_ENV_KEYS = [
  'TYPEORM_SYNC',
  'TYPEORM_MIGRATIONS_RUN',
  'CORS_RELAXED',
  'SECURITY_HEADERS_ENABLED',
  'PUSH_ENABLED',
  'PUSH_WEB_ENABLED',
];
const POSITIVE_INTEGER_ENV_KEYS = [
  'PORT',
  'API_THROTTLE_TTL_SECONDS',
  'API_THROTTLE_LIMIT',
];
const NON_NEGATIVE_NUMBER_ENV_KEYS = [
  'FARE_BASE_GBP',
  'FARE_PER_KM_MULTIPLIER',
  'FARE_PER_MINUTE_GBP',
  'FARE_MIN_GBP',
  'FARE_SCHEDULED_SURCHARGE_GBP',
  'FARE_SURGE_MULTIPLIER',
];

function hasValue(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function asTrimmedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asNumberInput(value: unknown): string | null {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value.toString() : null;
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  return null;
}

export function validateEnvironment(config: Record<string, unknown>) {
  const errors: string[] = [];
  const nodeEnv = asTrimmedString(config.NODE_ENV);
  const isProduction = nodeEnv === 'production';

  for (const key of BOOLEAN_ENV_KEYS) {
    const raw = config[key];
    if (raw == null || raw === '') continue;
    if (raw !== 'true' && raw !== 'false') {
      errors.push(`${key} must be either "true" or "false".`);
    }
  }

  const pushEnabled = config.PUSH_ENABLED === 'true';
  const pushWebEnabled = config.PUSH_WEB_ENABLED === 'true';
  if (pushEnabled) {
    const requiredPushKeys = [
      'AWS_REGION',
      'AWS_ACCESS_KEY_ID',
      'AWS_SECRET_ACCESS_KEY',
      'AWS_SNS_PLATFORM_APPLICATION_ARN_ANDROID',
      'AWS_SNS_PLATFORM_APPLICATION_ARN_IOS',
    ];
    for (const key of requiredPushKeys) {
      if (!hasValue(config[key])) {
        errors.push(`${key} is required when PUSH_ENABLED=true.`);
      }
    }
  }
  if (pushWebEnabled && !hasValue(config.FCM_WEB_SERVICE_ACCOUNT_JSON)) {
    errors.push(
      'FCM_WEB_SERVICE_ACCOUNT_JSON is required when PUSH_WEB_ENABLED=true.',
    );
  }

  for (const key of POSITIVE_INTEGER_ENV_KEYS) {
    const raw = config[key];
    if (raw == null || raw === '') continue;
    const numberInput = asNumberInput(raw);
    if (numberInput == null || numberInput.length === 0) {
      errors.push(`${key} must be a positive integer.`);
      continue;
    }
    const value = Number.parseInt(numberInput, 10);
    if (!Number.isFinite(value) || value <= 0) {
      errors.push(`${key} must be a positive integer.`);
    }
  }

  for (const key of NON_NEGATIVE_NUMBER_ENV_KEYS) {
    const raw = config[key];
    if (raw == null || raw === '') continue;
    const value = Number(raw);
    if (!Number.isFinite(value) || value < 0) {
      errors.push(`${key} must be a non-negative number.`);
    }
  }

  if (isProduction) {
    const requiredInProduction = [
      'DATABASE_URL',
      'JWT_SECRET',
      'STRIPE_SECRET_KEY',
      'STRIPE_PUBLISHABLE_KEY',
    ];
    for (const key of requiredInProduction) {
      if (!hasValue(config[key])) {
        errors.push(`${key} is required when NODE_ENV=production.`);
      }
    }

    if (config.TYPEORM_SYNC === 'true') {
      errors.push('TYPEORM_SYNC=true is not allowed when NODE_ENV=production.');
    }
  }

  if (errors.length > 0) {
    throw new Error(`Environment validation failed:\n- ${errors.join('\n- ')}`);
  }

  return config;
}
