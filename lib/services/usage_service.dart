import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/permission_status.dart';
import '../models/usage_models.dart';
import 'app_metadata_service.dart';
import 'app_visibility_filter_service.dart';

class UsageService {
  UsageService._();
  factory UsageService() => instance;
  static final UsageService instance = UsageService._();

  static const MethodChannel _channel = MethodChannel('detox/device_control');
  static const Duration _todayCacheTtl = Duration(seconds: 45);
  static const Duration _todaySummaryCacheTtl = Duration(seconds: 45);
  static const Duration _weeklyCacheTtl = Duration(minutes: 2);

  List<AppUsageEntry>? _todayEntriesCache;
  DateTime? _todayEntriesCachedAt;
  String? _todayEntriesDayToken;
  Future<List<AppUsageEntry>>? _todayEntriesLoadFuture;
  DailyUsageSummary? _todaySummaryCache;
  DateTime? _todaySummaryCachedAt;
  String? _todaySummaryDayToken;
  Future<DailyUsageSummary>? _todaySummaryLoadFuture;

  List<WeeklyUsagePoint>? _weeklyUsageCache;
  DateTime? _weeklyUsageCachedAt;
  String? _weeklyUsageDayToken;
  Future<List<WeeklyUsagePoint>>? _weeklyUsageLoadFuture;

  Future<DailyUsageSummary> getTodaySummary() async {
    if (kIsWeb) return _emptySummary();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final now = DateTime.now();
      final dayToken = _dayToken(now);
      final cachedAt = _todaySummaryCachedAt;
      final cached = _todaySummaryCache;
      if (cached != null &&
          cachedAt != null &&
          _todaySummaryDayToken == dayToken &&
          now.difference(cachedAt) <= _todaySummaryCacheTtl) {
        return cached;
      }

      final pending = _todaySummaryLoadFuture;
      if (pending != null) return pending;

      late final Future<DailyUsageSummary> future;
      future = _loadAndroidTodaySummary(now, dayToken).whenComplete(() {
        if (identical(_todaySummaryLoadFuture, future)) {
          _todaySummaryLoadFuture = null;
        }
      });
      _todaySummaryLoadFuture = future;
      return future;
    }

