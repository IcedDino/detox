import 'dart:async';

import 'package:detox/services/usage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Today query changes at local midnight while an earlier load is pending',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var now = DateTime(2026, 9, 24, 23, 59, 59);
    final service = UsageService.forTesting(() => now);
    final firstResponse = Completer<List<Map<String, Object>>>();
    final starts = <int>[];
    final ends = <int>[];
    const channel = MethodChannel('detox/device_control');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'queryUsage') return null;
      final arguments = Map<String, Object>.from(call.arguments as Map);
      starts.add(arguments['start']! as int);
      ends.add(arguments['end']! as int);
      if (starts.length == 1) return firstResponse.future;
      return [
        {'packageName': 'org.example.today', 'minutes': 3},
      ];
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final beforeMidnight = service.getTodayAppUsageEntries();
    await Future<void>.delayed(Duration.zero);
    now = DateTime(2026, 9, 25, 0, 0, 1);
    final afterMidnight = await service.getTodayAppUsageEntries();
    expect(afterMidnight.single.packageName, 'org.example.today');
    expect(starts, [
      DateTime(2026, 9, 24).millisecondsSinceEpoch,
      DateTime(2026, 9, 25).millisecondsSinceEpoch,
    ]);
    expect(ends, [
      DateTime(2026, 9, 25).millisecondsSinceEpoch,
      DateTime(2026, 9, 26).millisecondsSinceEpoch,
    ]);

    firstResponse.complete([
      {'packageName': 'org.example.yesterday', 'minutes': 90},
    ]);
    expect((await beforeMidnight).single.packageName, 'org.example.today');
    expect((await service.getTodayAppUsageEntries()).single.packageName,
        'org.example.today');
  });

  test('Weekly query starts on Monday and stops at the current day', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('detox/device_control');
    List<int> queriedStarts = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'queryWeeklyUsage') return null;
      queriedStarts = List<int>.from((call.arguments as Map)['starts'] as List);
      return [];
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    for (final day in [21, 24, 27]) {
      final now = DateTime(2026, 9, day, 9, 15);
      final points = await UsageService.forTesting(() => now).getWeeklyUsage();
      expect(queriedStarts, [
        for (var date = 21; date <= day; date++)
          DateTime(2026, 9, date).millisecondsSinceEpoch,
      ]);
      expect(points.length, day - 20);
    }
  });
}
