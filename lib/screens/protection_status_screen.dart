import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_blocking_service.dart';
import '../services/app_catalog_service.dart';
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

  Widget _permissionRow(String title, bool ready, VoidCallback action) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ready ? Icons.check_circle_outline : Icons.warning_amber_rounded,
        color: ready ? DetoxColors.success : DetoxColors.warning,
      ),
      title: Text(title),
      subtitle: Text(ready
          ? (_es ? 'Disponible' : 'Available')
          : (_es ? 'Requiere atención' : 'Needs attention')),
      trailing: ready ? null : const Icon(Icons.open_in_new_rounded),
      onTap: ready ? null : action,
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
                    _permissionRow(_es ? 'Acceso al uso' : 'Usage access',
                        status.usageReady, () {
                      AppBlockingService.instance.openUsageAccessSettings();
                    }),
                    _permissionRow(_es ? 'Mostrar sobre apps' : 'Display over apps',
                        status.overlayReady, () {
                      AppBlockingService.instance.openOverlayPermissionSettings();
                    }),
                    if (status.locationNeeded)
                      _permissionRow(_es ? 'Ubicación' : 'Location',
                          status.locationReady, () {
                        Geolocator.openAppSettings();
                      }),
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
    required this.locationNeeded,
    required this.locationReady,
    required this.zoneState,
  });

  final List<ActiveBlockingSource> sources;
  final Map<String, String> names;
  final bool usageReady;
  final bool overlayReady;
  final bool locationNeeded;
  final bool locationReady;
  final ZoneState zoneState;
}
