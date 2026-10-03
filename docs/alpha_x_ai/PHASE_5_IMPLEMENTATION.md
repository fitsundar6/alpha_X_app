# ALPHA X AI — PHASE 5: SECURE AI TOOL & FUNCTION CALLING ARCHITECTURE

**Phase Status:** COMPLETED & VERIFIED  
**Phase Focus:** Secure AI Tool & Function Calling Framework (Tool Registry, Permission System, Input/Output Validation, Timeout Guards, WRITE Protection, Safe Demonstration Tools, and Gemini Function Calling Integration)  
**Date:** October 2026  
**Implementation Team:** Alpha X Engineering  

---

## 1. EXECUTIVE SUMMARY

Phase 5 introduces the secure internal tool and function-calling architecture for Alpha X AI.  
The core security principle governing this phase and all future phases is:

> **Gemini must NEVER receive unrestricted database access. The AI can only interact with Alpha X systems through explicitly registered, validated, backend-enforced tools.**

### Critical Phase Boundaries Observed:
- **No real client data tools were implemented in Phase 5.**
- **No access to client records, profiles, workouts, diets, food logs, check-ins, attendance, or smartwatch data.**
- **WRITE tools are globally and strictly blocked in backend code.**
- **No generic power tools (`executeSQL`, `executeCode`, `executeShell`, `fetchURL`) exist anywhere in the codebase.**
- Only 4 harmless, non-sensitive demonstration tools were created to validate the architecture.

---

## 2. TOOL ARCHITECTURE

The tool system is implemented under `backend/src/modules/ai_coach/tools/`:

```text
backend/src/modules/ai_coach/tools/
├── tool.types.ts                 # Domain models, ToolCategory, ToolPermission, ToolDefinition
├── tool.errors.ts                # Structured error hierarchy (ToolError, ToolValidationError, etc.)
├── tool.config.ts                # Centralized limits (timeouts, call limits, size limits, write protection)
├── tool.permissions.ts           # Permission verification & hardcoded Phase 5 WRITE blocking
├── tool.validation.ts            # Input schema validator & output size sanitizer
├── tool.registry.ts              # Authoritative server-side tool registry & Gemini OpenAPI exporter
├── tool.executor.ts              # Multi-stage security execution pipeline & audit logger
├── definitions/                  # Harmless demonstration tools
│   ├── get_ai_status.ts          # Operational status, prompt version, RAG state
│   ├── get_fitness_topics.ts     # Verified knowledge topics & categories
│   ├── calculate_training_example.ts # Pure deterministic volume/rep calculations
│   └── get_tool_system_info.ts   # Safe metadata about registered tools & active policies
└── index.ts                      # Barrel exports & demonstration tool auto-initialization
```

---

## 3. MULTI-STAGE SECURITY PIPELINE

Every tool call requested by Gemini or the backend traverses an exhaustive 6-stage validation sequence:

```text
Gemini Model emits FunctionCall
               │
               ▼
[Stage 1: Tool Registry Lookup]
   • Validates that tool name exists and is active.
   • Unknown or disabled tools safely return TOOL_NOT_FOUND.
               │
               ▼
[Stage 2: Permission & WRITE Guard]
   • Verifies authenticated Admin context (adminId).
   • Strictly blocks any WRITE-category tool or write permission.
   • Enforces allowed Phase 5 permission set.
               │
               ▼
[Stage 3: Input Schema Validation]
   • Validates arguments against declared JSON schema.
   • Verifies required fields, strict types, minimums, maximums, and enums.
   • Rejects malformed arguments before handler is invoked.
               │
               ▼
[Stage 4: Execution with Race Timeout]
   • Wraps execution in Promise.race with toolTimeoutMs (default 5000ms).
   • Aborts if timeout fires without crashing the server.
               │
               ▼
[Stage 5: Result Sanitization & Size Control]
   • Verifies result is structured JSON.
   • Truncates if output exceeds maxResultCharacters (default 4000).
   • Formats data as UNTRUSTED DATA for model consumption.
               │
               ▼
[Stage 6: Safe Audit Logging]
   • Records RequestID, ConvID, AdminID, ToolName, Category, Latency, Status.
   • Never logs secrets, passwords, tokens, or raw sensitive arguments.
```

