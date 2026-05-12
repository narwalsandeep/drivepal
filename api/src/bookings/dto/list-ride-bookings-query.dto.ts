import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class ListRideBookingsQueryDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}
