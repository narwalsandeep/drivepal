import { IsString, MaxLength } from 'class-validator';

export class CreateWebSetupSessionDto {
  @IsString()
  @MaxLength(1024)
  returnUrl: string;
}
