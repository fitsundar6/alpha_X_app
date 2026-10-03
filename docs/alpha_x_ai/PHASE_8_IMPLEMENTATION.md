# Alpha X AI — Phase 8 Implementation Documentation

## Deterministic Fitness Calculation Engine

**Status:** Complete & Fully Verified  
**Date:** October 2026  
**Phase:** 8 of 20  
**Repository:** Alpha X Gym (Flutter Mobile/Desktop + Node.js/Express TypeScript API + PostgreSQL Prisma ORM)

---

## 1. Executive Summary

Phase 8 implements the **Deterministic Fitness Calculation Engine** for Alpha X AI. 

### Core Architecture Principle:
```
REAL ALPHA X DATABASE DATA
          ↓
DETERMINISTIC BACKEND CALCULATION ENGINE
          ↓
STRUCTURED METRIC (source: 'ALPHA_X_DATABASE')
          ↓
GEMINI CONVERSATIONAL EXPLANATION & COACHING CONTEXT
```

Gemini is strictly **prohibited** from being the source of truth for arithmetic, summations, averages, differences, and statistical trends. All calculations over client body metrics, nutrition logs, workout volume, gym attendance, and weekly check-ins are performed by pure, deterministic TypeScript backend code. Gemini receives authoritative, structured results and interprets them for administrators and coaches.

---

## 2. Calculation Architecture

The calculation engine resides in `backend/src/modules/ai_coach/calculations/` with a modular, decoupled structure:

```
backend/src/modules/ai_coach/calculations/
├── calculation.types.ts       # Unified CalculationResult, metric enums, value contracts
├── calculation.errors.ts      # CalculationError, InsufficientDataError, InvalidCalculationInputError
├── calculation.validation.ts  # ISO date validator, precision rounding, safe aggregators
├── weight.calculator.ts       # Pure deterministic weight math (delta, %, min/max/avg)
├── waist.calculator.ts        # Pure deterministic waist math (cm units, delta, %)
├── nutrition.calculator.ts    # Actual intake aggregator & Target vs Actual comparison
├── activity.calculator.ts     # Step totals, averages, cardio, and goal achievement %
├── workout.calculator.ts      # Total volume load, session averages, RPE/RIR intensity
├── attendance.calculator.ts   # Attendance percentage strictly over recorded visits
├── checkin.calculator.ts      # Check-in frequency, sleep, and pain occurrence tracking
├── calculation.service.ts     # Prisma query coordinator & client context bridge
└── index.ts                   # Central module barrel export
```

### Decoupled Pure Calculators
Each calculator (`weight.calculator.ts`, `waist.calculator.ts`, etc.) is implemented as a pure mathematical class with zero database dependencies. This allows:
1. Complete deterministic unit testing with edge cases (zero values, negative numbers, single records).
2. Reuse across live Prisma database queries and temporary in-memory comparison payloads.
3. Strict isolation between data retrieval and mathematical evaluation.

---

## 3. Supported Metrics & Formulas

All calculations use IEEE 754 internal float precision and round final presentation values to exactly two decimal places (`round2` using standard arithmetic rounding with `Number.EPSILON` guard).

### 3.1 Weight Progress
- **Starting Weight (`startingWeightKg`):** Earliest valid record in selected chronological range.
- **Latest Weight (`latestWeightKg`):** Most recent valid record in selected chronological range.
- **Weight Change (`changeKg`):**
  $$\text{changeKg} = \text{latestWeight} - \text{startingWeight}$$
- **Weight Lost (`weightLostKg`):**
  $$\text{weightLostKg} = \begin{cases} \text{startingWeight} - \text{latestWeight}, & \text{if } \text{changeKg} < 0 \\ \text{null}, & \text{otherwise} \end{cases}$$
- **Percentage Change (`percentageChange`):**
  $$\text{percentageChange} = \left( \frac{\text{latestWeight} - \text{startingWeight}}{\text{startingWeight}} \right) \times 100$$
  *(Guarded: If starting weight $\le 0$, percentage is null).*
