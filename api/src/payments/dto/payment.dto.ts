import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RemoveCardParamsDto {
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  cardId: string;
}

export class SyncCardsDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  stripeCustomerId?: string;
}
