import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    FocusNotificationService.pendingActionKey,
    response.actionId ?? response.payload ?? '',
  );
}

class FocusNotificationService {
  FocusNotificationService._();
  static final FocusNotificationService instance = FocusNotificationService._();

  static const int _notificationId = 8207;
  static const int _smartSuggestionNotificationId = 8211;
  static const String _channelId = 'detox_focus_timer';
  static const String _channelName = 'Detox Focus Timer';
  static const String _sponsorChannelId = 'detox_sponsor_alerts';
  static const String _sponsorChannelName = 'Detox Sponsor Alerts';
  static const String _smartChannelId = 'detox_smart_recommendations';
  static const String _smartChannelName = 'Detox Smart Recommendations';
  static const String startFocusAction = 'smart_focus_start';
  static const String denySuggestionAction = 'smart_focus_deny';
  static const String pendingActionKey = 'detox_pending_notification_action_v1';

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
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Shows remaining time for active focus sessions.',
        importance: Importance.low,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _sponsorChannelId,
        _sponsorChannelName,
        description: 'Sponsor requests and approval codes.',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _smartChannelId,
        _smartChannelName,
        description: 'Automatic focus recommendations after extended app usage.',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      pendingActionKey,
      response.actionId ?? response.payload ?? '',
    );
  }

  Future<String?> consumePendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(pendingActionKey);
    if (value == null || value.isEmpty) return null;
    await prefs.remove(pendingActionKey);
    return value;
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
        _channelId,
        _channelName,
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
      _notificationId,
      'Detox focus active',
      '$label remaining · ${_format(remainingSeconds)}',
      details,
    );
  }

  Future<void> showSmartUsageSuggestion({
    required String title,
    required String body,
    required String startActionLabel,
    required String denyActionLabel,
    required String appName,
    required int minutes,
  }) async {
    if (!_isAndroid) return;
    await initialize();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _smartChannelId,
        _smartChannelName,
        channelDescription: 'Automatic focus recommendations after extended app usage.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            startFocusAction,
            startActionLabel,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            denySuggestionAction,
            denyActionLabel,
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );

    await _plugin.show(
      _smartSuggestionNotificationId,
      title,
      body,
      details,
      payload: '$appName:$minutes',
    );
  }

  Future<void> showSponsorAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isAndroid) return;
    await initialize();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _sponsorChannelId,
        _sponsorChannelName,
        channelDescription: 'Sponsor requests and approval codes.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        visibility: NotificationVisibility.public,
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  Future<void> cancel() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(_notificationId);
  }

  Future<void> cancelSmartSuggestion() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(_smartSuggestionNotificationId);
  }

  Future<bool> _isVisible() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    final active = await androidPlugin.getActiveNotifications();
    return active.any((item) => item.id == _notificationId);
  }

  String _format(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
