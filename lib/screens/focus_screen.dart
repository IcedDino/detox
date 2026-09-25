import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../services/app_blocking_service.dart';
import '../services/focus_session_service.dart';
import '../services/focus_notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/blocking_permission_gate.dart';

/// Focus screen. Answers one question: do I protect my attention now?
/// The timer is the protagonist; mode and duration are secondary controls.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.isCurrentPage});

  final bool isCurrentPage;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final FocusSessionService _sessions = FocusSessionService.instance;
  final StorageService _storage = StorageService();

  FocusSessionSnapshot _snapshot = FocusSessionSnapshot(
    isActive: false,
    isPomodoro: false,
    isBreak: false,
    endsAt: null,
    minutes: 0,
    label: 'Focus',
    currentCycle: 1,
    totalCycles: 1,
    breakMinutes: 5,
    source: 'focus',
  );
  Duration _selectedDuration = const Duration(minutes: 25);
  List<AppLimit> _shieldedApps = const [];
  bool _strictMode = false;
  bool _pomodoroMode = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant FocusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      _sessions.loadSnapshot(),
      _storage.loadAppLimits(),
      _storage.loadStrictModeEnabled(),
    ]);
    final snap = results[0] as FocusSessionSnapshot;
    final limits = results[1] as List<AppLimit>;
    final strict = results[2] as bool;
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _shieldedApps = limits
          .where((e) => e.useInFocusMode && (e.packageName ?? '').isNotEmpty)
          .toList();
      _strictMode = strict;
      if (snap.isActive) _pomodoroMode = snap.isPomodoro;
    });
    _ensureTicker();
  }

  void _ensureTicker() {
    final active = _snapshot.isActive;
    if (!active) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _snapshot.remainingSeconds;
      if (remaining <= 0) {
        _tick?.cancel();
        _tick = null;
        _load();
        return;
      }
      if (widget.isCurrentPage) setState(() {});
    });
  }

  String _formatTimer(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _durationLabel(AppStrings t, Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) {
      return t.isEs
          ? '$h h ${m.toString().padLeft(2, '0')} min'
          : '$h h ${m.toString().padLeft(2, '0')} min';
    }
    return '$m min';
  }

  String _sessionLabel(AppStrings t) {
    if (_snapshot.isBreak) {
      return t.isEs ? 'Descanso' : 'Break';
    }
    if (_snapshot.isActive) return _snapshot.label;
    return t.isEs ? 'Nueva sesión' : 'New session';
  }

  Future<void> _pickDuration() async {
    if (_snapshot.isActive) return;
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(detoxRadius)),
      ),
      builder: (context) {
        Duration local = _selectedDuration;
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.of(context).isEs ? 'Duración' : 'Duration',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final minutes in const [15, 25, 45, 60, 90, 120])
                          ChoiceChip(
                            label: Text(_durationLabel(AppStrings.of(context),
                                Duration(minutes: minutes))),
                            selected: local == Duration(minutes: minutes),
                            onSelected: (v) => setSheetState(
                                () => local = Duration(minutes: minutes)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, local),
                      child:
                          Text(AppStrings.of(context).isEs ? 'Listo' : 'Done'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDuration = picked);
    }
  }

  Future<void> _startFocus() async {
    final allowed = await ensureBlockingPermissions(context);
    if (!allowed || !mounted) return;
    await FocusNotificationService.instance.requestPermission();
    if (_pomodoroMode) {
      await _sessions.startPomodoro();
    } else {
      await _sessions.startFocus(
        minutes: _selectedDuration.inMinutes,
        label: 'Focus',
      );
    }
    await _load();
  }

  Future<void> _stop() async {
    await _sessions.stopSession();
    await _load();
  }

  Future<void> _showModeSheet() async {
    final t = AppStrings.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(detoxRadius)),
      ),
      builder: (sheetContext) {
        int localMode = _pomodoroMode ? 2 : (_strictMode ? 1 : 0);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.isEs ? 'Modo de sesión' : 'Session mode',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.isEs
                          ? 'Elige cómo quieres concentrarte.'
                          : 'Choose how you want to focus.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? DetoxColors.muted
                                    : DetoxColors.lightMuted,
                          ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<int>(
                      value: 0,
                      groupValue: localMode,
                      onChanged: (_) => setSheetState(() => localMode = 0),
                      title: Text(t.isEs ? 'Normal' : 'Normal'),
                      subtitle: Text(
                        t.isEs
                            ? 'Pausas y salida disponibles.'
                            : 'Pauses and exit available.',
                      ),
                    ),
                    RadioListTile<int>(
                      value: 1,
                      groupValue: localMode,
                      onChanged: (_) => setSheetState(() => localMode = 1),
                      title: Text(t.isEs ? 'Estricto' : 'Strict'),
                      subtitle: Text(
                        t.isEs
                            ? 'Sin pausas ni salida fácil hasta terminar.'
                            : 'No pauses or easy exit until done.',
                      ),
                    ),
                    RadioListTile<int>(
                      value: 2,
                      groupValue: localMode,
                      onChanged: (_) => setSheetState(() => localMode = 2),
                      title: const Text('Pomodoro'),
                      subtitle: Text(
                        t.isEs
                            ? '25 min de enfoque y 5 min de descanso.'
                            : '25 min of focus and a 5 min break.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final strictMode = localMode == 1;
                        await _storage.saveStrictModeEnabled(strictMode);
                        await AppBlockingService.instance.refreshStrictMode();
                        if (!mounted) return;
                        setState(() {
                          _strictMode = strictMode;
                          _pomodoroMode = localMode == 2;
                        });
                      },
                      child: Text(t.isEs ? 'Guardar' : 'Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAllFocusApps() {
    final apps = _shieldedApps;
    final t = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  t.isEs ? 'Apps en esta sesión' : 'Apps in this session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final app in apps)
                        ListTile(
                          title: Text(app.appName.trim().isNotEmpty
                              ? app.appName
                              : app.packageName!),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final selectedSeconds = _selectedDuration.inSeconds;
    final totalSeconds =
        _snapshot.isActive ? (_snapshot.minutes * 60) : selectedSeconds;
    final remaining =
        _snapshot.isActive ? _snapshot.remainingSeconds : selectedSeconds;
    final safeTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final progress = 1 - (remaining / safeTotal);
    final blockedAppsLabel = t.isEs
        ? '${_shieldedApps.length} app${_shieldedApps.length == 1 ? '' : 's'} bloqueadas'
        : '${_shieldedApps.length} blocked app${_shieldedApps.length == 1 ? '' : 's'}';
    final active = _snapshot.isActive;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // ── Timer: the protagonist ──
        Text(
          _sessionLabel(t).toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? DetoxColors.accent : muted,
                letterSpacing: 1.4,
              ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            height: 208,
            width: 208,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  constraints: const BoxConstraints.tightFor(
                    width: 208,
                    height: 208,
                  ),
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.08)
                      : DetoxColors.accentDeep.withOpacity(0.10),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimer(remaining),
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: active ? DetoxColors.accentSoft : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(height: 8),
                        Text(blockedAppsLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Duration picker (secondary) ──
        if (!active)
          InkWell(
            borderRadius: BorderRadius.circular(detoxRadius),
            onTap: _pomodoroMode ? null : _pickDuration,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(detoxRadius),
                color: isDark
                    ? DetoxColors.cardSubtle
                    : DetoxColors.lightCardSubtle,
                border: Border.all(
                  color: isDark
                      ? DetoxColors.cardBorder
                      : DetoxColors.lightCardBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 20, color: DetoxColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pomodoroMode
                          ? (t.isEs
                              ? '25 min de enfoque · 5 min de descanso'
                              : '25 min focus · 5 min break')
                          : _durationLabel(t, _selectedDuration),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!_pomodoroMode)
                    Icon(Icons.expand_more_rounded, size: 20, color: muted),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ── Mode selector ──
        InkWell(
          borderRadius: BorderRadius.circular(detoxRadius),
          onTap: _showModeSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(detoxRadius),
              color:
                  isDark ? DetoxColors.cardSubtle : DetoxColors.lightCardSubtle,
              border: Border.all(
                color: isDark
                    ? DetoxColors.cardBorder
                    : DetoxColors.lightCardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _pomodoroMode
                      ? Icons.timer_outlined
                      : _strictMode
                          ? Icons.lock_outline_rounded
                          : Icons.tune_rounded,
                  size: 20,
                  color: _strictMode && !_pomodoroMode
                      ? DetoxColors.warning
                      : DetoxColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pomodoroMode
                        ? 'Pomodoro'
                        : _strictMode
                            ? (t.isEs ? 'Modo estricto' : 'Strict mode')
                            : (t.isEs ? 'Modo normal' : 'Normal mode'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 20, color: muted),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Single primary action ──
        FilledButton.icon(
          onPressed: active ? _stop : _startFocus,
          icon: Icon(active ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(
            active
                ? (t.isEs ? 'Terminar sesión' : 'End session')
                : _pomodoroMode
                    ? (t.isEs ? 'Empezar Pomodoro' : 'Start Pomodoro')
                    : t.startFocusSession,
          ),
        ),
        const SizedBox(height: 28),

        // ── Blocked apps summary ──
        if (_shieldedApps.isEmpty)
          GlassCard(
            child: Text(
              t.isEs
                  ? 'Aún no hay apps agregadas para enfoque. Puedes elegirlas en Configuración.'
                  : 'No focus apps added yet. You can choose them in Settings.',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
            ),
          )
        else
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.isEs ? 'Apps en esta sesión' : 'Apps in this session',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(blockedAppsLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted)),
                const SizedBox(height: 12),
                for (final app in _shieldedApps.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      app.appName.trim().isNotEmpty
                          ? app.appName
                          : app.packageName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (_shieldedApps.length > 3)
                  TextButton(
                    onPressed: _showAllFocusApps,
                    child: Text(t.isEs ? 'Ver todas' : 'See all'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
