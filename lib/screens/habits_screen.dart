import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/progress_models.dart';
import '../services/focus_session_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final StorageService _storage = StorageService();
  ProgressSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final counters = await _storage.loadProgressCounters();
    final startedToday = await _storage.isProgressStartedToday();
    final current = counters['currentStreak'] ?? 0;
    final best = counters['bestStreak'] ?? 0;
    final achievements = <AchievementItem>[
      AchievementItem(id: 'streak3', title: '🔥 3', body: '3-day streak', unlocked: current >= 3, icon: '🔥'),
      AchievementItem(id: 'focus5', title: '⏱ 5', body: '5 completed sessions', unlocked: (counters['focusCompleted'] ?? 0) >= 5, icon: '⏱'),
      AchievementItem(id: 'smart5', title: '🧠 5', body: '5 smart suggestions accepted', unlocked: (counters['suggestionsAccepted'] ?? 0) >= 5, icon: '🧠'),
      AchievementItem(id: 'pomodoro8', title: '🍅 8', body: '8 Pomodoro cycles', unlocked: (counters['pomodoroCyclesCompleted'] ?? 0) >= 8, icon: '🍅'),
    ];
    final dailyChallenges = <DailyChallengeItem>[
      DailyChallengeItem(id: 'activate', title: 'Activate progress today', done: startedToday),
      DailyChallengeItem(id: 'smart', title: 'Accept 1 smart suggestion', done: (counters['suggestionsAccepted'] ?? 0) > 0),
      DailyChallengeItem(id: 'focus', title: 'Complete 1 focus session', done: (counters['focusCompleted'] ?? 0) > 0),
    ];
    if (!mounted) return;
    setState(() {
      _snapshot = ProgressSnapshot(
        startedToday: startedToday,
        currentStreak: current,
        longestStreak: best,
        sessionsStarted: counters['focusStarted'] ?? 0,
        sessionsCompleted: counters['focusCompleted'] ?? 0,
        suggestionsShown: counters['suggestionsShown'] ?? 0,
        suggestionsAccepted: counters['suggestionsAccepted'] ?? 0,
        suggestionsDenied: counters['suggestionsDenied'] ?? 0,
        pauseRequests: counters['pauseRequests'] ?? 0,
        pauseApproved: counters['pauseApproved'] ?? 0,
        pauseRejected: counters['pauseRejected'] ?? 0,
        pomodoroCyclesCompleted: counters['pomodoroCyclesCompleted'] ?? 0,
        achievements: achievements,
        dailyChallenges: dailyChallenges,
      );
      _loading = false;
    });
  }

  Future<void> _startProgressDay() async {
    await _storage.markProgressStartedToday();
    await FocusSessionService.instance.startQuickFocusHour();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).progressStartedSnack)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final snapshot = _snapshot;
    if (_loading || snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(t.progressTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t.progressMedalsSubtitle, style: const TextStyle(color: DetoxColors.muted)),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.currentStreak, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _BigMetric(icon: Icons.local_fire_department, value: '${snapshot.currentStreak}', label: t.currentStreak)),
                  const SizedBox(width: 12),
                  Expanded(child: _BigMetric(icon: Icons.emoji_events_outlined, value: '${snapshot.longestStreak}', label: t.longestStreak)),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _startProgressDay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(snapshot.startedToday ? t.continueToday : t.startStreak),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.achievements, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: snapshot.achievements.map((item) => Container(
                  width: 145,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: item.unlocked ? Theme.of(context).colorScheme.primary.withOpacity(0.14) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item.body, style: const TextStyle(color: DetoxColors.muted, fontSize: 12)),
                  ]),
                )).toList(),
              )
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.dailyChallenges, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...snapshot.dailyChallenges.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.done ? Icons.check_circle : Icons.radio_button_unchecked, color: item.done ? Colors.greenAccent : DetoxColors.muted),
                title: Text(item.title),
              )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.sponsorShowcase, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(t.sponsorShowcaseBody, style: const TextStyle(color: DetoxColors.muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PillStat(label: t.sessionsCompleted, value: '${snapshot.sessionsCompleted}'),
                  _PillStat(label: t.suggestionsAccepted, value: '${snapshot.suggestionsAccepted}'),
                  _PillStat(label: t.pomodoroCycles, value: '${snapshot.pomodoroCyclesCompleted}'),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: DetoxColors.accentSoft),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: DetoxColors.muted)),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  const _PillStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      ),
      child: Text('$label · $value'),
    );
  }
}
