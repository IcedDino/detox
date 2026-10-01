import 'dart:convert';

import 'package:detox/models/app_limit.dart';
import 'package:detox/models/concentration_zone.dart';
import 'package:detox/services/app_blocking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Native monitor receives enabled zones with resolved blocked apps', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    Map<String, dynamic>? callArguments;
    const channel = MethodChannel('detox/device_control');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncZoneConfig') {
        callArguments = Map<String, dynamic>.from(call.arguments as Map);
      }
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await AppBlockingService.instance.syncZoneMonitorConfig(
      ownerUid: 'test-user',
      zones: const [
        ConcentrationZone(id: 'home', name: 'Home', latitude: 10, longitude: 20,
            radiusMeters: 180, blockedPackages: ['example.chat']),
        ConcentrationZone(id: 'school', name: 'School', latitude: 11, longitude: 21,
            radiusMeters: 220),
        ConcentrationZone(id: 'off', name: 'Off', latitude: 12, longitude: 22,
            radiusMeters: 150, enabled: false, blockedPackages: ['example.off']),
      ],
      appLimits: [
        AppLimit(appName: 'Video', minutes: 30, packageName: 'example.video'),
        AppLimit(appName: 'Ignored', minutes: 30, packageName: 'example.ignored',
            useInFocusMode: false),
      ],
    );

    final zones = jsonDecode(callArguments!['zonesJson'] as String) as List<dynamic>;
    expect(zones.length, 2);
    expect(zones[0]['blockedPackages'], ['example.chat']);
    expect(zones[1]['blockedPackages'], ['example.video']);
  });
}
