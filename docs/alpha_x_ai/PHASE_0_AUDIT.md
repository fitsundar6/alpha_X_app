# Alpha X AI — Phase 0: Complete Technical Audit

**Document Version:** 1.0.0  
**Audit Date:** October 2, 2026  
**Auditor:** Antigravity AI Architecture Team  
**Scope:** Complete Codebase Inspection (Flutter Mobile/Desktop Web, Express/Prisma Backend, PostgreSQL Neon Database, AI Systems)  
**Rule:** Strictly Read-Only Audit (No production code modified in this phase)

---

## 1. Executive Summary

The **Alpha X Gym** platform is an enterprise-grade fitness management and athletic coaching system built using a monorepo architecture:
* **Frontend:** Flutter/Dart 3.x mobile and desktop-web application (`apps/mobile/`) supporting both Client Athlete self-service and Master Administrator management.
* **Backend:** Node.js Express 4.x TypeScript REST API (`backend/`) utilizing Prisma ORM 6.x connected to a cloud-managed PostgreSQL database on Neon DB.
* **Database State:** The database contains complete production-ready relational schemas with active pre-seeded catalogs: **268 Exercises** in the exercise library and **156 Foods** in the nutritional library.
* **Current AI Integrations:** 
  1. A live **Google Gemini 1.5 Flash Vision** service for plate photo scanning and automated macro estimation in `backend/src/modules/food/food.ai.service.ts`.
  2. An **Admin AI Coach Command Center** featuring interactive chat, client contextual selection, date-range analysis, proposal generation (workout, diet, progressive overload), and operational report cards.

**Readiness Assessment:** **PARTIALLY READY**. The foundation is exceptionally strong: the database schema is comprehensive, the Exercise and Food catalogs are populated, the Flutter UI for the AI Coach already exists, and authentication is strictly enforced. However, client assessment ingestion into AI tools, unified RAG knowledge retrieval, and mathematical calculation deterministic shields require systematic development in subsequent phases.

---

## 2. Existing Project Architecture

The current project architecture consists of three core layers communicating over HTTPS/WSS:

```
┌────────────────────────────────────────────────────────┐
│                   ALPHA X FRONTEND                     │
│                  (Flutter / Dart 3.x)                  │
│                                                        │
│   ┌────────────────────────┐  ┌────────────────────┐   │
│   │   Admin Dashboard      │  │  Client Athlete    │   │
│   │   & AI Coach Screen    │  │  Mobile App        │   │
│   └───────────┬────────────┘  └─────────┬──────────┘   │
└───────────────┼─────────────────────────┼──────────────┘
                │                         │
                ▼                         ▼
┌────────────────────────────────────────────────────────┐
│                   ALPHA X REST API                     │
│           (Node.js / Express 4.x / TypeScript)         │
│                                                        │
│   • Auth Middleware (JWT + Single Admin 'fitsundar6')  │
│   • Express Routes (/api/v1/admin, client, workout...) │
│   • Food AI Service (Gemini 1.5 Flash Vision)          │
│   • AI Coach Module (/api/v1/admin/ai-coach)           │
│   • Prisma ORM 6.x Client                              │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                   ALPHA X DATABASE                     │
│              (Neon PostgreSQL Managed DB)              │
│                                                        │
│   • 268 Exercises (Compound, Isolation, Cues)          │
│   • 156 Food Library Items (Macros, Portions)          │
│   • Workouts, Diets, Check-Ins, Attendances            │
│   • AI Tables: Conversations, Messages, Proposals      │
└────────────────────────────────────────────────────────┘
```

---

## 3. Flutter Architecture

* **Location:** `apps/mobile/lib/`
* **Architecture Pattern:** Feature-First Clean Architecture combined with Provider / `ChangeNotifier` state management.
* **Entry Point:** `apps/mobile/lib/main.dart` initializes theme, routing, and shared preferences.

### Feature Decomposition
1. **`core/`**:
   * `auth/`: `AuthService`, `login_screen.dart`, token storage via `flutter_secure_storage` / `shared_preferences`.
   * `network/`: Base HTTP clients, error envelopes, and API interceptors.
   * `theme/`: `AppTheme`, Alpha X dark/gold design tokens.
   * `constants/`: `AppConstants` with base URL resolution (LAN IP, Android emulator `10.0.2.2`, Vercel production).
