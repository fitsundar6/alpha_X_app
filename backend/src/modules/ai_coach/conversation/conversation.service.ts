/**
 * Alpha X AI — Conversation Service
 * Phase 4 — Admin AI Chat Experience
 */

import {
  Conversation,
  ConversationMessage,
  FormattedHistoryMessage,
} from './conversation.types';
import { IConversationStore, conversationStore } from './conversation.store';
import { conversationConfig } from './conversation.config';

export class ConversationService {
  private store: IConversationStore;

  constructor(store: IConversationStore = conversationStore) {
    this.store = store;
  }

  /**
   * Validates and normalizes Admin input message
   */
  public validateMessage(message: unknown): string {
    if (typeof message !== 'string') {
      throw new Error('Message prompt must be a text string');
    }

    const trimmed = message.trim();
    if (trimmed.length === 0) {
      throw new Error('Prompt message cannot be empty');
    }

    if (trimmed.length > conversationConfig.maxMessageLength) {
      throw new Error(
        `Message exceeds maximum allowed length of ${conversationConfig.maxMessageLength} characters (received ${trimmed.length})`
      );
    }

    return trimmed;
  }

  /**
   * Resolves or creates an isolated conversation for the authenticated Admin
   */
  public resolveConversation(
    adminId: string,
    conversationId?: string
  ): { conversation: Conversation; isNew: boolean } {
    return this.store.resolveForAdmin(adminId, conversationId);
  }

  /**
   * Extracts bounded multi-turn conversation history for LLM context injection.
   *
   * SECURITY ENFORCEMENT:
   * - Bounded by maxHistoryMessages and maxHistoryCharacters.
   * - Strict role mapping ('user' | 'assistant').
   * - Strips internal prompt injection markers from prior history.
   */
  public getRecentHistory(conversation: Conversation): FormattedHistoryMessage[] {
    const rawMessages = conversation.messages || [];
    if (rawMessages.length === 0) {
      return [];
    }

    const maxMsgs = conversationConfig.maxHistoryMessages;
    const maxChars = conversationConfig.maxHistoryCharacters;

    // Take the most recent messages up to the limit
    const candidates = rawMessages
      .filter((m) => m.role === 'user' || m.role === 'assistant')
      .slice(-maxMsgs);

    const history: FormattedHistoryMessage[] = [];
    let accumulatedChars = 0;

    // Build history from newest backwards to prioritize immediate context
    for (let i = candidates.length - 1; i >= 0; i--) {
      const msg = candidates[i];
      const sanitizedContent = this.sanitizeHistoryContent(msg.content);
      const msgLength = sanitizedContent.length;

      if (accumulatedChars + msgLength > maxChars) {
        break;
      }

      history.unshift({
        role: msg.role as 'user' | 'assistant',
        content: sanitizedContent,
      });
      accumulatedChars += msgLength;
    }

    return history;
  }

  /**
   * Records a user-assistant exchange into the conversation store
   */
  public recordExchange(
    conversation: Conversation,
    userContent: string,
    assistantContent: string,
    meta?: Record<string, any>
  ): void {
    const timestamp = new Date().toISOString();

    const userMsg: ConversationMessage = {
      id: `msg_user_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      role: 'user',
      content: userContent,
      timestamp,
    };

    const aiMsg: ConversationMessage = {
      id: `msg_ai_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      role: 'assistant',
      content: assistantContent,
      timestamp,
      metadata: meta,
    };

    conversation.messages.push(userMsg, aiMsg);
    this.store.save(conversation);
  }

  /**
   * Retrieves conversation by ID for an Admin
   */
  public getConversation(adminId: string, conversationId: string): Conversation | undefined {
    const conv = this.store.get(conversationId);
    if (conv && conv.adminId === adminId) {
      return conv;
    }
    return undefined;
  }

  /**
   * Sanitizes history content to prevent historical prompt injection
   */
  private sanitizeHistoryContent(text: string): string {
    if (!text) return '';
    return text
      .replace(/ignore\s+(all\s+)?(previous\s+)?instructions/gi, '[neutralized directive]')
      .replace(/system\s*:\s*/gi, 'note: ')
      .trim();
  }
}

export const conversationService = new ConversationService();
