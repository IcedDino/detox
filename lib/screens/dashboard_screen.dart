import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/dashboard_data.dart';
import '../models/usage_models.dart';
import '../services/smart_usage_recommendation_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_app_tile.dart';
import '../widgets/ui_kit.dart';

/// "Today" screen. Answers one question: how am I doing?
/// One hero number, one primary action, three supporting apps.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onStartFocus,
    this.isCurrentPage = true,
  });

  /// Called when the user taps the single primary action.
  final VoidCallback? onStartFocus;
  final bool isCurrentPage;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final UsageService _usageService = UsageService();
  final StorageService _storageService = StorageService();

  late Future<DashboardData> _future;
  Timer? _usageRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _updateUsageRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrentPage != widget.isCurrentPage) {
      _updateUsageRefreshTimer();
      if (widget.isCurrentPage) _refreshUsage();
    }
  }

  void _updateUsageRefreshTimer() {
    _usageRefreshTimer?.cancel();
    if (!widget.isCurrentPage) return;
    _usageRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshUsage();
    });
  }

  void _refreshUsage() {
    if (!mounted || !widget.isCurrentPage) return;
    _startRefresh();
  }

  Future<DashboardData> _startRefresh() {
    final nextFuture = _load();
    setState(() {
      _future = nextFuture;
    });
    return nextFuture;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUsage();
    }
  }

  Future<DashboardData> _load() async {
    // This load starts in initState. Notification copy uses the app locale
    // without subscribing to inherited widgets before initialization finishes.
    final strings = AppStrings.current;
    final results = await Future.wait<dynamic>([
      _usageService.getTodaySummary(),
      _storageService.loadDailyLimitMinutes(),
    ]);
    final summary = results[0] as DailyUsageSummary;
    final limit = results[1] as int;

    if (summary.topApps.isNotEmpty) {
      unawaited(
        SmartUsageRecommendationService.instance
            .evaluateTopApp(entry: summary.topApps.first, strings: strings)
            .catchError((_) {}),
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
        await _startRefresh();
      },
      child: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final summary = data?.summary;
          final limit = data?.dailyLimit ?? 180;
          final topApps = (summary?.topApps ?? const []).take(3).toList();
          final totalMinutes = summary?.totalMinutes ?? 0;
          final percent =
              limit == 0 ? 0.0 : (totalMinutes / limit).clamp(0.0, 1.0);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              // ── Hero: the single number that matters ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(detoxRadius + 4),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x338BC7AE)
                        : const Color(0x5581A995),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF1B2A23), Color(0xFF131B17)]
                        : const [Color(0xFFE4F0E8), Color(0xFFFBFDFB)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.isEs ? 'HOY' : 'TODAY',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: isDark
                                      ? DetoxColors.accentSoft
                                      : DetoxColors.accentDeep,
                                  letterSpacing: 1.4,
                                ),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: DetoxColors.accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.spa_outlined,
                            color: DetoxColors.accent,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      summary == null ? '--' : _formatMinutes(totalMinutes),
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.isEs
                          ? 'de ${_formatMinutes(limit)} de tu meta diaria'
                          : 'of your ${_formatMinutes(limit)} daily goal',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(detoxRadiusPill),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : DetoxColors.accentDeep.withOpacity(0.10),
                        color: percent >= 1
                            ? DetoxColors.warning
                            : DetoxColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          percent >= 1
                              ? Icons.flag_outlined
                              : Icons.check_circle_outline_rounded,
                          size: 17,
                          color: percent >= 1
                              ? DetoxColors.warning
                              : DetoxColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _friendlyUsageLabel(t, totalMinutes, limit),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ),
                      ],
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
                  ],
                ),
              ),

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
                      color: isDark
                          ? DetoxColors.cardBorder
                          : DetoxColors.lightCardBorder,
                    ),
                  ),
                  child: Text(
                    snapshot.hasError
                        ? (t.isEs
                            ? 'No pudimos cargar el uso de tus apps. Intenta de nuevo.'
                            : 'Could not load app usage. Please try again.')
                        : summary == null
                            ? (t.isEs
                                ? 'Cargando el uso de tus apps…'
                                : 'Loading your app usage…')
                            : t.noAppUsageYet,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted),
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
              if (snapshot.hasError)
                TextButton.icon(
                  onPressed: _refreshUsage,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(t.isEs ? 'Reintentar' : 'Retry'),
                ),
            ],
          );
        },
      ),
    );
  }
}
