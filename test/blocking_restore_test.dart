import 'dart:convert';

import 'package:detox/services/app_blocking_service.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
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

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuth();
  });

  test('Removing a restored focus block preserves the automation block',
      () async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('detox/device_control');
    Map<String, dynamic>? lastStart;
    var stopCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getBlockingSources') {
        return jsonEncode({
          'uid': null,
          'requests': [
            {
              'source': 'focus',
              'blockedPackages': ['example.focus'],
              'reason': 'focus_session',
              'hasSponsor': false,
              'strictMode': false,
            },
            {
              'source': 'automation',
              'blockedPackages': ['example.schedule'],
              'reason': 'automation_rule',
              'hasSponsor': false,
              'strictMode': false,
            },
            {
              'source': 'old_focus',
              'blockedPackages': ['example.expired'],
              'reason': 'focus_session',
              'hasSponsor': false,
              'strictMode': false,
              'expiresAtMillis': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .millisecondsSinceEpoch,
            },
          ],
        });
      }
      if (call.method == 'startBlocking') {
        lastStart = Map<String, dynamic>.from(call.arguments as Map);
        return true;
      }
      if (call.method == 'stopBlocking') stopCalls++;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await AppBlockingService.instance.stopShield(source: 'focus');

    expect(stopCalls, 0);
    expect(lastStart?['blockedPackages'], ['example.schedule']);
    final stored =
        jsonDecode(lastStart?['sourcesJson'] as String) as Map<String, dynamic>;
    final sources = stored['requests'] as List<dynamic>;
    expect(sources.map((e) => (e as Map)['source']), ['automation']);
  });
}
