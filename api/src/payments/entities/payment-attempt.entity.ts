import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PaymentAttemptStatus } from '../enums/payment-attempt-status.enum';

@Entity('payment_attempts')
@Index(['userId', 'createdAt'])
@Index(['bookingId'])
@Index(['status', 'createdAt'])
@Index(['stripePaymentIntentId'])
export class PaymentAttempt {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'user_id' })
  userId: string;

  @Column({ type: 'uuid', name: 'booking_id', nullable: true })
  bookingId: string | null;

  @Column({ type: 'uuid', name: 'payment_card_id', nullable: true })
  paymentCardId: string | null;

  @Column({
    type: 'varchar',
    length: 255,
    name: 'stripe_payment_method_id',
    nullable: true,
  })
  stripePaymentMethodId: string | null;

  @Column({
    type: 'varchar',
    length: 255,
    name: 'stripe_payment_intent_id',
    nullable: true,
  })
  stripePaymentIntentId: string | null;

  @Column({ type: 'int', name: 'amount_minor' })
  amountMinor: number;

  @Column({ type: 'varchar', length: 8, name: 'currency_code' })
  currencyCode: string;

  @Column({ type: 'int', name: 'captured_amount_minor', nullable: true })
  capturedAmountMinor: number | null;

  @Column({
    type: 'enum',
    enum: PaymentAttemptStatus,
    default: PaymentAttemptStatus.PENDING,
  })
  status: PaymentAttemptStatus;

  @Column({ type: 'varchar', length: 80, name: 'error_code', nullable: true })
  errorCode: string | null;

  @Column({
    type: 'varchar',
    length: 500,
    name: 'error_message',
    nullable: true,
  })
  errorMessage: string | null;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
