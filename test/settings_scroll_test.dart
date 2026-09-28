import 'package:detox/models/app_limit.dart';
import 'package:detox/models/auth_user.dart';
import 'package:detox/services/app_catalog_service.dart';
import 'package:detox/screens/settings_screen.dart';
import 'package:detox/widgets/app_icon_badge.dart';
import 'package:firebase_core/firebase_core.dart';
// FlutterFire provides its platform mocks separately from the app packages.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    Object? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuth();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  testWidgets('Settings mounts visible app rows and keeps scroll across tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'app_limits_v2': List.generate(
        80,
        (index) => AppLimit(
          appName: 'Test app $index',
          packageName: 'example.app$index',
          minutes: 30,
        ).toJson(),
      ),
    });
    final controller = PageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageView.builder(
            controller: controller,
            itemCount: 2,
            itemBuilder: (context, index) => index == 1
                ? const Center(child: Text('Other tab'))
                : SettingsScreen(
                    darkMode: false,
                    onDarkModeChanged: (_) {},
                    currentUser: null,
                    onSignOut: () async {},
                    localeCode: 'es',
                    onLocaleChanged: (_) {},
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final savedApps =
        (await SharedPreferences.getInstance()).getStringList(
          'app_limits_v2',
        ) ??
        const <String>[];
    expect(
      savedApps.map(AppLimit.fromJson).every((app) => app.minutes == 0),
      isTrue,
    );
    expect(find.text('Test app 79'), findsNothing);
    expect(find.byType(AppIconBadge).evaluate().length, lessThan(12));

    final list = find.byKey(const PageStorageKey('settings-list'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Test app 45'),
      600,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppIconBadge).evaluate().length, lessThan(20));
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;

    controller.jumpToPage(1);
    await tester.pumpAndSettle();
    controller.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
    expect(find.text('Test app 45'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Adding apps does not assign a per-app time limit', (
    tester,
  ) async {
    AppCatalogService.clearCache();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('detox/device_control');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'getLaunchableApps') {
        return [
          {'name': 'Alpha', 'packageName': 'example.alpha'},
          {'name': 'Beta', 'packageName': 'example.beta'},
        ];
      }
      if (call.method == 'hasOverlayPermission') return true;
      return null;
    });
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      notifications,
      (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'areNotificationsEnabled') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        notifications,
        null,
      );
      AppCatalogService.clearCache();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: SettingsScreen(
            darkMode: false,
            onDarkModeChanged: (_) {},
            currentUser: null,
            onSignOut: () async {},
            localeCode: 'en',
            onLocaleChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const PageStorageKey('settings-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.add),
      300,
      scrollable: scrollable,
    );
    final addButton = find.byIcon(Icons.add).first;
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('2 apps selected'), findsOneWidget);
    expect(find.text('Add 2 apps'), findsOneWidget);
    await tester.tap(find.text('Add 2 apps'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('No time limit'), findsNothing);
  });

  testWidgets('Adding an app waits when overlay permission is missing', (
    tester,
  ) async {
    AppCatalogService.clearCache();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('detox/device_control');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'getLaunchableApps') {
        return [
          {'name': 'Alpha', 'packageName': 'example.alpha'},
        ];
      }
      if (call.method == 'hasOverlayPermission') return false;
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      AppCatalogService.clearCache();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            darkMode: false,
            onDarkModeChanged: _noop,
            currentUser: null,
            onSignOut: _noopAsync,
            localeCode: 'en',
            onLocaleChanged: _noopLocale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const PageStorageKey('settings-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.add),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 apps'));
    await tester.pumpAndSettle();

    final saved = (await SharedPreferences.getInstance()).getStringList(
      'app_limits_v2',
    );
    expect(saved, isNull);
    expect(find.text('Overlay'), findsOneWidget);
  });

  testWidgets(
    'Zone editor uses a vertical app checklist and requires a choice',
    (tester) async {
      tester.view.physicalSize = const Size(360, 806);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'app_limits_v2': [
          AppLimit(
            appName: 'Alpha',
            packageName: 'example.alpha',
            minutes: 0,
          ).toJson(),
          AppLimit(
            appName: 'Beta',
            packageName: 'example.beta',
            minutes: 0,
          ).toJson(),
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: SettingsScreen(
              darkMode: false,
              onDarkModeChanged: (_) {},
              currentUser: null,
              onSignOut: () async {},
              localeCode: 'en',
              onLocaleChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byKey(const PageStorageKey('settings-list')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Add zone'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.byTooltip('Add zone'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(
        tester.getBottomLeft(find.widgetWithText(FilledButton, 'Save zone')).dy,
        lessThan(tester.view.physicalSize.height),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save zone'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save zone'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.widgetWithText(FilledButton, 'Save zone').hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('Move the map to any place'), findsNothing);
    },
  );

  testWidgets('Account actions live inside the profile card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            darkMode: false,
            onDarkModeChanged: (_) {},
            currentUser: const AuthUser(
              uid: 'anonymous-test',
              email: '',
              displayName: 'Donatelarump',
              provider: 'Anónimo',
              isAnonymous: true,
            ),
            onSignOut: () async {},
            localeCode: 'es',
            onLocaleChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Donatelarump'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Vincular con Google'), findsNothing);
    await tester.tap(find.text('Donatelarump'));
    await tester.pumpAndSettle();
    expect(find.text('Change username'), findsOneWidget);
    expect(find.text('Link with Google'), findsOneWidget);
    expect(find.text('Delete account'), findsWidgets);
  });
}

void _noop(bool _) {}
Future<void> _noopAsync() async {}
void _noopLocale(String _) {}
