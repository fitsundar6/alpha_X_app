# Alpha X Gym — Complete Security, Bug & Issue Audit Report

**Primary Reference Document:** "Alpha X App – Phased Security Assessment" (Prepared by Manus AI, 2026-11-02, Revision `3e542ee`)  
**Assessment Target:** Source Code Repository (`fitsundar6/alpha_X_app`), Local Workspace (`alpha_x_gym`), and Production Deployment (`https://alpha-x-app.vercel.app/`)  
**Current HEAD Commit:** `fe43df3`  
**Audit Date:** 2026-11-04  
**Audit Mode:** Strict READ-ONLY Architecture, Source Code, and Safe Runtime Verification  

---

## 1. Executive Summary

### Overall Security Status: **ELEVATED RISK (SUBSTANTIALLY IMPROVED SINCE `3e542ee`, BUT NOT FULLY SECURED)**
Since the initial assessment at commit `3e542ee`, five dedicated security fix commits (`23b8a96`, `e12385f`, `3e1974c`, `a8f4471`, `fe43df3`) have addressed several major architectural vulnerabilities. Specifically:
- Food mutation routes now enforce authentication and admin checks.
- Media routes enforce object-level ownership checks.
- Expired access tokens are strictly rejected by `requireAuth`.
- CORS wildcard reflection has been replaced with an explicit domain whitelist (verified at runtime).
- Public health endpoint information disclosure has been minimized (verified at runtime).
- Request body limits have been constrained to 1MB globally.

However, **critical residual risks remain**:
1. **Exposed Database Backup in Git History:** The 4.5 MB database backup was deleted from the working tree in `23b8a96`, but it **remains permanently accessible in Git commit `6ec03658`**. Anyone with read access to the GitHub repository can extract client emails, personal profiles, and bcrypt password hashes.
2. **Credential Rotation Incomplete:** Client passwords and JWT signing secrets that were active when the backup was committed have not yet been rotated.
3. **New Security Findings:** This audit uncovered several new vulnerabilities not mentioned in the original report, including an admin login rate limit bypass in `admin.routes.ts`, potential Gemini API key leakage in the Flutter mobile binary, fully disabled Apple Transport Security (`NSAllowsArbitraryLoads: true`) on iOS, and 11 vulnerable NPM packages (5 High).

### Overall Application Health: **MODERATE TO HEALTHY (CORE FUNCTIONALITY INTACT)**
- The core API server on Vercel is operational (HTTP 200 health check, 904ms latency).
- Database connectivity to Neon PostgreSQL is healthy (194 active food catalog items queryable).
- Flutter mobile architecture features hardware-backed token storage (Keychain/KeyStore), automatic 401 session purge, and robust onboarding persistence.

### Total Issues Identified
- **Previous PDF Findings (F-01 to F-09):** 9 findings total.
  - **5 FIXED** (F-02, F-04 [access tokens], F-07, F-08, F-09)
  - **4 PARTIALLY FIXED / OPEN RESIDUAL RISK** (F-01, F-03, F-05, F-06)
- **Newly Discovered Issues (NEW-01 to NEW-10):** 10 new issues identified.
  - **2 HIGH Severity** (Admin login rate limit bypass, Gemini client-side key risk)
  - **4 MEDIUM Severity** (iOS ATS disabled, Android release APK unminified, 11 vulnerable NPM dependencies, incomplete CI test coverage)
  - **4 LOW / MEDIUM Severity** (No backend CI pipeline, test files deployed to production bundle, 6-char minimum password policy, hardcoded Firebase build config)
- **Grand Total Issues in Register:** **19 issues**.

---

## 2. Previous PDF Findings — Current Status

