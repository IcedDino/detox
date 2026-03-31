import 'package:shared_preferences/shared_preferences.dart';

import '../l10n_app_strings.dart';
import '../models/usage_models.dart';
import 'focus_notification_service.dart';
import 'progress_service.dart';

class SmartUsageRecommendationService {
  SmartUsageRecommendationService._();
  static final SmartUsageRecommendationService instance =
      SmartUsageRecommendationService._();

  static const _lastKey = 'smart_usage_last_notification_v1';
  static const int triggerMinutes = 120;

  Future<void> maybeNotifyTopApp({
    required AppUsageEntry? topApp,
    required AppStrings strings,
  }) async {
    if (topApp == null || topApp.minutes < triggerMinutes) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final marker =
        '${today.year}-${today.month}-${today.day}:${topApp.packageName ?? topApp.appName}:$triggerMinutes';
    if (prefs.getString(_lastKey) == marker) return;

    await prefs.setString(_lastKey, marker);
    await ProgressService.instance.recordSuggestionShown();
    await FocusNotificationService.instance.showSmartUsageSuggestion(
      appName: topApp.appName,
      minutes: topApp.minutes,
      startActionLabel: strings.startConcentrationHour,
      denyActionLabel: strings.deny,
      body: strings.smartSuggestionNotification(topApp.appName, _formatMinutes(topApp.minutes)),
      title: strings.smartSuggestionTitle,
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}:${mins.toString().padLeft(2, '0')}';
  }
}
