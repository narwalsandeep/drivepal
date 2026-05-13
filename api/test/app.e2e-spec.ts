import {
  BadRequestException,
  NotFoundException,
  ValidationPipe,
} from '@nestjs/common';
import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppController } from './../src/app.controller';
import { AppService } from './../src/app.service';
import { BookingsController } from './../src/bookings/bookings.controller';
import { CreateRideBookingDto } from './../src/bookings/dto/create-ride-booking.dto';
import {
  BookingCancelReasonCode,
  CancelRideBookingDto,
} from './../src/bookings/dto/cancel-ride-booking.dto';
import { UpdateDriverLocationDto } from './../src/bookings/dto/driver-location.dto';
import { BookingsService } from './../src/bookings/bookings.service';

type BookingStatus =
  | 'requested'
  | 'accepted'
  | 'driver_arriving'
  | 'in_progress'
  | 'completed'
  | 'cancelled';

interface FakeBookingRecord {
  id: string;
  status: BookingStatus;
  hasSucceededPaymentAttempt: boolean;
  refundTriggered: boolean;
  pickupAddress: string;
  dropoffAddress: string;
  carTitle: string;
  paymentMaskedNumber: string;
  driverLocation?: {
    latitude: number;
    longitude: number;
    accuracyMeters: number | null;
    recordedAt: string;
  };
}

function readRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value == null) {
    throw new Error('Expected object response body.');
  }
  return value as Record<string, unknown>;
}

function readStringField(
  value: Record<string, unknown>,
  field: string,
): string {
  const raw = value[field];
  if (typeof raw !== 'string') {
    throw new Error(`Expected "${field}" to be a string.`);
  }
  return raw;
}

function readNumberField(
  value: Record<string, unknown>,
  field: string,
): number {
  const raw = value[field];
  if (typeof raw !== 'number') {
    throw new Error(`Expected "${field}" to be a number.`);
  }
  return raw;
}

class FakeBookingsService {
  private bookingSequence = 1;
  private readonly bookings = new Map<string, FakeBookingRecord>();

  createForCustomer(
    _authorization: string | undefined,
    dto: CreateRideBookingDto,
  ) {
    const id = this.nextBookingId();
    const booking: FakeBookingRecord = {
      id,
      status: 'requested',
      hasSucceededPaymentAttempt: dto.payment.id !== 'pm_unsuccessful',
      refundTriggered: false,
      pickupAddress: dto.pickup.address,
      dropoffAddress: dto.dropoff.address,
      carTitle: dto.car.title,
      paymentMaskedNumber: dto.payment.maskedNumber,
    };
    this.bookings.set(id, booking);
    return { id: booking.id, status: booking.status };
  }

  listCarOptions() {
    return [
      { id: 'city-sedan', title: 'City Sedan', seats: 4, pricePerKmGbp: 1.5 },
    ];
  }

  routePreview() {
    return {
      distanceMeters: 1000,
      durationSeconds: 400,
      polyline: 'encoded',
    };
  }

  listForCustomer() {
    return Array.from(this.bookings.values());
  }

  listOpenForDriver() {
    return Array.from(this.bookings.values()).filter(
      (booking) => booking.status === 'requested',
    );
  }

  listForDriver() {
    return Array.from(this.bookings.values()).filter((booking) =>
      ['accepted', 'driver_arriving', 'in_progress', 'completed'].includes(
        booking.status,
      ),
    );
  }

  listEarningsForDriver() {
    return [];
  }

  acceptForDriver(_authorization: string | undefined, bookingId: string) {
    const booking = this.getBookingOrThrow(bookingId);
    if (booking.status !== 'requested') {
      throw new BadRequestException(
        'Booking can only be accepted once requested.',
      );
    }
    booking.status = 'accepted';
    return { id: booking.id, status: booking.status };
  }

  arriveForDriver(_authorization: string | undefined, bookingId: string) {
    const booking = this.getBookingOrThrow(bookingId);
    if (booking.status !== 'accepted') {
      throw new BadRequestException(
        'Booking can only be marked arriving after acceptance.',
      );
    }
    booking.status = 'driver_arriving';
    return { id: booking.id, status: booking.status };
  }