### Finding F-01 — Publicly Tracked Database Backup
* **Original Severity:** Critical
* **Current Status:** **PARTIALLY FIXED (CRITICAL RESIDUAL RISK IN GIT HISTORY)**
* **Evidence:**
  - Working Tree: The file `backend/backups/db_backup_2026-10-10T13-01-42-639Z.json` was deleted in commit `23b8a96e`.
  - Git Ignore: `.gitignore` and `backend/.gitignore` were updated to ignore `backups/`, `*.dump`, and `db_backup_*.json`.
  - Git History: Running `git log --all --full-history -- "backend/backups/db_backup_2026-10-10T13-01-42-639Z.json"` confirms the file remains completely intact and recoverable in commit `6ec036580f8e1435d0b0d19541a69f4ef486bacc`.
  - Credential Rotation: Client passwords, JWT secrets, and personal user data contained within that snapshot have not yet been rotated.
* **Remaining Risk:** Anyone who forks or clones the repository can extract 36 user records, emails, client profiles, and password hashes.

---

### Finding F-02 — Unauthenticated Food Mutation Routes
* **Original Severity:** High
* **Current Status:** **FIXED**
* **Evidence:**
  - `backend/src/modules/food/food.routes.ts`:
    - Line 43: `router.post('/seed', requireAuth, requireAdmin, ...)` — admin only.
    - Line 50: `router.post('/ai-scan', requireAuth, ...)` — authenticated only.
    - Line 53: `router.post('/', requireAuth, ...)` — authenticated only.
    - Line 56: `router.delete('/:id', requireAuth, ...)` — authenticated only.
  - `backend/src/modules/food/food.controller.ts`:
    - Removed caller-controlled identity headers (`x-client-id`, `x-user-id`, and `req.body.createdBy`). User identity is derived strictly from `(req as any).user` populated by verified JWT.
  - `backend/src/modules/food/food.service.ts`:
    - Line 240+: `const isAdmin = user.role === 'ADMIN'; const isPublic = isAdmin ? (input.isPublic !== false) : false; const status = isAdmin ? 'APPROVED' : 'PENDING';`
    - Non-admin custom foods are strictly marked private (`isPublic: false`) and pending (`status: 'PENDING'`).
* **Remaining Risk:** None. The trust boundary is fully enforced at the route and service layers.

---

### Finding F-03 — Media Routes Bypass Centralized Middleware
* **Original Severity:** High
* **Current Status:** **PARTIALLY FIXED**
* **Evidence:**
  - `backend/src/modules/food/food.photo.routes.ts`:
    - All state-changing routes (`POST /live`, `POST /`, `POST /cleanup`, `DELETE /:id`, `PATCH /:id/verify`, `GET /admin/monitoring`) now mount `requireAuth` or `requireAuth, requireAdmin`.
  - `backend/src/modules/food/food.photo.controller.ts`:
    - Object-level ownership check added in `streamMealPhotoImage` (lines 337-345): users cannot view other clients' meal photos unless they possess the `ADMIN` role.
    - Token verification in `resolveUserFromRequest` uses strict `jwt.verify(token, env.JWT_ACCESS_SECRET)` without `ignoreExpiration`.
  - **Residual Gap:** Binary streaming endpoints (`GET /:id/image` and `GET /:milestoneId/:angle`) do not use `requireAuth` on the router; they still use the controller helper `resolveUserFromRequest` which accepts `?token=` query parameters to accommodate Flutter's `Image.network`.
* **Remaining Risk:** Low/Medium. Tokens passed in query parameters can be logged by web proxies, CDNs, or server access logs.

---

### Finding F-04 — Expired Access Tokens Accepted for Up to 30 Days
* **Original Severity:** High
* **Current Status:** **FIXED FOR ACCESS TOKENS / ARCHITECTURAL LIMITATION FOR REFRESH**
* **Evidence:**
  - `backend/src/middlewares/auth.ts`:
    - Lines 71-125: `requireAuth` executes `jwt.verify(token, env.JWT_ACCESS_SECRET)` with NO `ignoreExpiration: true`. If the token is expired, it catches `TokenExpiredError` and returns HTTP 401 `INVALID_TOKEN`.
    - The 30-day grace period was completely purged from `requireAuth`, `optionalAuth`, and media controllers.
  - `backend/src/modules/auth/auth.routes.ts`:
    - Line 184: `POST /api/v1/auth/refresh` still uses `jwt.verify(token, env.JWT_ACCESS_SECRET, { ignoreExpiration: true })` with a 30-day grace period.
    - The backend does not maintain a server-side revocable refresh token table; the access token itself acts as the refresh credential.
