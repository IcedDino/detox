import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas_icons/atlas_icons.dart';

import 'firebase_options.dart';
import 'l10n_app_strings.dart';
import 'models/auth_user.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/usage_access_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sponsor_screen.dart';
import 'screens/stats_screen.dart';
import 'services/app_blocking_service.dart';
import 'services/anti_bypass_service.dart';
import 'services/automation_service.dart';
import 'services/auth_service.dart';
import 'services/focus_notification_service.dart';
import 'services/focus_session_service.dart';
import 'services/location_zone_service.dart';
import 'services/sponsor_alert_service.dart';
import 'services/sponsor_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DetoxBootstrapApp());
}

class _BootstrapState {
  const _BootstrapState({
    required this.darkMode,
    required this.onboardingDone,
    required this.currentUser,
    required this.localeCode,
  });

  final bool darkMode;
  final bool onboardingDone;
  final AuthUser? currentUser;
  final String? localeCode;
}

class DetoxBootstrapApp extends StatefulWidget {
  const DetoxBootstrapApp({super.key});

  @override
  State<DetoxBootstrapApp> createState() => _DetoxBootstrapAppState();
}

class _DetoxBootstrapAppState extends State<DetoxBootstrapApp> {
  late final Future<_BootstrapState> _bootstrapFuture = _bootstrap();

  Future<_BootstrapState> _bootstrap() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode') ?? true;
    final localeCode = prefs.getString('locale_code');

    // Services and notifications have no BuildContext, so record the active
    // language here before anything else renders user-facing text. The device
    // fallback mirrors MaterialApp's own resolution over supportedLocales.
    final deviceLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final resolvedLanguage =
        const ['en', 'es'].contains(deviceLanguage) ? deviceLanguage : 'es';
    AppLocale.set(
      Locale(
        localeCode != null && localeCode.isNotEmpty
            ? localeCode
            : resolvedLanguage,
      ),
    );

    final onboardingDone = await StorageService().loadOnboardingDone();
    final currentUser = await AuthService.instance.getCurrentUser();

    return _BootstrapState(
      darkMode: darkMode,
      onboardingDone: onboardingDone,
      currentUser: currentUser,
      localeCode: localeCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapState>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: DetoxTheme.light,
            darkTheme: DetoxTheme.dark,
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              body: DetoxBackground(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return DetoxApp(
          initialDarkMode: data.darkMode,
          onboardingDone: data.onboardingDone,
          initialUser: data.currentUser,
          initialLocaleCode: data.localeCode,
        );
      },
    );
  }
}

class DetoxApp extends StatefulWidget {
  const DetoxApp({
    super.key,
    required this.initialDarkMode,
    required this.onboardingDone,
    required this.initialUser,
    required this.initialLocaleCode,
  });

  final bool initialDarkMode;
  final bool onboardingDone;
  final AuthUser? initialUser;
  final String? initialLocaleCode;

  @override
  State<DetoxApp> createState() => _DetoxAppState();
}