- **Average Weight (`averageWeightKg`):**
  $$\text{averageWeightKg} = \frac{\sum_{i=1}^N \text{weight}_i}{N}$$
- **Minimum Weight (`minimumWeightKg`):** $\min(\text{weights})$
- **Maximum Weight (`maximumWeightKg`):** $\max(\text{weights})$
- **Unit:** `kg`

### 3.2 Waist Circumference
- **Starting Waist (`startingWaistCm`):** Earliest valid waist record.
- **Latest Waist (`latestWaistCm`):** Latest valid waist record.
- **Absolute Waist Change (`changeCm`):** $\text{latestWaist} - \text{startingWaist}$
- **Waist Percentage Change (`percentageChange`):**
  $$\text{percentageChange} = \left( \frac{\text{latestWaist} - \text{startingWaist}}{\text{startingWaist}} \right) \times 100$$
- **Average Waist (`averageWaistCm`):** $\frac{\sum \text{waist}}{N}$
- **Unit:** Strictly centimeters (`cm`).

### 3.3 Nutrition & Assigned Target Comparison
- **Strict Separation:** Coach-assigned targets (`DietPlan` / `MacroPlan`) and actual logged items (`ClientFoodLog`) are kept strictly separated.
- **Aggregated Actual Totals:**
  - $\text{totalCalories} = \sum \text{calories}$
  - $\text{totalProtein} = \sum \text{protein}$ (grams)
  - $\text{totalCarbs} = \sum \text{carbohydrates}$ (grams)
  - $\text{totalFat} = \sum \text{fat}$ (grams)
  - $\text{totalFiber} = \sum \text{fiber}$ (grams)
- **Distinct Logged Days (`distinctDaysCount`):** Count of unique calendar dates with food logs.
- **Daily Intake Averages:**
  $$\text{averageDailyCalories} = \frac{\text{totalCalories}}{\text{distinctDaysCount}}$$
  $$\text{averageDailyProtein} = \frac{\text{totalProtein}}{\text{distinctDaysCount}}$$
  $$\text{averageDailyCarbs} = \frac{\text{totalCarbs}}{\text{distinctDaysCount}}$$
  $$\text{averageDailyFat} = \frac{\text{totalFat}}{\text{distinctDaysCount}}$$
  $$\text{averageDailyFiber} = \frac{\text{totalFiber}}{\text{distinctDaysCount}}$$
- **Mathematical Target Comparison:**
  $$\text{difference}_{\text{nutrient}} = \text{actualAverage} - \text{assignedTarget}$$
  *(Negative value indicates intake below target; positive value indicates intake above target).*
- **Units:** `kcal` (calories), `g` (protein, carbohydrates, fat, fiber).

### 3.4 Steps & Activity
- **Total Steps (`totalSteps`):** $\sum \text{steps}$
- **Daily Average Steps (`averageDailySteps`):** $\frac{\text{totalSteps}}{\text{daysRecorded}}$
- **Min / Max Steps:** $\min(\text{steps})$, $\max(\text{steps})$
- **Total Cardio Minutes (`totalCardioMinutes`):** $\sum \text{cardioMinutes}$
- **Average Cardio Minutes:** $\frac{\text{totalCardioMinutes}}{\text{daysRecorded}}$
- **Total Calories Burned:** $\sum \text{caloriesBurned}$
- **Step Goal Difference (`stepDifference`):**
  $$\text{stepDifference} = \text{averageDailySteps} - \text{stepGoal}$$
- **Goal Achievement Percentage (`goalAchievementPercentage`):**
  $$\text{goalAchievementPercentage} = \left( \frac{\text{averageDailySteps}}{\text{stepGoal}} \right) \times 100$$
- **Units:** `steps`, `minutes` (cardio), `kcal` (calories burned).

