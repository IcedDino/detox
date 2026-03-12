# Detox Firebase setup notes

This build includes:
- Firebase Authentication with Email/Password
- Google Sign-In
- Phone verification flow
- Cloud Firestore sync for user settings and habits

## Enable in Firebase Console
- Authentication > Sign-in method > Email/Password, Google, Phone
- Firestore Database > create database

## Synced data
- daily limit
- per-app limits and focus-mode app flags
- habits and streaks
- concentration zones
- onboarding completion

## Build
```bash
flutter clean
flutter pub get
flutter build apk --split-per-abi
```

## Notes
- Google sign-in on Android needs the correct SHA-1/SHA-256 in Firebase.
- Phone auth may require a physical device and proper Firebase project setup.
