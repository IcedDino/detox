import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_limit.dart';
import '../models/automation_rule.dart';
import '../models/concentration_zone.dart';
import '../models/habit.dart';
import 'cloud_sync_service.dart';

class StorageService {
  static Future<void>? _bootstrapFuture;
  static String? _bootstrapUid;

  static const _habitsKey = 'habits_v2';
  static const _dailyLimitKey = 'daily_limit_minutes';
  static const _limitsKey = 'app_limits_v2';
  static const _onboardingDoneKey = 'onboarding_done_local_v2';
  static const _zonesKey = 'concentration_zones_v1';
  static const _automationRulesKey = 'automation_rules_v1';
  static const _strictModeKey = 'focus_strict_mode_v1';
  static const _focusStreakKey = 'focus_streak_v1';
  static const _focusLastCompletedAtKey = 'focus_last_completed_at_v1';

  static const _progressCurrentStreakKey = 'progress_current_streak_v1';
  static const _progressBestStreakKey = 'progress_best_streak_v1';
  static const _progressLastActiveDayKey = 'progress_last_active_day_v1';
  static const _progressStartedTodayKey = 'progress_started_today_v1';
  static const _suggestionsShownKey = 'progress_suggestions_shown_v1';
  static const _suggestionsAcceptedKey = 'progress_suggestions_accepted_v1';
  static const _suggestionsDeniedKey = 'progress_suggestions_denied_v1';
  static const _focusSessionsStartedKey = 'focus_sessions_started_v1';
  static const _focusSessionsCompletedKey = 'focus_sessions_completed_v1';
  static const _pauseRequestsKey = 'pause_requests_v1';
  static const _pauseApprovedKey = 'pause_approved_v1';
  static const _pauseRejectedKey = 'pause_rejected_v1';
  static const _pomodoroCyclesCompletedKey = 'pomodoro_cycles_completed_v1';


  Future<void> setStrictMode(bool value) => saveStrictMode(value);

  Future<bool> getStrictMode() => loadStrictMode();
  static final StorageService instance = StorageService._internal();
  factory StorageService() => instance;
  StorageService._internal();

  List<Habit> _defaultHabits() => [
    Habit(
      id: '1',
      title: 'No social media before breakfast',
      targetDescription: 'Start the day without mindless scrolling',
    ),
    Habit(
      id: '2',
      title: 'One 25-minute focus session',
      targetDescription: 'Finish one distraction-free session',
    ),
    Habit(
      id: '3',
      title: 'Keep screen time under 3 hours',
      targetDescription: 'Respect your daily limit',
    ),
  ];

  List<AppLimit> _defaultAppLimits() => [
    AppLimit(appName: 'Instagram', packageName: 'com.instagram.android', minutes: 30),
    AppLimit(appName: 'TikTok', packageName: 'com.zhiliaoapp.musically', minutes: 25),
    AppLimit(appName: 'YouTube', packageName: 'com.google.android.youtube', minutes: 45),
  ];

  Future<void> bootstrapForSignedInUser() async {
    final uid = CloudSyncService.instance.currentUid;
    if (uid == null) return;

    final inFlight = _bootstrapFuture;
    if (inFlight != null && _bootstrapUid == uid) {
      await inFlight;
      return;
    }

    final future = _bootstrapForSignedInUserInternal(uid);
    _bootstrapUid = uid;
    _bootstrapFuture = future;

    try {
      await future;
    } finally {
      if (identical(_bootstrapFuture, future)) {
        _bootstrapFuture = null;
      }
    }
  }

