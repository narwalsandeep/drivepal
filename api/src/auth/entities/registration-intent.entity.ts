import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { AppRole } from '../enums/app-role.enum';

@Entity('registration_intents')
@Index(['phoneE164'], { unique: true })
@Index(['email'], { unique: true })
export class RegistrationIntent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 320 })
  email: string;

  @Column({ type: 'varchar', length: 20, name: 'phone_e164' })
  phoneE164: string;

  /** Defaults let `synchronize` add NOT NULL columns when old rows already exist in the table. */
  @Column({ type: 'varchar', length: 80, name: 'first_name', default: '' })
  firstName: string;

  @Column({ type: 'varchar', length: 80, name: 'last_name', default: '' })
  lastName: string;

  @Column({ type: 'varchar', length: 120, name: 'password_hash' })
  passwordHash: string;

  @Column({ type: 'varchar', length: 128, name: 'otp_code_hash' })
  otpCodeHash: string;

  @Column({ type: 'timestamptz', name: 'expires_at' })
  expiresAt: Date;

  @Column({ type: 'int', default: 0 })
  attempts: number;

  /** When set, OTP verifies adding driver/customer role to this account (same email + phone + password). */
  @Column({ type: 'uuid', name: 'existing_user_id', nullable: true })
  existingUserId: string | null;

  @Column({
    type: 'enum',
    enum: AppRole,
    name: 'signup_as',
    default: AppRole.CUSTOMER,
  })
  signupAs: AppRole;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;
}
