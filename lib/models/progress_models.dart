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
    this.pomodoroCyclesCompleted = 0,
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
  final int pomodoroCyclesCompleted;
  final List<AchievementItem> achievements;
  final List<DailyChallengeItem> dailyChallenges;

  bool get startedToday => streakActiveToday;
  int get sessionsStarted => focusSessionsStarted;
  int get sessionsCompleted => focusSessionsCompleted;
  int get pauseApproved => pauseApprovals;
  int get pauseRejected => pauseDenials;
}

class ProgressSnapshot extends ProgressSummary {
  const ProgressSnapshot({
    required bool startedToday,
    required int currentStreak,
    required int longestStreak,
    required int sessionsStarted,
    required int sessionsCompleted,
    required int suggestionsShown,
    required int suggestionsAccepted,
    required int suggestionsDenied,
    required int pauseRequests,
    required int pauseApproved,
    required int pauseRejected,
    required int pomodoroCyclesCompleted,
    required List<AchievementItem> achievements,
    required List<DailyChallengeItem> dailyChallenges,
  }) : super(
          currentStreak: currentStreak,
          longestStreak: longestStreak,
          focusSessionsStarted: sessionsStarted,
          focusSessionsCompleted: sessionsCompleted,
          suggestionsShown: suggestionsShown,
          suggestionsAccepted: suggestionsAccepted,
          suggestionsDenied: suggestionsDenied,
          pauseRequests: pauseRequests,
          pauseApprovals: pauseApproved,
          pauseDenials: pauseRejected,
          streakActiveToday: startedToday,
          pomodoroCyclesCompleted: pomodoroCyclesCompleted,
          achievements: achievements,
          dailyChallenges: dailyChallenges,
        );
}

class AchievementItem {
  const AchievementItem({
    required this.id,
    required this.title,
    String? body,
    String? description,
    this.progress = 0,
    this.goal = 0,
    required this.unlocked,
    this.icon = '🏅',
  }) : body = body ?? description ?? '';

  final String id;
  final String title;
  final String body;
  final int progress;
  final int goal;
  final bool unlocked;
  final String icon;

  String get description => body;

  double get ratio {
    if (goal <= 0) return unlocked ? 1 : 0;
    final value = progress / goal;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

class DailyChallengeItem {
  const DailyChallengeItem({
    required this.id,
    required this.title,
    this.description = '',
    bool? done,
    bool? completed,
  }) : done = done ?? completed ?? false;

  final String id;
  final String title;
  final String description;
  final bool done;

  bool get completed => done;
}
