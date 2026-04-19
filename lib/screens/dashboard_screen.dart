import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/dashboard_data.dart';
import '../services/smart_usage_recommendation_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/detox_logo.dart';
import '../widgets/metric_card.dart';
import '../widgets/top_app_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
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

  String _topAppsTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code == 'es' ? 'Apps más usadas' : 'Top apps';
  }

  @override
  Widget build(BuildContext context) {
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
          final percent = summary == null || limit == 0
              ? 0.0
              : (summary.totalMinutes / limit).clamp(0.0, 1.4);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const DetoxLogo(showLabel: true),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                t.dashboardTitle,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: DetoxColors.accentSoft,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          t.today,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (summary != null && !summary.fromRealUsage)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t.demoDataNotice,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      summary == null ? '--' : _formatMinutes(summary.totalMinutes),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_formatMinutes(limit)} · ${((percent * 100).clamp(0, 140)).round()}%',
                      style: const TextStyle(color: DetoxColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (summary != null)
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: t.pickups,
                        value: '${summary.pickups}',
                        subtitle: '',
                        icon: Icons.touch_app_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        title: t.topApp,
                        value: summary.topApps.isEmpty
                            ? '—'
                            : summary.topApps.first.appName,
                        subtitle: summary.topApps.isEmpty
                            ? ''
                            : t.minToday(summary.topApps.first.minutes),
                        leading: AppIconBadge(
                          packageName: summary.topApps.isEmpty
                              ? null
                              : summary.topApps.first.packageName,
                          iconBytes: summary.topApps.isEmpty
                              ? null
                              : summary.topApps.first.iconBytes,
                          size: 50,
                          borderRadius: 14,
                          fallbackIcon: Icons.auto_graph_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              if (summary != null && summary.topApps.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _topAppsTitle(context),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...summary.topApps
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TopAppTile(
                            entry: entry.value,
                            index: entry.key,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
