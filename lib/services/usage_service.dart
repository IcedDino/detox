import 'dart:math';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/permission_status.dart';
import '../models/usage_models.dart';
import 'app_metadata_service.dart';

class UsageService {
  static const MethodChannel _channel = MethodChannel('detox/device_control');

  Future<DailyUsageSummary> getTodaySummary() async {
    if (kIsWeb) return _fallbackSummary();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _loadAndroidTodaySummary();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosSummaryPlaceholder();
    }

    return _fallbackSummary();
  }

  Future<List<WeeklyUsagePoint>> getWeeklyUsage() async {
    if (kIsWeb) return _fallbackWeeklyUsage();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final now = DateTime.now();
      final points = <WeeklyUsagePoint>[];

      for (var offset = 6; offset >= 0; offset--) {
        final day = now.subtract(Duration(days: offset));
        final start = DateTime(day.year, day.month, day.day);
        final end = start.add(const Duration(days: 1));

        try {
          final usage = await AppUsage().getAppUsage(start, end);
          var totalMinutes = 0;
          for (final item in usage) {
            totalMinutes += item.usage.inMinutes;
          }
          points.add(
            WeeklyUsagePoint(
              dateLabel: DateFormat.E().format(start),
              minutes: totalMinutes,
            ),
          );
        } catch (_) {
          return _fallbackWeeklyUsage();
        }
      }

      return points;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
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

    return _fallbackWeeklyUsage();
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
        platformMessage: 'The iOS UI is ready. Real Screen Time enforcement needs Apple Family Controls entitlement and native setup in Xcode.',
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
    if (kIsWeb) return _fallbackSummary().topApps;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _loadAndroidTodayEntries();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const [];
    }
    return _fallbackSummary().topApps;
  }

  Future<DailyUsageSummary> _loadAndroidTodaySummary() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final usage = await AppUsage().getAppUsage(start, now);

      final entries = await _loadAndroidTodayEntries();
      final totalMinutes = entries.fold<int>(0, (sum, item) => sum + item.minutes);

      if (entries.isEmpty) return _fallbackSummary();

      return DailyUsageSummary(
        totalMinutes: totalMinutes,
        pickups: _estimatePickups(totalMinutes),
        topApps: entries.take(5).toList(),
        fromRealUsage: true,
      );
    } catch (_) {
      return _fallbackSummary();
    }
  }


  Future<List<AppUsageEntry>> _loadAndroidTodayEntries() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final usage = await AppUsage().getAppUsage(start, now);

    final entries = <AppUsageEntry>[];
    for (final item in usage) {
      final minutes = item.usage.inMinutes;
      if (minutes <= 0) continue;

      final packageName = item.packageName;
      final resolvedName = packageName.isNotEmpty
          ? await AppMetadataService.instance.getLabel(packageName)
          : null;

      entries.add(
        AppUsageEntry(
          appName: (resolvedName?.trim().isNotEmpty ?? false)
              ? resolvedName!.trim()
              : (item.appName.isNotEmpty ? item.appName : item.packageName),
          minutes: minutes,
          packageName: packageName.isEmpty ? null : packageName,
        ),
      );
    }

    entries.sort((a, b) => b.minutes.compareTo(a.minutes));
    return entries;
  }

  DailyUsageSummary _iosSummaryPlaceholder() {
    return const DailyUsageSummary(
      totalMinutes: 0,
      pickups: 0,
      topApps: [],
      fromRealUsage: false,
    );
  }

  DailyUsageSummary _fallbackSummary() {
    return const DailyUsageSummary(
      totalMinutes: 132,
      pickups: 34,
      topApps: [
        AppUsageEntry(appName: 'Instagram', minutes: 48, packageName: 'com.instagram.android'),
        AppUsageEntry(appName: 'YouTube', minutes: 34, packageName: 'com.google.android.youtube'),
        AppUsageEntry(appName: 'TikTok', minutes: 28, packageName: 'com.zhiliaoapp.musically'),
        AppUsageEntry(appName: 'Chrome', minutes: 14, packageName: 'com.android.chrome'),
        AppUsageEntry(appName: 'WhatsApp', minutes: 8, packageName: 'com.whatsapp'),
      ],
      fromRealUsage: false,
    );
  }

  List<WeeklyUsagePoint> _fallbackWeeklyUsage() {
    return const [
      WeeklyUsagePoint(dateLabel: 'Mon', minutes: 145),
      WeeklyUsagePoint(dateLabel: 'Tue', minutes: 132),
      WeeklyUsagePoint(dateLabel: 'Wed', minutes: 118),
      WeeklyUsagePoint(dateLabel: 'Thu', minutes: 160),
      WeeklyUsagePoint(dateLabel: 'Fri', minutes: 170),
      WeeklyUsagePoint(dateLabel: 'Sat', minutes: 124),
      WeeklyUsagePoint(dateLabel: 'Sun', minutes: 96),
    ];
  }

  int _estimatePickups(int totalMinutes) {
    return max(6, (totalMinutes / 4).round());
  }
}
