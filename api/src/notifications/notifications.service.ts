import {
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { ListNotificationsQueryDto } from './dto/list-notifications-query.dto';
import { Notification } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  private static readonly defaultLimit = 50;

  constructor(
    @InjectRepository(Notification)
    private readonly notifications: Repository<Notification>,
    @InjectRepository(User)
    private readonly users: Repository<User>,
    private readonly auth: AuthService,
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
}
