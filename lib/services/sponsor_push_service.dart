import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'focus_notification_service.dart';
import 'sponsor_push_notice.dart';

class SponsorPushService {
  SponsorPushService._();
  static final SponsorPushService instance = SponsorPushService._();

  static const _deviceIdKey = 'sponsor_push_device_id_v1';

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  VoidCallback? _onOpenSponsor;
  String? _registeredUid;
  String? _deviceId;
  String _locale = 'es';
  bool _foreground = true;

  bool get isRegistered => _registeredUid != null;

  void setOpenHandler(VoidCallback? handler) {
    _onOpenSponsor = handler;
  }

  Future<void> start({required String locale}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_registeredUid != null && _registeredUid != uid) {
      await stopAndRemove();
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (error) {
        debugPrint('Old sponsor push token could not be invalidated: $error');
      }
    }
    _locale = locale;
    _deviceId ??= await _loadDeviceId();
    _registeredUid = uid;
    _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_saveToken(token));
    });
    _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
    _messageSub ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleOpen(initial);
    } catch (error) {
      debugPrint('Sponsor push registration unavailable: $error');
    }
  }

  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    final ref = _tokenRef();
    if (ref == null) return;
    try {
      await ref.update({
        'foreground': foreground,
        'locale': _locale,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> stopAndRemove() async {
    await _tokenSub?.cancel();
    await _openSub?.cancel();
    await _messageSub?.cancel();
    _tokenSub = null;
    _openSub = null;
    _messageSub = null;
    final ref = _tokenRef();
    if (ref != null) {
      try {
        await ref.delete();
      } catch (_) {}
    }
    _registeredUid = null;
  }

  void _handleOpen(RemoteMessage message) {
    if (message.data['type'] == 'sponsor') _onOpenSponsor?.call();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notice = SponsorPushNotice.fromMessage(message);
    if (notice == null) return;
    unawaited(
      FocusNotificationService.instance.showSponsorAlert(
        id: notice.id,
        title: notice.title,
        body: notice.body,
      ),
    );
  }

  Future<void> _saveToken(String token) async {
    final ref = _tokenRef();
    if (ref == null) return;
    try {
      await ref.set({
        'token': token,
        'locale': _locale,
        'foreground': _foreground,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Sponsor push token could not be saved: $error');
    }
  }

  DocumentReference<Map<String, dynamic>>? _tokenRef() {
    final uid = _registeredUid;
    final id = _deviceId;
    if (uid == null || id == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('push_tokens')
        .doc(id);
  }

  Future<String> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}