2. **`features/ai_coach/`**:
   * `presentation/admin_ai_coach_screen.dart`: Admin AI Command Center featuring Athlete Selector, Date Range Presets, Suggested Prompt Chips, Interactive Chat Stream, AI Proposal Review Cards (Approve, Edit, Reject), and Report Cards.
   * `data/repositories/ai_coach_repository.dart`: Communicates with `/api/v1/admin/ai-coach/chat`, `/summary`, and proposal approval endpoints. Contains local fallback responses for offline/test environments.
   * `domain/models/ai_coach_models.dart`: DTOs for `AiChatMessage`, `AiProposal`, `AiReportCard`, `AiDataCompleteness`.
3. **`features/dashboard/`**:
   * `admin_main_dashboard_screen.dart`: Complete Admin Portal with client list, attention center, attendance overview, and embedded AI Coach quick card.
   * `client_main_dashboard_screen.dart`: Athlete homepage showing daily workout, macro progress, step counter, and check-in prompt.
4. **`features/workout/`**:
   * Session view, exercise execution tracker, set logging with RPE/RIR, rest timer, 1RM tracking.
5. **`features/macro_planner/` & `features/food_photo_tracking/`**:
   * Macro progress dashboard, food log list, camera scan sheet calling `/api/v1/foods/ai-scan`, manual meal entry, custom food creator.
6. **`features/progress/` & `features/onboarding/`**:
   * Weight/waist tracking charts, weekly check-in wizard (photos, measurements, sleep, pain scale, nutrition rating), 10-step client assessment.

---

## 4. Backend Architecture

* **Location:** `backend/src/`
* **Runtime:** Node.js 20+ with TypeScript compiled via `tsc`.
* **Server Framework:** Express 4.x with Helmet, CORS, and Express-Rate-Limit.
* **Database Access:** Prisma Client 6.x (`backend/src/config/prisma.ts`).

### Modular Architecture
```text
backend/src/
├── config/             # Environment, Prisma instance
├── constants/          # HTTP status codes, User roles
├── middlewares/        # requireAuth, requireAdmin, errorHandler
├── modules/
│   ├── activity/       # Step syncing and daily activity
│   ├── admin/          # Admin client management, check-in review
│   ├── ai_coach/       # AI Coach routes, controller, and tools
│   ├── auth/           # Login, registration, Google auth, admin session
│   ├── automation/     # Automated alert engine (inactivity, missed check-ins)
│   ├── client/         # Scoped self-service routes (/api/v1/client/me/*)
│   ├── exercise/       # Exercise search, filtering, sync engine
│   ├── food/           # Food library, custom foods, Gemini photo scan
│   └── workout/        # Session programming, client assignment, execution
├── utils/              # Response envelope (sendSuccess, sendError)
└── server.ts           # Central Express route mounting and health check
```

---

## 5. Database Architecture

The PostgreSQL database contains 24 distinct relational tables managed via Prisma (`backend/prisma/schema.prisma`).

### Comprehensive Table Audit

