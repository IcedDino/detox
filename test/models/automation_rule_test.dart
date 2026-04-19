import 'package:detox/models/automation_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutomationRule.appliesAt', () {
    final weekdays = <int>{1, 2, 3, 4, 5};

    test('returns false when rule is disabled', () {
      final rule = AutomationRule(
        id: 'r1',
        name: 'Disabled',
        enabled: false,
        startMinuteOfDay: 8 * 60,
        endMinuteOfDay: 9 * 60,
        weekdays: weekdays,
        blockedPackages: const <String>{'com.instagram.android'},
      );

      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 8, 30), insideZone: true),
        isFalse,
      );
    });

    test('supports a normal schedule and excludes the end minute', () {
      final rule = AutomationRule(
        id: 'r2',
        name: 'Study block',
        startMinuteOfDay: 8 * 60,
        endMinuteOfDay: 14 * 60,
        weekdays: weekdays,
        blockedPackages: const <String>{'com.tiktok'},
      );

      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 8, 0), insideZone: true),
        isTrue,
      );
      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 13, 59), insideZone: true),
        isTrue,
      );
      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 14, 0), insideZone: true),
        isFalse,
      );
    });

    test('supports rules that cross midnight', () {
      final rule = AutomationRule(
        id: 'r3',
        name: 'Night block',
        startMinuteOfDay: 22 * 60,
        endMinuteOfDay: 7 * 60,
        weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
        blockedPackages: const <String>{'com.youtube'},
      );

      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 23, 15), insideZone: true),
        isTrue,
      );
      expect(
        rule.appliesAt(DateTime(2026, 4, 21, 6, 45), insideZone: true),
        isTrue,
      );
      expect(
        rule.appliesAt(DateTime(2026, 4, 21, 12, 0), insideZone: true),
        isFalse,
      );
      expect(rule.crossesMidnight, isTrue);
    });

    test('treats equal start and end as a 24-hour rule', () {
      final rule = AutomationRule(
        id: 'r4',
        name: 'Always active',
        startMinuteOfDay: 0,
        endMinuteOfDay: 0,
        weekdays: const <int>{1, 2, 3, 4, 5, 6, 7},
        blockedPackages: const <String>{'com.facebook.katana'},
      );

      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 0, 1), insideZone: false),
        isTrue,
      );
      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 23, 59), insideZone: true),
        isTrue,
      );
    });

    test('requires being inside the zone when onlyInsideZone is enabled', () {
      final rule = AutomationRule(
        id: 'r5',
        name: 'Library only',
        startMinuteOfDay: 10 * 60,
        endMinuteOfDay: 12 * 60,
        weekdays: weekdays,
        blockedPackages: const <String>{'com.instagram.android'},
        onlyInsideZone: true,
      );

      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 10, 30), insideZone: false),
        isFalse,
      );
      expect(
        rule.appliesAt(DateTime(2026, 4, 20, 10, 30), insideZone: true),
        isTrue,
      );
    });
  });

  group('AutomationRule serialization', () {
    test('round-trips and normalizes values from mixed input types', () {
      final rule = AutomationRule.fromMap(<String, dynamic>{
        'id': 'mixed',
        'name': 'Mixed payload',
        'enabled': 'true',
        'startMinuteOfDay': '480',
        'endMinuteOfDay': 720.0,
        'weekdays': <dynamic>['1', 2, 3.0, 'x'],
        'blockedPackages': <dynamic>[' com.instagram.android ', '', null],
        'onlyInsideZone': 'false',
        'strictMode': true,
      });

      expect(rule.id, 'mixed');
      expect(rule.enabled, isTrue);
      expect(rule.startMinuteOfDay, 480);
      expect(rule.endMinuteOfDay, 720);
      expect(rule.weekdays, <int>{1, 2, 3});
      expect(rule.blockedPackages, <String>{'com.instagram.android'});
      expect(rule.onlyInsideZone, isFalse);
      expect(rule.strictMode, isTrue);

      final restored = AutomationRule.fromJson(rule.toJson());
      expect(restored, equals(rule));
    });
  });
}
