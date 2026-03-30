import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    return FutureBuilder<List<int>>(
      future: _weeklyMinutes,
      builder: (context, snapshot) {
        final weekly = snapshot.data ?? [145, 132, 118, 160, 170, 124, 96];
        final maxY = (weekly.reduce((a, b) => a > b ? a : b) + 20).toDouble();
        final days = t.weekDayLabels;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _weeklyMinutes = _load());
            await _weeklyMinutes;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                t.statsWeeklyTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(t.statsWeeklySubtitle, style: const TextStyle(color: DetoxColors.muted)),
              const SizedBox(height: 18),
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
                        getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            reservedSize: 42,
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 11, color: DetoxColors.muted),
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
                                child: Text(days[index], style: const TextStyle(color: DetoxColors.muted)),
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
              const SizedBox(height: 14),
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insights_outlined, color: DetoxColors.accentSoft),
                  title: Text(t.statsTrendInsight),
                  subtitle: Text(
                    weekly.last <= weekly.first ? t.statsTrendDown : t.statsTrendUp,
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: DetoxColors.accentSoft),
                  title: Text(t.statsWeeklyGoal),
                  subtitle: Text(
                    weekly.where((e) => e <= 180).length >= 5 ? t.statsGoalMet : t.statsGoalMiss,
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}