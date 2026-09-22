// Generated fallback firebase options.
//
// Values were taken from `android/google-services.json` so the app can build
// without running `flutterfire configure`. Ideally regenerate this file with
// `flutterfire configure` to get all platforms (iOS/web) filled in.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Run "flutterfire configure" for this project.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS/macOS. '
          'Run "flutterfire configure" for this project.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgYO9qPz1iGEKIoWz4wgI5Hsy3ghfIwWo',
    appId: '1:957513789397:android:ab36f4c7b4989f47e8975c',
    messagingSenderId: '957513789397',
    projectId: 'detox-c0790',
    storageBucket: 'detox-c0790.firebasestorage.app',
    androidClientId:
        '957513789397-7rnrclagedk1461na4mc74jjsi4crika.apps.googleusercontent.com',
  );
}
