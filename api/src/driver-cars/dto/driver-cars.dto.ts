import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const CAR_TYPE_IDS = ['sedan4', 'mpv5', 'suv6', 'van7', 'van8'] as const;
const TRANSMISSIONS = ['automatic', 'manual'] as const;

export class CreateDriverCarDto {
  @IsString()
  @MaxLength(50)
  displayName: string;

  @IsString()
  @MaxLength(60)
  manufacturer: string;

  @IsString()
  @MaxLength(60)
  model: string;

  @IsString()
  @MaxLength(40)
  color: string;

  @IsString()
  @MaxLength(24)
  plateNumber: string;

  @IsInt()
  @Min(2)
  @Max(8)
  seatCapacity: number;

  @IsString()
  @IsIn(CAR_TYPE_IDS)
  carTypeId: (typeof CAR_TYPE_IDS)[number];

  @IsString()
  @IsIn(TRANSMISSIONS)
  transmission: (typeof TRANSMISSIONS)[number];

  @IsBoolean()
  isActive: boolean;

  @IsBoolean()
  acceptsPets: boolean;

  @IsBoolean()
  hasAirConditioning: boolean;

  @IsBoolean()
  hasChildSeat: boolean;

  @IsBoolean()
  wheelchairAccessible: boolean;
}

export class UpdateDriverCarDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  manufacturer?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  model?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  color?: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  plateNumber?: string;

  @IsOptional()
  @IsInt()
  @Min(2)
  @Max(8)
  seatCapacity?: number;

  @IsOptional()
  @IsString()
  @IsIn(CAR_TYPE_IDS)
  carTypeId?: (typeof CAR_TYPE_IDS)[number];

  @IsOptional()
  @IsString()
  @IsIn(TRANSMISSIONS)
  transmission?: (typeof TRANSMISSIONS)[number];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  acceptsPets?: boolean;

  @IsOptional()
  @IsBoolean()
  hasAirConditioning?: boolean;

  @IsOptional()
  @IsBoolean()
  hasChildSeat?: boolean;

  @IsOptional()
  @IsBoolean()
  wheelchairAccessible?: boolean;
}