class _DetoxAppState extends State<DetoxApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  final ValueNotifier<int> _index = ValueNotifier<int>(0);
  late final PageController _pageController;
  late bool _darkMode;
  bool _timeAtmosphereEnabled = false;
  Timer? _timeRefreshTimer;
  late bool _onboardingDone;
  AuthUser? _currentUser;
  StreamSubscription<AuthUser?>? _authSubscription;
  String? _syncingUserUid;
  Future<void>? _syncingUserFuture;
  Locale? _locale;
  bool _protectedServicesRunning = false;
  bool _sponsorCenterQueued = false;
  bool _openingSponsorCenter = false;
  bool _usageAccessReady = false;
  bool _tutorialPromptOpen = false;

  /// Jump to the Focus tab (index 1) from anywhere in the app.
  void goToFocus() {
    _index.value = 1;
    _selectPage(1);
  }

  void _selectPage(int index) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _index.value);
    _darkMode = widget.initialDarkMode;
    _onboardingDone = widget.onboardingDone;
    _currentUser = widget.initialUser;
    _locale = widget.initialLocaleCode == null
        ? null
        : Locale(widget.initialLocaleCode!);
    SharedPreferences.getInstance().then((prefs) {
      if (mounted)
        setState(() => _timeAtmosphereEnabled =
            prefs.getBool('time_atmosphere_enabled') ?? false);
    });
    _timeRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _darkMode && _timeAtmosphereEnabled) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _configureProtectedServices();
      await _runDeferredStartup();
    });

    _authSubscription = AuthService.instance.authChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        SponsorAlertService.instance.stop();
        await _stopProtectedServices();

        if (!mounted) return;
        setState(() {
          _currentUser = null;
          _usageAccessReady = false;
          _index.value = 0;
          _sponsorCenterQueued = false;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        return;
      }

      await _syncSignedInUser(user);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeRefreshTimer?.cancel();
    _authSubscription?.cancel();
    _index.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifyUsageAccess());
      unawaited(_drainPendingLaunchActions());
      if (_protectedServicesRunning) {
        unawaited(AutomationService.instance.refresh());
      }
    }
  }

  Future<void> _verifyUsageAccess() async {
    if (_currentUser == null || !_usageAccessReady) return;
    if (await AppBlockingService.instance.hasUsageAccess()) return;
    if (!mounted) return;
    setState(() => _usageAccessReady = false);
    await _configureProtectedServices();
  }

  Future<void> _startProtectedServices() async {
    if (_protectedServicesRunning) return;
    await AutomationService.instance.start();
    await AntiBypassService.instance.start();
    _protectedServicesRunning = true;
  }

  Future<void> _stopProtectedServices() async {
    if (!_protectedServicesRunning) return;
    AutomationService.instance.stop();
    AntiBypassService.instance.stop();
    _protectedServicesRunning = false;
  }

  Future<void> _configureProtectedServices() async {
    final shouldRun =
        _currentUser != null && _onboardingDone && _usageAccessReady;
    if (shouldRun) {
      await _startProtectedServices();
    } else {
      await _stopProtectedServices();
    }
  }

  Future<void> _refreshProtectedState() async {
    try {
      await LocationZoneService.instance.refresh();
    } catch (_) {}
  }

  Future<void> _runDeferredStartup() async {
    await FocusNotificationService.instance.initialize();

    if (_currentUser != null) {
      await StorageService().bootstrapForSignedInUser();
      await SponsorService.instance.ensureCurrentUserInitialized(_currentUser);
      SponsorAlertService.instance.start();
      await _consumePendingBlockAction();
    }

    await _drainPendingLaunchActions();
  }

  Future<void> _syncSignedInUser(AuthUser user) async {
    final activeSync = _syncingUserFuture;
    if (_syncingUserUid == user.uid && activeSync != null) {
      await activeSync;
      return;
    }

    final future = _syncSignedInUserInternal(user);
    _syncingUserUid = user.uid;
    _syncingUserFuture = future;
    try {
      await future;
    } finally {
      if (identical(_syncingUserFuture, future)) {
        _syncingUserFuture = null;
        _syncingUserUid = null;
      }
    }
  }

  Future<void> _syncSignedInUserInternal(AuthUser user) async {
    await StorageService().bootstrapForSignedInUser();

    await SponsorService.instance.ensureCurrentUserInitialized(user);
    SponsorAlertService.instance.start();
    await _consumePendingNotificationAction();
    await _consumePendingBlockAction();

    var onboardingDone = await StorageService().loadOnboardingDone();
    if (!onboardingDone) {
      onboardingDone = true;
      await StorageService().saveOnboardingDone(true);
    }

    if (!mounted) return;
    setState(() {
      if (_currentUser?.uid != user.uid) {
        _usageAccessReady = false;
      }
      _currentUser = user;
      _onboardingDone = onboardingDone;
    });

    await _configureProtectedServices();
  }

  Future<void> _onUsageAccessGranted() async {
    if (!mounted || _usageAccessReady) return;
    setState(() => _usageAccessReady = true);
    await FocusSessionService.instance.restoreActiveShield();
    await _refreshProtectedState();
    await _configureProtectedServices();
    _tryOpenQueuedSponsorCenter();
  }

  Future<void> _drainPendingLaunchActions() async {
    await _consumePendingNotificationAction();
    _tryOpenQueuedSponsorCenter();
  }

  Future<void> _consumePendingNotificationAction() async {
    final action =
        await FocusNotificationService.instance.consumePendingAction();
    if (action == null) return;

    if (action == 'start_focus_hour') {
      await StorageService().incrementSuggestionsAccepted();
      await StorageService().markProgressStartedToday();
      await FocusSessionService.instance.startQuickFocusHour();
      return;
    }

    if (action == 'deny_focus_hour') {
      await StorageService().incrementSuggestionsDenied();
      return;
    }

    if (action == FocusNotificationService.actionOpenSponsorCenter) {
      _sponsorCenterQueued = true;
    }
  }

  void _tryOpenQueuedSponsorCenter() {
    if (!_sponsorCenterQueued || _openingSponsorCenter || !mounted) {
      return;
    }
    if (_currentUser == null || !_onboardingDone) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryOpenQueuedSponsorCenter();
      });
      return;
    }

    _sponsorCenterQueued = false;
    _openingSponsorCenter = true;

    navigator
        .push(MaterialPageRoute(builder: (_) => const SponsorScreen()))
        .whenComplete(() {
      _openingSponsorCenter = false;
    });
  }

  Future<void> _consumePendingBlockAction() async {
    final action =
        await AppBlockingService.instance.consumePendingNativeAction();
    if (action == null) return;

    if (action == NativeBlockAction.requestShieldPause) {
      try {
        await SponsorService.instance.createUnlockRequest(
          requestType: 'shield_pause',
          durationMinutes: 15,
        );
      } catch (_) {}
      return;
    }

    if (action == NativeBlockAction.suspendShield15) {
      await AppBlockingService.instance.suspendForMinutes(15);
    }
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    if (!mounted) return;
    setState(() => _darkMode = value);
  }

  Future<void> _setTimeAtmosphere(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('time_atmosphere_enabled', value);
    if (mounted) setState(() => _timeAtmosphereEnabled = value);
  }

  Future<void> _setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale_code', code);
    AppLocale.setLanguageCode(code);
    if (!mounted) return;
    setState(() => _locale = Locale(code));
  }

  Future<void> _maybeOfferTutorial() async {
    if (_tutorialPromptOpen || !mounted || _currentUser == null) return;
    _tutorialPromptOpen = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('main_tutorial_seen_v1') ?? false) {
      _tutorialPromptOpen = false;
      return;
    }
    if (!mounted) return;
    final strings = AppStrings.of(context);
    final start = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(strings.isEs
            ? '¿Quieres un recorrido rápido?'
            : 'Would you like a quick tour?'),
        content: Text(strings.isEs
            ? 'Te mostraremos las opciones principales de Detox. Puedes omitirlo ahora.'
            : 'We’ll show you the main Detox features. You can skip it now.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.isEs ? 'Omitir' : 'Skip tutorial')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.isEs ? 'Sí, empezar' : 'Yes, start')),
        ],
      ),
    );
    if (start == true && mounted) await _showTutorialSlides(strings);
    await prefs.setBool('main_tutorial_seen_v1', true);
    _tutorialPromptOpen = false;
  }

  Future<void> _showTutorialSlides(AppStrings strings) async {
    var step = 0;
    final titles = strings.isEs
        ? ['Hoy', 'Enfoque', 'Estadísticas y ajustes']
        : ['Today', 'Focus', 'Stats and settings'];
    final descriptions = strings.isEs
        ? [
            'Revisa tu uso diario y encuentra accesos para terminar de configurar Detox.',
            'Inicia sesiones de enfoque para mantener la atención en lo que importa.',
            'Consulta tu progreso y configura restricciones, zonas, horarios y apariencia.'
          ]
        : [
            'Review your daily usage and find shortcuts to finish setting up Detox.',
            'Start focus sessions to stay with what matters.',
            'Track your progress and configure restrictions, zones, schedules, and appearance.'
          ];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                icon: Icon([Atlas.statistics, Atlas.timer, Atlas.gear][step],
                    size: 34, color: DetoxColors.accent),
                title: Text(titles[step]),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(descriptions[step], textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        3,
                        (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == step ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: i == step
                                    ? DetoxColors.accent
                                    : DetoxColors.muted.withOpacity(.5),
                                borderRadius: BorderRadius.circular(8)))),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(strings.isEs ? 'Salir' : 'Close')),
                  FilledButton(
                      onPressed: () {
                        if (step == 2) {
                          Navigator.pop(context);
                        } else {
                          setDialogState(() => step++);
                        }
                      },
                      child: Text(step == 2
                          ? (strings.isEs ? 'Listo' : 'Done')
                          : (strings.isEs ? 'Siguiente' : 'Next'))),
                ],
              )),
    );
  }

  Future<void> _handleAuthenticated(AuthUser user) async {
    await _syncSignedInUser(user);
  }

  Future<void> _signOut() async {
    SponsorAlertService.instance.stop();
    await _stopProtectedServices();
    await AuthService.instance.signOut();

    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _usageAccessReady = false;
      _index.value = 0;
      _sponsorCenterQueued = false;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLocale =
        _locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final t = AppStrings(resolvedLocale);

    Widget home;
    if (_currentUser == null) {
      home = AuthScreen(onAuthenticated: _handleAuthenticated);
    } else if (!_usageAccessReady &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      home = UsageAccessScreen(onGranted: _onUsageAccessGranted);
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeOfferTutorial());
      home = Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            DetoxBackground(child: const SizedBox.expand()),
            if (_darkMode && _timeAtmosphereEnabled)
              _TimeAtmosphere(now: DateTime.now()),
            SafeArea(
              child: PageView.builder(
                controller: _pageController,
                allowImplicitScrolling: false,
                physics:
                    const BouncingScrollPhysics(parent: PageScrollPhysics()),
                itemCount: 4,
                onPageChanged: (value) {
                  _index.value = value;
                },
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ValueListenableBuilder<int>(
                      valueListenable: _index,
                      builder: (context, selectedIndex, child) =>
                          DashboardScreen(
                        key: const PageStorageKey('dashboard'),
                        onStartFocus: goToFocus,
                        onOpenSettings: () {
                          _index.value = 3;
                          _selectPage(3);
                        },
                        isCurrentPage: selectedIndex == 0,
                      ),
                    );
                  }
                  if (index == 1) {
                    return ValueListenableBuilder<int>(
                      valueListenable: _index,
                      builder: (context, selectedIndex, child) => FocusScreen(
                        key: const PageStorageKey('focus'),
                        isCurrentPage: selectedIndex == 1,
                      ),
                    );
                  }
                  if (index == 2) {
                    return ValueListenableBuilder<int>(
                      valueListenable: _index,
                      builder: (context, selectedIndex, child) => StatsScreen(
                        key: const PageStorageKey('stats'),
                        isCurrentPage: selectedIndex == 2,
                      ),
                    );
                  }

                  return ValueListenableBuilder<int>(
                    valueListenable: _index,
                    builder: (context, selectedIndex, child) => SettingsScreen(
                      key: const PageStorageKey('settings'),
                      isCurrentPage: selectedIndex == 3,
                      darkMode: _darkMode,
                      onDarkModeChanged: _setDarkMode,
                      timeAtmosphereEnabled: _timeAtmosphereEnabled,
                      onTimeAtmosphereChanged: _setTimeAtmosphere,
                      currentUser: _currentUser,
                      onSignOut: _signOut,
                      localeCode: (_locale ??
                              WidgetsBinding.instance.platformDispatcher.locale)
                          .languageCode,
                      onLocaleChanged: _setLocale,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(detoxRadius),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: _index,
            builder: (context, selectedIndex, child) => NavigationBar(
              height: 74,
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                _index.value = value;
                _selectPage(value);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Atlas.home_thin),
                  selectedIcon: const Icon(Atlas.home),
                  label: t.home,
                ),
                NavigationDestination(
                  icon: const Icon(Atlas.timer_thin),
                  selectedIcon: const Icon(Atlas.timer),
                  label: t.focus,
                ),
                NavigationDestination(
                  icon: const Icon(Atlas.statistics_thin),
                  selectedIcon: const Icon(Atlas.statistics),
                  label: t.stats,
                ),
                NavigationDestination(
                  icon: const Icon(Atlas.gear_thin),
                  selectedIcon: const Icon(Atlas.gear),
                  label: t.settings,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Detox',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: DetoxTheme.light,
      darkTheme: DetoxTheme.dark,
      locale: _locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

class _TimeAtmosphere extends StatelessWidget {
  const _TimeAtmosphere({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hour = now.hour + now.minute / 60;
    final sunrise = hour >= 5 && hour < 8;
    final morning = hour >= 8 && hour < 17;
    final sunset = hour >= 17 && hour < 20;
    final night = !sunrise && !morning && !sunset && (hour >= 20 || hour < 5);
    final tint = sunrise
        ? const Color(0xFFFFA66B)
        : morning
            ? const Color(0xFFFFD27A)
            : sunset
                ? const Color(0xFFFF795D)
                : const Color(0xFF263F82);
    final opacity = sunrise || sunset
        ? .18
        : morning
            ? .11
            : .14;
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tint.withOpacity(opacity),
                Colors.transparent,
                tint.withOpacity(opacity * .35)
              ],
              stops: const [0, .48, 1],
            ),
          ),
        ),
        if (night)
          Positioned(
            top: 44,
            right: 32,
            child: Opacity(
              opacity: .27,
              child: Icon(Atlas.moon, size: 42, color: const Color(0xFFE2E7FF)),
            ),
          ),
        if (night)
          const Positioned.fill(child: CustomPaint(painter: _StarPainter())),
      ]),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x99E7ECFF);
    const points = [
      Offset(.12, .15),
      Offset(.30, .08),
      Offset(.52, .19),
      Offset(.76, .12),
      Offset(.90, .31),
      Offset(.20, .42),
      Offset(.67, .38),
      Offset(.42, .62)
    ];
    for (final point in points) {
      canvas.drawCircle(
          Offset(size.width * point.dx, size.height * point.dy), 1.3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}
