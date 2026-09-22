import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../services/app_blocking_service.dart';
import '../services/focus_session_service.dart';
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
  );
  Duration _selectedDuration = const Duration(minutes: 25);
  List<AppLimit> _shieldedApps = const [];
  bool _strictMode = false;
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
    final snap = await _sessions.loadSnapshot();
    final limits = await _storage.loadAppLimits();
    final strict = await _storage.loadStrictModeEnabled();
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _shieldedApps = limits
          .where((e) => e.useInFocusMode && (e.packageName ?? '').isNotEmpty)
          .toList();
      _strictMode = strict;
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
      setState(() {});
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
      return t.isEs ? '$h h ${m.toString().padLeft(2, '0')} min' : '$h h ${m.toString().padLeft(2, '0')} min';
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
                            label: Text(_durationLabel(AppStrings.of(context), Duration(minutes: minutes))),
                            selected: local == Duration(minutes: minutes),
                            onSelected: (v) => setSheetState(() => local = Duration(minutes: minutes)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, local),
                      child: Text(AppStrings.of(context).isEs ? 'Listo' : 'Done'),
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
    await _sessions.startFocus(
      minutes: _selectedDuration.inMinutes,
      label: 'Focus',
    );
    await _load();
  }

  Future<void> _startPomodoro() async {
    final allowed = await ensureBlockingPermissions(context);
    if (!allowed || !mounted) return;
    await _sessions.startPomodoro();
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
        bool localStrict = _strictMode;
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
                      t.isEs ? 'Modo de bloqueo' : 'Blocking mode',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.isEs
                          ? 'El modo estricto reduce salidas y pausas mientras el bloqueo esté activo.'
                          : 'Strict mode reduces exits and pauses while blocking is active.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? DetoxColors.muted
                                : DetoxColors.lightMuted,
                          ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: localStrict,
                      onChanged: (v) => setSheetState(() => localStrict = false),
                      title: Text(t.isEs ? 'Normal' : 'Normal'),
                      subtitle: Text(
                        t.isEs ? 'Pausas y salida disponibles.' : 'Pauses and exit available.',
                      ),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: localStrict,
                      onChanged: (v) => setSheetState(() => localStrict = true),
                      title: Text(t.isEs ? 'Estricto' : 'Strict'),
                      subtitle: Text(
                        t.isEs
                            ? 'Sin pausas ni salida fácil hasta terminar.'
                            : 'No pauses or easy exit until done.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _storage.saveStrictModeEnabled(localStrict);
                        await AppBlockingService.instance.refreshStrictMode();
                        if (!mounted) return;
                        setState(() => _strictMode = localStrict);
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final selectedSeconds = _selectedDuration.inSeconds;
    final totalSeconds = _snapshot.isActive ? (_snapshot.minutes * 60) : selectedSeconds;
    final remaining = _snapshot.isActive ? _snapshot.remainingSeconds : selectedSeconds;
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
            height: 240,
            width: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimer(remaining),
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        active ? blockedAppsLabel : _durationLabel(t, _selectedDuration),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                      ),
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
            onTap: _pickDuration,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(detoxRadius),
                border: Border.all(
                  color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20, color: DetoxColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _durationLabel(t, _selectedDuration),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
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
              border: Border.all(
                color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _strictMode ? Icons.lock_outline_rounded : Icons.tune_rounded,
                  size: 20,
                  color: _strictMode ? DetoxColors.warning : DetoxColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _strictMode
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
                : t.startFocusSession,
          ),
        ),
        const SizedBox(height: 10),
        if (!active)
          OutlinedButton(
            onPressed: _startPomodoro,
            child: Text(
              t.isEs ? 'Empezar Pomodoro (25/5)' : 'Start Pomodoro (25/5)',
            ),
          ),

        const SizedBox(height: 28),

        // ── Blocked apps summary ──
        Text(
          t.isEs ? 'Apps en esta sesión' : 'Apps in this session',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_shieldedApps.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(detoxRadius),
              border: Border.all(
                color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
              ),
            ),
            child: Text(
              t.isEs
                  ? 'Aún no hay apps agregadas para enfoque. Puedes elegirlas en Configuración.'
                  : 'No focus apps added yet. You can choose them in Settings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _shieldedApps.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _shieldedApps[i].appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != _shieldedApps.length - 1)
                    Divider(
                      height: 1,
                      color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
