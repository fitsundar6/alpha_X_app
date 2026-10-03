/**
 * Alpha X AI — In-Memory Knowledge Store
 * Phase 3 — Fitness Knowledge / RAG Architecture
 */

import { KnowledgeDocument, KnowledgeTopic } from './knowledge.types';
import { SEED_KNOWLEDGE_DOCUMENTS } from './knowledge.sources';

export interface IKnowledgeStore {
  getAll(): KnowledgeDocument[];
  getById(id: string): KnowledgeDocument | undefined;
  getByTopic(topic: KnowledgeTopic): KnowledgeDocument[];
  add(doc: KnowledgeDocument): void;
  remove(id: string): boolean;
  count(): number;
  listTopics(): string[];
  clear(): void;
  reset(): void;
}

export class InMemoryKnowledgeStore implements IKnowledgeStore {
  private documents: Map<string, KnowledgeDocument> = new Map();

  constructor(initialDocs: KnowledgeDocument[] = SEED_KNOWLEDGE_DOCUMENTS) {
    this.initialize(initialDocs);
  }

  private initialize(docs: KnowledgeDocument[]): void {
    this.documents.clear();
    for (const doc of docs) {
      this.documents.set(doc.id, { ...doc });
    }
  }

  public getAll(): KnowledgeDocument[] {
    return Array.from(this.documents.values());
  }

  public getById(id: string): KnowledgeDocument | undefined {
    return this.documents.get(id);
  }

  public getByTopic(topic: KnowledgeTopic): KnowledgeDocument[] {
    return this.getAll().filter((doc) => doc.topic === topic);
  }

  public add(doc: KnowledgeDocument): void {
    this.documents.set(doc.id, { ...doc });
  }

  public remove(id: string): boolean {
    return this.documents.delete(id);
  }

  public count(): number {
    return this.documents.size;
  }

  public listTopics(): string[] {
    const topics = new Set<string>();
    for (const doc of this.documents.values()) {
      topics.add(doc.topic);
    }
    return Array.from(topics);
  }

  /**
   * Clears all documents from the store.
   * Useful for testing empty knowledge base fallback behavior (Phase 3 Test 8).
   */
  public clear(): void {
    this.documents.clear();
  }

  /**
   * Resets the store to default seed documents.
   */
  public reset(): void {
    this.initialize(SEED_KNOWLEDGE_DOCUMENTS);
  }
}

export const knowledgeStore = new InMemoryKnowledgeStore();
