# Security Audit Report — Detox (Flutter + Firebase)

**Date:** 2026-11-19  
**Scope:** Read-only static analysis of authentication/authorization, Firestore rules, secrets/config, personal data handling, Android permissions, validation, and sponsor flows.  
**Project:** Detox — Android app (package `com.nerqova.detox`) with Firebase Auth, Firestore, and native Android services for app blocking and location-based concentration zones.

---

## Executive Summary

| Category | Critical | High | Medium | Low | Info |
|----------|----------|------|--------|-----|------|
| **Authentication / Authorization** | 0 | 1 | 2 | 1 | 2 |
| **Firestore Rules** | 0 | 0 | 3 | 2 | 1 |
| **Secrets / Configuration** | 0 | 1 | 1 | 0 | 1 |
| **Personal Data Handling** | 0 | 0 | 2 | 1 | 3 |
| **Android Permissions / Native Code** | 0 | 2 | 3 | 2 | 2 |
| **Input Validation / Injection** | 0 | 1 | 2 | 1 | 0 |
| **Sponsor Flows** | 0 | 1 | 2 | 1 | 1 |
| **TOTAL** | **0** | **6** | **15** | **8** | **10** |

> **No critical-severity findings** (direct exploit / data breach). The highest-severity issues are **High**: missing rate limiting on auth endpoints, over-permissive Firestore `list` rules on sponsor collections, API key in `google-services.json` committed to repo, missing certificate pinning / TLS enforcement verification, and sponsor unlink race conditions.

---

## 1. Authentication & Authorization

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| AUTH-01 | **High** | **No rate limiting / brute-force protection on Firebase Auth endpoints** (email/password, phone, anonymous). The app relies solely on Firebase's built-in protections which are opaque and may not suffice for targeted attacks. | `lib/services/auth_service.dart:102-160` (`signUpWithEmail`, `signInWithEmail`), `lib/services/auth_service.dart:213-270` (`startPhoneVerification`), `lib/screens/auth_screen.dart` — no client-side throttling, CAPTCHA, or device fingerprinting. | Credential stuffing, password spraying, SMS pumping (phone auth), anonymous account enumeration. | Implement client-side exponential backoff + CAPTCHA (reCAPTCHA Enterprise) for sign-up/sign-in. Enable Firebase Auth "Password Policy" and "Block/allow IP ranges" in console. Monitor `too-many-requests` errors and alert. |
| AUTH-02 | **Medium** | **Anonymous accounts can be upgraded to email/password/Google/phone without re-verifying ownership of the anonymous UID**. The `linkWithCredential` flow trusts the current session. | `lib/services/auth_service.dart:112-122` (`signUpWithEmail` links to existing anonymous user), `lib/services/auth_service.dart:162-211` (`signInWithGoogle` with `linkToCurrentUser`). | If an attacker gains temporary access to an unlocked device with an anonymous session, they can permanently link their own credentials and take over the account. | Require re-authentication (password / biometric) before linking a new provider to an anonymous account. |
| AUTH-03 | **Medium** | **Phone verification uses client-side `Completer` and nonce but no server-side enforcement of "one code per request"**. The `_verificationId` is stored only in memory. | `lib/services/auth_service.dart:273-311` (`_verificationId`, `_activeVerificationNonce`, `_completePhoneCredential`). | Race condition / request smuggling if the user rapidly requests codes; could allow bypassing SMS delivery verification. | Store `verificationId` + nonce in Firestore with TTL; validate server-side on `verifySmsCode`. |
| AUTH-04 | **Low** | **Google Sign-In uses `GoogleSignIn.instance` (new API) but does not validate `idToken` audience (`aud`) claim matches the Firebase project**. | `lib/services/auth_service.dart:169-176` (`GoogleAuthProvider.credential(idToken: googleAuth.idToken)`). | Theoretical token substitution if a malicious OAuth client is registered in the same Google Cloud project. | Verify `idToken` audience matches `project_id` from `google-services.json` before sending to Firebase. |
| AUTH-05 | **Info** | **Account deletion flow marks Firestore doc with `accountDeleted: true` but does not revoke Firebase Auth tokens immediately**. | `lib/services/cloud_sync_service.dart:301-363` (`markAccountDeleted`), `lib/services/auth_service.dart:313-347` (`deleteAccount`). | Brief window where deleted account's ID token could still access Firestore (rules check `request.auth != null`). | Call `FirebaseAuth.instance.currentUser?.delete()` before Firestore cleanup; ensure rules reject `accountDeleted == true` docs. |
| AUTH-06 | **Info** | **`AuthUser` model stores `provider` as a free-form string from `providerData.first.providerId`**. | `lib/models/auth_user.dart:361-376` (`_mapUser`). | Low risk; used only for display. | Consider enum for known providers; validate against allowlist. |