* **Remaining Risk:** Medium. If an access token is compromised, an attacker can refresh it within the 30-day grace window unless `JWT_ACCESS_SECRET` is rotated or the user is deactivated.

---

### Finding F-05 — Known Admin Password Defaults in Mobile Code
* **Original Severity:** High
* **Current Status:** **PARTIALLY FIXED**
* **Evidence:**
  - `apps/mobile/lib/config/admin_config.dart`:
    - Lines 19-22: `adminPassword` changed to `defaultValue: ''` (literal password removed from release configuration).
  - `apps/mobile/lib/core/auth/auth_service.dart`:
    - Release path no longer performs offline password string comparisons.
  - **Residual Gap:**
    - Line 1124 in `auth_service.dart` STILL contains the literal strings `'AlphaXAdmin2026'` and `'AlphaXAdmin2026!'` inside an `if (_isTestEnvironment)` block.
    - Line 13 in `admin_config.dart` and line 1121 in `auth_service.dart` still hardcode the administrator email `'fitsundar6@gmail.com'`.
* **Remaining Risk:** Medium. String extraction tools on the mobile binary can recover the known password string if dead-code elimination does not prune the test helper block.

---

### Finding F-06 — Predictable Security Defaults
* **Original Severity:** High/Medium
* **Current Status:** **PARTIALLY FIXED**
* **Evidence:**
  - `backend/src/config/environment.ts`:
    - `CORS_ORIGIN`: Changed from `*` to default `'https://alpha-x-app.vercel.app,https://alphaxgym.com'`.
    - `QR_SECRET_KEY`: Uses `crypto.randomBytes(32).toString('hex')` dynamic fallback in production to eliminate static key guessing.
    - `CRON_SECRET`: `verifyCronSecret` in `cron.routes.ts:100` strictly fails closed if `CRON_SECRET` is not set on the server.
  - **Residual Gap:**
    - The ephemeral QR secret generated on cold-starts means QR codes created by one serverless container will fail validation if verified by another container instance. A persistent `QR_SECRET_KEY` must be configured in Vercel.
    - `ADMIN_EMAIL` still defaults to `'admin@alphaxgym.com'`.
* **Remaining Risk:** Low/Medium. Functional check-in instability until a static persistent `QR_SECRET_KEY` is added to Vercel environment variables.

---

### Finding F-07 — CORS Reflects Arbitrary Origins with Credentials Enabled
* **Original Severity:** High/Medium
* **Current Status:** **FIXED (CONFIRMED IN CODE & RUNTIME)**
* **Evidence:**
  - `backend/src/server.ts:81-125`: Removed wildcard matching and `.vercel.app` regex reflection. Implemented strict whitelist check against `allowedOrigins`.
  - **Live Runtime Test on Production (`https://alpha-x-app.vercel.app`):**
    - Request from `Origin: https://example.invalid` $\rightarrow$ Rejected (HTTP 500, `allowOrigin: null`, `allowCredentials: null`).
    - Request from `Origin: https://malicious.vercel.app` $\rightarrow$ Rejected (HTTP 500, `allowOrigin: null`, `allowCredentials: null`).
    - Request from `Origin: https://alpha-x-app.vercel.app` $\rightarrow$ Accepted (HTTP 204, `Access-Control-Allow-Origin: https://alpha-x-app.vercel.app`, `Access-Control-Allow-Credentials: true`).
    - Request from `Origin: https://alphaxgym.com` $\rightarrow$ Accepted (HTTP 204, `Access-Control-Allow-Origin: https://alphaxgym.com`, `Access-Control-Allow-Credentials: true`).
