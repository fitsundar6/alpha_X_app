/**
 * Alpha X AI — Knowledge Configuration
 * Phase 3 — Fitness Knowledge / RAG Architecture
 */

export interface KnowledgeConfig {
  enabled: boolean;
  maxDocuments: number;
  maxTotalCharacters: number;
  minRelevanceScore: number;
}

class KnowledgeConfigurationManager {
  private config: KnowledgeConfig;

  constructor() {
    this.config = {
      enabled: process.env.AI_KNOWLEDGE_RAG_ENABLED !== 'false',
      maxDocuments: parseInt(process.env.AI_KNOWLEDGE_MAX_DOCS || '3', 10),
      maxTotalCharacters: parseInt(process.env.AI_KNOWLEDGE_MAX_CHARS || '4000', 10),
      minRelevanceScore: parseFloat(process.env.AI_KNOWLEDGE_MIN_SCORE || '0.15'),
    };
  }

  public get current(): KnowledgeConfig {
    return { ...this.config };
  }

  public get isEnabled(): boolean {
    return this.config.enabled;
  }

  public get maxDocuments(): number {
    return this.config.maxDocuments;
  }

  public get maxTotalCharacters(): number {
    return this.config.maxTotalCharacters;
  }

  public get minRelevanceScore(): number {
    return this.config.minRelevanceScore;
  }

  /**
   * Updates configuration dynamically (used for unit tests or admin tuning)
   */
  public updateConfig(partial: Partial<KnowledgeConfig>): void {
    this.config = {
      ...this.config,
      ...partial,
    };
  }

  /**
   * Resets configuration to default environment-driven settings
   */
  public resetToDefaults(): void {
    this.config = {
      enabled: process.env.AI_KNOWLEDGE_RAG_ENABLED !== 'false',
      maxDocuments: parseInt(process.env.AI_KNOWLEDGE_MAX_DOCS || '3', 10),
      maxTotalCharacters: parseInt(process.env.AI_KNOWLEDGE_MAX_CHARS || '4000', 10),
      minRelevanceScore: parseFloat(process.env.AI_KNOWLEDGE_MIN_SCORE || '0.15'),
    };
  }
}

export const knowledgeConfig = new KnowledgeConfigurationManager();
