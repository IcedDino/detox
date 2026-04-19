import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/progress_models.dart';
import '../services/focus_session_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> with AutomaticKeepAliveClientMixin {
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);
    final snapshot = _snapshot;
    if (_loading || snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          t.habits,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        HeroInfoCard(
          icon: Icons.local_fire_department_rounded,
          title: t.isEs ? 'Tu racha actual' : 'Your current streak',
          subtitle: snapshot.startedToday
              ? (t.isEs ? 'Hoy ya registraste actividad positiva.' : 'You already logged positive activity today.')
              : (t.isEs ? 'Todavía puedes empezar hoy con una sesión rápida.' : 'You can still begin today with a quick session.'),
          badge: StatusPill(
            label: snapshot.startedToday
                ? (t.isEs ? 'Hoy activo' : 'Today active')
                : (t.isEs ? 'Pendiente' : 'Pending'),
            icon: snapshot.startedToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
            color: snapshot.startedToday ? DetoxColors.success : DetoxColors.warning,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FriendlyStatTile(
                      label: t.currentStreak,
                      value: '${snapshot.currentStreak}',
                      helper: t.isEs ? 'días seguidos' : 'days in a row',
                      icon: Icons.local_fire_department_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FriendlyStatTile(
                      label: t.longestStreak,
                      value: '${snapshot.longestStreak}',
                      helper: t.isEs ? 'mejor marca' : 'best record',
                      icon: Icons.emoji_events_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startProgressDay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(snapshot.startedToday ? t.continueToday : t.startStreak),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(
          title: t.achievements,
          subtitle: t.isEs
              ? 'Pequeños hitos que te ayudan a notar tu avance real.'
              : 'Small milestones that help you notice your real progress.',
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: LayoutBuilder(
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
        ),
        const SizedBox(height: 16),
        SectionTitle(
          title: t.dailyChallenges,
          subtitle: t.isEs
              ? 'Tres acciones simples para mantener el día encaminado.'
              : 'Three simple actions to keep the day on track.',
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: snapshot.dailyChallenges.map(
              (item) {
                final done = item.done;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftActionTile(
                    icon: done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: done ? DetoxColors.success : DetoxColors.accentSoft,
                    title: item.title,
                    subtitle: done
                        ? (t.isEs ? 'Completado por hoy.' : 'Completed for today.')
                        : (t.isEs ? 'Aún puedes hacerlo hoy.' : 'You can still complete it today.'),
                    trailing: StatusPill(
                      label: done ? (t.isEs ? 'Hecho' : 'Done') : (t.isEs ? 'Pendiente' : 'Pending'),
                      color: done ? DetoxColors.success : DetoxColors.warning,
                    ),
                  ),
                );
              },
            ).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(
          title: t.isEs ? 'Resumen rápido' : 'Quick summary',
          subtitle: t.isEs
              ? 'Las señales más útiles de tu progreso reciente.'
              : 'The most useful signs of your recent progress.',
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PillStat(label: t.sessionsCompleted, value: '${snapshot.sessionsCompleted}'),
              _PillStat(label: t.suggestionsAccepted, value: '${snapshot.suggestionsAccepted}'),
              _PillStat(label: t.pomodoroCycles, value: '${snapshot.pomodoroCyclesCompleted}'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = unlocked
        ? primary.withOpacity(0.28)
        : (isDark ? Colors.white.withOpacity(0.06) : DetoxColors.lightCardBorder);
    final background = unlocked
        ? primary.withOpacity(isDark ? 0.16 : 0.10)
        : (isDark ? Colors.white.withOpacity(0.035) : const Color(0xFFF8FAFF));
    final textColor = unlocked
        ? (isDark ? Colors.white : DetoxColors.lightText)
        : (isDark ? Colors.white.withOpacity(0.78) : DetoxColors.lightText.withOpacity(0.78));
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

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
                  color: unlocked
                      ? primary.withOpacity(0.16)
                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.white),
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
                backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE6EEFF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  unlocked ? DetoxColors.accentSoft : mutedColor,
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