  Future<void> _bootstrapForSignedInUserInternal(String uid) async {
    if (CloudSyncService.instance.currentUid != uid) return;

    final prefs = await SharedPreferences.getInstance();
    final remote = await CloudSyncService.instance.loadSnapshot();
    if (CloudSyncService.instance.currentUid != uid) return;

    final remoteHabits = CloudSyncService.instance.habitsFromSnapshot(remote);
    final remoteDaily = CloudSyncService.instance.dailyLimitMinutesFromSnapshot(remote);
    final remoteLimits = CloudSyncService.instance.appLimitsFromSnapshot(remote);
    final remoteZones = CloudSyncService.instance.concentrationZonesFromSnapshot(remote);
    final remoteOnboarding = CloudSyncService.instance.onboardingDoneFromSnapshot(remote);
    final hasAnyRemoteData =
        remoteHabits != null ||
        remoteDaily != null ||
        remoteLimits != null ||
        remoteZones != null ||
        remoteOnboarding != null;

    if (hasAnyRemoteData) {
      if (remoteHabits != null) {
        await prefs.setStringList(
          _habitsKey,
          remoteHabits.map((e) => e.toJson()).toList(),
        );
      }

      if (remoteDaily != null) {
        await prefs.setInt(_dailyLimitKey, remoteDaily);
      }

      if (remoteLimits != null) {
        await prefs.setStringList(
          _limitsKey,
          remoteLimits.map((e) => e.toJson()).toList(),
        );
      }

      if (remoteZones != null) {
        await prefs.setStringList(
          _zonesKey,
          remoteZones.map((e) => e.toJson()).toList(),
        );
      }

      if (remoteOnboarding != null) {
        await prefs.setBool(_onboardingDoneKey, remoteOnboarding);
      }

      return;
    }

    final localHabitsRaw = prefs.getStringList(_habitsKey);
    final localLimitsRaw = prefs.getStringList(_limitsKey);
    final localZonesRaw = prefs.getStringList(_zonesKey);
    final hasLocalDaily = prefs.containsKey(_dailyLimitKey);
    final hasLocalOnboarding = prefs.containsKey(_onboardingDoneKey);

    final hasMeaningfulLocalData =
        (localHabitsRaw != null && localHabitsRaw.isNotEmpty) ||
        (localLimitsRaw != null && localLimitsRaw.isNotEmpty) ||
        (localZonesRaw != null && localZonesRaw.isNotEmpty) ||
        hasLocalDaily ||
        hasLocalOnboarding;

    if (!hasMeaningfulLocalData) {
      return;
    }

    final localHabits = await loadHabits();
    final localDaily = await loadDailyLimitMinutes();
    final localLimits = await loadAppLimits();
    final localZones = await loadConcentrationZones();
    final localOnboarding = await loadOnboardingDone();

    if (CloudSyncService.instance.currentUid != uid) return;

    await Future.wait<void>([
      CloudSyncService.instance.saveHabits(localHabits),
      CloudSyncService.instance.saveDailyLimitMinutes(localDaily),
      CloudSyncService.instance.saveAppLimits(localLimits),
      CloudSyncService.instance.saveConcentrationZones(localZones),
      CloudSyncService.instance.saveOnboardingDone(localOnboarding),
    ]);
  }

  Future<void> refreshFromCloud() async {
    if (!CloudSyncService.instance.isSignedIn) return;

    final prefs = await SharedPreferences.getInstance();
    final remote = await CloudSyncService.instance.loadSnapshot();
    final remoteHabits = CloudSyncService.instance.habitsFromSnapshot(remote);
    final remoteDaily = CloudSyncService.instance.dailyLimitMinutesFromSnapshot(remote);
    final remoteLimits = CloudSyncService.instance.appLimitsFromSnapshot(remote);
    final remoteZones = CloudSyncService.instance.concentrationZonesFromSnapshot(remote);
    final remoteOnboarding = CloudSyncService.instance.onboardingDoneFromSnapshot(remote);

    if (remoteHabits != null) {
      await prefs.setStringList(
        _habitsKey,
        remoteHabits.map((e) => e.toJson()).toList(),
      );
    }

    if (remoteDaily != null) {
      await prefs.setInt(_dailyLimitKey, remoteDaily);
    }

    if (remoteLimits != null) {
      await prefs.setStringList(
        _limitsKey,
        remoteLimits.map((e) => e.toJson()).toList(),
      );
    }

    if (remoteZones != null) {
      await prefs.setStringList(
        _zonesKey,
        remoteZones.map((e) => e.toJson()).toList(),
      );
    }

    if (remoteOnboarding != null) {
      await prefs.setBool(_onboardingDoneKey, remoteOnboarding);
    }
  }

