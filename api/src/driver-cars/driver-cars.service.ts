import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthService } from '../auth/auth.service';
import { User } from '../auth/entities/user.entity';
import { UserStatus } from '../auth/enums/user-status.enum';
import { BOOKING_CAR_OPTIONS } from '../bookings/constants/car-options.constant';
import { CreateDriverCarDto, UpdateDriverCarDto } from './dto/driver-cars.dto';
import { DriverCar } from './entities/driver-car.entity';

@Injectable()
export class DriverCarsService {
  constructor(
    @InjectRepository(DriverCar)
    private readonly cars: Repository<DriverCar>,
    @InjectRepository(User)
    private readonly users: Repository<User>,
    private readonly auth: AuthService,
  ) {}

  async listMine(authorizationHeader: string | undefined) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const rows = await this.cars.find({
      where: { driverId },
      order: { isActive: 'DESC', createdAt: 'DESC' },
    });
    return {
      cars: rows.map((row) => this.toResponse(row)),
    };
  }

  async createMine(
    authorizationHeader: string | undefined,
    dto: CreateDriverCarDto,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const plateNormalized = this.normalizePlate(dto.plateNumber);
    await this.assertPlateAvailable(driverId, plateNormalized, null);
    const selectedCarType = this.resolveCarType(dto.carTypeId);
    if (!selectedCarType) {
      throw new ConflictException('Selected car type is not supported');
    }
    if (dto.isActive) {
      await this.deactivateOtherCars(driverId, null);
    }
    const saved = await this.cars.save(
      this.cars.create({
        driverId,
        displayName: dto.displayName.trim(),
        manufacturer: dto.manufacturer.trim(),
        model: dto.model.trim(),
        color: dto.color.trim(),
        plateNumber: dto.plateNumber.trim().toUpperCase(),
        plateNormalized,
        seatCapacity: dto.seatCapacity,
        carTypeId: selectedCarType.id,
        transmission: dto.transmission,
        isActive: dto.isActive,
        acceptsPets: dto.acceptsPets,
        hasAirConditioning: dto.hasAirConditioning,
        hasChildSeat: dto.hasChildSeat,
        wheelchairAccessible: dto.wheelchairAccessible,
      }),
    );
    return { car: this.toResponse(saved) };
  }

  async updateMine(
    authorizationHeader: string | undefined,
    carId: string,
    dto: UpdateDriverCarDto,
  ) {
    const driverId = await this.getAuthenticatedDriverId(authorizationHeader);
    const existing = await this.cars.findOne({
      where: { id: carId, driverId },
    });
    if (!existing) {
      throw new NotFoundException('Car not found');
    }
    if (dto.plateNumber != null) {
      const plateNormalized = this.normalizePlate(dto.plateNumber);
      await this.assertPlateAvailable(driverId, plateNormalized, existing.id);
      existing.plateNumber = dto.plateNumber.trim().toUpperCase();
      existing.plateNormalized = plateNormalized;
    }
    if (dto.displayName != null) existing.displayName = dto.displayName.trim();
    if (dto.manufacturer != null)
      existing.manufacturer = dto.manufacturer.trim();
    if (dto.model != null) existing.model = dto.model.trim();
    if (dto.color != null) existing.color = dto.color.trim();
    if (dto.seatCapacity != null) existing.seatCapacity = dto.seatCapacity;
    if (dto.carTypeId != null) {
      const selectedCarType = this.resolveCarType(dto.carTypeId);
      if (!selectedCarType) {
        throw new ConflictException('Selected car type is not supported');
      }
      existing.carTypeId = selectedCarType.id;
    }
    if (dto.transmission != null) existing.transmission = dto.transmission;
    if (dto.isActive != null) existing.isActive = dto.isActive;
    if (dto.acceptsPets != null) existing.acceptsPets = dto.acceptsPets;
    if (dto.hasAirConditioning != null) {
      existing.hasAirConditioning = dto.hasAirConditioning;
    }
    if (dto.hasChildSeat != null) existing.hasChildSeat = dto.hasChildSeat;
    if (dto.wheelchairAccessible != null) {
      existing.wheelchairAccessible = dto.wheelchairAccessible;
    }
    if (existing.isActive) {
      await this.deactivateOtherCars(driverId, existing.id);
    }
    const saved = await this.cars.save(existing);
    return { car: this.toResponse(saved) };
  }

  private toResponse(car: DriverCar) {
    const carType = this.resolveCarType(car.carTypeId);
    return {
      id: car.id,
      displayName: car.displayName,
      manufacturer: car.manufacturer,
      model: car.model,
      color: car.color,
      plateNumber: car.plateNumber,
      seatCapacity: car.seatCapacity,
      carType: {
        id: car.carTypeId,
        title: carType?.title ?? car.carTypeId,
        subtitle: carType?.subtitle ?? null,
        pricePerKmGbp: carType?.pricePerKmGbp ?? null,
      },
      transmission: car.transmission,
      isActive: car.isActive,
      features: {
        acceptsPets: car.acceptsPets,
        hasAirConditioning: car.hasAirConditioning,
        hasChildSeat: car.hasChildSeat,
        wheelchairAccessible: car.wheelchairAccessible,
      },
      createdAt: car.createdAt.toISOString(),
      updatedAt: car.updatedAt.toISOString(),
    };
  }

  private normalizePlate(plateNumber: string) {
    return plateNumber.replace(/\s+/g, '').trim().toUpperCase();
  }

  private resolveCarType(carTypeId: string) {
    const normalized = carTypeId.trim().toLowerCase();
    return BOOKING_CAR_OPTIONS.find(
      (option) => option.id.toLowerCase() === normalized,
    );
  }

  private async assertPlateAvailable(
    driverId: string,
    plateNormalized: string,
    exceptCarId: string | null,
  ) {
    const existing = await this.cars.findOne({
      where: { driverId, plateNormalized },
      select: { id: true },
    });
    if (existing && existing.id !== exceptCarId) {
      throw new ConflictException('A car with this plate already exists');
    }
  }

  private async getAuthenticatedDriverId(
    authorizationHeader: string | undefined,
  ): Promise<string> {
    const userId = await this.auth.getAuthenticatedUserId(authorizationHeader);
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || user.status !== UserStatus.ACTIVE || !user.isDriver) {
      throw new UnauthorizedException('Driver account unavailable');
    }
    if (!user.driverProfileCompleted) {
      throw new UnauthorizedException(
        'Complete driver profile before managing cars',
      );
    }
    return user.id;
  }

  private async deactivateOtherCars(
    driverId: string,
    exceptCarId: string | null,
  ) {
    const rows = await this.cars.find({ where: { driverId, isActive: true } });
    for (const row of rows) {
      if (exceptCarId != null && row.id === exceptCarId) {
        continue;
      }
      row.isActive = false;
      await this.cars.save(row);
    }
  }
}