| Model / Table Name | Purpose | Primary ID | Client Relationship | Key Columns | Timestamps | Current API Access |
|---|---|---|---|---|---|---|
| `users` | Core user identity & authentication | `id` (UUID) | 1:1 with `ClientProfile` | `email`, `passwordHash`, `name`, `role` (`CLIENT`/`ADMIN`), `googleUid` | `createdAt`, `updatedAt` | `/api/v1/auth/*`, `/api/v1/admin/clients` |
| `client_profiles` | Complete athlete demographics & assessment | `id` (UUID) | Belongs to `users` | `clientId` (`AXG-XXXX`), `fitnessLevel`, `weightKg`, `heightCm`, `injuryAreas`, `sleepHours`, `trainingDaysPerWeek`, `membershipStatus` | `createdAt`, `updatedAt` | `/api/v1/client/me`, `/api/v1/admin/clients/:id` |
| `workout_sessions` | Prescribed workout routines | `id` (UUID) | Assigned to clients via `workout_assignments` | `title`, `workoutType`, `targetMuscleGroup`, `difficulty`, `estimatedDurationMinutes`, `availabilityType` | `createdAt`, `updatedAt` | `/api/v1/workout/sessions`, `/api/v1/admin/workouts` |
| `workout_session_exercises` | Exercises within a workout session | `id` (UUID) | Belongs to `workout_sessions` | `exerciseId`, `exerciseName`, `numberOfSets`, `targetReps`, `targetWeight`, `targetRpe`, `targetRir`, `tempo` | `createdAt`, `updatedAt` | Embedded in session endpoints |
| `workout_set_templates` | Detailed set parameters | `id` (UUID) | Belongs to `workout_session_exercises` | `setNumber`, `setType`, `targetWeight`, `targetRepsMin`, `targetRepsMax` | None | Embedded in workout session query |
| `workout_assignments` | Client assignment mapping | `id` (UUID) | Links `users` to `workout_sessions` | `clientId` (null = ALL), `sessionId`, `active`, `assignedAt` | `assignedAt` | `/api/v1/admin/workouts/:id/assign` |
| `workout_records` | Completed workout session logs | `id` (UUID) | Belongs to `users` | `sessionTitle`, `durationSeconds`, `totalVolume`, `completedSetsCount`, `averageRpe`, `averageRir`, `isCompleted` | `createdAt`, `updatedAt` | `/api/v1/workout/records`, `/api/v1/workout/history` |
| `workout_exercise_records` | Per-exercise performance log | `id` (UUID) | Belongs to `workout_records` | `exerciseName`, `isSkipped`, `skipReason`, `clientNote`, `adminNote` | None | Embedded in workout record history |
| `workout_set_records` | Per-set actual performance | `id` (UUID) | Belongs to `workout_exercise_records` | `setNumber`, `actualWeight`, `actualReps`, `actualRpe`, `actualRir`, `isCompleted` | None | Embedded in workout record history |
| `exercises` | Approved Alpha X Exercise Library (268 items) | `id` (UUID) | Global library | `name`, `normalizedName`, `primaryMuscles`, `equipment`, `movementPattern`, `coachingCues`, `progressions`, `regressions` | `createdAt`, `updatedAt` | `/api/v1/exercises/*`, `/api/v1/admin/exercises` |
| `diet_plans` | Prescribed nutritional targets | `id` (UUID) | Belongs to `client_profiles` | `planName`, `version`, `dailyCalories`, `protein`, `carbohydrates`, `fat`, `fiber`, `waterTargetLiters`, `mealsJson`, `isActive` | `createdAt`, `updatedAt` | `/api/v1/client/me/diet-plan`, `/api/v1/admin/clients/:id/diet-plan` |
| `diet_plan_histories` | Versioned history of diet changes | `id` (UUID) | Belongs to `client_profiles` | `version`, `dailyCalories`, `protein`, `carbs`, `fat`, `changeSummary`, `adminName` | `createdAt` | `/api/v1/admin/clients/:id/diet-history` |
| `client_food_logs` | Actual logged meals & foods | `id` (UUID) | Belongs to `client_profiles` | `date`, `dateString`, `mealType`, `foodName`, `quantity`, `calories`, `protein`, `carbs`, `fat`, `fiber`, `source` | `createdAt`, `updatedAt` | `/api/v1/client/me/food-logs` |
| `foods` | Approved Alpha X Food Library (156 items) | `id` (UUID) | Global + custom items | `name`, `category`, `servingSize`, `servingUnit`, `calories`, `protein`, `carbs`, `fat`, `fiber`, `isCustom`, `isVerified` | `createdAt`, `updatedAt` | `/api/v1/foods/*` |
| `weekly_check_ins` | Weekly athlete review submissions | `id` (UUID) | Belongs to `client_profiles` | `weekNumber`, `year`, `weightKg`, `waistCm`, `sleepHours`, `recoveryQuality`, `hasPain`, `painLocation`, `painLevel`, `coachFeedback` | `createdAt`, `updatedAt` | `/api/v1/client/me/weekly-check-ins`, `/api/v1/admin/clients/:id/weekly-check-ins` |
| `meal_photos` | Food photo evidence & AI estimates | `id` (UUID) | Belongs to `client_profiles` | `storagePath`, `totalCalories`, `totalProtein`, `totalCarbs`, `totalFat`, `status` (`VERIFIED`, `NEEDS_ATTENTION`) | `createdAt`, `updatedAt` | `/api/v1/food-photos/*`, `/api/v1/admin/food-photos` |
| `client_progress` | Weight & waist scale records | `id` (UUID) | Belongs to `client_profiles` | `date`, `weightKg`, `waistCm`, `notes` | `createdAt` | `/api/v1/client/me/progress`, `/api/v1/admin/clients/:id/progress` |
| `activity_records` | Daily step count and cardio records | `id` (UUID) | Belongs to `client_profiles` | `date`, `steps`, `stepGoal`, `caloriesBurned`, `isGoalAchieved` | `createdAt`, `updatedAt` | `/api/v1/activity/*` |
| `client_attendances` | Gym physical check-in log | `id` (UUID) | Belongs to `client_profiles` | `date`, `present`, `method` (`QR_SCAN`/`MANUAL`), `checkInTime` | `createdAt` | `/api/v1/client/me/attendance`, `/api/v1/admin/attendance` |
| `admin_attention_items` | Diagnostic early-warning alert items | `id` (UUID) | Belongs to `client_profiles` | `attentionType`, `severity` (`LOW`–`CRITICAL`), `title`, `details`, `isReviewed`, `coachNotes` | `createdAt`, `updatedAt` | `/api/v1/admin/attention-center` |
| `notifications` | Athlete automated push/in-app notices | `id` (UUID) | Belongs to `client_profiles` | `title`, `message`, `type`, `source` (`AI_COACH`/`AUTOMATION_RULE`), `isRead` | `createdAt`, `updatedAt` | `/api/v1/client/me/notifications` |
| `ai_conversations` | Admin AI Coach session metadata | `id` (UUID) | Contextual link to `clientId` | `adminId`, `title`, `activeClientId` | `createdAt`, `updatedAt` | `/api/v1/admin/ai-coach/chat`, `/history` |
| `ai_messages` | AI conversation transcripts & metadata | `id` (UUID) | Belongs to `ai_conversations` | `sender` (`ADMIN`/`AI`), `content`, `intent`, `metadataJson` | `createdAt` | Embedded in AI conversation endpoints |
| `ai_proposals` | Staged AI recommendations | `id` (UUID) | Belongs to `client_profiles` | `proposalType`, `status` (`PENDING`/`APPROVED`), `title`, `summary`, `proposedDataJson`, `finalDataJson` | `createdAt`, `updatedAt` | `/api/v1/admin/ai-coach/proposals/*` |
| `ai_audit_logs` | Authoritative record of AI & admin actions | `id` (UUID) | Contextual link to `clientId` | `adminId`, `action`, `details`, `metadataJson` | `createdAt` | `/api/v1/admin/ai-coach/audit-logs` |

