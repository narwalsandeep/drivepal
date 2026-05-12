import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { PaymentAttempt } from './entities/payment-attempt.entity';
import { PaymentCard } from './entities/payment-card.entity';
import { PaymentsService } from './payments.service';
import { STRIPE_CLIENT } from './stripe-client.provider';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('PaymentsService', () => {
  let service: PaymentsService;
  let users: MockRepo<User>;
  let cards: MockRepo<PaymentCard>;
  let attempts: MockRepo<PaymentAttempt>;
  let auth: { getAuthenticatedUserId: jest.Mock };
  let stripe: {
    customers: { create: jest.Mock; retrieve: jest.Mock };
    setupIntents: { create: jest.Mock };
    ephemeralKeys: { create: jest.Mock };
    paymentMethods: { list: jest.Mock; detach: jest.Mock };
    paymentIntents: { create: jest.Mock };
    refunds: { create: jest.Mock };
  };

  beforeEach(async () => {
    users = {
      findOne: jest.fn().mockResolvedValue({
        id: 'user-1',
        email: 'u@example.com',
        firstName: 'Ride',
        lastName: 'Customer',
        status: UserStatus.ACTIVE,
        isCustomer: true,
        stripeCustomerId: 'cus_existing',
      }),
      save: jest.fn((input: unknown) => input),
    };
    cards = {
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((input: unknown) => input),
      save: jest.fn((input: unknown) => input),
      delete: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    attempts = {
      create: jest.fn((input: unknown) => input),
      save: jest.fn((input: Record<string, unknown>) => ({
        id: 'attempt-1',
        ...input,
      })),
      findOne: jest.fn().mockResolvedValue(null),
    };
    auth = {
      getAuthenticatedUserId: jest.fn().mockResolvedValue('user-1'),
    };
    stripe = {
      customers: {
        create: jest.fn().mockResolvedValue({ id: 'cus_created' }),
        retrieve: jest.fn().mockResolvedValue({
          id: 'cus_existing',
          deleted: false,
          invoice_settings: { default_payment_method: 'pm_1' },
        }),
      },
      setupIntents: {
        create: jest.fn().mockResolvedValue({ client_secret: 'seti_secret' }),
      },
      ephemeralKeys: {
        create: jest.fn().mockResolvedValue({ secret: 'eph_secret' }),
      },
      paymentMethods: {
        list: jest.fn().mockResolvedValue({
          data: [
            {
              id: 'pm_1',
              card: {
                brand: 'visa',
                last4: '4242',
                exp_month: 12,
                exp_year: 2030,
                funding: 'credit',
                country: 'US',
              },
            },
          ],
        }),
        detach: jest.fn().mockResolvedValue({}),
      },
      paymentIntents: {
        create: jest.fn().mockResolvedValue({
          id: 'pi_1',
          status: 'succeeded',
          amount: 1200,
          amount_received: 1200,
        }),
      },
      refunds: {
        create: jest.fn().mockResolvedValue({
          id: 're_1',
          status: 'succeeded',
        }),
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: getRepositoryToken(User), useValue: users },
        { provide: getRepositoryToken(PaymentCard), useValue: cards },
        { provide: getRepositoryToken(PaymentAttempt), useValue: attempts },
        { provide: AuthService, useValue: auth },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key) =>
              key === 'STRIPE_PUBLISHABLE_KEY' ? 'pk_test' : undefined,
            ),
          },
        },
        { provide: STRIPE_CLIENT, useValue: stripe },
      ],
    }).compile();

    service = moduleRef.get(PaymentsService);
  });

  it('lists saved cards for authenticated customer', async () => {
    cards.find?.mockResolvedValueOnce([
      {
        id: 'card-1',
        userId: 'user-1',
        stripePaymentMethodId: 'pm_1',
        brand: 'visa',
        last4: '4242',
        expMonth: 12,
        expYear: 2030,
        funding: 'credit',
        country: 'US',
        isDefault: true,
      },
    ]);

    const res = await service.listCards('Bearer token');

    expect(auth.getAuthenticatedUserId).toHaveBeenCalledWith('Bearer token');
    expect(res.cards).toEqual([
      expect.objectContaining({
        id: 'card-1',
        maskedNumber: '**** **** **** 4242',
        isDefault: true,
      }),
    ]);
  });

  it('creates setup intent payload for payment sheet', async () => {
    const res = await service.createSetupIntent('Bearer token');

    expect(stripe.setupIntents.create).toHaveBeenCalledWith(
      expect.objectContaining({
        customer: 'cus_existing',
        usage: 'off_session',
      }),
    );
    expect(res).toEqual(
      expect.objectContaining({
        setupIntentClientSecret: 'seti_secret',
        customerId: 'cus_existing',
        customerEphemeralKeySecret: 'eph_secret',
      }),
    );
  });

  it('syncs stripe cards into local store', async () => {
    const res = await service.syncCards('Bearer token');

    expect(stripe.paymentMethods.list).toHaveBeenCalledWith({
      customer: 'cus_existing',
      type: 'card',
    });
    expect(cards.save).toHaveBeenCalled();
    expect(res.cards).toHaveLength(0);
  });

  it('removes card for authenticated customer', async () => {
    cards.findOne?.mockResolvedValueOnce({
      id: 'card-1',
      userId: 'user-1',
      stripePaymentMethodId: 'pm_1',
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
      funding: null,
      country: null,
      isDefault: true,
    });

    await service.removeCard('Bearer token', 'card-1');

    expect(stripe.paymentMethods.detach).toHaveBeenCalledWith('pm_1');
    expect(cards.delete).toHaveBeenCalled();
  });

  it('charges a saved card and records successful attempt', async () => {
    cards.findOne?.mockResolvedValueOnce({
      id: 'card-1',
      userId: 'user-1',
      stripePaymentMethodId: 'pm_1',
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
      funding: null,
      country: null,
      isDefault: true,
    });
    const result = await service.chargeSavedCardForBooking({
      userId: 'user-1',
      paymentCardId: 'card-1',
      amountMinor: 1200,
      currencyCode: 'GBP',
      bookingDescription: 'Ride booking',
      metadata: { flow: 'test' },
    });
    expect(stripe.paymentIntents.create).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 1200,
        currency: 'gbp',
        payment_method: 'pm_1',
        confirm: true,
      }),
    );
    expect(result.attemptId).toBe('attempt-1');
    expect(result.stripePaymentIntentId).toBe('pi_1');
  });

  it('rejects missing customer account', async () => {
    users.findOne?.mockResolvedValueOnce(null);
    await expect(service.listCards('Bearer token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('throws not found when removing unknown card', async () => {
    cards.findOne?.mockResolvedValueOnce(null);
    await expect(
      service.removeCard('Bearer token', 'missing-card'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