  pickupForDriver(_authorization: string | undefined, bookingId: string) {
    const booking = this.getBookingOrThrow(bookingId);
    if (booking.status !== 'driver_arriving') {
      throw new BadRequestException(
        'Booking can only be started after driver is arriving.',
      );
    }
    booking.status = 'in_progress';
    return { id: booking.id, status: booking.status };
  }

  finishForDriver(_authorization: string | undefined, bookingId: string) {
    const booking = this.getBookingOrThrow(bookingId);
    if (booking.status !== 'in_progress') {
      throw new BadRequestException(
        'Booking must be in progress before finishing.',
      );
    }
    booking.status = 'completed';
    return { id: booking.id, status: booking.status };
  }

  cancelForDriver(_authorization: string | undefined, bookingId: string) {
    const booking = this.getBookingOrThrow(bookingId);
    booking.status = 'requested';
    return { id: booking.id, status: booking.status };
  }

  updateDriverLocation(
    _authorization: string | undefined,
    bookingId: string,
    dto: UpdateDriverLocationDto,
  ) {
    const booking = this.getBookingOrThrow(bookingId);
    booking.driverLocation = {
      latitude: dto.latitude,
      longitude: dto.longitude,
      accuracyMeters: dto.accuracyMeters ?? null,
      recordedAt: new Date().toISOString(),
    };
    return { ok: true };
  }

  cancelForCustomer(
    _authorization: string | undefined,
    bookingId: string,
    dto: CancelRideBookingDto,
  ) {
    const booking = this.getBookingOrThrow(bookingId);
    const refundableStatuses: BookingStatus[] = [
      'requested',
      'accepted',
      'driver_arriving',
    ];
    if (!refundableStatuses.includes(booking.status)) {
      throw new BadRequestException(
        'Booking can only be cancelled while waiting or before pickup.',
      );
    }
    booking.status = 'cancelled';
    if (booking.hasSucceededPaymentAttempt) {
      booking.refundTriggered = true;
    }
    return {
      id: booking.id,
      status: booking.status,
      cancellation: {
        reasonCode: dto.reasonCode,
        note: dto.note ?? null,
      },
      refundTriggered: booking.refundTriggered,
    };
  }

  getTrackingForCustomer(
    _authorization: string | undefined,
    bookingId: string,
  ) {
    const booking = this.getBookingOrThrow(bookingId);
    return {
      booking: {
        id: booking.id,
        status: booking.status,
        pickupAddress: booking.pickupAddress,
        dropoffAddress: booking.dropoffAddress,
        carTitle: booking.carTitle,
        paymentMaskedNumber: booking.paymentMaskedNumber,
      },
      driverLocation: booking.driverLocation ?? null,
    };
  }