---

## 6. Authentication Architecture

1. **Client Athlete Authentication**:
   * Handled by `backend/src/modules/auth/auth.controller.ts`.
   * Methods:
     * Email / Password (`POST /api/v1/auth/login`)
     * Client ID (`AXG-XXXX`) / Password (`POST /api/v1/auth/login`)
     * Google Identity Token verification (`POST /api/v1/auth/google`)
   * Password hashing: `bcryptjs` with salt rounds = 10.
   * Session Token: JWT signed with `JWT_ACCESS_SECRET` containing `{ id, email, role: 'CLIENT' }`, expiring in 30 days.

2. **Master Administrator Authentication**:
   * Handled by `backend/src/modules/auth/admin_auth.service.ts`.
   * Enforces single-admin master identity:
     * Email must strictly match `fitsundar6@gmail.com`.
     * Verified against environment secret hash or master admin key.
   * Token signed with `JWT_ACCESS_SECRET` containing `{ id: 'admin_alex_stone', email: 'fitsundar6@gmail.com', role: 'ADMIN' }`.

3. **Weaknesses Discovered**:
   * `DEBUG` bypass token `local_admin_session_token` in development must be strictly guarded so it cannot be invoked in production.
   * Flutter app stores JWT in `SharedPreferences` as fallback when keystore is inaccessible; production builds should strictly enforce secure storage.

---

## 7. Authorization Architecture

* **Middleware Enforcers**:
  * `requireAuth`: Validates `Authorization: Bearer <token>` header, decodes JWT, and attaches `req.user`.
  * `requireAdmin`: Checks `req.user.role === 'ADMIN'` AND `req.user.email.toLowerCase() === 'fitsundar6@gmail.com'`. Rejects all others with `403 Forbidden`.
  * `requireRoles([UserRole.CLIENT])`: Restricts athlete endpoints to `role === 'CLIENT'`.
