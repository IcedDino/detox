class ProgressSummary {
  const ProgressSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.focusSessionsStarted,
    required this.focusSessionsCompleted,
    required this.suggestionsShown,
    required this.suggestionsAccepted,
    required this.suggestionsDenied,
    required this.pauseRequests,
    required this.pauseApprovals,
    required this.pauseDenials,
    required this.streakActiveToday,
    required this.achievements,
    required this.dailyChallenges,
  });

  final int currentStreak;
  final int longestStreak;
  final int focusSessionsStarted;
  final int focusSessionsCompleted;
  final int suggestionsShown;
  final int suggestionsAccepted;
  final int suggestionsDenied;
  final int pauseRequests;
  final int pauseApprovals;
  final int pauseDenials;
  final bool streakActiveToday;
  final List<AchievementItem> achievements;
  final List<DailyChallengeItem> dailyChallenges;
}

class AchievementItem {
  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.goal,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int goal;
  final bool unlocked;

  double get ratio {
    if (goal <= 0) return unlocked ? 1 : 0;
    return (progress / goal).clamp(0, 1).toDouble();
  }
}

class DailyChallengeItem {
  const DailyChallengeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
  });

  final String id;
  final String title;
  final String description;
  final bool completed;
}
