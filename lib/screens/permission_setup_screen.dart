import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../services/app_blocking_service.dart';
import '../services/location_zone_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detox_logo.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  final UsageService _usageService = UsageService();
  final StorageService _storageService = StorageService();

  bool _checking = true;
  bool _usageReady = false;
  bool _overlayReady = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
  bool _waitingFromUsage = false;
  bool _waitingFromOverlay = false;
  String _message = '…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_waitingFromUsage || _waitingFromOverlay)) {
      _refreshWithGracePeriod();
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _checking = true);
    }
    final status = await _usageService.getPermissionStatus();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    if (!mounted) return;
    setState(() {
      _usageReady = status.usageReady;
      _overlayReady = overlay;
      _message = status.platformMessage;
      _checking = false;
      _waitingFromUsage = false;
      _waitingFromOverlay = false;
    });

    final skipStrictPermissions =
        kIsWeb || defaultTargetPlatform != TargetPlatform.android;
    if ((_usageReady && _overlayReady) || skipStrictPermissions) {
      await _storageService.saveOnboardingDone(true);
      if (mounted) widget.onFinished();
    }
  }

  Future<void> _refreshWithGracePeriod() async {
    if (!mounted) return;
    setState(() {
      _checking = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    final status = await _usageService.getPermissionStatus();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    if (!mounted) return;

    setState(() {
      _usageReady = status.usageReady;
      _overlayReady = overlay;
      _message = status.platformMessage;
      _checking = false;
      if (_usageReady) _waitingFromUsage = false;
      if (_overlayReady) _waitingFromOverlay = false;
    });

    final skipStrictPermissions =
        kIsWeb || defaultTargetPlatform != TargetPlatform.android;
    if ((_usageReady && _overlayReady) || skipStrictPermissions) {
      await _storageService.saveOnboardingDone(true);
      if (mounted) widget.onFinished();
    }
  }

  Future<void> _openUsageSettings() async {
    setState(() => _waitingFromUsage = true);
    await _usageService.openUsageAccessSettings();
  }

  Future<void> _openOverlaySettings() async {
    setState(() => _waitingFromOverlay = true);
    await AppBlockingService.instance.openOverlayPermissionSettings();
  }

  Future<void> _enableLocation() async {
    await LocationZoneService.instance.ensurePermissions();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return Scaffold(
      body: DetoxBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 28),
              const Center(child: DetoxLogo(size: 84, showLabel: true)),
              const SizedBox(height: 22),
              Text(
                t.welcomeToDetox,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  children: [
                    _PermissionStatusTile(
                      icon: _usageReady
                          ? Icons.check_circle_rounded
                          : Icons.admin_panel_settings_outlined,
                      title: t.openUsageAccess,
                      subtitle: _message,
                      ready: _usageReady,
                    ),
                    if (defaultTargetPlatform == TargetPlatform.android) ...[
                      const Divider(height: 18),
                      _PermissionStatusTile(
                        icon: _overlayReady
                            ? Icons.check_circle_rounded
                            : Icons.layers_outlined,
                        title: t.openOverlayPermission,
                        subtitle: _overlayReady ? t.overlayReady : t.overlayNeeded,
                        ready: _overlayReady,
                      ),
                    ],
                    const Divider(height: 18),
                    _PermissionStatusTile(
                      icon: Icons.location_on_outlined,
                      title: t.allowLocationForZones,
                      subtitle: t.permZones,
                      ready: false,
                      tint: DetoxColors.accentSoft,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_waitingFromUsage || _waitingFromOverlay)
                GlassCard(
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.returnAndRefresh,
                          style: TextStyle(color: mutedColor),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                FilledButton.icon(
                  onPressed: _checking ? null : _openUsageSettings,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(t.openUsageAccess),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _checking ? null : _openOverlaySettings,
                  icon: const Icon(Icons.layers_outlined),
                  label: Text(t.openOverlayPermission),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _checking ? null : _refresh,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(t.continueText),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _checking ? null : _enableLocation,
                icon: const Icon(Icons.location_searching_rounded),
                label: Text(t.allowLocationForZones),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ready,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ready;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = ready ? Colors.greenAccent : (tint ?? DetoxColors.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: DetoxColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
