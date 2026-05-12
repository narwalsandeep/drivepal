import { ForbiddenException } from '@nestjs/common';
import { resolveAppLoginRole } from './resolve-app-login-role';

describe('resolveAppLoginRole', () => {
  it('returns customer when requested and user is customer', () => {
    expect(
      resolveAppLoginRole({ isCustomer: true, isDriver: false }, 'customer'),
    ).toBe('customer');
  });

  it('throws when customer requested but user is not customer', () => {
    expect(() =>
      resolveAppLoginRole({ isCustomer: false, isDriver: true }, 'customer'),
    ).toThrow(ForbiddenException);
  });

  it('returns driver when requested and user is driver', () => {
    expect(
      resolveAppLoginRole({ isCustomer: false, isDriver: true }, 'driver'),
    ).toBe('driver');
  });

  it('throws when driver requested but user is not driver', () => {
    expect(() =>
      resolveAppLoginRole({ isCustomer: true, isDriver: false }, 'driver'),
    ).toThrow(ForbiddenException);
  });

  it('when loginAs omitted prefers customer if both roles exist', () => {
    expect(
      resolveAppLoginRole({ isCustomer: true, isDriver: true }, undefined),
    ).toBe('customer');
  });

  it('when loginAs omitted returns driver if only driver', () => {
    expect(
      resolveAppLoginRole({ isCustomer: false, isDriver: true }, undefined),
    ).toBe('driver');
  });

  it('when loginAs omitted throws if neither role', () => {
    expect(() =>
      resolveAppLoginRole({ isCustomer: false, isDriver: false }, undefined),
    ).toThrow(ForbiddenException);
  });
});
