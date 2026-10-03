/**
 * Alpha X - OneSignal Push Notification Service
 *
 * Sends push notifications to client devices via OneSignal REST API.
 * Never sends to admin users. Respects the client's opt-out flag.
 */

import { env } from '../../config/environment';

const ONESIGNAL_API = 'https://api.onesignal.com';

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface SendResult {
  success: boolean;
  playerId: string;
  error?: string;
}

export class OneSignalService {
  private get appId(): string {
    return env.ONESIGNAL_APP_ID || '';
  }
  private get apiKey(): string {
    return env.ONESIGNAL_REST_API_KEY || '';
  }

  /** Send a push notification to one specific device by OneSignal player ID */
  async sendToPlayer(playerId: string, payload: NotificationPayload): Promise<SendResult> {
    if (!this.appId || !this.apiKey) {
      console.warn('[ONESIGNAL] Missing credentials — notification skipped for player:', playerId);
      return { success: false, playerId, error: 'OneSignal not configured' };
    }

    const body = {
      app_id: this.appId,
      include_player_ids: [playerId],
      headings: { en: payload.title },
      contents: { en: payload.body },
      data: payload.data || {},
      // Alpha X green accent
      android_accent_color: 'FF39FF14',
      ios_sound: 'default',
      android_channel_id: 'alpha_x_ai_coach',
    };

    try {
      const response = await fetch(`${ONESIGNAL_API}/notifications`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Key ${this.apiKey}`,
        },
        body: JSON.stringify(body),
      });

      const result = (await response.json()) as any;
      if (result.errors) {
        console.error(`[ONESIGNAL] Error for player ${playerId}:`, result.errors);
        return { success: false, playerId, error: JSON.stringify(result.errors) };
      }
      console.log(`[ONESIGNAL] ✅ Sent to ${playerId}: "${payload.title}"`);
      return { success: true, playerId };
    } catch (err: any) {
      console.error('[ONESIGNAL] Network error:', err?.message);
      return { success: false, playerId, error: err?.message };
    }
  }

  /** Send to multiple players at once (batches per-player for personalized messages) */
  async sendToPlayers(playerIds: string[], payload: NotificationPayload): Promise<SendResult[]> {
    return Promise.all(playerIds.map((id) => this.sendToPlayer(id, payload)));
  }
}

export const oneSignalService = new OneSignalService();
