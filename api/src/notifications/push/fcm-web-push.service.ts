import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JWT } from 'google-auth-library';
import https from 'https';
import { PushDispatchResult, PushMessagePayload } from './push-message.types';

interface FcmServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

@Injectable()
export class FcmWebPushService {
  private readonly serviceAccount: FcmServiceAccount | null;

  constructor(private readonly config: ConfigService) {
    const raw = this.config.get<string>('FCM_WEB_SERVICE_ACCOUNT_JSON')?.trim();
    if (!raw) {
      this.serviceAccount = null;
      return;
    }
    try {
      const parsed = JSON.parse(raw) as Partial<FcmServiceAccount>;
      if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
        this.serviceAccount = null;
        return;
      }
      this.serviceAccount = {
        client_email: parsed.client_email,
        private_key: parsed.private_key,
        project_id: parsed.project_id,
      };
    } catch {
      this.serviceAccount = null;
    }
  }

  isConfigured(): boolean {
    return this.serviceAccount != null;
  }

  async publishToToken(input: {
    token: string;
    payload: PushMessagePayload;
  }): Promise<PushDispatchResult> {
    if (!this.serviceAccount) {
      return {
        ok: false,
        provider: 'fcm-web',
        error: 'FCM web service account is not configured.',
      };
    }

    try {
      const accessToken = await this.fetchAccessToken();
      const body = JSON.stringify({
        message: {
          token: input.token,
          notification: {
            title: input.payload.title,
            body: input.payload.body,
          },
          data: {
            kind: input.payload.kind,
            createdAt: input.payload.createdAtIso,
            metadata: JSON.stringify(input.payload.metadata),
          },
          webpush: {
            headers: {
              Urgency: 'high',
            },
          },
        },
      });

      const path = `/v1/projects/${this.serviceAccount.project_id}/messages:send`;
      const response = await this.httpsRequest({
        hostname: 'fcm.googleapis.com',
        path,
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
        body,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        const parsed = JSON.parse(response.body || '{}') as {
          name?: string;
        };
        return {
          ok: true,
          provider: 'fcm-web',
          providerMessageId: parsed.name ?? null,
        };
      }
      return {
        ok: false,
        provider: 'fcm-web',
        error: `FCM web push failed (${response.statusCode}): ${response.body}`,
      };
    } catch (error) {
      return {
        ok: false,
        provider: 'fcm-web',
        error: (error as Error).message,
      };
    }
  }

  private async fetchAccessToken(): Promise<string> {
    if (!this.serviceAccount) {
      throw new Error('FCM web service account is not configured.');
    }
    const jwt = new JWT({
      email: this.serviceAccount.client_email,
      key: this.serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    const result = await jwt.authorize();
    const token = result.access_token?.toString().trim();
    if (!token) {
      throw new Error('Failed to obtain FCM web access token.');
    }
    return token;
  }

  private async httpsRequest(input: {
    hostname: string;
    path: string;
    method: 'POST';
    headers: Record<string, string | number>;
    body: string;
  }): Promise<{ statusCode: number; body: string }> {
    return new Promise((resolve, reject) => {
      const req = https.request(
        {
          hostname: input.hostname,
          path: input.path,
          method: input.method,
          headers: input.headers,
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => {
            resolve({
              statusCode: res.statusCode ?? 500,
              body: Buffer.concat(chunks).toString('utf8'),
            });
          });
        },
      );
      req.on('error', reject);
      req.write(input.body);
      req.end();
    });
  }
}
