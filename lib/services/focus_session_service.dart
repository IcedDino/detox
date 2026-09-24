import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_blocking_service.dart';
import 'automation_service.dart';
import 'sponsor_service.dart';
import 'storage_service.dart';

class FocusSessionSnapshot {
  const FocusSessionSnapshot({
    required this.isActive,
    required this.isPomodoro,
    required this.isBreak,
    required this.endsAt,
    required this.minutes,
    required this.label,
    required this.currentCycle,
    required this.totalCycles,
    required this.breakMinutes,
    required this.source,
  });

  final bool isActive;
  final bool isPomodoro;
  final bool isBreak;
  final DateTime? endsAt;
  final int minutes;
  final String label;
  final int currentCycle;
  final int totalCycles;
  final int breakMinutes;
  final String source;

  int get remainingSeconds {
    final end = endsAt;
    if (!isActive || end == null) return 0;
    final diff = end.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }
}

class FocusSessionService {
  FocusSessionService._();
  static final FocusSessionService instance = FocusSessionService._();

  static const _activeKey = 'focus_session_active_v2';
  static const _endsAtKey = 'focus_session_ends_at_v2';
  static const _minutesKey = 'focus_session_minutes_v2';
  static const _labelKey = 'focus_session_label_v2';
  static const _isPomodoroKey = 'focus_session_is_pomodoro_v2';
  static const _isBreakKey = 'focus_session_is_break_v2';
  static const _cycleKey = 'focus_session_cycle_v2';
  static const _cyclesTotalKey = 'focus_session_cycles_total_v2';
  static const _breakMinutesKey = 'focus_session_break_minutes_v2';
  static const _sourceKey = 'focus_session_source_v2';

  final StorageService _storage = StorageService();

