import { ForbiddenException } from '@nestjs/common';

/**
 * Chooses customer vs driver for app login after password step.
 * - If `loginAs` is set, the user must already have that profile.
 * - If omitted, prefers customer when both exist (rider-first).
 * - Throws if the requested profile is missing or the user has neither.
 */
export function resolveAppLoginRole(
  user: { isCustomer: boolean; isDriver: boolean },
  requested?: 'customer' | 'driver',
): 'customer' | 'driver' {
  if (requested === 'customer') {
    if (!user.isCustomer) {
      throw new ForbiddenException(
        'Sign up as a rider first, or complete rider registration',
      );
    }
    return 'customer';
  }
  if (requested === 'driver') {
    if (!user.isDriver) {
      throw new ForbiddenException(
        'Sign up as a driver first, or complete driver registration',
      );
    }
    return 'driver';
  }
  if (user.isCustomer) {
    return 'customer';
  }
  if (user.isDriver) {
    return 'driver';
  }
  throw new ForbiddenException('No rider or driver profile on this account');
}
