import 'dart:typed_data';

class AppUsageEntry {
  const AppUsageEntry({
    required this.appName,
    required this.minutes,
    this.packageName,
    this.iconBytes,
  });

  final String appName;
  final int minutes;
  final String? packageName;
  final Uint8List? iconBytes;

  AppUsageEntry copyWith({
    String? appName,
    int? minutes,
    String? packageName,
    Uint8List? iconBytes,
  }) {
    return AppUsageEntry(
      appName: appName ?? this.appName,
      minutes: minutes ?? this.minutes,
      packageName: packageName ?? this.packageName,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }
}

class DailyUsageSummary {
  const DailyUsageSummary({
    required this.totalMinutes,
    required this.pickups,
    required this.topApps,
    required this.fromRealUsage,
  });

  final int totalMinutes;
  final int pickups;
  final List<AppUsageEntry> topApps;
  final bool fromRealUsage;
}

class WeeklyUsagePoint {
  const WeeklyUsagePoint({
    required this.dateLabel,
    required this.minutes,
  });

  final String dateLabel;
  final int minutes;
}
