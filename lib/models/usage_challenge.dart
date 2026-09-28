class UsageChallengeDay {
  const UsageChallengeDay({required this.minutes, required this.goalMinutes});

  final int minutes;
  final int goalMinutes;
}

class UsageComparison {
  const UsageComparison({
    required this.days,
    required this.myMinutes,
    required this.sponsorMinutes,
  });

  final int days;
  final int myMinutes;
  final int sponsorMinutes;
}

String usageDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

int usageStreak(Map<String, UsageChallengeDay> days, DateTime today) {
  var count = 0;
  for (var offset = 1; offset <= 365; offset++) {
    final day = DateTime(today.year, today.month, today.day - offset);
    final value = days[usageDayKey(day)];
    if (value == null || value.minutes > value.goalMinutes) break;
    count++;
  }
  return count;
}

UsageComparison compareUsage(
  Map<String, UsageChallengeDay> mine,
  Map<String, UsageChallengeDay> sponsor,
  DateTime today,
) {
  var days = 0;
  var myMinutes = 0;
  var sponsorMinutes = 0;
  for (var offset = 1; offset <= 7; offset++) {
    final key = usageDayKey(
      DateTime(today.year, today.month, today.day - offset),
    );
    final myDay = mine[key];
    final sponsorDay = sponsor[key];
    if (myDay == null || sponsorDay == null) continue;
    days++;
    myMinutes += myDay.minutes;
    sponsorMinutes += sponsorDay.minutes;
  }
  return UsageComparison(
    days: days,
    myMinutes: myMinutes,
    sponsorMinutes: sponsorMinutes,
  );
}