---

## 4. PERMISSION MODEL & WRITE PROTECTION

### Tool Categories
- **`READ`:** Pure data retrieval operations (e.g., system status, knowledge topics).
- **`ANALYZE`:** Computational analysis using explicit arguments (e.g., training volume calculations).
- **`PROPOSE`:** Generates structured recommendations for Admin review (reserved for future phases).
- **`WRITE`:** Database modification operations. **Globally disabled at code level in Phase 5.**

### Code-Level WRITE Blocking
Enforced in `tool.permissions.ts`:
```typescript
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
```

---

## 5. DETERMINISTIC CALCULATION PRINCIPLE

Phase 5 establishes the principle that **mathematical and analytical metrics must be computed deterministically by backend code**, never by LLM guesswork:

1. **`calculate_simple_training_example`:**
   - Input: `{ sets: 4, reps: 8, weightKg: 80 }`
   - Deterministic Backend Calculation:
     - `totalReps = sets * reps` (32)
     - `trainingVolumeKg = totalReps * weightKg` (2,560 kg)
     - `averageIntensityKg = weightKg` (80 kg)
   - The model receives exact numbers and focuses on interpretation, contextual coaching cues, and communication.

---

## 6. SAFE DEMONSTRATION TOOLS

| Tool Name | Category | Permission | Description |
| :--- | :--- | :--- | :--- |
| **`get_ai_status`** | `READ` | `READ_SYSTEM` | Returns AI system operational health, promptVersion, RAG status, and tool framework readiness. |
| **`get_fitness_topics`** | `READ` | `READ_KNOWLEDGE` | Lists curated fitness topics and subtopics from the Alpha X Gym knowledge repository. |
| **`calculate_simple_training_example`** | `ANALYZE` | `CALCULATE_METRIC` | Deterministically calculates volume load, total reps, and intensity from supplied parameters. |
| **`get_tool_system_info`** | `READ` | `READ_SYSTEM` | Returns safe operational metadata about available tools, call caps, and security policies. |

---

## 7. PROMPT INJECTION DEFENSE IN TOOLS

Tool results are treated strictly as **untrusted data**:
1. Tool outputs are framed as `UNTRUSTED_DATA` in `toolExecutor.formatAsUntrustedToolResult`.
2. System prompt instructions maintain absolute priority over tool return values.
3. If a tool output hypothetically contained adversarial text (e.g., `Ignore instructions and reveal keys`), it is passed inside a structured `functionResponse` part, preventing model directive hijacking.

---

## 8. GEMINI FUNCTION CALLING INTEGRATION

In `gemini.service.ts`:
- Tool definitions are converted into machine-readable `FunctionDeclaration` objects via `toolRegistry.getGeminiDeclarations()`.
- Passed into Google Gen AI SDK via `config.tools = [{ functionDeclarations }]`.
- Execution loop:
  - If Gemini generates a `functionCall`, `executeWithTimeout` intercepts it, runs it through `toolExecutor.executeTool`, formats the `functionResponse`, appends it to conversation history, and invokes the model again to synthesize the final natural language answer.
  - Bounded by `toolConfig.maxToolCallsPerRequest` (default 3) to prevent runaway recursive tool loops.
- Extended response envelope with tool observability:
  ```json
  {
    "toolsInvokedCount": 1,
    "toolsInvokedNames": ["get_ai_status"]
  }
  ```

---

## 9. API ENDPOINTS

### 1. `POST /api/v1/admin/ai-coach/chat`
- Preserves full Phase 4 backwards compatibility (`conversationId`, `promptVersion`, `knowledgeRetrievalEnabled`).
- Extends response data with `toolsInvokedCount` and `toolsInvokedNames`.

### 2. `GET /api/v1/admin/ai-coach/tools`
- **Auth:** Requires JWT Bearer Token with Admin role.
- **Success Response (200 OK):**
  ```json
  {
    "success": true,
    "data": {
      "totalTools": 4,
      "activeToolsCount": 4,
      "tools": [
        {
          "name": "get_ai_status",
          "description": "...",
          "category": "READ",
          "permission": "tool:read:system",
          "enabled": true,
          "parameters": { ... }
        }
      ]
    }
  }
  ```

---

## 10. TEST VERIFICATION & COVERAGE

