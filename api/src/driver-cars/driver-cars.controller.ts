import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { CreateDriverCarDto, UpdateDriverCarDto } from './dto/driver-cars.dto';
import { DriverCarsService } from './driver-cars.service';

@Controller('driver-cars')
export class DriverCarsController {
  constructor(private readonly cars: DriverCarsService) {}

  @Get('me')
  @HttpCode(HttpStatus.OK)
  listMine(@Headers('authorization') authorization: string | undefined) {
    return this.cars.listMine(authorization);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: CreateDriverCarDto,
  ) {
    return this.cars.createMine(authorization, dto);
  }

  @Patch(':carId')
  @HttpCode(HttpStatus.OK)
  update(
    @Headers('authorization') authorization: string | undefined,
    @Param('carId', ParseUUIDPipe) carId: string,
    @Body() dto: UpdateDriverCarDto,
  ) {
    return this.cars.updateMine(authorization, carId, dto);
  }
}
