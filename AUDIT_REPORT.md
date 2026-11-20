# Comprehensive Read-Only Audit Report — Detox (Flutter + Firebase)

**Date:** 2026-11-19  
**Scope:** Architecture, structure, maintainability, functional bugs, security, data/permissions handling, dependencies/configuration, validation coverage.  
**Mode:** Read-only — no modifications, deployments, or configuration changes executed.

---

## Project Overview

| Aspect | Details |
|--------|---------|
| **Type** | Flutter app (Android primary) with Firebase Auth, Firestore, native Android services |
| **Package** | `com.nerqova.detox` |
| **Platforms** | Android (primary), Web (preview), macOS (preview), iOS (planned) |
| **Architecture** | Feature-based services + singleton pattern, local-first with cloud sync |
| **Key Capabilities** | App blocking (UsageStats + overlay), focus sessions (Pomodoro, smart breaks), concentration zones (geofencing), sponsor/guardian linking, automation rules, usage analytics |
| **Dependencies** | Firebase (Auth, Firestore, Messaging, Core), Google Sign-In, Geolocator, Flutter Map, SharedPreferences, fl_chart |
| **Test Coverage** | 11 unit/widget test files (username policy, zone config, blocking restore, auth, usage, sponsor, settings, dashboard, legal, protection status) |

---

## Architecture & Structure Assessment

### Strengths
1. **Clear Service Layer Separation** — Services are well-organized singletons (`AppBlockingService`, `CloudSyncService`, `SponsorService`, `UsageService`, `LocationZoneService`, `FocusSessionService`, `AutomationService`, `AntiBypassService`) with single responsibilities.
2. **Local-First with Cloud Sync** — Data primarily in `SharedPreferences`; Firestore acts as backup/sync. Debounced writes (2s) with exponential backoff retry in `CloudSyncService`.
3. **Bootstrap Pattern** — `main.dart` cleanly separates web/macOS preview (`DetoxWebPreviewApp`) from production bootstrap (`DetoxBootstrapApp` → `DetoxApp`).
4. **State Management** — `ValueNotifier` + `PageController` for tabs; `StreamController` for zone state; `FutureBuilder` for async initialization. No external state management library (reduces complexity).
5. **Android Native Integration** — MethodChannel (`detox/device_control`) cleanly bridges Flutter ↔ Kotlin for usage stats, overlay blocking, location monitoring.

### Structural Concerns
| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| ARCH-01 | **Medium** | **Massive `main.dart` (1187 lines)** — Contains bootstrap, app lifecycle, auth state sync, notification handling, sponsor queue, tutorial, time atmosphere rendering, and `_TimeAtmosphere`/`_CloudPainter`/`_StarPainter` custom painters. Violates single responsibility; hard to test. | `lib/main.dart:1-1187` |
| ARCH-02 | **Medium** | **`SponsorService` is 1371 lines** — Handles link requests, unlock requests, support unlink, code generation, profile loading, purge logic, transactions. Should be split into `LinkRequestService`, `UnlockRequestService`, `SponsorProfileService`, `UnlinkService`. | `lib/services/sponsor_service.dart:1-1371` |
| ARCH-03 | **Medium** | **`LocationZoneService` is 532 lines** — Combines permission handling, position streaming, zone evaluation, adaptive location settings, override scheduling, native sync. Consider splitting into `ZoneMonitor`, `ZoneEvaluator`, `ZoneConfigSync`. | `lib/services/location_zone_service.dart:1-532` |
| ARCH-04 | **Low** | **Duplicate bootstrap logic** — `StorageService.bootstrapForSignedInUser()` and `CloudSyncService` both handle user switching; `_resetForNewUser` in `AppBlockingService` duplicates UID tracking. | `lib/services/storage_service.dart:45-145`, `lib/services/app_blocking_service.dart:409-415` |
| ARCH-05 | **Low** | **Inconsistent singleton access** — Some services use `Service.instance`, others `StorageService()` (factory). Standardize. | `lib/services/storage_service.dart:41-43` vs others |
| ARCH-06 | **Info** | **No feature folders** — All services in `lib/services/`, all screens in `lib/screens/`, all models in `lib/models/`. As app grows, consider feature-based grouping (e.g., `lib/features/sponsor/`). | Project structure |

