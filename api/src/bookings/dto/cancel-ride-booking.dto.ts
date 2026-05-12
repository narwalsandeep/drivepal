import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export const bookingCancelReasons = [
  'change_of_plans',
  'driver_delay',
  'pickup_changed',
  'booked_by_mistake',
  'fare_concern',
  'other',
] as const;

export type BookingCancelReasonCode = (typeof bookingCancelReasons)[number];

export class CancelRideBookingDto {
  @IsIn(bookingCancelReasons)
  reasonCode: BookingCancelReasonCode;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}
