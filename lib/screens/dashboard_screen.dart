import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/dashboard_data.dart';
import '../services/smart_usage_recommendation_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/top_app_tile.dart';
import '../widgets/ui_kit.dart';

/// "Today" screen. Answers one question: how am I doing?
/// One hero number, one primary action, three supporting apps.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onStartFocus});

  /// Called when the user taps the single primary action.
  final VoidCallback? onStartFocus;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final UsageService _usageService = UsageService();
  final StorageService _storageService = StorageService();

  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _future = _load());
    }
  }

  Future<DashboardData> _load() async {
    final summary = await _usageService.getTodaySummary();
    final limit = await _storageService.loadDailyLimitMinutes();
    final strings = AppStrings(
      Localizations.maybeLocaleOf(context) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );

    if (summary.topApps.isNotEmpty) {
      await SmartUsageRecommendationService.instance.evaluateTopApp(
        entry: summary.topApps.first,
        strings: strings,
      );
    }

    return DashboardData(summary: summary, dailyLimit: limit);
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  String _friendlyUsageLabel(AppStrings t, int total, int limit) {
    if (total == 0) {
      return t.isEs
          ? 'Todavía no hay actividad registrada.'
          : 'No activity has been recorded yet.';
    }
    if (total <= limit * 0.6) {
      return t.isEs
          ? 'Vas por buen ritmo y todavía tienes margen.'
          : 'You are on a healthy pace and still have room left.';
    }
    if (total <= limit) {
      return t.isEs
          ? 'Vas cerca de tu meta diaria. Un bloque de enfoque puede ayudarte.'
          : 'You are getting close to your daily goal. A focus block could help.';
    }
    return t.isEs
        ? 'Hoy ya superaste tu meta. Conviene proteger las apps que más te distraen.'
        : 'You already passed your goal today. It may help to protect the apps that distract you most.';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load());
        await _future;
      },
      child: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final summary = data?.summary;
          final limit = data?.dailyLimit ?? 180;
          final topApps = (summary?.topApps ?? const []).take(3).toList();
          final totalMinutes = summary?.totalMinutes ?? 0;
          final remaining = (limit - totalMinutes).clamp(0, limit);
          final percent = limit == 0 ? 0.0 : (totalMinutes / limit).clamp(0.0, 1.0);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              // ── Hero: the single number that matters ──
              Text(
                t.isEs ? 'HOY' : 'TODAY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: muted,
                      letterSpacing: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                summary == null ? '--' : _formatMinutes(totalMinutes),
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 6),
              Text(
                t.isEs
                    ? 'de ${_formatMinutes(limit)} de tu meta diaria'
                    : 'of your ${_formatMinutes(limit)} daily goal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(detoxRadiusPill),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _friendlyUsageLabel(t, totalMinutes, limit),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (summary != null && !summary.fromRealUsage) ...[
                const SizedBox(height: 10),
                Text(
                  t.usageUnavailableNotice,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DetoxColors.warning,
                      ),
                ),
              ],

              if (summary != null) ...[
                const SizedBox(height: 24),

                // ── Supporting metrics: estimated pickups + top app ──
                Row(
                  children: [
                    Expanded(
                      child: FriendlyStatTile(
                        label: t.estimatedUnlocks,
                        value: '${summary.pickups}',
                        helper: t.today,
                        icon: Icons.touch_app_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FriendlyStatTile(
                        label: t.topApp,
                        value: topApps.isEmpty ? '—' : topApps.first.appName,
                        helper: topApps.isEmpty
                            ? t.noDataYet
                            : t.minToday(topApps.first.minutes),
                        icon: Icons.star_outline_rounded,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // ── The one primary action ──
              FilledButton.icon(
                onPressed: widget.onStartFocus,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(t.isEs ? 'Empezar enfoque' : 'Start focus'),
              ),

              const SizedBox(height: 28),

              // ── Supporting data: top 3 apps ──
              Text(
                t.topAppsToday,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (summary == null || summary.topApps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(detoxRadius),
                    border: Border.all(
                      color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
                    ),
                  ),
                  child: Text(
                    t.noAppUsageYet,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                )
              else
                ...topApps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TopAppTile(
                          entry: entry.value,
                          index: entry.key,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