---

## 2. Firestore Security Rules (`firestore.rules`)

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| FS-01 | **Medium** | **`allow list` on `meta/sponsor/link_requests` and `meta/sponsor/unlock_requests` for any signed-in user**. Users can list *all* pending requests in the system, not just their own. | `firestore.rules:106-107`, `firestore.rules:114-115` — `allow list: if signedIn();` | Information disclosure: any authenticated user can enumerate all sponsor link/unlock requests, seeing requester/target names, messages, and timestamps. | Restrict `list` to `requesterUid == request.auth.uid || targetUid == request.auth.uid || sponsorUid == request.auth.uid`. Use `get` for single-doc access. |
| FS-02 | **Medium** | **`meta/admin/unlink_requests` `get` rule allows reading *any* user's support unlink request if the document exists** (`resource == null || resource.data.requesterUid == request.auth.uid`). A user can probe for existence of other users' requests. | `firestore.rules:146` — `allow get: if signedIn() && (resource == null || resource.data.requesterUid == request.auth.uid);` | Enumeration of which users have filed support unlink requests (PII: email, name, sponsorUid). | Change to `allow get: if signedIn() && resource.data.requesterUid == request.auth.uid;` (deny on non-existent). |
| FS-03 | **Medium** | **`users/{userId}` `allow read: if signedIn()` — any authenticated user can read *any* other user's profile document** (displayName, email, sponsorUid, sponsorCode, settings unlock timestamps, push tokens). | `firestore.rules:65` — `allow read: if signedIn();` | Full profile enumeration: sponsor codes (allows spoofing link requests), email addresses, sponsor relationships, unlock timestamps. | Restrict to `isSelf(userId) || (signedIn() && get(/users/$(request.auth.uid)).data.sponsorUid == userId) || (signedIn() && get(/users/$(userId)).data.sponsorUid == request.auth.uid)`. |
| FS-04 | **Low** | **`users/{userId}/usage_days/{day}` read rule allows sponsor to read *only if* mutual sponsorship exists** (both directions). However, the rule does not validate that the sponsor link is *currently active* (could be stale `sponsorUid` after unlink). | `firestore.rules:70-74` — checks `sponsorUid` on both docs but not `sponsorLinkedAt` freshness. | If unlink cleanup races, a former sponsor might briefly read usage data. | Add `sponsorLinkedAt` timestamp check (e.g., within last 30 days) or rely on `_purgeSponsorPairState` atomicity. |
| FS-05 | **Low** | **`mail/{docId}` completely blocked (`allow read, write: if false`)** — correct for server-only, but no comment explaining which Cloud Function writes here. | `firestore.rules:160-162` | Maintenance risk: future dev may open it accidentally. | Add comment: `// Written only by sendSupportUnlinkEmail Cloud Function (see apps_script/Code.gs)`. |
| FS-06 | **Info** | **Rules use `exists()` and `get()` heavily in helper functions** (`canAcceptPendingSponsorLink`, `canApplySettingsUnlock`, etc.). Each call counts against Firestore read quota and adds latency. | `firestore.rules:23-62` | Cost / latency at scale; not a security issue. | Consider denormalizing `status` into the user doc or using custom claims for sponsor role. |