* **Remaining Risk:** None. Verified against live production server.

---

### Finding F-08 — Health Endpoint Discloses Deployment Details
* **Original Severity:** Low/Medium
* **Current Status:** **FIXED (CONFIRMED IN CODE & RUNTIME)**
* **Evidence:**
  - `backend/src/server.ts:176-181`: Public health handler was completely rewritten to return only:
    ```json
    { "status": "healthy", "timestamp": "..." }
    ```
  - **Live Runtime Test:** `GET https://alpha-x-app.vercel.app/api/v1/health` returned:
    ```json
    { "status": "healthy", "timestamp": "2026-11-04T00:54:42.117Z" }
    ```
    Zero infrastructure disclosure (no host, port, process uptime, environment, or AI status).
* **Remaining Risk:** None. Verified against live production server.

---

### Finding F-09 — Large Request Bodies and Expensive Public AI Surface
* **Original Severity:** Medium
* **Current Status:** **FIXED**
* **Evidence:**
  - `backend/src/server.ts:164-165`: Global request body limit lowered from 10MB to **1MB** (`express.json({ limit: '1mb' })`).
  - `backend/src/modules/food/food.routes.ts:50`: `POST /ai-scan` now mounts `requireAuth`. Unauthenticated callers cannot trigger AI scans.
  - `backend/src/modules/food/food.ai.service.ts`: Enforces strict per-user quotas (5 scans per minute, 30 scans per day).
* **Remaining Risk:** None. Unauthenticated compute exhaustion vector is closed.

---

## 3. Newly Discovered Issues (Not in PDF)

### **NEW-01: Admin Login Endpoint Rate Limit Bypass in `admin.routes.ts`**
* **Category:** Security / Abuse Protection
* **Severity:** **HIGH**
* **Location:** `backend/src/modules/admin/admin.routes.ts:25-41`
* **Finding:** While `auth.routes.ts` applies `loginRateLimiter` (`max: 10` per 15 min) to `/api/v1/auth/login` and `/api/v1/auth/admin/login`, the parallel admin router `admin.routes.ts` mounts `router.post('/login')` with **no route-specific rate limiter**. An attacker targeting `/api/admin/login` or `/api/v1/admin/login` directly can perform up to 300 attempts per 15-minute window under the general limiter.
* **Recommended Fix:** Attach `loginRateLimiter` to `router.post('/login')` in `admin.routes.ts`.

---

### **NEW-02: Client-Side Gemini API Key Exposure Risk in Flutter Repository**
* **Category:** Mobile Security / Credential Exposure
* **Severity:** **HIGH**
* **Location:** `apps/mobile/lib/features/ai_coach/data/repositories/ai_coach_repository.dart:28-29, 1072-1144`
* **Finding:** `ai_coach_repository.dart` contains code for calling Google Gemini directly from the Flutter client via `google_generative_ai` and `String.fromEnvironment('GEMINI_API_KEY')`. If compiled with `--dart-define=GEMINI_API_KEY=...` during build, the private Gemini API key will be baked into the compiled client binary.
* **Recommended Fix:** Remove direct client-to-Gemini SDK calls from the mobile application entirely. All AI Coach requests must proxy through the backend (`/api/v1/admin/ai-coach/chat`).

---

### **NEW-03: Apple Transport Security (ATS) Disabled on iOS (`NSAllowsArbitraryLoads: true`)**
* **Category:** Mobile Security / App Store Compliance
* **Severity:** **MEDIUM**
* **Location:** `apps/mobile/ios/Runner/Info.plist:44-50`
* **Finding:** `NSAllowsArbitraryLoads` is explicitly set to `<true/>`, disabling iOS system-level HTTPS enforcement. This allows cleartext HTTP communication to any external domain and risks rejection during Apple App Store review.
* **Recommended Fix:** Set `NSAllowsArbitraryLoads` to `false` (or remove the key). Retain `NSAllowsLocalNetworking: true` for local development.

