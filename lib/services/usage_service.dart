import 'dart:math';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/permission_status.dart';
import '../models/usage_models.dart';
import 'app_metadata_service.dart';
import 'app_visibility_filter_service.dart';

class UsageService {
  static const MethodChannel _channel = MethodChannel('detox/device_control');
  static const Duration _todayCacheTtl = Duration(seconds: 45);
  static const Duration _weeklyCacheTtl = Duration(minutes: 2);

  List<AppUsageEntry>? _todayEntriesCache;
  DateTime? _todayEntriesCachedAt;
  String? _todayEntriesDayToken;

  List<WeeklyUsagePoint>? _weeklyUsageCache;
  DateTime? _weeklyUsageCachedAt;
  String? _weeklyUsageDayToken;

  Future<DailyUsageSummary> getTodaySummary() async {
    if (kIsWeb) return _emptySummary();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _loadAndroidTodaySummary();
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

      final points = <WeeklyUsagePoint>[];
      try {
        for (var offset = 6; offset >= 0; offset--) {
          final day = now.subtract(Duration(days: offset));
          final start = DateTime(day.year, day.month, day.day);
          final end = start.add(const Duration(days: 1));
          final usage = await AppUsage().getAppUsage(start, end);

          var totalMinutes = 0;
          for (final item in usage) {
            final minutes = item.usage.inMinutes;
            if (minutes <= 0) continue;

            final packageName = item.packageName;
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

    return _emptyWeeklyUsage();
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

  Future<DailyUsageSummary> _loadAndroidTodaySummary() async {
    try {
      final entries = await _loadAndroidTodayEntries();
      final totalMinutes = entries.fold<int>(0, (sum, item) => sum + item.minutes);

      if (entries.isEmpty) return _emptySummary();

      return DailyUsageSummary(
        totalMinutes: totalMinutes,
        pickups: _estimatePickups(totalMinutes),
        topApps: entries.take(5).toList(),
        fromRealUsage: true,
      );
    } catch (_) {
      return _emptySummary();
    }
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

    final start = DateTime(now.year, now.month, now.day);
    final usage = await AppUsage().getAppUsage(start, now);

    final futures = usage.map((item) async {
      final minutes = item.usage.inMinutes;
      if (minutes <= 0) return null;

      final packageName = item.packageName;
      if (packageName.isEmpty ||
          !AppVisibilityFilterService.instance.shouldShowPackageName(packageName)) {
        return null;
      }

      final fallbackName = item.appName.trim();
      String? resolvedName =
          (fallbackName.isNotEmpty && fallbackName != packageName) ? fallbackName : null;
      resolvedName ??= await AppMetadataService.instance.getLabel(packageName);

      final visibleLabel = (resolvedName?.trim().isNotEmpty ?? false)
          ? resolvedName!.trim()
          : fallbackName;
      if (!AppVisibilityFilterService.instance.shouldShowResolvedLabel(visibleLabel)) {
        return null;
      }

      return AppUsageEntry(
        appName: visibleLabel.isNotEmpty ? visibleLabel : packageName,
        minutes: minutes,
        packageName: packageName,
      );
    });

    final entries = (await Future.wait(futures)).whereType<AppUsageEntry>().toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

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
