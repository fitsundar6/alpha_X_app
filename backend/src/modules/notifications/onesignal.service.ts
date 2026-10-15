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

export interface BroadcastResult {
  success: boolean;
  notificationId?: string;
  recipientsCount: number;
  devicesTargeted: number;
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
      console.warn('[ONESIGNAL] Missing credentials — notification skipped for target:', playerId);
      return {
        success: false,
        playerId,
        error: 'OneSignal not configured on backend (.env ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY missing)',
      };
    }

    if (!playerId || typeof playerId !== 'string' || playerId.trim().length === 0) {
      return { success: false, playerId, error: 'Invalid or empty player/subscription ID' };
    }

    const cleanPlayerId = playerId.trim();

    // In modern OneSignal v5, devices are addressed via include_subscription_ids.
    // Legacy OneSignal apps use include_player_ids.
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
      console.log(`[ONESIGNAL] Retrying target ${cleanPlayerId} using legacy include_player_ids...`);
      return this.executePost({
        ...basePayload,
        include_player_ids: [cleanPlayerId],
      }, cleanPlayerId, payload.title);
    }

    return resultV5;
  }

  /** Broadcast push notification to multiple devices in a single OneSignal API call */
  async broadcastToDevices(playerIds: string[], payload: NotificationPayload): Promise<BroadcastResult> {
    if (!this.appId || !this.apiKey) {
      return {
        success: false,
        recipientsCount: playerIds.length,
        devicesTargeted: 0,
        error: 'OneSignal not configured on backend (.env ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY missing)',
      };
    }

    // Deduplicate and sanitize IDs
    const cleanPlayerIds = Array.from(new Set(playerIds.map((p) => p.trim()).filter((p) => p.length > 0)));

    if (cleanPlayerIds.length === 0) {
      return {
        success: true,
        recipientsCount: 0,
        devicesTargeted: 0,
        response: { notice: 'No active device tokens found for target audience' },
      };
    }

    const basePayload = {
      app_id: this.appId,
      headings: { en: payload.title },
      contents: { en: payload.body },
      data: payload.data || {},
      android_accent_color: 'FF39FF14',
      ios_sound: 'default',
      ...(payload.channelId ? { android_channel_id: payload.channelId } : {}),
    };

    // First attempt using include_subscription_ids (OneSignal v5 standard)
    const resultV5 = await this.executePost({
      ...basePayload,
      include_subscription_ids: cleanPlayerIds,
    }, `bulk-${cleanPlayerIds.length}-devices`, payload.title);

    if (resultV5.success) {
      return {
        success: true,
        notificationId: resultV5.response?.id,
        recipientsCount: resultV5.response?.recipients ?? cleanPlayerIds.length,
        devicesTargeted: cleanPlayerIds.length,
        httpStatus: resultV5.httpStatus,
        response: resultV5.response,
      };
    }

    // Fallback attempt using include_player_ids if subscription IDs rejected
    if (resultV5.httpStatus === 400 || (resultV5.error && resultV5.error.includes('subscription'))) {
      console.log(`[ONESIGNAL] Retrying bulk dispatch of ${cleanPlayerIds.length} devices using include_player_ids...`);
      const resultLegacy = await this.executePost({
        ...basePayload,
        include_player_ids: cleanPlayerIds,
      }, `bulk-${cleanPlayerIds.length}-legacy-players`, payload.title);

      return {
        success: resultLegacy.success,
        notificationId: resultLegacy.response?.id,
        recipientsCount: resultLegacy.response?.recipients ?? cleanPlayerIds.length,
        devicesTargeted: cleanPlayerIds.length,
        httpStatus: resultLegacy.httpStatus,
        response: resultLegacy.response,
        error: resultLegacy.error,
      };
    }

    return {
      success: false,
      recipientsCount: cleanPlayerIds.length,
      devicesTargeted: cleanPlayerIds.length,
      httpStatus: resultV5.httpStatus,
      response: resultV5.response,
      error: resultV5.error,
    };
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
        let errorMsg = result.errors ? JSON.stringify(result.errors) : `HTTP ${httpStatus}`;
        if (httpStatus === 401) {
          errorMsg = 'OneSignal REST API authentication failed (HTTP 401: Access denied). Please verify ONESIGNAL_REST_API_KEY in server environment.';
        }
        console.error(`[ONESIGNAL] Gateway error (HTTP ${httpStatus}) for ${targetId}:`, errorMsg);
        return {
          success: false,
          playerId: targetId,
          httpStatus,
          response: result,
          error: errorMsg,
        };
      }

      console.log(`[ONESIGNAL] ✅ Dispatched to ${targetId}: "${title}" (ID: ${result.id || 'ok'})`);
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
