/**
 * Alpha X AI — Tool Permission & Authorization Framework
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

import { ToolCategory, ToolPermission, ToolDefinition, ToolExecutionContext } from './tool.types';
import { ToolPermissionError } from './tool.errors';
import { toolConfig } from './tool.config';

/**
 * Validates whether a tool execution request complies with security boundaries
 * and the caller's authorized permissions.
 *
 * SECURITY ENFORCEMENTS:
 * 1. Admin context verification: Every tool call must be initiated by an authenticated Admin.
 * 2. WRITE Tool Protection: In Phase 5, all WRITE category tools and write permissions are globally blocked at code level.
 * 3. Scope validation: The tool's declared permission must be in the active allowed set.
 */
export function validateToolPermission(
  tool: ToolDefinition,
  context: ToolExecutionContext
): void {
  // 1. Caller Authentication Guard
  if (!context || !context.adminId || typeof context.adminId !== 'string' || context.adminId.trim().length === 0) {
    throw new ToolPermissionError(tool.name, 'Admin authorization context is required to execute AI tools');
  }

  // 2. Global Phase 5 WRITE Protection
  if (
    tool.category === 'WRITE' ||
    tool.permission === ToolPermission.WRITE_DATA ||
    tool.name.toLowerCase().startsWith('write_') ||
    tool.name.toLowerCase().startsWith('update_') ||
    tool.name.toLowerCase().startsWith('delete_')
  ) {
    throw new ToolPermissionError(
      tool.name,
      'WRITE tools are strictly disabled in Phase 5. Alpha X database write operations cannot be performed by AI tools.'
    );
  }

  // In Phase 6-9, safe read-only client and calculation/analysis tools are activated:
  const allowedPermissions: Set<ToolPermission> = new Set([
    ToolPermission.READ_SYSTEM,
    ToolPermission.READ_KNOWLEDGE,
    ToolPermission.CALCULATE_METRIC,
    ToolPermission.READ_CLIENT,
    ToolPermission.ANALYZE_DATA,
  ]);

  if (!allowedPermissions.has(tool.permission)) {
    throw new ToolPermissionError(
      tool.name,
      `Permission '${tool.permission}' is not permitted or is reserved for future phases`
    );
  }
}