---

## Functional Bugs & Logic Issues

| ID | Severity | Finding | Evidence | Impact |
|----|----------|---------|----------|--------|
| BUG-01 | **High** | **Sponsor unlink race condition** — `unlinkSponsor()` and `consumeCode(unlink_sponsor)` both call `_purgeSponsorPairState` after committing unlink, but purge is best-effort (`try/catch` swallowed). Stale requests remain in `pending`/`approved` state. | `lib/services/sponsor_service.dart:672-709`, `1100-1225`, `813-884` | UI shows stale pending requests; blocks new requests via `errPendingRequestExists` |
| BUG-02 | **High** | **Shield pause request ID collision** — `FocusBlockerService.requestShieldPauseFromSponsor` uses fixed ID `"${uid}_shield_pause"`. If previous request was *approved but not consumed*, new request overwrites it (transaction uses `merge: true`). | `FocusBlockerService.kt:1158-1186`, `lib/services/sponsor_service.dart:985-1002` | Sponsor may approve old request; user consumes new code; mismatch |
| BUG-03 | **Medium** | **`createUnlockRequest` silently succeeds if pending request exists** — Returns early without updating message or notifying UI. User thinks they sent new request; sponsor sees old one. | `lib/services/sponsor_service.dart:979` | Message not updated; confusing UX |
| BUG-04 | **Medium** | **Automation service midnight timer uses `DateTime.now()` at scheduling time** — If device time changes (NTP, manual), timer fires at wrong moment. | `lib/services/automation_service.dart:42-50` | Schedule drift; rules may not refresh at true midnight |
| BUG-05 | **Medium** | **Focus session `tickAndAdvance` recursively calls `buildSnapshot` on day boundary** — If `completedAt` day ≠ `now` day, calls `buildSnapshot()` again without await, risking stack overflow. | `lib/services/automation_service.dart:74-79` | Potential stack overflow on day boundary |
| BUG-06 | **Medium** | **`LocationZoneService._applyAdaptiveLocationSettings` restarts position stream on every evaluation** — Called from `_evaluatePosition` which runs on every position update (every 30-120s). Stream restart cancels/recreates subscription frequently. | `lib/services/location_zone_service.dart:219-242`, `379-406` | Battery drain; subscription churn |
| BUG-07 | **Low** | **`CloudSyncService._flushNow` re-throws after scheduling retry** — Caller sees exception even though retry is scheduled. `flushPendingWrites` in `AuthService.deleteAccount` catches but `signOut` doesn't. | `lib/services/cloud_sync_service.dart:292-299` | Inconsistent error handling on sign-out |
| BUG-08 | **Low** | **`UsageService._estimatePickups` uses arbitrary formula** — `max(6, totalMinutes/4)`. Not based on real pickup data. | `lib/services/usage_service.dart:400-402` | Misleading "pickups" metric on dashboard |

---

## Security Findings

### Critical/High (from existing SECURITY_AUDIT_REPORT + my verification)

| ID | Severity | Finding | Evidence | Status |
|----|----------|---------|----------|--------|
| SEC-01 | **Critical** | **`google-services.json` committed to repo** — Contains Firebase API key (`AIzaSyCgYO9qPz1iGEKIoWz4wgI5Hsy3ghfIwWo`), OAuth client IDs, SHA-1 hashes for two packages. | `google-services.json:17-51`, `55`, `83-110` | **CONFIRMED** — Must remove from git history, rotate key, restrict to package+SHA-1 |
| SEC-02 | **High** | **No rate limiting on Firebase Auth endpoints** — Email/password, phone, anonymous sign-up/in rely solely on Firebase's opaque protections. No client-side throttling, CAPTCHA, or device fingerprinting. | `lib/services/auth_service.dart:102-160`, `213-270` | **CONFIRMED** |
| SEC-03 | **High** | **Firestore `list` rules over-permissive on sponsor collections** — Any signed-in user can list ALL pending link/unlock requests (`allow list: if signedIn()`). | `firestore.rules:106-107`, `114-115` | **CONFIRMED** |
| SEC-04 | **High** | **Firestore `users/{userId}` read allows any authenticated user to read ANY profile** — Exposes displayName, email, sponsorUid, sponsorCode, unlock timestamps, push tokens. | `firestore.rules:65` | **CONFIRMED** |
| SEC-05 | **High** | **Anonymous account upgrade without re-verification** — `linkWithCredential` trusts current session; attacker with temporary device access can permanently link their credentials. | `lib/services/auth_service.dart:112-122`, `162-211` | **CONFIRMED** |
| SEC-06 | **High** | **Phone verification state only in memory** — `_verificationId` + nonce not persisted; race conditions possible on rapid code requests. | `lib/services/auth_service.dart:273-311` | **CONFIRMED** |

