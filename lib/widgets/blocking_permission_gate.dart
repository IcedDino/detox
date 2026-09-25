import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n_app_strings.dart';
import '../services/app_blocking_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';

/// Makes sure the Android permissions that keep the shield working — including
/// while Detox is in the background — are ready before a focus session that
/// needs blocking starts.
///
/// Usage access and overlay cannot be requested with a native system pop-up, so
/// a short in-app dialog drives the user through each Settings screen, one tap
/// each, right at the moment they are needed. The battery optimization
/// exemption is asked in the same pass, because without it Android can kill the
/// shield service when the screen is off or Detox is not in the foreground.
///
/// Returns true when the session may start (permissions already granted, or
/// the user chose to continue without blocking). Returns false when the user
/// aborts.
Future<bool> ensureBlockingPermissions(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;

  final usageReady = await UsageService()
      .getPermissionStatus()
      .then((status) => status.usageReady);
  final overlayReady = await AppBlockingService.instance.hasOverlayPermission();
  final backgroundReady =
      await AppBlockingService.instance.isIgnoringBatteryOptimizations();
  if (usageReady && overlayReady && backgroundReady) return true;

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BlockingPermissionsDialog(),
  );
  return result ?? false;
}

class _BlockingPermissionsDialog extends StatefulWidget {
  const _BlockingPermissionsDialog();

  @override
  State<_BlockingPermissionsDialog> createState() =>
      _BlockingPermissionsDialogState();
}

class _BlockingPermissionsDialogState extends State<_BlockingPermissionsDialog>
    with WidgetsBindingObserver {
  bool _usageReady = false;
  bool _overlayReady = false;
  bool _backgroundReady = false;
  bool _checking = true;
  bool _waitingSettings = false;

  /// One flag per permission so each pass through Settings visits every missing
  /// screen exactly once instead of looping.
  bool _openedUsage = false;
  bool _openedOverlay = false;
  bool _openedBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final usageReady = await UsageService()
        .getPermissionStatus()
        .then((status) => status.usageReady);
    final overlayReady =
        await AppBlockingService.instance.hasOverlayPermission();
    final backgroundReady =
        await AppBlockingService.instance.isIgnoringBatteryOptimizations();
    if (!mounted) return;

    setState(() {
      _usageReady = usageReady;
      _overlayReady = overlayReady;
      _backgroundReady = backgroundReady;
      _checking = false;
    });

    if (usageReady && overlayReady && backgroundReady) {
      Navigator.of(context).pop(true);
      return;
    }

    // The user already consented once (they tapped the activate button), so
    // chain straight into the next Settings screen to keep it one tap each.
    if (_waitingSettings) {
      await _openNextMissing();
    }
  }

  Future<void> _activate() async {
    setState(() {
      _waitingSettings = true;
      _openedUsage = false;
      _openedOverlay = false;
      _openedBackground = false;
    });
    await _openNextMissing();
  }

  Future<void> _openNextMissing() async {
    if (!mounted) return;

    if (!_usageReady && !_openedUsage) {
      _openedUsage = true;
      await UsageService().openUsageAccessSettings();
      return;
    }
    if (!_overlayReady && !_openedOverlay) {
      _openedOverlay = true;
      await AppBlockingService.instance.openOverlayPermissionSettings();
      return;
    }
    if (!_backgroundReady && !_openedBackground) {
      _openedBackground = true;
      await AppBlockingService.instance.openBatteryOptimizationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(detoxRadius)),
      title: Text(t.isEs ? 'Activa 3 permisos' : 'Enable 3 permissions'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.isEs
                ? 'Para cubrir las apps bloqueadas y seguir protegiéndote con la pantalla apagada, Detox necesita Datos de uso, Superposición y trabajo en segundo plano. Te llevamos a cada ajuste: es un toque por permiso.'
                : 'To cover blocked apps and keep protecting you with the screen off, Detox needs Usage access, Overlay and background work. We will take you to each setting: one tap per permission.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: mutedColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          _permissionRow(t.isEs ? 'Datos de uso' : 'Usage access', _usageReady),
          const SizedBox(height: 8),
          _permissionRow(t.isEs ? 'Superposición' : 'Overlay', _overlayReady),
          const SizedBox(height: 8),
          _permissionRow(
            t.isEs ? 'Segundo plano' : 'Background work',
            _backgroundReady,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _checking ? null : _activate,
              child: _waitingSettings
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            t.isEs
                                ? 'Concede el permiso y vuelve'
                                : 'Grant it, then come back',
                          ),
                        ),
                      ],
                    )
                  : Text(t.isEs ? 'Activar en Ajustes' : 'Enable in Settings'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.isEs ? 'Iniciar sin bloqueo' : 'Start without blocking'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                t.isEs ? 'Ahora no' : 'Not now',
                style: TextStyle(color: mutedColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionRow(String label, bool ready) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = ready ? DetoxColors.success : DetoxColors.warning;

    return Row(
      children: [
        Icon(
          _checking
              ? Icons.autorenew_rounded
              : (ready ? Icons.check_circle_rounded : Icons.schedule_rounded),
          size: 18,
          color: _checking
              ? (isDark ? DetoxColors.muted : DetoxColors.lightMuted)
              : color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 8),
        Text(
          _checking
              ? '…'
              : (ready
                  ? (t.isEs ? 'Listo' : 'Ready')
                  : (t.isEs ? 'Pendiente' : 'Pending')),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: detoxWeightEmphasis,
              ),
        ),
      ],
    );
  }
}
