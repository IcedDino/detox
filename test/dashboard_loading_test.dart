import 'package:detox/screens/dashboard_screen.dart';
import 'package:detox/models/dashboard_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home reads and displays usage on its first mount after login',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('detox/device_control');
    var queries = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      switch (call.method) {
        case 'queryUsage':
          queries++;
          return [
            {'packageName': 'org.example.reader', 'minutes': 12},
          ];
        case 'getAppLabels':
          return {'org.example.reader': 'Reader'};
        case 'hasUsageAccess':
          return true;
        default:
          return null;
      }
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();
    await tester
        .widget<FutureBuilder<DashboardData>>(
            find.byType(FutureBuilder<DashboardData>))
        .future;
    expect(queries, 1, reason: 'Home must reach Android on the first mount.');
    expect(find.text('0h 12m'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