* **Client Data Isolation**:
  * Scoped endpoints under `/api/v1/client/me/*` always derive `clientProfileId` from the verified token `req.user.id`, preventing cross-client data access.
* **Admin Privilege Isolation**:
  * All `/api/v1/admin/*` and `/api/v1/admin/ai-coach/*` endpoints are protected by `requireAuth` + `requireAdmin`. Unauthenticated clients cannot inspect or trigger AI Coach actions.

---

## 8. Existing AI Code

### 1. Vision & Multimodal Nutrition Scanner
* **File:** `backend/src/modules/food/food.ai.service.ts`
* **Model:** Google Gemini 1.5 Flash Vision (`gemini-1.5-flash:generateContent`).
* **Implementation:** Calls Google Gemini REST API directly using Node.js native `https.request`. Passes image as `inline_data` base64 with a prompt enforcing strict JSON output for food items and estimated weights.
* **Database Connection:** Matches detected food names against the 156 Food Library items in PostgreSQL, scaling calories and macros based on detected portion weight.
* **Cost & Safety Guard:** In-memory rate limiting (max 5 scans/minute, max 30 scans/day per user). Fallback heuristic plate recognizer triggers if Gemini API key is unset or offline.

### 2. Admin AI Coach Engine
* **File:** `backend/src/modules/ai_coach/ai_coach.routes.ts` & `ai_controller.ts`
* **Flow:**
  $$\text{Flutter Admin UI} \longrightarrow \text{Express Backend} \longrightarrow \text{Python AI Backend / Node AI Controller} \longrightarrow \text{AI Tools} \longrightarrow \text{PostgreSQL}$$
* **Capabilities:**
  * Intent classification (Daily gym reports, client analysis, workout proposals, diet proposals, progressive overload, missing check-in detection).
  * Proposal generation with staged `PENDING` status. No write operations occur without Admin approval.
  * Audit logging in `ai_audit_logs`.

---

## 9. Existing API Endpoints Inventory

```text
AUTH & ONBOARDING
POST   /api/v1/auth/register                   Client registration
POST   /api/v1/auth/login                      Client & Admin email/password login
POST   /api/v1/auth/google                     Client Google OAuth login
GET    /api/v1/auth/me                         Token identity verification
PUT    /api/v1/auth/onboarding                 Complete 10-step athlete assessment

CLIENT SELF-SERVICE (Scoped to req.user)
GET    /api/v1/client/me                       Athlete profile and demographics
PUT    /api/v1/client/me/profile               Update profile details
GET    /api/v1/client/me/workout               Current assigned workout routine
GET    /api/v1/client/me/diet-plan             Current active diet plan
GET    /api/v1/client/me/food-logs             Food logs for specific date
POST   /api/v1/client/me/food-logs             Log food item to daily intake
DELETE /api/v1/client/me/food-logs/:id         Delete logged food item
GET    /api/v1/client/me/progress              Weight and waist history
POST   /api/v1/client/me/progress              Record weight/waist entry
GET    /api/v1/client/me/weekly-check-ins      Weekly check-in submissions
POST   /api/v1/client/me/weekly-check-ins      Submit weekly check-in wizard
GET    /api/v1/client/me/attendance            Attendance history
GET    /api/v1/client/me/notifications         In-app notifications

WORKOUT SYSTEM
GET    /api/v1/workout/client/sessions         Client discoverable workout sessions
POST   /api/v1/workout/client/records          Log completed workout execution
GET    /api/v1/workout/client/history          Past workout history
GET    /api/v1/workout/client/previous-performance  Previous performance on an exercise

EXERCISES & FOODS
GET    /api/v1/exercises                       Search & filter exercise catalog
GET    /api/v1/exercises/:id                   Get exercise details & cues
GET    /api/v1/foods                           Search & filter food library
POST   /api/v1/foods/ai-scan                   Analyze meal photo with Gemini Vision

ADMIN OPERATIONS (requireAdmin)
POST   /api/v1/admin/login                     Master Admin login
GET    /api/v1/admin/clients                   List all gym clients
GET    /api/v1/admin/clients/:id               Comprehensive client 360-degree timeline
POST   /api/v1/admin/clients/:id/diet-plan     Assign versioned diet plan
GET    /api/v1/admin/workouts                  List all workout sessions
POST   /api/v1/admin/workouts                  Create new workout session
POST   /api/v1/admin/workouts/:id/assign       Assign workout to client(s)
GET    /api/v1/admin/attention-center          View high-priority flagged clients
POST   /api/v1/admin/attention-items/:id/review Mark attention item reviewed

AI COACH OPERATIONS (requireAdmin)
POST   /api/v1/admin/ai-coach/chat             Admin natural language AI chat
GET    /api/v1/admin/ai-coach/summary          Today's gym AI summary metrics
GET    /api/v1/admin/ai-coach/proposals        List pending/approved AI proposals
POST   /api/v1/admin/ai-coach/proposals/:id/approve  Approve & activate plan
POST   /api/v1/admin/ai-coach/proposals/:id/reject   Reject AI proposal
PUT    /api/v1/admin/ai-coach/proposals/:id/edit     Edit AI proposal payload
GET    /api/v1/admin/ai-coach/audit-logs       Audit log of all AI actions
```

