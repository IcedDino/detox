import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/progress_models.dart';
import '../services/focus_session_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late Future<ProgressSummary> _future;

  @override
  void initState() {
    super.initState();
    final isEs = WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase().startsWith('es');
    _future = ProgressService.instance.loadSummary(isEs: isEs);
  }

  Future<ProgressSummary> _load() {
    return ProgressService.instance.loadSummary(isEs: AppStrings.of(context).isEs);
  }

  Future<void> _refresh() async {
    final updated = _load();
    setState(() => _future = updated);
    await updated;
  }

  Future<void> _activateStreak() async {
    await ProgressService.instance.activateStreakToday();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).progressStartedSnack)),
    );
    await _refresh();
  }

  Future<void> _startRecommendedHour() async {
    final t = AppStrings.of(context);
    final result = await FocusSessionService.instance.startSession(
      minutes: 60,
      label: t.focusSessionLabel,
      reason: 'manual_progress_focus',
    );

    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.autoFocusStartedSnack)),
      );
      await _refresh();
      return;
    }

    final message = switch (result.code) {
      'usage_permission_missing' => t.grantUsageSnack,
      'overlay_permission_missing' => t.grantOverlaySnack,
      'no_apps_configured' => t.addAppsSnack,
      _ => 'Unable to start focus session.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ProgressSummary>(
        future: _future,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final unlocked = summary.achievements.where((e) => e.unlocked).length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                t.progressTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.progressSubtitle,
                style: const TextStyle(color: DetoxColors.muted),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                        const SizedBox(width: 10),
                        Text(
                          t.currentStreak,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        FilledButton.tonal(
                          onPressed: summary.streakActiveToday ? _startRecommendedHour : _activateStreak,
                          child: Text(summary.streakActiveToday ? t.continueToday : t.startStreak),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricPill(
                            label: t.currentStreak,
                            value: '${summary.currentStreak}',
                            subtitle: t.isEs ? 'días' : 'days',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricPill(
                            label: t.longestStreak,
                            value: '${summary.longestStreak}',
                            subtitle: t.isEs ? 'máximo' : 'best',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricPill(
                            label: t.achievements,
                            value: '$unlocked/${summary.achievements.length}',
                            subtitle: t.isEs ? 'medallas' : 'medals',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: _MiniStat(
                        icon: Icons.play_circle_outline,
                        title: t.isEs ? 'Sesiones iniciadas' : 'Sessions started',
                        value: '${summary.focusSessionsStarted}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      child: _MiniStat(
                        icon: Icons.check_circle_outline,
                        title: t.isEs ? 'Sesiones completadas' : 'Sessions completed',
                        value: '${summary.focusSessionsCompleted}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: _MiniStat(
                        icon: Icons.notifications_active_outlined,
                        title: t.isEs ? 'Sugerencias aceptadas' : 'Accepted suggestions',
                        value: '${summary.suggestionsAccepted}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      child: _MiniStat(
                        icon: Icons.pause_circle_outline,
                        title: t.isEs ? 'Pausas gestionadas' : 'Handled pauses',
                        value: '${summary.pauseRequests}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                t.dailyChallenges,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...summary.dailyChallenges.map(
                (challenge) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Icon(
                          challenge.completed ? Icons.verified_rounded : Icons.radio_button_unchecked,
                          color: challenge.completed ? Colors.greenAccent : DetoxColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                challenge.description,
                                style: const TextStyle(color: DetoxColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t.achievements,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...summary.achievements.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              achievement.unlocked ? Icons.emoji_events_rounded : Icons.lock_outline,
                              color: achievement.unlocked ? Colors.amberAccent : DetoxColors.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                achievement.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Text(
                              '${achievement.progress}/${achievement.goal}',
                              style: const TextStyle(color: DetoxColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          achievement.description,
                          style: const TextStyle(color: DetoxColors.muted),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: achievement.ratio,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: DetoxColors.accentSoft),
                        const SizedBox(width: 10),
                        Text(
                          t.sponsorShowcase,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.sponsorShowcaseBody,
                      style: const TextStyle(color: DetoxColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: DetoxColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: DetoxColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: DetoxColors.accentSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: DetoxColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
