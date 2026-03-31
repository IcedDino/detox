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
import 'screens/stats_screen.dart';
import 'services/app_blocking_service.dart';
import 'services/automation_service.dart';
import 'services/auth_service.dart';
import 'services/focus_notification_service.dart';
import 'services/focus_session_service.dart';
import 'services/progress_service.dart';
import 'services/location_zone_service.dart';
import 'services/sponsor_alert_service.dart';
import 'services/sponsor_service.dart';
import 'services/storage_service.dart';
import 'services/usage_service.dart';
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
    final pendingNotificationAction = await FocusNotificationService.instance.consumePendingAction();
    if (pendingNotificationAction == FocusNotificationService.denySuggestionAction) {
      await ProgressService.instance.recordSuggestionDenied();
      await FocusNotificationService.instance.cancelSmartSuggestion();
    } else if (pendingNotificationAction == FocusNotificationService.startFocusAction) {
      await FocusSessionService.instance.startSession(
        minutes: 60,
        label: 'Focus session',
        reason: 'smart_suggestion_focus',
        fromSuggestion: true,
      );
      await FocusNotificationService.instance.cancelSmartSuggestion();
    }
  }

  await AutomationService.instance.start();

  final onboardingDone = await StorageService().loadOnboardingDone();

  await FocusNotificationService.instance.initialize();
  await FocusSessionService.instance.initialize();
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

class _DetoxAppState extends State<DetoxApp> {
  int _index = 0;
  late bool _darkMode;
  late bool _onboardingDone;
  AuthUser? _currentUser;
  StreamSubscription<AuthUser?>? _authSubscription;
  Locale? _locale;

  final UsageService _usageService = UsageService();
  bool _permissionsChecked = false;
  bool _permissionsReady = false;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
    _onboardingDone = widget.onboardingDone;
    _currentUser = widget.initialUser;
    _locale = widget.initialLocaleCode == null
        ? null
        : Locale(widget.initialLocaleCode!);

    _initializePermissionGate();

    _authSubscription = AuthService.instance.authChanges().listen((user) async {
      if (!mounted) return;

      if (user == null) {
        SponsorAlertService.instance.stop();
        setState(() {
          _currentUser = null;
          _index = 0;
          _permissionsChecked = false;
          _permissionsReady = false;
        });
        return;
      }

      await _syncSignedInUser(user);
    });
  }

  Future<void> _initializePermissionGate() async {
    if (_currentUser == null) {
      if (!mounted) return;
      setState(() {
        _permissionsChecked = false;
        _permissionsReady = false;
      });
      return;
    }

    final permissionsReady = await _hasRequiredPermissions();
    if (!mounted) return;

    setState(() {
      _permissionsChecked = true;
      _permissionsReady = permissionsReady;
    });

    if (permissionsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await LocationZoneService.instance.refresh();
          await AutomationService.instance.refresh();
        } catch (_) {}
      });
    }
  }

  Future<bool> _hasRequiredPermissions() async {
    final usageStatus = await _usageService.getPermissionStatus();
    final overlayReady = await AppBlockingService.instance.hasOverlayPermission();
    return usageStatus.usageReady && overlayReady;
  }

  Future<void> _syncSignedInUser(AuthUser user) async {
    if (!StorageService.bootstrapInProgress) {
      await StorageService().bootstrapForSignedInUser();
    }
    await SponsorService.instance.ensureCurrentUserInitialized(user);
    SponsorAlertService.instance.start();
    await _consumePendingBlockAction();
    await _consumePendingNotificationAction();

    final onboardingDone = await StorageService().loadOnboardingDone();
    final permissionsReady = await _hasRequiredPermissions();

    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _onboardingDone = onboardingDone;
      _permissionsChecked = true;
      _permissionsReady = permissionsReady;
    });

    if (_permissionsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await LocationZoneService.instance.refresh();
          await AutomationService.instance.refresh();
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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
    setState(() => _darkMode = value);
  }

  Future<void> _setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale_code', code);
    setState(() => _locale = Locale(code));
  }

  Future<void> _finishOnboarding() async {
    setState(() {
      _onboardingDone = true;
      _permissionsChecked = true;
      _permissionsReady = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocationZoneService.instance.refresh();
      } catch (_) {}
    });
  }

  Future<void> _handleAuthenticated(AuthUser user) async {
    await _syncSignedInUser(user);
  }


  Future<void> _consumePendingNotificationAction() async {
    final action = await FocusNotificationService.instance.consumePendingAction();
    if (action == null) return;

    if (action == FocusNotificationService.denySuggestionAction) {
      await ProgressService.instance.recordSuggestionDenied();
      await FocusNotificationService.instance.cancelSmartSuggestion();
      return;
    }

    if (action == FocusNotificationService.startFocusAction) {
      await FocusSessionService.instance.startSession(
        minutes: 60,
        label: AppStrings((_locale ?? WidgetsBinding.instance.platformDispatcher.locale)).focusSessionLabel,
        reason: 'smart_suggestion_focus',
        fromSuggestion: true,
      );
      await FocusNotificationService.instance.cancelSmartSuggestion();
    }
  }

  Future<void> _signOut() async {
    SponsorAlertService.instance.stop();
    await AuthService.instance.signOut();
    setState(() {
      _currentUser = null;
      _index = 0;
      _permissionsChecked = false;
      _permissionsReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLocale =
        _locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final t = AppStrings(resolvedLocale);

    final screens = [
      const DashboardScreen(),
      const FocusScreen(),
      const HabitsScreen(),
      const StatsScreen(),
      SettingsScreen(
        darkMode: _darkMode,
        onDarkModeChanged: _setDarkMode,
        currentUser: _currentUser,
        onSignOut: _signOut,
        localeCode:
        (_locale ?? WidgetsBinding.instance.platformDispatcher.locale)
            .languageCode,
        onLocaleChanged: _setLocale,
      ),
    ];

    Widget home;
    if (_currentUser == null) {
      home = AuthScreen(onAuthenticated: _handleAuthenticated);
    } else if (!_permissionsChecked) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (!_permissionsReady) {
      home = PermissionSetupScreen(onFinished: _finishOnboarding);
    } else {
      home = Scaffold(
        body: DetoxBackground(
          child: SafeArea(
            child: IndexedStack(
              index: _index,
              children: screens,
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
            onDestinationSelected: (value) => setState(() => _index = value),
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
