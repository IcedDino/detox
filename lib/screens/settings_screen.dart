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
import '../screens/sponsor_screen.dart';
import '../services/app_blocking_service.dart';
import '../services/app_catalog_service.dart';
import '../services/location_zone_service.dart';
import '../services/sponsor_service.dart';
import '../services/storage_service.dart';
import '../services/usage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';

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
    with WidgetsBindingObserver {
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
              'Removing apps or zones needs your sponsor to approve settings access.',
              style: TextStyle(color: DetoxColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'request'),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Request sponsor approval'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, 'open'),
              child: const Text('Open sponsor center'),
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
              content: Text('Settings approval request sent to your sponsor.'),
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

    if (zone != null) {
      final next = [..._zones, zone];
      setState(() => _zones = next);
      await _storageService.saveConcentrationZones(_zones);
      await LocationZoneService.instance.refresh();
    }
  }

  Future<void> _toggleZone(ConcentrationZone zone, bool value) async {
    if (zone.enabled &&
        !value &&
        !await _ensureProtectedSettingsAccess()) {
      return;
    }

    final next = _zones
        .map((e) => e.id == zone.id ? e.copyWith(enabled: value) : e)
        .toList();

    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(_zones);
    await LocationZoneService.instance.refresh();
  }

  Future<void> _removeZone(ConcentrationZone zone) async {
    if (!await _ensureProtectedSettingsAccess()) return;
    final next = _zones.where((e) => e.id != zone.id).toList();
    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(_zones);
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
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.currentUser != null) ...[
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(widget.currentUser!.displayName),
                  subtitle: Text(
                    '${widget.currentUser!.email} • ${widget.currentUser!.provider}',
                    style: const TextStyle(
                      color: DetoxColors.muted,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(t.signOut),
                  subtitle: Text(
                    t.returnLoginScreen,
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                  onTap: () async {
                    await widget.onSignOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.handshake_outlined,
                    color: DetoxColors.accentSoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.sponsorCenter,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _hasSponsor
                    ? t.linkedWith(
                  _sponsorProfile?.displayName ?? '',
                  _settingsUnlockActive,
                )
                    : '${t.yourCode}: ${_mySponsorCode.isEmpty ? t.loading : _mySponsorCode}',
                style: const TextStyle(color: DetoxColors.muted),
              ),
              if (_settingsUnlockActive &&
                  _settingsUnlockUntil != null) ...[
                const SizedBox(height: 6),
                Text(
                  t.settingsUnlockedUntil(
                    '${_settingsUnlockUntil!.hour.toString().padLeft(2, '0')}:${_settingsUnlockUntil!.minute.toString().padLeft(2, '0')}',
                  ),
                  style:
                  const TextStyle(color: Colors.greenAccent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t.settings,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                value: widget.darkMode,
                onChanged: widget.onDarkModeChanged,
                title: Text(t.darkMode),
                subtitle: Text(
                  t.darkModeSubtitle,
                  style: const TextStyle(color: DetoxColors.muted),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.language_rounded,
                  color: DetoxColors.accentSoft,
                ),
                title: Text(t.language),
                subtitle: Text(
                  widget.localeCode == 'es' ? 'Español' : 'English',
                  style: const TextStyle(color: DetoxColors.muted),
                ),
                trailing: DropdownButton<String>(
                  value: widget.localeCode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: 'es',
                      child: Text('Español'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) widget.onLocaleChanged(value);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(t.dailyScreenTimeLimit),
                subtitle: Text(
                  t.minutesLabel(_dailyLimit),
                  style: const TextStyle(color: DetoxColors.muted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Slider(
                  min: 30,
                  max: 480,
                  divisions: 15,
                  label: t.minutesLabel(_dailyLimit),
                  value: _dailyLimit.toDouble(),
                  onChanged: (value) =>
                      setState(() => _dailyLimit = value.round()),
                  onChangeEnd: (value) =>
                      _storageService.saveDailyLimitMinutes(
                        value.round(),
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: DetoxColors.accentSoft,
                ),
                title: Text(
                  defaultTargetPlatform == TargetPlatform.android
                      ? t.openAndroidUsageSettings
                      : t.permissionsOverview,
                ),
                subtitle: Text(
                  defaultTargetPlatform == TargetPlatform.android
                      ? t.grantUsageAndRefresh
                      : t.iosSeparatePath,
                  style: const TextStyle(color: DetoxColors.muted),
                ),
                onTap: defaultTargetPlatform == TargetPlatform.android
                    ? _openUsageSettings
                    : null,
              ),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    _overlayReady
                        ? Icons.shield_rounded
                        : Icons.warning_amber_rounded,
                    color: _overlayReady
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                  title: Text(t.focusShieldOverlay),
                  subtitle: Text(
                    _overlayReady
                        ? t.overlayReadyShield
                        : t.overlayGrantShield,
                    style: const TextStyle(color: DetoxColors.muted),
                  ),
                  onTap: _openOverlaySettings,
                ),
              ],
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
                  Text(
                    t.perAppLimits,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _addAppLimit,
                    icon: const Icon(
                      Icons.add,
                      color: DetoxColors.accentSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? t.pickAppsBody
                    : t.iosAppsBody,
                style: const TextStyle(color: DetoxColors.muted),
              ),
              const SizedBox(height: 10),
              if (_appLimits.isEmpty)
                Text(
                  t.noPerAppLimits,
                  style:
                  const TextStyle(color: DetoxColors.muted),
                )
              else
                ..._appLimits.map(
                      (item) => Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppIconBadge(
                          packageName: item.packageName,
                          size: 40,
                          borderRadius: 12,
                        ),
                        title: Text(
                          item.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          t.appLimitSubtitle(
                            item.minutes,
                            item.packageName ?? 'custom',
                          ),
                          style: const TextStyle(
                            color: DetoxColors.muted,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: () => _removeAppLimit(item),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: DetoxColors.muted,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: item.useInFocusMode,
                        onChanged: (value) =>
                            _toggleFocus(item, value),
                        title: Text(t.blockInFocusMode),
                        subtitle: Text(
                          t.focusModeBlockSubtitle,
                          style: const TextStyle(
                            color: DetoxColors.muted,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
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
                  Text(
                    t.concentrationZones,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _addZone,
                    icon: const Icon(
                      Icons.add_location_alt_outlined,
                      color: DetoxColors.accentSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _zoneState.message ?? t.zonesIntro,
                style: const TextStyle(color: DetoxColors.muted),
              ),
              const SizedBox(height: 10),
              if (_zones.isEmpty)
                Text(
                  t.noConcentrationZonesYet,
                  style:
                  const TextStyle(color: DetoxColors.muted),
                )
              else
                ..._zones.map(
                      (zone) => Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _zoneState.zoneName == zone.name &&
                              _zoneState.insideZone
                              ? Icons.school_rounded
                              : Icons.location_on_outlined,
                          color: _zoneState.zoneName == zone.name &&
                              _zoneState.insideZone
                              ? Colors.greenAccent
                              : DetoxColors.accentSoft,
                        ),
                        title: Text(zone.name),
                        subtitle: Text(
                          zone.blockedPackages.isEmpty
                              ? t.zoneRadiusUsesFocus(
                            zone.radiusMeters.round(),
                          )
                              : t.zoneRadiusSelectedApps(
                            zone.radiusMeters.round(),
                            zone.blockedPackages.length,
                          ),
                          style: const TextStyle(
                            color: DetoxColors.muted,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: () => _removeZone(zone),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: DetoxColors.muted,
                          ),
                        ),
                      ),
                      if (zone.blockedAppNames.isNotEmpty)
                        Padding(
                          padding:
                          const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: zone.blockedAppNames
                                  .map(
                                    (name) =>
                                    Chip(label: Text(name)),
                              )
                                  .toList(),
                            ),
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: zone.enabled,
                        onChanged: (value) =>
                            _toggleZone(zone, value),
                        title: Text(
                          t.isEs
                              ? 'Activar enfoque automático aquí'
                              : 'Enable automatic focus here',
                        ),
                        subtitle: Text(
                          t.isEs
                              ? 'Detox revisa tu ubicación y empieza a bloquear las apps seleccionadas en esta zona.'
                              : 'Detox checks your location and starts shielding the selected apps in this zone.',
                          style: const TextStyle(
                            color: DetoxColors.muted,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
            ],
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
  const _ZoneEditorSheet({required this.appLimits});

  final List<AppLimit> appLimits;

  @override
  State<_ZoneEditorSheet> createState() => _ZoneEditorSheetState();
}

class _ZoneEditorSheetState extends State<_ZoneEditorSheet> {
  late final TextEditingController _nameController;
  final MapController _mapController = MapController();

  LatLng _center = const LatLng(21.8853, -102.2916);
  double _radius = 180;
  bool _loading = true;
  final Set<String> _selectedPackages = <String>{};
  final Set<String> _selectedNames = <String>{};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Universidad');
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

      final position = await Geolocator.getCurrentPosition();
      _center = LatLng(position.latitude, position.longitude);
      _mapController.move(_center, 15);
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
                t.newConcentrationZone,
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

                  Navigator.pop(
                    context,
                    ConcentrationZone(
                      id: DateTime.now()
                          .microsecondsSinceEpoch
                          .toString(),
                      name: name,
                      latitude: _center.latitude,
                      longitude: _center.longitude,
                      radiusMeters: _radius,
                      blockedPackages:
                      _selectedPackages.toList()..sort(),
                      blockedAppNames: _selectedNames.toList()
                        ..sort(),
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