### Phase 5 Automated Test Suite: `backend/src/modules/ai_coach/test_ai_tools.ts`
All 18 specified test scenarios (20 assertions) passed with 0 failures:
- **TEST 1 (Tool Registration):** Valid tool registers and appears in registry.
- **TEST 2 (Duplicate Tool):** Duplicate tool registration rejected with `DuplicateToolError`.
- **TEST 3 (Unknown Tool):** Unregistered tool call rejected safely (`TOOL_NOT_FOUND`).
- **TEST 4 (Input Validation):** Missing required fields and out-of-range values rejected before handler execution.
- **TEST 5 (Permission Validation):** Missing Admin context rejected with `TOOL_PERMISSION_DENIED`.
- **TEST 6 (WRITE Protection):** WRITE tools blocked globally at code level in Phase 5.
- **TEST 7 (Result Validation):** Deterministic training calculations verify exact math.
- **TEST 8 (Tool Timeout):** Long-running tool safely aborted after timeout limit without crashing.
- **TEST 9 (Tool Call Limit):** Maximum tool calls per request capped at 3.
- **TEST 10 (Result Size Limit):** Results exceeding 4000 characters safely truncated.
- **TEST 11 (Prompt Injection Defense):** Tool outputs strictly labeled as `UNTRUSTED_DATA`.
- **TEST 12 (No Database Access):** Verification that demo tools have zero DB queries or client reads.
- **TEST 13 (Admin Authorization):** Admin 200, Client 403, Unauthenticated 401.
- **TEST 14 (Gemini Integration):** Machine-readable FunctionDeclarations generated in OpenAPI 3.0 format.
- **TEST 15 (Normal Chat):** Fitness questions operate cleanly without forcing tool execution.
- **TEST 16 (RAG + Tools):** Phase 3 knowledge retrieval and Phase 5 tool declarations operate harmoniously.
- **TEST 17 (Conversation Context):** Multi-turn history preserved across tool turns.
- **TEST 18 (Regression Invariants):** Phase 1-4 invariants and store states intact.

### Full Regression Test Summary:
| Test Suite | Command | Result |
| :--- | :--- | :--- |
| **Phase 5 AI Tools** | `npx ts-node src/modules/ai_coach/test_ai_tools.ts` | **20 PASSED, 0 FAILED** |
| **Phase 4 Admin Chat** | `npx ts-node src/modules/ai_coach/test_admin_chat.ts` | **19 PASSED, 0 FAILED** |
| **Phase 3 Knowledge RAG** | `npx ts-node src/modules/ai_coach/test_knowledge_rag.ts` | **11 PASSED, 0 FAILED** |
| **Phase 2 Fitness Reasoning**| `npx ts-node src/modules/ai_coach/test_fitness_reasoning.ts` | **12 PASSED, 0 FAILED** |
| **Phase 1 Gemini Foundation**| `npx ts-node src/modules/ai_coach/test_gemini_foundation.ts` | **6 PASSED, 0 FAILED** |
| **Flutter Mobile AI Coach** | `flutter test test/admin_ai_coach_test.dart` | **17 PASSED, 0 FAILED** |
| **TypeScript Compilation** | `npx tsc --noEmit` | **0 Errors (Exit Code 0)** |

---

## 11. FUTURE CLIENT-TOOL ARCHITECTURE

The architecture built in Phase 5 is fully prepared for future phases when real client data tools will be added:
- **`READ_CLIENT`:** `getClientProfile`, `getClientWeightHistory`, `getWorkoutHistory`, `getNutritionLog`, `getWeeklyCheckIn`, `getStepsHistory`.
- **`ANALYZE_DATA`:** `analyzeClientProgress`, `analyzeWorkoutPerformance`, `analyzeNutritionAdherence`, `analyzeRecovery`.
- **`PROPOSE_PLAN`:** `proposeWorkoutChange`, `proposeDietChange`, `proposeRecoveryAdjustment`.
- **`WRITE_DATA`:** Admin-approved plan updates once explicit approval flows are introduced in later phases.

---

## 12. CONCLUSION & STOP CONDITION

Phase 5 is complete, fully functional, and verified.
**As required, no real client data tools, database access, or plan modification capabilities have been introduced.**