---

### **NEW-04: Android Release Build Code Obfuscation and Shrinking Disabled**
* **Category:** Mobile Security / Reverse Engineering
* **Severity:** **MEDIUM**
* **Location:** `apps/mobile/android/app/build.gradle.kts:117-118`
* **Finding:** In `buildTypes.release`, `isMinifyEnabled = false` and `isShrinkResources = false`. The compiled Android APK does not have R8/ProGuard obfuscation enabled, allowing full decompilation with intact symbol names.
* **Recommended Fix:** Enable R8 minification and resource shrinking for release builds with standard Flutter ProGuard rules.

---

### **NEW-05: 11 Vulnerable NPM Dependencies in Backend (5 High Severity)**
* **Category:** Supply Chain Security
* **Severity:** **HIGH**
* **Location:** `backend/package.json`
* **Finding:** `npm audit` identifies 11 vulnerabilities (5 High, 6 Moderate):
  - `body-parser < 1.20.9` (High - DoS via trailing bytes after compressed body, GHSA-27r3-jxmh-p828)
  - `deepmerge-ts < 8.0.0` (High - Stack exhaustion on recursive graphs, GHSA-ggr8-5vv4-36mx)
  - `zod < 4.6.6` (High - Memory exhaustion on oversized collections, GHSA-mrhx-c7xc-m3w5)
  - `nodemailer 3.0.0 - 10.1.3` (Moderate - Parser injection, GHSA-8c8m-p3m8-cjg8)
  - `qs 6.7.0 - 6.16.0` (Moderate - Uncaught TypeError DoS, GHSA-6pq8-jhm2-2vcw)
* **Recommended Fix:** Run `npm update` and upgrade vulnerable direct dependencies (`body-parser`, `zod`, `nodemailer`).

---

### **NEW-06: 55 Test Files Located in `backend/src/` Deployed to Production Bundle**
* **Category:** Architecture / Deployment Hygiene
* **Severity:** **LOW / MEDIUM**
* **Location:** `backend/src/test_*.ts`, `backend/tsconfig.json:14`
* **Finding:** 55 test scripts are located directly inside `backend/src/`. Because `tsconfig.json` compiles `"src/**/*"`, all test files, test tokens, and mock credentials are compiled into `dist/` and included in the Vercel production serverless bundle.
* **Recommended Fix:** Relocate `backend/src/test_*.ts` into a root `backend/test/` directory and configure `tsconfig.json` to only compile production application code.

---

### **NEW-07: Incomplete CI Mobile Test Coverage (Only 2 of 81 Test Files Run)**
* **Category:** DevOps / Quality Assurance
* **Severity:** **MEDIUM**
* **Location:** `.github/workflows/build-mobile.yml:48`
* **Finding:** The GitHub Actions workflow executes only `test/api_config_test.dart` and `test/workout_proposal_generation_regression_test.dart`. 79 other test suites in `apps/mobile/test` are omitted, allowing client regressions to bypass CI.
* **Recommended Fix:** Expand the CI quality gate to run all stable unit and regression tests.

---

### **NEW-08: Complete Absence of Backend CI Pipeline**
* **Category:** DevOps / Quality Assurance
* **Severity:** **MEDIUM**
* **Location:** `.github/workflows/`
* **Finding:** There is no GitHub Actions workflow for backend linting, type-checking, or testing. Backend errors are only discovered after Vercel attempts deployment.
* **Recommended Fix:** Create `.github/workflows/backend-ci.yml` running `npm ci`, `prisma generate`, `tsc --noEmit`, and regression tests.

---

### **NEW-09: Weak Client Password Policy (6 Characters Minimum, No Complexity)**
* **Category:** Authentication Security
* **Severity:** **LOW / MEDIUM**
* **Location:** `backend/src/modules/auth/auth.routes.ts:327, 1251`
* **Finding:** Account registration and password change routes only validate `password.length >= 6`. There is no character complexity requirement (digits, symbols, or uppercase).
* **Recommended Fix:** Increase minimum password length to at least 8 characters and enforce basic character diversity.

