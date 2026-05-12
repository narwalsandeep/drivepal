import { PaymentCard } from '../entities/payment-card.entity';

export type ChargeBookingPaymentDto = {
  readonly userId: string;
  readonly paymentCardId: string;
  readonly amountMinor: number;
  readonly currencyCode: string;
  readonly bookingDescription: string;
  readonly metadata?: Record<string, string>;
};

export type ChargeBookingPaymentResult = {
  readonly attemptId: string;
  readonly stripePaymentIntentId: string;
  readonly paymentCard: PaymentCard;
  readonly chargedAmountMinor: number;
  readonly currencyCode: string;
};
