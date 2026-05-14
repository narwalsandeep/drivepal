import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PushDevice } from '../entities/push-device.entity';
import { PushDevicePlatform } from '../enums/push-device-platform.enum';
import { FcmWebPushService } from './fcm-web-push.service';
import { PushDispatchResult, PushMessagePayload } from './push-message.types';
import { SnsMobilePushService } from './sns-mobile-push.service';

@Injectable()
export class PushDispatcherService {
  constructor(
    @InjectRepository(PushDevice)
    private readonly pushDevices: Repository<PushDevice>,
    private readonly snsMobilePush: SnsMobilePushService,
    private readonly fcmWebPush: FcmWebPushService,
  ) {}

  isAnyTransportConfigured(): boolean {
    return this.snsMobilePush.isConfigured() || this.fcmWebPush.isConfigured();
  }

  async dispatchToUser(input: {
    userId: string;
    payload: PushMessagePayload;
  }): Promise<void> {
    const devices = await this.pushDevices.find({
      where: { userId: input.userId, isActive: true },
    });
    if (devices.length === 0) {
      return;
    }

    const updatePromises = devices.map(async (device) => {
      const result = await this.dispatchToDevice(device, input.payload);
      await this.applyDispatchResult(device, result);
    });
    await Promise.all(updatePromises);
  }

  async registerMobileEndpoint(input: {
    platform: PushDevicePlatform.ANDROID | PushDevicePlatform.IOS;
    deviceToken: string;
    existingEndpointArn?: string | null;
  }): Promise<string> {
    return this.snsMobilePush.registerOrUpdateEndpoint(input);
  }

  async deleteMobileEndpoint(endpointArn: string): Promise<void> {
    await this.snsMobilePush.deleteEndpoint(endpointArn);
  }

  private async dispatchToDevice(
    device: PushDevice,
    payload: PushMessagePayload,
  ): Promise<PushDispatchResult> {
    if (device.platform === PushDevicePlatform.WEB) {
      return this.fcmWebPush.publishToToken({
        token: device.deviceToken,
        payload,
      });
    }
    if (!device.snsEndpointArn) {
      return {
        ok: false,
        provider: 'sns',
        error: 'Missing SNS endpoint ARN on mobile push device.',
      };
    }
    return this.snsMobilePush.publishToEndpoint({
      endpointArn: device.snsEndpointArn,
      payload,
    });
  }

  private async applyDispatchResult(
    device: PushDevice,
    result: PushDispatchResult,
  ): Promise<void> {
    device.lastSeenAt = new Date();
    if (result.ok) {
      device.lastError = null;
      if (!device.isActive) {
        device.isActive = true;
      }
      await this.pushDevices.save(device);
      return;
    }

    const error = (result.error ?? '').toLowerCase();
    const shouldDeactivate =
      error.includes('endpoint') ||
      error.includes('token') ||
      error.includes('unregistered') ||
      error.includes('notregistered');
    if (shouldDeactivate) {
      device.isActive = false;
    }
    device.lastError = result.error ?? 'Push dispatch failed.';
    await this.pushDevices.save(device);
  }
}