---

### **NEW-10: Hardcoded Firebase Configuration in Android Build Script**
* **Category:** Configuration Hygiene
* **Severity:** **LOW**
* **Location:** `apps/mobile/android/app/build.gradle.kts:16-47`
* **Finding:** `build.gradle.kts` dynamically writes a fallback `google-services.json` containing an embedded Google API key string (`AIzaSyC0er...`). While Firebase client keys are public, committing them into Gradle build scripts causes automated secret scanners to flag the repository.
* **Recommended Fix:** Provide `google-services.json` through repository secrets or an external configuration step.

---

## 4. Complete Issue Register

| ID | Issue Description | Category | Severity | Affected File/Component | Current Status | Recommended Fix |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **F-01** | Publicly tracked database backup in Git history | Data Exposure | **CRITICAL** | Git Commit `6ec03658` | **PARTIALLY FIXED** | Rewrite history with `git-filter-repo` or BFG; rotate all client passwords and JWT secrets. |
| **F-02** | Unauthenticated food mutation routes | Auth & Access | **HIGH** | `food.routes.ts`, `food.controller.ts` | **FIXED** | Verified fixed; maintain existing `requireAuth` guards. |
| **F-03** | Media routes bypass centralized middleware (`?token=`) | Authorization | **HIGH** | `food.photo.routes.ts`, `transformation_photo.routes.ts` | **PARTIALLY FIXED** | Transition mobile `Image.network` to short-lived signed URLs or auth headers. |
| **F-04** | Expired access tokens accepted for 30 days | Token Security | **HIGH** | `middlewares/auth.ts`, `auth.routes.ts` | **FIXED** (Access) | Implement revocable refresh token table in database. |
| **F-05** | Known admin password defaults in mobile code | Credential Exposure | **HIGH** | `admin_config.dart`, `auth_service.dart` | **PARTIALLY FIXED** | Purge `'AlphaXAdmin2026'` literals from test block in `auth_service.dart`. |
| **F-06** | Predictable security defaults (QR secret, CORS) | Configuration | **HIGH/MED** | `environment.ts` | **PARTIALLY FIXED** | Add persistent `QR_SECRET_KEY` in Vercel to prevent cold-start invalidation. |
| **F-07** | CORS reflects arbitrary origins with credentials | Web Security | **HIGH/MED** | `server.ts:81-135` | **FIXED** | Verified fixed at runtime; maintain whitelist. |
| **F-08** | Health endpoint discloses deployment details | Info Disclosure | **LOW/MED** | `server.ts:176-181` | **FIXED** | Verified fixed at runtime; minimal status payload preserved. |
| **F-09** | Large request bodies and expensive public AI surface | DoS / Resource Abuse | **MEDIUM** | `server.ts`, `food.routes.ts` | **FIXED** | Verified fixed; 1MB global body limit and auth enforced on AI scan. |
| **NEW-01** | Admin login rate limit bypass in `admin.routes.ts` | Brute Force Protection | **HIGH** | `backend/src/modules/admin/admin.routes.ts:25` | **OPEN** | Apply `loginRateLimiter` middleware to `router.post('/login')` in `admin.routes.ts`. |
| **NEW-02** | Client-side Gemini API key exposure risk | Mobile Security | **HIGH** | `ai_coach_repository.dart:28, 1072` | **OPEN** | Remove client-side Gemini fallback; route all LLM requests through backend. |
| **NEW-03** | iOS ATS disabled (`NSAllowsArbitraryLoads: true`) | Mobile Compliance | **MEDIUM** | `apps/mobile/ios/Runner/Info.plist:46` | **OPEN** | Remove `NSAllowsArbitraryLoads: true` from `Info.plist`. |
| **NEW-04** | Android release APK obfuscation & shrinking disabled | Mobile Security | **MEDIUM** | `build.gradle.kts:117-118` | **OPEN** | Enable `isMinifyEnabled = true` and `isShrinkResources = true` in release build type. |
| **NEW-05** | 11 vulnerable NPM dependencies (5 High) | Supply Chain | **HIGH** | `backend/package.json` | **OPEN** | Update `body-parser`, `zod`, `nodemailer`, `prisma` via `npm update`. |
| **NEW-06** | 55 test files compiled into production bundle | Deployment Hygiene | **LOW/MED** | `backend/src/test_*.ts`, `tsconfig.json` | **OPEN** | Move test files to `backend/test/` and exclude from production compilation. |
| **NEW-07** | Incomplete CI mobile test coverage (2 of 81 run) | QA / DevOps | **MEDIUM** | `.github/workflows/build-mobile.yml:48` | **OPEN** | Expand CI test command to run all stable test suites. |
| **NEW-08** | Absence of backend CI pipeline | QA / DevOps | **MEDIUM** | `.github/workflows/` | **OPEN** | Add GitHub Actions workflow for backend build, typecheck, and test. |
| **NEW-09** | Weak client password policy (6 characters min) | Authentication | **LOW/MED** | `backend/src/modules/auth/auth.routes.ts:327` | **OPEN** | Enforce minimum 8 characters and basic complexity on registration/reset. |
| **NEW-10** | Hardcoded Firebase configuration in Gradle script | Secret Hygiene | **LOW** | `apps/mobile/android/app/build.gradle.kts:16` | **OPEN** | Inject `google-services.json` via CI secrets or pre-build step. |

