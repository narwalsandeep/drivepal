import { ConflictException, NotFoundException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { DriverCarsService } from './driver-cars.service';
import { DriverCar } from './entities/driver-car.entity';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

describe('DriverCarsService', () => {
  let service: DriverCarsService;
  let cars: MockRepo<DriverCar>;
  let users: MockRepo<User>;
  let auth: { getAuthenticatedUserId: jest.Mock };

  beforeEach(async () => {
    cars = {
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((input: unknown) => input),
      save: jest.fn((input: Record<string, unknown>) => ({
        id: 'car-1',
        createdAt: new Date('2026-05-10T12:00:00.000Z'),
        updatedAt: new Date('2026-05-10T12:00:00.000Z'),
        ...input,
      })),
    };
    users = {
      findOne: jest.fn().mockResolvedValue({
        id: 'driver-1',
        status: UserStatus.ACTIVE,
        isDriver: true,
        driverProfileCompleted: true,
      }),
    };
    auth = {
      getAuthenticatedUserId: jest.fn().mockResolvedValue('driver-1'),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        DriverCarsService,
        { provide: getRepositoryToken(DriverCar), useValue: cars },
        { provide: getRepositoryToken(User), useValue: users },
        { provide: AuthService, useValue: auth },
      ],
    }).compile();
    service = moduleRef.get(DriverCarsService);
  });

  it('creates a driver car', async () => {
    const res = await service.createMine('Bearer token', {
      displayName: 'Daily Ride',
      manufacturer: 'Toyota',
      model: 'Corolla',
      color: 'Black',
      plateNumber: 'ab12 cde',
      seatCapacity: 4,
      carTypeId: 'mpv5',
      transmission: 'automatic',
      isActive: true,
      acceptsPets: false,
      hasAirConditioning: true,
      hasChildSeat: false,
      wheelchairAccessible: false,
    });
    expect(cars.create).toHaveBeenCalledWith(
      expect.objectContaining({
        driverId: 'driver-1',
        plateNumber: 'AB12 CDE',
        plateNormalized: 'AB12CDE',
      }),
    );
    expect(res.car.id).toBe('car-1');
  });

  it('rejects duplicate plate for same driver', async () => {
    cars.findOne?.mockResolvedValueOnce({ id: 'existing-car' });
    await expect(
      service.createMine('Bearer token', {
        displayName: 'Daily Ride',
        manufacturer: 'Toyota',
        model: 'Corolla',
        color: 'Black',
        plateNumber: 'AB12 CDE',
        seatCapacity: 4,
        carTypeId: 'mpv5',
        transmission: 'automatic',
        isActive: true,
        acceptsPets: false,
        hasAirConditioning: true,
        hasChildSeat: false,
        wheelchairAccessible: false,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('updates existing car', async () => {
    cars.findOne?.mockResolvedValueOnce({
      id: 'car-2',
      driverId: 'driver-1',
      displayName: 'Daily Ride',
      manufacturer: 'Toyota',
      model: 'Corolla',
      color: 'Black',
      plateNumber: 'AB12 CDE',
      plateNormalized: 'AB12CDE',
      seatCapacity: 4,
      carTypeId: 'mpv5',
      transmission: 'automatic',
      isActive: true,
      acceptsPets: false,
      hasAirConditioning: true,
      hasChildSeat: false,
      wheelchairAccessible: false,
      createdAt: new Date('2026-05-10T12:00:00.000Z'),
      updatedAt: new Date('2026-05-10T12:00:00.000Z'),
    });
    cars.findOne?.mockResolvedValueOnce(null);
    const res = await service.updateMine('Bearer token', 'car-2', {
      color: 'Blue',
      acceptsPets: true,
    });
    expect(cars.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'car-2',
        color: 'Blue',
        acceptsPets: true,
      }),
    );
    expect(res.car.color).toBe('Blue');
  });

  it('rejects update for unknown car', async () => {
    cars.findOne?.mockResolvedValueOnce(null);
    await expect(
      service.updateMine('Bearer token', 'missing', { isActive: false }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
