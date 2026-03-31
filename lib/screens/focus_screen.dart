import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/permission_status.dart';
import '../services/app_blocking_service.dart';
import '../services/automation_service.dart';
import '../services/focus_notification_service.dart';
import '../services/focus_session_service.dart';
import '../services/location_zone_service.dart';
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
  final StorageService _storageService = StorageService();
  final UsageService _usageService = UsageService();

  int _selectedMinutes = 25;
  List<AppLimit> _shieldedApps = const [];
  bool _overlayReady = true;
  bool _strictMode = false;
  bool _appInForeground = true;
  ZoneState _zoneState = LocationZoneService.instance.currentState;
  StreamSubscription<ZoneState>? _zoneSubscription;
  StreamSubscription<FocusSessionSnapshot>? _focusSubscription;
  FocusSessionSnapshot _focusSnapshot = FocusSessionService.instance.current;
  PermissionStatusModel? _permissionStatus;

  bool get _running => _focusSnapshot.isActive;
  bool get _hasConfiguredApps => _shieldedApps.any((e) => (e.packageName ?? '').isNotEmpty);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshData();
    _zoneSubscription = LocationZoneService.instance.states.listen((state) {
      if (!mounted) return;
      setState(() => _zoneState = state);
    });
    _focusSubscription = FocusSessionService.instance.snapshots.listen((snapshot) {
      if (!mounted) return;
      setState(() => _focusSnapshot = snapshot);
    });
  }

  Future<void> _refreshData() async {
    final limits = await _storageService.loadAppLimits();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    final permissionStatus = await _usageService.getPermissionStatus();
    final strictMode = await _storageService.loadStrictModeEnabled();
    if (!mounted) return;
    setState(() {
      _shieldedApps = limits.where((e) => e.useInFocusMode).toList();
      _overlayReady = overlay;
      _permissionStatus = permissionStatus;
      _strictMode = strictMode;
    });
  }

  Future<void> _start() async {
    await _refreshData();
    await FocusNotificationService.instance.resetSuppression();

    final result = await FocusSessionService.instance.startSession(
      minutes: _selectedMinutes,
      label: AppStrings.of(context).focusSessionLabel,
      reason: 'focus_session',
    );

    if (!mounted) return;
    if (result.success) return;

    switch (result.code) {
      case 'usage_permission_missing':
        _showSnack(AppStrings.of(context).grantUsageSnack);
        break;
      case 'overlay_permission_missing':
        _showSnack(AppStrings.of(context).grantOverlaySnack);
        break;
      case 'no_apps_configured':
        _showSnack(AppStrings.of(context).addAppsSnack);
        break;
      default:
        _showSnack('Could not start focus session.');
    }
  }

  Future<void> _stop() async {
    await FocusSessionService.instance.stopSession();
    if (!mounted) return;
    setState(() {
      _selectedMinutes = _selectedMinutes;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _format(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoneSubscription?.cancel();
    _focusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      FocusNotificationService.instance.cancel();
      FocusNotificationService.instance.resetSuppression();
      _refreshData();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appInForeground = false;
      if (_running) {
        FocusNotificationService.instance.showOrUpdateTimer(
          remainingSeconds: _focusSnapshot.remainingSeconds,
          label: AppStrings.of(context).focusSessionLabel,
          force: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final totalSeconds = _running ? _focusSnapshot.totalSeconds : _selectedMinutes * 60;
    final remainingSeconds = _running ? _focusSnapshot.remainingSeconds : _selectedMinutes * 60;
    final progress = totalSeconds == 0 ? 0.0 : 1 - (remainingSeconds / totalSeconds);

    final androidNeedsUsage = Theme.of(context).platform == TargetPlatform.android &&
        !(_permissionStatus?.usageReady ?? true);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t.focusTitle,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          t.focusSubtitle,
          style: const TextStyle(color: DetoxColors.muted),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.lock_clock_outlined, color: DetoxColors.accentSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _strictMode
                      ? (t.isEs
                          ? 'Modo estricto activo. Las pausas y anuncios quedan bloqueados mientras dure el enfoque.'
                          : 'Strict Mode is active. Pauses and ads stay blocked while focus is running.')
                      : (t.isEs
                          ? 'Modo normal. Puedes salir o pausar cuando el flujo lo permita.'
                          : 'Normal mode. You can exit or pause when the flow allows it.'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Switch(
                value: _strictMode,
                onChanged: _running ? null : (value) async {
                  setState(() => _strictMode = value);
                  await _storageService.saveStrictModeEnabled(value);
                  await AutomationService.instance.refresh();
                },
              ),
            ],
          ),
        ),
        if (androidNeedsUsage || !_overlayReady || !_hasConfiguredApps) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        color: DetoxColors.accentSoft),
                    const SizedBox(width: 10),
                    Text(
                      t.focusBeforeStart,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (androidNeedsUsage)
                  Text(
                    t.focusNeedUsage,
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                if (!_overlayReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.focusNeedOverlay,
                      style: const TextStyle(color: DetoxColors.muted),
                    ),
                  ),
                if (!_hasConfiguredApps)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.focusChooseApps,
                      style: const TextStyle(color: DetoxColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
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
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _format(remainingSeconds),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _running ? t.focusShieldActive : t.focusReadyToStart,
                              style: const TextStyle(
                                color: DetoxColors.muted,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets
                    .map(
                      (minutes) => ChoiceChip(
                    label: Text(t.minuteShort(minutes)),
                    selected: _selectedMinutes == minutes,
                    onSelected: _running
                        ? null
                        : (_) => setState(() {
                      _selectedMinutes = minutes;
                    }),
                  ),
                )
                    .toList(),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: (_overlayReady || Theme.of(context).platform == TargetPlatform.iOS)
                    ? (_running ? _stop : _start)
                    : null,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? t.stopSession : t.startFocusSession),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_moon_outlined,
                      color: DetoxColors.accentSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.shieldedDuringFocus,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_shieldedApps.isEmpty)
                Text(
                  t.addAppsForFocus,
                  style: const TextStyle(color: DetoxColors.muted),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _shieldedApps
                      .map((app) => Chip(label: Text(app.appName)))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _zoneState.insideZone ? Icons.school_rounded : Icons.place_outlined,
                    color:
                    _zoneState.insideZone ? Colors.greenAccent : DetoxColors.accentSoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.studyZoneAutomation,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _zoneState.message ?? t.studyZoneAutomationBody,
                style: const TextStyle(color: DetoxColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
