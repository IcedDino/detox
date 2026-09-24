import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/usage_models.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.isCurrentPage = true});

  final bool isCurrentPage;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// Weekly minutes plus the user's configured daily goal, loaded together so
/// the insight text always matches the limit set in Settings.
class _StatsData {
  const _StatsData({required this.weekly, required this.dailyLimitMinutes});

  final List<int> weekly;
  final int dailyLimitMinutes;
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
    final results = await Future.wait<dynamic>([
      _usageService.getWeeklyUsage(),
      _storageService.loadDailyLimitMinutes(),
    ]);
    final weekly = results[0] as List<WeeklyUsagePoint>;
    final dailyLimit = results[1] as int;
    return _StatsData(
      weekly: weekly.map((e) => e.minutes).toList(),
      dailyLimitMinutes: dailyLimit,
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
              AppPageHeader(
                eyebrow: t.isEs ? 'Panel' : 'Overview',
                title: t.stats,
                subtitle: t.statsWeeklySubtitle,
              ),
              const SizedBox(height: 18),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
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
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.statsWeeklyGoal,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weeklyGoalMet(weekly, dailyLimit)
                            ? t.statsGoalMet
                            : t.statsGoalMiss,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
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
    final bestDay = weekly.reduce((a, b) => a < b ? a : b);

    return HeroInfoCard(
      title: t.statsWeeklyTitle,
      subtitle: !hasTrend
          ? (t.isEs ? 'La semana comienza hoy.' : 'The week starts today.')
          : (trendDown ? t.statsTrendDown : t.statsTrendUp),
      badge: StatusPill(
        label: !hasTrend
            ? (t.isEs ? 'Semana en curso' : 'Week in progress')
            : trendDown
            ? (t.isEs ? 'A la baja' : 'Trending down')
            : (t.isEs ? 'A la alza' : 'Trending up'),
        icon: !hasTrend
            ? Icons.calendar_today_outlined
            : (trendDown ? Icons.south_east_rounded : Icons.north_east_rounded),
        color: !hasTrend
            ? DetoxColors.accent
            : (trendDown ? DetoxColors.success : DetoxColors.warning),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FriendlyStatTile(
                  label: t.isEs ? 'Promedio diario' : 'Daily average',
                  value: _averageLabel(),
                  helper: t.isEs ? 'pantalla por día' : 'screen time per day',
                  icon: Icons.timelapse_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FriendlyStatTile(
                  label: t.isEs ? 'Mejor día' : 'Best day',
                  value: '${bestDay}m',
                  helper: t.isEs
                      ? 'menor uso semanal'
                      : 'lowest screen time this week',
                  icon: Icons.emoji_events_outlined,
                  color: DetoxColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatusPill(
                  label: goalMet
                      ? (t.isEs
                          ? 'Meta semanal bien encaminada'
                          : 'Weekly goal on track')
                      : (t.isEs
                          ? 'Todavía puedes ajustar la semana'
                          : 'You can still improve this week'),
                  icon: goalMet
                      ? Icons.check_circle_rounded
                      : Icons.flag_outlined,
                  color: goalMet ? DetoxColors.success : DetoxColors.warning,
                ),
              ),
            ],
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
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
