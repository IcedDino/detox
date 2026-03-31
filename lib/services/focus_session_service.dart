import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_limit.dart';
import 'app_blocking_service.dart';
import 'automation_service.dart';
import 'focus_notification_service.dart';
import 'location_zone_service.dart';
import 'progress_service.dart';
import 'sponsor_service.dart';
import 'storage_service.dart';
import 'usage_service.dart';

class FocusSessionSnapshot {
  const FocusSessionSnapshot({
    required this.isActive,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.label,
    required this.reason,
  });

  final bool isActive;
  final int remainingSeconds;
  final int totalSeconds;
  final String label;
  final String reason;
}

class FocusStartResult {
  const FocusStartResult._(this.success, this.code);

  final bool success;
  final String code;

  static const ok = FocusStartResult._(true, 'ok');
  static const usagePermissionMissing = FocusStartResult._(false, 'usage_permission_missing');
  static const overlayPermissionMissing = FocusStartResult._(false, 'overlay_permission_missing');
  static const noAppsConfigured = FocusStartResult._(false, 'no_apps_configured');
}

class FocusSessionService {
  FocusSessionService._();
  static final FocusSessionService instance = FocusSessionService._();

  static const _endAtKey = 'focus_session_end_at_v1';
  static const _totalSecondsKey = 'focus_session_total_v1';
  static const _labelKey = 'focus_session_label_v1';
  static const _reasonKey = 'focus_session_reason_v1';

  final StorageService _storage = StorageService();
  final UsageService _usage = UsageService();
  final StreamController<FocusSessionSnapshot> _controller =
      StreamController<FocusSessionSnapshot>.broadcast();

  Timer? _timer;
  FocusSessionSnapshot _snapshot = const FocusSessionSnapshot(
    isActive: false,
    remainingSeconds: 0,
    totalSeconds: 0,
    label: '',
    reason: '',
  );

  Stream<FocusSessionSnapshot> get snapshots => _controller.stream;
  FocusSessionSnapshot get current => _snapshot;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEndAt = prefs.getString(_endAtKey);
    if (rawEndAt == null || rawEndAt.isEmpty) {
      _emitInactive();
      return;
    }

    final endAt = DateTime.tryParse(rawEndAt);
    if (endAt == null) {
      await _clearPersisted();
      _emitInactive();
      return;
    }

    final remaining = endAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      await _finishSession(expired: true);
      return;
    }

    _snapshot = FocusSessionSnapshot(
      isActive: true,
      remainingSeconds: remaining,
      totalSeconds: prefs.getInt(_totalSecondsKey) ?? remaining,
      label: prefs.getString(_labelKey) ?? 'Focus session',
      reason: prefs.getString(_reasonKey) ?? 'focus_session',
    );
    _controller.add(_snapshot);
    _startTicker(endAt);
  }

  Future<FocusStartResult> startSession({
    required int minutes,
    required String label,
    required String reason,
    bool fromSuggestion = false,
  }) async {
    final usageReady = (await _usage.getPermissionStatus()).usageReady;
    if (!usageReady) return FocusStartResult.usagePermissionMissing;

    final overlayReady = await AppBlockingService.instance.hasOverlayPermission();
    if (!overlayReady) return FocusStartResult.overlayPermissionMissing;

    final limits = await _storage.loadAppLimits();
    final packages = limits
        .where((AppLimit e) => e.useInFocusMode && (e.packageName?.isNotEmpty ?? false))
        .map((e) => e.packageName!)
        .toSet()
        .toList();

    if (packages.isEmpty) return FocusStartResult.noAppsConfigured;

    final hasSponsor = (await SponsorService.instance.getCurrentSponsorProfile()) != null;

    await AppBlockingService.instance.startShield(
      blockedPackages: packages,
      reason: reason,
      hasSponsor: hasSponsor,
    );

    if (fromSuggestion) {
      await ProgressService.instance.recordSuggestionAccepted();
    }
    await ProgressService.instance.recordFocusStarted();

    final totalSeconds = minutes * 60;
    final endAt = DateTime.now().add(Duration(seconds: totalSeconds));
    await _persistSession(
      endAt: endAt,
      totalSeconds: totalSeconds,
      label: label,
      reason: reason,
    );

    _snapshot = FocusSessionSnapshot(
      isActive: true,
      remainingSeconds: totalSeconds,
      totalSeconds: totalSeconds,
      label: label,
      reason: reason,
    );
    _controller.add(_snapshot);

    await FocusNotificationService.instance.showOrUpdateTimer(
      remainingSeconds: totalSeconds,
      label: label,
      force: true,
    );
    _startTicker(endAt);
    return FocusStartResult.ok;
  }

  Future<void> stopSession({bool countAsCompleted = false}) async {
    _timer?.cancel();
    _timer = null;
    await FocusNotificationService.instance.cancel();
    await _clearPersisted();
    await AppBlockingService.instance.stopShield();
    await LocationZoneService.instance.refresh();
    await AutomationService.instance.refresh();
    if (countAsCompleted) {
      await ProgressService.instance.recordFocusCompleted();
      await _storage.registerCompletedFocusSession();
    }
    _emitInactive();
  }

  void _startTicker(DateTime endAt) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = endAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _timer = null;
        await _finishSession(expired: true);
        return;
      }

      _snapshot = FocusSessionSnapshot(
        isActive: true,
        remainingSeconds: remaining,
        totalSeconds: _snapshot.totalSeconds,
        label: _snapshot.label,
        reason: _snapshot.reason,
      );
      _controller.add(_snapshot);
      await FocusNotificationService.instance.showOrUpdateTimer(
        remainingSeconds: remaining,
        label: _snapshot.label,
      );
    });
  }

  Future<void> _finishSession({required bool expired}) async {
    _timer?.cancel();
    _timer = null;
    await FocusNotificationService.instance.cancel();
    await _clearPersisted();
    await AppBlockingService.instance.stopShield();
    await LocationZoneService.instance.refresh();
    await AutomationService.instance.refresh();
    if (expired) {
      await ProgressService.instance.recordFocusCompleted();
      await _storage.registerCompletedFocusSession();
    }
    _emitInactive();
  }

  Future<void> _persistSession({
    required DateTime endAt,
    required int totalSeconds,
    required String label,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endAtKey, endAt.toIso8601String());
    await prefs.setInt(_totalSecondsKey, totalSeconds);
    await prefs.setString(_labelKey, label);
    await prefs.setString(_reasonKey, reason);
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_endAtKey);
    await prefs.remove(_totalSecondsKey);
    await prefs.remove(_labelKey);
    await prefs.remove(_reasonKey);
  }

  void _emitInactive() {
    _snapshot = const FocusSessionSnapshot(
      isActive: false,
      remainingSeconds: 0,
      totalSeconds: 0,
      label: '',
      reason: '',
    );
    _controller.add(_snapshot);
  }
}