### 3.5 Workout Performance & Volume Load
- **Completed Sessions Count (`completedSessionsCount`):** Count of recorded sessions with `isCompleted = true`.
- **Total Volume Load (`totalVolumeKg`):**
  $$\text{totalVolumeKg} = \sum \text{totalVolume}$$
  *(Uses the authoritative application-stored session volume load; does not invent ad-hoc volume formulas).*
- **Average Session Volume (`averageSessionVolumeKg`):** $\frac{\text{totalVolumeKg}}{\text{completedSessionsCount}}$
- **Max Session Volume (`maxSessionVolumeKg`):** $\max(\text{totalVolume})$
- **Total Duration (`totalDurationMinutes`):** $\frac{\sum \text{durationSeconds}}{60}$
- **Average Duration (`averageDurationMinutes`):** $\frac{\text{totalDurationMinutes}}{\text{completedSessionsCount}}$
- **Total Completed Sets (`totalCompletedSets`):** $\sum \text{completedSetsCount}$
- **Average Completed Sets (`averageCompletedSets`):** $\frac{\text{totalCompletedSets}}{\text{completedSessionsCount}}$
- **Average RPE (`averageRpe`):** Arithmetic mean of non-null session RPE entries.
- **Average RIR (`averageRir`):** Arithmetic mean of non-null session RIR entries.
  *(Nulls are ignored; RIR is never converted to RPE).*
- **Units:** `kg` (volume), `minutes` (duration), `sets`, `RPE` (1-10 scale), `RIR` (reps in reserve).

### 3.6 Attendance Calculations
- **Total Records (`totalRecords`):** Total gym attendance entries in database for period.
- **Present Count (`presentCount`):** Count where `present === true`.
- **Absent Count (`absentCount`):** Count where `present === false`.
- **Attendance Percentage (`attendancePercentage`):**
  $$\text{attendancePercentage} = \left( \frac{\text{presentCount}}{\text{totalRecords}} \right) \times 100$$
- **Absence Boundary Rule:** Missing calendar days are **never** treated as absences. Calculations strictly evaluate recorded check-ins.
- **Unit:** `percentage` (`%`).

### 3.7 Weekly Check-Ins
- **Check-In Count (`checkInCount`):** Total check-in records in range.
- **Average Sleep Hours (`averageSleepHours`):** $\frac{\sum \text{sleepHours}}{\text{checkInCount}}$
- **Pain Reported Count (`painRecordedCount`):** Count of check-ins where `hasPain === true`.
- **Average Pain Rating (`averagePainLevel`):** Arithmetic mean of recorded pain levels (scale 1–10).
- **Categorical Distributions:** Explicit counts per response for `sleepQuality`, `recoveryQuality`, `dietAdherence`, `workoutCompletion`.
- **Medical Safety Rule:** Summaries are strictly descriptive arithmetic. Never used to infer medical conditions or diagnoses.

---

## 4. Phase 5 Tool Integration

All 7 calculation routines are integrated into the existing Phase 5 tool architecture under category `'ANALYZE'` and permission `ToolPermission.CALCULATE_METRIC`:

| Tool Name | Category | Permission | Primary Purpose |
| :--- | :--- | :--- | :--- |
| `calculate_client_weight_change` | `ANALYZE` | `tool:calculate:metric` | Deterministic body weight change, %, min/max/avg |
| `calculate_client_waist_change` | `ANALYZE` | `tool:calculate:metric` | Deterministic waist circumference change in cm |
| `calculate_client_nutrition_summary` | `ANALYZE` | `tool:calculate:metric` | Logged intake averages & optional target comparison |
| `calculate_client_activity_summary` | `ANALYZE` | `tool:calculate:metric` | Step totals, averages, cardio, and step goal % |
| `calculate_client_workout_summary` | `ANALYZE` | `tool:calculate:metric` | Volume load, duration, sets, average RPE/RIR |
| `calculate_client_attendance_summary` | `ANALYZE` | `tool:calculate:metric` | Gym attendance % strictly over recorded logs |
| `calculate_client_checkin_summary` | `ANALYZE` | `tool:calculate:metric` | Sleep hours, pain counts, and rating distributions |

