/**
 * Alpha X AI — Conversation Configuration
 * Phase 4 — Admin AI Chat Experience
 */

export interface ConversationConfig {
  maxHistoryMessages: number;
  maxHistoryCharacters: number;
  maxMessageLength: number;
}

class ConversationConfigurationManager {
  private config: ConversationConfig;

  constructor() {
    this.config = {
      maxHistoryMessages: parseInt(process.env.AI_MAX_HISTORY_MESSAGES || '10', 10),
      maxHistoryCharacters: parseInt(process.env.AI_MAX_HISTORY_CHARS || '6000', 10),
      maxMessageLength: parseInt(process.env.AI_MAX_MESSAGE_LENGTH || '4000', 10),
    };
  }

  public get current(): ConversationConfig {
    return { ...this.config };
  }

  public get maxHistoryMessages(): number {
    return this.config.maxHistoryMessages;
  }

  public get maxHistoryCharacters(): number {
    return this.config.maxHistoryCharacters;
  }

  public get maxMessageLength(): number {
    return this.config.maxMessageLength;
  }

  public updateConfig(partial: Partial<ConversationConfig>): void {
    this.config = {
      ...this.config,
      ...partial,
    };
  }

  public resetToDefaults(): void {
    this.config = {
      maxHistoryMessages: parseInt(process.env.AI_MAX_HISTORY_MESSAGES || '10', 10),
      maxHistoryCharacters: parseInt(process.env.AI_MAX_HISTORY_CHARS || '6000', 10),
      maxMessageLength: parseInt(process.env.AI_MAX_MESSAGE_LENGTH || '4000', 10),
    };
  }
}

export const conversationConfig = new ConversationConfigurationManager();
