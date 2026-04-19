import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n_app_strings.dart';
import 'models/auth_user.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/permission_setup_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final darkMode = prefs.getBool('dark_mode') ?? true;
  final localeCode = prefs.getString('locale_code');
  final currentUser = await AuthService.instance.getCurrentUser();

  if (currentUser != null) {
    StorageService.bootstrapInProgress = true;
    await StorageService().bootstrapForSignedInUser();
    StorageService.bootstrapInProgress = false;
    await SponsorService.instance.ensureCurrentUserInitialized(currentUser);
    SponsorAlertService.instance.start();
    await AppBlockingService.instance.consumePendingNativeAction();
  }

  final onboardingDone = await StorageService().loadOnboardingDone();
  await FocusNotificationService.instance.initialize();

  runApp(
    DetoxApp(
      initialDarkMode: darkMode,
      onboardingDone: onboardingDone,
      initialUser: currentUser,
      initialLocaleCode: localeCode,
    ),
  );
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

  int _index = 0;
  late final PageController _pageController;
  late final List<Widget> _coreScreens;
  late bool _darkMode;
  late bool _onboardingDone;
  AuthUser? _currentUser;
  StreamSubscription<AuthUser?>? _authSubscription;
  Locale? _locale;
  bool _protectedServicesRunning = false;
  bool _sponsorCenterQueued = false;
  bool _openingSponsorCenter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _index);
    _coreScreens = const [
      RepaintBoundary(child: DashboardScreen(key: PageStorageKey('dashboard'))),
      RepaintBoundary(child: FocusScreen(key: PageStorageKey('focus'))),
      RepaintBoundary(child: HabitsScreen(key: PageStorageKey('habits'))),
      RepaintBoundary(child: StatsScreen(key: PageStorageKey('stats'))),
    ];
    _darkMode = widget.initialDarkMode;
    _onboardingDone = widget.onboardingDone;
    _currentUser = widget.initialUser;
    _locale = widget.initialLocaleCode == null
        ? null
        : Locale(widget.initialLocaleCode!);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _configureProtectedServices();
      if (_currentUser != null && _onboardingDone) {
        await _refreshProtectedState();
      }
      await _drainPendingLaunchActions();
    });

    _authSubscription = AuthService.instance.authChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        SponsorAlertService.instance.stop();
        await _stopProtectedServices();

        if (!mounted) return;
        setState(() {
          _currentUser = null;
          _index = 0;
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
    _authSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_drainPendingLaunchActions());
    }
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
    final shouldRun = _currentUser != null && _onboardingDone;
    if (shouldRun) {
      await _startProtectedServices();
    } else {
      await _stopProtectedServices();
    }
  }

  Future<void> _refreshProtectedState() async {
    try {
      await LocationZoneService.instance.refresh();
      await AutomationService.instance.refresh();
    } catch (_) {}
  }

  Future<void> _syncSignedInUser(AuthUser user) async {
    if (!StorageService.bootstrapInProgress) {
      await StorageService().bootstrapForSignedInUser();
    }

    await SponsorService.instance.ensureCurrentUserInitialized(user);
    SponsorAlertService.instance.start();
    await _consumePendingNotificationAction();
    await _consumePendingBlockAction();

    final onboardingDone = await StorageService().loadOnboardingDone();

    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _onboardingDone = onboardingDone;
    });

    await _configureProtectedServices();

    if (_currentUser != null && _onboardingDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _refreshProtectedState();
        _tryOpenQueuedSponsorCenter();
      });
    }
  }

  Future<void> _drainPendingLaunchActions() async {
    await _consumePendingNotificationAction();
    _tryOpenQueuedSponsorCenter();
  }

  Future<void> _consumePendingNotificationAction() async {
    final action = await FocusNotificationService.instance.consumePendingAction();
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
    final action = await AppBlockingService.instance.consumePendingNativeAction();
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

  Future<void> _setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale_code', code);
    if (!mounted) return;
    setState(() => _locale = Locale(code));
  }

  Future<void> _finishOnboarding() async {
    await StorageService().saveOnboardingDone(true);

    if (!mounted) return;
    setState(() {
      _onboardingDone = true;
    });

    await _configureProtectedServices();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshProtectedState();
      _tryOpenQueuedSponsorCenter();
    });
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
      _index = 0;
      _sponsorCenterQueued = false;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _deleteAccount() async {
    SponsorAlertService.instance.stop();
    await _stopProtectedServices();

    try {
      await AuthService.instance.deleteAccount();
    } catch (_) {
      await _configureProtectedServices();
      rethrow;
    }

    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _onboardingDone = false;
      _index = 0;
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
    } else if (!_onboardingDone) {
      home = PermissionSetupScreen(onFinished: _finishOnboarding);
    } else {
      home = Scaffold(
        body: DetoxBackground(
          child: SafeArea(
            child: PageView.builder(
              controller: _pageController,
              allowImplicitScrolling: true,
              itemCount: 5,
              onPageChanged: (value) {
                if (!mounted) return;
                setState(() => _index = value);
              },
              itemBuilder: (context, index) {
                if (index < _coreScreens.length) {
                  return _coreScreens[index];
                }

                return RepaintBoundary(
                  child: SettingsScreen(
                    key: const PageStorageKey('settings'),
                    darkMode: _darkMode,
                    onDarkModeChanged: _setDarkMode,
                    currentUser: _currentUser,
                    onSignOut: _signOut,
                    onDeleteAccount: _deleteAccount,
                    localeCode:
                        (_locale ?? WidgetsBinding.instance.platformDispatcher.locale)
                            .languageCode,
                    onLocaleChanged: _setLocale,
                  ),
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          child: NavigationBar(
            height: 74,
            selectedIndex: _index,
            onDestinationSelected: (value) {
              setState(() => _index = value);
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  value,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: t.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.timer_outlined),
                selectedIcon: const Icon(Icons.timer),
                label: t.focus,
              ),
              NavigationDestination(
                icon: const Icon(Icons.checklist_outlined),
                selectedIcon: const Icon(Icons.checklist),
                label: t.habits,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart),
                label: t.stats,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: t.settings,
              ),
            ],
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
