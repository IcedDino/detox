import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../services/app_blocking_service.dart';
import '../services/focus_notification_service.dart';
import '../services/focus_session_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/ui_kit.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final UsageService _usageService = UsageService();
  final StorageService _storage = StorageService();

  Timer? _timer;
  Duration _selectedDuration = const Duration(minutes: 45);
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
      if (!snap.isActive && snap.minutes > 0) {
        _selectedDuration = Duration(minutes: snap.minutes);
      }
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
    if (_selectedDuration.inMinutes <= 0) {
      _showSnack(AppStrings.of(context).isEs
          ? 'Elige una duración mayor a 0 minutos.'
          : 'Choose a duration greater than 0 minutes.');
      return;
    }
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
      minutes: _selectedDuration.inMinutes,
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

  Future<void> _setStrictMode(bool value) async {
    await _storage.saveStrictModeEnabled(value);
    await _storage.setStrictMode(value);
    await AppBlockingService.instance.refreshStrictMode();
    if (!mounted) return;
    setState(() => _strictMode = value);
  }

  Future<void> _showModeSheet() async {
    final t = AppStrings.of(context);
    final selected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.isEs ? 'Modo de enfoque' : 'Focus mode',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                t.isEs
                    ? 'Elige cómo quieres que se comporte el bloqueo durante la sesión.'
                    : 'Choose how blocking should behave during the session.',
                style: const TextStyle(color: DetoxColors.muted, height: 1.35),
              ),
              const SizedBox(height: 16),
              _ModeOptionTile(
                title: t.isEs ? 'Modo normal' : 'Normal mode',
                subtitle: t.isEs
                    ? 'Más flexible para empezar y volver a la app.'
                    : 'More flexible to begin and return to the app.',
                icon: Icons.tune_rounded,
                selected: !_strictMode,
                onTap: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 10),
              _ModeOptionTile(
                title: t.isEs ? 'Modo estricto' : 'Strict mode',
                subtitle: t.isEs
                    ? 'Reduce salidas, pausas y caminos fáciles para saltarte el bloqueo.'
                    : 'Reduces exits, pauses, and easy ways to bypass blocking.',
                icon: Icons.lock_outline_rounded,
                selected: _strictMode,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _strictMode) {
      await _setStrictMode(selected);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTimer(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _durationLabel(AppStrings t, Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    if (hours > 0) {
      return t.isEs ? '${hours} h ${minutes} min' : '${hours} h ${minutes} min';
    }
    return t.isEs ? '${minutes} min' : '${minutes} min';
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickDuration() async {
    if (_snapshot.isActive) return;

    final t = AppStrings.of(context);
    var tempDuration = _selectedDuration;

    final result = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final modalCupertinoTheme = CupertinoThemeData(
          brightness: Theme.of(context).brightness,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle:
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(fontSize: 22),
          ),
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 24,
              ),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          t.isEs ? 'Elige la duración' : 'Choose duration',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(t.isEs ? 'Cancelar' : 'Cancel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.isEs
                          ? 'Toca esta área cuando quieras cambiar horas o minutos.'
                          : 'Use this area only when you want to change hours or minutes.',
                      style: const TextStyle(color: DetoxColors.muted, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _durationLabel(t, tempDuration),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 180,
                      child: CupertinoTheme(
                        data: modalCupertinoTheme,
                        child: CupertinoTimerPicker(
                          mode: CupertinoTimerPickerMode.hm,
                          initialTimerDuration: tempDuration,
                          onTimerDurationChanged: (value) {
                            final normalized = value.inMinutes == 0
                                ? const Duration(minutes: 1)
                                : value;
                            setModalState(() => tempDuration = normalized);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(tempDuration),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(t.isEs ? 'Usar este tiempo' : 'Use this time'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _selectedDuration = result);
    }
  }

  String _sessionLabel(AppStrings t) {
    if (!_snapshot.isActive) {
      return t.isEs ? 'Listo para empezar' : 'Ready to begin';
    }
    if (_snapshot.isBreak) return t.pomodoroBreak;
    if (_snapshot.isPomodoro) return t.pomodoroWork;
    return t.focusTitle;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);
    final selectedSeconds = _selectedDuration.inSeconds;
    final totalSeconds = _snapshot.isActive ? (_snapshot.minutes * 60) : selectedSeconds;
    final remaining = _snapshot.isActive ? _snapshot.remainingSeconds : selectedSeconds;
    final safeTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final progress = 1 - (remaining / safeTotal);
    final blockedAppsLabel = t.isEs
        ? '${_shieldedApps.length} app${_shieldedApps.length == 1 ? '' : 's'} bloqueadas'
        : '${_shieldedApps.length} blocked app${_shieldedApps.length == 1 ? '' : 's'}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          t.focus,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        HeroInfoCard(
          icon: Icons.bolt_rounded,
          title: _sessionLabel(t),
          subtitle: _snapshot.isActive
              ? (t.isEs
                  ? 'Detox seguirá cubriendo tus apps mientras dure la sesión.'
                  : 'Detox will keep shielding your apps while the session is active.')
              : (t.isEs
                  ? 'Elige el tiempo que quieres bloquear y comienza cuando quieras.'
                  : 'Choose how long you want to block and start whenever you want.'),
          badge: _snapshot.isPomodoro
              ? StatusPill(
                  label: t.pomodoroCycleLabel(
                    _snapshot.currentCycle,
                    _snapshot.totalCycles,
                  ),
                  icon: Icons.repeat_rounded,
                )
              : null,
          child: Column(
            children: [
              SizedBox(
                width: 230,
                height: 230,
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
                            _formatTimer(remaining),
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            blockedAppsLabel,
                            style: const TextStyle(color: DetoxColors.muted),
                          ),
                          if (_snapshot.isPomodoro) ...[
                            const SizedBox(height: 6),
                            Text(
                              t.isEs ? 'Pomodoro 25 · 5 · 4' : 'Pomodoro 25 · 5 · 4',
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
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _snapshot.isActive ? null : _pickDuration,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DetoxColors.accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: DetoxColors.accentSoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.isEs ? 'Duración' : 'Duration',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _durationLabel(t, _selectedDuration),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _snapshot.isActive
                                  ? (t.isEs
                                      ? 'La sesión ya está en curso.'
                                      : 'The session is already running.')
                                  : (t.isEs
                                      ? 'Toca para elegir horas y minutos.'
                                      : 'Tap to choose hours and minutes.'),
                              style: const TextStyle(color: DetoxColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _snapshot.isActive
                            ? DetoxColors.muted.withOpacity(0.6)
                            : DetoxColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
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
                        _snapshot.isActive ? Icons.stop_rounded : Icons.timer_outlined,
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
        const SizedBox(height: 16),
        SoftActionTile(
          icon: _strictMode ? Icons.lock_outline_rounded : Icons.tune_rounded,
          color: _strictMode ? DetoxColors.warning : DetoxColors.accentSoft,
          title: _strictMode
              ? (t.isEs ? 'Modo estricto' : 'Strict mode')
              : (t.isEs ? 'Modo normal' : 'Normal mode'),
          subtitle: _strictMode
              ? (t.isEs
                  ? 'Toque para cambiar a un modo más flexible.'
                  : 'Tap to switch to a more flexible mode.')
              : (t.isEs
                  ? 'Toque para cambiar a un bloqueo más rígido.'
                  : 'Tap to switch to a stronger blocking mode.'),
          trailing: const Icon(Icons.swap_horiz_rounded),
          onTap: _showModeSheet,
        ),
        const SizedBox(height: 16),
        SectionTitle(
          title: t.isEs ? 'Apps bloqueadas en esta sesión' : 'Apps blocked in this session',
        ),
        const SizedBox(height: 12),
        if (_shieldedApps.isEmpty)
          GlassCard(
            child: Text(
              t.isEs
                  ? 'Aún no hay apps agregadas para enfoque. Puedes elegirlas en Configuración.'
                  : 'No focus apps added yet. You can choose them in Settings.',
              style: const TextStyle(color: DetoxColors.muted, height: 1.35),
            ),
          )
        else
          GlassCard(
            child: Column(
              children: [
                for (var i = 0; i < _shieldedApps.length; i++) ...[
                  Row(
                    children: [
                      AppIconBadge(
                        packageName: _shieldedApps[i].packageName,
                        size: 36,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _shieldedApps[i].appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (i != _shieldedApps.length - 1) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.06)
                          : DetoxColors.lightCardBorder,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),

      ],
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  const _ModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? DetoxColors.accentSoft.withOpacity(0.45)
        : (isDark ? Colors.white.withOpacity(0.08) : DetoxColors.lightCardBorder);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? DetoxColors.accent.withOpacity(isDark ? 0.14 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFF)),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: DetoxColors.accent.withOpacity(isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: DetoxColors.accentSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: DetoxColors.muted, height: 1.3),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: DetoxColors.accentSoft,
              ),
          ],
        ),
      ),
    );
  }
}
