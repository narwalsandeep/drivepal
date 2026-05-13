import {
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

export class UpdateDriverLocationDto {
  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(10000)
  accuracyMeters?: number;
}
