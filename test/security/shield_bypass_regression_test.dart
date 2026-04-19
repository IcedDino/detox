import 'package:detox/services/app_blocking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('detox/device_control');
  final calls = <MethodCall>[];

  Map<String, dynamic> _arguments(MethodCall call) =>
      Map<String, dynamic>.from(call.arguments! as Map);

  List<String> _packages(MethodCall call) =>
      List<String>.from(_arguments(call)['blockedPackages'] as List<dynamic>);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'hasOverlayPermission':
        case 'hasUsageAccess':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await AppBlockingService.instance.stopShield();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('Shield bypass regressions', () {
    test('stopping one source does not clear other active blocks', () async {
      final service = AppBlockingService.instance;

      await service.startShield(
        blockedPackages: const <String>['com.instagram.android', 'com.youtube'],
        reason: 'focus_session',
        hasSponsor: false,
        source: 'focus',
      );
      await service.startShield(
        blockedPackages: const <String>['com.youtube', 'com.tiktok'],
        reason: 'automation_rule',
        hasSponsor: false,
        source: 'automation',
      );
      await service.stopShield(source: 'focus');

      final startCalls = calls.where((c) => c.method == 'startBlocking').toList();
      expect(startCalls, isNotEmpty);

      final lastStart = startCalls.last;
      expect(_packages(lastStart), <String>['com.tiktok', 'com.youtube']);
      expect(_arguments(lastStart)['hasSponsor'], isFalse);
      expect(_arguments(lastStart)['strictMode'], isFalse);
    });

    test('merges sponsor and strict state across concurrent sources', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'focus_strict_mode_v1': true,
      });

      final service = AppBlockingService.instance;
      await service.startShield(
        blockedPackages: const <String>['com.instagram.android', 'com.instagram.android'],
        reason: 'focus_session',
        hasSponsor: false,
        source: 'focus',
      );
      await service.startShield(
        blockedPackages: const <String>['com.tiktok'],
        reason: 'zone',
        hasSponsor: true,
        source: 'zone',
      );

      final lastStart = calls.where((c) => c.method == 'startBlocking').last;
      expect(_packages(lastStart), <String>['com.instagram.android', 'com.tiktok']);
      expect(_arguments(lastStart)['hasSponsor'], isTrue);
      expect(_arguments(lastStart)['strictMode'], isTrue);
    });

    test('syncSponsorState updates active payload without dropping packages', () async {
      final service = AppBlockingService.instance;
      await service.startShield(
        blockedPackages: const <String>['com.youtube', 'com.instagram.android'],
        reason: 'automation_rule',
        hasSponsor: false,
        source: 'automation',
      );

      await service.syncSponsorState(true);

      final starts = calls.where((c) => c.method == 'startBlocking').toList();
      expect(starts.length, greaterThanOrEqualTo(2));

      final lastStart = starts.last;
      expect(_packages(lastStart), <String>['com.instagram.android', 'com.youtube']);
      expect(_arguments(lastStart)['hasSponsor'], isTrue);
    });
  });
}
