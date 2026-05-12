import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('login_challenges')
export class LoginChallenge {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'user_id' })
  @Index()
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'varchar', length: 128, name: 'otp_code_hash' })
  otpCodeHash: string;

  @Column({ type: 'timestamptz', name: 'expires_at' })
  expiresAt: Date;

  @Column({ type: 'int', default: 0 })
  attempts: number;

  @Column({ type: 'timestamptz', nullable: true, name: 'consumed_at' })
  consumedAt: Date | null;

  /** Which app surface this sign-in targets (Flutter rider vs driver). */
  @Column({ type: 'varchar', length: 16, name: 'app_role', nullable: true })
  appRole: 'customer' | 'driver' | null;

  /** Angular admin panel sign-in — skips rider/driver role checks. */
  @Column({ type: 'boolean', name: 'is_admin_panel', default: false })
  isAdminPanel: boolean;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;
}
