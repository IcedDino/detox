# Protection Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make active blocking understandable, keep zone behavior correct across process and device transitions, deliver sponsor alerts when Detox is closed, and verify those flows.

**Architecture:** Read the native shield's persisted source list for a user-facing protection status screen. Keep zone state owned by one monitor with explicit recovery behavior. Send sponsor events from Firebase to device tokens so alerts do not depend on an in-process Firestore listener.

**Tech Stack:** Flutter/Dart, Android/Kotlin, Firebase Firestore/FCM, Flutter tests, Android release tests.

**Spec:** User approved the five prioritized improvements in the preceding conversation. Zone behavior after closing Detox and Firebase server availability are pending the two requested clarifications.

## Global Constraints

- Keep existing local changes in `FocusBlockerService.kt` and the recent sponsor/zone fixes.
- Do not publish Firebase rules/functions or a Play release without a reviewable artifact.
- Preserve existing focus and automation blocks when a zone is disabled.

## Review Focus

- Two block sources cover the same app: status names both sources and disabling one retains the other.
- An expired source is never shown as active.
- Zone monitoring stops or continues after process death according to the chosen product behavior, without a stale block.
- A sponsor request resolves while the recipient app is terminated: one alert arrives and opens the relevant screen.
- Permission or location loss is shown as an actionable protection state.

## Tasks

### Task 1: Protection status

**Files:** `lib/services/app_blocking_service.dart`, `lib/screens/protection_status_screen.dart`, `lib/screens/settings_screen.dart`, `test/protection_status_test.dart`.

- [ ] Add a failing test for parsing independent native shield sources and filtering expired sources.
- [ ] Add a read-only `getActiveSources()` API and prove the test passes.
- [ ] Add a Settings entry and screen with sources, affected apps, zone state, permissions, loading and retry.
- [ ] Run focused tests and analyzer.

### Task 2: Zone lifecycle

**Files:** `lib/services/location_zone_service.dart`, Android native service/receiver as needed, focused tests.

- [ ] Write a failing test for the chosen close/reboot behavior.
- [ ] Implement reconciliation without clearing focus or automation sources.
- [ ] Verify on both Android devices when available.

### Task 3: Sponsor delivery

**Files:** Firebase server code/config, client token registration and notification navigation, focused tests.

- [ ] Add a failing event-routing test covering request and accepted/rejected transitions.
- [ ] Implement server send, own-device token storage, token rotation/cleanup, and notification navigation.
- [ ] Verify foreground/background/terminated cases; leave deployment for final review if authorization or infrastructure is missing.

### Task 4: Release checks and publication guide

**Files:** `docs/publicacion-google-play.md`, related tests and release artifact.

- [ ] Add a repeatable two-device scenario checklist for zone and sponsor flows.
- [ ] Correct the guide's location/foreground-service claim using current Google Play guidance.
- [ ] Run tests, analyzer and release build; record any limitations.
