# Alpha X App – Step 3.1: Pre-Push Git Reference Verification Report

**Date & Time:** 2026-11-04 08:46 UTC+5:30  
**Operation Scope:** STRICT READ-ONLY Investigation & Comparison  
**Investigated Repositories:**
- **Original Mirror Backup:** `C:\Users\johng\.gemini\antigravity-ide\scratch\alpha_x_gym_git_mirror_backup.git`
- **Cleaned Working Copy:** `C:\Users\johng\.gemini\antigravity-ide\scratch\alpha_x_gym_cleaned_working_copy.git`
- **Remote Origin (GitHub):** `https://github.com/fitsundar6/alpha_X_app.git`

---

## 1. Executive Summary: The 6-Branch vs 3-Branch Investigation

### Core Finding
**Zero branches were omitted or lost.**  
The apparent discrepancy (6 branches in the mirror vs 3 branches in the cleaned repository) is the intended and correct behavior of `git-filter-repo`:

1. **Why the original mirror reported 6 branches:**
   The offline mirror backup was created with `git clone --mirror . <backup_path>` from the active development workspace. In that workspace:
   - There were **2 local heads** (`refs/heads/main` and `refs/heads/fix/push-notification-production-readiness`).
   - There were **4 remote-tracking references** (`refs/remotes/origin/main`, `refs/remotes/origin/fix/gemini-reliability`, `refs/remotes/origin/fix/push-notification-production-readiness`, and symbolic pointer `refs/remotes/origin/HEAD`).
   - Because `git clone --mirror` clones the `.git` directory literally, it cloned both the local heads and the remote tracking heads, producing **6 branch refs** in `git branch -a` with duplicate representations of `main` and `fix/push-notification-...`.

2. **Why the cleaned repository reports 3 branches:**
   `git-filter-repo` is built specifically to prepare repositories for clean remote migration. By design:
   - It strips the redundant client-side tracking prefix (`refs/remotes/origin/`) and promotes remote branches without a local counterpart (`origin/fix/gemini-reliability`) into proper first-class heads (`refs/heads/fix/gemini-reliability`).
   - For branches that existed in both namespaces (`main` and `fix/push-notification-production-readiness`), it deduplicated them by taking the local branch tip (which contained recent commits ahead of remote) and dropping the redundant `refs/remotes/origin/` tracking ref.
   - It discarded `refs/remotes/origin/HEAD`, which is an alias pointer rather than an independent branch.

3. **Remote Verification with GitHub (`origin`):**
   A live read-only inspection of GitHub (`git ls-remote --heads origin`) confirms that **GitHub has exactly 3 branches**, identical to the 3 branches in the cleaned repository:
   - `refs/heads/main`
   - `refs/heads/fix/gemini-reliability`
   - `refs/heads/fix/push-notification-production-readiness`

---

## 2. Complete Ref Inventory & Migration Mapping

The table below details every ref in the original mirror backup, how it was processed, and its corresponding cleaned ref in `alpha_x_gym_cleaned_working_copy.git`:

