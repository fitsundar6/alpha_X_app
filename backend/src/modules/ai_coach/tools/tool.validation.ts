/**
 * Alpha X AI — Tool Input & Output Validation
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

import { ToolDefinition, ToolInputSchema, ToolParameterProperty } from './tool.types';
import { ToolValidationError } from './tool.errors';

export class ToolValidationService {
  /**
   * Validates arguments passed to a tool against its declared input schema.
   */
  public validateInput(tool: ToolDefinition, rawArgs: any): Record<string, any> {
    const schema = tool.inputSchema || { type: 'object', properties: {} };
    const args = rawArgs === null || rawArgs === undefined ? {} : rawArgs;

    if (typeof args !== 'object' || Array.isArray(args)) {
      throw new ToolValidationError(tool.name, 'Tool arguments must be a structured JSON object');
    }

    const properties = schema.properties || {};
    const required = schema.required || [];

    // 1. Check required properties
    for (const reqKey of required) {
      if (args[reqKey] === undefined || args[reqKey] === null) {
        throw new ToolValidationError(tool.name, `Missing required argument: '${reqKey}'`);
      }
    }

    // 2. Validate individual properties
    const validatedArgs: Record<string, any> = {};

    for (const [key, val] of Object.entries(args)) {
      const propDef = properties[key];

      if (!propDef) {
        // If additional properties are explicitly forbidden
        if (schema.additionalProperties === false) {
          throw new ToolValidationError(tool.name, `Unexpected unrecognized argument: '${key}'`);
        }
        // Otherwise ignore or pass through safely
        continue;
      }

      this.validateProperty(tool.name, key, val, propDef);
      validatedArgs[key] = val;
    }

    // Fill in defaults or check non-supplied optional properties
    for (const [propKey] of Object.entries(properties)) {
      if (validatedArgs[propKey] === undefined && args[propKey] !== undefined) {
        validatedArgs[propKey] = args[propKey];
      }
    }

    return validatedArgs;
  }

  /**
   * Validates a single property against its definition
   */
  private validateProperty(
    toolName: string,
    propName: string,
    val: any,
    def: ToolParameterProperty
  ): void {
    if (val === undefined || val === null) {
      return;
    }

    switch (def.type) {
      case 'string':
        if (typeof val !== 'string') {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be a string (got ${typeof val})`);
        }
        if (def.minLength !== undefined && val.length < def.minLength) {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be at least ${def.minLength} characters (got ${val.length})`);
        }
        const maxLen = def.maxLength !== undefined ? def.maxLength : 2000;
        if (val.length > maxLen) {
          throw new ToolValidationError(toolName, `Argument '${propName}' exceeds maximum length of ${maxLen} characters`);
        }
        if (def.pattern && !new RegExp(def.pattern).test(val)) {
          throw new ToolValidationError(toolName, `Argument '${propName}' does not match required format pattern (${def.pattern})`);
        }
        if (def.enum && !def.enum.includes(val)) {
          throw new ToolValidationError(
            toolName,
            `Argument '${propName}' must be one of: [${def.enum.join(', ')}] (got '${val}')`
          );
        }
        break;

      case 'number':
      case 'integer':
        if (typeof val !== 'number' || !Number.isFinite(val)) {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be a valid finite number`);
        }
        if (def.type === 'integer' && !Number.isInteger(val)) {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be an integer`);
        }
        if (def.minimum !== undefined && val < def.minimum) {
          throw new ToolValidationError(
            toolName,
            `Argument '${propName}' must be at least ${def.minimum} (got ${val})`
          );
        }
        if (def.maximum !== undefined && val > def.maximum) {
          throw new ToolValidationError(
            toolName,
            `Argument '${propName}' cannot exceed ${def.maximum} (got ${val})`
          );
        }
        break;

      case 'boolean':
        if (typeof val !== 'boolean') {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be a boolean`);
        }
        break;

      case 'array':
        if (!Array.isArray(val)) {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be an array`);
        }
        break;

      case 'object':
        if (typeof val !== 'object' || Array.isArray(val)) {
          throw new ToolValidationError(toolName, `Argument '${propName}' must be an object`);
        }
        break;

      default:
        break;
    }
  }

  /**
   * Sanitizes and enforces character limits on tool results before returning to LLM
   */
  public sanitizeResult(toolName: string, data: any, maxCharacters: number): any {
    if (data === undefined || data === null) {
      return null;
    }

    try {
      const serialized = JSON.stringify(data);
      if (serialized.length <= maxCharacters) {
        return data;
      }

      // If data is an array, slice it
      if (Array.isArray(data)) {
        const sliced = [...data];
        while (JSON.stringify(sliced).length > maxCharacters && sliced.length > 0) {
          sliced.pop();
        }
        return {
          _truncated: true,
          _notice: `Tool result truncated to stay within ${maxCharacters} character limit`,
          items: sliced,
        };
      }

      // If data is a string
      if (typeof data === 'string') {
        return data.substring(0, maxCharacters - 50) + '... [TRUNCATED]';
      }

      // Otherwise return truncated preview
      return {
        _truncated: true,
        _notice: `Tool result size (${serialized.length} chars) exceeded limit (${maxCharacters} chars)`,
        preview: serialized.substring(0, 500) + '...',
      };
    } catch {
      return { error: 'Failed to serialize tool result' };
    }
  }
}

export const toolValidator = new ToolValidationService();
