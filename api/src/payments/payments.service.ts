import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { STRIPE_CLIENT } from './stripe-client.provider';
import { PaymentAttempt } from './entities/payment-attempt.entity';
import { PaymentCard } from './entities/payment-card.entity';
import {
  ChargeBookingPaymentDto,
  ChargeBookingPaymentResult,
} from './dto/charge-booking-payment.dto';
import { PaymentAttemptStatus } from './enums/payment-attempt-status.enum';
import type { StripeClient, StripePaymentMethod } from './stripe-client.types';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(User)
    private readonly users: Repository<User>,
    @InjectRepository(PaymentCard)
    private readonly cards: Repository<PaymentCard>,
    @InjectRepository(PaymentAttempt)
    private readonly paymentAttempts: Repository<PaymentAttempt>,
    private readonly auth: AuthService,
    private readonly config: ConfigService,
    @Inject(STRIPE_CLIENT) private readonly stripe: StripeClient,
  ) {}

  async listCards(authorizationHeader: string | undefined) {
    const user = await this.getAuthenticatedCustomer(authorizationHeader);
    const rows = await this.cards.find({
      where: { userId: user.id },
      order: { isDefault: 'DESC', createdAt: 'DESC' },
    });
    return { cards: rows.map((row) => this.toCardResponse(row)) };
  }

  async createSetupIntent(authorizationHeader: string | undefined) {
    try {
      const user = await this.getAuthenticatedCustomer(authorizationHeader);
      const customerId = await this.ensureStripeCustomerId(user);

      const setupIntent = await this.stripe.setupIntents.create({
        customer: customerId,
        usage: 'off_session',
        automatic_payment_methods: { enabled: true },
        metadata: {
          app_user_id: user.id,
          app_flow: 'wallet_add_card',
        },
      });
      const ephemeralKey = await this.stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2026-04-22.dahlia' },
      );

      return {
        setupIntentClientSecret: setupIntent.client_secret,
        customerId,
        customerEphemeralKeySecret: ephemeralKey.secret,
        publishableKey:
          this.config.get<string>('STRIPE_PUBLISHABLE_KEY')?.trim() ?? '',
      };
    } catch (error) {
      this.rethrowStripeError(error);
    }
  }

  async createWebSetupSession(
    authorizationHeader: string | undefined,
    returnUrl: string,
  ) {
    try {
      const user = await this.getAuthenticatedCustomer(authorizationHeader);
      const customerId = await this.ensureStripeCustomerId(user);
      const parsed = this.parseAllowedWebReturnUrl(returnUrl);
      const successUrl = this.withStripeWebStatus(parsed, 'success', true);
      const cancelUrl = this.withStripeWebStatus(parsed, 'cancelled', false);

      const session = await this.stripe.checkout.sessions.create({
        mode: 'setup',
        customer: customerId,
        success_url: successUrl,
        cancel_url: cancelUrl,
        payment_method_types: ['card'],
        metadata: {
          app_user_id: user.id,
          app_flow: 'wallet_add_card_web',
        },
      });
      if (!session.url) {
        throw new BadRequestException('Stripe did not return checkout URL.');
      }
      return { url: session.url };
    } catch (error) {
      this.rethrowStripeError(error);
    }
  }

  async syncCards(authorizationHeader: string | undefined) {
    try {
      const user = await this.getAuthenticatedCustomer(authorizationHeader);
      const customerId = await this.ensureStripeCustomerId(user);

      const [methodsResponse, customer] = await Promise.all([
        this.stripe.paymentMethods.list({
          customer: customerId,
          type: 'card',
        }),
        this.stripe.customers.retrieve(customerId),
      ]);

      const defaultPaymentMethodId =
        customer.deleted || !customer.invoice_settings?.default_payment_method
          ? null
          : customer.invoice_settings.default_payment_method.toString();

      const byStripeId = new Map<string, StripePaymentMethod>();
      for (const method of methodsResponse.data) {
        if (!method.card) {
          continue;
        }
        byStripeId.set(method.id, method);
        const existing = await this.cards.findOne({
          where: { stripePaymentMethodId: method.id },
        });
        const row =
          existing ??
          this.cards.create({
            userId: user.id,
            stripePaymentMethodId: method.id,
            brand: method.card.brand,
            last4: method.card.last4,
            expMonth: method.card.exp_month,
            expYear: method.card.exp_year,
            funding: method.card.funding ?? null,
            country: method.card.country ?? null,
            isDefault: false,
          });
        row.userId = user.id;
        row.brand = method.card.brand;
        row.last4 = method.card.last4;
        row.expMonth = method.card.exp_month;
        row.expYear = method.card.exp_year;
        row.funding = method.card.funding ?? null;
        row.country = method.card.country ?? null;
        row.isDefault = method.id === defaultPaymentMethodId;
        await this.cards.save(row);
      }

      const existingRows = await this.cards.find({
        where: { userId: user.id },
      });
      for (const row of existingRows) {
        if (!byStripeId.has(row.stripePaymentMethodId)) {
          await this.cards.delete({ id: row.id });
        }
      }

      return this.listCards(authorizationHeader);
    } catch (error) {
      this.rethrowStripeError(error);
    }
  }

  async chargeSavedCardForBooking(
    input: ChargeBookingPaymentDto,
  ): Promise<ChargeBookingPaymentResult> {
    if (input.amountMinor <= 0) {
      throw new BadRequestException('Charge amount must be greater than zero.');
    }
    const normalizedCurrency = input.currencyCode.trim().toLowerCase();
    if (!normalizedCurrency) {
      throw new BadRequestException('Currency code is required.');
    }
    const user = await this.users.findOne({ where: { id: input.userId } });
    if (!user || user.status !== UserStatus.ACTIVE || !user.isCustomer) {
      throw new UnauthorizedException('Customer account unavailable');
    }
    const card = await this.cards.findOne({
      where: { id: input.paymentCardId, userId: input.userId },
    });
    if (!card) {
      throw new NotFoundException('Selected payment card was not found');
    }
    const customerId = await this.ensureStripeCustomerId(user);
    const attempt = this.paymentAttempts.create({
      userId: input.userId,
      bookingId: null,
      paymentCardId: card.id,
      stripePaymentMethodId: card.stripePaymentMethodId,
      stripePaymentIntentId: null,
      amountMinor: input.amountMinor,
      capturedAmountMinor: null,
      currencyCode: normalizedCurrency.toUpperCase(),
      status: PaymentAttemptStatus.PENDING,
      errorCode: null,
      errorMessage: null,
    });
    const savedAttempt = await this.paymentAttempts.save(attempt);
    try {
      const intent = await this.stripe.paymentIntents.create({
        amount: input.amountMinor,
        currency: normalizedCurrency,
        customer: customerId,
        payment_method: card.stripePaymentMethodId,
        confirm: true,
        off_session: true,
        description: input.bookingDescription,
        metadata: {
          app_user_id: input.userId,
          payment_attempt_id: savedAttempt.id,
          payment_card_id: card.id,
          ...input.metadata,
        },
      });
      if (intent.status !== 'succeeded') {
        throw new BadRequestException('Payment was not completed.');
      }
      savedAttempt.status = PaymentAttemptStatus.SUCCEEDED;
      savedAttempt.stripePaymentIntentId = intent.id;
      savedAttempt.capturedAmountMinor =
        intent.amount_received ?? intent.amount ?? input.amountMinor;
      savedAttempt.errorCode = null;
      savedAttempt.errorMessage = null;
      await this.paymentAttempts.save(savedAttempt);
      return {
        attemptId: savedAttempt.id,
        stripePaymentIntentId: intent.id,
        paymentCard: card,
        chargedAmountMinor:
          savedAttempt.capturedAmountMinor ?? input.amountMinor,
        currencyCode: savedAttempt.currencyCode,
      };
    } catch (error) {
      const errorInfo = this.parseStripePaymentError(error);
      savedAttempt.status = PaymentAttemptStatus.FAILED;
      savedAttempt.errorCode = errorInfo.code;
      savedAttempt.errorMessage = errorInfo.message;
      await this.paymentAttempts.save(savedAttempt);
      throw new BadRequestException(errorInfo.message);
    }
  }

  async attachPaymentAttemptToBooking(
    paymentAttemptId: string,
    bookingId: string,
  ): Promise<void> {
    const attempt = await this.paymentAttempts.findOne({
      where: { id: paymentAttemptId },
    });
    if (!attempt) {
      return;
    }
    attempt.bookingId = bookingId;
    await this.paymentAttempts.save(attempt);
  }

  async refundBookingCharge(
    paymentAttemptId: string,
    reason: string,
  ): Promise<void> {
    const attempt = await this.paymentAttempts.findOne({
      where: { id: paymentAttemptId },
    });
    if (
      !attempt ||
      !attempt.stripePaymentIntentId ||
      attempt.status !== PaymentAttemptStatus.SUCCEEDED
    ) {
      return;
    }
    try {
      await this.stripe.refunds.create({
        payment_intent: attempt.stripePaymentIntentId,
        metadata: {
          app_payment_attempt_id: attempt.id,
          refund_reason: reason,
        },
      });
      attempt.status = PaymentAttemptStatus.REFUNDED;
      attempt.errorCode = 'booking_refunded';
      attempt.errorMessage = reason;
      await this.paymentAttempts.save(attempt);
    } catch (error) {
      const info = this.parseStripePaymentError(error);
      attempt.errorCode = info.code;
      attempt.errorMessage = `Refund failed: ${info.message}`;
      await this.paymentAttempts.save(attempt);
    }
  }

  private rethrowStripeError(
    error: unknown,
    options: { allowUnknown?: boolean } = {},
  ): never {
    if (error instanceof Error) {
      if (error.message.includes('Stripe is not configured')) {
        throw new BadRequestException('Stripe payments are not configured.');
      }
      if (!options.allowUnknown) {
        throw new BadRequestException('Stripe payment operation failed.');
      }
      throw error;
    }
    if (!options.allowUnknown) {
      throw new BadRequestException('Stripe payment operation failed.');
    }
    throw new BadRequestException('Could not complete payment card action.');
  }

  private parseStripePaymentError(error: unknown): {
    code: string;
    message: string;
  } {
    if (error instanceof BadRequestException) {
      const response = error.getResponse();
      if (typeof response === 'string') {
        return { code: 'payment_error', message: response };
      }
      if (typeof response === 'object' && response && 'message' in response) {
        const message = (response as { message?: string }).message;
        if (message) {
          return { code: 'payment_error', message };
        }
      }
      return { code: 'payment_error', message: error.message };
    }
    if (error instanceof Error) {
      const raw = error as Error & {
        code?: string;
        raw?: { code?: string; message?: string };
      };
      const code = raw.raw?.code ?? raw.code ?? 'payment_failed';
      const message =
        raw.raw?.message ??
        (raw.message.includes('Stripe is not configured')
          ? 'Payments are not configured right now.'
          : 'Payment could not be completed. Please retry or choose another card.');
      return { code, message };
    }
    return {
      code: 'payment_failed',
      message:
        'Payment could not be completed. Please retry or choose another card.',
    };
  }

  private parseAllowedWebReturnUrl(urlRaw: string): URL {
    try {
      const parsed = new URL(urlRaw);
      if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
        throw new BadRequestException('Invalid return URL protocol.');
      }
      return parsed;
    } catch {
      throw new BadRequestException('Invalid return URL.');
    }
  }

  private withStripeWebStatus(
    baseUrl: URL,
    status: 'success' | 'cancelled',
    includeSessionId: boolean,
  ): string {
    const cloned = new URL(baseUrl.toString());
    cloned.searchParams.set('stripeSetup', status);
    if (includeSessionId) {
      cloned.searchParams.set('stripeSessionId', '{CHECKOUT_SESSION_ID}');
    } else {
      cloned.searchParams.delete('stripeSessionId');
    }
    return cloned.toString();
  }

  async removeCard(authorizationHeader: string | undefined, cardId: string) {
    const user = await this.getAuthenticatedCustomer(authorizationHeader);
    const row = await this.cards.findOne({
      where: { id: cardId, userId: user.id },
    });
    if (!row) {
      throw new NotFoundException('Card not found');
    }

    try {
      await this.stripe.paymentMethods.detach(row.stripePaymentMethodId);
    } catch (error) {
      this.rethrowStripeError(error, { allowUnknown: true });
    }
    await this.cards.delete({ id: row.id, userId: user.id });
    return this.listCards(authorizationHeader);
  }

  private async getAuthenticatedCustomer(
    authorizationHeader: string | undefined,
  ): Promise<User> {
    const userId = await this.auth.getAuthenticatedUserId(authorizationHeader);
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status !== UserStatus.ACTIVE || !user.isCustomer) {
      throw new UnauthorizedException('Customer account unavailable');
    }
    return user;
  }

  private async ensureStripeCustomerId(user: User): Promise<string> {
    if (user.stripeCustomerId && user.stripeCustomerId.trim().length > 0) {
      return user.stripeCustomerId;
    }

    const created = await this.stripe.customers.create({
      email: user.email,
      name: `${user.firstName} ${user.lastName}`.trim(),
      metadata: {
        app_user_id: user.id,
      },
    });
    user.stripeCustomerId = created.id;
    await this.users.save(user);
    return created.id;
  }

  private toCardResponse(row: PaymentCard) {
    return {
      id: row.id,
      brand: row.brand,
      last4: row.last4,
      expMonth: row.expMonth,
      expYear: row.expYear,
      funding: row.funding,
      country: row.country,
      isDefault: row.isDefault,
      maskedNumber: `**** **** **** ${row.last4}`,
    };
  }
}
