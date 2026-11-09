# Alpha X Gym – Critical Production Client List Investigation Report

**Date:** 2026-11-04  
**Workspace:** `C:\Users\johng\.gemini\antigravity-ide\scratch\alpha_x_gym`  
**Target Environment:** Vercel Production (`https://alpha-x-app.vercel.app`)  
**Production Commit:** `bcb130e2b6bad2b5878143a7e367df4218448b6a`  
**Investigation Policy:** Strict READ-ONLY Forensic Inspection (zero database modifications, zero secret exposures, zero personal client PII disclosure)  
**File Output:** `CLIENT_LIST_MISSING_ROOT_CAUSE_REPORT.md`

---

## 1. Executive Summary & Exact Root Cause

### 1.1 The Exact Root Cause
The empty client list in the live production app is caused by a **Database Connection Authentication Failure on Neon PostgreSQL combined with a Silent Error Mask in the Backend Code**:

1. **Database Authentication Failure (`ERROR: password authentication failed for user 'neondb_owner'`)**:
   - The production backend hosted on Vercel is configured with a `DATABASE_URL` pointing to Neon PostgreSQL (`ep-wispy-scene-a5yzabm1-pooler.us-east-2.aws.neon.tech:5432/alpha-x-mobile-db`).
   - TCP network connectivity to the database host on port 5432 is 100% healthy (`TcpTestSucceeded: True`).
   - However, PostgreSQL authentication fails with:
     ```text
     connection failed: ERROR: password authentication failed for user 'neondb_owner'
     ```
   - This occurs because the database password in the Neon console was rotated, reset, or misconfigured relative to the environment secrets.

2. **The Silent Error Mask in `workout.service.ts`**:
   - In `backend/src/modules/workout/workout.service.ts` (lines 214–217), the function `getClientsList()` wraps the database query in a `try / catch` block:
     ```typescript
     async getClientsList() {
       try {
         const dbUsers = await prisma.user.findMany({
           where: { role: 'CLIENT' },
           ...
         });
         return dbUsers.map(...);
       } catch (err) {
         console.error('[DATABASE GET CLIENTS ERROR]', err);
         return []; // <-- SILENTLY RETURNS EMPTY ARRAY
       }
     }
     ```
   - When the database query fails due to authentication, `getClientsList()` catches the error, logs it to serverless output, and silently returns an empty array `[]`.
   - `workoutController.getClientsList()` receives `[]` and responds to the mobile app with **HTTP 200 OK** and payload:
     ```json
     {
       "success": true,
       "data": [],
       "error": null,
       "meta": { "count": 0 }
     }
     ```

3. **Why the Flutter App Displays an Empty List**:
   - In `apps/mobile/lib/features/workout/data/repositories/workout_repository.dart` (lines 323–327):
     ```dart
     if (response.statusCode == 200) {
       final decoded = jsonDecode(response.body);
       final List<dynamic> clientList = decoded['data'] ?? [];
       _clients.clear();
       ...
     ```
   - Because the backend returns HTTP 200 OK instead of an error (HTTP 500), the Flutter app believes the request succeeded and that the gym legitimately has zero registered clients. It clears `_clients` and renders the empty list view.

4. **Why Admin Login Worked While Client List Was Empty**:
   - Admin authentication in `backend/src/modules/auth/admin_auth.service.ts` is evaluated **100% in-memory** against environment variables (`ADMIN_EMAIL` and `ADMIN_PASSWORD_HASH` / `ADMIN_PASSWORD`).
   - Admin login does not query PostgreSQL at all. Therefore, the admin can log in without issue, only to see zero clients once the dashboard tries to query the database.

5. **Why Earlier Audits Believed Database Connectivity Was Healthy**:
   - In previous audits, `GET /api/v1/foods` returned HTTP 200 with 194 food items.
   - Investigation of `backend/src/modules/food/food.service.ts` (lines 181–185) revealed that `FoodService` also has an in-memory fallback catalog (`INITIAL_FOOD_CATALOG`) containing exactly 194 items. When the database query fails, it silently returns the memory catalog. Thus, `GET /foods` succeeded even though the database was completely unreachable.

6. **Impact of Recent Git Cleanup**:
   - The recent Git history synchronization **did NOT cause this issue**.
   - Git commits `fe43df3` (previous production) and `bcb130e` (current production) have bit-for-bit identical backend source code, Prisma schema, and `vercel.json`. The cleanup only purged the leaked Android keystore binary and scrubbed historical commits.

---

## 2. Production Deployment Status (Vercel)

