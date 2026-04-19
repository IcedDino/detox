import 'package:detox/services/app_blocking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('detox/device_control');
  final calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    await AppBlockingService.instance.stopShield();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('survives repeated shield churn without clearing final stop', () async {
    final service = AppBlockingService.instance;
    const sources = <String>['focus', 'zone', 'automation'];
    const packageMatrix = <List<String>>[
      <String>['com.instagram.android', 'com.youtube'],
      <String>['com.youtube', 'com.tiktok'],
      <String>['com.x', 'com.instagram.android', ''],
    ];

    for (var i = 0; i < 120; i++) {
      final source = sources[i % sources.length];
      final packages = packageMatrix[i % packageMatrix.length];
      await service.startShield(
        blockedPackages: packages,
        reason: 'stress_$i',
        hasSponsor: i.isEven,
        source: source,
        strictModeOverride: i % 5 == 0,
      );

      if (i % 4 == 0) {
        await service.stopShield(source: sources[(i + 1) % sources.length]);
      }
    }

    await service.stopShield();

    expect(calls.where((c) => c.method == 'startBlocking').length, greaterThan(20));
    expect(calls.last.method, 'stopBlocking');
  });
}