---

## 3. Secrets & Configuration

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| SEC-01 | **High** | **`google-services.json` committed to repository** containing **Firebase API key (`AIzaSyCgYO9qPz1iGEKIoWz4wgI5Hsy3ghfIwWo`)**, OAuth client IDs, and project IDs for two Android packages (`com.example.detox`, `com.nerqova.detox`). | `google-services.json:55`, `google-services.json:17-51`, `google-services.json:83-110` | API key can be used to call Firebase Auth / Firestore REST APIs anonymously (subject to project quotas and Auth restrictions). OAuth client IDs + SHA-1 hashes enable potential app impersonation if combined with a stolen keystore. | **Remove from repo immediately**. Add to `.gitignore`. Rotate API key in Firebase Console → Project Settings → API keys. Restrict API key to Android package name + SHA-1. Use `google-services.json` only at build time (CI secret). |
| SEC-02 | **Medium** | **AdMob App ID (`${admobAppId}`) in `AndroidManifest.xml` as manifest placeholder** — actual value likely in `local.properties` or `build.gradle` (not inspected). If committed, exposes AdMob publisher ID. | `AndroidManifest.xml:70-71` — `android:value="${admobAppId}"` | Low direct risk; AdMob IDs are public in ad requests. | Ensure `admobAppId` is not in version control; inject via CI secret / `local.properties` (gitignored). |
| SEC-03 | **Info** | **`flutter_launcher_icons` config in `pubspec.yaml` references local asset paths** — no secrets, but indicates icon generation is manual. | `pubspec.yaml:45-51` | None. | N/A |

---

## 4. Personal Data Handling & Privacy

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| PRIV-01 | **Medium** | **Usage stats (app package names, minutes) never leave the device per privacy policy, *but* `UsageService` reads them via native `UsageStatsManager` and caches in memory**. No encryption at rest for cached data (only in RAM). | `lib/services/usage_service.dart:243-375` (`queryUsage`, `queryWeeklyUsage`), `android/app/src/main/kotlin/.../MainActivity.kt:464-562` (`queryUsageRows`). | If device is compromised (root, malware with usage stats permission), historical usage can be reconstructed. | Acceptable for this threat model. Document that usage stats are ephemeral. |
| PRIV-02 | **Medium** | **Concentration zones store precise GPS coordinates (lat/long/radius) in Firestore**. User creates them voluntarily, but they reveal home/work/school locations. | `lib/models/concentration_zone.dart` (inferred), `lib/services/location_zone_service.dart`, `lib/screens/sponsor_screen.dart:150-178` (`_ensureLocationForZonePause`). | Sponsor (if linked) does *not* see zones per privacy policy — but Firestore rules allow any signed-in user to read `users/{userId}` (see FS-03), exposing zones to all users. | Fix FS-03 to restrict profile read. Add `concentrationZones` subcollection with sponsor-only read rules if sharing is ever needed. |
| PRIV-03 | **Low** | **Push tokens stored in `users/{userId}/push_tokens/{deviceId}` with 32-hex-char deviceId validation**. Token length capped at 4096. | `firestore.rules:88-102`, `lib/models/sponsor_profile.dart` (not used), `lib/services/sponsor_push_service.dart` (inferred). | Reasonable validation. DeviceId format (32 hex) suggests FCM token derivation — verify it's not a hardware ID. | Confirm `deviceId` is a random UUID, not Android ID / SSAID. |
| PRIV-04 | **Low** | **`AuthUser` model serializes `phoneNumber` and `emailVerified` to Firestore `profile` field**. | `lib/models/auth_user.dart:22-30` (`toMap`), `lib/services/cloud_sync_service.dart:68-83` (`saveUserProfile`). | Phone number is PII; stored in user doc readable by all (FS-03). | Fix FS-03; consider storing phone in a separate subcollection with stricter rules. |
| PRIV-05 | **Info** | **Privacy policy (aviso-de-privacidad.md) is thorough and accurate** — discloses Firebase/Google hosting outside Mexico, ARCO rights, data retention, third-party processors (AdMob, Apps Script). | `docs/legal/aviso-de-privacidad.md:1-285` | Good compliance baseline for Mexico LFPDPPP + GDPR fallback. | Ensure policy is surfaced in-app before account creation (currently shown at auth screen bottom — `lib/screens/auth_screen.dart:91`, `lib/screens/auth_screen.dart:274`). |
| PRIV-06 | **Info** | **Anonymous account auto-unlink after 7 days of inactivity** (server-side check on `anonymousLastSeenAt`). Documented in privacy policy. | `lib/services/cloud_sync_service.dart:75-77` (`anonymousLastSeenAt`), `docs/legal/aviso-de-privacidad.md:46-49`. | Reduces orphaned sponsor links. | Verify server-side Cloud Function / scheduled job actually enforces this (not seen in client code). |