| Parameter | Value / Finding |
| :--- | :--- |
| **Production Domain** | `https://alpha-x-app.vercel.app` |
| **Vercel Project ID / Target** | `https://vercel.com/alpha-580b/alpha-x-app/Fdw4dCsP5fCyyscQpZyoHn5iaBcL` |
| **Active Deployment SHA** | `bcb130e2b6bad2b5878143a7e367df4218448b6a` |
| **Vercel Deployment State** | `success` (Deployment completed at `2026-11-04T03:37:13Z`) |
| **Health Check (`GET /api/v1/health`)** | **HTTP 200 OK** (`{"status":"healthy"}`) |
| **Node.js Serverless Container** | Online, serving traffic normally |

### Recent Vercel Deployment History (from GitHub Deployments API)
1. `2026-11-04T03:38:27Z`: Preview deployment of `29ab508` (`fix/gemini-reliability`)
2. `2026-11-04T03:37:13Z`: **Production deployment of `bcb130e` (`main`)** $\rightarrow$ **CURRENT LIVE**
3. `2026-11-04T03:36:13Z`: Preview deployment of `28005a5` (`fix/push-notification-production-readiness`)
4. `2026-11-03T13:22:04Z`: Production deployment of `fe43df3`
5. `2026-11-03T13:17:57Z`: Production deployment of `a8f4471`
6. `2026-10-29T07:54:29Z`: Production deployment of `3e542ee`

---

## 3. Production Backend API Verification

### 3.1 Client-List Endpoints
- **Primary Endpoint**: `GET /api/v1/admin/clients` (or `GET /api/admin/clients`)
  - **Controller**: `workoutController.getClientsList()` $\rightarrow$ `workoutService.getClientsList()`
  - **Auth**: Protected by `requireAuth` + `requireAdmin` (Admin JWT required)
  - **Query**: `prisma.user.findMany({ where: { role: 'CLIENT' } })`
- **Secondary Endpoint**: `GET /api/v1/admin/verification/users`
  - **Controller**: Direct in `admin.routes.ts:85`
  - **Auth**: Protected by `requireAuth` + `requireAdmin`
  - **Query**: `prisma.user.findMany({ where: { role: 'CLIENT' } })`

### 3.2 Live Probe Results on Production (`https://alpha-x-app.vercel.app`)

| Request | Route | Expected | Observed HTTP Response | Diagnosis |
| :--- | :--- | :---: | :---: | :--- |
| `GET /api/v1/health` | Public Health | 200 OK | **HTTP 200 OK** | Vercel container is online |
| `GET /api/v1/admin/clients` | Admin Clients (Unauth) | 401 | **HTTP 401 Unauthorized** | Auth middleware is active and enforcing tokens |
| `POST /api/v1/auth/login` | Client Login Probe | 401/404 | **HTTP 500 Internal Server Error** | Throws `INTERNAL_ERROR: Authentication failed` because `prisma.user.findFirst` fails |
| `GET /api/v1/foods` | Food Catalog | 200 OK | **HTTP 200 OK** (194 items) | Masked by in-memory fallback catalog |

---

## 4. Production Database Status & Client Data Verification

### 4.1 Connection Details
- **Host**: `ep-wispy-scene-a5yzabm1-pooler.us-east-2.aws.neon.tech` (AWS Ohio)
- **Database**: `alpha-x-mobile-db`
- **User**: `neondb_owner`
- **Port**: `5432`
- **SSL / TLS**: `sslmode=require`
- **TCP Reachability**: **PASS** (Handshake succeeded to `3.23.186.13:5432` and `3.131.64.200:5432`)
- **Authentication**: **FAIL** (`ERROR: password authentication failed for user 'neondb_owner'`)

### 4.2 Client Data Presence Check (Zero Personal PII)
Is client data lost? **NO.**
The database records exist in verified, uncorrupted local JSON backups created prior to the issue:

| Backup File | Date Created | Total Users | Client Count | Total Client Profiles | Complete Entities Preserved |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `backend/backups/db_backup_2026-10-27T06-57-13-236Z.json` | 2026-10-27 12:27 | **13** | **12** | **12** | Users, Profiles, Workouts, Diets, Food Logs, Macros, Progress, Activity, Check-ins, Photos |
| `backend/backups/db_backup_2026-10-19T03-15-35-535Z.json` | 2026-10-19 08:46 | **13** | **12** | **12** | Full database snapshot |
| `backend/backups/db_backup_2026-10-15T13-07-26-664Z.json` | 2026-10-15 18:38 | **13** | **12** | **12** | Full database snapshot |

All 12 client accounts and profiles are safely preserved on disk and ready for re-synchronization.

---

## 5. Old Live App Implementation & URL Verification

