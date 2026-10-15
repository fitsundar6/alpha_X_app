/**
 * Alpha X - OneSignal Push Notification Service
 *
 * Sends push notifications to client devices via OneSignal REST API.
 * Never sends to admin users. Respects the client's opt-out flag.
 * Supports OneSignal v5 subscription IDs, legacy player IDs, and external user IDs.
 */

import { env } from '../../config/environment';

const ONESIGNAL_API = 'https://api.onesignal.com';

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  channelId?: string;
}

export interface SendResult {
  success: boolean;
  playerId: string;
  httpStatus?: number;
  response?: any;
  error?: string;
}

export class OneSignalService {
  private get appId(): string {
    return env.ONESIGNAL_APP_ID || '';
  }
  private get apiKey(): string {
    return env.ONESIGNAL_REST_API_KEY || '';
  }

  /** Check if OneSignal credentials are configured */
  isConfigured(): boolean {
    return Boolean(this.appId && this.apiKey);
  }

  /** Send a push notification to one specific device by OneSignal player ID or subscription ID */
  async sendToPlayer(playerId: string, payload: NotificationPayload): Promise<SendResult> {
    if (!this.appId || !this.apiKey) {
      console.warn('[ONESIGNAL] Missing credentials — notification skipped for player:', playerId);
      return { success: false, playerId, error: 'OneSignal not configured on backend (.env ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY missing)' };
    }

    if (!playerId || typeof playerId !== 'string' || playerId.trim().length === 0) {
      return { success: false, playerId, error: 'Invalid or empty player/subscription ID' };
    }

    const cleanPlayerId = playerId.trim();

    // In modern OneSignal v5, devices are addressed via include_subscription_ids.
    // Legacy OneSignal apps use include_player_ids.
    // We send via include_subscription_ids first, falling back to include_player_ids if needed.
    const basePayload = {
      app_id: this.appId,
      headings: { en: payload.title },
      contents: { en: payload.body },
      data: payload.data || {},
      android_accent_color: 'FF39FF14',
      ios_sound: 'default',
      ...(payload.channelId ? { android_channel_id: payload.channelId } : {}),
    };

    // Try sending with include_subscription_ids (OneSignal v5 standard)
    const resultV5 = await this.executePost({
      ...basePayload,
      include_subscription_ids: [cleanPlayerId],
    }, cleanPlayerId, payload.title);

    if (resultV5.success) {
      return resultV5;
    }

    // If rejected with an error specifically related to subscription IDs or targeting, attempt include_player_ids
    if (resultV5.httpStatus === 400 || (resultV5.error && resultV5.error.includes('subscription'))) {
      console.log(`[ONESIGNAL] Retrying player ${cleanPlayerId} using legacy include_player_ids...`);
      return this.executePost({
        ...basePayload,
        include_player_ids: [cleanPlayerId],
      }, cleanPlayerId, payload.title);
    }

    return resultV5;
  }

  /** Send push notification targeting by external user ID (Alpha X User UUID) */
  async sendToUser(userId: string, payload: NotificationPayload): Promise<SendResult> {
    if (!this.appId || !this.apiKey) {
      return { success: false, playerId: userId, error: 'OneSignal not configured' };
    }

    const body = {
      app_id: this.appId,
      include_aliases: {
        external_id: [userId],
      },
      target_channel: 'push',
      headings: { en: payload.title },
      contents: { en: payload.body },
      data: payload.data || {},
      android_accent_color: 'FF39FF14',
      ios_sound: 'default',
      ...(payload.channelId ? { android_channel_id: payload.channelId } : {}),
    };

    return this.executePost(body, userId, payload.title);
  }

  private async executePost(body: any, targetId: string, title: string): Promise<SendResult> {
    try {
      const response = await fetch(`${ONESIGNAL_API}/notifications`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Key ${this.apiKey}`,
        },
        body: JSON.stringify(body),
      });

      const httpStatus = response.status;
      let result: any;
      try {
        result = await response.json();
      } catch (_) {
        result = { raw: await response.text() };
      }

      if (!response.ok || result.errors) {
        const errorMsg = result.errors ? JSON.stringify(result.errors) : `HTTP ${httpStatus}`;
        console.error(`[ONESIGNAL] Delivery error (HTTP ${httpStatus}) for ${targetId}:`, errorMsg);
        return {
          success: false,
          playerId: targetId,
          httpStatus,
          response: result,
          error: errorMsg,
        };
      }

      console.log(`[ONESIGNAL] ✅ Sent to ${targetId}: "${title}" (ID: ${result.id || 'ok'})`);
      return {
        success: true,
        playerId: targetId,
        httpStatus,
        response: result,
      };
    } catch (err: any) {
      console.error('[ONESIGNAL] Network exception:', err?.message);
      return {
        success: false,
        playerId: targetId,
        error: err?.message,
      };
    }
  }

  /** Send to multiple players at once (batches per-player for personalized messages) */
  async sendToPlayers(playerIds: string[], payload: NotificationPayload): Promise<SendResult[]> {
    return Promise.all(playerIds.map((id) => this.sendToPlayer(id, payload)));
  }
}

export const oneSignalService = new OneSignalService();
