import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, In, IsNull, Not, Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { DriverDocumentStatus } from '../auth/enums/driver-document-status.enum';
import { UserStatus } from '../auth/enums/user-status.enum';
import { MailService } from '../auth/services/mail.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentAttempt } from '../payments/entities/payment-attempt.entity';
import { PaymentAttemptStatus } from '../payments/enums/payment-attempt-status.enum';
import { PaymentsService } from '../payments/payments.service';
import { DriverCar } from '../driver-cars/entities/driver-car.entity';
import {
  BOOKING_CAR_OPTIONS,
  BOOKING_CAR_OPTIONS_CURRENCY_CODE,
  type BookingCarOptionConfig,
} from './constants/car-options.constant';
import { CreateRideBookingDto } from './dto/create-ride-booking.dto';
import { CancelRideBookingDto } from './dto/cancel-ride-booking.dto';
import { UpdateDriverLocationDto } from './dto/driver-location.dto';
import { ListRideBookingsQueryDto } from './dto/list-ride-bookings-query.dto';
import { RideBookingDriverLocation } from './entities/ride-booking-driver-location.entity';
import { DriverTripEarning } from './entities/driver-trip-earning.entity';
import { RideBooking } from './entities/ride-booking.entity';
import { BookingStatus } from './enums/booking-status.enum';

