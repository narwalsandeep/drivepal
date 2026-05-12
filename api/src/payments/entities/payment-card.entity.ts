import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity';

@Entity('payment_cards')
@Index(['userId', 'isDefault'])
@Index(['stripePaymentMethodId'], { unique: true })
export class PaymentCard {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'varchar', length: 255, name: 'stripe_payment_method_id' })
  stripePaymentMethodId: string;

  @Column({ type: 'varchar', length: 40 })
  brand: string;

  @Column({ type: 'varchar', length: 8, name: 'last4' })
  last4: string;

  @Column({ type: 'int', name: 'exp_month' })
  expMonth: number;

  @Column({ type: 'int', name: 'exp_year' })
  expYear: number;

  @Column({ type: 'varchar', length: 40, nullable: true })
  funding: string | null;

  @Column({ type: 'varchar', length: 8, nullable: true })
  country: string | null;

  @Column({ type: 'boolean', name: 'is_default', default: false })
  isDefault: boolean;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
