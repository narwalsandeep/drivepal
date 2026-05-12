import {
  IsDefined,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsISO8601,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class BookingStopDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  address: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}

export class BookingRouteDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000000)
  distanceMeters?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(86400)
  durationSeconds?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(86400)
  durationInTrafficSeconds?: number;
}

export class BookingCarDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  id: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string;

  @IsInt()
  @Min(1)
  @Max(12)
  seats: number;
}

export class BookingPaymentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  id: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  brand: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  maskedNumber: string;
}

export class CreateRideBookingDto {
  @IsDefined()
  @ValidateNested()
  @Type(() => BookingStopDto)
  pickup: BookingStopDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => BookingStopDto)
  dropoff: BookingStopDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => BookingRouteDto)
  route?: BookingRouteDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => BookingCarDto)
  car: BookingCarDto;

  @IsDefined()
  @ValidateNested()
  @Type(() => BookingPaymentDto)
  payment: BookingPaymentDto;

  @IsOptional()
  @IsISO8601()
  scheduledFor?: string;
}
