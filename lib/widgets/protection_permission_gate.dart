import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_blocking_service.dart';
import '../services/focus_notification_service.dart';
import '../services/location_zone_service.dart';

/// Checks the permissions needed before saving an enabled protection.
Future<bool> ensureProtectionPermissions(
  BuildContext context, {
  required bool forZone,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  final es = Localizations.localeOf(context).languageCode == 'es';

  if (forZone) {
    final location = await LocationZoneService.instance.ensurePermissions();
    if (location == LocationPermission.denied ||
        location == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final granted = await _showPermissionDialog(
        context,
        title: es ? 'Ubicación' : 'Location',
        detail: es
            ? 'Activa la ubicación para usar esta zona.'
            : 'Enable location to use this zone.',
        openSettings: () async {
          if (!await Geolocator.isLocationServiceEnabled()) {
            return Geolocator.openLocationSettings();
          }
          return Geolocator.openAppSettings();
        },
        isGranted: () async {
          final permission = await Geolocator.checkPermission();
          return permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever &&
              await Geolocator.isLocationServiceEnabled();
        },
      );
      if (!granted) return false;
    }
  }

  final blocker = AppBlockingService.instance;
  if (!await blocker.hasOverlayPermission()) {
    if (!context.mounted) return false;
    final granted = await _showPermissionDialog(
      context,
      title: es ? 'Superposición' : 'Overlay',
      detail: es
          ? 'Permite que Detox se muestre sobre otras apps para bloquearlas.'
          : 'Allow Detox to appear over other apps to block them.',
      openSettings: () async {
        await blocker.openOverlayPermissionSettings();
        return true;
      },
      isGranted: blocker.hasOverlayPermission,
    );
    if (!granted) return false;
  }

  final notifications = FocusNotificationService.instance;
  if (!await notifications.hasPermission()) {
    if (!context.mounted) return false;
    final granted = await _showPermissionDialog(
      context,
      title: es ? 'Notificaciones' : 'Notifications',
      detail: es
          ? 'Permite las notificaciones de Detox para esta protección.'
          : 'Allow Detox notifications for this protection.',
      openSettings: () async {
        if (await notifications.requestPermission()) return true;
        await notifications.openNotificationSettings();
        return true;
      },
      isGranted: notifications.hasPermission,
    );
    if (!granted) return false;
  }

  return context.mounted;
}

Future<bool> _showPermissionDialog(
  BuildContext context, {
  required String title,
  required String detail,
  required Future<bool> Function() openSettings,
  required Future<bool> Function() isGranted,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PermissionDialog(
          title: title,
          detail: detail,
          openSettings: openSettings,
          isGranted: isGranted,
        ),
      ) ??
      false;
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.title,
    required this.detail,
    required this.openSettings,
    required this.isGranted,
  });

  final String title;
  final String detail;
  final Future<bool> Function() openSettings;
  final Future<bool> Function() isGranted;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final granted = await widget.isGranted();
    if (granted && mounted && !_completed) {
      _completed = true;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      await widget.openSettings();
      if (mounted) await _check();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.detail),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(es ? 'Ahora no' : 'Not now'),
        ),
        FilledButton(
          onPressed: _busy ? null : _open,
          child: Text(es ? 'Abrir ajustes' : 'Open settings'),
        ),
      ],
    );
  }
}
