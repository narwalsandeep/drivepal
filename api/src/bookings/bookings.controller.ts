import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseFloatPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CancelRideBookingDto } from './dto/cancel-ride-booking.dto';
import { CreateRideBookingDto } from './dto/create-ride-booking.dto';
import { UpdateDriverLocationDto } from './dto/driver-location.dto';
import { ListRideBookingsQueryDto } from './dto/list-ride-bookings-query.dto';

@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: CreateRideBookingDto,
  ) {
    return this.bookings.createForCustomer(authorization, dto);
  }

  @Get('car-options')
  @HttpCode(HttpStatus.OK)
  listCarOptions() {
    return this.bookings.listCarOptions();
  }

  @Get('route')
  @HttpCode(HttpStatus.OK)
  routePreview(
    @Query('originLat', ParseFloatPipe) originLat: number,
    @Query('originLng', ParseFloatPipe) originLng: number,
    @Query('destinationLat', ParseFloatPipe) destinationLat: number,
    @Query('destinationLng', ParseFloatPipe) destinationLng: number,
  ) {
    return this.bookings.routePreview({
      originLat,
      originLng,
      destinationLat,
      destinationLng,
    });
  }

  @Get('me')
  @HttpCode(HttpStatus.OK)
  listMine(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ListRideBookingsQueryDto,
  ) {
    return this.bookings.listForCustomer(authorization, query);
  }

  @Get('driver/new')
  @HttpCode(HttpStatus.OK)
  listNewForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ListRideBookingsQueryDto,
  ) {
    return this.bookings.listOpenForDriver(authorization, query);
  }

  @Get('driver/me')
  @HttpCode(HttpStatus.OK)
  listMineForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ListRideBookingsQueryDto,
  ) {
    return this.bookings.listForDriver(authorization, query);
  }

  @Get('driver/earnings')
  @HttpCode(HttpStatus.OK)
  listEarningsForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ListRideBookingsQueryDto,
  ) {
    return this.bookings.listEarningsForDriver(authorization, query);
  }

  @Patch(':bookingId/accept')
  @HttpCode(HttpStatus.OK)
  acceptForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ) {
    return this.bookings.acceptForDriver(authorization, bookingId);
  }

  @Patch(':bookingId/pickup')
  @HttpCode(HttpStatus.OK)
  pickupForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ) {
    return this.bookings.pickupForDriver(authorization, bookingId);
  }

  @Patch(':bookingId/arrive')
  @HttpCode(HttpStatus.OK)
  arriveForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ) {
    return this.bookings.arriveForDriver(authorization, bookingId);
  }

  @Patch(':bookingId/finish')
  @HttpCode(HttpStatus.OK)
  finishForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ) {
    return this.bookings.finishForDriver(authorization, bookingId);
  }

  @Patch(':bookingId/driver-cancel')
  @HttpCode(HttpStatus.OK)
  cancelForDriver(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ) {
    return this.bookings.cancelForDriver(authorization, bookingId);
  }

  @Patch(':bookingId/driver-location')
  @HttpCode(HttpStatus.OK)
  updateDriverLocation(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
    @Body() dto: UpdateDriverLocationDto,
  ) {
    return this.bookings.updateDriverLocation(authorization, bookingId, dto);
  }

  @Patch(':bookingId/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
    @Body() dto: CancelRideBookingDto,
  ) {
    return this.bookings.cancelForCustomer(authorization, bookingId, dto);
  }

  @Get(':bookingId/tracking')
  @HttpCode(HttpStatus.OK)
  trackingForCustomer(
    @Headers('authorization') authorization: string | undefined,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ) {
    return this.bookings.getTrackingForCustomer(authorization, bookingId);
  }
}
