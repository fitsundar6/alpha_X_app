/**
 * Alpha X AI — Client Context Service
 * Phase 7 — Secure Client Identification & Conversation Context
 *
 * Manages deterministic client verification, conversation-scoped client context,
 * safe client switching, pronoun binding, and ambiguity handling.
 */

import { Conversation, VerifiedClientContext, ClientIdentitySource } from './conversation.types';
import { clientDataService } from '../tools/definitions/client/client_data.service';

export interface ClientResolutionOutcome {
  success: boolean;
  status: 'FOUND' | 'NOT_FOUND' | 'AMBIGUOUS' | 'CLEARED' | 'NO_OP' | 'VERIFIED';
  client?: VerifiedClientContext;
  matches?: Array<{
    userId: string;
    clientId: string | null;
    name: string;
    primaryGoal: string | null;
  }>;
  candidates?: Array<{
    userId: string;
    clientId: string | null;
    name: string;
    primaryGoal: string | null;
  }>;
  message?: string;
  previousClient?: VerifiedClientContext | null;
}

export interface ClientIntentDetectionResult {
  intent: 'CLEAR' | 'SWITCH' | 'SELECT' | 'PRONOUN_QUERY' | 'NONE';
  type: 'CLEAR' | 'SWITCH' | 'SELECT' | 'PRONOUN_QUERY' | 'NONE';
  targetIdentifier?: string;
  targetReference?: string;
  isAmbiguousPronounWithoutClient?: boolean;
}

export class ClientContextService {
  /**
   * Resolves and sets a verified client context onto the specific conversation.
   *
   * SECURITY ENFORCEMENT:
   * - A client can ONLY be set if verified by clientDataService.resolveClient.
   * - If ambiguous: DOES NOT switch or modify existing verified context.
   * - If not found: DOES NOT switch or modify existing verified context.
   */
  public async resolveAndSetClient(
    conversation: Conversation,
    identifier: string,
    sourceOverride?: ClientIdentitySource
  ): Promise<ClientResolutionOutcome> {
    if (!identifier || typeof identifier !== 'string' || identifier.trim().length === 0) {
      return {
        success: false,
        status: 'NOT_FOUND',
        message: 'Client identifier cannot be empty.',
        previousClient: conversation.verifiedClient || null,
      };
    }

    const clean = identifier.trim();
    const resolution = await clientDataService.resolveClient(clean);

    if (resolution.status === 'FOUND' && resolution.client) {
      const isExplicitAxg = clean.toUpperCase().startsWith('AXG-');
      const identitySource: ClientIdentitySource =
        sourceOverride ||
        (isExplicitAxg
          ? 'EXPLICIT_AXG_ID'
          : conversation.verifiedClient
          ? 'ADMIN_SWITCH'
          : 'RESOLVED_UNIQUE_NAME');

      const verifiedClient: VerifiedClientContext = {
        clientId: resolution.client.clientId || resolution.client.userId,
        userId: resolution.client.userId,
        profileId: resolution.client.profileId,
        displayName: resolution.client.name,
        identitySource,
        verified: true,
        selectedAt: new Date().toISOString(),
      };

      conversation.verifiedClient = verifiedClient;

      return {
        success: true,
        status: 'FOUND',
        client: verifiedClient,
        previousClient: conversation.verifiedClient || null,
        message: `Verified and selected client ${verifiedClient.displayName} (${verifiedClient.clientId}).`,
      };
    }

    if (resolution.status === 'AMBIGUOUS') {
      // PREVENT ACCIDENTAL CLIENT SWITCHING: Preserve current verified client
      return {
        success: false,
        status: 'AMBIGUOUS',
        matches: resolution.matches,
        candidates: resolution.matches,
        message: resolution.message || `Multiple clients match '${clean}'. Please provide the specific AXG ID to select.`,
        previousClient: conversation.verifiedClient || null,
      };
    }

    // NOT_FOUND: Preserve current verified client
    return {
      success: false,
      status: 'NOT_FOUND',
      message: resolution.message || `No Alpha X client found matching '${clean}'.`,
      previousClient: conversation.verifiedClient || null,
    };
  }

  /**
   * Explicitly clears the verified client context for this conversation.
   */
  public clearClient(conversation: Conversation): ClientResolutionOutcome {
    const previousClient = conversation.verifiedClient || null;
    conversation.verifiedClient = null;

    return {
      success: true,
      status: 'CLEARED',
      previousClient,
      message: 'Client context cleared. You are no longer focused on a specific client.',
    };
  }

  /**
   * Retrieves the active verified client context for this conversation.
   */
  public getVerifiedClient(conversation: Conversation): VerifiedClientContext | null {
    return conversation.verifiedClient || null;
  }

