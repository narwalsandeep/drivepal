export interface PushMessagePayload {
  kind: string;
  title: string;
  body: string;
  metadata: Record<string, unknown>;
  createdAtIso: string;
}

export interface PushDispatchResult {
  ok: boolean;
  provider: 'sns' | 'fcm-web';
  providerMessageId?: string | null;
  error?: string | null;
}
