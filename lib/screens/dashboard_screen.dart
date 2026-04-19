import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/dashboard_data.dart';
import '../services/smart_usage_recommendation_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/detox_logo.dart';
import '../widgets/top_app_tile.dart';
import '../widgets/ui_kit.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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

  String _progressLabel(AppStrings t, double progress) {
    final pct = (progress * 100).round();
    return t.isEs ? '$pct% de tu meta diaria' : '$pct% of your daily goal';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);

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
          final topApp = (summary != null && summary.topApps.isNotEmpty)
              ? summary.topApps.first
              : null;
          final totalMinutes = summary?.totalMinutes ?? 0;
          final percent = limit == 0
              ? 0.0
              : (totalMinutes / limit).clamp(0.0, 1.3);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Row(
                children: [
                  const DetoxLogo(size: 34),
                  const SizedBox(width: 10),
                  Text(
                    'Detox',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.82),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              HeroInfoCard(
                icon: Icons.timelapse_rounded,
                title: t.isEs ? 'Resumen de hoy' : 'Today overview',
                subtitle: _friendlyUsageLabel(t, totalMinutes, limit),
                badge: summary != null && !summary.fromRealUsage
                    ? StatusPill(
                        label: t.demoDataNotice,
                        icon: Icons.info_outline_rounded,
                        color: DetoxColors.warning,
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          summary == null ? '--' : _formatMinutes(totalMinutes),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 0.95,
                              ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            t.isEs ? 'usados hoy' : 'used today',
                            style: const TextStyle(color: DetoxColors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_formatMinutes(limit)} · ${_progressLabel(t, percent)}',
                      style: const TextStyle(color: DetoxColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FriendlyStatTile(
                            label: t.pickups,
                            value: '${summary?.pickups ?? 0}',
                            helper: t.isEs
                                ? 'desbloqueos estimados'
                                : 'estimated unlocks',
                            icon: Icons.touch_app_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FriendlyStatTile(
                            label: t.topApp,
                            value: topApp?.appName ?? '—',
                            helper: topApp == null
                                ? (t.isEs
                                    ? 'sin datos todavía'
                                    : 'no data yet')
                                : t.minToday(topApp.minutes),
                            icon: Icons.star_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (topApp != null)
                GlassCard(
                  child: Row(
                    children: [
                      AppIconBadge(
                        packageName: topApp.packageName,
                        iconBytes: topApp.iconBytes,
                        size: 56,
                        borderRadius: 16,
                        fallbackIcon: Icons.auto_graph_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.isEs
                                  ? 'Tu app más demandante'
                                  : 'Your most demanding app',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              topApp.appName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.isEs
                                  ? 'Lleva ${topApp.minutes} minutos hoy. Es una buena candidata para entrar en bloqueo.'
                                  : 'It has ${topApp.minutes} minutes today. It is a strong candidate for blocking.',
                              style: const TextStyle(
                                color: DetoxColors.muted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SectionTitle(title: t.topAppsToday),
              const SizedBox(height: 12),
              if (summary == null || summary.topApps.isEmpty)
                GlassCard(
                  child: Text(
                    t.noAppUsageYet,
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                )
              else
                GlassCard(
                  child: Column(
                    children: summary.topApps
                        .take(5)
                        .toList()
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key == 4 ? 0 : 10,
                            ),
                            child: TopAppTile(
                              entry: entry.value,
                              index: entry.key,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