@Injectable()
export class BookingsService {
  private static readonly defaultListLimit = 50;
  private static readonly driverShareBps = 1000;
  private static readonly scheduledOffsetsMinutes = [10, 20, 30, 60, 120];
  private static readonly cancellableStatuses = new Set<BookingStatus>([
    BookingStatus.REQUESTED,
    BookingStatus.ACCEPTED,
    BookingStatus.DRIVER_ARRIVING,
  ]);
  private static readonly activeDriverTripStatuses = new Set<BookingStatus>([
    BookingStatus.ACCEPTED,
    BookingStatus.DRIVER_ARRIVING,
    BookingStatus.IN_PROGRESS,
  ]);
  private static readonly reassignableStatuses = new Set<BookingStatus>([
    BookingStatus.ACCEPTED,
    BookingStatus.DRIVER_ARRIVING,
  ]);
  private static readonly defaultFareModel = Object.freeze({
    baseFareGbp: 0,
    perKmMultiplier: 1,
    perMinuteRateGbp: 0,
    minFareGbp: 0,
    scheduledSurchargeGbp: 0,
    surgeMultiplier: 1,
  });
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    @InjectRepository(RideBooking)
    private readonly bookings: Repository<RideBooking>,
    @InjectRepository(User)
    private readonly users: Repository<User>,
    @InjectRepository(DriverCar)
    private readonly driverCars: Repository<DriverCar>,
    @InjectRepository(PaymentAttempt)
    private readonly paymentAttempts: Repository<PaymentAttempt>,
    @InjectRepository(DriverTripEarning)
    private readonly tripEarnings: Repository<DriverTripEarning>,
    @InjectRepository(RideBookingDriverLocation)
    private readonly rideBookingDriverLocations: Repository<RideBookingDriverLocation>,
    private readonly config: ConfigService,
    private readonly auth: AuthService,
    private readonly mail: MailService,
    private readonly notifications: NotificationsService,
    private readonly payments: PaymentsService,
  ) {}

  listCarOptions() {
    return {
      currencyCode: BOOKING_CAR_OPTIONS_CURRENCY_CODE,
      carOptions: BOOKING_CAR_OPTIONS.map((option) => ({ ...option })),
    };
  }

  async routePreview(input: {
    originLat: number;
    originLng: number;
    destinationLat: number;
    destinationLng: number;
  }) {
    this.assertValidCoordinates(input);

    const key = this.config.get<string>('GOOGLE_MAPS_API_KEY')?.trim();
    if (!key) {
      throw new BadRequestException(
        'Google Maps route service is not configured.',
      );
    }

    const params = new URLSearchParams({
      origin: `${input.originLat},${input.originLng}`,
      destination: `${input.destinationLat},${input.destinationLng}`,
      key,
      departure_time: 'now',
      traffic_model: 'best_guess',
    });
    const uri = `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`;

    let resp: Response;
    try {
      resp = await fetch(uri);
    } catch (error) {
      this.logger.warn(`Directions transport error: ${String(error)}`);
      throw new BadRequestException('Could not fetch route from Google Maps.');
    }

    if (!resp.ok) {
      this.logger.warn(`Directions HTTP status ${resp.status}`);
      throw new BadRequestException('Could not fetch route from Google Maps.');
    }

    const data = (await resp.json()) as Record<string, unknown>;
    const status = typeof data.status === 'string' ? data.status : 'UNKNOWN';
    if (status !== 'OK') {
      const errorMessage =
        typeof data.error_message === 'string' ? data.error_message : null;
      this.logger.warn(
        `Directions status ${status}${errorMessage ? `: ${errorMessage}` : ''}`,
      );
      throw new BadRequestException(
        `Google Maps directions failed with status ${status}.`,
      );
    }

    const routes = Array.isArray(data.routes) ? data.routes : [];
    const first = routes[0] as Record<string, unknown> | undefined;
    if (!first) {
      throw new BadRequestException('No route available for these locations.');
    }

    const overview = first.overview_polyline as Record<string, unknown> | null;
    const encodedPolyline =
      overview && typeof overview.points === 'string' ? overview.points : '';
    if (!encodedPolyline) {
      throw new BadRequestException('Route path is unavailable.');
    }

    const legs = Array.isArray(first.legs) ? first.legs : [];
    const leg0 = legs[0] as Record<string, unknown> | undefined;
    const distanceMeters = this.readNestedInt(leg0, 'distance', 'value');
    const durationSeconds = this.readNestedInt(leg0, 'duration', 'value');
    const durationInTrafficSeconds = this.readNestedInt(
      leg0,
      'duration_in_traffic',
      'value',
    );

    return {
      route: {
        encodedPolyline,
        distanceMeters,
        durationSeconds,
        durationInTrafficSeconds,
      },
    };
  }

  async createForCustomer(
    authorizationHeader: string | undefined,
    dto: CreateRideBookingDto,
  ) {
    const customerId =
      await this.auth.getAuthenticatedUserId(authorizationHeader);
    const customer = await this.users.findOne({ where: { id: customerId } });
    if (
      !customer ||
      customer.status !== UserStatus.ACTIVE ||
      !customer.isCustomer
    ) {
      throw new UnauthorizedException('Customer account unavailable');
    }
    if (
      dto.pickup.latitude === dto.dropoff.latitude &&
      dto.pickup.longitude === dto.dropoff.longitude
    ) {
      throw new BadRequestException('Pickup and drop-off cannot be the same');
    }
    const selectedCarOption = this.resolveCarOption(dto.car.id);
    if (!selectedCarOption) {
      throw new BadRequestException('Selected car type is not available');
    }
    if (!dto.route?.distanceMeters || dto.route.distanceMeters <= 0) {
      throw new BadRequestException(
        'Route distance is required to calculate charge amount.',
      );
    }
    const requestedAt = new Date();
    const scheduledFor = this.normalizeScheduledFor(
      dto.scheduledFor,
      requestedAt,
    );
    const chargeAmountMinor = this.calculateFareAmountMinor(
      dto.route.distanceMeters,
      dto.route?.durationSeconds ?? null,
      selectedCarOption.pricePerKmGbp,
      Boolean(scheduledFor),
    );
    const charge = await this.payments.chargeSavedCardForBooking({
      userId: customerId,
      paymentCardId: dto.payment.id.trim(),
      amountMinor: chargeAmountMinor,
      currencyCode: BOOKING_CAR_OPTIONS_CURRENCY_CODE,
      bookingDescription: `Ride booking ${dto.pickup.address.trim()} → ${dto.dropoff.address.trim()}`,
      metadata: {
        ride_flow: 'booking_finish',
        car_type_id: selectedCarOption.id,
      },
    });

    try {
      const booking = this.bookings.create({
        customerId,
        driverId: null,
        status: BookingStatus.REQUESTED,
        pickupAddress: dto.pickup.address.trim(),
        pickupLatitude: dto.pickup.latitude,
        pickupLongitude: dto.pickup.longitude,
        dropoffAddress: dto.dropoff.address.trim(),
        dropoffLatitude: dto.dropoff.latitude,
        dropoffLongitude: dto.dropoff.longitude,
        routeDistanceMeters: dto.route.distanceMeters,
        routeDurationSeconds: dto.route?.durationSeconds ?? null,
        routeDurationInTrafficSeconds:
          dto.route?.durationInTrafficSeconds ?? null,
        carTypeId: selectedCarOption.id,
        carTypeTitle: selectedCarOption.title,
        carSeats: selectedCarOption.seats,
        paymentMethodId: charge.paymentCard.id,
        paymentBrand: charge.paymentCard.brand.trim(),
        paymentMaskedNumber: `**** **** **** ${charge.paymentCard.last4}`,
        requestedAt,
        scheduledFor,
        scheduledReminderSentAt: null,
        acceptedAt: null,
      });

      const saved = await this.bookings.save(booking);
      await this.payments.attachPaymentAttemptToBooking(
        charge.attemptId,
        saved.id,
      );
      await this.notifications.createForCustomer({
        userId: customerId,
        kind: scheduledFor ? 'trip_scheduled' : 'trip_requested',
        title: scheduledFor ? 'Ride scheduled' : 'Ride requested',
        body: scheduledFor
          ? `Your ride is scheduled for ${scheduledFor.toISOString()}. Drivers can already accept it.`
          : 'Your ride request has been sent. We are finding a nearby driver.',
        metadata: {
          bookingId: saved.id,
          status: saved.status,
          chargeAmountMinor,
          chargeCurrency: BOOKING_CAR_OPTIONS_CURRENCY_CODE,
          scheduledFor: scheduledFor?.toISOString() ?? null,
        },
      });
      return { booking: this.toResponse(saved) };
    } catch (error) {
      await this.payments.refundBookingCharge(
        charge.attemptId,
        'Booking creation failed after charge',
      );
      throw error;
    }
  }

  async listForCustomer(
    authorizationHeader: string | undefined,
    query: ListRideBookingsQueryDto,
  ) {
    const customerId =
      await this.auth.getAuthenticatedUserId(authorizationHeader);
    const customer = await this.users.findOne({ where: { id: customerId } });
    if (
      !customer ||
      customer.status !== UserStatus.ACTIVE ||
      !customer.isCustomer
    ) {
      throw new UnauthorizedException('Customer account unavailable');
    }

    const limit = query.limit ?? BookingsService.defaultListLimit;
    const rows = await this.bookings.find({
      where: { customerId },
      order: { requestedAt: 'DESC', createdAt: 'DESC' },
      take: limit,
    });

    return {
      bookings: rows.map((row) => this.toResponse(row)),
    };
  }

  async listOpenForDriver(
    authorizationHeader: string | undefined,
    query: ListRideBookingsQueryDto,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const activeCar = await this.getActiveDriverCar(driverId);
    if (!activeCar) {
      return { bookings: [] };
    }
    const limit = query.limit ?? BookingsService.defaultListLimit;
    const rows = await this.bookings.find({
      where: {
        status: BookingStatus.REQUESTED,
        driverId: IsNull(),
        carTypeId: activeCar.carTypeId,
      },
      order: { requestedAt: 'DESC', createdAt: 'DESC' },
      take: limit,
    });
    return { bookings: rows.map((row) => this.toResponse(row)) };
  }

  async listForDriver(
    authorizationHeader: string | undefined,
    query: ListRideBookingsQueryDto,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const limit = query.limit ?? BookingsService.defaultListLimit;
    const rows = await this.bookings.find({
      where: { driverId },
      order: { requestedAt: 'DESC', createdAt: 'DESC' },
      take: limit,
    });
    return { bookings: rows.map((row) => this.toResponse(row)) };
  }

  async listEarningsForDriver(
    authorizationHeader: string | undefined,
    query: ListRideBookingsQueryDto,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const limit = query.limit ?? BookingsService.defaultListLimit;
    const rows = await this.tripEarnings.find({
      where: { driverId },
      order: { calculatedAt: 'DESC', createdAt: 'DESC' },
      take: limit,
    });
    const bookingIds = rows.map((row) => row.bookingId);
    const bookingsById =
      bookingIds.length === 0
        ? new Map<string, RideBooking>()
        : new Map(
            (
              await this.bookings.find({
                where: bookingIds.map((bookingId) => ({ id: bookingId })),
              })
            ).map((booking) => [booking.id, booking]),
          );

    return {
      earnings: rows.map((row) => this.toDriverEarningResponse(row, bookingsById)),
    };
  }

  async acceptForDriver(
    authorizationHeader: string | undefined,
    bookingId: string,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const activeTrip = await this.findActiveDriverTrip(driverId);
    if (activeTrip && activeTrip.id !== bookingId) {
      throw new ConflictException(
        'Finish or cancel your active trip before accepting another request',
      );
    }
    const existing = await this.bookings.findOne({ where: { id: bookingId } });
    if (!existing) {
      throw new NotFoundException('Trip not found');
    }
    if (
      existing.status !== BookingStatus.REQUESTED ||
      existing.driverId != null
    ) {
      throw new ConflictException('This trip is no longer available');
    }
    const activeCar = await this.getActiveDriverCar(driverId);
    if (!activeCar || activeCar.carTypeId !== existing.carTypeId) {
      throw new ConflictException(
        'Switch active car to the requested car type before accepting this trip',
      );
    }
    const acceptedAt = new Date();
    const updateResult = await this.bookings
      .createQueryBuilder()
      .update(RideBooking)
      .set({
        driverId,
        acceptedAt,
        status: BookingStatus.ACCEPTED,
      })
      .where('id = :bookingId', { bookingId })
      .andWhere('status = :status', { status: BookingStatus.REQUESTED })
      .andWhere('driver_id IS NULL')
      .execute();
    if (!updateResult.affected) {
      throw new ConflictException('This trip is no longer available');
    }
    const saved = await this.bookings.findOne({ where: { id: bookingId } });
    if (!saved) {
      throw new NotFoundException('Trip not found');
    }
    await this.notifications.createForUser({
      userId: saved.customerId,
      kind: 'trip_accepted',
      title: 'Driver assigned',
      body: 'A driver accepted your ride and is preparing to arrive.',
      metadata: { bookingId: saved.id, driverId },
    });
    await this.notifications.createForUser({
      userId: driverId,
      kind: 'trip_assigned',
      title: 'Trip accepted',
      body: 'You have accepted a new rider request.',
      metadata: { bookingId: saved.id, customerId: saved.customerId },
    });
    const [customer, driver] = await Promise.all([
      this.users.findOne({ where: { id: saved.customerId } }),
      this.users.findOne({ where: { id: driverId } }),
    ]);
    if (customer?.email) {
      try {
        await this.mail.sendTripAcceptedToCustomer({
          to: customer.email,
          pickupAddress: saved.pickupAddress,
          dropoffAddress: saved.dropoffAddress,
        });
      } catch (error) {
        this.logger.warn(
          `sendTripAcceptedToCustomer failed for ${customer.email}: ${(error as Error).message}`,
        );
      }
    }
    if (driver?.email) {
      try {
        await this.mail.sendTripAcceptedToDriver({
          to: driver.email,
          pickupAddress: saved.pickupAddress,
          dropoffAddress: saved.dropoffAddress,
        });
      } catch (error) {
        this.logger.warn(
          `sendTripAcceptedToDriver failed for ${driver.email}: ${(error as Error).message}`,
        );
      }
    }
    return { booking: this.toResponse(saved) };
  }

  async pickupForDriver(
    authorizationHeader: string | undefined,
    bookingId: string,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const booking = await this.bookings.findOne({
      where: { id: bookingId, driverId },
    });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    if (booking.status !== BookingStatus.DRIVER_ARRIVING) {
      throw new ConflictException(
        'Trip must be marked as driver arriving before pickup',
      );
    }
    booking.status = BookingStatus.IN_PROGRESS;
    const saved = await this.bookings.save(booking);
    await this.notifications.createForUser({
      userId: saved.customerId,
      kind: 'trip_started',
      title: 'Trip started',
      body: 'Your ride is now in progress.',
      metadata: { bookingId: saved.id, driverId },
    });
    return { booking: this.toResponse(saved) };
  }

  async arriveForDriver(
    authorizationHeader: string | undefined,
    bookingId: string,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const booking = await this.bookings.findOne({
      where: { id: bookingId, driverId },
    });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    if (booking.status !== BookingStatus.ACCEPTED) {
      throw new ConflictException(
        'Only accepted trips can be marked as driver arriving',
      );
    }
    booking.status = BookingStatus.DRIVER_ARRIVING;
    const saved = await this.bookings.save(booking);
    await this.notifications.createForUser({
      userId: saved.customerId,
      kind: 'trip_driver_arriving',
      title: 'Driver is arriving',
      body: 'Your driver is on the way to pickup.',
      metadata: { bookingId: saved.id, driverId },
    });
    return { booking: this.toResponse(saved) };
  }

  async finishForDriver(
    authorizationHeader: string | undefined,
    bookingId: string,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const booking = await this.bookings.findOne({
      where: { id: bookingId, driverId },
    });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    if (booking.status !== BookingStatus.IN_PROGRESS) {
      throw new ConflictException('Only in-progress trips can be finished');
    }
    booking.status = BookingStatus.COMPLETED;
    const saved = await this.bookings.save(booking);
    await this.calculateAndSaveDriverEarning(saved);
    await this.notifications.createForUser({
      userId: saved.customerId,
      kind: 'trip_completed',
      title: 'Trip completed',
      body: 'Your ride has been marked as completed.',
      metadata: { bookingId: saved.id, driverId },
    });
    return { booking: this.toResponse(saved) };
  }

  async processScheduledRideReminders(now: Date = new Date()) {
    const lookBack = new Date(now.getTime() - 5 * 60 * 1000);
    const lookAhead = new Date(now.getTime() + 10 * 60 * 1000);
    const rows = await this.bookings.find({
      where: {
        status: In([
          BookingStatus.ACCEPTED,
          BookingStatus.DRIVER_ARRIVING,
          BookingStatus.IN_PROGRESS,
        ]),
        driverId: Not(IsNull()),
        scheduledFor: Between(lookBack, lookAhead),
        scheduledReminderSentAt: IsNull(),
      },
      order: { scheduledFor: 'ASC' },
      take: 100,
    });
    for (const row of rows) {
      if (!row.driverId || !row.scheduledFor) {
        continue;
      }
      await this.notifications.createForUser({
        userId: row.driverId,
        kind: 'trip_schedule_reminder',
        title: 'Scheduled trip starts in 10 minutes',
        body: `Pickup at ${row.scheduledFor.toISOString()}.`,
        metadata: {
          bookingId: row.id,
          scheduledFor: row.scheduledFor.toISOString(),
        },
      });
      const driver = await this.users.findOne({ where: { id: row.driverId } });
      if (driver?.email) {
        try {
          await this.mail.sendScheduledTripReminderToDriver({
            to: driver.email,
            pickupAddress: row.pickupAddress,
            dropoffAddress: row.dropoffAddress,
            scheduledForIso: row.scheduledFor.toISOString(),
          });
        } catch (error) {
          this.logger.warn(
            `sendScheduledTripReminderToDriver failed for ${driver.email}: ${(error as Error).message}`,
          );
        }
      }
      row.scheduledReminderSentAt = now;
      await this.bookings.save(row);
    }
  }

  async cancelForDriver(
    authorizationHeader: string | undefined,
    bookingId: string,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const booking = await this.bookings.findOne({
      where: { id: bookingId, driverId },
    });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    if (!BookingsService.reassignableStatuses.has(booking.status)) {
      throw new ConflictException('Only assigned trips can be rejected');
    }
    const priorDriverId = booking.driverId;
    const saved = await this.reopenForReassignment(
      booking,
      'driver_rejected',
      null,
    );
    await this.notifications.createForUser({
      userId: saved.customerId,
      kind: 'trip_reopened',
      title: 'Finding another driver',
      body: 'Your previous driver rejected this trip. We are finding another driver now.',
      metadata: { bookingId: saved.id },
    });
    if (priorDriverId) {
      await this.notifications.createForUser({
        userId: priorDriverId,
        kind: 'trip_unassigned',
        title: 'Trip unassigned',
        body: 'You rejected this trip. It is available for other drivers now.',
        metadata: { bookingId: saved.id },
      });
    }
    await this.sendReassignmentEmails(
      saved,
      priorDriverId,
      'Driver rejected the trip assignment.',
    );
    return { booking: this.toResponse(saved) };
  }

  async cancelForCustomer(
    authorizationHeader: string | undefined,
    bookingId: string,
    dto: CancelRideBookingDto,
  ) {
    const customerId =
      await this.auth.getAuthenticatedUserId(authorizationHeader);
    const customer = await this.users.findOne({ where: { id: customerId } });
    if (
      !customer ||
      customer.status !== UserStatus.ACTIVE ||
      !customer.isCustomer
    ) {
      throw new UnauthorizedException('Customer account unavailable');
    }

    const booking = await this.bookings.findOne({
      where: { id: bookingId, customerId },
    });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    if (!BookingsService.cancellableStatuses.has(booking.status)) {
      throw new ConflictException('This trip can no longer be cancelled');
    }
    const reasonNote = dto.note?.trim() || null;

    if (
      BookingsService.reassignableStatuses.has(booking.status) &&
      booking.driverId
    ) {
      const priorDriverId = booking.driverId;
      const saved = await this.reopenForReassignment(
        booking,
        dto.reasonCode,
        reasonNote,
      );
      await this.notifications.createForUser({
        userId: customerId,
        kind: 'trip_reopened',
        title: 'Finding another driver',
        body: 'Your assigned driver was removed. We are finding another driver.',
        metadata: {
          bookingId: saved.id,
          reasonCode: dto.reasonCode,
        },
      });
      await this.notifications.createForUser({
        userId: priorDriverId,
        kind: 'trip_unassigned',
        title: 'Trip unassigned',
        body: 'Customer cancelled your assignment. The trip is available to other drivers.',
        metadata: {
          bookingId: saved.id,
          reasonCode: dto.reasonCode,
        },
      });
      await this.sendReassignmentEmails(
        saved,
        priorDriverId,
        'Customer requested another driver for this trip.',
      );
      return { booking: this.toResponse(saved) };
    }

    booking.status = BookingStatus.CANCELLED;
    booking.cancelledAt = new Date();
    booking.cancelReasonCode = dto.reasonCode;
    booking.cancelReasonNote = reasonNote;
    const saved = await this.bookings.save(booking);
    const refundAttempt = await this.findLatestSucceededPaymentAttempt(
      booking.id,
    );
    const refunded = Boolean(refundAttempt);
    if (refundAttempt) {
      await this.payments.refundBookingCharge(
        refundAttempt.id,
        'Customer cancelled trip before pickup',
      );
    }
    await this.notifications.createForCustomer({
      userId: customerId,
      kind: 'trip_cancelled',
      title: 'Trip cancelled',
      body: refunded
        ? 'Your trip was cancelled and a refund has been initiated.'
        : 'Your trip was cancelled successfully.',
      metadata: {
        bookingId: saved.id,
        reasonCode: dto.reasonCode,
        refundInitiated: refunded,
      },
    });
    return { booking: this.toResponse(saved) };
  }

  async updateDriverLocation(
    authorizationHeader: string | undefined,
    bookingId: string,
    dto: UpdateDriverLocationDto,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const booking = await this.bookings.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    if (booking.driverId !== driverId) {
      throw new UnauthorizedException(
        'Driver is not assigned to this booking.',
      );
    }
    if (!BookingsService.activeDriverTripStatuses.has(booking.status)) {
      throw new ConflictException('Driver location update is not allowed now.');
    }
    const now = new Date();
    const existing = await this.rideBookingDriverLocations.findOne({
      where: { bookingId },
    });
    const nextSample = this.rideBookingDriverLocations.create({
      id: existing?.id,
      bookingId,
      driverId,
      latitude: dto.latitude,
      longitude: dto.longitude,
      accuracyMeters: dto.accuracyMeters ?? null,
      recordedAt: now,
    });
    await this.rideBookingDriverLocations.save(nextSample);
    return {
      tracking: {
        bookingId,
        status: booking.status,
        driverLocation: {
          latitude: nextSample.latitude,
          longitude: nextSample.longitude,
          accuracyMeters: nextSample.accuracyMeters,
          recordedAt: now.toISOString(),
        },
      },
    };
  }

  async getTrackingForCustomer(
    authorizationHeader: string | undefined,
    bookingId: string,
  ) {
    const customerId =
      await this.auth.getAuthenticatedUserId(authorizationHeader);
    const customer = await this.users.findOne({ where: { id: customerId } });
    if (
      !customer ||
      customer.status !== UserStatus.ACTIVE ||
      !customer.isCustomer
    ) {
      throw new UnauthorizedException('Customer account unavailable');
    }
    const booking = await this.bookings.findOne({
      where: { id: bookingId, customerId },
    });
    if (!booking) {
      throw new NotFoundException('Trip not found');
    }
    const latestLocation = await this.rideBookingDriverLocations.findOne({
      where: { bookingId },
    });
    return {
      tracking: {
        booking: this.toResponse(booking),
        driverLocation: latestLocation
          ? {
              latitude: latestLocation.latitude,
              longitude: latestLocation.longitude,
              accuracyMeters: latestLocation.accuracyMeters,
              recordedAt: latestLocation.recordedAt.toISOString(),
              updatedAt: latestLocation.updatedAt?.toISOString() ?? null,
            }
          : null,
      },
    };
  }

  private async findLatestSucceededPaymentAttempt(
    bookingId: string,
  ): Promise<PaymentAttempt | null> {
    return this.paymentAttempts.findOne({
      where: {
        bookingId,
        status: PaymentAttemptStatus.SUCCEEDED,
      },
      order: { createdAt: 'DESC' },
    });
  }

  private toResponse(booking: RideBooking) {
    const carOption = this.resolveCarOption(booking.carTypeId);
    return {
      id: booking.id,
      status: booking.status,
      pickup: {
        address: booking.pickupAddress,
        latitude: booking.pickupLatitude,
        longitude: booking.pickupLongitude,
      },
      dropoff: {
        address: booking.dropoffAddress,
        latitude: booking.dropoffLatitude,
        longitude: booking.dropoffLongitude,
      },
      route: {
        distanceMeters: booking.routeDistanceMeters,
        durationSeconds: booking.routeDurationSeconds,
        durationInTrafficSeconds: booking.routeDurationInTrafficSeconds,
      },
      car: {
        id: booking.carTypeId,
        title: booking.carTypeTitle,
        seats: booking.carSeats,
        pricePerKmGbp: carOption?.pricePerKmGbp ?? null,
      },
      payment: {
        id: booking.paymentMethodId,
        brand: booking.paymentBrand,
        maskedNumber: booking.paymentMaskedNumber,
      },
      driver: {
        id: booking.driverId,
      },
      cancellation: {
        cancelledAt: booking.cancelledAt?.toISOString() ?? null,
        reasonCode: booking.cancelReasonCode,
        note: booking.cancelReasonNote,
      },
      canCancel: BookingsService.cancellableStatuses.has(booking.status),
      requestedAt: booking.requestedAt.toISOString(),
      scheduledFor: booking.scheduledFor?.toISOString() ?? null,
      acceptedAt: booking.acceptedAt?.toISOString() ?? null,
      createdAt: booking.createdAt?.toISOString(),
    };
  }

  private toDriverEarningResponse(
    row: DriverTripEarning,
    bookingsById: Map<string, RideBooking>,
  ) {
    const booking = bookingsById.get(row.bookingId);
    return {
      id: row.id,
      driverId: row.driverId,
      bookingId: row.bookingId,
      paymentAttemptId: row.paymentAttemptId,
      grossAmountMinor: row.grossAmountMinor,
      platformFeeMinor: row.platformFeeMinor,
      driverAmountMinor: row.driverAmountMinor,
      driverShareBps: row.driverShareBps,
      currencyCode: row.currencyCode,
      calculatedAt: row.calculatedAt.toISOString(),
      trip: booking
        ? {
            pickupAddress: booking.pickupAddress,
            dropoffAddress: booking.dropoffAddress,
            carTitle: booking.carTypeTitle,
            requestedAt: booking.requestedAt.toISOString(),
            completedAt: booking.updatedAt.toISOString(),
          }
        : null,
    };
  }

  private resolveCarOption(carId: string): BookingCarOptionConfig | null {
    const normalized = carId.trim().toLowerCase();
    for (const option of BOOKING_CAR_OPTIONS) {
      if (option.id.toLowerCase() === normalized) {
        return option;
      }
    }
    return null;
  }

  private assertValidCoordinates(input: {
    originLat: number;
    originLng: number;
    destinationLat: number;
    destinationLng: number;
  }) {
    const hasInvalid =
      Number.isNaN(input.originLat) ||
      Number.isNaN(input.originLng) ||
      Number.isNaN(input.destinationLat) ||
      Number.isNaN(input.destinationLng) ||
      input.originLat < -90 ||
      input.originLat > 90 ||
      input.destinationLat < -90 ||
      input.destinationLat > 90 ||
      input.originLng < -180 ||
      input.originLng > 180 ||
      input.destinationLng < -180 ||
      input.destinationLng > 180;
    if (hasInvalid) {
      throw new BadRequestException('Invalid route coordinates.');
    }
  }

  private readNestedInt(
    source: Record<string, unknown> | undefined,
    parentKey: string,
    childKey: string,
  ): number | null {
    if (!source) return null;
    const parent = source[parentKey];
    if (!parent || typeof parent !== 'object') return null;
    const value = (parent as Record<string, unknown>)[childKey];
    if (typeof value !== 'number' || Number.isNaN(value)) return null;
    return Math.trunc(value);
  }

  private calculateFareAmountMinor(
    distanceMeters: number,
    durationSeconds: number | null,
    pricePerKmGbp: number,
    isScheduled: boolean,
  ): number {
    const distanceKm = distanceMeters / 1000;
    const durationMinutes = (durationSeconds ?? 0) / 60;
    const fareModel = this.getFareModelConfig();
    const distanceFare = distanceKm * pricePerKmGbp * fareModel.perKmMultiplier;
    const timeFare = durationMinutes * fareModel.perMinuteRateGbp;
    const scheduledSurcharge = isScheduled ? fareModel.scheduledSurchargeGbp : 0;
    const subtotal = fareModel.baseFareGbp + distanceFare + timeFare + scheduledSurcharge;
    const surged = subtotal * fareModel.surgeMultiplier;
    const fareGbp = Math.max(fareModel.minFareGbp, surged);
    const amountMinor = Math.round(fareGbp * 100);
    if (amountMinor <= 0) {
      throw new BadRequestException('Charge amount must be greater than zero.');
    }
    return amountMinor;
  }

  private getFareModelConfig() {
    return {
      baseFareGbp: this.readConfigNumber(
        'FARE_BASE_GBP',
        BookingsService.defaultFareModel.baseFareGbp,
      ),
      perKmMultiplier: this.readConfigNumber(
        'FARE_PER_KM_MULTIPLIER',
        BookingsService.defaultFareModel.perKmMultiplier,
      ),
      perMinuteRateGbp: this.readConfigNumber(
        'FARE_PER_MINUTE_GBP',
        BookingsService.defaultFareModel.perMinuteRateGbp,
      ),
      minFareGbp: this.readConfigNumber(
        'FARE_MIN_GBP',
        BookingsService.defaultFareModel.minFareGbp,
      ),
      scheduledSurchargeGbp: this.readConfigNumber(
        'FARE_SCHEDULED_SURCHARGE_GBP',
        BookingsService.defaultFareModel.scheduledSurchargeGbp,
      ),
      surgeMultiplier: this.readConfigNumber(
        'FARE_SURGE_MULTIPLIER',
        BookingsService.defaultFareModel.surgeMultiplier,
      ),
    };
  }

  private readConfigNumber(key: string, fallback: number): number {
    const raw = this.config.get<string | number>(key);
    if (raw == null || raw === '') {
      return fallback;
    }
    const parsed = typeof raw === 'number' ? raw : Number(raw);
    if (Number.isNaN(parsed) || !Number.isFinite(parsed)) {
      return fallback;
    }
    return parsed;
  }

  private normalizeScheduledFor(
    scheduledForRaw: string | undefined,
    now: Date,
  ): Date | null {
    if (!scheduledForRaw?.trim()) {
      return null;
    }
    const scheduledFor = new Date(scheduledForRaw);
    if (Number.isNaN(scheduledFor.getTime())) {
      throw new BadRequestException('Scheduled ride time is invalid.');
    }
    const diffMinutes = Math.round(
      (scheduledFor.getTime() - now.getTime()) / 60000,
    );
    if (!BookingsService.scheduledOffsetsMinutes.includes(diffMinutes)) {
      throw new BadRequestException(
        'Scheduled ride must be exactly 10, 20, 30, 60, or 120 minutes from now.',
      );
    }
    return scheduledFor;
  }

  private async getAuthenticatedDriverId(
    authorizationHeader: string | undefined,
  ): Promise<string> {
    const userId = await this.auth.getAuthenticatedUserId(authorizationHeader);
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status !== UserStatus.ACTIVE || !user.isDriver) {
      throw new UnauthorizedException('Driver account unavailable');
    }
    if (!user.driverProfileCompleted) {
      throw new UnauthorizedException(
        'Complete driver profile before accessing driver trips',
      );
    }
    if (
      (user as User & { driverDocumentStatus?: DriverDocumentStatus })
        .driverDocumentStatus != null &&
      user.driverDocumentStatus !== DriverDocumentStatus.APPROVED
    ) {
      throw new UnauthorizedException(
        'Driver documents are pending manual approval',
      );
    }
    return user.id;
  }

  private async findActiveDriverTrip(driverId: string) {
    return this.bookings.findOne({
      where: [
        { driverId, status: BookingStatus.ACCEPTED },
        { driverId, status: BookingStatus.DRIVER_ARRIVING },
        { driverId, status: BookingStatus.IN_PROGRESS },
      ],
      order: { requestedAt: 'DESC', createdAt: 'DESC' },
    });
  }

  private async getActiveDriverCar(driverId: string) {
    return this.driverCars.findOne({
      where: { driverId, isActive: true },
      order: { updatedAt: 'DESC' },
    });
  }

  private async calculateAndSaveDriverEarning(booking: RideBooking) {
    const existing = await this.tripEarnings.findOne({
      where: { bookingId: booking.id },
    });
    if (existing) {
      return;
    }
    if (!booking.driverId) {
      return;
    }
    const attempt = await this.paymentAttempts.findOne({
      where: {
        bookingId: booking.id,
        status: PaymentAttemptStatus.SUCCEEDED,
      },
      order: { updatedAt: 'DESC' },
    });
    const grossAmountMinor =
      attempt?.capturedAmountMinor ?? attempt?.amountMinor ?? 0;
    if (grossAmountMinor <= 0) {
      this.logger.warn(
        `No successful payment attempt found for completed booking ${booking.id}; earning not stored.`,
      );
      return;
    }
    const driverAmountMinor = Math.round(
      (grossAmountMinor * BookingsService.driverShareBps) / 10_000,
    );
    const platformFeeMinor = grossAmountMinor - driverAmountMinor;
    const row = this.tripEarnings.create({
      driverId: booking.driverId,
      bookingId: booking.id,
      paymentAttemptId: attempt?.id ?? null,
      grossAmountMinor,
      platformFeeMinor,
      driverAmountMinor,
      driverShareBps: BookingsService.driverShareBps,
      currencyCode: (attempt?.currencyCode ?? 'GBP').toUpperCase(),
      calculatedAt: new Date(),
    });
    await this.tripEarnings.save(row);
  }

  private async reopenForReassignment(
    booking: RideBooking,
    reasonCode: string,
    reasonNote: string | null,
  ) {
    booking.status = BookingStatus.REQUESTED;
    booking.driverId = null;
    booking.acceptedAt = null;
    booking.cancelledAt = null;
    booking.cancelReasonCode = reasonCode;
    booking.cancelReasonNote = reasonNote;
    return this.bookings.save(booking);
  }

  private async sendReassignmentEmails(
    booking: RideBooking,
    priorDriverId: string | null,
    reason: string,
  ) {
    const [customer, priorDriver] = await Promise.all([
      this.users.findOne({ where: { id: booking.customerId } }),
      priorDriverId
        ? this.users.findOne({ where: { id: priorDriverId } })
        : Promise.resolve(null),
    ]);
    if (customer?.email) {
      try {
        await this.mail.sendTripReopenedToCustomer({
          to: customer.email,
          pickupAddress: booking.pickupAddress,
          dropoffAddress: booking.dropoffAddress,
          reason,
        });
      } catch (error) {
        this.logger.warn(
          `sendTripReopenedToCustomer failed for ${customer.email}: ${(error as Error).message}`,
        );
      }
    }
    if (priorDriver?.email) {
      try {
        await this.mail.sendTripUnassignedToDriver({
          to: priorDriver.email,
          pickupAddress: booking.pickupAddress,
          dropoffAddress: booking.dropoffAddress,
          reason,
        });
      } catch (error) {
        this.logger.warn(
          `sendTripUnassignedToDriver failed for ${priorDriver.email}: ${(error as Error).message}`,
        );
      }
    }
  }
}
