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

@Entity('driver_cars')
@Index(['driverId', 'createdAt'])
@Index(['driverId', 'plateNormalized'], { unique: true })
export class DriverCar {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'driver_id' })
  driverId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'driver_id' })
  driver: User;

  @Column({ type: 'varchar', length: 50, name: 'display_name' })
  displayName: string;

  @Column({ type: 'varchar', length: 60, name: 'manufacturer' })
  manufacturer: string;

  @Column({ type: 'varchar', length: 60, name: 'model' })
  model: string;

  @Column({ type: 'varchar', length: 40, name: 'color' })
  color: string;

  @Column({ type: 'varchar', length: 24, name: 'plate_number' })
  plateNumber: string;

  @Column({ type: 'varchar', length: 24, name: 'plate_normalized' })
  plateNormalized: string;

  @Column({ type: 'int', name: 'seat_capacity' })
  seatCapacity: number;

  @Column({
    type: 'varchar',
    length: 24,
    name: 'car_type_id',
    default: 'sedan4',
  })
  carTypeId: string;

  @Column({ type: 'varchar', length: 24, name: 'transmission' })
  transmission: string;

  @Column({ type: 'boolean', name: 'is_active', default: true })
  isActive: boolean;

  @Column({ type: 'boolean', name: 'accepts_pets', default: false })
  acceptsPets: boolean;

  @Column({ type: 'boolean', name: 'has_air_conditioning', default: true })
  hasAirConditioning: boolean;

  @Column({ type: 'boolean', name: 'has_child_seat', default: false })
  hasChildSeat: boolean;

  @Column({ type: 'boolean', name: 'wheelchair_accessible', default: false })
  wheelchairAccessible: boolean;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
