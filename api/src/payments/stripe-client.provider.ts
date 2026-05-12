import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';
import { StripeClient } from './stripe-client.types';

export const STRIPE_CLIENT = Symbol('STRIPE_CLIENT');

export const stripeClientProvider = {
  provide: STRIPE_CLIENT,
  inject: [ConfigService],
  useFactory: (config: ConfigService) => {
    const secret = config.get<string>('STRIPE_SECRET_KEY')?.trim();
    if (!secret) {
      const unavailable = () => {
        throw new Error('Stripe is not configured on this API instance.');
      };
      return {
        setupIntents: { create: unavailable },
        ephemeralKeys: { create: unavailable },
        paymentMethods: { list: unavailable, detach: unavailable },
        customers: { create: unavailable, retrieve: unavailable },
        checkout: { sessions: { create: unavailable } },
        paymentIntents: { create: unavailable },
        refunds: { create: unavailable },
      } as unknown as StripeClient;
    }
    const stripe = new Stripe(secret, {
      apiVersion: '2026-04-22.dahlia',
      appInfo: {
        name: 'DRIVEPAL API',
      },
    });
    return stripe as unknown as StripeClient;
  },
};