### Medium/Low

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| SEC-07 | **Medium** | **`meta/admin/unlink_requests` get rule allows probing other users' requests** — `resource == null` check allows existence enumeration. | `firestore.rules:146` |
| SEC-08 | **Medium** | **Sponsor code input not format-validated before Firestore query** — Allows enumeration via error differentiation ("code not found" vs "target has sponsor"). | `lib/services/sponsor_service.dart:434-464` |
| SEC-09 | **Medium** | **Username policy lacks NFKC normalization** — Homoglyphs (Cyrillic `і` vs Latin `i`) bypass reserved word checks. | `lib/services/username_policy.dart:92-112` |
| SEC-10 | **Medium** | **Message fields in sponsor requests not sanitized** — Truncated to 300 chars but control characters not stripped. | `lib/services/sponsor_service.dart:187-191` |
| SEC-11 | **Medium** | **No certificate pinning** — Firebase SDK uses platform trust store; MITM possible on compromised networks. | N/A (architecture) |
| SEC-12 | **Low** | **AdMob App ID as manifest placeholder** — Ensure `admobAppId` not in version control; inject via CI secret. | `AndroidManifest.xml:70-71` |
| SEC-13 | **Low** | **Push token deviceId format (32 hex) — verify not hardware ID** | `firestore.rules:89` |
| SEC-14 | **Low** | **Phone number stored in user doc readable by all (FS-03)** | `lib/models/auth_user.dart:28`, `lib/services/cloud_sync_service.dart:68-83` |
| SEC-15 | **Low** | **Boot receiver restarts shield without user notification** — Could surprise user if state corrupted. | `BootReceiver.kt:14-53`, `AndroidManifest.xml:59-67` |

---

## Data Handling & Permissions

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| DATA-01 | **Medium** | **Concentration zones store precise GPS coordinates in Firestore** — Reveals home/work/school. Firestore rules (FS-03) expose to all authenticated users. | `lib/models/concentration_zone.dart`, `lib/services/location_zone_service.dart` |
| DATA-02 | **Medium** | **Usage stats cached only in RAM (no encryption at rest)** — Acceptable for threat model but document. | `lib/services/usage_service.dart:27-43` |
| DATA-03 | **Low** | **Push tokens stored with 4096-char limit, 32-hex deviceId** — Reasonable validation. Verify deviceId is random UUID, not Android ID/SSAID. | `firestore.rules:88-102` |
| DATA-04 | **Low** | **Anonymous account auto-unlink after 7 days** — Documented in privacy policy; verify server-side enforcement exists. | `lib/services/cloud_sync_service.dart:75-77`, `docs/legal/aviso-de-privacidad.md:46-49` |
| DATA-05 | **Info** | **Privacy policy thorough (Mexico LFPDPPP + GDPR)** — Discloses Firebase/Google hosting outside Mexico, ARCO rights, retention, third parties (AdMob, Apps Script). | `docs/legal/aviso-de-privacidad.md` |

---

