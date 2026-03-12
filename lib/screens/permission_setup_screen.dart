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
    if (state == AppLifecycleState.resumed && (_waitingFromUsage || _waitingFromOverlay)) {
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

    final skipStrictPermissions = kIsWeb || defaultTargetPlatform != TargetPlatform.android;
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

    final skipStrictPermissions = kIsWeb || defaultTargetPlatform != TargetPlatform.android;
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
    final cardBorder = isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder;

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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                t.permissionsIntro,
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor),
              ),
              const SizedBox(height: 26),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.whatDetoxUses, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    SizedBox(height: 12),
                    _PermissionBullet(icon: Icons.analytics_outlined, text: t.permReadUsage),
                    SizedBox(height: 10),
                    _PermissionBullet(icon: Icons.shield_rounded, text: t.permShield),
                    SizedBox(height: 10),
                    _PermissionBullet(icon: Icons.location_on_outlined, text: t.permZones),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.permissionStatus, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 12),
                    _StatusRow(
                      icon: _usageReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: _usageReady ? Colors.greenAccent : DetoxColors.accentSoft,
                      label: _message,
                    ),
                    if (defaultTargetPlatform == TargetPlatform.android) ...[
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: _overlayReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        color: _overlayReady ? Colors.greenAccent : Colors.orangeAccent,
                        label: _overlayReady
                            ? t.overlayReady
                            : t.overlayNeeded,
                      ),
                    ],
                    if (_waitingFromUsage || _waitingFromOverlay) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
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
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.specialPermissionsTitle, style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        t.specialPermissionsBody,
                        style: TextStyle(color: mutedColor),
                      ),
                      const SizedBox(height: 14),
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
                    ],
                  ),
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
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await _storageService.saveOnboardingDone(true);
                  if (mounted) widget.onFinished();
                },
                child: Text(t.skipForNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? DetoxColors.muted
                  : DetoxColors.lightMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionBullet extends StatelessWidget {
  const _PermissionBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? DetoxColors.muted
        : DetoxColors.lightMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DetoxColors.accentSoft, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}
