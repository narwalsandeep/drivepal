import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ListNotificationsQueryDto } from './dto/list-notifications-query.dto';
import {
  RegisterPushDeviceDto,
  UnregisterPushDeviceDto,
} from './dto/push-device.dto';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('me')
  @HttpCode(HttpStatus.OK)
  listMine(
    @Headers('authorization') authorization: string | undefined,
    @Query() query: ListNotificationsQueryDto,
  ) {
    return this.notifications.listForCustomer(authorization, query);
  }

  @Patch(':notificationId/read')
  @HttpCode(HttpStatus.OK)
  markRead(
    @Headers('authorization') authorization: string | undefined,
    @Param('notificationId', ParseUUIDPipe) notificationId: string,
  ) {
    return this.notifications.markRead(authorization, notificationId);
  }

  @Post('devices/register')
  @HttpCode(HttpStatus.OK)
  registerDevice(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: RegisterPushDeviceDto,
  ) {
    return this.notifications.registerPushDevice(authorization, dto);
  }

  @Delete('devices/:deviceId')
  @HttpCode(HttpStatus.OK)
  unregisterDeviceById(
    @Headers('authorization') authorization: string | undefined,
    @Param('deviceId', ParseUUIDPipe) deviceId: string,
  ) {
    return this.notifications.unregisterPushDeviceById(authorization, deviceId);
  }

  @Post('devices/unregister')
  @HttpCode(HttpStatus.OK)
  unregisterDevice(
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: UnregisterPushDeviceDto,
  ) {
    return this.notifications.unregisterPushDevice(authorization, dto);
  }
}
