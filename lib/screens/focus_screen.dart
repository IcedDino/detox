import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../services/app_blocking_service.dart';
import '../services/focus_notification_service.dart';
import '../services/focus_session_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  static const _presets = [15, 25, 45, 60];
  final UsageService _usageService = UsageService();
  final StorageService _storage = StorageService();

  Timer? _timer;
  int _selectedMinutes = 25;
  bool _overlayReady = true;
  bool _usageReady = true;
  bool _strictMode = false;
  List<AppLimit> _shieldedApps = const [];
  FocusSessionSnapshot _snapshot = const FocusSessionSnapshot(
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final limits = await _storage.loadAppLimits();
    final usageStatus = await _usageService.getPermissionStatus();
    final overlayReady = await AppBlockingService.instance.hasOverlayPermission();
    final strictMode = await _storage.loadStrictModeEnabled();
    final snap = await FocusSessionService.instance.loadSnapshot();
    _timer?.cancel();
    if (snap.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    if (!mounted) return;
    setState(() {
      _shieldedApps = limits
          .where((e) => e.useInFocusMode && (e.packageName ?? '').isNotEmpty)
          .toList();
      _usageReady = usageStatus.usageReady;
      _overlayReady = overlayReady;
      _strictMode = strictMode;
      _snapshot = snap;
    });
  }

  Future<void> _tick() async {
    final next = await FocusSessionService.instance.loadSnapshot();
    if (!mounted) return;
    setState(() => _snapshot = next);
    if (!next.isActive) {
      _timer?.cancel();
      await FocusNotificationService.instance.cancel();
    }
  }

  Future<void> _startFocus() async {
    if (!_usageReady) {
      _showSnack(AppStrings.of(context).grantUsageSnack);
      return;
    }
    if (!_overlayReady) {
      _showSnack(AppStrings.of(context).grantOverlaySnack);
      return;
    }
    if (_shieldedApps.isEmpty) {
      _showSnack(AppStrings.of(context).addAppsSnack);
      return;
    }
    await FocusSessionService.instance.startFocus(
      minutes: _selectedMinutes,
      label: 'Focus',
    );
    await _refresh();
  }

  Future<void> _startPomodoro() async {
    if (!_usageReady || !_overlayReady || _shieldedApps.isEmpty) {
      await _startFocus();
      return;
    }
    await FocusSessionService.instance.startPomodoro(
      workMinutes: 25,
      breakMinutes: 5,
      cycles: 4,
    );
    await _refresh();
  }

  Future<void> _stop() async {
    await FocusSessionService.instance.stopSession();
    await _refresh();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final totalSeconds =
        (_snapshot.minutes <= 0 ? _selectedMinutes : _snapshot.minutes) * 60;
    final remaining =
    _snapshot.isActive ? _snapshot.remainingSeconds : _selectedMinutes * 60;
    final progress = totalSeconds == 0 ? 0.0 : 1 - (remaining / totalSeconds);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text(
              t.focusTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _CompactBadge(
              icon: _strictMode ? Icons.lock_outline : Icons.shield_outlined,
              label: _strictMode ? 'Strict' : '${_shieldedApps.length} apps',
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 14,
                      backgroundColor: DetoxColors.accent.withOpacity(0.12),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatSeconds(remaining),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _snapshot.isActive
                                ? (_snapshot.isBreak
                                ? t.pomodoroBreak
                                : (_snapshot.isPomodoro
                                ? t.pomodoroWork
                                : t.focusTitle))
                                : t.focusTitle,
                            style: const TextStyle(color: DetoxColors.muted),
                          ),
                          if (_snapshot.isPomodoro) ...[
                            const SizedBox(height: 6),
                            Text(
                              t.pomodoroCycleLabel(
                                _snapshot.currentCycle,
                                _snapshot.totalCycles,
                              ),
                              style: const TextStyle(color: DetoxColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets
                    .map(
                      (minutes) => ChoiceChip(
                    selected: _selectedMinutes == minutes,
                    label: Text('${minutes}m'),
                    onSelected: _snapshot.isActive
                        ? null
                        : (_) => setState(() => _selectedMinutes = minutes),
                  ),
                )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _snapshot.isActive ? null : _startFocus,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(t.startFocusSession),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _snapshot.isActive ? _stop : _startPomodoro,
                      icon: Icon(
                        _snapshot.isActive
                            ? Icons.stop_rounded
                            : Icons.timer_outlined,
                      ),
                      label: Text(
                        _snapshot.isActive ? t.stopSession : t.pomodoroStart,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStat(label: 'Apps', value: '${_shieldedApps.length}'),
            _MiniStat(label: 'Mode', value: _strictMode ? 'Strict' : 'Normal'),
            _MiniStat(label: 'Pomodoro', value: '25 · 5 · 4'),
          ],
        ),
      ],
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: DetoxColors.accentSoft),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: DetoxColors.muted)),
        ],
      ),
    );
  }
}
