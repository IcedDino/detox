import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/permission_status.dart';
import '../services/app_blocking_service.dart';
import '../services/automation_service.dart';
import '../services/focus_notification_service.dart';
import '../services/location_zone_service.dart';
import '../services/sponsor_service.dart';
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
  Timer? _timer;
  int _remainingSeconds = 25 * 60;
  List<AppLimit> _shieldedApps = const [];
  bool _overlayReady = true;
  bool _strictMode = false;
  int _focusStreak = 0;
  bool _appInForeground = true;
  ZoneState _zoneState = LocationZoneService.instance.currentState;
  StreamSubscription<ZoneState>? _zoneSubscription;
  PermissionStatusModel? _permissionStatus;

  bool get _running => _timer != null;
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
  }

  Future<void> _refreshData() async {
    final limits = await _storageService.loadAppLimits();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    final permissionStatus = await _usageService.getPermissionStatus();
    final strictMode = await _storageService.loadStrictModeEnabled();
    final focusStreak = await _storageService.loadFocusStreak();
    if (!mounted) return;
    setState(() {
      _shieldedApps = limits.where((e) => e.useInFocusMode).toList();
      _overlayReady = overlay;
      _permissionStatus = permissionStatus;
      _strictMode = strictMode;
      _focusStreak = focusStreak;
    });
  }

  Future<void> _start() async {
    await _refreshData();
    await FocusNotificationService.instance.resetSuppression();
    _timer?.cancel();
    setState(() => _remainingSeconds = _selectedMinutes * 60);

    final packages = _shieldedApps
        .where((e) => e.packageName?.isNotEmpty ?? false)
        .map((e) => e.packageName!)
        .toSet()
        .toList();

    final usageReady = _permissionStatus?.usageReady ?? true;
    if (!usageReady) {
      _showSnack(AppStrings.of(context).grantUsageSnack);
      return;
    }
    if (!_overlayReady) {
      _showSnack(AppStrings.of(context).grantOverlaySnack);
      return;
    }
    if (packages.isEmpty) {
      _showSnack(AppStrings.of(context).addAppsSnack);
      return;
    }

    final hasSponsor =
        (await SponsorService.instance.getCurrentSponsorProfile()) != null;

    final blockedPackages = packages.toList(); // o la variable real que uses
    const reason = 'focus_session';

    await AppBlockingService.instance.startShield(
      blockedPackages: blockedPackages,
      reason: reason,
      hasSponsor: hasSponsor,
      source: 'focus',
      strictModeOverride: _strictMode,
    );

    if (!_appInForeground) {
      await FocusNotificationService.instance.showOrUpdateTimer(
        remainingSeconds: _remainingSeconds,
        label: AppStrings.of(context).focusSessionLabel,
        force: true,
      );
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _timer = null;
        setState(() => _remainingSeconds = 0);
        await FocusNotificationService.instance.cancel();
        if (!_zoneState.insideZone) {
          await AppBlockingService.instance.stopShield(source: 'focus');
        }
        final streak = await _storageService.registerCompletedFocusSession();
        if (mounted) {
          setState(() => _focusStreak = streak);
        }
        await AutomationService.instance.refresh();
        _showSnack('${AppStrings.of(context).focusCompleteSnack} • 🔥 $streak');
      } else {
        setState(() => _remainingSeconds--);
        if (!_appInForeground) {
          await FocusNotificationService.instance.showOrUpdateTimer(
            remainingSeconds: _remainingSeconds,
            label: AppStrings.of(context).focusSessionLabel,
          );
        }
      }
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    await FocusNotificationService.instance.cancel();
    setState(() => _remainingSeconds = _selectedMinutes * 60);
    if (!_zoneState.insideZone) {
      await AppBlockingService.instance.stopShield(source: 'focus');
    }
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
    _timer?.cancel();
    _zoneSubscription?.cancel();
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
          remainingSeconds: _remainingSeconds,
          label: AppStrings.of(context).focusSessionLabel,
          force: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final progress = _selectedMinutes == 0
        ? 0.0
        : 1 - (_remainingSeconds / (_selectedMinutes * 60));

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
          style: TextStyle(color: DetoxColors.muted),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Focus streak: $_focusStreak day${_focusStreak == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    style: TextStyle(color: DetoxColors.muted),
                  ),
                if (!_overlayReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.focusNeedOverlay,
                      style: TextStyle(color: DetoxColors.muted),
                    ),
                  ),
                if (!_hasConfiguredApps)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.focusChooseApps,
                      style: TextStyle(color: DetoxColors.muted),
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
                                _format(_remainingSeconds),
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
                      _remainingSeconds = minutes * 60;
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
                  style: TextStyle(color: DetoxColors.muted),
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
                _zoneState.message ??
                    t.studyZoneAutomationBody,
                style: const TextStyle(color: DetoxColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}