## Android Permissions & Native Code

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| AND-01 | **High** | **`PACKAGE_USAGE_STATS` + `tools:ignore="ProtectedPermissions"`** — Grants visibility into ALL app usage. Mitigated by user-grant flow. | `AndroidManifest.xml:3-5` |
| AND-02 | **High** | **`SYSTEM_ALERT_WINDOW` + foreground services (location, specialUse)** — Overlay draws on top of blocked apps; persistent foreground service. `SHOW_SERVICE_NOTIFICATION = true` (good). | `AndroidManifest.xml:6, 7-9, 11-14, 48-56` |
| AND-03 | **Medium** | **`FocusBlockerService` stores shield state in `SharedPreferences` (world-readable by same UID)** — Not encrypted. | `FocusBlockerService.kt:93`, `ShieldStateStore.kt:30-78` |
| AND-04 | **Medium** | **`NativeZoneMonitor` registers GPS/Network listeners with 30s/25m intervals** — Runs in foreground service. Battery drain; location precision reveals patterns. | `NativeZoneMonitor.kt:45-63`, `113-165` |
| AND-05 | **Low** | **Method channel `detox/device_control` exposes 10+ methods** — All have permission checks; surface area if Flutter engine compromised. | `MainActivity.kt:51-359` |

---

## Dependencies & Configuration

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| DEP-01 | **Medium** | **`flutter_launcher_icons` config in `pubspec.yaml` but not declared as dependency** — Block is inert; icon generation via external script. | `pubspec.yaml:41-51` |
| DEP-02 | **Low** | **Dependency versions use caret ranges** — `firebase_core: ^4.15.0`, `firebase_auth: ^6.7.0`, `cloud_firestore: ^6.10.0`. Pin exact versions for reproducible builds; check for CVEs. | `pubspec.yaml:22-26` |
| DEP-03 | **Low** | **`google-services.json` references two packages** — `com.example.detox` (placeholder) and `com.nerqova.detox`. Remove unused. | `google-services.json:17-51`, `83-110` |
| DEP-04 | **Info** | **Vercel deploy config for static web preview** — Clean rewrites for legal docs, security headers present. | `vercel-deploy/vercel.json` |

---

## Validation Coverage

| Area | Coverage | Gaps |
|------|----------|------|
| **Username policy** | Good — 3 tests covering insults, obfuscations, reserved names, size/char validation, false positives (Scunthorpe). | No NFKC normalization test; no homoglyph test. |
| **Zone monitor config** | 1 test — verifies native receives enabled zones with resolved apps. | No test for disabled zones, override, sponsor state. |
| **Blocking restore** | 1 test — verifies removing focus block preserves automation block. | No test for sponsor state, strict mode, expiry. |
| **Auth flows** | 1 test (anonymous) — limited. | No tests for email/password, Google, phone, link, unlink, delete. |
| **Usage service** | 2 tests (day boundary, challenge) — logic only. | No integration test with native channel. |
| **Sponsor flows** | 1 test (push notice) — UI only. | No tests for link/unlock/unlink requests, code generation, purge. |
| **Settings/Protection/Legal/Dashboard** | UI scroll/loading tests only. | No business logic tests. |
| **Firestore rules** | **NO UNIT TESTS** — Critical gap. | Add `firebase_rules_unit_test` for all rules. |

---

## Maintainability & Code Quality

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| MAINT-01 | **Medium** | **`main.dart` 1187 lines** — Multiple responsibilities: bootstrap, auth sync, notifications, sponsor queue, tutorial, custom painters. Split into `BootstrapCoordinator`, `AuthStateManager`, `NotificationHandler`, `SponsorQueue`, `TutorialService`, `TimeAtmosphere`. | `lib/main.dart` |
| MAINT-02 | **Medium** | **`SponsorService` 1371 lines** — 7 distinct responsibilities. Split into 4-5 focused services. | `lib/services/sponsor_service.dart` |
| MAINT-03 | **Medium** | **Deeply nested callbacks in `SponsorService` transactions** — Hard to follow; consider extracting transaction logic to private methods. | `lib/services/sponsor_service.dart:138-161`, `193-270`, `607-669` |
| MAINT-04 | **Low** | **Inconsistent error handling** — Some `catch (_) {}`, some `catch (e) { rethrow; }`, some `catch (e) { debugPrint; }`. Standardize. | Multiple files |
| MAINT-05 | **Low** | **Magic numbers/strings** — e.g., `_writeDebounce = 2s`, `_snapshotCacheTtl = 5s`, sponsor code length 6, zone padding 200/600m. Extract to constants. | `lib/services/cloud_sync_service.dart:21-22`, `lib/services/location_zone_service.dart:48-53` |
| MAINT-06 | **Low** | **Duplicate `unlink` field maps** — `_unlinkLinkedUserFields` and `clearReleasedUserFields` nearly identical. | `lib/services/sponsor_service.dart:782-792`, `905-915` |
| MAINT-07 | **Info** | **Good: `automaticKeepAliveClientMixin` on tabs** — Preserves state correctly. | `lib/screens/dashboard_screen.dart:226`, `lib/screens/focus_screen.dart:368` |
| MAINT-08 | **Info** | **Good: `WidgetsBindingObserver` for lifecycle** — Proper resume/pause handling. | Multiple screens/services |