### 5.1 Base URL Resolution in Old Live App
In `apps/mobile/lib/core/config/api_config.dart` (lines 40–43 and 245–247):
```dart
static const String productionUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://alpha-x-app.vercel.app/api/v1',
);
```
- The old live app connects to: `https://alpha-x-app.vercel.app/api/v1`
- The endpoint called for the client list: `https://alpha-x-app.vercel.app/api/v1/admin/clients`

### 5.2 Authentication Flow in Old Live App
1. Admin enters credentials (`fitsundar6@gmail.com`).
2. App sends `POST /api/v1/admin/login` (or `/api/v1/auth/login`).
3. Backend checks `adminAuthService.verifyAdminCredentials()`, which passes in memory.
4. App stores admin JWT in hardware keystore.
5. App requests `GET /api/v1/admin/clients` with `Bearer <admin_jwt>`.
6. Backend returns HTTP 200 with `data: []` due to the silent catch block.
7. Old live app receives HTTP 200, parses 0 items, and displays an empty screen.

---

## 6. Git & Deployment Comparison Analysis

| Dimension | Pre-Cleanup (`fe43df3`) | Post-Cleanup (`bcb130e`) | Divergence? |
| :--- | :--- | :--- | :---: |
| `backend/src/server.ts` | Blob `808d70b` | Blob `808d70b` | **NO (Bit-for-bit identical)** |
| `backend/src/modules/workout/workout.service.ts` | Blob `28bb1b0` | Blob `28bb1b0` | **NO (Bit-for-bit identical)** |
| `backend/src/modules/admin/admin.routes.ts` | Blob `620e722` | Blob `620e722` | **NO (Bit-for-bit identical)** |
| `backend/prisma/schema.prisma` | Blob `b487c45` | Blob `b487c45` | **NO (Bit-for-bit identical)** |
| `backend/package.json` | Blob `aff6e15` | Blob `aff6e15` | **NO (Bit-for-bit identical)** |
| `vercel.json` | Blob `c891114` | Blob `c891114` | **NO (Bit-for-bit identical)** |
| Removed Files | Keystore backup in mobile tree | Removed from tree | Only 1 mobile keystore file |

**Conclusion**: The Git history cleanup did not introduce any code changes, schema changes, or routing regressions. The problem is strictly external database credential authentication.

---

## 7. Safest Recommended Fix Plan

### Phase A: Re-establish Database Connectivity (Zero Code Changes)
1. **Access Neon Console (`console.neon.tech`)**:
   - Locate the project containing database `alpha-x-mobile-db` / compute endpoint `ep-wispy-scene-a5yzabm1`.
   - Check the role `neondb_owner` and reset/obtain its active password, OR create a dedicated application role.
   - Copy the fresh connection string:
     `postgresql://neondb_owner:<NEW_PASSWORD>@ep-wispy-scene-a5yzabm1-pooler.us-east-2.aws.neon.tech/alpha-x-mobile-db?sslmode=require`
2. **Update Vercel Environment Variable**:
   - Go to Vercel Dashboard $\rightarrow$ **alpha-x-app** $\rightarrow$ **Settings** $\rightarrow$ **Environment Variables**.
   - Update `DATABASE_URL` for **Production** and **Preview** with the verified connection string.
   - Update the local `backend/.env` with the same string.
3. **Redeploy / Restart Vercel Production**:
   - Trigger a redeploy of the latest production commit (`bcb130e`) in Vercel to load the new environment variable.
4. **Verify Client List**:
   - Immediately test `GET /api/v1/admin/clients` with the admin token.
   - If the Neon database contains the existing data, the client list will immediately populate on both the old live app and new builds.

### Phase B: Restore Client Data If Neon Database Was Reset
- If the live Neon database is empty or was recreated during recent maintenance:
  - Run a safe restoration script using the pristine local backup `backend/backups/db_backup_2026-10-27T06-57-13-236Z.json` to re-import the 12 client records, workouts, diets, and profiles.

### Phase C: Backend Error Transparency Hardening (Prevent Future Silent Masking)
- Modify `backend/src/modules/workout/workout.service.ts`:
  - When `prisma.user.findMany` throws an error in `getClientsList()`, do NOT return `[]`.
  - Let the error propagate or return an explicit database error so `workoutController` responds with `HTTP 500 INTERNAL_ERROR` (`"Database connection failure"`).
  - This guarantees that mobile apps know when a network or database outage occurs, allowing the app to display a "Unable to load clients: Database offline" banner with a "Retry" button instead of presenting a false "0 Clients" empty state.

---

> [!IMPORTANT]
> **Investigation Complete — Strictly Paused for Approval**  
> In accordance with safety rules, zero code changes, zero database writes, and zero environment modifications have been performed. Awaiting explicit user instruction before proceeding with any fix steps.

