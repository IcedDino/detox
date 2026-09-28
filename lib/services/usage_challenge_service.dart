import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usage_challenge.dart';
import 'app_visibility_filter_service.dart';
import 'sponsor_service.dart';
import 'usage_service.dart';

class UsageChallengeSnapshot {
  const UsageChallengeSnapshot({
    required this.streak,
    required this.hasUsageAccess,
    required this.hasSponsor,
    required this.sponsorName,
    required this.comparison,
    required this.comparisonEnabled,
  });

  final int streak;
  final bool hasUsageAccess;
  final bool hasSponsor;
  final String? sponsorName;
  final UsageComparison? comparison;
  final bool comparisonEnabled;
}

class UsageChallengeService {
  static const _channel = MethodChannel('detox/device_control');
  static String _sharingKey(String uid) =>
      'share_daily_usage_with_sponsor_$uid';
  final _firestore = FirebaseFirestore.instance;

  Future<void> enableComparison() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sharingKey(uid), true);
  }

  Future<void> disableComparison() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final days = await _firestore
        .collection('users')
        .doc(uid)
        .collection('usage_days')
        .get();
    for (final doc in days.docs) {
      await doc.reference.delete();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sharingKey(uid), false);
  }

  Future<UsageChallengeSnapshot> load(int dailyGoal) async {
    final now = DateTime.now();
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !(await UsageService().getPermissionStatus()).usageReady) {
      return const UsageChallengeSnapshot(
        streak: 0,
        hasUsageAccess: false,
        hasSponsor: false,
        sponsorName: null,
        comparison: null,
        comparisonEnabled: false,
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final preferences = await SharedPreferences.getInstance();
    final comparisonEnabled =
        uid != null && (preferences.getBool(_sharingKey(uid)) ?? false);
    final ownRef = uid == null || !comparisonEnabled
        ? null
        : _firestore.collection('users').doc(uid).collection('usage_days');
    final ownDays = <String, UsageChallengeDay>{};
    final cloudDays = <String>{};
    final localPrefix = 'usage_day_${uid ?? 'anonymous'}_';
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(localPrefix),
    )) {
      final value = preferences.getString(key)?.split(':');
      if (value?.length != 2) continue;
      final minutes = int.tryParse(value![0]);
      final goal = int.tryParse(value[1]);
      if (minutes != null && goal != null && minutes >= 0 && goal > 0) {
        ownDays[key.substring(localPrefix.length)] = UsageChallengeDay(
          minutes: minutes,
          goalMinutes: goal,
        );
      }
    }
    if (ownRef != null) {
      try {
        final history = await ownRef
            .orderBy(FieldPath.documentId, descending: true)
            .limit(365)
            .get();
        for (final doc in history.docs) {
          final day = _dayFromData(doc.data());
          if (day != null) {
            ownDays[doc.id] = day;
            cloudDays.add(doc.id);
          }
        }
      } catch (error) {
        debugPrint('Could not load streak history: $error');
      }
    }

    // Android can backfill recently completed days even when Detox was not
    // opened. Persist only totals and the goal, never package names.
    final starts = List<DateTime>.generate(
      30,
      (index) => DateTime(now.year, now.month, now.day - index - 1),
    );
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'queryWeeklyUsage',
        {'starts': starts.map((day) => day.millisecondsSinceEpoch).toList()},
      );
      final byStart = <int, List<Map<Object?, Object?>>>{};
      for (final row in rows ?? const <Map<Object?, Object?>>[]) {
        if (row['date'] is int && row['apps'] is List) {
          byStart[row['date'] as int] = (row['apps'] as List)
              .whereType<Map<Object?, Object?>>()
              .toList();
        }
      }
      int? earliestObserved;
      for (final entry in byStart.entries) {
        if (entry.value.isNotEmpty &&
            (earliestObserved == null || entry.key < earliestObserved)) {
          earliestObserved = entry.key;
        }
      }
      for (final date in starts) {
        if (earliestObserved == null ||
            date.millisecondsSinceEpoch < earliestObserved) {
          continue;
        }
        final apps = byStart[date.millisecondsSinceEpoch];
        if (apps == null) continue; // Missing data is never a zero-minute win.
        var total = 0;
        for (final app in apps) {
          final minutes = app['minutes'];
          final package = app['packageName'];
          if (minutes is int &&
              minutes > 0 &&
              package is String &&
              AppVisibilityFilterService.instance.shouldShowPackageName(
                package,
              )) {
            total += minutes;
          }
        }
        final key = usageDayKey(date);
        final previous = ownDays[key];
        ownDays[key] = UsageChallengeDay(
          minutes: total,
          goalMinutes: previous?.goalMinutes ?? dailyGoal,
        );
        await preferences.setString(
          '$localPrefix$key',
          '$total:${previous?.goalMinutes ?? dailyGoal}',
        );
        if (ownRef != null &&
            (!cloudDays.contains(key) || previous?.minutes != total)) {
          try {
            await ownRef.doc(key).set({
              'minutes': total,
              'goalMinutes': previous?.goalMinutes ?? dailyGoal,
            });
          } catch (error) {
            debugPrint('Could not sync usage day: $error');
          }
        }
      }
    } catch (error) {
      debugPrint('Could not backfill usage days: $error');
    }

    var hasSponsor = false;
    String? sponsorName;
    UsageComparison? comparison;
    try {
      final context = await SponsorService.instance.loadCurrentUserContext();
      final sponsorUid = context.sponsorUid;
      if (sponsorUid != null) {
        hasSponsor = true;
        sponsorName = context.sponsorProfile?.displayName;
        if (comparisonEnabled) {
          final sponsorRows = await _firestore
              .collection('users')
              .doc(sponsorUid)
              .collection('usage_days')
              .where(
                FieldPath.documentId,
                isGreaterThanOrEqualTo: usageDayKey(
                  DateTime(now.year, now.month, now.day - 7),
                ),
              )
              .get();
          final sponsorDays = <String, UsageChallengeDay>{};
          for (final doc in sponsorRows.docs) {
            final day = _dayFromData(doc.data());
            if (day != null) sponsorDays[doc.id] = day;
          }
          comparison = compareUsage(ownDays, sponsorDays, now);
        }
      }
    } catch (error) {
      debugPrint('Could not load sponsor comparison: $error');
    }
    return UsageChallengeSnapshot(
      streak: usageStreak(ownDays, now),
      hasUsageAccess: true,
      hasSponsor: hasSponsor,
      sponsorName: sponsorName,
      comparison: comparison,
      comparisonEnabled: comparisonEnabled,
    );
  }

  UsageChallengeDay? _dayFromData(Map<String, dynamic> data) {
    final minutes = data['minutes'];
    final goal = data['goalMinutes'];
    if (minutes is! int || minutes < 0 || goal is! int || goal <= 0) {
      return null;
    }
    return UsageChallengeDay(minutes: minutes, goalMinutes: goal);
  }
}