| Original Ref Name | Pre-Cleaned Commit SHA | Cleaned Ref Name | Cleaned Commit SHA | Commit Subject / Description | Transformation Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `refs/heads/main` | `fe43df36e9fc` | `refs/heads/main` | `bcb130e2b6ba` | `fix(config): generate cryptographic fallback for production QR secret...` | Rewritten to scrub history; identical file tree minus `.jks.backup` |
| `refs/remotes/origin/main` | `fe43df36e9fc` | *(Deduplicated)* | — | *(Same as refs/heads/main)* | Consolidated into `refs/heads/main` |
| `refs/remotes/origin/HEAD` | `fe43df36e9fc` | *(Pruned)* | — | Pointer to `origin/main` | Client-side tracking pointer removed |
| `refs/remotes/origin/fix/gemini-reliability` | `43f69a5563ed` | `refs/heads/fix/gemini-reliability` | `29ab50844645` | `final` | Promoted from remote tracking to first-class head; rewritten |
| `refs/heads/fix/push-notification-production-readiness` | `2fb6b8fffefa` | `refs/heads/fix/push-notification-production-readiness` | `28005a527290` | `feat(notifications): add single client test push dispatch...` | Preserved with full 5-commit lineage; rewritten |
| `refs/remotes/origin/fix/push-notification-production-readiness` | `db3976f44dda` | *(Ancestor)* | `b7aad1f0f423` | `feat(notifications): add automated fitness engagement push...` | Remote commit was 2 commits behind local tip; preserved as ancestor |
| `refs/tags/v1.0.0` | `a7ec180e6cb5` | `refs/tags/v1.0.0` | `a7ec180e6cb5` | `build: trigger GitHub release build for iOS and Android` | **Unchanged (Identical SHA)** — predates exposure commit `6ec03658` |
| `refs/tags/v1.0.0-build.77` | `0ec4812e0c13` | `refs/tags/v1.0.0-build.77` | `18cd35344e9f` | `final s` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.78` | `9d243d5280e0` | `refs/tags/v1.0.0-build.78` | `1e78989657ac` | `fix(audit): resolve security, rate limiting, Client ID race...` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.79` | `62ba164347a0` | `refs/tags/v1.0.0-build.79` | `a126847dddbd` | `fix(audit): prevent passwordless account enumeration...` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.82` | `0f57b7143745` | `refs/tags/v1.0.0-build.82` | `19f50fb732ee` | `FINAL` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.86` | `a4380735e83f` | `refs/tags/v1.0.0-build.86` | `15f42a4a52d8` | `fix(mobile): resolve prefer_interpolation_to_compose_strings...` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.87` | `5d5ea7b9c3c8` | `refs/tags/v1.0.0-build.87` | `8ebde2a1f028` | `fix: resolve AI coach backend errors and admin token handling` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.88` | `61da59bf5fdb` | `refs/tags/v1.0.0-build.88` | `b6cd60f9e716` | `fix: eliminate Gemini SDK .text warning and reliably capture...` | Rewritten with sanitized ancestor history |
| `refs/tags/v1.0.0-build.89` | `aef070e04b8a` | `refs/tags/v1.0.0-build.89` | `8d573fa71126` | `fix: resolve AI coach localhost connection error and guarantee...` | Rewritten with sanitized ancestor history |

---

## 3. Empirical Verification: Sensitive File Absence Across Every Ref

Every reachable ref in the cleaned repository was queried across its entire commit history and tree objects for:
1. `backend/backups/db_backup_2026-10-10T13-01-42-639Z.json`
2. `apps/mobile/android/app/upload-keystore.jks.backup`
3. Wildcard patterns: `*db_backup*` and `*upload-keystore*`

### Verification Results Table

