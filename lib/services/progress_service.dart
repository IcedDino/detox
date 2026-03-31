import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_models.dart';

class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  static const _currentStreakKey = 'progress_current_streak_v1';
  static const _longestStreakKey = 'progress_longest_streak_v1';
  static const _lastStreakDateKey = 'progress_last_streak_date_v1';
  static const _focusStartedKey = 'progress_focus_started_v1';
  static const _focusCompletedKey = 'progress_focus_completed_v1';
  static const _suggestionsShownKey = 'progress_suggestions_shown_v1';
  static const _suggestionsAcceptedKey = 'progress_suggestions_accepted_v1';
  static const _suggestionsDeniedKey = 'progress_suggestions_denied_v1';
  static const _pauseRequestsKey = 'progress_pause_requests_v1';
  static const _pauseApprovalsKey = 'progress_pause_approvals_v1';
  static const _pauseDenialsKey = 'progress_pause_denials_v1';
  static const _todayAcceptedKey = 'progress_today_suggestions_accepted_v1';
  static const _todayFocusCompletedKey = 'progress_today_focus_completed_v1';
  static const _todayFocusStartedKey = 'progress_today_focus_started_v1';
  static const _todayResetDateKey = 'progress_today_reset_date_v1';

  Future<void> activateStreakToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);

    final today = _dayKey(DateTime.now());
    final lastDay = prefs.getString(_lastStreakDateKey);
    var current = prefs.getInt(_currentStreakKey) ?? 0;

    if (lastDay == today) {
      return;
    }

    if (lastDay != null) {
      final diff = _dateDiff(lastDay, today);
      current = diff == 1 ? current + 1 : 1;
    } else {
      current = 1;
    }

    final longest = prefs.getInt(_longestStreakKey) ?? 0;
    await prefs.setString(_lastStreakDateKey, today);
    await prefs.setInt(_currentStreakKey, current);
    if (current > longest) {
      await prefs.setInt(_longestStreakKey, current);
    }
  }

  Future<void> recordFocusStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await activateStreakToday();
    await prefs.setInt(_focusStartedKey, (prefs.getInt(_focusStartedKey) ?? 0) + 1);
    await prefs.setInt(_todayFocusStartedKey, (prefs.getInt(_todayFocusStartedKey) ?? 0) + 1);
  }

  Future<void> recordFocusCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await activateStreakToday();
    await prefs.setInt(_focusCompletedKey, (prefs.getInt(_focusCompletedKey) ?? 0) + 1);
    await prefs.setInt(_todayFocusCompletedKey, (prefs.getInt(_todayFocusCompletedKey) ?? 0) + 1);
  }

  Future<void> recordSuggestionShown() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await prefs.setInt(_suggestionsShownKey, (prefs.getInt(_suggestionsShownKey) ?? 0) + 1);
  }

  Future<void> recordSuggestionAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await activateStreakToday();
    await prefs.setInt(_suggestionsAcceptedKey, (prefs.getInt(_suggestionsAcceptedKey) ?? 0) + 1);
    await prefs.setInt(_todayAcceptedKey, (prefs.getInt(_todayAcceptedKey) ?? 0) + 1);
  }

  Future<void> recordSuggestionDenied() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await prefs.setInt(_suggestionsDeniedKey, (prefs.getInt(_suggestionsDeniedKey) ?? 0) + 1);
  }

  Future<void> recordPauseRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseRequestsKey, (prefs.getInt(_pauseRequestsKey) ?? 0) + 1);
  }

  Future<void> recordPauseApproved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseApprovalsKey, (prefs.getInt(_pauseApprovalsKey) ?? 0) + 1);
  }

  Future<void> recordPauseDenied() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pauseDenialsKey, (prefs.getInt(_pauseDenialsKey) ?? 0) + 1);
  }

  Future<ProgressSummary> loadSummary({required bool isEs}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);

    final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
    final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    final focusSessionsStarted = prefs.getInt(_focusStartedKey) ?? 0;
    final focusSessionsCompleted = prefs.getInt(_focusCompletedKey) ?? 0;
    final suggestionsShown = prefs.getInt(_suggestionsShownKey) ?? 0;
    final suggestionsAccepted = prefs.getInt(_suggestionsAcceptedKey) ?? 0;
    final suggestionsDenied = prefs.getInt(_suggestionsDeniedKey) ?? 0;
    final pauseRequests = prefs.getInt(_pauseRequestsKey) ?? 0;
    final pauseApprovals = prefs.getInt(_pauseApprovalsKey) ?? 0;
    final pauseDenials = prefs.getInt(_pauseDenialsKey) ?? 0;
    final streakActiveToday = prefs.getString(_lastStreakDateKey) == _dayKey(DateTime.now());

    final achievements = <AchievementItem>[
      AchievementItem(
        id: 'streak_3',
        title: isEs ? '🔥 Racha inicial' : '🔥 Starter streak',
        description: isEs ? 'Mantén 3 días de racha.' : 'Keep a 3-day streak.',
        progress: currentStreak,
        goal: 3,
        unlocked: currentStreak >= 3,
      ),
      AchievementItem(
        id: 'focus_5',
        title: isEs ? '⏱️ Enfoque constante' : '⏱️ Steady focus',
        description: isEs ? 'Completa 5 sesiones de enfoque.' : 'Complete 5 focus sessions.',
        progress: focusSessionsCompleted,
        goal: 5,
        unlocked: focusSessionsCompleted >= 5,
      ),
      AchievementItem(
        id: 'suggestions_5',
        title: isEs ? '🧠 Disciplina I' : '🧠 Discipline I',
        description: isEs ? 'Acepta 5 recomendaciones automáticas.' : 'Accept 5 automatic recommendations.',
        progress: suggestionsAccepted,
        goal: 5,
        unlocked: suggestionsAccepted >= 5,
      ),
      AchievementItem(
        id: 'pause_3',
        title: isEs ? '🛡️ Pausas bajo control' : '🛡️ Pauses under control',
        description: isEs ? 'Gestiona 3 solicitudes de pausa.' : 'Handle 3 pause requests.',
        progress: pauseRequests,
        goal: 3,
        unlocked: pauseRequests >= 3,
      ),
    ];

    final dailyChallenges = <DailyChallengeItem>[
      DailyChallengeItem(
        id: 'today_accept',
        title: isEs ? 'Acepta una recomendación' : 'Accept one recommendation',
        description: isEs ? 'Inicia una hora de concentración desde una alerta automática.' : 'Start one focus hour from an automatic alert.',
        completed: (prefs.getInt(_todayAcceptedKey) ?? 0) >= 1,
      ),
      DailyChallengeItem(
        id: 'today_focus',
        title: isEs ? 'Completa una sesión' : 'Complete one session',
        description: isEs ? 'Termina al menos una sesión de enfoque hoy.' : 'Finish at least one focus session today.',
        completed: (prefs.getInt(_todayFocusCompletedKey) ?? 0) >= 1,
      ),
      DailyChallengeItem(
        id: 'today_streak',
        title: isEs ? 'Mantén tu racha' : 'Keep your streak alive',
        description: isEs ? 'Registra actividad de enfoque hoy.' : 'Log focus activity today.',
        completed: streakActiveToday,
      ),
    ];

    return ProgressSummary(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      focusSessionsStarted: focusSessionsStarted,
      focusSessionsCompleted: focusSessionsCompleted,
      suggestionsShown: suggestionsShown,
      suggestionsAccepted: suggestionsAccepted,
      suggestionsDenied: suggestionsDenied,
      pauseRequests: pauseRequests,
      pauseApprovals: pauseApprovals,
      pauseDenials: pauseDenials,
      streakActiveToday: streakActiveToday,
      achievements: achievements,
      dailyChallenges: dailyChallenges,
    );
  }

  Future<void> _ensureDailyReset(SharedPreferences prefs) async {
    final today = _dayKey(DateTime.now());
    final lastReset = prefs.getString(_todayResetDateKey);
    if (lastReset == today) return;
    await prefs.setString(_todayResetDateKey, today);
    await prefs.setInt(_todayAcceptedKey, 0);
    await prefs.setInt(_todayFocusCompletedKey, 0);
    await prefs.setInt(_todayFocusStartedKey, 0);
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  int _dateDiff(String fromDay, String toDay) {
    final from = DateTime.parse(fromDay);
    final to = DateTime.parse(toDay);
    return DateTime(to.year, to.month, to.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;
  }
}
