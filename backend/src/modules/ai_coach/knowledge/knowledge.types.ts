/**
 * Alpha X AI — Knowledge / RAG Layer Types
 * Phase 3 — Fitness Knowledge / RAG Architecture
 */

export type KnowledgeTopic = 'TRAINING' | 'NUTRITION' | 'RECOVERY' | 'SUPPLEMENTS' | 'COACHING';

export type KnowledgeSourceType =
  | 'PRIMARY_EVIDENCE'      // Systematic reviews, meta-analyses, randomized controlled trials, position stands
  | 'SECONDARY_EVIDENCE'    // High-quality reviews, textbooks, professional guidelines (ACSM, NSCA, ISSN)
  | 'GENERAL_KNOWLEDGE'     // Curated fitness principles without fabricated citations
  | 'ALPHA_X_GUIDELINE';    // Verified Alpha X internal coaching protocols

export type EvidenceLevel =
  | 'STRONG'                // Meta-analysis, systematic review, multi-center RCT
  | 'MODERATE'              // Single RCT, robust observational study, textbook consensus
  | 'GENERAL'               // Educational standard, established practical principle
  | 'EXPERT_CONSENSUS';     // Position stand from recognized organizations (ACSM, ISSN, NSCA)

export interface KnowledgeDocument {
  id: string;
  title: string;
  topic: KnowledgeTopic;
  subtopic: string;
  content: string;
  source: string;
  sourceType: KnowledgeSourceType;
  authors?: string[];
  publicationYear?: number;
  evidenceLevel: EvidenceLevel;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  version: string;
  priority: number; // 1 = Admin/Internal, 2 = Primary Evidence, 3 = Secondary Evidence, 4 = General
}

export interface KnowledgeSearchResult {
  document: KnowledgeDocument;
  score: number;
  matchedTerms: string[];
}

export interface KnowledgeRetrievalOptions {
  maxDocuments?: number;
  minScore?: number;
  topic?: KnowledgeTopic;
}

export interface FormattedKnowledgeContext {
  contextBlock: string;
  retrievedCount: number;
  documentIds: string[];
  highestEvidenceLevel?: EvidenceLevel;
}