### Automatic Pronoun & Client Context Resolution
All calculation tools declare `clientId` as a required input schema parameter. Under the Phase 7 `ToolExecutor` pipeline:
- If `clientId` is omitted or contains a pronoun (`he`, `she`, `they`, `his`, `her`, `the client`), `ToolExecutor` automatically binds `clientId` to `context.verifiedClient.clientId`.
- If no client context is active in the conversation, execution is safely rejected with `ToolValidationError` without performing unverified calculations.

---

## 5. Structured Result Format & Provenance

Every calculation output adheres to the standardized `CalculationResult` interface:

```typescript
export interface CalculationResult<T = any> {
  metric: string;
  status: 'SUCCESS' | 'NO_RECORDS_FOUND' | 'DATA_NOT_AVAILABLE' | 'INSUFFICIENT_DATA' | 'INVALID_INPUT';
  value: T;
  unit: string;
  source: 'ALPHA_X_DATABASE';
  calculationMethod: string;
  recordCount: number;
  startDate?: string | null;
  endDate?: string | null;
  startValue?: number | null;
  endValue?: number | null;
  message?: string;
}
```

### Example Weight Change Output:
```json
{
  "metric": "WEIGHT_SUMMARY",
  "status": "SUCCESS",
  "value": {
    "startingWeightKg": 82.0,
    "latestWeightKg": 80.0,
    "changeKg": -2.0,
    "weightLostKg": 2.0,
    "percentageChange": -2.44,
    "averageWeightKg": 81.0,
    "minimumWeightKg": 80.0,
    "maximumWeightKg": 82.0,
    "recordCount": 3,
    "startDate": "2026-09-01",
    "endDate": "2026-09-30",
    "unit": "kg"
  },
  "unit": "kg",
  "source": "ALPHA_X_DATABASE",
  "calculationMethod": "change = latest - earliest; percentage = (change / earliest) * 100",
  "recordCount": 3,
  "startDate": "2026-09-01",
  "endDate": "2026-09-30",
  "startValue": 82.0,
  "endValue": 80.0
}
```

---

## 6. Missing & Invalid Data Handling

The engine strictly rejects data fabrication:

1. **`NO_RECORDS_FOUND`:**
   - Returned when the database query returns 0 matching entries for the specified date range.
   - Values are populated with neutral nulls (`changeKg: null`, `averageWeightKg: null`).
2. **`INSUFFICIENT_DATA`:**
   - Returned when calculating a change over time (e.g. weight change, waist change) but only **one** measurement exists.
   - Descriptive metrics (`latestWeightKg`, `averageWeightKg`, `min/max`) are preserved.
   - Change metrics (`changeKg`, `weightLostKg`, `percentageChange`) are set to `null`.
   - Clear explanatory message provided: *"Insufficient data: only 1 weight record exists. At least 2 measurements are required to calculate change over time."*
3. **`INVALID_INPUT` / Sanitization:**
   - Negative body weights and zero starting weights are blocked from percentage calculations to prevent division by zero.
   - `NaN` and `Infinity` are trapped and sanitized to `0` via `round2`.
   - Chronological validation requires `start <= end` and enforces a maximum span of $\le 365$ days.

---

## 7. Security & Authorization

1. **Admin Authorization Guard:** AI routes enforce `requireAuth` and `requireAdmin`. Unauthenticated callers receive HTTP 401; non-admin users receive HTTP 403.
2. **Global WRITE Protection:** `ToolPermission.WRITE_DATA` and WRITE-category tools remain strictly disabled. Database mutation is completely blocked.
3. **Verified Client Isolation:** Calculations operate strictly against the active conversation's verified client context (`context.verifiedClient`). Data from Conversation A cannot leak into Conversation B.
4. **No Arbitrary Code Execution:** The AI is not provided generic code evaluation tools (`eval`, `executeCode`, `runDatabaseQuery`, `executeSQL`). Tools invoke only statically compiled TypeScript methods.
5. **Untrusted Data Marking:** All database records and calculation outputs passed to Gemini are wrapped in `[TOOL_RESULT:...] UNTRUSTED_DATA: ...` blocks to defend against prompt injection.