---

## 5. Production Readiness Evaluation

**Current Status:** **NOT READY FOR PRODUCTION DEPLOYMENT / DISTRIBUTION**

### Readiness Criteria Breakdown:
1. **Data Protection & Privacy (FAIL):** Git history still contains the unpurged database backup (`6ec03658`). Until the repository history is scrubbed and client passwords/secrets are rotated, deploying to real gym members carries severe incident and regulatory liability.
2. **API & Infrastructure Security (PASS WITH CONDITIONS):** Vercel backend routing, CORS whitelisting, minimal health disclosure, and database query functionality are verified healthy. However, the admin login rate limit bypass (NEW-01) must be patched.
3. **Mobile Client Security (FAIL):** The mobile application has ATS disabled on iOS (NEW-03), R8 obfuscation disabled on Android (NEW-04), and contains dormant client-side Gemini fallback logic that could leak API keys if configured via compile flags (NEW-02).

---

## 6. Testing Results

### Summary of Executed Tests:
* **Runtime Verification:**
  - Production Health Check (`GET /api/v1/health`): **PASS** (HTTP 200, 904ms, minimal disclosure confirmed).
  - Production Neon Database Query (`GET /api/v1/foods?limit=1`): **PASS** (HTTP 200, 1033ms, 194 records accessible).
  - CORS Whitelist Validation on Production (`OPTIONS` from 4 origins): **PASS** (rejected `example.invalid` and `malicious.vercel.app`; accepted `alpha-x-app.vercel.app` and `alphaxgym.com`).
  - Neon PostgreSQL Port 5432 Connectivity: **PASS** (TCP handshake succeeded to `3.143.47.40:5432`).
* **Static Source & Configuration Audits:**
  - Git History Scan for Backup Artifact: **CONFIRMED EXPOSED** in commit `6ec03658`.
  - Food Route Authentication Audit: **CONFIRMED FIXED** (`requireAuth`, `requireAdmin`).
  - Media Route Authorization Audit: **CONFIRMED PARTIALLY FIXED** (ownership checks added, query token streaming remains).
  - JWT Expiration Logic Audit: **CONFIRMED FIXED FOR ACCESS TOKENS** (no `ignoreExpiration` in `requireAuth`).
  - Backend Dependency Security Audit: **11 VULNERABILITIES IDENTIFIED** (5 High).
  - Mobile Manifest & Info.plist Audit: **IDENTIFIED ATS DISABLED & R8 DISABLED**.
