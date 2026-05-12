import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { User } from '../auth/entities/user.entity';
import { DriverCarsController } from './driver-cars.controller';
import { DriverCarsService } from './driver-cars.service';
import { DriverCar } from './entities/driver-car.entity';

@Module({
  imports: [AuthModule, TypeOrmModule.forFeature([DriverCar, User])],
  controllers: [DriverCarsController],
  providers: [DriverCarsService],
})
export class DriverCarsModule {}