  Future<List<Habit>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_habitsKey);
    if (raw == null || raw.isEmpty) return _defaultHabits();
    return raw.map(Habit.fromJson).toList();
  }

  Future<void> saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_habitsKey, habits.map((e) => e.toJson()).toList());
    try {
      await CloudSyncService.instance.saveHabits(habits);
    } catch (_) {}
  }

  Future<int> loadDailyLimitMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyLimitKey) ?? 180;
  }

  Future<void> saveDailyLimitMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyLimitKey, minutes);
    try {
      await CloudSyncService.instance.saveDailyLimitMinutes(minutes);
    } catch (_) {}
  }

  Future<List<AppLimit>> loadAppLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_limitsKey);
    if (raw == null || raw.isEmpty) return _defaultAppLimits();
    return raw.map(AppLimit.fromJson).toList();
  }

  Future<void> saveAppLimits(List<AppLimit> limits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_limitsKey, limits.map((e) => e.toJson()).toList());
    try {
      await CloudSyncService.instance.saveAppLimits(limits);
    } catch (_) {}
  }

  Future<List<ConcentrationZone>> loadConcentrationZones() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_zonesKey);
    if (raw == null || raw.isEmpty) return const [];

    final zones = <ConcentrationZone>[];
    var hadBadData = false;
    for (final item in raw) {
      try {
        zones.add(ConcentrationZone.fromJson(item));
      } catch (_) {
        hadBadData = true;
      }
    }
    if (hadBadData) {
      await prefs.setStringList(_zonesKey, zones.map((e) => e.toJson()).toList());
    }
    return zones;
  }

  Future<void> saveConcentrationZones(List<ConcentrationZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_zonesKey, zones.map((e) => e.toJson()).toList());
    try {
      await CloudSyncService.instance.saveConcentrationZones(zones);
    } catch (_) {}
  }

  Future<List<AutomationRule>> loadAutomationRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_automationRulesKey);
    if (raw == null || raw.isEmpty) return const [];
    return raw.map(AutomationRule.fromJson).toList();
  }

  Future<void> saveAutomationRules(List<AutomationRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_automationRulesKey, rules.map((e) => e.toJson()).toList());
  }

  Future<bool> loadStrictMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_strictModeKey) ?? false;
  }

  Future<void> saveStrictMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_strictModeKey, value);
  }

  Future<bool> loadStrictModeEnabled() => loadStrictMode();

  Future<void> saveStrictModeEnabled(bool value) => saveStrictMode(value);

  Future<int> loadFocusStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_focusStreakKey) ?? 0;
  }

  Future<DateTime?> loadLastFocusCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_focusLastCompletedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<int> registerCompletedFocusSession() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rawLast = prefs.getString(_focusLastCompletedAtKey);
    final last = rawLast == null ? null : DateTime.tryParse(rawLast);
    final lastDay = last == null ? null : DateTime(last.year, last.month, last.day);
    var streak = prefs.getInt(_focusStreakKey) ?? 0;

    if (lastDay == null) {
      streak = 1;
    } else {
      final diff = today.difference(lastDay).inDays;
      if (diff <= 0) {
        return streak;
      }
      if (diff == 1) {
        streak += 1;
      } else {
        streak = 1;
      }
    }

    await prefs.setInt(_focusStreakKey, streak);
    await prefs.setString(_focusLastCompletedAtKey, now.toIso8601String());
    await prefs.setInt(_focusSessionsCompletedKey, (prefs.getInt(_focusSessionsCompletedKey) ?? 0) + 1);
    return streak;
  }



  String _dayToken([DateTime? now]) {
    final value = now ?? DateTime.now();
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<bool> isProgressStartedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_progressStartedTodayKey) == _dayToken();
  }

  Future<int> markProgressStartedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayToken();
    final startedToday = prefs.getString(_progressStartedTodayKey);
    if (startedToday == today) {
      return prefs.getInt(_progressCurrentStreakKey) ?? 0;
    }

    final lastActive = prefs.getString(_progressLastActiveDayKey);
    var current = prefs.getInt(_progressCurrentStreakKey) ?? 0;
    if (lastActive == null) {
      current = 1;
    } else {
      final prev = DateTime.tryParse(lastActive);
      final now = DateTime.now();
      if (prev == null) {
        current = 1;
      } else {
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(prev.year, prev.month, prev.day))
            .inDays;
        if (diff <= 0) {
          current = current == 0 ? 1 : current;
        } else if (diff == 1) {
          current = current + 1;
        } else {
          current = 1;
        }
      }
    }
    final best = (prefs.getInt(_progressBestStreakKey) ?? 0) < current
        ? current
        : (prefs.getInt(_progressBestStreakKey) ?? 0);
    await prefs.setString(_progressStartedTodayKey, today);
    await prefs.setString(_progressLastActiveDayKey, DateTime.now().toIso8601String());
    await prefs.setInt(_progressCurrentStreakKey, current);
    await prefs.setInt(_progressBestStreakKey, best);
    return current;
  }

  Future<int> loadCurrentProgressStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_progressCurrentStreakKey) ?? 0;
  }

  Future<int> loadBestProgressStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_progressBestStreakKey) ?? 0;
  }

  Future<void> incrementSuggestionsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_suggestionsShownKey, (prefs.getInt(_suggestionsShownKey) ?? 0) + 1);
  }

  Future<void> incrementSuggestionsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_suggestionsAcceptedKey, (prefs.getInt(_suggestionsAcceptedKey) ?? 0) + 1);
  }

  Future<void> incrementSuggestionsDenied() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_suggestionsDeniedKey, (prefs.getInt(_suggestionsDeniedKey) ?? 0) + 1);
  }

  Future<void> incrementFocusSessionsStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_focusSessionsStartedKey, (prefs.getInt(_focusSessionsStartedKey) ?? 0) + 1);
  }

  Future<void> incrementPauseRequests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseRequestsKey, (prefs.getInt(_pauseRequestsKey) ?? 0) + 1);
  }

  Future<void> incrementPauseApproved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseApprovedKey, (prefs.getInt(_pauseApprovedKey) ?? 0) + 1);
  }

  Future<void> incrementPauseRejected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseRejectedKey, (prefs.getInt(_pauseRejectedKey) ?? 0) + 1);
  }

  Future<void> incrementPomodoroCyclesCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pomodoroCyclesCompletedKey, (prefs.getInt(_pomodoroCyclesCompletedKey) ?? 0) + 1);
  }

  Future<Map<String, int>> loadProgressCounters() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'currentStreak': prefs.getInt(_progressCurrentStreakKey) ?? 0,
      'bestStreak': prefs.getInt(_progressBestStreakKey) ?? 0,
      'suggestionsShown': prefs.getInt(_suggestionsShownKey) ?? 0,
      'suggestionsAccepted': prefs.getInt(_suggestionsAcceptedKey) ?? 0,
      'suggestionsDenied': prefs.getInt(_suggestionsDeniedKey) ?? 0,
      'focusStarted': prefs.getInt(_focusSessionsStartedKey) ?? 0,
      'focusCompleted': prefs.getInt(_focusSessionsCompletedKey) ?? 0,
      'pauseRequests': prefs.getInt(_pauseRequestsKey) ?? 0,
      'pauseApproved': prefs.getInt(_pauseApprovedKey) ?? 0,
      'pauseRejected': prefs.getInt(_pauseRejectedKey) ?? 0,
      'pomodoroCyclesCompleted': prefs.getInt(_pomodoroCyclesCompletedKey) ?? 0,
    };
  }


  Future<void> clearLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode');
    final localeCode = prefs.getString('locale_code');

    await prefs.clear();

    if (darkMode != null) {
      await prefs.setBool('dark_mode', darkMode);
    }
    if (localeCode != null && localeCode.isNotEmpty) {
      await prefs.setString('locale_code', localeCode);
    }
  }

  Future<bool> loadOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> saveOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, value);
    try {
      await CloudSyncService.instance.saveOnboardingDone(value);
    } catch (_) {}
  }
}
