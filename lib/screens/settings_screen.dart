import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/auth_user.dart';
import '../models/concentration_zone.dart';
import '../models/installed_app_entry.dart';
import '../models/sponsor_profile.dart';
import '../screens/automation_settings_screen.dart';
import '../screens/sponsor_screen.dart';
import '../services/app_blocking_service.dart';
import '../services/anti_bypass_service.dart';
import '../services/app_catalog_service.dart';
import '../services/location_zone_service.dart';
import '../services/sponsor_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/ui_kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.currentUser,
    required this.onSignOut,
    required this.localeCode,
    required this.onLocaleChanged,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final AuthUser? currentUser;
  final Future<void> Function() onSignOut;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final StorageService _storageService = StorageService();
  final UsageService _usageService = UsageService();
  final AppCatalogService _catalogService = AppCatalogService();

  bool _loading = true;
  int _dailyLimit = 180;
  bool _overlayReady =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
  List<AppLimit> _appLimits = const [];
  List<InstalledAppEntry> _installedApps = const [];
  List<ConcentrationZone> _zones = const [];
  bool _hasSponsor = false;
  bool _settingsUnlockActive = false;
  String _mySponsorCode = '';
  SponsorProfile? _sponsorProfile;
  DateTime? _settingsUnlockUntil;
  ZoneState _zoneState = LocationZoneService.instance.currentState;
  StreamSubscription<ZoneState>? _zoneSubscription;
  bool _antiBypassHealthy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _zoneSubscription = LocationZoneService.instance.states.listen((state) {
      if (!mounted) return;
      setState(() => _zoneState = state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoneSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.currentUser != null) {
      await SponsorService.instance
          .ensureCurrentUserInitialized(widget.currentUser);
    }

    final results = await Future.wait<dynamic>([
      _storageService.loadDailyLimitMinutes(),
      _storageService.loadAppLimits(),
      _catalogService.loadInstalledApps(),
      _storageService.loadConcentrationZones(),
      AppBlockingService.instance.hasOverlayPermission(),
      SponsorService.instance.hasSponsor(),
      SponsorService.instance.getCurrentSponsorProfile(),
      SponsorService.instance.hasActiveSettingsUnlock(),
      SponsorService.instance.getSettingsUnlockUntil(),
      SponsorService.instance.getMySponsorCode(),
      AntiBypassService.instance.getStatus(),
    ]);

    if (!mounted) return;

    setState(() {
      _dailyLimit = results[0] as int;
      _appLimits = results[1] as List<AppLimit>;
      _installedApps = results[2] as List<InstalledAppEntry>;
      _zones = results[3] as List<ConcentrationZone>;
      _overlayReady = results[4] as bool;
      _hasSponsor = results[5] as bool;
      _sponsorProfile = results[6] as SponsorProfile?;
      _settingsUnlockActive = results[7] as bool;
      _settingsUnlockUntil = results[8] as DateTime?;
      _mySponsorCode = results[9] as String;
      _antiBypassHealthy = (results[10] as AntiBypassStatus).healthy;
      _loading = false;
    });
  }

  Future<bool> _ensureProtectedSettingsAccess() async {
    if (!_hasSponsor || _settingsUnlockActive) return true;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sponsor approval required',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Protected changes need sponsor approval.',
              style: TextStyle(color: DetoxColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'request'),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Request approval'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, 'open'),
              child: const Text('Sponsor center'),
            ),
          ],
        ),
      ),
    );

    if (action == 'request') {
      try {
        await SponsorService.instance.createUnlockRequest(
          requestType: 'settings_unlock',
          durationMinutes: 10,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Approval request sent.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          );
        }
      }
      return false;
    }

    if (action == 'open') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SponsorScreen()),
      );
      await _load();
      return _settingsUnlockActive;
    }

    return false;
  }
  Future<void> _addAppLimit() async {
    final created = await showModalBottomSheet<AppLimit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppPickerSheet(
        apps: _installedApps,
        existing: _appLimits,
      ),
    );

    if (created != null) {
      final next = [..._appLimits, created]
        ..sort(
              (a, b) => a.appName.toLowerCase().compareTo(
            b.appName.toLowerCase(),
          ),
        );
      setState(() => _appLimits = next);
      await _storageService.saveAppLimits(_appLimits);
    }
  }

  Future<void> _removeAppLimit(AppLimit item) async {
    if (!await _ensureProtectedSettingsAccess()) return;
    final next = _appLimits.where((e) => e.appName != item.appName).toList();
    setState(() => _appLimits = next);
    await _storageService.saveAppLimits(_appLimits);
  }

  Future<void> _toggleFocus(AppLimit item, bool value) async {
    if (item.useInFocusMode &&
        !value &&
        !await _ensureProtectedSettingsAccess()) {
      return;
    }

    final next = _appLimits
        .map(
          (e) => e.appName == item.appName
          ? e.copyWith(useInFocusMode: value)
          : e,
    )
        .toList();

    setState(() => _appLimits = next);
    await _storageService.saveAppLimits(_appLimits);
  }

  Future<void> _addZone() async {
    final zone = await showModalBottomSheet<ConcentrationZone>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ZoneEditorSheet(appLimits: _appLimits),
    );

    if (zone == null) return;

    final next = [..._zones, zone];
    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(next);
    await LocationZoneService.instance.refresh();
  }

  Future<void> _editZone(ConcentrationZone zone) async {
    if (!await _ensureProtectedSettingsAccess()) return;
    final updatedZone = await showModalBottomSheet<ConcentrationZone>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ZoneEditorSheet(
        appLimits: _appLimits,
        initialZone: zone,
      ),
    );

    if (updatedZone == null) return;

    final next = _zones
        .map((e) => e.id == zone.id ? updatedZone : e)
        .toList();
    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(next);
    await LocationZoneService.instance.refresh();
  }

  Future<void> _toggleZone(ConcentrationZone zone, bool value) async {
    if (zone.enabled != value &&
        !await _ensureProtectedSettingsAccess()) {
      return;
    }

    final next = _zones
        .map((e) => e.id == zone.id ? e.copyWith(enabled: value) : e)
        .toList();

    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(next);
    await LocationZoneService.instance.refresh();
  }

  Future<void> _removeZone(ConcentrationZone zone) async {
    if (!await _ensureProtectedSettingsAccess()) return;
    final next = _zones.where((e) => e.id != zone.id).toList();
    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(next);
    await LocationZoneService.instance.refresh();
  }

  Future<void> _openOverlaySettings() async {
    await AppBlockingService.instance.openOverlayPermissionSettings();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final ready = await AppBlockingService.instance.hasOverlayPermission();
    if (!mounted) return;
    setState(() => _overlayReady = ready);
  }

  Future<void> _openUsageSettings() async {
    await _usageService.openUsageAccessSettings();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _load();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              if (widget.currentUser != null) ...[
                HeroInfoCard(
                  icon: Icons.person_outline_rounded,
                  title: widget.currentUser!.displayName,
                  subtitle: widget.currentUser!.email,
                  badge: StatusPill(
                    label: widget.currentUser!.provider,
                    icon: Icons.verified_user_outlined,
                  ),
                  child: Column(
                    children: [
                      SoftActionTile(
                        icon: Icons.logout_rounded,
                        title: t.signOut,
                        subtitle: t.returnLoginScreen,
                        color: DetoxColors.warning,
                        onTap: () async {
                          await widget.onSignOut();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              HeroInfoCard(
                icon: Icons.handshake_outlined,
                title: t.sponsorCenter,
                subtitle: _hasSponsor
                    ? (_sponsorProfile?.displayName ?? '')
                    : '${t.yourCode}: ${_mySponsorCode.isEmpty ? t.loading : _mySponsorCode}',
                badge: StatusPill(
                  label: _hasSponsor
                      ? (t.isEs ? 'Vínculo activo' : 'Linked')
                      : (t.isEs ? 'Sin padrino' : 'No sponsor'),
                  icon: _hasSponsor ? Icons.check_circle_rounded : Icons.link_off_rounded,
                  color: _hasSponsor ? DetoxColors.success : DetoxColors.warning,
                ),
                action: TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SponsorScreen(),
                      ),
                    );
                    await _load();
                  },
                  child: Text(t.open),
                ),
                child: Column(
                  children: [
                    if (_settingsUnlockActive && _settingsUnlockUntil != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            StatusPill(
                              label: t.settingsUnlockedUntil(
                                '${_settingsUnlockUntil!.hour.toString().padLeft(2, '0')}:${_settingsUnlockUntil!.minute.toString().padLeft(2, '0')}',
                              ),
                              icon: Icons.lock_open_rounded,
                              color: DetoxColors.success,
                            ),
                          ],
                        ),
                      ),
                    SoftActionTile(
                      icon: Icons.shield_outlined,
                      title: t.isEs ? 'Protección con padrino' : 'Sponsor protection',
                      subtitle: _hasSponsor
                          ? (t.isEs
                              ? 'Las acciones sensibles piden aprobación o una pausa autorizada.'
                              : 'Sensitive actions can request approval or an authorized pause.')
                          : (t.isEs
                              ? 'Puedes agregar una persona de confianza para aprobar cambios importantes.'
                              : 'You can add a trusted person to approve important changes.'),
                      trailing: Icon(Icons.chevron_right_rounded, color: muted),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SponsorScreen(),
                          ),
                        );
                        await _load();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle(
                title: t.isEs ? 'Preferencias generales' : 'General preferences',
                subtitle: t.isEs
                    ? 'Aspecto, idioma y tiempo de pantalla diario.'
                    : 'Appearance, language, and your daily screen-time target.',
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    SoftActionTile(
                      icon: widget.darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      title: t.darkMode,
                      subtitle: t.darkModeSubtitle,
                      trailing: Switch(
                        value: widget.darkMode,
                        onChanged: widget.onDarkModeChanged,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoftActionTile(
                      icon: Icons.language_rounded,
                      title: t.language,
                      subtitle: widget.localeCode == 'es' ? 'Español' : 'English',
                      trailing: DropdownButton<String>(
                        value: widget.localeCode,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'es', child: Text('Español')),
                        ],
                        onChanged: (value) {
                          if (value != null) widget.onLocaleChanged(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark ? Colors.white.withOpacity(0.035) : const Color(0xFFF8FAFF),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.06) : DetoxColors.lightCardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.dailyScreenTimeLimit,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.minutesLabel(_dailyLimit),
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            min: 30,
                            max: 480,
                            divisions: 15,
                            label: t.minutesLabel(_dailyLimit),
                            value: _dailyLimit.toDouble(),
                            onChanged: (value) => setState(() => _dailyLimit = value.round()),
                            onChangeEnd: (value) => _storageService.saveDailyLimitMinutes(
                              value.round(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle(
                title: t.perAppLimits,
                subtitle: t.pickAppsBody,
                trailing: IconButton(
                  onPressed: _addAppLimit,
                  icon: const Icon(Icons.add),
                ),
              ),
              const SizedBox(height: 12),
              if (_appLimits.isEmpty)
                GlassCard(
                  child: Text(
                    t.noPerAppLimits,
                    style: TextStyle(color: muted),
                  ),
                )
              else
                GlassCard(
                  child: Column(
                    children: _appLimits.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Column(
                        children: [
                          Row(
                            children: [
                              AppIconBadge(
                                packageName: item.packageName,
                                size: 38,
                                borderRadius: 10,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Switch(
                                value: item.useInFocusMode,
                                onChanged: (value) => _toggleFocus(item, value),
                              ),
                              IconButton(
                                onPressed: () => _removeAppLimit(item),
                                icon: const Icon(Icons.delete_outline),
                                color: muted,
                              ),
                            ],
                          ),
                          if (index != _appLimits.length - 1) ...[
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: isDark ? Colors.white.withOpacity(0.06) : DetoxColors.lightCardBorder,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              SectionTitle(
                title: t.isEs ? 'Horarios de Detox' : 'Detox schedules',
                subtitle: t.isEs
                    ? 'Programa bloqueos automáticos y presets de apps para ciertos momentos del día, incluso sin usar zonas.'
                    : 'Schedule automatic blocking and app presets for certain moments of the day, even without using zones.',
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: SoftActionTile(
                  icon: Icons.schedule_rounded,
                  title: t.isEs ? 'Horarios de Detox' : 'Detox schedules',
                  subtitle: t.isEs
                      ? 'Crea horarios automáticos y presets de apps para clases, trabajo o descanso.'
                      : 'Create automatic schedules and app presets for classes, work, or downtime.',
                  trailing: Icon(Icons.chevron_right_rounded, color: muted),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AutomationSettingsScreen(),
                      ),
                    );
                    await _load();
                  },
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle(
                title: t.concentrationZones,
                subtitle: t.isEs
                    ? 'Espacios donde el enfoque se puede activar solo.'
                    : 'Places where focus can activate automatically.',
                trailing: IconButton(
                  onPressed: _addZone,
                  icon: const Icon(Icons.add_location_alt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              if (_zones.isEmpty)
                GlassCard(
                  child: Text(
                    t.noConcentrationZonesYet,
                    style: TextStyle(color: muted),
                  ),
                )
              else
                GlassCard(
                  child: Column(
                    children: _zones.map((zone) {
                      final inside = _zoneState.zoneName == zone.name && _zoneState.insideZone;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isDark ? Colors.white.withOpacity(0.035) : const Color(0xFFF8FAFF),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.06) : DetoxColors.lightCardBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: (inside ? DetoxColors.success : DetoxColors.accentSoft).withOpacity(0.14),
                                    ),
                                    child: Icon(
                                      inside ? Icons.school_rounded : Icons.location_on_outlined,
                                      color: inside ? DetoxColors.success : DetoxColors.accentSoft,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          zone.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          zone.blockedPackages.isEmpty
                                              ? t.zoneRadiusUsesFocus(zone.radiusMeters.round())
                                              : t.zoneRadiusSelectedApps(zone.radiusMeters.round(), zone.blockedPackages.length),
                                          style: TextStyle(color: muted, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _editZone(zone),
                                    icon: const Icon(Icons.edit_outlined),
                                    color: muted,
                                  ),
                                  IconButton(
                                    onPressed: () => _removeZone(zone),
                                    icon: const Icon(Icons.delete_outline),
                                    color: muted,
                                  ),
                                ],
                              ),
                              if (zone.blockedAppNames.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: zone.blockedAppNames.map((name) => Chip(label: Text(name))).toList(),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: isDark ? Colors.white.withOpacity(0.035) : const Color(0xFFF8FAFF),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.06) : DetoxColors.lightCardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      zone.enabled ? Icons.location_searching_rounded : Icons.location_disabled_outlined,
                                      color: zone.enabled ? DetoxColors.accentSoft : muted,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        t.isEs ? 'Activar / desactivar' : 'Enable / disable',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Switch(
                                      value: zone.enabled,
                                      onChanged: (value) => _toggleZone(zone, value),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
  }
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({
    required this.apps,
    required this.existing,
  });

  final List<InstalledAppEntry> apps;
  final List<AppLimit> existing;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minutesController =
  TextEditingController(text: '30');

  InstalledAppEntry? _selected;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    final existingPackages =
    widget.existing.map((e) => e.packageName).toSet();

    final filtered = widget.apps
        .where((app) => !existingPackages.contains(app.packageName))
        .where(
          (app) =>
          app.name.toLowerCase().contains(_query.toLowerCase()),
    )
        .take(80)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: GlassCard(
        child: SizedBox(
          height: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.addAppLimit,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: t.searchApp,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.timer_outlined),
                  labelText: t.dailyScreenTimeLimit,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Text(
                    t.noAppsFound,
                    style: const TextStyle(
                      color: DetoxColors.muted,
                    ),
                  ),
                )
                    : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final selected =
                        _selected?.packageName == app.packageName;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: selected,
                      leading: AppIconBadge(
                        packageName: app.packageName,
                        iconBytes: app.iconBytes,
                        size: 42,
                        borderRadius: 12,
                      ),
                      title: Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        app.packageName,
                        style: const TextStyle(
                          color: DetoxColors.muted,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                        Icons.check_circle,
                        color: DetoxColors.accentSoft,
                      )
                          : null,
                      onTap: () => setState(() => _selected = app),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _selected == null
                    ? null
                    : () {
                  final minutes =
                      int.tryParse(_minutesController.text.trim()) ??
                          30;

                  Navigator.pop(
                    context,
                    AppLimit(
                      appName: _selected!.name,
                      packageName: _selected!.packageName,
                      minutes: minutes,
                    ),
                  );
                },
                child: Text(t.addSelectedApp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneEditorSheet extends StatefulWidget {
  const _ZoneEditorSheet({
    required this.appLimits,
    this.initialZone,
  });

  final List<AppLimit> appLimits;
  final ConcentrationZone? initialZone;

  @override
  State<_ZoneEditorSheet> createState() => _ZoneEditorSheetState();
}

class _ZoneEditorSheetState extends State<_ZoneEditorSheet> {
  late final TextEditingController _nameController;
  final MapController _mapController = MapController();

  late LatLng _center;
  late double _radius;
  bool _loading = true;
  final Set<String> _selectedPackages = <String>{};
  final Set<String> _selectedNames = <String>{};

  @override
  void initState() {
    super.initState();
    final initialZone = widget.initialZone;
    _nameController = TextEditingController(text: initialZone?.name ?? '');
    _center = initialZone != null
        ? LatLng(initialZone.latitude, initialZone.longitude)
        : const LatLng(21.8853, -102.2916);
    _radius = initialZone?.radiusMeters ?? 180;
    _selectedPackages.addAll(initialZone?.blockedPackages ?? const <String>[]);
    _selectedNames.addAll(initialZone?.blockedAppNames ?? const <String>[]);
    _syncSelectedNamesWithApps();
    _loadCurrentPosition();
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final permission =
      await LocationZoneService.instance.ensurePermissions();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (widget.initialZone == null) {
        final position = await Geolocator.getCurrentPosition();
        _center = LatLng(position.latitude, position.longitude);
        _mapController.move(_center, 15);
      } else {
        _mapController.move(_center, 15);
      }
    } catch (_) {
      // Keep default center.
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncSelectedNamesWithApps() {
    final packageToName = <String, String>{
      for (final app in widget.appLimits)
        if (app.packageName != null && app.packageName!.isNotEmpty)
          app.packageName!: app.appName,
    };

    final syncedNames = _selectedPackages
        .map((pkg) => packageToName[pkg])
        .whereType<String>()
        .toSet();

    if (syncedNames.isNotEmpty) {
      _selectedNames
        ..clear()
        ..addAll(syncedNames);
    }
  }

  void _toggleZoneApp(AppLimit app, bool selected) {
    final package = app.packageName;
    if (package == null || package.isEmpty) return;

    setState(() {
      if (selected) {
        _selectedPackages.add(package);
        _selectedNames.add(app.appName);
      } else {
        _selectedPackages.remove(package);
        _selectedNames.remove(app.appName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    final selectableApps = widget.appLimits
        .where((e) => e.packageName?.isNotEmpty ?? false)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: GlassCard(
        child: SizedBox(
          height: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialZone == null
                    ? t.newConcentrationZone
                    : (t.isEs ? 'Editar zona de concentración' : 'Edit concentration zone'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.label_outline),
                  labelText: t.zoneName,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.mapZoneHelp,
                style: const TextStyle(color: DetoxColors.muted),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: 15,
                            onPositionChanged: (position, _) {
                              setState(
                                    () => _center = position.center,
                              );
                            },
                            onTap: (_, point) {
                              _mapController.move(point, 15);
                              setState(() => _center = point);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.detox',
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _center,
                                  radius: _radius,
                                  useRadiusInMeter: true,
                                  color: DetoxColors.accent
                                      .withOpacity(0.18),
                                  borderColor:
                                  DetoxColors.accentSoft,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const IgnorePointer(
                          child: Center(
                            child: Icon(
                              Icons.location_on_rounded,
                              color: DetoxColors.accentSoft,
                              size: 42,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: FilledButton.icon(
                            onPressed: _loadCurrentPosition,
                            icon: const Icon(
                              Icons.my_location_rounded,
                            ),
                            label: Text(t.myLocation),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.44),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                t.centerText(
                                  _center.latitude.toStringAsFixed(5),
                                  _center.longitude.toStringAsFixed(5),
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                t.radiusText(_radius.round()),
                style: const TextStyle(color: DetoxColors.muted),
              ),
              Slider(
                min: 100,
                max: 1200,
                divisions: 22,
                value: _radius,
                onChanged: (value) => setState(() => _radius = value),
              ),
              const SizedBox(height: 4),
              Text(
                t.appsBlockedInThisZone,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (selectableApps.isEmpty)
                Text(
                  t.zoneAppsHelp,
                  style: const TextStyle(color: DetoxColors.muted),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectableApps.map((app) {
                    final selected =
                    _selectedPackages.contains(app.packageName);
                    return FilterChip(
                      label: Text(app.appName),
                      selected: selected,
                      onSelected: (value) =>
                          _toggleZoneApp(app, value),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim().isEmpty
                      ? t.studyZoneDefaultName
                      : _nameController.text.trim();

                  final initialZone = widget.initialZone;
                  final sortedPackages = _selectedPackages.toList()..sort();
                  final sortedNames = _selectedNames.toList()..sort();

                  Navigator.pop(
                    context,
                    ConcentrationZone(
                      id: initialZone?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name,
                      latitude: _center.latitude,
                      longitude: _center.longitude,
                      radiusMeters: _radius,
                      enabled: initialZone?.enabled ?? true,
                      blockedPackages: sortedPackages,
                      blockedAppNames: sortedNames,
                    ),
                  );
                },
                child: Text(t.saveZone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}