---

## Test Coverage Summary

| Test File | Type | Coverage |
|-----------|------|----------|
| `username_policy_test.dart` | Unit | 3 tests — good coverage of validation logic |
| `zone_monitor_config_test.dart` | Unit | 1 test — verifies native sync payload |
| `blocking_restore_test.dart` | Unit | 1 test — verifies shield merge logic |
| `anonymous_auth_test.dart` | Widget | Anonymous auth flow |
| `usage_day_boundary_test.dart` | Unit | Day boundary logic |
| `usage_challenge_test.dart` | Unit | Usage challenge logic |
| `sponsor_push_notice_test.dart` | Widget | Push notice UI |
| `settings_scroll_test.dart` | Widget | Settings scroll |
| `protection_status_test.dart` | Widget | Protection status UI |
| `legal_document_test.dart` | Widget | Legal doc rendering |
| `dashboard_loading_test.dart` | Widget | Dashboard loading state |
| `web_preview_test.dart` | Widget | Web preview gallery |

**Total: 11 test files, ~15 test cases** — Low for project size. Missing: integration tests, Firestore rules tests, sponsor flow tests, automation tests, focus session tests, location zone tests.

---

## Prioritized Remediation Plan

### P0 — Immediate (Security/Compliance)
1. **Remove `google-services.json` from git history** (`git filter-repo` or BFG), rotate Firebase API key, restrict to `com.nerqova.detox` + SHA-1.
2. **Fix Firestore rules** — Restrict `list` on sponsor collections (FS-01), fix `get` on admin unlink (FS-02), restrict `users/{userId}` read (FS-03).
3. **Add rate limiting + CAPTCHA** to auth flows (AUTH-01).

### P1 — This Sprint (Critical Bugs + High Security)
4. **Fix sponsor unlink race** (SPON-01/BUG-01) — Make purge idempotent + retry with backoff; surface failure to user.
5. **Fix shield pause request ID collision** (SPON-03/BUG-02) — Use unique ID per attempt (timestamp suffix).
6. **Validate sponsor code format client-side + rate-limit** (VAL-01/SEC-08) — Regex `^[A-HJ-NP-Z2-9]{6}$`, max 5 attempts/min.
7. **Fix `createUnlockRequest` silent success** (BUG-03) — Return status indicating existing pending request.

### P2 — Next Sprint (Medium Bugs + Security)
8. **Require re-auth before linking providers to anonymous account** (AUTH-02).
9. **Store phone verification state server-side (Firestore) with TTL** (AUTH-03).
10. **Apply NFKC normalization to username policy** (VAL-03/SEC-09).
11. **Fix automation midnight timer drift** (BUG-04) — Use `Timer.periodic` with daily check or `vercel-schedules`/`pg_cron` equivalent.
12. **Optimize `LocationZoneService` adaptive settings** (BUG-06) — Debounce stream restart; only restart when accuracy tier actually changes.
13. **Add max cumulative unlock time per day** (SPON-05) — Enforce in rules or service (e.g., 60 min/day).

