/**
 * Alpha X AI — Knowledge Retriever
 * Phase 3 — Fitness Knowledge / RAG Architecture
 */

import {
  KnowledgeDocument,
  KnowledgeRetrievalOptions,
  KnowledgeSearchResult,
} from './knowledge.types';
import { IKnowledgeStore, knowledgeStore } from './knowledge.store';
import { knowledgeConfig } from './knowledge.config';

export interface IKnowledgeRetriever {
  retrieve(query: string, options?: KnowledgeRetrievalOptions): Promise<KnowledgeSearchResult[]>;
}

const STOP_WORDS = new Set([
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
  'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
  'to', 'was', 'were', 'will', 'with', 'what', 'how', 'why', 'can',
  'do', 'does', 'should', 'i', 'my', 'me', 'you', 'your', 'we', 'our',
]);

export class SimpleKeywordRetriever implements IKnowledgeRetriever {
  private store: IKnowledgeStore;

  constructor(store: IKnowledgeStore = knowledgeStore) {
    this.store = store;
  }

  public async retrieve(
    query: string,
    options?: KnowledgeRetrievalOptions
  ): Promise<KnowledgeSearchResult[]> {
    const rawQuery = (query || '').trim();
    if (!rawQuery) {
      return [];
    }

    const maxDocs = options?.maxDocuments ?? knowledgeConfig.maxDocuments;
    const minScore = options?.minScore ?? knowledgeConfig.minRelevanceScore;
    const targetTopic = options?.topic;

    const normalizedQuery = rawQuery.toLowerCase();
    const tokens = this.tokenize(normalizedQuery);

    if (tokens.length === 0) {
      return [];
    }

    const docs = targetTopic
      ? this.store.getByTopic(targetTopic)
      : this.store.getAll();

    if (docs.length === 0) {
      return [];
    }

    const results: KnowledgeSearchResult[] = [];

    for (const doc of docs) {
      const { score, matchedTerms } = this.calculateDocumentScore(
        doc,
        normalizedQuery,
        tokens
      );

      if (score >= minScore) {
        results.push({
          document: doc,
          score: Math.min(1.0, Math.round(score * 100) / 100),
          matchedTerms,
        });
      }
    }

    // Sort by score descending; if tied, sort by priority (lower number = higher priority)
    results.sort((a, b) => {
      if (b.score !== a.score) {
        return b.score - a.score;
      }
      return a.document.priority - b.document.priority;
    });

    return results.slice(0, maxDocs);
  }

  private tokenize(text: string): string[] {
    return text
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, ' ')
      .split(/\s+/)
      .map((t) => t.trim())
      .filter((t) => t.length > 1 && !STOP_WORDS.has(t));
  }

  private calculateDocumentScore(
    doc: KnowledgeDocument,
    fullQuery: string,
    tokens: string[]
  ): { score: number; matchedTerms: string[] } {
    let rawScore = 0;
    const matchedTermsSet = new Set<string>();

    const docTitleLower = doc.title.toLowerCase();
    const docSubtopicLower = doc.subtopic.toLowerCase();
    const docContentLower = doc.content.toLowerCase();
    const docTagsLower = doc.tags.map((t) => t.toLowerCase());

    // 1. Exact multi-word phrase matching
    if (tokens.length >= 2) {
      if (docTitleLower.includes(fullQuery)) {
        rawScore += 5.0;
        matchedTermsSet.add(fullQuery);
      } else if (docContentLower.includes(fullQuery)) {
        rawScore += 3.0;
        matchedTermsSet.add(fullQuery);
      }
    }

    // 2. Token-level matching across fields
    for (const token of tokens) {
      let tokenMatched = false;

      // Title match (high weight)
      if (docTitleLower.includes(token)) {
        rawScore += 2.5;
        tokenMatched = true;
      }

      // Tag match (high weight)
      if (docTagsLower.some((t) => t === token || t.includes(token))) {
        rawScore += 2.0;
        tokenMatched = true;
      }

      // Subtopic match (moderate weight)
      if (docSubtopicLower.includes(token)) {
        rawScore += 1.5;
        tokenMatched = true;
      }

      // Content match (lower weight, capped)
      const contentOccurrences = (docContentLower.match(new RegExp(`\\b${token}\\b`, 'g')) || []).length;
      if (contentOccurrences > 0) {
        rawScore += Math.min(2.0, contentOccurrences * 0.5);
        tokenMatched = true;
      }

      if (tokenMatched) {
        matchedTermsSet.add(token);
      }
    }

    // If zero tokens matched, score is 0
    if (matchedTermsSet.size === 0) {
      return { score: 0, matchedTerms: [] };
    }

    // Token coverage ratio (what % of query tokens were matched)
    const tokenCoverage = matchedTermsSet.size / tokens.length;

    // Normalization: Scale raw score using token coverage
    let normalized = (rawScore / (tokens.length * 3.5)) * (0.5 + 0.5 * tokenCoverage);

    // Source Priority small bonus (Priority 1: +0.08, Priority 2: +0.04)
    if (doc.priority === 1) {
      normalized += 0.08;
    } else if (doc.priority === 2) {
      normalized += 0.04;
    }

    return {
      score: normalized,
      matchedTerms: Array.from(matchedTermsSet),
    };
  }
}

export const simpleKeywordRetriever = new SimpleKeywordRetriever();
