import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FocusNotificationService {
  FocusNotificationService._();
  static final FocusNotificationService instance = FocusNotificationService._();

  static const int _notificationId = 8207;
  static const String _channelId = 'detox_focus_timer';
  static const String _channelName = 'Detox Focus Timer';
  static const String _sponsorChannelId = 'detox_sponsor_alerts';
  static const String _sponsorChannelName = 'Detox Sponsor Alerts';

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
    await _plugin.initialize(settings);

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

    _initialized = true;
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
