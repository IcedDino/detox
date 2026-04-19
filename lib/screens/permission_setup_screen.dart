import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n_app_strings.dart';
import '../services/app_blocking_service.dart';
import '../services/focus_notification_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detox_logo.dart';
import '../widgets/ui_kit.dart';

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
  bool _notificationsReady = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
  bool _locationReady = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;

  bool _waitingFromUsage = false;
  bool _waitingFromOverlay = false;
  bool _waitingFromNotifications = false;
  bool _waitingFromLocation = false;

  String _usageMessage = '…';
  String _overlayMessage = '…';
  String _notificationsMessage = '…';
  String _locationMessage = '…';

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _allReady =>
      _usageReady && _overlayReady && _notificationsReady && _locationReady;
  int get _grantedCount => [
        _usageReady,
        _overlayReady,
        _notificationsReady,
        _locationReady,
      ].where((ready) => ready).length;

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
        (_waitingFromUsage ||
            _waitingFromOverlay ||
            _waitingFromNotifications ||
            _waitingFromLocation)) {
      _refreshWithGracePeriod();
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _checking = true);
    }

    final usageStatus = await _usageService.getPermissionStatus();
    final overlayReady = await AppBlockingService.instance.hasOverlayPermission();
    final notificationsReady = await FocusNotificationService.instance.hasPermission();
    final locationStatus = await _readLocationStatus();

    if (!mounted) return;
    setState(() {
      _usageReady = usageStatus.usageReady;
      _overlayReady = overlayReady;
      _notificationsReady = notificationsReady;
      _locationReady = locationStatus.ready;

      _usageMessage = usageStatus.platformMessage;
      _overlayMessage = overlayReady
          ? (AppStrings.of(context).isEs
              ? 'Detox ya puede cubrir apps bloqueadas durante tus sesiones.'
              : 'Detox can already cover blocked apps during your sessions.')
          : (AppStrings.of(context).isEs
              ? 'Activa este permiso para que el bloqueo aparezca encima de la app correcta.'
              : 'Enable this so Detox can appear on top of the correct app.');
      _notificationsMessage = notificationsReady
          ? (AppStrings.of(context).isEs
              ? 'Las notificaciones están listas para mostrar temporizador, recordatorios y avisos del padrino.'
              : 'Notifications are ready for timers, reminders, and sponsor alerts.')
          : (AppStrings.of(context).isEs
              ? 'Permite notificaciones para ver el tiempo restante y avisos importantes de Detox.'
              : 'Allow notifications to see remaining time and important Detox alerts.');
      _locationMessage = locationStatus.message;

      _checking = false;
      _waitingFromUsage = false;
      _waitingFromOverlay = false;
      _waitingFromNotifications = false;
      _waitingFromLocation = false;
    });

    final skipStrictPermissions = kIsWeb || defaultTargetPlatform != TargetPlatform.android;
    if (_allReady || skipStrictPermissions) {
      await _storageService.saveOnboardingDone(true);
      if (mounted) widget.onFinished();
    }
  }

  Future<void> _refreshWithGracePeriod() async {
    if (!mounted) return;
    setState(() => _checking = true);

    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _refresh(silent: true);
  }

  Future<_LocationStatus> _readLocationStatus() async {
    final t = AppStrings.of(context);
    if (!_isAndroid) {
      return _LocationStatus(
        ready: true,
        message: t.isEs
            ? 'Ubicación lista.'
            : 'Location ready.',
      );
    }

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return _LocationStatus(
        ready: false,
        message: t.isEs
            ? 'Activa la ubicación del teléfono para usar zonas de concentración automáticas.'
            : 'Turn on device location to use automatic concentration zones.',
      );
    }

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return _LocationStatus(
          ready: true,
          message: t.isEs
              ? 'La ubicación ya está lista para zonas y automatizaciones.'
              : 'Location is ready for zones and automations.',
        );
      case LocationPermission.deniedForever:
        return _LocationStatus(
          ready: false,
          message: t.isEs
              ? 'La ubicación está bloqueada. Actívala desde Configuración para usar zonas.'
              : 'Location is blocked. Turn it on in Settings to use zones.',
        );
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return _LocationStatus(
          ready: false,
          message: t.isEs
              ? 'Permite ubicación para activar Detox automáticamente cuando llegues a una zona.'
              : 'Allow location to auto-start Detox when you arrive at a zone.',
        );
    }
  }

  Future<void> _openUsageSettings() async {
    setState(() {
      _waitingFromUsage = true;
    });
    await _usageService.openUsageAccessSettings();
  }

  Future<void> _openOverlaySettings() async {
    setState(() {
      _waitingFromOverlay = true;
    });
    await AppBlockingService.instance.openOverlayPermissionSettings();
  }

  Future<void> _requestNotificationPermission() async {
    if (!_isAndroid) return;
    setState(() {
      _waitingFromNotifications = true;
      _checking = true;
    });
    await FocusNotificationService.instance.requestPermission();
    await _refresh(silent: true);
  }

  Future<void> _enableLocation() async {
    if (!_isAndroid) return;

    setState(() {
      _waitingFromLocation = true;
    });

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    await _refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;
    final progress = _grantedCount / 4;

    return Scaffold(
      body: DetoxBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Center(child: DetoxLogo(size: 84, showLabel: true)),
              const SizedBox(height: 20),
              AppPageHeader(
                title: t.isEs ? 'Activa los 4 permisos' : 'Turn on all 4 permissions',
                subtitle: t.isEs
                    ? 'Necesitamos estos permisos para bloquear apps bien, mostrar el escudo de enfoque y activar automatizaciones sin fallos.'
                    : 'Detox needs these permissions to block apps correctly, show the focus shield, and run automations reliably.',
                eyebrow: t.isEs ? 'Último paso antes de entrar' : 'Last step before you start',
                icon: Icons.shield_rounded,
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.isEs
                                ? 'Llevas $_grantedCount de 4 permisos listos'
                                : 'You have $_grantedCount of 4 permissions ready',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        StatusPill(
                          label: _allReady
                              ? (t.isEs ? 'Todo listo' : 'All set')
                              : (t.isEs ? 'Faltan pasos' : 'More steps'),
                          icon: _allReady
                              ? Icons.check_circle_rounded
                              : (_checking
                                  ? Icons.autorenew_rounded
                                  : Icons.pending_actions_rounded),
                          color: _allReady
                              ? DetoxColors.success
                              : (_checking ? DetoxColors.accentSoft : DetoxColors.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0x140C2242),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.isEs
                          ? 'La app avanzará automáticamente cuando los 4 permisos estén aceptados.'
                          : 'The app will continue automatically as soon as all 4 permissions are accepted.',
                      style: TextStyle(color: mutedColor, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PermissionCard(
                title: t.isEs ? 'Datos de uso' : 'Usage access',
                subtitle: t.isEs
                    ? 'Sirve para detectar qué app está abierta y medir tu tiempo real de uso.'
                    : 'Lets Detox detect which app is open and measure your real screen time.',
                detail: _usageMessage,
                icon: Icons.bar_chart_rounded,
                ready: _usageReady,
                waiting: _waitingFromUsage,
                actionLabel: t.isEs ? 'Activar datos de uso' : 'Turn on usage access',
                onPressed: _checking ? null : _openUsageSettings,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                title: t.isEs ? 'Superposición' : 'Overlay',
                subtitle: t.isEs
                    ? 'Permite mostrar la pantalla de bloqueo arriba de las apps distraídas.'
                    : 'Allows Detox to show the blocking screen on top of distracting apps.',
                detail: _overlayMessage,
                icon: Icons.layers_rounded,
                ready: _overlayReady,
                waiting: _waitingFromOverlay,
                actionLabel: t.isEs ? 'Activar superposición' : 'Turn on overlay',
                onPressed: _checking ? null : _openOverlaySettings,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                title: t.isEs ? 'Notificaciones' : 'Notifications',
                subtitle: t.isEs
                    ? 'Muestran el temporizador activo, recordatorios y avisos importantes.'
                    : 'Shows your active timer, reminders, and important alerts.',
                detail: _notificationsMessage,
                icon: Icons.notifications_active_rounded,
                ready: _notificationsReady,
                waiting: _waitingFromNotifications,
                actionLabel: t.isEs ? 'Permitir notificaciones' : 'Allow notifications',
                onPressed: _checking ? null : _requestNotificationPermission,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                title: t.isEs ? 'Ubicación' : 'Location',
                subtitle: t.isEs
                    ? 'Se usa para activar zonas de concentración y horarios automáticos según tu lugar.'
                    : 'Used to start concentration zones and automatic schedules based on where you are.',
                detail: _locationMessage,
                icon: Icons.location_on_rounded,
                ready: _locationReady,
                waiting: _waitingFromLocation,
                actionLabel: t.isEs ? 'Permitir ubicación' : 'Allow location',
                onPressed: _checking ? null : _enableLocation,
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: DetoxColors.accent.withOpacity(isDark ? 0.14 : 0.10),
                      ),
                      child: const Icon(
                        Icons.favorite_outline_rounded,
                        color: DetoxColors.accentSoft,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.isEs ? 'Todo explicado de forma simple' : 'Everything explained simply',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.isEs
                                ? 'Detox no te lanzará a pantallas técnicas. Solo toca cada botón y vuelve a la app. Cuando los 4 permisos estén listos, entrarás automáticamente.'
                                : 'Detox keeps this simple: tap each button and come back. As soon as all 4 permissions are ready, you will enter automatically.',
                            style: TextStyle(color: mutedColor, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.ready,
    required this.waiting,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final bool ready;
  final bool waiting;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: ready
                      ? DetoxColors.success.withOpacity(isDark ? 0.16 : 0.12)
                      : DetoxColors.accent.withOpacity(isDark ? 0.14 : 0.10),
                ),
                child: Icon(
                  ready ? Icons.check_rounded : icon,
                  color: ready ? DetoxColors.success : DetoxColors.accentSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(color: mutedColor, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: waiting
                    ? (AppStrings.of(context).isEs ? 'Revisando...' : 'Checking...')
                    : (ready
                        ? (AppStrings.of(context).isEs ? 'Listo' : 'Ready')
                        : (AppStrings.of(context).isEs ? 'Pendiente' : 'Pending')),
                icon: waiting
                    ? Icons.hourglass_top_rounded
                    : (ready ? Icons.check_circle_rounded : Icons.schedule_rounded),
                color: waiting
                    ? DetoxColors.accentSoft
                    : (ready ? DetoxColors.success : DetoxColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFF7FAFF),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0x120C2242),
              ),
            ),
            child: Text(
              detail,
              style: TextStyle(color: mutedColor, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ready
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(AppStrings.of(context).isEs ? 'Ya activado' : 'Already enabled'),
                  )
                : FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(waiting ? Icons.autorenew_rounded : icon),
                    label: Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocationStatus {
  const _LocationStatus({required this.ready, required this.message});

  final bool ready;
  final String message;
}