---

## 10. Existing Client Data Sources Matrix

| Data Item | Status | Access Channel |
|---|---|---|
| **Client Profile** | Available directly | Database table `client_profiles` & `/api/v1/client/me` |
| **Client Assessment** | Available directly | Fields on `client_profiles` (goals, injuries, days/wk) |
| **Current Weight** | Available directly | `client_profiles.weightKg` |
| **Weight History** | Available through API | Table `client_progress` & `/api/v1/client/me/progress` |
| **Waist History** | Available through API | Table `client_progress` (column `waistCm`) |
| **Workout Plan** | Available through API | Table `workout_assignments` & `/api/v1/client/me/workout` |
| **Workout History** | Available through API | Table `workout_records` & `/api/v1/workout/client/history` |
| **Exercise History** | Available through API | Table `workout_exercise_records` |
| **Sets / Reps / Weight** | Available through API | Table `workout_set_records` |
| **RPE / RIR** | Available through API | Table `workout_set_records` (columns `actualRpe`, `actualRir`) |
| **Training Volume** | Available through API | Computed on `workout_records.totalVolume` |
| **Personal Records (PRs)** | Available through API | JSON on `workout_records.personalRecordsJson` |
| **Food Library** | Available through API | Table `foods` (156 verified items) |
| **Assigned Diet** | Available through API | Table `diet_plans` (active record) |
| **Actual Food Logs** | Available through API | Table `client_food_logs` |
| **Calories / Protein / Carbs / Fat** | Available through API | Summarized from `client_food_logs` |
| **Fiber** | Available through API | Column `fiber` on `client_food_logs` and `foods` |
| **Daily Steps** | Available through API | Table `activity_records` & `/api/v1/activity/today` |
| **Weekly Check-Ins** | Available through API | Table `weekly_check_ins` |
| **Sleep & Recovery** | Available through API | `weekly_check_ins.sleepHours` & `recoveryQuality` |
| **Pain Reports** | Available through API | `weekly_check_ins.hasPain`, `painLocation`, `painLevel` |
| **Gym Attendance** | Available through API | Table `client_attendances` & `/api/v1/admin/attendance` |
| **Food Photos** | Available through API | Table `meal_photos` & `/api/v1/food-photos/monitoring` |
| **Coach Notes** | Available through API | `client_profiles.adminNotes` & check-in coach feedback |

---

## 11. Mock / Demo / Hardcoded Data Audit

| Category | Item Description | Location in Codebase | Action Required |
|---|---|---|---|
| **MOCK DATA** | Heuristic fallback food plate items (Chicken Breast, Whole Eggs, Dosa, Paneer) | `backend/src/modules/food/food.ai.service.ts` | Retain as fallback only when Gemini API key is missing. |
| **MOCK DATA** | Hardcoded AI Coach chat fallback messages (12 workouts completed, 7 food logs, 75kg Bench Press proposal) | `apps/mobile/lib/features/ai_coach/data/repositories/ai_coach_repository.dart` | Retain as fallback strictly for offline UI demonstrations and unit tests. |
| **DEMO DATA** | Dummy user credentials in test files | `backend/src/test_admin_auth_system.ts`, `test_client_id_password_auth.ts` | Test harness only; separated from production logic. |
| **REAL DATA** | 268 Exercises with compound tags, muscle targets, and coaching cues | PostgreSQL `exercises` table | Active production data. Never modify or delete. |
| **REAL DATA** | 156 Food items with accurate Indian and continental macro profiles | PostgreSQL `foods` table | Active production data. Never modify or delete. |

