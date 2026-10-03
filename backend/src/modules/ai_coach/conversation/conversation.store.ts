/**
 * Alpha X AI — In-Memory Conversation Store
 * Phase 4 — Admin AI Chat Experience
 */

import { Conversation } from './conversation.types';

export interface IConversationStore {
  get(id: string): Conversation | undefined;
  getByAdmin(adminId: string): Conversation[];
  create(adminId: string, customId?: string): Conversation;
  save(conversation: Conversation): void;
  delete(id: string): boolean;
  clear(): void;
  resolveForAdmin(
    adminId: string,
    conversationId?: string
  ): { conversation: Conversation; isNew: boolean };
}

export class InMemoryConversationStore implements IConversationStore {
  private conversations: Map<string, Conversation> = new Map();

  public get(id: string): Conversation | undefined {
    return this.conversations.get(id);
  }

  public getByAdmin(adminId: string): Conversation[] {
    return Array.from(this.conversations.values())
      .filter((c) => c.adminId === adminId)
      .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
  }

  public create(adminId: string, customId?: string): Conversation {
    const id = customId || this.generateConversationId();
    const now = new Date().toISOString();
    const conv: Conversation = {
      id,
      adminId,
      createdAt: now,
      updatedAt: now,
      messages: [],
    };
    this.conversations.set(id, conv);
    return conv;
  }

  public save(conversation: Conversation): void {
    conversation.updatedAt = new Date().toISOString();
    this.conversations.set(conversation.id, conversation);
  }

  public delete(id: string): boolean {
    return this.conversations.delete(id);
  }

  public clear(): void {
    this.conversations.clear();
  }

  /**
   * Resolves a conversation for an authenticated Admin.
   *
   * ISOLATION & SECURITY RULES:
   * 1. If conversationId is provided and belongs to the authenticated Admin -> reuse conversation.
   * 2. If conversationId is provided but belongs to another Admin -> ZERO LEAKAGE. Create a new conversation.
   * 3. If conversationId is provided but does not exist in store -> safely create with a new ID.
   * 4. If conversationId is omitted -> create a new conversation.
   */
  public resolveForAdmin(
    adminId: string,
    conversationId?: string
  ): { conversation: Conversation; isNew: boolean } {
    if (conversationId && conversationId.trim().length > 0) {
      const cleanId = conversationId.trim();
      const existing = this.conversations.get(cleanId);

      if (existing) {
        if (existing.adminId === adminId) {
          return { conversation: existing, isNew: false };
        }
        // Foreign Admin conversation access blocked - generate fresh isolated conversation
        console.warn(
          `[CONVERSATION ISOLATION] Blocked attempt by Admin ${adminId} to access foreign conversation ${cleanId}`
        );
        const newConv = this.create(adminId);
        return { conversation: newConv, isNew: true };
      }

      // Provided conversationId does not exist yet; initialize fresh conversation with that ID
      const newConv = this.create(adminId, cleanId);
      return { conversation: newConv, isNew: true };
    }

    // No conversationId provided; generate fresh conversation
    const newConv = this.create(adminId);
    return { conversation: newConv, isNew: true };
  }

  private generateConversationId(): string {
    const timestamp = Date.now();
    const randomSuffix = Math.random().toString(36).substring(2, 8);
    return `conv_${timestamp}_${randomSuffix}`;
  }
}

export const conversationStore = new InMemoryConversationStore();
