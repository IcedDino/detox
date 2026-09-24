import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:atlas_icons/atlas_icons.dart';

import '../l10n_app_strings.dart';
import '../models/app_limit.dart';
import '../models/auth_user.dart';
import '../models/concentration_zone.dart';
import '../models/installed_app_entry.dart';
import '../models/sponsor_profile.dart';
import '../screens/automation_settings_screen.dart';
import '../screens/sponsor_screen.dart';
import '../services/auth_service.dart';
import '../services/app_catalog_service.dart';
import '../services/focus_notification_service.dart';
import '../services/location_zone_service.dart';
import '../services/sponsor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/blocking_permission_gate.dart';
import '../widgets/ui_kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
    this.timeAtmosphereEnabled = false,
    this.onTimeAtmosphereChanged,
    required this.currentUser,
    required this.onSignOut,
    required this.localeCode,
    required this.onLocaleChanged,
    this.isCurrentPage = true,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final bool timeAtmosphereEnabled;
  final ValueChanged<bool>? onTimeAtmosphereChanged;
  final AuthUser? currentUser;
  final Future<void> Function() onSignOut;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;
  final bool isCurrentPage;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _AccountAction { signOut, delete }

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final StorageService _storageService = StorageService();
  final AppCatalogService _catalogService = AppCatalogService();

  bool _loading = true;
  final ValueNotifier<int> _dailyLimit = ValueNotifier(180);
  Future<void>? _loadFuture;
  bool _refreshOnVisible = false;
  List<AppLimit> _appLimits = const [];
  List<ConcentrationZone> _zones = const [];
  bool _hasSponsor = false;
  bool _settingsUnlockActive = false;
  String _mySponsorCode = '';
  SponsorProfile? _sponsorProfile;
  DateTime? _settingsUnlockUntil;
  ZoneState _zoneState = LocationZoneService.instance.currentState;
  StreamSubscription<ZoneState>? _zoneSubscription;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    unawaited(_catalogService
        .loadInstalledApps()
        .then<void>((_) {}, onError: (_) {}));
    _zoneSubscription = LocationZoneService.instance.states.listen((state) {
      if (!mounted) return;
      if (_zoneState.zoneName == state.zoneName &&
          _zoneState.insideZone == state.insideZone) {
        return;
      }
      if (widget.isCurrentPage) {
        setState(() => _zoneState = state);
      } else {
        _zoneState = state;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoneSubscription?.cancel();
    _dailyLimit.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.isCurrentPage) {
        _load();
      } else {
        _refreshOnVisible = true;
      }
    }
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && _refreshOnVisible) {
      _refreshOnVisible = false;
      _load();
    }
  }

  Future<void> _load() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadSettings();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait<dynamic>([
        _storageService.loadDailyLimitMinutes(),
        _storageService.loadAppLimits(),
        _storageService.loadConcentrationZones(),
      ]);

      if (widget.currentUser != null) {
        await SponsorService.instance.ensureCurrentUserInitialized();
      }
      final sponsorContext =
          await SponsorService.instance.loadCurrentUserContext();
      if (!mounted) return;
      _dailyLimit.value = results[0] as int;
      setState(() {
        _appLimits = results[1] as List<AppLimit>;
        _zones = results[2] as List<ConcentrationZone>;
        _hasSponsor = sponsorContext.hasSponsor;
        _sponsorProfile = sponsorContext.sponsorProfile;
        _settingsUnlockActive = sponsorContext.hasActiveSettingsUnlock;
        _settingsUnlockUntil = sponsorContext.settingsUnlockUntil;
        _mySponsorCode = sponsorContext.sponsorCode;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
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
    final created = await showModalBottomSheet<List<AppLimit>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AppPickerSheet(
        appsFuture: _catalogService.loadInstalledApps(),
        existing: _appLimits,
      ),
    );

    if (created != null && created.isNotEmpty && mounted) {
      final allowed = await ensureBlockingPermissions(context);
      if (!allowed || !mounted) return;
      await FocusNotificationService.instance.requestPermission();
      if (!mounted) return;
      final existingPackages = _appLimits.map((e) => e.packageName).toSet();
      final next = [
        ..._appLimits,
        ...created.where((app) => !existingPackages.contains(app.packageName)),
      ]..sort(
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
    if (value) {
      final allowed = await ensureBlockingPermissions(context);
      if (!allowed || !mounted) return;
      await FocusNotificationService.instance.requestPermission();
    }
    if (item.useInFocusMode &&
        !value &&
        !await _ensureProtectedSettingsAccess()) {
      return;
    }

    final next = _appLimits
        .map(
          (e) =>
              e.appName == item.appName ? e.copyWith(useInFocusMode: value) : e,
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

    final next = _zones.map((e) => e.id == zone.id ? updatedZone : e).toList();
    setState(() => _zones = next);
    await _storageService.saveConcentrationZones(next);
    await LocationZoneService.instance.refresh();
  }

  Future<void> _toggleZone(ConcentrationZone zone, bool value) async {
    if (zone.enabled != value && !await _ensureProtectedSettingsAccess()) {
      return;
    }
    if (value) {
      final permission = await LocationZoneService.instance.ensurePermissions();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).isEs
                  ? 'Activa la ubicación para usar zonas de concentración.'
                  : 'Enable location to use concentration zones.'),
            ),
          );
        }
        return;
      }
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

  Future<void> _openAccountActions() async {
    final t = AppStrings.of(context);
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.accountOptions,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: detoxWeightEmphasis,
                  ),
            ),
            const SizedBox(height: 14),
            SoftActionTile(
              icon: Icons.logout_rounded,
              title: t.signOut,
              subtitle: t.returnLoginScreen,
              color: DetoxColors.warning,
              onTap: () => Navigator.of(context).pop(_AccountAction.signOut),
            ),
            const SizedBox(height: 10),
            SoftActionTile(
              icon: Icons.delete_forever_rounded,
              title: t.deleteAccount,
              subtitle: t.deleteAccountWarning,
              color: DetoxColors.danger,
              onTap: () => Navigator.of(context).pop(_AccountAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == _AccountAction.signOut) {
      await widget.onSignOut();
      return;
    }

    await _confirmDeleteAccount();
  }

  Future<void> _confirmDeleteAccount() async {
    final t = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteAccountForever),
        content: Text(t.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: DetoxColors.danger,
            ),
            child: Text(t.deleteAccountConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await AuthService.instance.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.deleteAccountSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? DetoxColors.muted : DetoxColors.lightMuted;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final sections = <WidgetBuilder>[
      (context) => AppPageHeader(
            eyebrow: t.isEs ? 'Ajustes' : 'Settings',
            title: t.settings,
            subtitle: t.settingsPageSubtitle,
          ),
      (context) => const SizedBox(height: 18),
      if (widget.currentUser != null) ...[
        (context) => GestureDetector(
              onTap: _deletingAccount ? null : _openAccountActions,
              behavior: HitTestBehavior.opaque,
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(detoxRadius),
                        color: DetoxColors.accent
                            .withOpacity(isDark ? 0.18 : 0.10),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: DetoxColors.accentSoft,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                widget.currentUser!.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: detoxWeightEmphasis,
                                    ),
                              ),
                              StatusPill(
                                label: widget.currentUser!.provider,
                                icon: Icons.verified_user_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.currentUser!.email,
                            style: TextStyle(color: muted, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _deletingAccount
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                            ),
                          )
                        : Icon(
                            Icons.expand_more_rounded,
                            color: muted,
                          ),
                  ],
                ),
              ),
            ),
        (context) => const SizedBox(height: 16),
      ],
      (context) => HeroInfoCard(
            icon: Icons.handshake_outlined,
            title: t.sponsorCenter,
            subtitle: _hasSponsor
                ? (_sponsorProfile?.displayName ?? '')
                : '${t.yourCode}: ${_mySponsorCode.isEmpty ? t.loading : _mySponsorCode}',
            badge: StatusPill(
              label: _hasSponsor
                  ? (t.isEs ? 'Vínculo activo' : 'Linked')
                  : (t.isEs ? 'Sin padrino' : 'No sponsor'),
              icon: _hasSponsor
                  ? Icons.check_circle_rounded
                  : Icons.link_off_rounded,
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
                  title:
                      t.isEs ? 'Protección con padrino' : 'Sponsor protection',
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
      (context) => const SizedBox(height: 16),
      (context) => SectionTitle(
            title: t.isEs ? 'Preferencias generales' : 'General preferences',
            subtitle: t.isEs
                ? 'Aspecto, idioma y tiempo de pantalla diario.'
                : 'Appearance, language, and your daily screen-time target.',
          ),
      (context) => const SizedBox(height: 12),
      (context) => GlassCard(
            child: Column(
              children: [
                SoftActionTile(
                  icon: widget.darkMode ? Atlas.moon : Atlas.sunny,
                  title: t.darkMode,
                  subtitle: t.darkModeSubtitle,
                  trailing: Switch(
                    value: widget.darkMode,
                    onChanged: widget.onDarkModeChanged,
                  ),
                ),
                const SizedBox(height: 12),
                SoftActionTile(
                  icon: Atlas.sunrise,
                  title: t.isEs
                      ? 'Ambiente según la hora'
                      : 'Time of day atmosphere',
                  subtitle: t.isEs
                      ? 'Luz cálida al amanecer y estrellas de noche. Solo en modo oscuro.'
                      : 'Warm light at sunrise and stars at night. Dark mode only.',
                  trailing: Switch(
                    value: widget.timeAtmosphereEnabled && widget.darkMode,
                    onChanged:
                        widget.darkMode ? widget.onTimeAtmosphereChanged : null,
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
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: _dailyLimit,
                  builder: (context, dailyLimit, child) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(detoxRadius),
                      color: isDark
                          ? DetoxColors.cardSubtle
                          : DetoxColors.lightCardSubtle,
                      border: Border.all(
                        color: isDark
                            ? DetoxColors.cardBorder
                            : DetoxColors.lightCardBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.dailyScreenTimeLimit,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: detoxWeightEmphasis,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.minutesLabel(dailyLimit),
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          min: 30,
                          max: 480,
                          divisions: 15,
                          label: t.minutesLabel(dailyLimit),
                          value: dailyLimit.toDouble(),
                          onChanged: (value) =>
                              _dailyLimit.value = value.round(),
                          onChangeEnd: (value) =>
                              _storageService.saveDailyLimitMinutes(
                            value.round(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      (context) => const SizedBox(height: 16),
      (context) => SectionTitle(
            title: t.perAppLimits,
            subtitle: t.pickAppsBody,
            trailing: IconButton(
              onPressed: _addAppLimit,
              icon: const Icon(Icons.add),
            ),
          ),
      (context) => const SizedBox(height: 12),
      if (_appLimits.isEmpty)
        (context) => GlassCard(
              child: Text(
                t.noPerAppLimits,
                style: TextStyle(color: muted),
              ),
            )
      else
        ..._appLimits.map<WidgetBuilder>((item) => (context) => Padding(
              key: ValueKey('limit:${item.packageName ?? item.appName}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                  child: Row(
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
                      style: const TextStyle(
                        fontWeight: detoxWeightEmphasis,
                      ),
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
              )),
            )),
      (context) => const SizedBox(height: 16),
      (context) => SectionTitle(
            title: t.isEs ? 'Horarios de Detox' : 'Detox schedules',
            subtitle: t.isEs
                ? 'Programa bloqueos automáticos y presets de apps para ciertos momentos del día, incluso sin usar zonas.'
                : 'Schedule automatic blocking and app presets for certain moments of the day, even without using zones.',
          ),
      (context) => const SizedBox(height: 12),
      (context) => GlassCard(
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
      (context) => const SizedBox(height: 16),
      (context) => SectionTitle(
            title: t.concentrationZones,
            subtitle: t.isEs
                ? 'Espacios donde el enfoque se puede activar solo.'
                : 'Places where focus can activate automatically.',
            trailing: IconButton(
              onPressed: _addZone,
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ),
      (context) => const SizedBox(height: 12),
      if (_zones.isEmpty)
        (context) => GlassCard(
              child: Text(
                t.noConcentrationZonesYet,
                style: TextStyle(color: muted),
              ),
            )
      else
        ..._zones.map<WidgetBuilder>((zone) => (context) {
              final inside =
                  _zoneState.zoneName == zone.name && _zoneState.insideZone;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(detoxRadius),
                    color: isDark
                        ? DetoxColors.cardSubtle
                        : DetoxColors.lightCardSubtle,
                    border: Border.all(
                      color: isDark
                          ? DetoxColors.cardBorder
                          : DetoxColors.lightCardBorder,
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
                              borderRadius: BorderRadius.circular(detoxRadius),
                              color: (inside
                                      ? DetoxColors.success
                                      : DetoxColors.accentSoft)
                                  .withOpacity(0.14),
                            ),
                            child: Icon(
                              inside
                                  ? Icons.school_rounded
                                  : Icons.location_on_outlined,
                              color: inside
                                  ? DetoxColors.success
                                  : DetoxColors.accentSoft,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  zone.name,
                                  style: const TextStyle(
                                    fontWeight: detoxWeightEmphasis,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  zone.blockedPackages.isEmpty
                                      ? t.zoneRadiusUsesFocus(
                                          zone.radiusMeters.round(),
                                        )
                                      : t.zoneRadiusSelectedApps(
                                          zone.radiusMeters.round(),
                                          zone.blockedPackages.length,
                                        ),
                                  style: TextStyle(
                                    color: muted,
                                    height: 1.3,
                                  ),
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
                          children: zone.blockedAppNames
                              .map((name) => Chip(label: Text(name)))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(detoxRadius),
                          color: isDark
                              ? DetoxColors.cardSubtle
                              : DetoxColors.lightCardSubtle,
                          border: Border.all(
                            color: isDark
                                ? DetoxColors.cardBorder
                                : DetoxColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              zone.enabled
                                  ? Icons.location_searching_rounded
                                  : Icons.location_disabled_outlined,
                              color:
                                  zone.enabled ? DetoxColors.accentSoft : muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t.isEs
                                    ? 'Activar / desactivar'
                                    : 'Enable / disable',
                                style: const TextStyle(
                                  fontWeight: detoxWeightEmphasis,
                                ),
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
            }),
    ];
    return ListView.builder(
      key: const PageStorageKey('settings-list'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      itemCount: sections.length,
      itemBuilder: (context, index) => sections[index](context),
    );
  }
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({
    required this.appsFuture,
    required this.existing,
  });

  final Future<List<InstalledAppEntry>> appsFuture;
  final List<AppLimit> existing;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  static const Set<String> _socialPackageHints = {
    'instagram',
    'facebook',
    'whatsapp',
    'telegram',
    'discord',
    'snapchat',
    'twitter',
    'reddit',
    'messenger',
    'tiktok',
    'musically',
    'pinterest',
    'threads',
    'tumblr',
    'bereal',
    'wechat',
    'line',
    'signal',
    'linkedin',
  };

  static const Set<String> _socialNameHints = {
    'instagram',
    'facebook',
    'whatsapp',
    'telegram',
    'discord',
    'snapchat',
    'twitter',
    'reddit',
    'messenger',
    'tik tok',
    'tiktok',
    'pinterest',
    'threads',
    'tumblr',
    'bereal',
    'wechat',
    'line',
    'signal',
    'linkedin',
  };

  static const Set<String> _gamePackageHints = {
    'roblox',
    'minecraft',
    'supercell',
    'epicgames',
    'riotgames',
    'garena',
    'activision',
    'ea.gp',
    'mojang',
    'niantic',
    'king',
    'brawlstars',
    'clashroyale',
    'clashofclans',
    'freefire',
    'pubg',
    'callofduty',
    'stumble',
    'subwaysurf',
    'amongus',
    'pokemon',
  };

  static const Set<String> _gameNameHints = {
    'game',
    'juego',
    'roblox',
    'minecraft',
    'fortnite',
    'free fire',
    'pubg',
    'call of duty',
    'brawl stars',
    'clash royale',
    'clash of clans',
    'stumble guys',
    'subway surfers',
    'among us',
    'pokemon',
    'candy crush',
    'fifa',
    'mlbb',
    'mobile legends',
  };

  final TextEditingController _searchController = TextEditingController();

  final Map<String, InstalledAppEntry> _selected = {};
  List<InstalledAppEntry> _apps = const [];
  bool _loadingApps = true;
  bool _loadFailed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadApps(widget.appsFuture);
  }

  Future<void> _loadApps(Future<List<InstalledAppEntry>> future) async {
    try {
      final apps = await future;
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loadingApps = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingApps = false;
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesHints(String value, Set<String> hints) {
    return hints.any(value.contains);
  }

  bool _matchesExactName(String value, Set<String> names) {
    return names.contains(value.trim());
  }

  bool _isSocialApp(InstalledAppEntry app) {
    final package = app.packageName.toLowerCase();
    final name = app.name.toLowerCase();
    return _matchesHints(package, _socialPackageHints) ||
        _matchesHints(name, _socialNameHints) ||
        _matchesExactName(name, const {'x'});
  }

  bool _isGameApp(InstalledAppEntry app) {
    final package = app.packageName.toLowerCase();
    final name = app.name.toLowerCase();
    return _matchesHints(package, _gamePackageHints) ||
        _matchesHints(name, _gameNameHints);
  }

  int _priorityForApp(InstalledAppEntry app) {
    if (_isSocialApp(app)) return 0;
    if (_isGameApp(app)) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final existingPackages = widget.existing.map((e) => e.packageName).toSet();
    final query = _query.trim().toLowerCase();

    final filtered = _apps
        .where((app) => !existingPackages.contains(app.packageName))
        .where((app) {
      if (query.isEmpty) return true;
      return app.name.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        final priorityCompare =
            _priorityForApp(a).compareTo(_priorityForApp(b));
        if (priorityCompare != 0) return priorityCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final visibleApps = filtered;

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
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
              const SizedBox(height: 14),
              Text(
                t.selectedAppsCount(_selected.length),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: DetoxColors.muted),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loadingApps
                    ? const Center(child: CircularProgressIndicator())
                    : _loadFailed
                        ? Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _loadingApps = true;
                                  _loadFailed = false;
                                });
                                _loadApps(
                                    AppCatalogService().loadInstalledApps());
                              },
                              child: Text(t.retryLoadingApps),
                            ),
                          )
                        : visibleApps.isEmpty
                            ? Center(
                                child: Text(
                                  t.noAppsFound,
                                  style:
                                      const TextStyle(color: DetoxColors.muted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: visibleApps.length,
                                separatorBuilder: (context, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final app = visibleApps[index];
                                  final selected =
                                      _selected.containsKey(app.packageName);

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(detoxRadius),
                                      onTap: () => setState(() {
                                        if (selected) {
                                          _selected.remove(app.packageName);
                                        } else {
                                          _selected[app.packageName] = app;
                                        }
                                      }),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                              detoxRadius),
                                          color: selected
                                              ? DetoxColors.accent
                                                  .withOpacity(0.16)
                                              : (isDark
                                                  ? DetoxColors.cardSubtle
                                                  : DetoxColors
                                                      .lightCardSubtle),
                                          border: Border.all(
                                            color: selected
                                                ? DetoxColors.accentSoft
                                                    .withOpacity(0.45)
                                                : (isDark
                                                    ? DetoxColors.cardBorder
                                                    : DetoxColors
                                                        .lightCardBorder),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            AppIconBadge(
                                              packageName: app.packageName,
                                              iconBytes: app.iconBytes,
                                              size: 42,
                                              borderRadius: 12,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                app.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight:
                                                      detoxWeightEmphasis,
                                                ),
                                              ),
                                            ),
                                            if (selected)
                                              const Icon(
                                                Icons.check_circle,
                                                color: DetoxColors.accentSoft,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        const minutes = 30;

                        Navigator.pop(
                          context,
                          _selected.values
                              .map((app) => AppLimit(
                                    appName: app.name,
                                    packageName: app.packageName,
                                    minutes: minutes,
                                  ))
                              .toList(),
                        );
                      },
                child: Text(t.addSelectedApps(_selected.length)),
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
      final permission = await LocationZoneService.instance.ensurePermissions();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (widget.initialZone == null) {
        final position = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 8),
        );
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
                    : (t.isEs
                        ? 'Editar zona de concentración'
                        : 'Edit concentration zone'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                    borderRadius: BorderRadius.circular(detoxRadius),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: 15,
                            onPositionChanged: (position, _) {
                              setState(() => _center = position.center);
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
                                  color: DetoxColors.accent.withOpacity(0.18),
                                  borderColor: DetoxColors.accentSoft,
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
                            icon: const Icon(Icons.my_location_rounded),
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
                              borderRadius: BorderRadius.circular(detoxRadius),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                      onSelected: (value) => _toggleZoneApp(app, value),
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