| Cleaned Ref Name | Type | Target in Tree? | Target in Commit History? | Wildcard Matches? | Integrity Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `refs/heads/main` | Branch | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/heads/fix/gemini-reliability` | Branch | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/heads/fix/push-notification-production-readiness` | Branch | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.77` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.78` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.79` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.82` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.86` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.87` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.88` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |
| `refs/tags/v1.0.0-build.89` | Tag | **0 (None)** | **0 (None)** | **0 (None)** | **CLEAN (PASS)** |

**Git Object Database Check:**
`git cat-file -t b02dff135a6dab78f642b12fe947777b8571f1ad` (the 4.5 MB database backup blob)  
**Result:** `fatal: git cat-file: could not get object info` — **Purged from database.**

---

## 4. Critical Remote Discovery: Stale CI/CD Tags on GitHub

A live read-only inspection of the remote tags currently published on GitHub (`git ls-remote --tags origin`) uncovered **3 tags that exist on GitHub but were never fetched to the local workspace**:

```text
3e542eeec4038e3c3e419a754516a34402a395a3  refs/tags/v1.0.0-build.90
fe43df36e9fc9e1a9a26ca1722042f6c61948314  refs/tags/v1.0.0-build.91
fe43df36e9fc9e1a9a26ca1722042f6c61948314  refs/tags/v1.0.0-build.92
```

### Why They Exist on GitHub but Not Locally
These 3 tags were automatically generated on GitHub by the CI/CD GitHub Actions build workflow (`build-mobile.yml` / release trigger) when previous builds were dispatched. Because `git fetch --tags` was not run in the local development workspace before the Step 2 offline mirror was cloned, they were absent from the local `.git/refs/tags/`.

### The Security Implication
- `v1.0.0-build.91` and `v1.0.0-build.92` point directly to pre-cleaned commit `fe43df36e9fc`.
  - `fe43df36e9fc` contains `apps/mobile/android/app/upload-keystore.jks.backup` in its working tree.
  - `fe43df36e9fc` has `6ec03658` (the 4.5 MB database backup) in its direct ancestry.
- `v1.0.0-build.90` points to commit `3e542eeec403` (`"jesus"`), which also has `6ec03658` in its ancestry.

> [!CAUTION]
> If a standard `git push origin --force --tags` is executed without addressing these 3 tags, Git will push the 9 cleaned tags but **will leave `build.90`, `build.91`, and `build.92` untouched on GitHub**.  
> As long as those 3 tags exist on GitHub, GitHub will consider `fe43df36` and `3e542ee` reachable refs, preventing GitHub from purging the exposed database backup and keystore backup.

### Clean Resolution Strategy for Step 4
In the cleaned repository, the corresponding sanitized commits are already known and verified:
- `3e542eeec403` was rewritten to sanitized commit `c37f473` (contains no backups).
- `fe43df36e9fc` was rewritten to sanitized commit `bcb130e` (contains no backups).

During Step 4, we have two safe options:
1. **Option A (Preserve All Build Tags):** Add the 3 missing build tags in the cleaned repository pointing to their sanitized commits (`build.90 -> c37f473`, `build.91 -> bcb130e`, `build.92 -> bcb130e`), then force push all tags (`git push origin --force --tags`).
2. **Option B (Delete Stale Remote Build Tags):** Explicitly delete the 3 uncleaned tags on GitHub via `git push origin --delete v1.0.0-build.90 v1.0.0-build.91 v1.0.0-build.92`.

---

## 5. Verification Checklist & Migration Readiness

| Check | Spec Requirement | Verdict | Empirical Evidence |
| :--- | :--- | :--- | :--- |
| **All Original Branches Accounted For** | Verify `main`, `fix/gemini-...`, `fix/push-...` | **PASS** | All 3 present as first-class heads in cleaned copy |
| **Why 6 vs 3 Branches** | Explain difference with evidence | **PASS** | 2 local + 4 remote tracking refs consolidated into 3 distinct heads |
| **All 9 Tags Accounted For** | Verify `v1.0.0` through `build.89` | **PASS** | All 9 tags exist and point to valid sanitized commits |
| **Accidental Omissions** | Confirm no branch/tag omitted from mirror | **PASS** | 0 branches or tags lost from the mirror backup |
| **Target Files Scrubbed** | Verify `.json` and `.jks.backup` absent | **PASS** | 0 references across all 12 refs in tree, history, or wildcards |
| **Repository Health** | `git fsck --full` | **PASS** | 0 errors, 0 warnings, 0 missing objects |
| **Remote Push Status** | Strictly read-only | **PASS** | 0 push commands executed; remote untouched |

### Readiness Conclusion
The cleaned repository at `C:\Users\johng\.gemini\antigravity-ide\scratch\alpha_x_gym_cleaned_working_copy.git` is **100% verified and structurally ready for remote migration**.

---

> [!IMPORTANT]
> **Strict Read-Only Guarantee:** No Git refs have been modified. No push commands have been executed. No GitHub settings have been altered.  
> Awaiting your explicit guidance and approval on the tag handling strategy before proceeding to Step 4.