* **Skipped / Not Possible Tests:**
  - Authenticated end-to-end data mutation flows (skipped to preserve strict read-only audit rules).
  - Dockerized Shannon automated penetration testing (Docker unavailable in environment).

---

## 7. Prioritized Action Plan

### **P0 — Critical Immediate Action (Blockers for Production Launch)**
1. **Purge Git History:** Rewrite repository history using `git-filter-repo` or BFG to permanently eradicate `backend/backups/db_backup_2026-10-10T13-01-42-639Z.json` from commit `6ec03658`. Force push to GitHub and instruct all contributors to clone fresh copies.
2. **Execute Credential Rotation:**
   - Rotate `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` in Vercel.
   - Force password resets for all 36 client accounts exposed in the historical backup.
   - Rotate the master administrator password in Vercel and remove any traces of `'AlphaXAdmin2026'`.
3. **Configure Persistent `QR_SECRET_KEY` in Vercel:** Set a persistent 64-character secret in Vercel to prevent check-in failures across container cold-starts.

### **P1 — High Priority (Pre-Release Security Fixes)**
4. **Fix Admin Login Rate Limiting (NEW-01):** Add `loginRateLimiter` to `router.post('/login')` in `backend/src/modules/admin/admin.routes.ts`.
5. **Remove Direct Client-Side Gemini SDK Calls (NEW-02):** Remove `google_generative_ai` dependency from mobile `pubspec.yaml` and eliminate `_callGeminiDirectly` from `ai_coach_repository.dart`.
6. **Update Vulnerable Backend Dependencies (NEW-05):** Update `body-parser`, `zod`, and `nodemailer` to secure versions.
7. **Purge Test Admin Passwords from Mobile Source (F-05):** Remove `'AlphaXAdmin2026'` literals from `apps/mobile/lib/core/auth/auth_service.dart`.

### **P2 — Medium Priority (Platform Hardening & Quality Gate)**
8. **Re-enable iOS ATS (NEW-03):** Remove `NSAllowsArbitraryLoads: true` from `apps/mobile/ios/Runner/Info.plist`.
9. **Enable Android Release Obfuscation (NEW-04):** Set `isMinifyEnabled = true` and `isShrinkResources = true` in `build.gradle.kts`.
10. **Establish Backend CI Workflow (NEW-08):** Add `.github/workflows/backend-ci.yml` to run automated builds, lints, and tests.
11. **Expand Mobile CI Test Suite (NEW-07):** Update `build-mobile.yml` to run the full regression test suite.
12. **Relocate Backend Tests (NEW-06):** Move 55 `test_*.ts` files from `backend/src/` to `backend/test/`.

### **P3 — Low Priority (Hygiene & Polish)**
13. **Strengthen Password Validation (NEW-09):** Update registration/reset schemas to require $\ge 8$ characters and character diversity.
14. **Clean Firebase Build Script (NEW-10):** Remove hardcoded fallback template from `build.gradle.kts`.
15. **Migrate Media Streaming to Signed URLs (F-03):** Replace `?token=` image streaming with short-lived pre-signed download URLs.

---

## 8. Final Recommendation

### **Verdict: NOT READY FOR PRODUCTION**

### Justification:
While the development team has made commendable progress resolving 5 of the 9 original security findings (notably securing food routes, CORS whitelisting, request body limits, and token expiration checks), **the repository remains in an active credential exposure state** due to the database backup retained in Git history. 

Releasing the mobile application or promoting the current environment to live gym athletes without scrubbing Git history, rotating compromised credentials, and patching the newly identified admin login rate limit bypass poses immediate privacy, security, and reputational risks.

Once the **P0** and **P1** items are executed, the system will achieve **SAFE TO CONTINUE** status for staging verification and subsequent production deployment.