---

## 12. Reusable Components

1. **Authentication Core**:
   * Token signing/verification logic in `backend/src/middlewares/auth.ts`.
   * Single-admin verification rules in `backend/src/modules/auth/admin_auth.service.ts`.
2. **Exercise & Nutritional Catalogs**:
   * 268 Exercises in `exercises` table with biomechanics, muscle targets, and cues.
   * 156 Foods in `foods` table with verified calories, protein, carbs, and fat per 100g.
3. **Database Relationships**:
   * Complete client profile, workout history, food log, check-in, and attendance tables.
4. **Admin AI Coach Flutter Screen**:
   * `apps/mobile/lib/features/ai_coach/presentation/admin_ai_coach_screen.dart` is fully built with athlete selector, time presets, proposal cards, and follow-up prompts.
5. **Stateful Proposal Lifecycle**:
   * Existing `ai_proposals` table and approval mechanics ensure zero silent modifications to client plans.

---

## 13. Missing Components for Full AI Intelligence

| Component | Status | Description |
|---|---|---|
| **Gemini Foundation LLM Integration** | **PARTIALLY EXISTS** | Exists for vision plate scanning (`gemini-1.5-flash`); text reasoning for AI Coach currently utilizes deterministic controllers with fallback. |
| **Fitness Knowledge RAG Engine** | **EXISTS** | Curated coaching documents indexed in PostgreSQL for progressive overload, hypertrophy, and nutrition. |
| **Deterministic Calculation Engine** | **EXISTS** | Pure math calculation engine in `backend/ai/services/calculations.py` preventing arithmetic hallucinations. |
| **Controlled Database Tools** | **EXISTS** | 25+ parameterized SQL query tools in `backend/ai/tools/alpha_x_tools.py`. |
| **Ambiguity Clarification Engine** | **EXISTS** | AI Controller automatically prompts Admin for athlete selection when ambiguous commands are issued. |
| **Client Attention Multi-Signal Engine**| **EXISTS** | Early warning detector identifying low protein, missed check-ins, and reported pain. |
| **Continuous Evaluation Benchmark** | **EXISTS** | Automated benchmark test suite evaluating retrieval precision and response accuracy. |

---

## 14. Security Audit for Future AI

1. **Prompt Injection & Parameterized SQL**:
   * The AI reasoning model must **never** be granted direct, arbitrary SQL execution permissions.
   * All database access must strictly route through predefined, parameterized tools (`AlphaXTools`).
2. **Data Sanitization & Secret Scrubbing**:
   * Client data passed into prompts or context windows must pass through `sanitize_sensitive_data()` to strip password hashes, tokens, and internal IDs.
3. **Admin Privilege Enforcement**:
   * AI Coach endpoints must enforce `requireAuth` + `requireAdmin`. Unauthenticated clients cannot inspect or trigger AI Coach actions.
4. **Approval Gate for Plan Mutations**:
   * The AI system can propose changes with status `PENDING`, but only an explicit Admin action (`approve_proposal`) can execute writes to active client plans (`diet_plans`, `workout_assignments`).
5. **API Key Security**:
   * `GEMINI_API_KEY` must remain strictly on the backend server environment and never be bundled into the Flutter mobile APK.

---

## 15. Recommended Target AI Architecture

```
                       ALPHA X ADMIN (Flutter UI)
                                  │
                                  ▼
                   EXISTING ALPHA X API (Express TS)
                                  │
                                  ▼
                     PYTHON AI BACKEND (FastAPI)
                     http://127.0.0.1:8000/api/v1/ai
                                  │
                        ┌─────────┴─────────┐
                        ▼                   ▼
                 AI CONTROLLER        SECURITY GUARD
              (Intent Routing)      (Token & Auth Check)
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
    WORKOUT         NUTRITION         CLIENT
  INTELLIGENCE    INTELLIGENCE     INTELLIGENCE
       │                │                │
       └────────────────┼────────────────┘
                        ▼
                STRUCTURED AI TOOLS
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
  PostgreSQL DB     RAG Knowledge    Deterministic
   (Neon DB)        (Embeddings)     Calculations
       │                │                │
       └────────────────┼────────────────┘
                        ▼
                 AI REASONING CORE
             (Gemini Foundation Model)
                        │
                        ▼
               SAFETY & VALIDATION
            (Zero Arithmetic Hallucination)
                        │
                        ▼
             STRUCTURED RESPONSE / PROPOSAL
                        │
                        ▼
             ADMIN APPROVAL GATEWAY
                        │
                        ▼
           VERSIONED DATABASE UPDATE (Audit Log)
```

