import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { PushDevicePlatform } from '../enums/push-device-platform.enum';

export class RegisterPushDeviceDto {
  @IsEnum(PushDevicePlatform)
  platform: PushDevicePlatform;

  @IsString()
  @MinLength(20)
  @MaxLength(2048)
  deviceToken: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  appVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  deviceLabel?: string;
}

export class UnregisterPushDeviceDto {
  @IsEnum(PushDevicePlatform)
  platform: PushDevicePlatform;

  @IsString()
  @MinLength(20)
  @MaxLength(2048)
  deviceToken: string;
}