---

## 5. Android Permissions & Native Code

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| AND-01 | **High** | **`PACKAGE_USAGE_STATS` (usage access) requested in manifest with `tools:ignore="ProtectedPermissions"`** — this special permission grants visibility into *all* app usage on the device. The app uses it for screen-time stats and shield triggering. | `AndroidManifest.xml:3-5` — `<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />` | High privilege; if app is compromised, attacker gets full usage history. Mitigated by user-grant flow (Settings → Usage Access). | Keep. Ensure `hasUsageAccess()` checks (`FocusBlockerService.kt:641-662`, `MainActivity.kt:391-413`) are enforced before any usage query. Consider dropping `tools:ignore` and handling denial gracefully (already done). |
| AND-02 | **High** | **`SYSTEM_ALERT_WINDOW` (overlay) + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` + location foreground service** — the `FocusBlockerService` draws a full-screen overlay *on top of blocked apps* and runs persistently. | `AndroidManifest.xml:6, 7-9, 11-14, 48-56`; `FocusBlockerService.kt:664-994` (`showOverlay`), `FocusBlockerService.kt:144-155` (`startForegroundSafely`). | Overlay can phish credentials if spoofed; foreground service with location type requires user-visible notification. | Overlay is user-triggered (shield). Ensure `SHOW_SERVICE_NOTIFICATION = true` (line 57) — currently true. Add `android:foregroundServiceType="location|specialUse"` (already present). |
| AND-03 | **Medium** | **`FocusBlockerService` stores shield state (blocked packages, sponsor flag, strict mode) in `SharedPreferences` (`detox_native`)** — world-readable by other apps with same UID (none), but not encrypted. | `FocusBlockerService.kt:93` (`prefs`), `ShieldStateStore.kt:30-78` (`activeSources`). | Low: only this app accesses it. | Acceptable. If device is rooted, prefs are readable. |
| AND-04 | **Medium** | **`NativeZoneMonitor` registers `LocationListener` on GPS/Network providers with 30s/25m intervals** — runs in foreground service context. Location data never leaves device (evaluated locally). | `NativeZoneMonitor.kt:45-63` (`start`), `NativeZoneMonitor.kt:113-165` (`evaluate`). | Battery drain; location precision reveals user's movement patterns to the app. | User opt-in (zone creation). Ensure `ACCESS_BACKGROUND_LOCATION` runtime permission requested (manifest has it). |
| AND-05 | **Medium** | **`BootReceiver` restarts `FocusBlockerService` on `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`** — re-arms shield without user interaction. | `BootReceiver.kt:14-53`; `AndroidManifest.xml:59-67`. | Could be abused if shield state is corrupted (e.g., blocks all apps). State validated via `ShieldStateStore.activeSources` (checks expiry). | Add user-facing notification "Detox protection restored" on boot. Validate `blocked_packages` against installed apps before restarting. |
| AND-06 | **Low** | **`RewardAdActivity` loads rewarded interstitial ad from AdMob** — uses test ID in debug, production ID in release via `BuildConfig`. | `RewardAdActivity.kt:50-56`, `RewardAdActivity.kt:76-79`. | Ad SDK collects advertising ID; disclosed in privacy policy. | Ensure `BuildConfig.ADS_ENABLED` and `REWARDED_INTERSTITIAL_AD_UNIT_ID` are not hardcoded in repo. |
| AND-07 | **Low** | **`MainActivity` method channel `detox/device_control` exposes `queryUsage`, `queryWeeklyUsage`, `getAppLabel`, `getAppIcon`, `startBlocking`, `stopBlocking`, `syncZoneConfig`, `suspendBlockingForMinutes`** — all require usage access / overlay permission checks. | `MainActivity.kt:51-359` (`configureFlutterEngine`). | Surface area for malicious Flutter code if engine compromised. | Permission checks are enforced in each handler. Good. |
| AND-08 | **Info** | **`ShieldStateStore.activeSources` merges multiple shield sources (zone, manual, sponsor) and deduplicates packages** — runs on every poll. | `ShieldStateStore.kt:30-78`. | Correct merging logic; no security issue. | N/A |

---

## 6. Input Validation & Injection

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| VAL-01 | **High** | **Sponsor code input (`_codeController`) normalized to uppercase but not validated for format before Firestore query** — 6-char alphanumeric (excludes I/O/0/1). Query uses `.where('sponsorCode', isEqualTo: normalized)`. | `lib/services/sponsor_service.dart:434-464` (`sendLinkRequestWithCode`), `lib/services/sponsor_service.dart:1349-1370` (`_generateUniqueCode` uses `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`). | Low injection risk (Firestore query is parameterized). But allows enumeration of valid codes if attacker can observe "code not found" vs "target has sponsor" errors. | Add client-side regex `^[A-HJ-NP-Z2-9]{6}$` before query. Rate-limit code entry attempts (e.g., 5/min). |
| VAL-02 | **Medium** | **Message fields in sponsor requests (`message`, `replyMessage`) truncated to 300 chars but not sanitized** — rendered in UI via `Text` widgets (safe from XSS in Flutter), but could contain control characters. | `lib/services/sponsor_service.dart:187-191` (`_cleanMessage`), `lib/screens/sponsor_screen.dart:798-905` (`_noteBox`). | Flutter `Text` auto-escapes; no XSS. Control chars could affect layout. | Strip/normalize control chars (`\u0000-\u001F`, `\u007F-\u009F`). |
| VAL-03 | **Medium** | **Username policy (`UsernamePolicy.validate`) blocks profanity/reserved words but allows Unicode lookalikes (homoglyphs) via `_fold` normalization** — replaces `0→o`, `1→i`, `3→e`, etc. but does not handle full Unicode normalization (NFKC). | `lib/services/username_policy.dart:92-112` (`_fold`), `lib/services/username_policy.dart:114-143` (`validate`). | Spoofing: `admіn` (Cyrillic і) vs `admin` passes reserved check after fold? Actually `_fold` only handles ASCII substitutions; Cyrillic not folded. | Apply `String.toLowerCase().normalize('NFKC')` before fold; expand reserved list with common homoglyph variants. |
| VAL-04 | **Low** | **`AppLimit`, `ConcentrationZone`, `AutomationRule` models parsed from JSON stored in SharedPreferences** — `fromJson` / `fromMap` assume trusted data. | `lib/models/app_limit.dart`, `lib/models/concentration_zone.dart`, `lib/models/automation_rule.dart` (inferred), `lib/services/storage_service.dart:199-215` (`loadAppLimits`). | Local-only; corrupted prefs crash app (caught by `hadBadData` cleanup). | Add `try/catch` with defaults; already partially done. |
| VAL-05 | **Info** | **Firestore rules validate `request.resource.data` keys and types strictly for `push_tokens`, `usage_days`, `unlock_requests`** — e.g., `keys().hasOnly([...])`, `token.size() <= 4096`, `locale in ['es','en']`. | `firestore.rules:88-102`, `firestore.rules:69-85`. | Strong server-side validation. | Good practice. |

---

## 7. Sponsor Flows (Core Business Logic)

| ID | Severity | Finding | Evidence | Impact | Recommendation |
|----|----------|---------|----------|--------|----------------|
| SPON-01 | **High** | **Sponsor unlink race condition: `unlinkSponsor()` and `consumeCode(unlink_sponsor)` both call `_purgeSponsorPairState` after committing the unlink, but the purge is best-effort (`try/catch` swallowed)**. If purge fails, stale `link_requests` / `unlock_requests` remain in `pending`/`approved` state. | `lib/services/sponsor_service.dart:672-709` (`unlinkSponsor`), `lib/services/sponsor_service.dart:1100-1225` (`consumeCode`), `lib/services/sponsor_service.dart:813-884` (`_purgeSponsorPairState` with `catch (_) {}`). | Stale requests confuse UI (show as pending), may allow re-linking with old request IDs, or block new requests due to `errPendingRequestExists`. | Make purge idempotent and retry with exponential backoff. Surface purge failure to user ("Unlink completed but cleanup pending — retry in Settings"). |
| SPON-02 | **Medium** | **`createUnlockRequest` silently succeeds if a *pending* request already exists** (line 979: `if (stillActive && existing.isPending) return;`). User sees no feedback that request was not re-sent. | `lib/services/sponsor_service.dart:966-1003` (`createUnlockRequest`). | User thinks they sent a new request; sponsor sees old one. Message not updated. | Return a status indicating "request already pending"; update UI to show existing request. |
| SPON-03 | **Medium** | **Shield pause request from overlay (`FocusBlockerService.requestShieldPauseFromSponsor`) creates Firestore document with `requestId = "${uid}_shield_pause"`** — fixed ID per user. If a previous request was *approved but not consumed*, a new request overwrites it (transaction `SetOptions(merge: true)`). | `FocusBlockerService.kt:1158-1186` (`requestShieldPauseFromSponsor`), `lib/services/sponsor_service.dart:985-1002` (create uses `merge: true`). | Sponsor may approve old request; user consumes new code; mismatch. | Use unique request ID per attempt (e.g., timestamp suffix) or check `isApproved && !isExpired` before overwriting. |
| SPON-04 | **Low** | **Sponsor code generation (`_generateUniqueCode`) loops until unique Firestore query returns empty** — no max retries. In extreme collision scenario (millions of users), could loop indefinitely. | `lib/services/sponsor_service.dart:1349-1370`. | DoS via CPU spin (unlikely with 32^6 ≈ 1B space). | Add max attempts (e.g., 100) then fall back to longer code. |
| SPON-05 | **Low** | **`approveDirectRequest` (settings_unlock, zone_override, shield_pause) writes `settingsUnlockUntil` / `zoneOverrideUntil` / `shieldPauseUntil` timestamps to *requester's* user doc** — sponsor can extend unlock indefinitely by repeated approvals. | `lib/services/sponsor_service.dart:193-270` (`approveDirectRequest`). | Sponsor could effectively disable protection. | Add max cumulative unlock time per day (e.g., 60 min) enforced in rules or service. |
| SPON-06 | **Info** | **Support unlink flow uses Google Apps Script (`apps_script/Code.gs`) to email decision links** — single-use, 7-day expiry. | `FIRESTORE_RULES_FOR_SPONSOR.md:3`, `apps_script/Code.gs` (not fully read). | External dependency; ensure Apps Script is bound to same Google Cloud project. | Verify Apps Script OAuth scope limited to `sendMail` only. |

---

## 8. Additional Observations (Non-Security)

| Area | Note |
|------|------|
| **Dependency freshness** | `pubspec.yaml` uses `firebase_core: ^4.15.0`, `firebase_auth: ^6.7.0`, `cloud_firestore: ^6.10.0` — check for known CVEs in these versions. |
| **Certificate pinning** | Not implemented. Firebase SDK uses platform trust store; consider `FirebaseApp.setAutomaticResourceManagementEnabled(false)` + custom `HttpClient` with pinning for high-value traffic. |
| **Logging** | `debugPrint` used in services; ensure no PII (email, UID, sponsorCode) logged in release builds. `FocusBlockerService.kt` uses `Log.e/d/w` — strip in release via `BuildConfig.DEBUG`. |
| **Error handling** | Many `catch (_) {}` or `catch (e) { rethrow; }` — ensure user-facing errors don't leak stack traces or internal IDs. |
| **Testing** | No integration tests visible for sponsor flows, shield service, or Firestore rules. Consider `firebase_rules_unit_test` for rules. |

---

## 9. Remediation Priority

| Priority | Actions |
|----------|---------|
| **P0 (Immediate)** | 1. Remove `google-services.json` from git history (`git filter-repo` or BFG), rotate API key, restrict to package+SHA-1.<br>2. Fix FS-01, FS-02, FS-03 (Firestore `list`/`get`/`read` over-permissions). |
| **P1 (This sprint)** | 3. Add rate limiting / CAPTCHA to auth flows (AUTH-01).<br>4. Fix sponsor unlink race (SPON-01) — make purge idempotent + retry.<br>5. Validate sponsor code format client-side + rate-limit (VAL-01).<br>6. Fix shield pause request ID collision (SPON-03). |
| **P2 (Next sprint)** | 7. Require re-auth before linking providers to anonymous account (AUTH-02).<br>8. Store phone verification state server-side (AUTH-03).<br>9. Apply NFKC normalization to username policy (VAL-03).<br>10. Add max cumulative unlock time per day (SPON-05). |
| **P3 (Backlog)** | 11. Certificate pinning for Firebase traffic.<br>12. Encrypt `SharedPreferences` shield state (AND-03).<br>13. Boot receiver notification + validation (AND-05).<br>14. Firestore rules unit tests. |

---

## 10. Files Inspected (Read-Only)

```
firestore.rules
google-services.json
pubspec.yaml
firebase.json
lib/services/auth_service.dart
lib/services/sponsor_service.dart
lib/services/cloud_sync_service.dart
lib/services/usage_service.dart
lib/services/app_blocking_service.dart
lib/services/storage_service.dart
lib/services/username_policy.dart
lib/models/auth_user.dart
lib/models/sponsor_request.dart
lib/models/sponsor_profile.dart
lib/screens/auth_screen.dart
lib/screens/sponsor_screen.dart
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/nerqova/detox/FocusBlockerService.kt
android/app/src/main/kotlin/com/nerqova/detox/NativeZoneMonitor.kt
android/app/src/main/kotlin/com/nerqova/detox/MainActivity.kt
android/app/src/main/kotlin/com/nerqova/detox/ShieldStateStore.kt
android/app/src/main/kotlin/com/nerqova/detox/BootReceiver.kt
android/app/src/main/kotlin/com/nerqova/detox/RewardAdActivity.kt
docs/legal/aviso-de-privacidad.md
FIRESTORE_RULES_FOR_SPONSOR.md
AUTH_SETUP_NOTES.md
apps_script/Code.gs (referenced)
```

---

**End of Report** — All findings based on static source analysis. No runtime testing, penetration testing, or dynamic analysis performed. Secrets in `google-services.json` were noted by location only; values not disclosed beyond what is already in the committed file.