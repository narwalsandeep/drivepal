import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CreatePlatformEndpointCommand,
  DeleteEndpointCommand,
  GetEndpointAttributesCommand,
  PublishCommand,
  SetEndpointAttributesCommand,
  SNSClient,
} from '@aws-sdk/client-sns';
import { PushDevicePlatform } from '../enums/push-device-platform.enum';
import { PushDispatchResult, PushMessagePayload } from './push-message.types';

@Injectable()
export class SnsMobilePushService {
  private readonly logger = new Logger(SnsMobilePushService.name);
  private readonly snsClient: SNSClient | null;
  private readonly androidPlatformApplicationArn: string | null;
  private readonly iosPlatformApplicationArn: string | null;

  constructor(private readonly config: ConfigService) {
    const region = this.config.get<string>('AWS_REGION')?.trim();
    if (!region) {
      this.snsClient = null;
      this.androidPlatformApplicationArn = null;
      this.iosPlatformApplicationArn = null;
      return;
    }

    this.androidPlatformApplicationArn =
      this.config
        .get<string>('AWS_SNS_PLATFORM_APPLICATION_ARN_ANDROID')
        ?.trim() || null;
    this.iosPlatformApplicationArn =
      this.config.get<string>('AWS_SNS_PLATFORM_APPLICATION_ARN_IOS')?.trim() ||
      null;

    this.snsClient = new SNSClient({
      region,
      credentials: {
        accessKeyId: this.config.get<string>('AWS_ACCESS_KEY_ID')?.trim() ?? '',
        secretAccessKey:
          this.config.get<string>('AWS_SECRET_ACCESS_KEY')?.trim() ?? '',
      },
    });
  }

  isConfigured(): boolean {
    return (
      this.snsClient != null &&
      this.androidPlatformApplicationArn != null &&
      this.iosPlatformApplicationArn != null
    );
  }

  async registerOrUpdateEndpoint(input: {
    platform: PushDevicePlatform.ANDROID | PushDevicePlatform.IOS;
    deviceToken: string;
    existingEndpointArn?: string | null;
  }): Promise<string> {
    if (!this.snsClient) {
      throw new Error('AWS SNS is not configured.');
    }
    const platformApplicationArn = this.resolvePlatformApplicationArn(
      input.platform,
    );
    if (!platformApplicationArn) {
      throw new Error(
        `SNS platform application is not configured for ${input.platform}.`,
      );
    }

    const normalizedToken = input.deviceToken.trim();
    if (!normalizedToken) {
      throw new Error('Device token is required to register SNS endpoint.');
    }

    if (input.existingEndpointArn) {
      try {
        await this.ensureEndpointMatchesToken(
          input.existingEndpointArn,
          normalizedToken,
        );
        return input.existingEndpointArn;
      } catch (error) {
        this.logger.warn(
          `Failed to reuse SNS endpoint ${input.existingEndpointArn}: ${(error as Error).message}`,
        );
      }
    }

    const created = await this.snsClient.send(
      new CreatePlatformEndpointCommand({
        PlatformApplicationArn: platformApplicationArn,
        Token: normalizedToken,
      }),
    );
    const endpointArn = created.EndpointArn?.trim();
    if (!endpointArn) {
      throw new Error('SNS did not return endpoint ARN.');
    }
    await this.ensureEndpointMatchesToken(endpointArn, normalizedToken);
    return endpointArn;
  }

  async deleteEndpoint(endpointArn: string): Promise<void> {
    if (!this.snsClient || !endpointArn.trim()) {
      return;
    }
    try {
      await this.snsClient.send(
        new DeleteEndpointCommand({
          EndpointArn: endpointArn,
        }),
      );
    } catch (error) {
      this.logger.warn(
        `Failed to delete SNS endpoint ${endpointArn}: ${(error as Error).message}`,
      );
    }
  }

  async publishToEndpoint(input: {
    endpointArn: string;
    payload: PushMessagePayload;
  }): Promise<PushDispatchResult> {
    if (!this.snsClient) {
      return {
        ok: false,
        provider: 'sns',
        error: 'SNS is not configured.',
      };
    }
    const endpointArn = input.endpointArn.trim();
    if (!endpointArn) {
      return {
        ok: false,
        provider: 'sns',
        error: 'Missing endpoint ARN.',
      };
    }
    try {
      const response = await this.snsClient.send(
        new PublishCommand({
          TargetArn: endpointArn,
          MessageStructure: 'json',
          Message: JSON.stringify({
            default: input.payload.body,
            GCM: JSON.stringify({
              notification: {
                title: input.payload.title,
                body: input.payload.body,
              },
              data: {
                kind: input.payload.kind,
                createdAt: input.payload.createdAtIso,
                metadata: JSON.stringify(input.payload.metadata),
              },
            }),
            APNS: JSON.stringify({
              aps: {
                alert: {
                  title: input.payload.title,
                  body: input.payload.body,
                },
                sound: 'default',
              },
              kind: input.payload.kind,
              createdAt: input.payload.createdAtIso,
              metadata: input.payload.metadata,
            }),
          }),
        }),
      );
      return {
        ok: true,
        provider: 'sns',
        providerMessageId: response.MessageId ?? null,
      };
    } catch (error) {
      return {
        ok: false,
        provider: 'sns',
        error: (error as Error).message,
      };
    }
  }

  private resolvePlatformApplicationArn(
    platform: PushDevicePlatform.ANDROID | PushDevicePlatform.IOS,
  ): string | null {
    if (platform === PushDevicePlatform.ANDROID) {
      return this.androidPlatformApplicationArn;
    }
    return this.iosPlatformApplicationArn;
  }

  private async ensureEndpointMatchesToken(
    endpointArn: string,
    token: string,
  ): Promise<void> {
    if (!this.snsClient) return;
    try {
      const existing = await this.snsClient.send(
        new GetEndpointAttributesCommand({ EndpointArn: endpointArn }),
      );
      const existingToken = existing.Attributes?.Token ?? '';
      const existingEnabled = existing.Attributes?.Enabled ?? 'true';
      if (existingToken === token && existingEnabled === 'true') {
        return;
      }
    } catch {
      // Endpoint could be stale or deleted; set attributes below will recreate state if possible.
    }
    await this.snsClient.send(
      new SetEndpointAttributesCommand({
        EndpointArn: endpointArn,
        Attributes: {
          Token: token,
          Enabled: 'true',
        },
      }),
    );
  }
}
