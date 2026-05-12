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
import { BookingStatus } from '../enums/booking-status.enum';

@Entity('ride_bookings')
@Index(['customerId', 'createdAt'])
@Index(['driverId', 'createdAt'])
@Index(['status', 'createdAt'])
@Index(['scheduledFor'])
export class RideBooking {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'customer_id' })
  customerId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'customer_id' })
  customer: User;

  @Column({ type: 'uuid', name: 'driver_id', nullable: true })
  driverId: string | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'driver_id' })
  driver: User | null;

  @Column({
    type: 'enum',
    enum: BookingStatus,
    default: BookingStatus.REQUESTED,
  })
  status: BookingStatus;

  @Column({ type: 'varchar', length: 500, name: 'pickup_address' })
  pickupAddress: string;

  @Column({ type: 'double precision', name: 'pickup_latitude' })
  pickupLatitude: number;

  @Column({ type: 'double precision', name: 'pickup_longitude' })
  pickupLongitude: number;

  @Column({ type: 'varchar', length: 500, name: 'dropoff_address' })
  dropoffAddress: string;

  @Column({ type: 'double precision', name: 'dropoff_latitude' })
  dropoffLatitude: number;

  @Column({ type: 'double precision', name: 'dropoff_longitude' })
  dropoffLongitude: number;

  @Column({ type: 'int', name: 'route_distance_meters', nullable: true })
  routeDistanceMeters: number | null;

  @Column({ type: 'int', name: 'route_duration_seconds', nullable: true })
  routeDurationSeconds: number | null;

  @Column({
    type: 'int',
    name: 'route_duration_in_traffic_seconds',
    nullable: true,
  })
  routeDurationInTrafficSeconds: number | null;

  @Column({ type: 'varchar', length: 80, name: 'car_type_id' })
  carTypeId: string;

  @Column({ type: 'varchar', length: 120, name: 'car_type_title' })
  carTypeTitle: string;

  @Column({ type: 'int', name: 'car_seats' })
  carSeats: number;

  @Column({ type: 'varchar', length: 120, name: 'payment_method_id' })
  paymentMethodId: string;

  @Column({ type: 'varchar', length: 40, name: 'payment_brand' })
  paymentBrand: string;

  @Column({ type: 'varchar', length: 40, name: 'payment_masked_number' })
  paymentMaskedNumber: string;

  @Column({ type: 'timestamptz', name: 'requested_at' })
  requestedAt: Date;

  @Column({ type: 'timestamptz', name: 'scheduled_for', nullable: true })
  scheduledFor: Date | null;

  @Column({
    type: 'timestamptz',
    name: 'scheduled_reminder_sent_at',
    nullable: true,
  })
  scheduledReminderSentAt: Date | null;

  @Column({ type: 'timestamptz', name: 'accepted_at', nullable: true })
  acceptedAt: Date | null;

  @Column({ type: 'timestamptz', name: 'cancelled_at', nullable: true })
  cancelledAt: Date | null;

  @Column({
    type: 'varchar',
    length: 40,
    name: 'cancel_reason_code',
    nullable: true,
  })
  cancelReasonCode: string | null;

  @Column({
    type: 'varchar',
    length: 280,
    name: 'cancel_reason_note',
    nullable: true,
  })
  cancelReasonNote: string | null;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
