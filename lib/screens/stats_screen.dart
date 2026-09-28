import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/usage_challenge.dart';
import '../models/usage_models.dart';
import '../services/storage_service.dart';
import '../services/usage_challenge_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.isCurrentPage = true, this.demo = false});

  final bool isCurrentPage;
  final bool demo;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// Weekly minutes plus the user's configured daily goal, loaded together so
/// the insight text always matches the limit set in Settings.
class _StatsData {
  const _StatsData({
    required this.weekly,
    required this.dailyLimitMinutes,
    required this.challenge,
  });

  final List<int> weekly;
  final int dailyLimitMinutes;
  final Future<UsageChallengeSnapshot> challenge;
}

class _StatsScreenState extends State<StatsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final UsageService _usageService = UsageService();
  final StorageService _storageService = StorageService();

  late Future<_StatsData> _future;
  Timer? _midnightRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _scheduleMidnightRefresh();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isCurrentPage && widget.isCurrentPage) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleMidnightRefresh();
      _refresh();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightRefreshTimer = Timer(nextMidnight.difference(now), () {
      _scheduleMidnightRefresh();
      _refresh();
    });
  }

  void _refresh() {
    if (mounted && widget.isCurrentPage) {
      setState(() => _future = _load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightRefreshTimer?.cancel();
    super.dispose();
  }

  Future<_StatsData> _load() async {
    if (kIsWeb || widget.demo) {
      return _StatsData(
        weekly: const [145, 110, 130, 95, 120, 85, 105],
        dailyLimitMinutes: 180,
        challenge: Future.value(
          const UsageChallengeSnapshot(
            streak: 4,
            hasUsageAccess: true,
            hasSponsor: true,
            sponsorName: 'Padrino',
            comparison: UsageComparison(
              days: 7,
              myMinutes: 790,
              sponsorMinutes: 910,
            ),
            comparisonEnabled: true,
          ),
        ),
      );
    }
    final results = await Future.wait<dynamic>([
      _usageService.getWeeklyUsage(),
      _storageService.loadDailyLimitMinutes(),
    ]);
    final weekly = results[0] as List<WeeklyUsagePoint>;
    final dailyLimit = results[1] as int;
    return _StatsData(
      weekly: weekly.map((e) => e.minutes).toList(),
      dailyLimitMinutes: dailyLimit,
      challenge: UsageChallengeService().load(dailyLimit),
    );
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
        final nextFuture = _load();
        setState(() {
          _future = nextFuture;
        });
        await nextFuture;
      },
      child: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final weekly = data?.weekly ?? const <int>[];
          final dailyLimit = data?.dailyLimitMinutes ?? 180;
          final isLoading = snapshot.connectionState != ConnectionState.done;
          final hasUsage = weekly.isNotEmpty && weekly.any((e) => e > 0);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              AppPageHeader(title: t.stats, subtitle: t.statsWeeklySubtitle),
              if (kIsWeb || widget.demo)
                Text(
                  t.isEs ? 'Vista demo' : 'Demo view',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted),
                ),
              const SizedBox(height: 18),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.isEs
                            ? 'No se pudieron cargar las estadísticas'
                            : 'Could not load stats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(t.isEs ? 'Reintentar' : 'Retry'),
                      ),
                    ],
                  ),
                )
              else if (!hasUsage)
                _EmptyWeeklyState(muted: muted)
              else ...[
                _WeeklySummaryCard(
                  weekly: weekly,
                  dailyLimitMinutes: dailyLimit,
                  muted: muted,
                ),
                const SizedBox(height: 16),
                SectionTitle(title: t.isEs ? 'Uso por día' : 'Usage by day'),
                const SizedBox(height: 12),
                _WeeklyBarChart(weekly: weekly),
              ],
              if (data != null) ...[
                const SizedBox(height: 24),
                _ChallengeSection(future: data.challenge, onRefresh: _refresh,
                    demo: widget.demo),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// True when at least 5 of the 7 tracked days stayed under the daily goal.
bool _weeklyGoalMet(List<int> weekly, int dailyLimitMinutes) {
  return weekly.where((e) => e <= dailyLimitMinutes).length >= 5;
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    required this.weekly,
    required this.dailyLimitMinutes,
    required this.muted,
  });

  final List<int> weekly;
  final int dailyLimitMinutes;
  final Color muted;

  String _averageLabel() {
    final total = weekly.fold<int>(0, (sum, value) => sum + value);
    final avg = weekly.isEmpty ? 0 : (total / weekly.length).round();
    return '${avg}m';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final goalMet = _weeklyGoalMet(weekly, dailyLimitMinutes);
    final hasTrend = weekly.length > 1;
    final trendDown = weekly.last <= weekly.first;

    return HeroInfoCard(
      title: t.statsWeeklyTitle,
      subtitle: !hasTrend
          ? (t.isEs ? 'La semana comienza hoy.' : 'The week starts today.')
          : (trendDown ? t.statsTrendDown : t.statsTrendUp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _averageLabel(),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 4),
          Text(
            t.isEs ? 'promedio diario' : 'daily average',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          Text(
            goalMet ? t.statsGoalMet : t.statsGoalMiss,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.weekly});

  final List<int> weekly;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final days = t.weekDayLabels;
    final maxY = (weekly.reduce((a, b) => a > b ? a : b) + 20).toDouble();

    return GlassCard(
      child: SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              horizontalInterval: 60,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: DetoxColors.cardBorder),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  reservedSize: 42,
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: DetoxColors.muted,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= days.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        days[index],
                        style: const TextStyle(color: DetoxColors.muted),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(
              weekly.length,
              (index) => BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: weekly[index].toDouble(),
                    width: 18,
                    // Half of the system radius keeps the bar soft without
                    // inventing a new design value.
                    color: DetoxColors.accentSoft,
                    borderRadius: BorderRadius.circular(detoxRadius / 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeSection extends StatelessWidget {
  const _ChallengeSection({required this.future, required this.onRefresh,
      required this.demo});

  final Future<UsageChallengeSnapshot> future;
  final VoidCallback onRefresh;
  final bool demo;

  String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours == 0 ? '${rest}m' : '${hours}h ${rest}m';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final muted = Theme.of(context).brightness == Brightness.dark
        ? DetoxColors.muted
        : DetoxColors.lightMuted;
    return FutureBuilder<UsageChallengeSnapshot>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(title: t.isEs ? 'Tu racha' : 'Your streak'),
            const SizedBox(height: 12),
            GlassCard(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      data == null || !data.hasUsageAccess
                          ? (t.isEs
                                ? 'Activa el acceso al uso para ver tu racha.'
                                : 'Enable usage access to see your streak.')
                          : (t.isEs
                                ? '${data.streak} ${data.streak == 1 ? 'día' : 'días'} seguidos dentro de tu límite'
                                : '${data.streak} ${data.streak == 1 ? 'day' : 'days'} in a row within your limit'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
            ),
            if (data?.hasSponsor == true) ...[
              const SizedBox(height: 24),
              SectionTitle(
                title: t.isEs ? 'Tú y tu padrino' : 'You and your sponsor',
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: !data!.comparisonEnabled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.isEs
                                ? 'Comparte solo el total diario de uso con tu padrino. No se comparten las apps que usaste.'
                                : 'Share only your daily total with your sponsor. Apps you used are not shared.',
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () async {
                              await UsageChallengeService().enableComparison();
                              onRefresh();
                            },
                            child: Text(
                              t.isEs
                                  ? 'Activar comparación'
                                  : 'Enable comparison',
                            ),
                          ),
                        ],
                      )
                    : Builder(
                        builder: (context) {
                          final comparison = data.comparison;
                          if (comparison == null || comparison.days == 0) {
                            return Text(
                              t.isEs
                                  ? 'Aún no hay días compartidos para comparar.'
                                  : 'No shared days to compare yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }
                          final mine = comparison.myMinutes;
                          final sponsor = comparison.sponsorMinutes;
                          final name =
                              data.sponsorName ??
                              (t.isEs ? 'Padrino' : 'Sponsor');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.isEs
                                    ? 'Últimos 7 días · ${comparison.days} en común'
                                    : 'Last 7 days · ${comparison.days} in common',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: muted),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${t.isEs ? 'Tú' : 'You'}  ${_duration(mine)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$name  ${_duration(sponsor)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                mine == sponsor
                                    ? (t.isEs ? 'Van empatados' : 'It is a tie')
                                    : mine < sponsor
                                    ? (t.isEs
                                          ? 'Vas usando menos tiempo'
                                          : 'You used less time')
                                    : (t.isEs
                                          ? '$name usó menos tiempo'
                                          : '$name used less time'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: muted),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (data.comparisonEnabled && !kIsWeb && !demo)
                TextButton(
                  onPressed: () async {
                    try {
                      await UsageChallengeService().disableComparison();
                      onRefresh();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t.isEs
                                  ? 'No se pudo desactivar. Revisa tu conexión.'
                                  : 'Could not disable. Check your connection.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    t.isEs ? 'Desactivar comparación' : 'Disable comparison',
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyWeeklyState extends StatelessWidget {
  const _EmptyWeeklyState({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.noDataYet, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            t.usageUnavailableNotice,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