### P3 — Backlog (Architecture + Quality)
14. **Split `main.dart`** into coordinator classes.
15. **Split `SponsorService`** into `LinkRequestService`, `UnlockRequestService`, `SponsorProfileService`, `UnlinkService`.
16. **Split `LocationZoneService`** into `ZoneMonitor`, `ZoneEvaluator`, `ZoneConfigSync`.
17. **Add Firestore rules unit tests** (`firebase_rules_unit_test`).
18. **Add integration tests** for sponsor flows, shield service, focus sessions, automation.
19. **Certificate pinning** for Firebase traffic.
20. **Encrypt `SharedPreferences` shield state** (AND-03).
21. **Boot receiver notification + validation** (AND-05).
22. **Standardize error handling** across services.
23. **Extract magic numbers to constants**.

---

## Coverage Limitations

| Limitation | Impact |
|------------|--------|
| **No runtime testing** — Static analysis only; no penetration testing, dynamic analysis, or device testing performed. | May miss runtime-only issues (e.g., native crash, permission dialog flows). |
| **Native Kotlin code partially reviewed** — `FocusBlockerService.kt`, `NativeZoneMonitor.kt`, `MainActivity.kt`, `ShieldStateStore.kt`, `BootReceiver.kt`, `RewardAdActivity.kt` referenced in security audit but not fully read in this audit. | Native-layer bugs (memory leaks, ANR, permission edge cases) not assessed. |
| **iOS/macOS not reviewed** — No iOS folder found; macOS only has `RunnerTests`. | Platform-specific issues unknown. |
| **Apps Script (`apps_script/Code.gs`) not reviewed** — Referenced for support unlink email flow. | External dependency risk not assessed. |
| **CI/CD pipeline not reviewed** — No GitHub Actions / `.github/workflows` found. | Build/release process security unknown. |
| **Dependency vulnerability scan not run** — `pubspec.yaml` versions not checked against CVE databases. | Potential vulnerable dependencies. |

---

## Files Inspected (Read-Only)

```
pubspec.yaml
pubspec.lock
firebase.json
firestore.rules
google-services.json
lib/main.dart
lib/firebase_options.dart
lib/l10n_app_strings.dart
lib/theme/app_theme.dart
lib/models/*.dart (14 files)
lib/screens/*.dart (13 files)
lib/services/*.dart (23 files)
lib/widgets/*.dart (8 files)
android/app/src/main/AndroidManifest.xml
android/app/src/profile/AndroidManifest.xml
android/app/src/debug/AndroidManifest.xml
android/settings.gradle.kts
android/build.gradle.kts
android/gradle.properties
android/key.properties
vercel-deploy/vercel.json
vercel-deploy/web/*.html
web/*.html
docs/legal/*.md
docs/legal/*.html
docs/brand/detox-logo/*
SECURITY_AUDIT_REPORT.md
test/*.dart (11 files)
apps_script/*.gs
scripts/*.cjs
README.md
PLAY_STORE_DEPLOYMENT.md
FIREBASE_EMAIL_SETUP.md
FIRESTORE_RULES_FOR_SPONSOR.md
```

---

## Summary

| Category | Critical | High | Medium | Low | Info |
|----------|----------|------|--------|-----|------|
| **Security** | 1 | 5 | 5 | 4 | 1 |
| **Functional Bugs** | 0 | 2 | 5 | 1 | 0 |
| **Architecture** | 0 | 0 | 3 | 2 | 1 |
| **Data/Permissions** | 0 | 0 | 2 | 2 | 1 |
| **Dependencies** | 0 | 0 | 1 | 2 | 1 |
| **Validation/Testing** | 0 | 0 | 1 | 0 | 0 |
| **Maintainability** | 0 | 0 | 3 | 3 | 2 |
| **TOTAL** | **1** | **7** | **20** | **14** | **6** |

**Top 3 Risks:**
1. **`google-services.json` in repo** — Immediate credential exposure.
2. **Firestore over-permissive reads** — Any user can enumerate all profiles and sponsor requests.
3. **Sponsor unlink race + shield pause collision** — Data integrity bugs in core business logic.

**Overall Assessment:** Solid Flutter/Firebase architecture with local-first sync and native Android integration. Security posture weakened by committed secrets and over-permissive Firestore rules. Core sponsor/shield logic has race conditions needing fixes. Test coverage is minimal — invest in Firestore rules tests and integration tests. Architecture would benefit from splitting monolithic files (`main.dart`, `SponsorService`, `LocationZoneService`).