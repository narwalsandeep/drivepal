export interface StripeSetupIntent {
  client_secret: string | null;
}

export interface StripeEphemeralKey {
  secret: string | null;
}

export interface StripeCustomer {
  id: string;
  deleted?: boolean;
  invoice_settings?: {
    default_payment_method?: string | null;
  };
}

export interface StripeCardDetails {
  brand: string;
  last4: string;
  exp_month: number;
  exp_year: number;
  funding?: string | null;
  country?: string | null;
}

export interface StripePaymentMethod {
  id: string;
  card?: StripeCardDetails;
}

export interface StripePaymentMethodList {
  data: StripePaymentMethod[];
}

export interface StripeCheckoutSession {
  url: string | null;
}

export interface StripePaymentIntent {
  id: string;
  status: string;
  amount: number;
  amount_received?: number | null;
}

export interface StripeRefund {
  id: string;
  status: string;
}

export interface StripeClient {
  setupIntents: {
    create(input: {
      customer: string;
      usage: 'off_session';
      automatic_payment_methods: { enabled: true };
      metadata: Record<string, string>;
    }): Promise<StripeSetupIntent>;
  };
  ephemeralKeys: {
    create(
      input: { customer: string },
      options: { apiVersion: string },
    ): Promise<StripeEphemeralKey>;
  };
  paymentMethods: {
    list(input: {
      customer: string;
      type: 'card';
    }): Promise<StripePaymentMethodList>;
    detach(paymentMethodId: string): Promise<unknown>;
  };
  customers: {
    create(input: {
      email: string;
      name: string;
      metadata: Record<string, string>;
    }): Promise<StripeCustomer>;
    retrieve(customerId: string): Promise<StripeCustomer>;
  };
  checkout: {
    sessions: {
      create(input: {
        mode: 'setup';
        customer: string;
        success_url: string;
        cancel_url: string;
        payment_method_types: ['card'];
        metadata: Record<string, string>;
      }): Promise<StripeCheckoutSession>;
    };
  };
  paymentIntents: {
    create(input: {
      amount: number;
      currency: string;
      customer: string;
      payment_method: string;
      confirm: true;
      off_session: true;
      description?: string;
      metadata?: Record<string, string>;
    }): Promise<StripePaymentIntent>;
  };
  refunds: {
    create(input: {
      payment_intent: string;
      metadata?: Record<string, string>;
    }): Promise<StripeRefund>;
  };
}
