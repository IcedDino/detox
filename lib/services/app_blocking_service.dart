import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

class NativeBlockAction {
  static const String requestShieldPause = 'request_shield_pause';
  static const String suspendShield15 = 'suspend_shield_15';
}

class _ShieldRequest {
  const _ShieldRequest({
    required this.source,
    required this.blockedPackages,
    required this.reason,
    required this.hasSponsor,
    required this.strictMode,
  });

  final String source;
  final List<String> blockedPackages;
  final String reason;
  final bool hasSponsor;
  final bool strictMode;
}

class AppBlockingService {
  static const MethodChannel _channel = MethodChannel('detox/device_control');
  static final AppBlockingService instance = AppBlockingService._();
  AppBlockingService._();

  final StorageService _storage = StorageService();
  final Map<String, _ShieldRequest> _requests = <String, _ShieldRequest>{};

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openOverlayPermissionSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openOverlayPermissionSettings');
    } catch (_) {}
  }

  Future<void> startShield({
    required List<String> blockedPackages,
    required String reason,
    required bool hasSponsor,
    String source = 'default',
    bool? strictModeOverride,
  }) async {
    if (!_isAndroid) return;
    final normalized = blockedPackages.toSet().where((e) => e.isNotEmpty).toList()..sort();
    if (normalized.isEmpty) return;
    final strictMode = strictModeOverride ?? await _storage.getStrictMode();
    _requests[source] = _ShieldRequest(
      source: source,
      blockedPackages: normalized,
      reason: reason,
      hasSponsor: hasSponsor,
      strictMode: strictMode,
    );
    await _syncMergedState();
  }

  Future<void> stopShield({String? source}) async {
    if (!_isAndroid) return;
    if (source == null) {
      _requests.clear();
    } else {
      _requests.remove(source);
    }
    await _syncMergedState();
  }

  Future<void> _syncMergedState() async {
    if (!_isAndroid) return;
    if (_requests.isEmpty) {
      try {
        await _channel.invokeMethod('stopBlocking');
      } catch (_) {}
      return;
    }

    final mergedPackages = _requests.values.expand((e) => e.blockedPackages).toSet().toList()..sort();
    final strictMode = _requests.values.any((e) => e.strictMode);
    final hasSponsor = _requests.values.any((e) => e.hasSponsor);
    final reasons = _requests.values.map((e) => e.reason).toSet().toList();

    try {
      await _channel.invokeMethod('startBlocking', {
        'blockedPackages': mergedPackages,
        'reason': reasons.join(', '),
        'hasSponsor': hasSponsor,
        'strictMode': strictMode,
      });
    } catch (e) {
      debugPrint('startShield error: $e');
    }
  }

  Future<void> suspendForMinutes(int minutes) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('suspendBlockingForMinutes', {'minutes': minutes});
    } catch (_) {}
  }

  Future<String?> consumePendingNativeAction() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('consumePendingBlockAction');
    } catch (_) {
      return null;
    }
  }

  Future<void> syncSponsorState(bool hasSponsor) async {
    if (!_isAndroid) return;
    final strictMode = await _storage.getStrictMode();
    try {
      await _channel.invokeMethod('syncSponsorState', {
        'hasSponsor': hasSponsor,
        'strictMode': strictMode,
      });
      if (_requests.isNotEmpty) {
        final updated = <String, _ShieldRequest>{};
        for (final entry in _requests.entries) {
          updated[entry.key] = _ShieldRequest(
            source: entry.value.source,
            blockedPackages: entry.value.blockedPackages,
            reason: entry.value.reason,
            hasSponsor: hasSponsor,
            strictMode: entry.value.strictMode,
          );
        }
        _requests
          ..clear()
          ..addAll(updated);
        await _syncMergedState();
      }
    } catch (_) {}
  }
}
