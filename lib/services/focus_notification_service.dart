import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusNotificationService {
  FocusNotificationService._();
  static final FocusNotificationService instance = FocusNotificationService._();

  static const int _timerNotificationId = 8207;
  static const int _smartSuggestionId = 8208;

  static const String _timerChannelId = 'detox_focus_timer';
  static const String _timerChannelName = 'Detox Focus Timer';

  static const String _sponsorChannelId = 'detox_sponsor_alerts';
  static const String _sponsorChannelName = 'Detox Sponsor Alerts';

  static const String _smartChannelId = 'detox_smart_suggestions';
  static const String _smartChannelName = 'Detox Smart Suggestions';

  static const String _pendingActionKey = 'pending_notification_action_v1';
  static const String _pendingPayloadKey = 'pending_notification_payload_v1';

  static const String actionOpenSponsorCenter = 'open_sponsor_center';
  static const String actionStartFocusHour = 'start_focus_hour';
  static const String actionDenyFocusHour = 'deny_focus_hour';
  static const String actionSmartStart = 'smart_start';
  static const String actionSmartDismiss = 'smart_dismiss';

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _suppressedUntilResume = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        await _persistResponse(response);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) {
        await _persistResponse(response);
      }
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();


    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _timerChannelId,
        _timerChannelName,
        description: 'Shows remaining time for active focus sessions.',
        importance: Importance.low,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _sponsorChannelId,
        _sponsorChannelName,
        description: 'Sponsor requests and approval updates.',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _smartChannelId,
        _smartChannelName,
        description: 'Smart suggestions based on app usage.',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }


  Future<bool> hasPermission() async {
    if (!_isAndroid) return true;
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await androidPlugin?.areNotificationsEnabled();
    return enabled ?? false;
  }

  Future<bool> requestPermission() async {
    if (!_isAndroid) return true;
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidPlugin?.requestNotificationsPermission();
    if (granted != null) return granted;

    return await hasPermission();
  }

  Future<void> _persistResponse(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;

    final effectiveAction = (actionId != null && actionId.isNotEmpty)
        ? actionId
        : ((payload != null && payload.isNotEmpty) ? payload : null);

    await savePendingAction(
      effectiveAction,
      payload: payload,
    );
  }

  Future<void> savePendingAction(
      String? action, {
        String? payload,
      }) async {
    final prefs = await SharedPreferences.getInstance();

    if (action != null && action.isNotEmpty) {
      await prefs.setString(_pendingActionKey, action);
    } else {
      await prefs.remove(_pendingActionKey);
    }

    if (payload != null && payload.isNotEmpty) {
      await prefs.setString(_pendingPayloadKey, payload);
    } else {
      await prefs.remove(_pendingPayloadKey);
    }
  }

  Future<String?> consumePendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingActionKey);
    if (value != null) {
      await prefs.remove(_pendingActionKey);
    }
    return value;
  }

  Future<Map<String, dynamic>?> consumePendingPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPayloadKey);
    if (raw == null || raw.isEmpty) return null;

    await prefs.remove(_pendingPayloadKey);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
              (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}

    return null;
  }

  Future<void> resetSuppression() async {
    _suppressedUntilResume = false;
  }

  Future<void> showOrUpdateTimer({
    required int remainingSeconds,
    required String label,
    bool force = false,
  }) async {
    if (!_isAndroid) return;
    await initialize();

    if (_suppressedUntilResume) return;

    if (!force) {
      final visible = await _isVisible();
      if (!visible) {
        _suppressedUntilResume = true;
        return;
      }
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannelId,
        _timerChannelName,
        channelDescription: 'Shows remaining time for active focus sessions.',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        ongoing: false,
        autoCancel: false,
        showWhen: false,
        visibility: NotificationVisibility.public,
      ),
    );

    await _plugin.show(
      _timerNotificationId,
      'Detox focus active',
      '$label remaining · ${_format(remainingSeconds)}',
      details,
    );
  }

  Future<void> showSmartSuggestion({
    required String title,
    required String body,
    required String startLabel,
    required String denyLabel,
    String? packageName,
    String? appName,
  }) async {
    if (!_isAndroid) return;
    await initialize();

    final payload = jsonEncode({
      'type': 'smart_suggestion',
      'packageName': packageName,
      'appName': appName,
    });

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _smartChannelId,
        _smartChannelName,
        channelDescription: 'Smart suggestions based on app usage.',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionSmartStart,
            startLabel,
            cancelNotification: true,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            actionSmartDismiss,
            denyLabel,
            cancelNotification: true,
          ),
        ],
      ),
    );

    await _plugin.show(
      _smartSuggestionId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showSponsorAlert({
    required int id,
    required String title,
    required String body,
    String payload = actionOpenSponsorCenter,
  }) async {
    if (!_isAndroid) return;
    await initialize();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _sponsorChannelId,
        _sponsorChannelName,
        channelDescription: 'Sponsor requests and approval updates.',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        visibility: NotificationVisibility.public,
      ),
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> cancel() async {
    await cancelTimer();
  }

  Future<void> cancelTimer() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(_timerNotificationId);
  }

  Future<void> cancelSmartSuggestion() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(_smartSuggestionId);
  }

  Future<void> cancelSponsorAlert(int id) async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancelAll();
  }

  Future<bool> _isVisible() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    final active = await androidPlugin.getActiveNotifications();
    return active.any((item) => item.id == _timerNotificationId);
  }

  String _format(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
