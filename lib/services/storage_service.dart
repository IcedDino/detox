import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_limit.dart';
import '../models/concentration_zone.dart';
import '../models/habit.dart';
import 'cloud_sync_service.dart';

class StorageService {
  /// Prevents concurrent bootstrap calls from main() and the auth listener.
  static bool bootstrapInProgress = false;

  static const _habitsKey = 'habits_v2';
  static const _dailyLimitKey = 'daily_limit_minutes';
  static const _limitsKey = 'app_limits_v2';
  static const _onboardingDoneKey = 'onboarding_done_v1';
  static const _zonesKey = 'concentration_zones_v1';

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
    if (!CloudSyncService.instance.isSignedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final hasRemote = await CloudSyncService.instance.hasRemoteData();

    if (hasRemote) {
      final remoteHabits = await CloudSyncService.instance.loadHabits();
      if (remoteHabits != null) {
        await prefs.setStringList(
          _habitsKey,
          remoteHabits.map((e) => e.toJson()).toList(),
        );
      }

      final remoteDaily = await CloudSyncService.instance.loadDailyLimitMinutes();
      if (remoteDaily != null) {
        await prefs.setInt(_dailyLimitKey, remoteDaily);
      }

      final remoteLimits = await CloudSyncService.instance.loadAppLimits();
      if (remoteLimits != null) {
        await prefs.setStringList(
          _limitsKey,
          remoteLimits.map((e) => e.toJson()).toList(),
        );
      }

      final remoteZones = await CloudSyncService.instance.loadConcentrationZones();
      if (remoteZones != null) {
        await prefs.setStringList(
          _zonesKey,
          remoteZones.map((e) => e.toJson()).toList(),
        );
      }

      return;
    }

    final localHabits = await loadHabits();
    final localDaily = await loadDailyLimitMinutes();
    final localLimits = await loadAppLimits();
    final localZones = await loadConcentrationZones();

    await CloudSyncService.instance.saveHabits(localHabits);
    await CloudSyncService.instance.saveDailyLimitMinutes(localDaily);
    await CloudSyncService.instance.saveAppLimits(localLimits);
    await CloudSyncService.instance.saveConcentrationZones(localZones);
  }

  Future<List<Habit>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    if (CloudSyncService.instance.isSignedIn) {
      try {
        final remote = await CloudSyncService.instance.loadHabits();
        if (remote != null) {
          await prefs.setStringList(_habitsKey, remote.map((e) => e.toJson()).toList());
          return remote.isEmpty ? _defaultHabits() : remote;
        }
      } catch (_) {}
    }
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
    if (CloudSyncService.instance.isSignedIn) {
      try {
        final remote = await CloudSyncService.instance.loadDailyLimitMinutes();
        if (remote != null) {
          await prefs.setInt(_dailyLimitKey, remote);
          return remote;
        }
      } catch (_) {}
    }
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
    if (CloudSyncService.instance.isSignedIn) {
      try {
        final remote = await CloudSyncService.instance.loadAppLimits();
        if (remote != null) {
          await prefs.setStringList(_limitsKey, remote.map((e) => e.toJson()).toList());
          return remote.isEmpty ? _defaultAppLimits() : remote;
        }
      } catch (_) {}
    }
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
    if (CloudSyncService.instance.isSignedIn) {
      try {
        final remote = await CloudSyncService.instance.loadConcentrationZones();
        if (remote != null) {
          await prefs.setStringList(_zonesKey, remote.map((e) => e.toJson()).toList());
          return remote;
        }
      } catch (_) {}
    }
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

  Future<bool> loadOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> saveOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, value);
  }}