---

## 8. Test Verification & Results

All 81 required test cases were verified using real Neon PostgreSQL database fixtures in `backend/src/modules/ai_coach/test_calculations.ts`:

```bash
npx ts-node src/modules/ai_coach/test_calculations.ts
```

### Test Summary:
```
================================================================
🏁 PHASE 8 TEST SUMMARY: 81 PASSED, 0 FAILED
================================================================
```

### Full Breakdown:
- **General Architecture (1–6):** Module load, 7 tool registrations, admin auth, non-admin rejection, unauthenticated rejection, WRITE tool blocking. *(6/6 Passed)*
- **Weight Calculations (7–16):** Absolute change, percentage change, starting weight, latest weight, average weight, min weight, max weight, single-record insufficient data guard, zero starting weight protection, negative/invalid weight handling. *(10/10 Passed)*
- **Waist Calculations (17–20):** Absolute waist change, percentage change, average waist, missing waist handling. *(4/4 Passed)*
- **Nutrition & Target Comparison (21–30):** Daily calories, daily protein, carbs, fat, fiber, daily averages over logged days, target vs actual calorie difference, target vs actual protein difference, assigned diet separation. *(10/10 Passed)*
- **Steps & Activity (31–36):** Total steps, average steps, min/max steps, cardio minutes, step goal difference, step goal achievement percentage. *(6/6 Passed)*
- **Workout Performance & Volume (37–44):** Completed session count, total volume load, average session volume, average RPE, average RIR, total duration, average duration, completed sets count. *(8/8 Passed)*
- **Attendance (45–49):** Total records, present count, absent count, attendance percentage, unrecorded dates not treated as absences. *(5/5 Passed)*
- **Weekly Check-Ins (50–54):** Check-in count, average sleep hours, recovery quality distribution, diet adherence distribution, pain record count & average pain rating. *(5/5 Passed)*
- **Date Range Engine (55–58):** Malformed date rejection, startDate > endDate rejection, >365 day limit enforcement, inclusive UTC boundary verification. *(4/4 Passed)*
- **Data Integrity & Units (59–63):** Null values skipped without turning into fake zeros, NaN/Infinity sanitization, explicit unit preservation (kg, cm, percentage, kcal), 2-decimal rounding, zero data fabrication. *(5/5 Passed)*
- **Client Security & Isolation (64–68):** Automatic resolution of missing clientId to verifiedClient, unverified client rejection, cross-client data isolation, conversation isolation, prompt/SQL injection sanitization. *(5/5 Passed)*
- **Tool Execution & Gemini Integration (69–72):** Real Phase 6 client data fed to Phase 8 calculator, AI tool execution returning volume metrics, ALPHA_X_DATABASE provenance tag, untrusted tool result formatting. *(4/4 Passed)*
- **Regression Integrity (73–81):** Phase 1 Gemini Foundation, Phase 2 Fitness Reasoning, Phase 3 Knowledge RAG, Phase 4 Admin Chat, Phase 5 Tool Architecture, Phase 6 Client Data, Phase 7 Client Identification, Flutter Mobile Tests (18/18), TypeScript Compilation (`npx tsc --noEmit` exited 0). *(9/9 Passed)*

