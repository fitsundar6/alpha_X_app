/**
 * Alpha X AI — Tool Registry
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

import { ToolDefinition, GeminiFunctionDeclaration } from './tool.types';
import { DuplicateToolError, ToolValidationError } from './tool.errors';

export class ToolRegistry {
  private tools: Map<string, ToolDefinition> = new Map();

  /**
   * Registers a tool into the authoritative system registry.
   * Rejects duplicate names and invalid definitions.
   */
  public register(tool: ToolDefinition): void {
    if (!tool || typeof tool !== 'object') {
      throw new ToolValidationError('unknown', 'Tool definition must be an object');
    }

    if (!tool.name || typeof tool.name !== 'string' || !/^[a-zA-Z0-9_]{1,64}$/.test(tool.name)) {
      throw new ToolValidationError(
        tool.name || 'unnamed',
        'Tool name must be an alphanumeric string (with underscores) between 1 and 64 characters'
      );
    }

    if (this.tools.has(tool.name)) {
      throw new DuplicateToolError(tool.name);
    }

    if (!tool.description || typeof tool.description !== 'string') {
      throw new ToolValidationError(tool.name, 'Tool must include a descriptive summary string');
    }

    if (!tool.category || !tool.permission) {
      throw new ToolValidationError(tool.name, 'Tool must declare a valid category and permission level');
    }

    if (typeof tool.handler !== 'function') {
      throw new ToolValidationError(tool.name, 'Tool must provide an executable handler function');
    }

    if (!tool.inputSchema || typeof tool.inputSchema !== 'object') {
      throw new ToolValidationError(tool.name, 'Tool must declare a structured inputSchema');
    }

    this.tools.set(tool.name, tool);
  }

  /**
   * Retrieves a tool by name
   */
  public getTool(name: string): ToolDefinition | undefined {
    return this.tools.get(name);
  }

  /**
   * Checks if a tool is registered
   */
  public hasTool(name: string): boolean {
    return this.tools.has(name);
  }

  /**
   * Lists all registered tools
   */
  public listTools(includeDisabled: boolean = false): ToolDefinition[] {
    const all = Array.from(this.tools.values());
    if (includeDisabled) {
      return all;
    }
    return all.filter((t) => t.enabled !== false);
  }

  /**
   * Unregisters a tool by name
   */
  public unregister(name: string): boolean {
    return this.tools.delete(name);
  }

  /**
   * Clears all registered tools (used primarily for test isolation)
   */
  public clear(): void {
    this.tools.clear();
  }

  /**
   * Converts all active registered tools into Gemini SDK FunctionDeclaration format
   */
  public getGeminiDeclarations(): GeminiFunctionDeclaration[] {
    const activeTools = this.listTools(false);
    return activeTools.map((tool) => {
      const properties: Record<string, any> = {};
      const toolProps = tool.inputSchema?.properties || {};

      for (const [key, prop] of Object.entries(toolProps)) {
        properties[key] = {
          type: prop.type.toUpperCase(),
          description: prop.description,
          ...(prop.enum ? { enum: prop.enum } : {}),
        };
      }

      return {
        name: tool.name,
        description: tool.description,
        parameters: {
          type: 'OBJECT',
          properties,
          required: tool.inputSchema?.required || [],
        },
      };
    });
  }
}

export const toolRegistry = new ToolRegistry();
