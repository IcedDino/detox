import 'package:detox/models/app_limit.dart';
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
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuth();
  });

  testWidgets('Settings mounts visible app rows and keeps scroll across tabs',
      (tester) async {
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
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pumpAndSettle();
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

  testWidgets('App picker keeps multiple selections in one opening',
      (tester) async {
    AppCatalogService.clearCache();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('detox/device_control');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'getLaunchableApps') {
          return [
            {'name': 'Alpha', 'packageName': 'example.alpha'},
            {'name': 'Beta', 'packageName': 'example.beta'},
          ];
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      AppCatalogService.clearCache();
    });

    await tester.pumpWidget(MaterialApp(
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
    ));
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
  });
}
