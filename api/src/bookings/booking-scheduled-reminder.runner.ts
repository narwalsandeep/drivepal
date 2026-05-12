import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';

@Injectable()
export class BookingScheduledReminderRunner
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(BookingScheduledReminderRunner.name);
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(private readonly bookings: BookingsService) {}

  onModuleInit() {
    this.timer = setInterval(() => {
      void this.tick();
    }, 60_000);
    void this.tick();
  }

  onModuleDestroy() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async tick() {
    if (this.running) {
      return;
    }
    this.running = true;
    try {
      await this.bookings.processScheduledRideReminders();
    } catch (error) {
      this.logger.warn(
        `Scheduled reminder run failed: ${(error as Error).message}`,
      );
    } finally {
      this.running = false;
    }
  }
}
