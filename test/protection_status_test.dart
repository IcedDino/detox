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
  FirebaseAuthPlatform setInitialValues({Object? currentUser, String? languageCode}) => this;

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

  test('Protection status shows independent sources and omits expired blocks', () async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('detox/device_control');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getBlockingSources') {
        return jsonEncode({
          'uid': null,
          'requests': [
            {'source': 'zone', 'blockedPackages': ['example.chat'], 'reason': 'Study zone: Home', 'hasSponsor': false, 'strictMode': false},
            {'source': 'automation', 'blockedPackages': ['example.chat', 'example.video'], 'reason': 'automation_rule', 'hasSponsor': false, 'strictMode': false},
            {'source': 'focus', 'blockedPackages': ['example.old'], 'reason': 'focus_session', 'hasSponsor': false, 'strictMode': false, 'expiresAtMillis': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch},
          ],
        });
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final sources = await AppBlockingService.instance.getActiveSources();

    expect(sources.map((source) => source.source), ['zone', 'automation']);
    expect(sources.first.blockedPackages, ['example.chat']);
    expect(sources.last.blockedPackages, ['example.chat', 'example.video']);
  });
}