### Regression Suite Status:
| Suite | Command | Result |
| :--- | :--- | :--- |
| **Phase 8 Calculations** | `npx ts-node src/modules/ai_coach/test_calculations.ts` | **81 PASSED, 0 FAILED** |
| **Phase 7 Client Identification** | `npx ts-node src/modules/ai_coach/test_client_identification.ts` | **37 PASSED, 0 FAILED** |
| **Phase 6 Client Data** | `npx ts-node src/modules/ai_coach/test_client_data_tools.ts` | **33 PASSED, 0 FAILED** |
| **Phase 5 Tool Engine** | `npx ts-node src/modules/ai_coach/test_ai_tools.ts` | **20 PASSED, 0 FAILED** |
| **Flutter Mobile App** | `flutter test test/admin_ai_coach_test.dart` | **18 PASSED, 0 FAILED** |
| **TypeScript Build** | `npx tsc --noEmit` | **0 Errors (Exit Code 0)** |

---

## 9. Files Created & Modified

### Files Created:
1. `backend/src/modules/ai_coach/calculations/calculation.types.ts` — Core interfaces and value types.
2. `backend/src/modules/ai_coach/calculations/calculation.errors.ts` — Error classes for calculation boundaries.
3. `backend/src/modules/ai_coach/calculations/calculation.validation.ts` — Precision rounding and date range validators.
4. `backend/src/modules/ai_coach/calculations/weight.calculator.ts` — Pure deterministic weight math.
5. `backend/src/modules/ai_coach/calculations/waist.calculator.ts` — Pure deterministic waist math.
6. `backend/src/modules/ai_coach/calculations/nutrition.calculator.ts` — Intake aggregator and target comparison.
7. `backend/src/modules/ai_coach/calculations/activity.calculator.ts` — Activity and step analytics.
8. `backend/src/modules/ai_coach/calculations/workout.calculator.ts` — Volume load and workout intensity metrics.
9. `backend/src/modules/ai_coach/calculations/attendance.calculator.ts` — Gym attendance percentage engine.
10. `backend/src/modules/ai_coach/calculations/checkin.calculator.ts` — Sleep, pain, and reflection aggregation.
11. `backend/src/modules/ai_coach/calculations/calculation.service.ts` — Prisma database coordinator.
12. `backend/src/modules/ai_coach/calculations/index.ts` — Module barrel export.
13. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_weight_change.ts` — Weight tool definition.
14. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_waist_change.ts` — Waist tool definition.
15. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_nutrition_summary.ts` — Nutrition tool definition.
16. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_activity_summary.ts` — Activity tool definition.
17. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_workout_summary.ts` — Workout tool definition.
18. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_attendance_summary.ts` — Attendance tool definition.
19. `backend/src/modules/ai_coach/tools/definitions/calculations/calculate_client_checkin_summary.ts` — Check-in tool definition.
20. `backend/src/modules/ai_coach/tools/definitions/calculations/index.ts` — Calculation tools barrel export.
21. `backend/src/modules/ai_coach/test_calculations.ts` — 81-test comprehensive Phase 8 test suite.
22. `docs/alpha_x_ai/PHASE_8_IMPLEMENTATION.md` — Technical implementation document.

### Files Modified:
1. `backend/src/modules/ai_coach/tools/index.ts` — Exported and registered `CALCULATION_TOOLS` in `ALL_DEFAULT_TOOLS`.
2. `backend/src/modules/ai_coach/prompts/system_prompt.ts` — Added Section 5 Deterministic Backend Calculation rules instructing Gemini to use calculation tools for all arithmetic.

---

## 10. Dependencies

Zero external libraries were added. Built strictly on top of existing Node.js, Express, Prisma ORM, and Flutter test frameworks.

---

## 11. Known Limitations & Deferred Scope

In strict accordance with Phase 8 boundaries:
- **No Advanced Analytics or Predictive Modeling:** Trend forecasting, linear regression, target date predictions, and plateau detection were intentionally omitted (deferred to future phases).
- **No Adherence Scoring or Complex Composite Indexes:** No overall "activity scores" or subjective compliance scores were synthesized.
- **Strict Read-Only Enforcement:** No calculation results are written into the database. Calculations are computed dynamically from source records on demand.
- **Zero Medical Inferences:** Pain ratings and injury areas are reported as raw arithmetic counts and scales without clinical diagnosis.
