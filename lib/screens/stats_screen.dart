import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with AutomaticKeepAliveClientMixin {
  final UsageService _usageService = UsageService();

  late Future<List<int>> _weeklyMinutes;

  @override
  void initState() {
    super.initState();
    _weeklyMinutes = _load();
  }

  Future<List<int>> _load() async {
    final data = await _usageService.getWeeklyUsage();
    return data.map((e) => e.minutes).toList();
  }

  String _minutesLabel(List<int> weekly) {
    final total = weekly.fold<int>(0, (sum, value) => sum + value);
    final avg = weekly.isEmpty ? 0 : (total / weekly.length).round();
    return '${avg}m';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);

    return FutureBuilder<List<int>>(
      future: _weeklyMinutes,
      builder: (context, snapshot) {
        final weekly = snapshot.data ?? [145, 132, 118, 160, 170, 124, 96];
        final maxY = (weekly.reduce((a, b) => a > b ? a : b) + 20).toDouble();
        final days = t.weekDayLabels;
        final trendDown = weekly.last <= weekly.first;
        final goalMet = weekly.where((e) => e <= 180).length >= 5;
        final bestDay = weekly.reduce((a, b) => a < b ? a : b);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _weeklyMinutes = _load());
            await _weeklyMinutes;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                t.stats,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 18),
              HeroInfoCard(
                icon: Icons.insights_rounded,
                title: t.statsWeeklyTitle,
                subtitle: trendDown ? t.statsTrendDown : t.statsTrendUp,
                badge: StatusPill(
                  label: trendDown ? (t.isEs ? 'A la baja' : 'Trending down') : (t.isEs ? 'A la alza' : 'Trending up'),
                  icon: trendDown ? Icons.south_east_rounded : Icons.north_east_rounded,
                  color: trendDown ? DetoxColors.success : DetoxColors.warning,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FriendlyStatTile(
                            label: t.isEs ? 'Promedio diario' : 'Daily average',
                            value: _minutesLabel(weekly),
                            helper: t.isEs ? 'pantalla por día' : 'screen time per day',
                            icon: Icons.timelapse_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FriendlyStatTile(
                            label: t.isEs ? 'Mejor día' : 'Best day',
                            value: '${bestDay}m',
                            helper: t.isEs ? 'menor uso semanal' : 'lowest screen time this week',
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
                            label: goalMet ? (t.isEs ? 'Meta semanal bien encaminada' : 'Weekly goal on track') : (t.isEs ? 'Todavía puedes ajustar la semana' : 'You can still improve this week'),
                            icon: goalMet ? Icons.check_circle_rounded : Icons.flag_outlined,
                            color: goalMet ? DetoxColors.success : DetoxColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle(
                title: t.isEs ? 'Uso por día' : 'Usage by day',
              ),
              const SizedBox(height: 12),
              GlassCard(
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
                            const FlLine(color: Colors.white10),
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
                                  style: const TextStyle(
                                    color: DetoxColors.muted,
                                  ),
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
                              color: DetoxColors.accentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.statsWeeklyGoal,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      goalMet ? t.statsGoalMet : t.statsGoalMiss,
                      style: const TextStyle(color: DetoxColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
