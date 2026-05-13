import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { IsNull, Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { MailService } from '../auth/services/mail.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PaymentAttempt } from '../payments/entities/payment-attempt.entity';
import { PaymentAttemptStatus } from '../payments/enums/payment-attempt-status.enum';
import { DriverCar } from '../driver-cars/entities/driver-car.entity';
import { BookingsService } from './bookings.service';
import { DriverTripEarning } from './entities/driver-trip-earning.entity';
import { RideBookingDriverLocation } from './entities/ride-booking-driver-location.entity';
import { RideBooking } from './entities/ride-booking.entity';
import { BookingStatus } from './enums/booking-status.enum';

type MockRepo<T extends object> = Partial<
  Record<keyof Repository<T>, jest.Mock>
>;

const dto = {
  pickup: { address: '10 Start Street', latitude: 51.5, longitude: -0.12 },
  dropoff: { address: 'Airport Terminal 2', latitude: 51.47, longitude: -0.45 },
  route: {
    distanceMeters: 12400,
    durationSeconds: 1320,
    durationInTrafficSeconds: 1560,
  },
  car: { id: 'sedan4', title: 'City Sedan', seats: 4 },
  payment: { id: 'visa-1042', brand: 'Visa', maskedNumber: '**** 1042' },
};

describe('BookingsService', () => {
  let service: BookingsService;
  let bookings: MockRepo<RideBooking>;
  let paymentAttempts: MockRepo<PaymentAttempt>;
  let tripEarnings: MockRepo<DriverTripEarning>;
  let rideBookingDriverLocations: MockRepo<RideBookingDriverLocation>;
  let driverCars: MockRepo<DriverCar>;
  let users: MockRepo<User>;
  let auth: { getAuthenticatedUserId: jest.Mock };
  let notifications: { createForCustomer: jest.Mock; createForUser: jest.Mock };
  let mail: {
    sendTripAcceptedToCustomer: jest.Mock;
    sendTripAcceptedToDriver: jest.Mock;
    sendTripReopenedToCustomer: jest.Mock;
    sendTripUnassignedToDriver: jest.Mock;
    sendScheduledTripReminderToDriver: jest.Mock;
  };
  let payments: {
    chargeSavedCardForBooking: jest.Mock;
    attachPaymentAttemptToBooking: jest.Mock;
    refundBookingCharge: jest.Mock;
  };
  let config: { get: jest.Mock };

  beforeEach(async () => {
    bookings = {
      create: jest.fn((input: unknown) => input),
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 1 }),
      })),
      save: jest.fn((input: Record<string, unknown>) => ({
        id: 'booking-1',
        createdAt: new Date('2026-05-09T12:00:00.000Z'),
        ...input,
      })),
    };
    paymentAttempts = {
      findOne: jest.fn().mockResolvedValue({
        id: 'attempt-1',
        bookingId: 'booking-7',
        amountMinor: 1798,
        capturedAmountMinor: 1798,
        currencyCode: 'GBP',
        status: PaymentAttemptStatus.SUCCEEDED,
      }),
    };
    tripEarnings = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((input: unknown) => input),
      find: jest.fn().mockResolvedValue([]),
      save: jest.fn((input: Record<string, unknown>) =>
        Promise.resolve({
          id: 'earning-1',
          createdAt: new Date('2026-05-10T11:20:00.000Z'),
          ...input,
        }),
      ),
    };
    rideBookingDriverLocations = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((input: unknown) => input),
      save: jest.fn((input: Record<string, unknown>) =>
        Promise.resolve({
          id: 'driver-location-1',
          createdAt: new Date('2026-05-10T11:20:00.000Z'),
          updatedAt: new Date('2026-05-10T11:20:00.000Z'),
          ...input,
        }),
      ),
    };
    driverCars = {
      findOne: jest.fn().mockResolvedValue({
        id: 'driver-car-1',
        driverId: 'driver-1',
        isActive: true,
        carTypeId: 'car',
      }),
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
    notifications = {
      createForCustomer: jest.fn().mockResolvedValue(undefined),
      createForUser: jest.fn().mockResolvedValue(undefined),
    };
    mail = {
      sendTripAcceptedToCustomer: jest.fn().mockResolvedValue(undefined),
      sendTripAcceptedToDriver: jest.fn().mockResolvedValue(undefined),
      sendTripReopenedToCustomer: jest.fn().mockResolvedValue(undefined),
      sendTripUnassignedToDriver: jest.fn().mockResolvedValue(undefined),
      sendScheduledTripReminderToDriver: jest.fn().mockResolvedValue(undefined),
    };
    payments = {
      chargeSavedCardForBooking: jest.fn().mockResolvedValue({
        attemptId: 'attempt-1',
        stripePaymentIntentId: 'pi_1',
        paymentCard: {
          id: 'card-1',
          brand: 'visa',
          last4: '1042',
          stripePaymentMethodId: 'pm_1',
        },
        chargedAmountMinor: 1798,
        currencyCode: 'GBP',
      }),
      attachPaymentAttemptToBooking: jest.fn().mockResolvedValue(undefined),
      refundBookingCharge: jest.fn().mockResolvedValue(undefined),
    };
    config = {
      get: jest
        .fn()
        .mockImplementation((key: string) =>
          key === 'GOOGLE_MAPS_API_KEY' ? 'maps-key' : undefined,
        ),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: getRepositoryToken(RideBooking), useValue: bookings },
        {
          provide: getRepositoryToken(PaymentAttempt),
          useValue: paymentAttempts,
        },
        {
          provide: getRepositoryToken(DriverTripEarning),
          useValue: tripEarnings,
        },
        {
          provide: getRepositoryToken(RideBookingDriverLocation),
          useValue: rideBookingDriverLocations,
        },
        { provide: getRepositoryToken(DriverCar), useValue: driverCars },
        { provide: getRepositoryToken(User), useValue: users },
        { provide: ConfigService, useValue: config },
        { provide: AuthService, useValue: auth },
        { provide: MailService, useValue: mail },
        { provide: NotificationsService, useValue: notifications },
        { provide: PaymentsService, useValue: payments },
      ],
    }).compile();

    service = moduleRef.get(BookingsService);
  });

  it('creates a requested booking for an authenticated customer', async () => {
    const res = await service.createForCustomer('Bearer token', dto);

    expect(auth.getAuthenticatedUserId).toHaveBeenCalledWith('Bearer token');
    expect(bookings.create).toHaveBeenCalledWith(
      expect.objectContaining({
        customerId: 'user-1',
        status: BookingStatus.REQUESTED,
        pickupAddress: dto.pickup.address,
        dropoffAddress: dto.dropoff.address,
        routeDistanceMeters: dto.route.distanceMeters,
        carTypeId: dto.car.id,
        carTypeTitle: 'City Sedan',
        carSeats: 4,
        paymentMethodId: 'card-1',
      }),
    );
    expect(payments.chargeSavedCardForBooking).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        paymentCardId: dto.payment.id,
        currencyCode: 'GBP',
      }),
    );
    expect(res.booking.id).toBe('booking-1');
    expect(res.booking.status).toBe(BookingStatus.REQUESTED);
    expect(res.booking.pickup.address).toBe(dto.pickup.address);
    expect(res.booking.car.title).toBe(dto.car.title);
    expect(notifications.createForCustomer).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_requested',
      }),
    );
  });

  it('applies configurable fare model values from environment', async () => {
    config.get.mockImplementation((key: string) => {
      switch (key) {
        case 'GOOGLE_MAPS_API_KEY':
          return 'maps-key';
        case 'FARE_BASE_GBP':
          return '2.0';
        case 'FARE_PER_MINUTE_GBP':
          return '0.1';
        case 'FARE_MIN_GBP':
          return '0';
        case 'FARE_SCHEDULED_SURCHARGE_GBP':
          return '0';
        case 'FARE_PER_KM_MULTIPLIER':
          return '1';
        case 'FARE_SURGE_MULTIPLIER':
          return '1';
        default:
          return undefined;
      }
    });

    await service.createForCustomer('Bearer token', dto);

    expect(payments.chargeSavedCardForBooking).toHaveBeenCalledWith(
      expect.objectContaining({
        amountMinor: 2218,
      }),
    );
  });

  it('creates a scheduled booking when time offset is allowed', async () => {
    const now = Date.now();
    const scheduledFor = new Date(now + 20 * 60 * 1000).toISOString();

    const res = await service.createForCustomer('Bearer token', {
      ...dto,
      scheduledFor,
    });

    expect(bookings.create).toHaveBeenCalledWith(
      expect.objectContaining({
        status: BookingStatus.REQUESTED,
      }),
    );
    const createCalls = bookings.create?.mock.calls ?? [];
    const latestCreateArg = createCalls.at(-1)?.[0] as
      | { scheduledFor?: Date | null }
      | undefined;
    expect(latestCreateArg?.scheduledFor).toBeInstanceOf(Date);
    expect(res.booking.scheduledFor).toBeTruthy();
  });

  it('rejects scheduled booking with disallowed offset', async () => {
    const scheduledFor = new Date(Date.now() + 45 * 60 * 1000).toISOString();

    await expect(
      service.createForCustomer('Bearer token', {
        ...dto,
        scheduledFor,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects inactive or non-customer accounts', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isCustomer: false,
    });

    await expect(
      service.createForCustomer('Bearer token', dto),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects identical pickup and drop-off coordinates', async () => {
    await expect(
      service.createForCustomer('Bearer token', {
        ...dto,
        dropoff: { ...dto.pickup },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects unavailable car options', async () => {
    await expect(
      service.createForCustomer('Bearer token', {
        ...dto,
        car: { ...dto.car, id: 'spaceship' },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects missing route distance before charging', async () => {
    await expect(
      service.createForCustomer('Bearer token', {
        ...dto,
        route: {
          durationSeconds: dto.route.durationSeconds,
          durationInTrafficSeconds: dto.route.durationInTrafficSeconds,
        },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(payments.chargeSavedCardForBooking).not.toHaveBeenCalled();
  });

  it('lists configured car options with GBP pricing', () => {
    const response = service.listCarOptions();
    expect(response.currencyCode).toBe('GBP');
    const sedan = response.carOptions.find((option) => option.id === 'sedan4');
    expect(sedan).toBeDefined();
    expect(sedan?.title).toBe('City Sedan');
    expect(sedan?.seats).toBe(4);
    expect(typeof sedan?.pricePerKmGbp).toBe('number');
  });

  it('lists customer bookings with latest requested first', async () => {
    bookings.find?.mockResolvedValueOnce([
      {
        id: 'booking-2',
        status: BookingStatus.ACCEPTED,
        customerId: 'user-1',
        pickupAddress: 'A',
        pickupLatitude: 1,
        pickupLongitude: 2,
        dropoffAddress: 'B',
        dropoffLatitude: 3,
        dropoffLongitude: 4,
        routeDistanceMeters: 10,
        routeDurationSeconds: 20,
        routeDurationInTrafficSeconds: 25,
        carTypeId: 'car',
        carTypeTitle: 'Car',
        carSeats: 4,
        paymentMethodId: 'pay',
        paymentBrand: 'Visa',
        paymentMaskedNumber: '**** 1111',
        cancelledAt: null,
        cancelReasonCode: null,
        cancelReasonNote: null,
        requestedAt: new Date('2026-05-10T11:00:00.000Z'),
        createdAt: new Date('2026-05-10T11:00:00.000Z'),
      } as RideBooking,
    ]);

    const res = await service.listForCustomer('Bearer token', { limit: 30 });

    expect(bookings.find).toHaveBeenCalledWith({
      where: { customerId: 'user-1' },
      order: { requestedAt: 'DESC', createdAt: 'DESC' },
      take: 30,
    });
    expect(res.bookings).toHaveLength(1);
    expect(res.bookings[0]).toEqual(
      expect.objectContaining({
        id: 'booking-2',
        status: BookingStatus.ACCEPTED,
        canCancel: true,
      }),
    );
  });

  it('cancels a customer booking with reason', async () => {
    paymentAttempts.findOne?.mockResolvedValueOnce({
      id: 'attempt-3',
      bookingId: 'booking-3',
      status: PaymentAttemptStatus.SUCCEEDED,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-3',
      customerId: 'user-1',
      status: BookingStatus.REQUESTED,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });

    const res = await service.cancelForCustomer('Bearer token', 'booking-3', {
      reasonCode: 'change_of_plans',
      note: 'No longer needed',
    });

    expect(bookings.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'booking-3',
        status: BookingStatus.CANCELLED,
        cancelReasonCode: 'change_of_plans',
      }),
    );
    expect(res.booking).toEqual(
      expect.objectContaining({
        id: 'booking-3',
        status: BookingStatus.CANCELLED,
        canCancel: false,
      }),
    );
    expect(notifications.createForCustomer).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_cancelled',
        metadata: expect.objectContaining({
          bookingId: 'booking-3',
          reasonCode: 'change_of_plans',
          refundInitiated: true,
        }),
      }),
    );
    expect(payments.refundBookingCharge).toHaveBeenCalledWith(
      'attempt-3',
      'Customer cancelled trip before pickup',
    );
  });

  it('cancels booking without refund when no successful payment attempt exists', async () => {
    paymentAttempts.findOne?.mockResolvedValueOnce(null);
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-30',
      customerId: 'user-1',
      status: BookingStatus.REQUESTED,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });

    await service.cancelForCustomer('Bearer token', 'booking-30', {
      reasonCode: 'change_of_plans',
    });

    expect(payments.refundBookingCharge).not.toHaveBeenCalled();
    expect(notifications.createForCustomer).toHaveBeenCalledWith(
      expect.objectContaining({
        metadata: expect.objectContaining({
          bookingId: 'booking-30',
          refundInitiated: false,
        }),
      }),
    );
  });

  it('lists open bookings for driver from requested pool', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.find?.mockResolvedValueOnce([
      {
        id: 'booking-open',
        status: BookingStatus.REQUESTED,
        customerId: 'user-1',
        driverId: null,
        pickupAddress: 'A',
        pickupLatitude: 1,
        pickupLongitude: 2,
        dropoffAddress: 'B',
        dropoffLatitude: 3,
        dropoffLongitude: 4,
        routeDistanceMeters: 10,
        routeDurationSeconds: 20,
        routeDurationInTrafficSeconds: 25,
        carTypeId: 'car',
        carTypeTitle: 'Car',
        carSeats: 4,
        paymentMethodId: 'pay',
        paymentBrand: 'Visa',
        paymentMaskedNumber: '**** 1111',
        cancelledAt: null,
        cancelReasonCode: null,
        cancelReasonNote: null,
        acceptedAt: null,
        requestedAt: new Date('2026-05-10T11:00:00.000Z'),
        createdAt: new Date('2026-05-10T11:00:00.000Z'),
      } as RideBooking,
    ]);

    const res = await service.listOpenForDriver('Bearer token', { limit: 20 });
    expect(bookings.find).toHaveBeenCalledWith({
      where: {
        status: BookingStatus.REQUESTED,
        driverId: IsNull(),
        carTypeId: 'car',
      },
      order: { requestedAt: 'DESC', createdAt: 'DESC' },
      take: 20,
    });
    expect(res.bookings).toHaveLength(1);
  });

  it('rejects driver access when documents are pending approval', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
      driverDocumentStatus: 'pending',
    });

    await expect(
      service.listOpenForDriver('Bearer token', { limit: 20 }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('accepts an open booking for driver', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.findOne?.mockResolvedValueOnce(null);
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-5',
      customerId: 'user-1',
      status: BookingStatus.REQUESTED,
      driverId: null,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: null,
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-5',
      customerId: 'user-1',
      status: BookingStatus.ACCEPTED,
      driverId: 'driver-1',
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    users.findOne?.mockResolvedValueOnce({
      id: 'user-1',
      email: 'customer@example.com',
      status: UserStatus.ACTIVE,
      isCustomer: true,
    });
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      email: 'driver@example.com',
      status: UserStatus.ACTIVE,
      isDriver: true,
    });

    const res = await service.acceptForDriver('Bearer token', 'booking-5');
    expect(bookings.createQueryBuilder).toHaveBeenCalled();
    expect(notifications.createForUser).toHaveBeenCalledTimes(2);
    expect(mail.sendTripAcceptedToCustomer).toHaveBeenCalled();
    expect(mail.sendTripAcceptedToDriver).toHaveBeenCalled();
    expect(res.booking.status).toBe(BookingStatus.ACCEPTED);
  });

  it('rejects accepting another trip when driver already has one active', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-active',
      driverId: 'driver-1',
      status: BookingStatus.ACCEPTED,
    });

    await expect(
      service.acceptForDriver('Bearer token', 'booking-next'),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('marks accepted booking as driver arriving', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-6',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.ACCEPTED,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );

    const res = await service.arriveForDriver('Bearer token', 'booking-6');

    expect(res.booking.status).toBe(BookingStatus.DRIVER_ARRIVING);
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_driver_arriving',
      }),
    );
  });

  it('marks arriving booking as in progress on pickup', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-6b',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.DRIVER_ARRIVING,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );

    const res = await service.pickupForDriver('Bearer token', 'booking-6b');

    expect(res.booking.status).toBe(BookingStatus.IN_PROGRESS);
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_started',
      }),
    );
  });

  it('marks in-progress booking as completed on finish', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-7',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.IN_PROGRESS,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );

    const res = await service.finishForDriver('Bearer token', 'booking-7');

    expect(res.booking.status).toBe(BookingStatus.COMPLETED);
    expect(tripEarnings.create).toHaveBeenCalledWith(
      expect.objectContaining({
        bookingId: 'booking-7',
        driverId: 'driver-1',
        grossAmountMinor: 1798,
        driverAmountMinor: 180,
      }),
    );
    expect(tripEarnings.save).toHaveBeenCalled();
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_completed',
      }),
    );
  });

  it('lists driver earnings latest-first', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    tripEarnings.find?.mockResolvedValueOnce([
      {
        id: 'earning-2',
        driverId: 'driver-1',
        bookingId: 'booking-2',
        paymentAttemptId: 'attempt-2',
        grossAmountMinor: 2500,
        platformFeeMinor: 2250,
        driverAmountMinor: 250,
        driverShareBps: 1000,
        currencyCode: 'GBP',
        calculatedAt: new Date('2026-05-10T11:30:00.000Z'),
        createdAt: new Date('2026-05-10T11:30:00.000Z'),
      } as DriverTripEarning,
    ]);
    bookings.find?.mockResolvedValueOnce([
      {
        id: 'booking-2',
        pickupAddress: 'A',
        dropoffAddress: 'B',
        carTypeTitle: 'City Sedan',
        requestedAt: new Date('2026-05-10T11:00:00.000Z'),
        updatedAt: new Date('2026-05-10T11:20:00.000Z'),
      } as RideBooking,
    ]);

    const res = await service.listEarningsForDriver('Bearer token', {
      limit: 20,
    });

    expect(tripEarnings.find).toHaveBeenCalledWith({
      where: { driverId: 'driver-1' },
      order: { calculatedAt: 'DESC', createdAt: 'DESC' },
      take: 20,
    });
    expect(res.earnings).toHaveLength(1);
    expect(res.earnings[0]).toEqual(
      expect.objectContaining({
        id: 'earning-2',
        grossAmountMinor: 2500,
        driverAmountMinor: 250,
      }),
    );
  });

  it('allows driver to cancel active accepted booking', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    users.findOne?.mockResolvedValueOnce({
      id: 'user-1',
      email: 'customer@example.com',
      status: UserStatus.ACTIVE,
      isCustomer: true,
    });
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      email: 'driver@example.com',
      status: UserStatus.ACTIVE,
      isDriver: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-8',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.ACCEPTED,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );

    const res = await service.cancelForDriver('Bearer token', 'booking-8');

    expect(res.booking.status).toBe(BookingStatus.REQUESTED);
    expect(res.booking.driver.id).toBeNull();
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_reopened',
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'driver-1',
        kind: 'trip_unassigned',
      }),
    );
    expect(mail.sendTripReopenedToCustomer).toHaveBeenCalled();
    expect(mail.sendTripUnassignedToDriver).toHaveBeenCalled();
  });

  it('updates driver location for active trip', async () => {
    auth.getAuthenticatedUserId.mockResolvedValueOnce('driver-1');
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
      driverDocumentStatus: 'approved',
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-track-1',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.ACCEPTED,
    });
    rideBookingDriverLocations.findOne?.mockResolvedValueOnce(null);

    const res = await service.updateDriverLocation(
      'Bearer token',
      'booking-track-1',
      {
        latitude: 51.5,
        longitude: -0.12,
        accuracyMeters: 14,
      },
    );

    expect(rideBookingDriverLocations.save).toHaveBeenCalledWith(
      expect.objectContaining({
        bookingId: 'booking-track-1',
        driverId: 'driver-1',
        latitude: 51.5,
        longitude: -0.12,
        accuracyMeters: 14,
      }),
    );
    expect(res.tracking.bookingId).toBe('booking-track-1');
    expect(res.tracking.status).toBe(BookingStatus.ACCEPTED);
  });

  it('rejects driver location update for non-active trip status', async () => {
    auth.getAuthenticatedUserId.mockResolvedValueOnce('driver-1');
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
      driverDocumentStatus: 'approved',
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-track-2',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.COMPLETED,
    });

    await expect(
      service.updateDriverLocation('Bearer token', 'booking-track-2', {
        latitude: 51.5,
        longitude: -0.12,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('returns customer tracking snapshot with latest driver location', async () => {
    users.findOne?.mockResolvedValueOnce({
      id: 'user-1',
      status: UserStatus.ACTIVE,
      isCustomer: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-track-3',
      customerId: 'user-1',
      driverId: 'driver-2',
      status: BookingStatus.ACCEPTED,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    rideBookingDriverLocations.findOne?.mockResolvedValueOnce({
      id: 'driver-location-9',
      bookingId: 'booking-track-3',
      driverId: 'driver-2',
      latitude: 51.48,
      longitude: -0.32,
      accuracyMeters: 10,
      recordedAt: new Date('2026-05-10T11:03:00.000Z'),
      updatedAt: new Date('2026-05-10T11:03:00.000Z'),
    });

    const res = await service.getTrackingForCustomer(
      'Bearer token',
      'booking-track-3',
    );

    expect(res.tracking.booking.id).toBe('booking-track-3');
    expect(res.tracking.driverLocation).toEqual(
      expect.objectContaining({
        latitude: 51.48,
        longitude: -0.32,
        accuracyMeters: 10,
      }),
    );
  });

  it('reopens customer trip for reassignment when driver already accepted', async () => {
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-9',
      customerId: 'user-1',
      driverId: 'driver-2',
      status: BookingStatus.ACCEPTED,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );
    users.findOne?.mockResolvedValueOnce({
      id: 'user-1',
      status: UserStatus.ACTIVE,
      isCustomer: true,
    });
    users.findOne?.mockResolvedValueOnce({
      id: 'user-1',
      email: 'customer@example.com',
      status: UserStatus.ACTIVE,
      isCustomer: true,
    });
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-2',
      email: 'driver2@example.com',
      status: UserStatus.ACTIVE,
      isDriver: true,
    });

    const res = await service.cancelForCustomer('Bearer token', 'booking-9', {
      reasonCode: 'driver_delay',
      note: 'Need another driver',
    });

    expect(res.booking.status).toBe(BookingStatus.REQUESTED);
    expect(res.booking.driver.id).toBeNull();
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'trip_reopened',
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'driver-2',
        kind: 'trip_unassigned',
      }),
    );
    expect(mail.sendTripReopenedToCustomer).toHaveBeenCalled();
    expect(mail.sendTripUnassignedToDriver).toHaveBeenCalled();
    expect(payments.refundBookingCharge).not.toHaveBeenCalled();
  });

  it('rejects cancel for unknown booking', async () => {
    bookings.findOne?.mockResolvedValueOnce(null);
    await expect(
      service.cancelForCustomer('Bearer token', 'missing', {
        reasonCode: 'change_of_plans',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects cancel for non-cancellable status', async () => {
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-4',
      customerId: 'user-1',
      status: BookingStatus.COMPLETED,
    });
    await expect(
      service.cancelForCustomer('Bearer token', 'booking-4', {
        reasonCode: 'change_of_plans',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('sends 10 minute reminder for assigned scheduled ride', async () => {
    const scheduledFor = new Date(Date.now() + 9 * 60 * 1000);
    bookings.find?.mockResolvedValueOnce([
      {
        id: 'booking-reminder',
        customerId: 'user-1',
        driverId: 'driver-1',
        status: BookingStatus.ACCEPTED,
        pickupAddress: 'A',
        pickupLatitude: 1,
        pickupLongitude: 2,
        dropoffAddress: 'B',
        dropoffLatitude: 3,
        dropoffLongitude: 4,
        routeDistanceMeters: 1000,
        routeDurationSeconds: 1200,
        routeDurationInTrafficSeconds: 1300,
        carTypeId: 'car',
        carTypeTitle: 'Car',
        carSeats: 4,
        paymentMethodId: 'pay',
        paymentBrand: 'Visa',
        paymentMaskedNumber: '**** 1111',
        requestedAt: new Date('2026-05-10T11:00:00.000Z'),
        scheduledFor,
        scheduledReminderSentAt: null,
        acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
        cancelledAt: null,
        cancelReasonCode: null,
        cancelReasonNote: null,
        createdAt: new Date('2026-05-10T11:00:00.000Z'),
      } as RideBooking,
    ]);
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      email: 'driver@example.com',
      status: UserStatus.ACTIVE,
      isDriver: true,
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );

    await service.processScheduledRideReminders();

    expect(notifications.createForUser).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'driver-1',
        kind: 'trip_schedule_reminder',
      }),
    );
    expect(mail.sendScheduledTripReminderToDriver).toHaveBeenCalled();
    const saveCalls = bookings.save?.mock.calls ?? [];
    const latestSaveArg = saveCalls.at(-1)?.[0] as
      | { id?: string; scheduledReminderSentAt?: Date | null }
      | undefined;
    expect(latestSaveArg?.id).toBe('booking-reminder');
    expect(latestSaveArg?.scheduledReminderSentAt).toBeInstanceOf(Date);
  });

  it('does not create earning when payment attempt is unavailable', async () => {
    paymentAttempts.findOne?.mockResolvedValueOnce(null);
    users.findOne?.mockResolvedValueOnce({
      id: 'driver-1',
      status: UserStatus.ACTIVE,
      isDriver: true,
      driverProfileCompleted: true,
    });
    bookings.findOne?.mockResolvedValueOnce({
      id: 'booking-10',
      customerId: 'user-1',
      driverId: 'driver-1',
      status: BookingStatus.IN_PROGRESS,
      pickupAddress: 'A',
      pickupLatitude: 1,
      pickupLongitude: 2,
      dropoffAddress: 'B',
      dropoffLatitude: 3,
      dropoffLongitude: 4,
      routeDistanceMeters: 10,
      routeDurationSeconds: 20,
      routeDurationInTrafficSeconds: 25,
      carTypeId: 'car',
      carTypeTitle: 'Car',
      carSeats: 4,
      paymentMethodId: 'pay',
      paymentBrand: 'Visa',
      paymentMaskedNumber: '**** 1111',
      cancelledAt: null,
      cancelReasonCode: null,
      cancelReasonNote: null,
      acceptedAt: new Date('2026-05-10T11:01:00.000Z'),
      requestedAt: new Date('2026-05-10T11:00:00.000Z'),
      createdAt: new Date('2026-05-10T11:00:00.000Z'),
    });
    bookings.save?.mockImplementation((input: RideBooking) =>
      Promise.resolve(input),
    );

    await service.finishForDriver('Bearer token', 'booking-10');

    expect(tripEarnings.save).not.toHaveBeenCalled();
  });
});
