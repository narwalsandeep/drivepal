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
import { PushDevicePlatform } from '../enums/push-device-platform.enum';

@Entity('push_devices')
@Index(['userId', 'isActive'])
@Index(['platform', 'deviceToken'], { unique: true })
export class PushDevice {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({
    type: 'enum',
    enum: PushDevicePlatform,
  })
  platform: PushDevicePlatform;

  @Column({ type: 'varchar', name: 'device_token', length: 2048 })
  deviceToken: string;

  @Column({
    type: 'varchar',
    name: 'sns_endpoint_arn',
    length: 2048,
    nullable: true,
  })
  snsEndpointArn: string | null;

  @Column({ type: 'boolean', name: 'is_active', default: true })
  isActive: boolean;

  @Column({ type: 'timestamptz', name: 'last_seen_at', nullable: true })
  lastSeenAt: Date | null;

  @Column({ type: 'varchar', name: 'last_error', length: 2048, nullable: true })
  lastError: string | null;

  @Column({ type: 'varchar', name: 'app_version', length: 120, nullable: true })
  appVersion: string | null;

  @Column({
    type: 'varchar',
    name: 'device_label',
    length: 240,
    nullable: true,
  })
  deviceLabel: string | null;

  @CreateDateColumn({ type: 'timestamptz', name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz', name: 'updated_at' })
  updatedAt: Date;
}
