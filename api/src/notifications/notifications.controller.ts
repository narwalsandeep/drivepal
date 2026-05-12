import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
} from '@nestjs/common';
import { ListNotificationsQueryDto } from './dto/list-notifications-query.dto';
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
}