  /**
   * Detects conversational client management intent (select, switch, clear, pronoun reference).
   */
  public detectClientIntent(
    message: string,
    currentClient: VerifiedClientContext | null
  ): ClientIntentDetectionResult {
    if (!message || typeof message !== 'string') {
      return { intent: 'NONE', type: 'NONE' };
    }

    const clean = message.trim();

    // 1. Detect Clear Intent
    if (
      /^(clear|reset|forget)\s+(client(\s+context)?|context)$/i.test(clean) ||
      /^clear$/i.test(clean)
    ) {
      return { intent: 'CLEAR', type: 'CLEAR' };
    }

    // 2. Detect Explicit Switch Intent ("switch to ...", "change client to ...", "switch client to ...")
    const switchMatch = clean.match(
      /^(?:please\s+)?(?:switch|change)(?:\s+client)?\s+to\s+([A-Za-z0-9_\-\s.]+?)(?:[\.!\?]?)$/i
    );
    if (switchMatch && switchMatch[1]) {
      const target = switchMatch[1].trim();
      return {
        intent: 'SWITCH',
        type: 'SWITCH',
        targetIdentifier: target,
        targetReference: target,
      };
    }

    // 3. Detect "How about ...?" or "What about ...?" as potential switch targets
    const whatAboutMatch = clean.match(
      /^(?:how|what)\s+about\s+([A-Za-z0-9_\-\s.]+?)(?:\?|$)/i
    );
    if (whatAboutMatch && whatAboutMatch[1]) {
      const candidate = whatAboutMatch[1].trim();
      // Only treat as client switch if candidate does not look like a metric/topic (e.g. "workouts", "diet", "sleep")
      const nonClientTopics = ['workout', 'workouts', 'diet', 'nutrition', 'sleep', 'protein', 'weight', 'progress', 'checkin', 'attendance', 'steps'];
      if (!nonClientTopics.includes(candidate.toLowerCase())) {
        return {
          intent: 'SWITCH',
          type: 'SWITCH',
          targetIdentifier: candidate,
          targetReference: candidate,
        };
      }
    }

    // 4. Detect Selection Intent ("work with ...", "let's review ...", "select ...", "check ...")
    const selectMatch = clean.match(
      /^(?:please\s+)?(?:work\s+with|let'?s\s+review|review|select|focus\s+on)\s+([A-Za-z0-9_\-\s.]+?)(?:[\.!\?]?)$/i
    );
    if (selectMatch && selectMatch[1]) {
      const target = selectMatch[1].trim();
      return {
        intent: 'SELECT',
        type: 'SELECT',
        targetIdentifier: target,
        targetReference: target,
      };
    }

    // 5. Standalone AXG ID (e.g. "AXG-1001", "axg 1001")
    const axgMatch = clean.match(/^(?:AXG[-\s]?\w{3,10})$/i);
    if (axgMatch) {
      const target = clean.replace(/\s+/g, '-').toUpperCase();
      return {
        intent: 'SELECT',
        type: 'SELECT',
        targetIdentifier: target,
        targetReference: target,
      };
    }

    // 6. Pronoun Queries without an Active Verified Client
    const pronounRegex = /\b(he|she|they|him|her|his|their|the\s+client|this\s+client|this\s+member)\b/i;
    const clientMetricRegex = /\b(weight|workout|workouts|exercise|exercises|diet|food|nutrition|check-?in|checkins|steps|attendance|injur(y|ies)|progress|profile|personal\s+best(s)?|pb(s)?|pr(s)?|1rm|records?|bests?)\b/i;

    if (pronounRegex.test(clean) && clientMetricRegex.test(clean)) {
      if (!currentClient) {
        return {
          intent: 'PRONOUN_QUERY',
          type: 'PRONOUN_QUERY',
          isAmbiguousPronounWithoutClient: true,
        };
      }
      return {
        intent: 'PRONOUN_QUERY',
        type: 'PRONOUN_QUERY',
        isAmbiguousPronounWithoutClient: false,
      };
    }

    return { intent: 'NONE', type: 'NONE' };
  }

  /**
   * Formats the verified client context into an authoritative context slot for Gemini prompts.
   */
  public formatActiveClientContextSlot(client: VerifiedClientContext): string {
    const lines = [
      `[ACTIVE VERIFIED CLIENT CONTEXT]`,
      `Client ID: ${client.clientId}`,
      `Name: ${client.displayName}`,
      `Verified: true`,
      `Identity Source: ${client.identitySource}`,
    ];

    if (client.primaryGoal) {
      lines.push(`Primary Goal: ${client.primaryGoal}`);
    }
    if (client.currentWeightKg) {
      lines.push(`Latest Recorded Weight: ${client.currentWeightKg} kg`);
    }

    lines.push(
      `CRITICAL CONTEXT RULE: All conversational pronouns ('he', 'she', 'they', 'him', 'her', 'his', 'their', 'the client', 'this client') in the inquiry refer exclusively to this active verified client (${client.displayName} — ${client.clientId}).`
    );

    return lines.join('\n');
  }

  /**
   * Validates whether an incoming client reference is safe and corresponds to a real Alpha X client.
   */
  public async validateClientReference(identifier: string): Promise<boolean> {
    if (!identifier || typeof identifier !== 'string') return false;
    const res = await clientDataService.resolveClient(identifier.trim());
    return res.status === 'FOUND';
  }
}

export const clientContextService = new ClientContextService();