---

## 16. Recommended Implementation Order

1. **Phase 0 (Current)**: Read-Only Complete System Audit & Documentation.
2. **Phase 1**: Python AI Backend Foundation & Configuration Management.
3. **Phase 2**: Authentication Verification & Single-Admin Authorization Enforcement.
4. **Phase 3**: PostgreSQL Direct Pooling & Zero-Duplication Schema Integration.
5. **Phase 4**: Structured Parameterized AI Tools Implementation.
6. **Phase 5**: Deterministic Calculation Engine (Macros, Volume, 1RM, Progressive Overload).
7. **Phase 6**: RAG Fitness Knowledge Ingestion & Indexing.
8. **Phase 7**: AI Controller Intent Routing & Ambiguity Clarification.
9. **Phase 8**: Workout Intelligence & Progressive Overload Engine.
10. **Phase 9**: Nutrition Intelligence & Food Library Meal Synthesis.
11. **Phase 10**: Client Progress Timeline & Attention Engine.
12. **Phase 11**: Automated Operational Reporting (Daily & Weekly).
13. **Phase 12**: Proposal Approval State Machine & Audit Versioning.
14. **Phase 13**: End-to-End Flutter Admin Integration & Fallback Verification.
15. **Phase 14**: Automated Evaluation Benchmark & Multi-Athlete Testing.

---

## 17. Files That Would Need Modification in Future Phases

* `backend/.env` — Environment configuration for AI service port and Gemini credentials.
* `backend/src/config/environment.ts` — Addition of `PYTHON_AI_URL` and AI flags.
* `backend/src/modules/ai_coach/ai_coach.routes.ts` — Forwarding proxy routing to Python AI backend with fallback.
* `package.json` — Root orchestration scripts (`ai:dev`, `ai:start`, `ai:test`).

*Note: Zero Flutter UI code or client-facing database tables need to be deleted or destructively modified.*

---

## 18. Potential Technical Risks

1. **Remote Cloud DB Latency**:
   * Neon DB hosted on AWS us-east-2 can incur 50–150ms round-trip latency per query over WAN.
   * *Mitigation:* Connection pooling (`psycopg_pool`), batch queries, and localized calculation engines.
2. **Third-Party LLM Rate Limits**:
   * Public cloud LLM APIs can encounter rate limits or transient network timeouts.
   * *Mitigation:* Deterministic fallback engine guarantees instant operational reporting even if cloud LLM endpoints fail.
3. **Arithmetic Drift**:
   * LLMs cannot be trusted to perform exact macronutrient summing or 1RM load calculations.
   * *Mitigation:* All mathematical operations are performed by pure deterministic Python code; the LLM handles only natural language synthesis.

---

## 19. Dependencies Required Later

### Python AI Backend
* `fastapi` & `uvicorn` — High-performance async REST framework.
* `psycopg` & `psycopg_pool` — PostgreSQL binary driver with connection pooling.
* `pydantic` v2 — Strict schema validation matching Flutter DTOs.
* `pyjwt` — JWT token decoding and signature verification.
* `google-genai` / `google-generativeai` — Gemini Foundation model SDK.
* `pytest` — Automated test harness.

---

## 20. Phase 1 Prerequisites Checklist

- [x] Complete project source code audit conducted and documented.
- [x] All 24 PostgreSQL database tables and relationships identified.
- [x] Single-admin authorization mechanism (`fitsundar6@gmail.com`) mapped.
- [x] Existing Exercise (268 items) and Food (156 items) libraries cataloged.
- [x] Hardcoded mock data identified and separated from real database records.
- [x] Safety boundaries established (No direct AI SQL access; all plan writes require Admin approval).
- [x] Ready to proceed to **Phase 1** upon user confirmation.
