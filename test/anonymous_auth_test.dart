import 'package:detox/models/auth_user.dart';
import 'package:detox/screens/auth_screen.dart';
import 'package:detox/screens/anonymous_username_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });

  test('Anonymous identity survives serialization and old profiles remain compatible', () {
    const user = AuthUser(
      uid: 'stable-uid',
      email: '',
      displayName: 'alias',
      provider: 'anonymous',
      isAnonymous: true,
    );
    final restored = AuthUser.fromJson(user.toJson());
    expect(restored.uid, 'stable-uid');
    expect(restored.isAnonymous, isTrue);
    expect(restored.email, isEmpty);
    expect(
      AuthUser.fromJson('{"uid":"legacy","email":"a@b.com"}').isAnonymous,
      isFalse,
    );
  });

  testWidgets('Anonymous entry asks for alias without requiring email', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(onAuthenticated: (_) async {})),
    );
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Start anonymously'));
    await tester.pumpAndSettle();
    expect(find.byType(AnonymousUsernameScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AnonymousUsernameScreen),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(AnonymousUsernameScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'p3nd3jo');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose another username.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AnonymousUsernameScreen), findsNothing);
  });

  testWidgets('Account forms are separate from the anonymous entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(onAuthenticated: (_) async {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Start anonymously'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Start anonymously'), findsOneWidget);
  });
}
