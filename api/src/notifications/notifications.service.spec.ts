import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { Notification } from './entities/notification.entity';
import { NotificationsService } from './notifications.service';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('NotificationsService', () => {
  let service: NotificationsService;
  let notifications: MockRepo<Notification>;
  let users: MockRepo<User>;
  let auth: { getAuthenticatedUserId: jest.Mock };

  beforeEach(async () => {
    notifications = {
      find: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((input: unknown) => input),
      save: jest.fn((input: unknown) => input),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 1 }),
      })),
    };
    users = {
      findOne: jest.fn().mockResolvedValue({
        id: 'user-1',
        status: UserStatus.ACTIVE,
        isCustomer: true,
      }),
    };
    auth = {
      getAuthenticatedUserId: jest.fn().mockResolvedValue('user-1'),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: getRepositoryToken(Notification), useValue: notifications },
        { provide: getRepositoryToken(User), useValue: users },
        { provide: AuthService, useValue: auth },
      ],
    }).compile();

    service = moduleRef.get(NotificationsService);
  });

  it('lists notifications for authenticated customer', async () => {
    notifications.count?.mockResolvedValueOnce(1);
    notifications.find?.mockResolvedValueOnce([
      {
        id: 'n1',
        userId: 'user-1',
        kind: 'trip_requested',
        title: 'Ride requested',
        body: 'Searching',
        metadata: {},
        isRead: false,
        readAt: null,
        createdAt: new Date('2026-05-10T00:00:00.000Z'),
      },
    ]);
    const res = await service.listForCustomer('Bearer token', {});
    expect(res.notifications).toHaveLength(1);
    expect(res.unreadCount).toBe(1);
  });

  it('marks a notification as read', async () => {
    notifications.findOne?.mockResolvedValueOnce({
      id: 'n1',
      userId: 'user-1',
      kind: 'trip_requested',
      title: 'Ride requested',
      body: 'Searching',
      metadata: {},
      isRead: false,
      readAt: null,
      createdAt: new Date('2026-05-10T00:00:00.000Z'),
    });
    const res = await service.markRead('Bearer token', 'n1');
    expect(res.notification.isRead).toBe(true);
    expect(notifications.save).toHaveBeenCalled();
  });

  it('rejects mark read for unknown id', async () => {
    await expect(
      service.markRead('Bearer token', 'missing'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects unavailable customer account', async () => {
    users.findOne?.mockResolvedValueOnce(null);
    await expect(
      service.listForCustomer('Bearer token', {}),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