    return _emptySummary();
  }

  Future<List<WeeklyUsagePoint>> getWeeklyUsage() async {
    if (kIsWeb) return _emptyWeeklyUsage();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final now = DateTime.now();
      final dayToken = _dayToken(now);
      final cachedAt = _weeklyUsageCachedAt;
      final cached = _weeklyUsageCache;
      if (cached != null &&
          cachedAt != null &&
          _weeklyUsageDayToken == dayToken &&
          now.difference(cachedAt) <= _weeklyCacheTtl) {
        return cached;
      }

      final pending = _weeklyUsageLoadFuture;
      if (pending != null) return pending;

      final future = _loadWeeklyUsage(now, dayToken);
      _weeklyUsageLoadFuture = future;
      try {
        return await future;
      } finally {
        if (identical(_weeklyUsageLoadFuture, future)) {
          _weeklyUsageLoadFuture = null;
        }
      }
    }

    return _emptyWeeklyUsage();
  }

  Future<List<WeeklyUsagePoint>> _loadWeeklyUsage(
    DateTime now,
    String dayToken,
  ) async {
    final days = List<DateTime>.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });
    final points = <WeeklyUsagePoint>[];

    try {
      final rawDays = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'queryWeeklyUsage',
        {'starts': days.map((day) => day.millisecondsSinceEpoch).toList()},
      );
      final rowsByDate = <int, List<Map<Object?, Object?>>>{};
      for (final day in rawDays ?? const <Map<Object?, Object?>>[]) {
        final date = day['date'];
        final apps = day['apps'];
        if (date is int && apps is List) {
          rowsByDate[date] = apps.whereType<Map<Object?, Object?>>().toList();
        }
      }

      for (final start in days) {
        var totalMinutes = 0;
        final apps = rowsByDate[start.millisecondsSinceEpoch] ?? const [];
        for (final item in apps) {
          final minutes = item['minutes'];
          final packageName = item['packageName'];
          if (minutes is! int || minutes <= 0 || packageName is! String) {
            continue;
          }
          if (packageName.isEmpty ||
              !AppVisibilityFilterService.instance.shouldShowPackageName(
                packageName,
              )) {
            continue;
          }

          totalMinutes += minutes;
        }

        points.add(
          WeeklyUsagePoint(
            dateLabel: DateFormat.E().format(start),
            minutes: totalMinutes,
          ),
        );
      }
    } catch (_) {
      return _emptyWeeklyUsage();
    }

    _weeklyUsageCache = points;
    _weeklyUsageCachedAt = now;
    _weeklyUsageDayToken = dayToken;
    return points;
  }

  Future<PermissionStatusModel> getPermissionStatus() async {
    if (kIsWeb) {
      return const PermissionStatusModel(
        usageReady: true,
        platformMessage: 'Web uses demo analytics only.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final hasAccess = await _hasAndroidUsageAccess();
      return PermissionStatusModel(
        usageReady: hasAccess,
        platformMessage: hasAccess
            ? 'Usage access detected and ready.'
            : 'Enable Usage Access so Detox can read screen time and top apps.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const PermissionStatusModel(
        usageReady: true,
        platformMessage:
            'The iOS UI is ready. Real Screen Time enforcement needs Apple Family Controls entitlement and native setup in Xcode.',
      );
    }

    return const PermissionStatusModel(
      usageReady: true,
      platformMessage: 'Desktop uses demo analytics.',
    );
  }

  Future<void> openUsageAccessSettings() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('openUsageAccessSettings');
      } catch (_) {}
    }
  }

  Future<bool> _hasAndroidUsageAccess() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasUsageAccess');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<AppUsageEntry>> getTodayAppUsageEntries() async {
    if (kIsWeb) return const [];
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _loadAndroidTodayEntries();
    }
    return const [];
  }

  Future<DailyUsageSummary> _loadAndroidTodaySummary(
    DateTime now,
    String dayToken,
  ) async {
    try {
      final entries = await _loadAndroidTodayEntries();
      if (entries.isEmpty) {
        const empty = DailyUsageSummary(
          totalMinutes: 0,
          pickups: 0,
          topApps: [],
          fromRealUsage: true,
        );
        _cacheTodaySummary(empty, now, dayToken);
        return empty;
      }

      // Resolve labels before taking the top five. Otherwise system apps in
      // the first five slots could all be filtered out and hide real apps
      // ranked just below them on the Home screen.
      final labels = await AppMetadataService.instance
          .getLabels(entries.map((entry) => entry.packageName ?? ''));
      final visibleEntries = entries.where((entry) {
        return AppVisibilityFilterService.instance
            .shouldShowResolvedLabel(labels[entry.packageName]);
      }).toList();
      final totalMinutes =
          entries.fold<int>(0, (sum, item) => sum + item.minutes);
      final topApps = visibleEntries.take(5).map((entry) {
        final label = labels[entry.packageName];
        return AppUsageEntry(
          appName:
              label?.trim().isNotEmpty == true ? label!.trim() : entry.appName,
          minutes: entry.minutes,
          packageName: entry.packageName,
        );
      }).toList();
      final summary = DailyUsageSummary(
        totalMinutes: totalMinutes,
        pickups: totalMinutes > 0 ? _estimatePickups(totalMinutes) : 0,
        topApps: topApps,
        fromRealUsage: true,
      );
      _cacheTodaySummary(summary, now, dayToken);
      return summary;
    } catch (error) {
      debugPrint('Could not load today usage: $error');
      rethrow;
    }
  }

  void _cacheTodaySummary(
    DailyUsageSummary summary,
    DateTime now,
    String dayToken,
  ) {
    _todaySummaryCache = summary;
    _todaySummaryCachedAt = now;
    _todaySummaryDayToken = dayToken;
  }

  Future<List<AppUsageEntry>> _loadAndroidTodayEntries() async {
    final now = DateTime.now();
    final dayToken = _dayToken(now);
    final cachedAt = _todayEntriesCachedAt;
    final cached = _todayEntriesCache;
    if (cached != null &&
        cachedAt != null &&
        _todayEntriesDayToken == dayToken &&
        now.difference(cachedAt) <= _todayCacheTtl) {
      return cached;
    }

    final pending = _todayEntriesLoadFuture;
    if (pending != null) return pending;

    late final Future<List<AppUsageEntry>> future;
    future = _loadAndroidTodayEntriesInternal(now, dayToken).whenComplete(() {
      if (identical(_todayEntriesLoadFuture, future)) {
        _todayEntriesLoadFuture = null;
      }
    });
    _todayEntriesLoadFuture = future;
    return future;
  }

  Future<List<AppUsageEntry>> _loadAndroidTodayEntriesInternal(
    DateTime now,
    String dayToken,
  ) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    final usage = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'queryUsage',
      {
        'start': start.millisecondsSinceEpoch,
        // Match weekly statistics: Android can report a complete daily
        // bucket only when the range reaches the next local midnight.
        'end': end.millisecondsSinceEpoch,
      },
    );

    final entries = <AppUsageEntry>[];
    for (final item in usage ?? const <Map<Object?, Object?>>[]) {
      final packageName = item['packageName'];
      final minutes = item['minutes'];
      if (packageName is! String || minutes is! int || minutes <= 0) continue;
      if (!AppVisibilityFilterService.instance
          .shouldShowPackageName(packageName)) {
        continue;
      }

      entries.add(AppUsageEntry(
        appName: packageName,
        minutes: minutes,
        packageName: packageName,
      ));
    }
    entries.sort((a, b) => b.minutes.compareTo(a.minutes));

    _todayEntriesCache = entries;
    _todayEntriesCachedAt = now;
    _todayEntriesDayToken = dayToken;
    return entries;
  }

  /// Honest empty state: when real usage is unavailable we return zeros and
  /// an empty app list instead of inventing usage the user never had.
  DailyUsageSummary _emptySummary() {
    return const DailyUsageSummary(
      totalMinutes: 0,
      pickups: 0,
      topApps: [],
      fromRealUsage: false,
    );
  }

  List<WeeklyUsagePoint> _emptyWeeklyUsage() {
    return const [
      WeeklyUsagePoint(dateLabel: 'Mon', minutes: 0),
      WeeklyUsagePoint(dateLabel: 'Tue', minutes: 0),
      WeeklyUsagePoint(dateLabel: 'Wed', minutes: 0),
      WeeklyUsagePoint(dateLabel: 'Thu', minutes: 0),
      WeeklyUsagePoint(dateLabel: 'Fri', minutes: 0),
      WeeklyUsagePoint(dateLabel: 'Sat', minutes: 0),
      WeeklyUsagePoint(dateLabel: 'Sun', minutes: 0),
    ];
  }

  int _estimatePickups(int totalMinutes) {
    return max(6, (totalMinutes / 4).round());
  }

  String _dayToken(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
