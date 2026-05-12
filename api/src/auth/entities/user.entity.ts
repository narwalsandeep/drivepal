import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserStatus } from '../enums/user-status.enum';
import { DriverDocumentStatus } from '../enums/driver-document-status.enum';

@Entity('users')
@Index(['email'], { unique: true })
@Index(['phoneE164'], { unique: true })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 320 })
  email: string;

  @Column({ type: 'varchar', length: 20, name: 'phone_e164' })
  phoneE164: string;

  @Column({ type: 'varchar', length: 80, name: 'first_name', default: '' })
  firstName: string;

  @Column({ type: 'varchar', length: 80, name: 'last_name', default: '' })
  lastName: string;

  @Column({
    type: 'varchar',
    length: 120,
    name: 'password_hash',
    select: false,
  })
  passwordHash: string;

  @Column({ type: 'boolean', default: true })
  emailVerified: boolean;

  @Column({ type: 'boolean', default: true })
  phoneVerified: boolean;

  @Column({ type: 'enum', enum: UserStatus, default: UserStatus.ACTIVE })
  status: UserStatus;

  @Column({ type: 'boolean', name: 'is_customer', default: false })
  isCustomer: boolean;

  @Column({ type: 'boolean', name: 'is_driver', default: false })
  isDriver: boolean;

  @Column({
    type: 'boolean',
    name: 'driver_profile_completed',
    default: false,
  })
  driverProfileCompleted: boolean;

  @Column({
    type: 'text',
    name: 'driver_profile_photo_base64',
    nullable: true,
  })
  driverProfilePhotoBase64: string | null;

  @Column({
    type: 'varchar',
    length: 500,
    name: 'driver_address',
    nullable: true,
  })
  driverAddress: string | null;

  @Column({
    type: 'varchar',
    length: 160,
    name: 'driver_location_text',
    nullable: true,
  })
  driverLocationText: string | null;

  @Column({ type: 'int', name: 'driver_age', nullable: true })
  driverAge: number | null;

  @Column({
    type: 'varchar',
    length: 32,
    name: 'driver_gender',
    nullable: true,
  })
  driverGender: string | null;

  @Column({
    type: 'varchar',
    length: 120,
    name: 'driver_visa_status',
    nullable: true,
  })
  driverVisaStatus: string | null;

  @Column({ type: 'text', name: 'driver_dl_image_base64', nullable: true })
  driverDlImageBase64: string | null;

  @Column({
    type: 'enum',
    enum: DriverDocumentStatus,
    name: 'driver_document_status',
    default: DriverDocumentStatus.PENDING,
  })
  driverDocumentStatus: DriverDocumentStatus;

  @Column({
    type: 'timestamptz',
    name: 'driver_document_reviewed_at',
    nullable: true,
  })
  driverDocumentReviewedAt: Date | null;

  @Column({
    type: 'varchar',
    length: 255,
    name: 'stripe_customer_id',
    nullable: true,
  })
  stripeCustomerId: string | null;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
