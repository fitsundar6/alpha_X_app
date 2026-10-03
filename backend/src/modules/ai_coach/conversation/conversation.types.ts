/**
 * Alpha X AI — Conversation System Types
 * Phase 4 & Phase 7 — Secure Client Identification & Conversation Context
 */

export type ConversationRole = 'user' | 'assistant' | 'system';

export type ClientIdentitySource =
  | 'EXPLICIT_AXG_ID'
  | 'RESOLVED_UNIQUE_NAME'
  | 'PAYLOAD_SELECTED'
  | 'ADMIN_SWITCH';

/**
 * Structured, verified client context stored per-conversation.
 * Excludes all authentication secrets, tokens, password hashes, and OAuth UIDs.
 */
export interface VerifiedClientContext {
  clientId: string;        // Safe Alpha X Client ID (e.g. "AXG-1234") or validated primary ID
  userId: string;          // User record primary key
  profileId: string;       // ClientProfile record primary key
  displayName: string;     // Client display name (e.g. "John Doe")
  identitySource: ClientIdentitySource;
  verified: boolean;       // Must be true for active contexts
  selectedAt: string;      // ISO 8601 timestamp
  primaryGoal?: string | null;
  currentWeightKg?: number | null;
}

export interface ConversationMessage {
  id: string;
  role: ConversationRole;
  content: string;
  timestamp: string;
  metadata?: {
    model?: string;
    promptVersion?: string;
    knowledgeRetrievalEnabled?: boolean;
    retrievedKnowledgeCount?: number;
    retrievedKnowledgeIds?: string[];
    latencyMs?: number;
    verifiedClient?: VerifiedClientContext | null;
    ambiguityMatches?: Array<{
      userId: string;
      clientId: string | null;
      name: string;
      primaryGoal: string | null;
    }>;
  };
}

export interface Conversation {
  id: string;
  adminId: string;
  title?: string;
  createdAt: string;
  updatedAt: string;
  messages: ConversationMessage[];
  metadata?: Record<string, any>;
  verifiedClient?: VerifiedClientContext | null;
}

export interface FormattedHistoryMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface AdminChatPayload {
  message: string;
  conversationId?: string;
  selectedClientId?: string;
  dateRangePreset?: string;
  clearClient?: boolean;
}
