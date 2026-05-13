import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { User } from '../auth/entities/user.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { BookingScheduledReminderRunner } from './booking-scheduled-reminder.runner';
import { DriverCar } from '../driver-cars/entities/driver-car.entity';
import { PaymentAttempt } from '../payments/entities/payment-attempt.entity';
import { DriverTripEarning } from './entities/driver-trip-earning.entity';
import { RideBooking } from './entities/ride-booking.entity';
import { RideBookingDriverLocation } from './entities/ride-booking-driver-location.entity';

@Module({
  imports: [
    AuthModule,
    NotificationsModule,
    PaymentsModule,
    TypeOrmModule.forFeature([
      RideBooking,
      User,
      DriverCar,
      PaymentAttempt,
      DriverTripEarning,
      RideBookingDriverLocation,
    ]),
  ],
  controllers: [BookingsController],
  providers: [BookingsService, BookingScheduledReminderRunner],
})
export class BookingsModule {}