  Future<FocusSessionSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_activeKey) ?? false;
    final endsAt = DateTime.tryParse(prefs.getString(_endsAtKey) ?? '');
    final snap = FocusSessionSnapshot(
      isActive: active,
      isPomodoro: prefs.getBool(_isPomodoroKey) ?? false,
      isBreak: prefs.getBool(_isBreakKey) ?? false,
      endsAt: endsAt,
      minutes: prefs.getInt(_minutesKey) ?? 0,
      label: prefs.getString(_labelKey) ?? 'Focus',
      currentCycle: prefs.getInt(_cycleKey) ?? 1,
      totalCycles: prefs.getInt(_cyclesTotalKey) ?? 1,
      breakMinutes: prefs.getInt(_breakMinutesKey) ?? 5,
      source: prefs.getString(_sourceKey) ?? 'focus',
    );
    if (snap.isActive && snap.remainingSeconds == 0) {
      return tickAndAdvance();
    }
    return snap;
  }

  Future<List<String>> _loadShieldPackages() async {
    final limits = await _storage.loadAppLimits();
    return limits
        .where((e) => e.useInFocusMode && (e.packageName ?? '').isNotEmpty)
        .map((e) => e.packageName!)
        .toSet()
        .toList();
  }

  Future<void> restoreActiveShield() async {
    final snapshot = await loadSnapshot();
    if (!snapshot.isActive) return;
    if (snapshot.isBreak) {
      await AppBlockingService.instance.stopShield(source: snapshot.source);
      return;
    }
    final smartPackage = snapshot.source.startsWith('smart_break_')
        ? snapshot.source.substring('smart_break_'.length)
        : null;
    final packages = smartPackage == null
        ? await _loadShieldPackages()
        : <String>[smartPackage];
    if (packages.isEmpty) return;
    final hasSponsor = await SponsorService.instance.hasSponsor();
    await AppBlockingService.instance.startShield(
      blockedPackages: packages,
      reason: smartPackage != null
          ? 'smart_break'
          : snapshot.isPomodoro
              ? 'pomodoro_work'
              : 'focus_session',
      hasSponsor: hasSponsor,
      source: snapshot.source,
      expiresAt: snapshot.endsAt,
    );
  }

  Future<void> startQuickFocusHour() =>
      startFocus(minutes: 60, label: 'Focus hour');

  Future<void> startFocus(
      {required int minutes, String label = 'Focus session'}) async {
    final prefs = await SharedPreferences.getInstance();
    final packages = await _loadShieldPackages();
    final hasSponsor = await SponsorService.instance.hasSponsor();
    await _storage.incrementFocusSessionsStarted();
    await _storage.markProgressStartedToday();

    await prefs.setBool(_activeKey, true);
    final endsAt = DateTime.now().add(Duration(minutes: minutes));
    await prefs.setString(_endsAtKey, endsAt.toIso8601String());
    await prefs.setInt(_minutesKey, minutes);
    await prefs.setString(_labelKey, label);
    await prefs.setBool(_isPomodoroKey, false);
    await prefs.setBool(_isBreakKey, false);
    await prefs.setInt(_cycleKey, 1);
    await prefs.setInt(_cyclesTotalKey, 1);
    await prefs.setInt(_breakMinutesKey, 5);
    await prefs.setString(_sourceKey, 'focus');

    if (packages.isNotEmpty) {
      await AppBlockingService.instance.startShield(
        blockedPackages: packages,
        reason: 'focus_session',
        hasSponsor: hasSponsor,
        source: 'focus',
        expiresAt: endsAt,
      );
    }
  }

  Future<void> startPomodoro(
      {int workMinutes = 25, int breakMinutes = 5, int cycles = 4}) async {
    final prefs = await SharedPreferences.getInstance();
    final packages = await _loadShieldPackages();
    final hasSponsor = await SponsorService.instance.hasSponsor();
    await _storage.incrementFocusSessionsStarted();
    await _storage.markProgressStartedToday();

    await prefs.setBool(_activeKey, true);
    final endsAt = DateTime.now().add(Duration(minutes: workMinutes));
    await prefs.setString(_endsAtKey, endsAt.toIso8601String());
    await prefs.setInt(_minutesKey, workMinutes);
    await prefs.setString(_labelKey, 'Pomodoro');
    await prefs.setBool(_isPomodoroKey, true);
    await prefs.setBool(_isBreakKey, false);
    await prefs.setInt(_cycleKey, 1);
    await prefs.setInt(_cyclesTotalKey, cycles);
    await prefs.setInt(_breakMinutesKey, breakMinutes);
    await prefs.setString(_sourceKey, 'focus');

    if (packages.isNotEmpty) {
      await AppBlockingService.instance.startShield(
        blockedPackages: packages,
        reason: 'pomodoro_work',
        hasSponsor: hasSponsor,
        source: 'focus',
        expiresAt: endsAt,
      );
    }
  }

  Future<void> startSmartSuggestionBreak({
    required String packageName,
    required String appName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSponsor = await SponsorService.instance.hasSponsor();
    final source = 'smart_break_$packageName';

    await _storage.incrementFocusSessionsStarted();
    await _storage.markProgressStartedToday();

    await prefs.setBool(_activeKey, true);
    final endsAt = DateTime.now().add(const Duration(hours: 1));
    await prefs.setString(
      _endsAtKey,
      endsAt.toIso8601String(),
    );
    await prefs.setInt(_minutesKey, 60);
    await prefs.setString(_labelKey, 'Break from $appName');
    await prefs.setBool(_isPomodoroKey, false);
    await prefs.setBool(_isBreakKey, false);
    await prefs.setInt(_cycleKey, 1);
    await prefs.setInt(_cyclesTotalKey, 1);
    await prefs.setInt(_breakMinutesKey, 5);
    await prefs.setString(_sourceKey, source);

    await AppBlockingService.instance.startShield(
      blockedPackages: <String>[packageName],
      reason: 'smart_break',
      hasSponsor: hasSponsor,
      source: source,
      expiresAt: endsAt,
    );
  }

  Future<FocusSessionSnapshot> tickAndAdvance() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_activeKey) ?? false;
    if (!active) return loadSnapshot();
    final isPomodoro = prefs.getBool(_isPomodoroKey) ?? false;
    final isBreak = prefs.getBool(_isBreakKey) ?? false;
    final cycle = prefs.getInt(_cycleKey) ?? 1;
    final total = prefs.getInt(_cyclesTotalKey) ?? 1;
    final breakMinutes = prefs.getInt(_breakMinutesKey) ?? 5;
    final workMinutes = prefs.getInt(_minutesKey) ?? 25;

    if (!isPomodoro) {
      await stopSession(markCompleted: true);
      return loadSnapshot();
    }

    if (!isBreak) {
      await _storage.incrementPomodoroCyclesCompleted();
      if (cycle >= total) {
        await stopSession(markCompleted: true);
        return loadSnapshot();
      }
      await prefs.setBool(_isBreakKey, true);
      await prefs.setString(
          _endsAtKey,
          DateTime.now()
              .add(Duration(minutes: breakMinutes))
              .toIso8601String());
      await AppBlockingService.instance.stopShield(source: 'focus');
      return loadSnapshot();
    }

    final packages = await _loadShieldPackages();
    final hasSponsor = await SponsorService.instance.hasSponsor();
    await prefs.setBool(_isBreakKey, false);
    await prefs.setInt(_cycleKey, cycle + 1);
    final endsAt = DateTime.now().add(Duration(minutes: workMinutes));
    await prefs.setString(_endsAtKey, endsAt.toIso8601String());
    if (packages.isNotEmpty) {
      await AppBlockingService.instance.startShield(
        blockedPackages: packages,
        reason: 'pomodoro_work',
        hasSponsor: hasSponsor,
        source: 'focus',
        expiresAt: endsAt,
      );
    }
    return loadSnapshot();
  }

  Future<void> stopSession({bool markCompleted = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_sourceKey) ?? 'focus';
    await prefs.remove(_activeKey);
    await prefs.remove(_endsAtKey);
    await prefs.remove(_minutesKey);
    await prefs.remove(_labelKey);
    await prefs.remove(_isPomodoroKey);
    await prefs.remove(_isBreakKey);
    await prefs.remove(_cycleKey);
    await prefs.remove(_cyclesTotalKey);
    await prefs.remove(_breakMinutesKey);
    await prefs.remove(_sourceKey);
    await AppBlockingService.instance.stopShield(source: source);
    if (markCompleted) {
      await _storage.registerCompletedFocusSession();
    }
    await AutomationService.instance.refresh();
  }
}
