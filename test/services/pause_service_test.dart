import 'package:detox/services/pause_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PauseService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('allows one free pause and one ad pause per day', () async {
      final service = PauseService.instance;

      expect(await service.canUseFreePause(), isTrue);
      expect(await service.canUseAdPause(), isTrue);

      await service.markFreePauseUsed();
      expect(await service.canUseFreePause(), isFalse);
      expect(await service.canUseAdPause(), isTrue);

      expect(await service.useAdPause(), isTrue);
      expect(await service.canUseAdPause(), isFalse);
      expect(await service.useAdPause(), isFalse);

      final status = await service.getStatus();
      expect(status, <String, bool>{'freeUsed': true, 'adUsed': true});
    });

    test('resetDay clears both flags', () async {
      final service = PauseService.instance;

      await service.markFreePauseUsed();
      await service.markAdPauseUsed();
      await service.resetDay();

      expect(await service.getStatus(), <String, bool>{
        'freeUsed': false,
        'adUsed': false,
      });
    });

    test('stale saved date triggers an automatic daily reset', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pause_free_used': true,
        'pause_ad_used': true,
        'pause_last_reset': '1999-1-1',
      });

      final service = PauseService.instance;
      final status = await service.getStatus();

      expect(status['freeUsed'], isFalse);
      expect(status['adUsed'], isFalse);
      expect(await service.canUseFreePause(), isTrue);
      expect(await service.canUseAdPause(), isTrue);
    });
  });
}
