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
      AchievementItem(
        id: 'streak3',
        title: '🔥 3',
        body: '3-day streak',
        unlocked: current >= 3,
        progress: current,
        goal: 3,
        icon: '🔥',
      ),
      AchievementItem(
        id: 'focus5',
        title: '⏱ 5',
        body: '5 sessions',
        unlocked: (counters['focusCompleted'] ?? 0) >= 5,
        progress: counters['focusCompleted'] ?? 0,
        goal: 5,
        icon: '⏱',
      ),
      AchievementItem(
        id: 'smart5',
        title: '🧠 5',
        body: '5 accepted tips',
        unlocked: (counters['suggestionsAccepted'] ?? 0) >= 5,
        progress: counters['suggestionsAccepted'] ?? 0,
        goal: 5,
        icon: '🧠',
      ),
      AchievementItem(
        id: 'pomodoro8',
        title: '🍅 8',
        body: '8 cycles',
        unlocked: (counters['pomodoroCyclesCompleted'] ?? 0) >= 8,
        progress: counters['pomodoroCyclesCompleted'] ?? 0,
        goal: 8,
        icon: '🍅',
      ),
    ];

    final dailyChallenges = <DailyChallengeItem>[
      DailyChallengeItem(
        id: 'activate',
        title: 'Start today',
        done: startedToday,
      ),
      DailyChallengeItem(
        id: 'smart',
        title: 'Accept 1 tip',
        done: (counters['suggestionsAccepted'] ?? 0) > 0,
      ),
      DailyChallengeItem(
        id: 'focus',
        title: 'Complete 1 session',
        done: (counters['focusCompleted'] ?? 0) > 0,
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).progressStartedSnack)),
    );
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
        Text(
          t.progressTitle,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BigMetric(
                      icon: Icons.local_fire_department,
                      value: '${snapshot.currentStreak}',
                      label: t.currentStreak,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigMetric(
                      icon: Icons.emoji_events_outlined,
                      value: '${snapshot.longestStreak}',
                      label: t.longestStreak,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _startProgressDay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  snapshot.startedToday ? t.continueToday : t.startStreak,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.achievements,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 760 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.achievements.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.88,
                    ),
                    itemBuilder: (context, index) {
                      final item = snapshot.achievements[index];
                      return _AchievementCard(item: item);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.dailyChallenges,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...snapshot.dailyChallenges.map(
                    (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                    item.done ? Colors.greenAccent : DetoxColors.muted,
                  ),
                  title: Text(item.title),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PillStat(
                label: t.sessionsCompleted,
                value: '${snapshot.sessionsCompleted}',
              ),
              _PillStat(
                label: t.suggestionsAccepted,
                value: '${snapshot.suggestionsAccepted}',
              ),
              _PillStat(
                label: t.pomodoroCycles,
                value: '${snapshot.pomodoroCyclesCompleted}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item});

  final AchievementItem item;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    final progressLabel =
    item.goal > 0 ? '${item.progress.clamp(0, item.goal)}/${item.goal}' : null;
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = unlocked
        ? primary.withOpacity(0.28)
        : Colors.white.withOpacity(0.06);
    final background = unlocked ? primary.withOpacity(0.14) : const Color(0xFF161A20);
    final textColor = unlocked ? Colors.white : Colors.white.withOpacity(0.70);
    final mutedColor = unlocked
        ? DetoxColors.muted
        : Colors.white.withOpacity(0.48);
    final badgeColor = unlocked
        ? primary.withOpacity(0.16)
        : Colors.white.withOpacity(0.06);

    Widget content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(item.icon, style: const TextStyle(fontSize: 24)),
              ),
              const Spacer(),
              Icon(
                unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
                size: 18,
                color: unlocked ? DetoxColors.accentSoft : mutedColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const Spacer(),
          if (progressLabel != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: item.ratio,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  unlocked ? DetoxColors.accentSoft : Colors.white38,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                unlocked ? 'Done' : progressLabel,
                style: TextStyle(
                  color: unlocked ? DetoxColors.accentSoft : mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!unlocked) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: content,
      );
    }

    return content;
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
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
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
