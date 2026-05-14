import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { ListNotificationsQueryDto } from './dto/list-notifications-query.dto';
import {
  RegisterPushDeviceDto,
  UnregisterPushDeviceDto,
} from './dto/push-device.dto';
import { Notification } from './entities/notification.entity';
import { PushDevice } from './entities/push-device.entity';
import { PushDevicePlatform } from './enums/push-device-platform.enum';
import { PushDispatcherService } from './push/push-dispatcher.service';

@Injectable()
export class NotificationsService {
  private static readonly defaultLimit = 50;
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly notifications: Repository<Notification>,
    @InjectRepository(PushDevice)
    private readonly pushDevices: Repository<PushDevice>,
    @InjectRepository(User)
    private readonly users: Repository<User>,
    private readonly auth: AuthService,
    private readonly pushDispatcher: PushDispatcherService,
    private readonly config: ConfigService,
  ) {}

  async listForCustomer(
    authorizationHeader: string | undefined,
    query: ListNotificationsQueryDto,
  ) {
    const userId = await this.getAuthenticatedActiveUserId(authorizationHeader);
    const [rows, unreadCount] = await Promise.all([
      this.notifications.find({
        where: {
          userId,
          ...(query.unreadOnly ? { isRead: false } : {}),
        },
        order: { createdAt: 'DESC' },
        take: query.limit ?? NotificationsService.defaultLimit,
      }),
      this.notifications.count({
        where: {
          userId,
          isRead: false,
        },
      }),
    ]);
    return {
      notifications: rows.map((row) => this.toResponse(row)),
      unreadCount,
    };
  }

  async markRead(
    authorizationHeader: string | undefined,
    notificationId: string,
  ) {
    const userId = await this.getAuthenticatedActiveUserId(authorizationHeader);
    const row = await this.notifications.findOne({
      where: { id: notificationId, userId },
    });
    if (!row) {
      throw new NotFoundException('Notification not found');
    }
    if (!row.isRead) {
      row.isRead = true;
      row.readAt = new Date();
      await this.notifications.save(row);
    }
    return { notification: this.toResponse(row) };
  }

  async createForCustomer(input: {
    userId: string;
    kind: string;
    title: string;
    body: string;
    metadata?: Record<string, unknown>;
  }) {
    await this.createForUser(input);
  }

  async createForUser(input: {
    userId: string;
    kind: string;
    title: string;
    body: string;
    metadata?: Record<string, unknown>;
  }) {
    const row = this.notifications.create({
      userId: input.userId,
      kind: input.kind.trim(),
      title: input.title.trim(),
      body: input.body.trim(),
      metadata: input.metadata ?? null,
      isRead: false,
      readAt: null,
    });
    await this.notifications.save(row);
    const pushEnabled = this.config.get<string>('PUSH_ENABLED') === 'true';
    if (!pushEnabled || !this.pushDispatcher.isAnyTransportConfigured()) {
      return;
    }
    void this.pushDispatcher
      .dispatchToUser({
        userId: input.userId,
        payload: {
          kind: row.kind,
          title: row.title,
          body: row.body,
          metadata: row.metadata ?? {},
          createdAtIso: row.createdAt.toISOString(),
        },
      })
      .catch((error: Error) => {
        this.logger.warn(`Push dispatch failed: ${error.message}`);
      });
  }

  async registerPushDevice(
    authorizationHeader: string | undefined,
    dto: RegisterPushDeviceDto,
  ) {
    const userId = await this.getAuthenticatedActiveUserId(authorizationHeader);
    const token = dto.deviceToken.trim();
    if (!token) {
      throw new BadRequestException('Device token is required.');
    }

    let row = await this.pushDevices.findOne({
      where: {
        platform: dto.platform,
        deviceToken: token,
      },
    });
    if (!row) {
      row = this.pushDevices.create({
        userId,
        platform: dto.platform,
        deviceToken: token,
        snsEndpointArn: null,
        isActive: true,
        lastSeenAt: new Date(),
        lastError: null,
        appVersion: dto.appVersion?.trim() || null,
        deviceLabel: dto.deviceLabel?.trim() || null,
      });
    } else {
      row.userId = userId;
      row.isActive = true;
      row.lastSeenAt = new Date();
      row.appVersion = dto.appVersion?.trim() || row.appVersion;
      row.deviceLabel = dto.deviceLabel?.trim() || row.deviceLabel;
      row.lastError = null;
    }

    if (
      dto.platform === PushDevicePlatform.ANDROID ||
      dto.platform === PushDevicePlatform.IOS
    ) {
      try {
        row.snsEndpointArn = await this.pushDispatcher.registerMobileEndpoint({
          platform: dto.platform,
          deviceToken: token,
          existingEndpointArn: row.snsEndpointArn,
        });
      } catch (error) {
        row.lastError = (error as Error).message;
      }
    } else {
      row.snsEndpointArn = null;
    }

    await this.pushDevices.save(row);
    return {
      device: this.toPushDeviceResponse(row),
    };
  }

  async unregisterPushDeviceById(
    authorizationHeader: string | undefined,
    deviceId: string,
  ) {
    const userId = await this.getAuthenticatedActiveUserId(authorizationHeader);
    const row = await this.pushDevices.findOne({
      where: { id: deviceId, userId },
    });
    if (!row) {
      throw new NotFoundException('Push device not found');
    }
    await this.deactivatePushDevice(row);
    return { ok: true };
  }

  async unregisterPushDevice(
    authorizationHeader: string | undefined,
    dto: UnregisterPushDeviceDto,
  ) {
    const userId = await this.getAuthenticatedActiveUserId(authorizationHeader);
    const row = await this.pushDevices.findOne({
      where: {
        userId,
        platform: dto.platform,
        deviceToken: dto.deviceToken.trim(),
        isActive: true,
      },
    });
    if (!row) {
      return { ok: true };
    }
    await this.deactivatePushDevice(row);
    return { ok: true };
  }

  private async getAuthenticatedActiveUserId(
    authorizationHeader: string | undefined,
  ): Promise<string> {
    const userId = await this.auth.getAuthenticatedUserId(authorizationHeader);
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Account unavailable');
    }
    return user.id;
  }

  private toResponse(row: Notification) {
    return {
      id: row.id,
      kind: row.kind,
      title: row.title,
      body: row.body,
      metadata: row.metadata ?? {},
      isRead: row.isRead,
      readAt: row.readAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
    };
  }

  private async deactivatePushDevice(row: PushDevice): Promise<void> {
    row.isActive = false;
    row.lastSeenAt = new Date();
    if (row.snsEndpointArn) {
      await this.pushDispatcher.deleteMobileEndpoint(row.snsEndpointArn);
    }
    await this.pushDevices.save(row);
  }

  private toPushDeviceResponse(row: PushDevice) {
    return {
      id: row.id,
      platform: row.platform,
      isActive: row.isActive,
      lastSeenAt: row.lastSeenAt?.toISOString() ?? null,
      appVersion: row.appVersion,
      deviceLabel: row.deviceLabel,
      lastError: row.lastError,
    };
  }
}
