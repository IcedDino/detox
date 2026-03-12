Detox iOS Screen Time integration notes

This project now separates platform behavior cleanly so Android keeps working while iOS can evolve independently.

What is still pending for real iOS enforcement:
- Family Controls entitlement approval from Apple
- Native iOS targets/extensions for DeviceActivity / ManagedSettings / Shield configuration
- App Group setup and signing in Xcode

Current app behavior on iOS:
- Same UI and navigation flow as Android
- Habits, focus timer, settings, and app limit model remain available
- Usage analytics remain placeholder until the Screen Time entitlement flow is completed
