import 'package:detox/models/usage_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streak counts consecutive completed days under the goal', () {
    final days = <String, UsageChallengeDay>{
      '2026-09-24': const UsageChallengeDay(minutes: 120, goalMinutes: 180),
      '2026-09-25': const UsageChallengeDay(minutes: 190, goalMinutes: 180),
      '2026-09-26': const UsageChallengeDay(minutes: 100, goalMinutes: 180),
    };
    expect(usageStreak(days, DateTime(2026, 9, 27)), 1);
  });

  test('today never breaks a completed streak', () {
    final days = <String, UsageChallengeDay>{
      '2026-09-25': const UsageChallengeDay(minutes: 90, goalMinutes: 180),
      '2026-09-26': const UsageChallengeDay(minutes: 80, goalMinutes: 180),
      '2026-09-27': const UsageChallengeDay(minutes: 200, goalMinutes: 180),
    };
    expect(usageStreak(days, DateTime(2026, 9, 27)), 2);
  });

  test('comparison uses only matching completed days', () {
    final mine = <String, UsageChallengeDay>{
      '2026-09-25': const UsageChallengeDay(minutes: 100, goalMinutes: 180),
      '2026-09-26': const UsageChallengeDay(minutes: 80, goalMinutes: 180),
    };
    final sponsor = <String, UsageChallengeDay>{
      '2026-09-25': const UsageChallengeDay(minutes: 120, goalMinutes: 180),
    };
    final comparison = compareUsage(mine, sponsor, DateTime(2026, 9, 27));
    expect(comparison.days, 1);
    expect(comparison.myMinutes, 100);
    expect(comparison.sponsorMinutes, 120);
  });
}
