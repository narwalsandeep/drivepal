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
import { RideBooking } from './ride-booking.entity';

@Entity('driver_trip_earnings')
@Index(['driverId', 'createdAt'])
@Index(['bookingId'], { unique: true })
export class DriverTripEarning {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'driver_id' })
  driverId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'driver_id' })
  driver: User;

  @Column({ type: 'uuid', name: 'booking_id' })
  bookingId: string;

  @ManyToOne(() => RideBooking, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'booking_id' })
  booking: RideBooking;

  @Column({ type: 'uuid', name: 'payment_attempt_id', nullable: true })
  paymentAttemptId: string | null;

  @Column({ type: 'int', name: 'gross_amount_minor' })
  grossAmountMinor: number;

  @Column({ type: 'int', name: 'platform_fee_minor' })
  platformFeeMinor: number;

  @Column({ type: 'int', name: 'driver_amount_minor' })
  driverAmountMinor: number;

  @Column({ type: 'int', name: 'driver_share_bps' })
  driverShareBps: number;

  @Column({ type: 'varchar', length: 8, name: 'currency_code' })
  currencyCode: string;

  @Column({ type: 'timestamptz', name: 'calculated_at' })
  calculatedAt: Date;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
