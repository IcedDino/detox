import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppBlockingService {
  static const MethodChannel _channel = MethodChannel('detox/device_control');
  static final AppBlockingService instance = AppBlockingService._();

  AppBlockingService._();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('hasOverlayPermission error: $e');
      return false;
    }
  }

  Future<void> openOverlayPermissionSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openOverlayPermissionSettings');
    } catch (e) {
      debugPrint('openOverlayPermissionSettings error: $e');
    }
  }

  Future<void> startShield({
    required List<String> blockedPackages,
    required String reason,
  }) async {
    if (!_isAndroid) return;
    final normalized = blockedPackages.toSet().where((e) => e.isNotEmpty).toList();
    if (normalized.isEmpty) return;
    try {
      await _channel.invokeMethod('startBlocking', {
        'blockedPackages': normalized,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('startShield error: $e');
    }
  }

  Future<void> stopShield() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stopBlocking');
    } catch (e) {
      debugPrint('stopShield error: $e');
    }
  }
}
