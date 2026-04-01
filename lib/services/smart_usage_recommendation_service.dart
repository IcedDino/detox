import 'package:shared_preferences/shared_preferences.dart';

import '../l10n_app_strings.dart';
import '../models/usage_models.dart';
import 'focus_notification_service.dart';
import 'storage_service.dart';

class SmartUsageRecommendationService {
  SmartUsageRecommendationService._();
  static final SmartUsageRecommendationService instance = SmartUsageRecommendationService._();

  static const _prefix = 'smart_reco_sent_';

  Future<void> evaluateTopApp({required AppUsageEntry? entry, required AppStrings strings}) async {
    if (entry == null || (entry.packageName ?? '').isEmpty || entry.minutes < 90) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    final key = '$_prefix${entry.packageName}_$todayKey';
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    await StorageService().incrementSuggestionsShown();
    await FocusNotificationService.instance.showSmartSuggestion(
      title: strings.smartSuggestionTitle,
      body: strings.smartSuggestionNotification(entry.appName, _formatTime(entry.minutes)),
      startLabel: strings.startConcentrationHour,
      denyLabel: strings.deny,
    );
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}:${m.toString().padLeft(2, '0')}' : '${m}m';
  }
}
