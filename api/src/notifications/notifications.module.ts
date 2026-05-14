import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { User } from '../auth/entities/user.entity';
import { Notification } from './entities/notification.entity';
import { PushDevice } from './entities/push-device.entity';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { FcmWebPushService } from './push/fcm-web-push.service';
import { PushDispatcherService } from './push/push-dispatcher.service';
import { SnsMobilePushService } from './push/sns-mobile-push.service';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([Notification, PushDevice, User]),
  ],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    SnsMobilePushService,
    FcmWebPushService,
    PushDispatcherService,
  ],
  exports: [NotificationsService, PushDispatcherService],
})
export class NotificationsModule {}
