import 'usage_models.dart';

class DashboardData {
  const DashboardData({
    required this.summary,
    required this.dailyLimit,
  });

  final DailyUsageSummary summary;
  final int dailyLimit;
}
