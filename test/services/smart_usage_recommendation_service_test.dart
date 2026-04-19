import 'package:detox/l10n_app_strings.dart';
import 'package:detox/models/usage_models.dart';
import 'package:detox/services/smart_usage_recommendation_service.dart';
import 'package:detox/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartUsageRecommendationService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('ignores empty, missing-package, and short-usage entries', () async {
      final service = SmartUsageRecommendationService.instance;
      final strings = AppStrings(const Locale('es'));

      await service.evaluateTopApp(entry: null, strings: strings);
      await service.evaluateTopApp(
        entry: const AppUsageEntry(appName: 'TikTok', minutes: 89, packageName: 'com.zhiliaoapp.musically'),
        strings: strings,
      );
      await service.evaluateTopApp(
        entry: const AppUsageEntry(appName: 'TikTok', minutes: 120),
        strings: strings,
      );

      final counters = await StorageService().loadProgressCounters();
      expect(counters['suggestionsShown'], 0);
    });

    test('sends only one suggestion per app per day', () async {
      final service = SmartUsageRecommendationService.instance;
      final strings = AppStrings(const Locale('en'));
      const entry = AppUsageEntry(
        appName: 'TikTok',
        minutes: 120,
        packageName: 'com.zhiliaoapp.musically',
      );

      await service.evaluateTopApp(entry: entry, strings: strings);
      await service.evaluateTopApp(entry: entry, strings: strings);

      final counters = await StorageService().loadProgressCounters();
      expect(counters['suggestionsShown'], 1);
    });

    test('allows different apps to generate independent suggestions', () async {
      final service = SmartUsageRecommendationService.instance;
      final strings = AppStrings(const Locale('en'));

      await service.evaluateTopApp(
        entry: const AppUsageEntry(
          appName: 'TikTok',
          minutes: 120,
          packageName: 'com.zhiliaoapp.musically',
        ),
        strings: strings,
      );
      await service.evaluateTopApp(
        entry: const AppUsageEntry(
          appName: 'Instagram',
          minutes: 95,
          packageName: 'com.instagram.android',
        ),
        strings: strings,
      );

      final counters = await StorageService().loadProgressCounters();
      expect(counters['suggestionsShown'], 2);
    });
  });
}
