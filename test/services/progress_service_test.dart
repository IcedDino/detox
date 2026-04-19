import 'package:detox/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('starts a streak on first activation', () async {
      final service = ProgressService.instance;

      await service.activateStreakToday();
      final summary = await service.loadSummary(isEs: true);

      expect(summary.currentStreak, 1);
      expect(summary.longestStreak, 1);
      expect(summary.streakActiveToday, isTrue);
    });

    test('continues the streak when the last active day was yesterday', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final y =
          '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues(<String, Object>{
        'progress_current_streak_v1': 4,
        'progress_longest_streak_v1': 4,
        'progress_last_streak_date_v1': y,
      });

      final service = ProgressService.instance;
      await service.activateStreakToday();
      final summary = await service.loadSummary(isEs: false);

      expect(summary.currentStreak, 5);
      expect(summary.longestStreak, 5);
      expect(summary.streakActiveToday, isTrue);
    });

    test('resets the streak after a gap of more than one day', () async {
      final oldDay = DateTime.now().subtract(const Duration(days: 3));
      final token =
          '${oldDay.year.toString().padLeft(4, '0')}-${oldDay.month.toString().padLeft(2, '0')}-${oldDay.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues(<String, Object>{
        'progress_current_streak_v1': 7,
        'progress_longest_streak_v1': 7,
        'progress_last_streak_date_v1': token,
      });

      final service = ProgressService.instance;
      await service.activateStreakToday();
      final summary = await service.loadSummary(isEs: false);

      expect(summary.currentStreak, 1);
      expect(summary.longestStreak, 7);
    });

    test('updates focus and suggestion counters used by achievements and challenges', () async {
      final service = ProgressService.instance;

      await service.recordFocusStarted();
      await service.recordFocusCompleted();
      await service.recordSuggestionShown();
      await service.recordSuggestionAccepted();
      await service.recordPauseRequested();
      await service.recordPauseApproved();

      final summary = await service.loadSummary(isEs: true);

      expect(summary.focusSessionsStarted, 1);
      expect(summary.focusSessionsCompleted, 1);
      expect(summary.suggestionsShown, 1);
      expect(summary.suggestionsAccepted, 1);
      expect(summary.pauseRequests, 1);
      expect(summary.pauseApprovals, 1);
      expect(summary.dailyChallenges.first.completed, isTrue);
      expect(summary.dailyChallenges[1].completed, isTrue);
      expect(summary.dailyChallenges[2].completed, isTrue);
    });
  });
}