  private getBookingOrThrow(bookingId: string) {
    const booking = this.bookings.get(bookingId);
    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }
    return booking;
  }

  private nextBookingId(): string {
    const suffix = this.bookingSequence.toString().padStart(12, '0');
    this.bookingSequence += 1;
    return `00000000-0000-4000-8000-${suffix}`;
  }
}

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;
  let fakeBookings: FakeBookingsService;
  const authorization = 'Bearer test-token';

  const createBookingPayload = (overrides?: Partial<CreateRideBookingDto>) => ({
    pickup: {
      address: '10 Start Street',
      latitude: 51.5007,
      longitude: -0.1246,
    },
    dropoff: {
      address: 'Airport Terminal 3',
      latitude: 51.47,
      longitude: -0.4543,
    },
    route: {
      distanceMeters: 25000,
      durationSeconds: 3200,
      durationInTrafficSeconds: 3600,
    },
    car: {
      id: 'city-sedan',
      title: 'City Sedan',
      seats: 4,
    },
    payment: {
      id: 'pm_succeeded',
      brand: 'visa',
      maskedNumber: '**** 1111',
    },
    ...overrides,
  });

  beforeEach(async () => {
    fakeBookings = new FakeBookingsService();
    const moduleFixture: TestingModule = await Test.createTestingModule({
      controllers: [AppController, BookingsController],
      providers: [
        AppService,
        {
          provide: BookingsService,
          useValue: fakeBookings,
        },
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });

  it('/api (GET)', () => {
    return request(app.getHttpServer())
      .get('/api')
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'name')).toBe('DRIVEPAL');
      });
  });

  it('runs the booking lifecycle request -> accepted -> arriving -> in_progress -> completed', async () => {
    const createResponse = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('authorization', authorization)
      .send(createBookingPayload())
      .expect(201);
    const createBody = readRecord(createResponse.body);
    const bookingId = readStringField(createBody, 'id');
    expect(readStringField(createBody, 'status')).toBe('requested');

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/accept`)
      .set('authorization', authorization)
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'status')).toBe('accepted');
      });

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/arrive`)
      .set('authorization', authorization)
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'status')).toBe('driver_arriving');
      });

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/pickup`)
      .set('authorization', authorization)
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'status')).toBe('in_progress');
      });

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/finish`)
      .set('authorization', authorization)
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'status')).toBe('completed');
      });
  });

  it('rejects pickup before driver is marked arriving', async () => {
    const createResponse = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('authorization', authorization)
      .send(createBookingPayload())
      .expect(201);
    const bookingId = readStringField(readRecord(createResponse.body), 'id');

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/accept`)
      .set('authorization', authorization)
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/pickup`)
      .set('authorization', authorization)
      .expect(400);
  });

  it('returns tracking snapshot with latest driver location', async () => {
    const createResponse = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('authorization', authorization)
      .send(createBookingPayload())
      .expect(201);
    const bookingId = readStringField(readRecord(createResponse.body), 'id');

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/driver-location`)
      .set('authorization', authorization)
      .send({ latitude: 51.501, longitude: -0.126, accuracyMeters: 8.5 })
      .expect(200);

    await request(app.getHttpServer())
      .get(`/api/bookings/${bookingId}/tracking`)
      .set('authorization', authorization)
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        const booking = readRecord(body.booking);
        const driverLocation = readRecord(body.driverLocation);
        expect(readStringField(booking, 'id')).toBe(bookingId);
        expect(readNumberField(driverLocation, 'latitude')).toBeCloseTo(
          51.501,
          3,
        );
        expect(readNumberField(driverLocation, 'longitude')).toBeCloseTo(
          -0.126,
          3,
        );
      });
  });

  it('triggers refund on customer cancellation for refundable status with succeeded payment', async () => {
    const createResponse = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('authorization', authorization)
      .send(createBookingPayload())
      .expect(201);
    const bookingId = readStringField(readRecord(createResponse.body), 'id');

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/accept`)
      .set('authorization', authorization)
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/cancel`)
      .set('authorization', authorization)
      .send({
        reasonCode: 'change_of_plans' satisfies BookingCancelReasonCode,
        note: 'Need to leave later',
      })
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'status')).toBe('cancelled');
        expect(body.refundTriggered).toBe(true);
      });
  });

  it('does not trigger refund when no succeeded payment attempt exists', async () => {
    const createResponse = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('authorization', authorization)
      .send(
        createBookingPayload({
          payment: {
            id: 'pm_unsuccessful',
            brand: 'visa',
            maskedNumber: '**** 9999',
          },
        }),
      )
      .expect(201);
    const bookingId = readStringField(readRecord(createResponse.body), 'id');

    await request(app.getHttpServer())
      .patch(`/api/bookings/${bookingId}/cancel`)
      .set('authorization', authorization)
      .send({
        reasonCode: 'other' satisfies BookingCancelReasonCode,
      })
      .expect(200)
      .expect((res) => {
        const body = readRecord(res.body);
        expect(readStringField(body, 'status')).toBe('cancelled');
        expect(body.refundTriggered).toBe(false);
      });
  });

  afterEach(async () => {
    await app.close();
  });
});
