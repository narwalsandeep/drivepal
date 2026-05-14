import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { Notification } from './entities/notification.entity';
import { PushDevice } from './entities/push-device.entity';
import { PushDevicePlatform } from './enums/push-device-platform.enum';
import { PushDispatcherService } from './push/push-dispatcher.service';
import { NotificationsService } from './notifications.service';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('NotificationsService', () => {
  let service: NotificationsService;
  let notifications: MockRepo<Notification>;
  let pushDevices: MockRepo<PushDevice>;
  let users: MockRepo<User>;
  let auth: { getAuthenticatedUserId: jest.Mock };
  let pushDispatcher: {
    isAnyTransportConfigured: jest.Mock;
    dispatchToUser: jest.Mock;
    registerMobileEndpoint: jest.Mock;
    deleteMobileEndpoint: jest.Mock;
  };
  let config: { get: jest.Mock };

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
    pushDevices = {
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((input: unknown) => input),
      save: jest.fn((input: unknown) => input),
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
    pushDispatcher = {
      isAnyTransportConfigured: jest.fn().mockReturnValue(true),
      dispatchToUser: jest.fn().mockResolvedValue(undefined),
      registerMobileEndpoint: jest.fn().mockResolvedValue('arn:test'),
      deleteMobileEndpoint: jest.fn().mockResolvedValue(undefined),
    };
    config = {
      get: jest.fn((key: string) =>
        key === 'PUSH_ENABLED' ? 'true' : undefined,
      ),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: getRepositoryToken(Notification), useValue: notifications },
        { provide: getRepositoryToken(PushDevice), useValue: pushDevices },
        { provide: getRepositoryToken(User), useValue: users },
        { provide: AuthService, useValue: auth },
        { provide: PushDispatcherService, useValue: pushDispatcher },
        { provide: ConfigService, useValue: config },
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

  it('registers mobile device and stores endpoint ARN', async () => {
    pushDevices.findOne?.mockResolvedValueOnce(null);
    const res = await service.registerPushDevice('Bearer token', {
      platform: PushDevicePlatform.ANDROID,
      deviceToken: 'this-is-a-valid-device-token-value-123456789',
      appVersion: '1.0.0',
      deviceLabel: 'pixel',
    });
    expect(pushDispatcher.registerMobileEndpoint).toHaveBeenCalled();
    expect(pushDevices.save).toHaveBeenCalled();
    expect(res.device.platform).toBe(PushDevicePlatform.ANDROID);
  });

  it('unregisters device by id with ownership check', async () => {
    pushDevices.findOne?.mockResolvedValueOnce({
      id: 'dev-1',
      userId: 'user-1',
      platform: PushDevicePlatform.IOS,
      deviceToken: 'this-is-a-valid-device-token-value-987654321',
      snsEndpointArn: 'arn:test',
      isActive: true,
      lastSeenAt: null,
      lastError: null,
      appVersion: null,
      deviceLabel: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const res = await service.unregisterPushDeviceById('Bearer token', 'dev-1');
    expect(res.ok).toBe(true);
    expect(pushDispatcher.deleteMobileEndpoint).toHaveBeenCalledWith(
      'arn:test',
    );
    expect(pushDevices.save).toHaveBeenCalled();
  });

  it('dispatches push in a non-blocking way after notification save', async () => {
    notifications.create?.mockReturnValueOnce({
      userId: 'user-1',
      kind: 'trip_accepted',
      title: 'Trip accepted',
      body: 'Your driver accepted.',
      metadata: { bookingId: 'b1' },
      isRead: false,
      readAt: null,
      createdAt: new Date('2026-05-10T01:00:00.000Z'),
    });
    await service.createForUser({
      userId: 'user-1',
      kind: 'trip_accepted',
      title: 'Trip accepted',
      body: 'Your driver accepted.',
      metadata: { bookingId: 'b1' },
    });
    expect(notifications.save).toHaveBeenCalled();
    expect(pushDispatcher.dispatchToUser).toHaveBeenCalled();
  });
});
