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
import 'services/auth_service.dart';
import 'services/focus_notification_service.dart';
import 'services/location_zone_service.dart';
import 'services/storage_service.dart';
import 'services/sponsor_alert_service.dart';
import 'services/sponsor_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final darkMode = prefs.getBool('dark_mode') ?? true;
  final localeCode = prefs.getString('locale_code') ?? 'en';
  final currentUser = await AuthService.instance.getCurrentUser();

  if (currentUser != null) {
    await StorageService().bootstrapForSignedInUser();
    await SponsorService.instance.ensureCurrentUserInitialized(currentUser);
    SponsorAlertService.instance.start();
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
  final String initialLocaleCode;

  @override
  State<DetoxApp> createState() => _DetoxAppState();
}

class _DetoxAppState extends State<DetoxApp> {
  int _index = 0;
  late bool _darkMode;
  late bool _onboardingDone;
  AuthUser? _currentUser;
  StreamSubscription<AuthUser?>? _authSubscription;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
    _onboardingDone = widget.onboardingDone;
    _currentUser = widget.initialUser;
    _locale = Locale(widget.initialLocaleCode);

    _authSubscription =
        AuthService.instance.authChanges().listen((user) async {
          if (!mounted) return;

          if (user == null) {
            SponsorAlertService.instance.stop();
            setState(() {
              _currentUser = null;
              _index = 0;
            });
            return;
          }

          await StorageService().bootstrapForSignedInUser();
          await SponsorService.instance.ensureCurrentUserInitialized(user);
          SponsorAlertService.instance.start();

          final onboardingDone = await StorageService().loadOnboardingDone();

          if (!mounted) return;

          setState(() {
            _currentUser = user;
            _onboardingDone = onboardingDone;
          });

          if (_onboardingDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await LocationZoneService.instance.refresh();
              } catch (_) {}
            });
          }
        });

    if (_currentUser != null && _onboardingDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await LocationZoneService.instance.refresh();
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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

  void _finishOnboarding() {
    setState(() => _onboardingDone = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocationZoneService.instance.refresh();
      } catch (_) {}
    });
  }

  Future<void> _handleAuthenticated(AuthUser user) async {
    await StorageService().bootstrapForSignedInUser();
    await SponsorService.instance.ensureCurrentUserInitialized(user);
    SponsorAlertService.instance.start();

    final onboardingDone = await StorageService().loadOnboardingDone();

    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _onboardingDone = onboardingDone;
    });

    if (_onboardingDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await LocationZoneService.instance.refresh();
        } catch (_) {}
      });
    }
  }

  Future<void> _signOut() async {
    SponsorAlertService.instance.stop();
    await AuthService.instance.signOut();
    setState(() {
      _currentUser = null;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings(_locale);

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
        localeCode: _locale.languageCode,
        onLocaleChanged: _setLocale,
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Detox',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: DetoxTheme.light,
      darkTheme: DetoxTheme.dark,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _currentUser == null
          ? AuthScreen(onAuthenticated: _handleAuthenticated)
          : !_onboardingDone
          ? PermissionSetupScreen(onFinished: _finishOnboarding)
          : Scaffold(
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
            onDestinationSelected: (value) =>
                setState(() => _index = value),
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
      ),
    );
  }
}