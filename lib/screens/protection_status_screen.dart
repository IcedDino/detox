import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_blocking_service.dart';
import '../services/app_catalog_service.dart';
import '../services/focus_notification_service.dart';
import '../services/location_zone_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ProtectionStatusScreen extends StatefulWidget {
  const ProtectionStatusScreen({super.key});

  @override
  State<ProtectionStatusScreen> createState() => _ProtectionStatusScreenState();
}

class _ProtectionStatusScreenState extends State<ProtectionStatusScreen>
    with WidgetsBindingObserver {
  late Future<_ProtectionStatus> _status = _load();

  bool get _es => Localizations.localeOf(context).languageCode == 'es';

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
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = _load();
    setState(() => _status = next);
    await next;
  }

  Future<_ProtectionStatus> _load() async {
    final blocker = AppBlockingService.instance;
    final sources = await blocker.getActiveSources();
    final usage = await blocker.hasUsageAccess();
    final overlay = await blocker.hasOverlayPermission();
    final notifications = await FocusNotificationService.instance.hasPermission();
    final zones = await StorageService().loadConcentrationZones();
    final locationNeeded = zones.any((zone) => zone.enabled);
    var locationReady = true;
    if (locationNeeded && !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      final permission = await Geolocator.checkPermission();
      locationReady = permission == LocationPermission.always &&
          await Geolocator.isLocationServiceEnabled();
    }
    final apps = await AppCatalogService().loadInstalledApps();
    return _ProtectionStatus(
      sources: sources,
      names: {for (final app in apps) app.packageName: app.name},
      usageReady: usage,
      overlayReady: overlay,
      notificationsReady: notifications,
      locationNeeded: locationNeeded,
      locationReady: locationReady,
      zoneState: LocationZoneService.instance.currentState,
    );
  }

  String _sourceTitle(ActiveBlockingSource source) {
    if (source.source == 'zone') return _es ? 'Zona' : 'Zone';
    if (source.source == 'automation') {
      return _es ? 'Horario automático' : 'Automatic schedule';
    }
    if (source.source == 'focus') {
      return _es ? 'Sesión de enfoque' : 'Focus session';
    }
    if (source.source.startsWith('smart_break_')) {
      return _es ? 'Pausa inteligente' : 'Smart pause';
    }
    return _es ? 'Otra protección' : 'Other protection';
  }

  Widget _permissionRow({
    required String title,
    required String description,
    required bool ready,
    required VoidCallback action,
    bool needed = true,
  }) {
    final theme = Theme.of(context);
    final statusColor = !needed
        ? theme.colorScheme.onSurfaceVariant
        : ready
            ? DetoxColors.success
            : DetoxColors.warning;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        !needed
            ? Icons.info_outline_rounded
            : ready
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
        color: statusColor,
      ),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              !needed
                  ? (_es ? 'No se necesita ahora' : 'Not needed right now')
                  : ready
                      ? (_es ? 'Disponible' : 'Available')
                      : (_es ? 'Requiere atención' : 'Needs attention'),
              style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ],
        ),
      ),
      trailing: needed && !ready
          ? const Icon(Icons.open_in_new_rounded)
          : null,
      onTap: needed && !ready ? action : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_es ? 'Protección activa' : 'Active protection')),
      body: DetoxBackground(
        child: SafeArea(
          child: FutureBuilder<_ProtectionStatus>(
            future: _status,
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_es ? 'Reintentar' : 'Retry'),
                  ),
                );
              }
              final status = snapshot.requireData;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      status.sources.isEmpty
                          ? (_es ? 'No hay apps bloqueadas ahora.' : 'No apps are blocked now.')
                          : (_es ? 'Estas reglas bloquean apps ahora.' : 'These rules are blocking apps now.'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    for (final source in status.sources) ...[
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_sourceTitle(source),
                                style: Theme.of(context).textTheme.titleMedium),
                            if (source.source == 'zone' && source.reason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(source.reason.replaceFirst('Study zone: ',
                                  _es ? 'Zona: ' : 'Zone: ')),
                            ],
                            if (source.expiresAt != null && source.source != 'zone') ...[
                              const SizedBox(height: 4),
                              Text(_es
                                  ? 'Hasta ${TimeOfDay.fromDateTime(source.expiresAt!).format(context)}'
                                  : 'Until ${TimeOfDay.fromDateTime(source.expiresAt!).format(context)}'),
                            ],
                            const SizedBox(height: 10),
                            Text(source.blockedPackages
                                .map((name) => status.names[name] ?? name)
                                .join(', ')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (status.locationNeeded) ...[
                      const SizedBox(height: 12),
                      Text(_es ? 'Ubicación de zonas' : 'Zone location',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(status.zoneState.message ??
                          (status.zoneState.insideZone
                              ? (_es ? 'Dentro de una zona' : 'Inside a zone')
                              : (_es ? 'Fuera de las zonas' : 'Outside zones'))),
                    ],
                    const SizedBox(height: 24),
                    Text(_es ? 'Permisos' : 'Permissions',
                        style: Theme.of(context).textTheme.titleMedium),
                    _permissionRow(
                      title: _es ? 'Acceso al uso' : 'Usage access',
                      description: _es
                          ? 'Permite reconocer las apps que abres y aplicar límites y bloqueos que configures.'
                          : 'Lets Detox recognize the apps you open and apply the limits and blocks you set.',
                      ready: status.usageReady,
                      action: () => AppBlockingService.instance
                          .openUsageAccessSettings(),
                    ),
                    _permissionRow(
                      title: _es ? 'Mostrar sobre apps' : 'Display over apps',
                      description: _es
                          ? 'Permite mostrar la pantalla de bloqueo encima de las apps seleccionadas durante el enfoque.'
                          : 'Lets Detox show a blocking screen over selected apps during focus.',
                      ready: status.overlayReady,
                      action: () => AppBlockingService.instance
                          .openOverlayPermissionSettings(),
                    ),
                    _permissionRow(
                      title: _es ? 'Notificaciones' : 'Notifications',
                      description: _es
                          ? 'Muestra el tiempo de enfoque y los avisos mientras la protección está activa.'
                          : 'Shows focus time and alerts while protection is active.',
                      ready: status.notificationsReady,
                      action: () => FocusNotificationService.instance
                          .openNotificationSettings(),
                    ),
                    _permissionRow(
                      title: _es
                          ? 'Ubicación en segundo plano'
                          : 'Background location',
                      description: _es
                          ? 'Activa o pausa las zonas al entrar o salir, incluso con Detox cerrada.'
                          : 'Activates or pauses zones when you enter or leave, even while Detox is closed.',
                      ready: status.locationReady,
                      needed: status.locationNeeded,
                      action: Geolocator.openAppSettings,
                    ),
                    const SizedBox(height: 12),
                    Text(_es
                        ? 'Si una app sigue bloqueada al apagar una zona, revisa si hay otra regla activa arriba.'
                        : 'If an app remains blocked after turning off a zone, check for another active rule above.'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProtectionStatus {
  const _ProtectionStatus({
    required this.sources,
    required this.names,
    required this.usageReady,
    required this.overlayReady,
    required this.notificationsReady,
    required this.locationNeeded,
    required this.locationReady,
    required this.zoneState,
  });

  final List<ActiveBlockingSource> sources;
  final Map<String, String> names;
  final bool usageReady;
  final bool overlayReady;
  final bool notificationsReady;
  final bool locationNeeded;
  final bool locationReady;
  final ZoneState zoneState;
}
