import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('ride_booking_driver_locations')
@Index(['bookingId'], { unique: true })
@Index(['driverId', 'updatedAt'])
export class RideBookingDriverLocation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'booking_id' })
  bookingId: string;

  @Column({ type: 'uuid', name: 'driver_id' })
  driverId: string;

  @Column({ type: 'double precision', name: 'latitude' })
  latitude: number;

  @Column({ type: 'double precision', name: 'longitude' })
  longitude: number;

  @Column({ type: 'double precision', name: 'accuracy_meters', nullable: true })
  accuracyMeters: number | null;

  @Column({ type: 'timestamptz', name: 'recorded_at' })
  recordedAt: Date;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
