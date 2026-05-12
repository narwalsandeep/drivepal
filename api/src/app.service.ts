import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getWelcome() {
    return {
      name: 'DRIVEPAL',
      service: 'api',
      message: 'Base API is running. Use /api/health for database readiness.',
    };
  }
}
