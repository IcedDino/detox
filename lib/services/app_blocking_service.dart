import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cloud_sync_service.dart';
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
    this.expiresAtMillis,
  });

  final String source;
  final List<String> blockedPackages;
  final String reason;
  final bool hasSponsor;
  final bool strictMode;
  final int? expiresAtMillis;
}

class AppBlockingService {
  static const MethodChannel _channel = MethodChannel('detox/device_control');
  static final AppBlockingService instance = AppBlockingService._();
  AppBlockingService._();

  final StorageService _storage = StorageService();
  final Map<String, _ShieldRequest> _requests = <String, _ShieldRequest>{};
  Future<void>? _restoreFuture;
  String? _ownerUid;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasUsageAccess() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openUsageAccessSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  Future<void> openOverlayPermissionSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('openOverlayPermissionSettings');
    } catch (_) {}
  }

  /// Android may kill the shield service while Detox is in the background
  /// unless the app is exempt from battery optimization.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  Future<bool> startShield({
    required List<String> blockedPackages,
    required String reason,
    required bool hasSponsor,
    String source = 'default',
    bool? strictModeOverride,
    DateTime? expiresAt,
  }) async {
    if (!_isAndroid) return false;
    await _restoreRequests();
    await _resetForNewUser();
    final normalized =
        blockedPackages.toSet().where((e) => e.isNotEmpty).toList()..sort();
    if (normalized.isEmpty) return false;
    final strictMode = strictModeOverride ?? await _storage.getStrictMode();
    _requests[source] = _ShieldRequest(
      source: source,
      blockedPackages: normalized,
      reason: reason,
      hasSponsor: hasSponsor,
      strictMode: strictMode,
      expiresAtMillis: expiresAt?.millisecondsSinceEpoch,
    );
    return _syncMergedState();
  }

  Future<void> stopShield({String? source}) async {
    if (!_isAndroid) return;
    await _restoreRequests();
    await _resetForNewUser();
    if (source == null) {
      _requests.clear();
    } else {
      _requests.remove(source);
    }
    await _syncMergedState();
  }

  Future<bool> _syncMergedState() async {
    if (!_isAndroid) return false;
    _requests.removeWhere((_, request) =>
        request.expiresAtMillis != null &&
        request.expiresAtMillis! <= DateTime.now().millisecondsSinceEpoch);
    if (_requests.isEmpty) {
      try {
        await _channel.invokeMethod('stopBlocking');
      } catch (_) {}
      return false;
    }

    final mergedPackages = _requests.values
        .expand((e) => e.blockedPackages)
        .toSet()
        .toList()
      ..sort();
    final strictMode = _requests.values.any((e) => e.strictMode);
    final hasSponsor = _requests.values.any((e) => e.hasSponsor);
    final reasons = _requests.values.map((e) => e.reason).toSet().toList();

    try {
      return await _channel.invokeMethod<bool>('startBlocking', {
            'blockedPackages': mergedPackages,
            'reason': reasons.join(', '),
            'hasSponsor': hasSponsor,
            'strictMode': strictMode,
            'sourcesJson': jsonEncode({
              'uid': _ownerUid,
              'requests': _requests.values
                  .map((request) => {
                        'source': request.source,
                        'blockedPackages': request.blockedPackages,
                        'reason': request.reason,
                        'hasSponsor': request.hasSponsor,
                        'strictMode': request.strictMode,
                        'expiresAtMillis': request.expiresAtMillis,
                      })
                  .toList(),
            }),
          }) ??
          false;
    } catch (e) {
      debugPrint('startShield error: $e');
      return false;
    }
  }

  Future<void> suspendForMinutes(int minutes) async {
    if (!_isAndroid) return;
    try {
      await _channel
          .invokeMethod('suspendBlockingForMinutes', {'minutes': minutes});
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

  Future<void> refreshStrictMode() async {
    if (!_isAndroid) return;
    await _restoreRequests();
    await _resetForNewUser();
    if (_requests.isEmpty) return;
    final strictMode = await _storage.getStrictMode();
    final updated = <String, _ShieldRequest>{};
    for (final entry in _requests.entries) {
      updated[entry.key] = _ShieldRequest(
        source: entry.value.source,
        blockedPackages: entry.value.blockedPackages,
        reason: entry.value.reason,
        hasSponsor: entry.value.hasSponsor,
        strictMode: strictMode,
        expiresAtMillis: entry.value.expiresAtMillis,
      );
    }
    _requests
      ..clear()
      ..addAll(updated);
    await _syncMergedState();
  }

  Future<void> syncSponsorState(bool hasSponsor) async {
    if (!_isAndroid) return;
    if (CloudSyncService.instance.currentUid == null) return;
    await _restoreRequests();
    await _resetForNewUser();
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
            expiresAtMillis: entry.value.expiresAtMillis,
          );
        }
        _requests
          ..clear()
          ..addAll(updated);
        await _syncMergedState();
      }
    } catch (_) {}
  }

  Future<void> _restoreRequests() async {
    final inFlight = _restoreFuture;
    if (inFlight != null) return inFlight;
    final future = _restoreRequestsInternal();
    _restoreFuture = future;
    await future;
  }

  Future<void> _restoreRequestsInternal() async {
    try {
      final raw = await _channel.invokeMethod<String>('getBlockingSources');
      if (raw == null || raw.isEmpty) {
        _ownerUid = CloudSyncService.instance.currentUid;
        return;
      }
      final state = jsonDecode(raw) as Map<String, dynamic>;
      if (state['uid'] != CloudSyncService.instance.currentUid) {
        await _channel.invokeMethod('stopBlocking');
        _ownerUid = CloudSyncService.instance.currentUid;
        return;
      }
      _ownerUid = CloudSyncService.instance.currentUid;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in (state['requests'] as List<dynamic>? ?? const [])) {
        final data = Map<String, dynamic>.from(item as Map);
        final until = data['expiresAtMillis'] as int?;
        if (until != null && until <= now) continue;
        final source = data['source'] as String?;
        if (source == null || source.isEmpty) continue;
        _requests.putIfAbsent(
          source,
          () => _ShieldRequest(
            source: source,
            blockedPackages: List<String>.from(data['blockedPackages'] as List),
            reason: data['reason'] as String? ?? '',
            hasSponsor: data['hasSponsor'] == true,
            strictMode: data['strictMode'] == true,
            expiresAtMillis: until,
          ),
        );
      }
    } catch (e) {
      debugPrint('restoreShield error: $e');
    }
  }

  Future<void> _resetForNewUser() async {
    final uid = CloudSyncService.instance.currentUid;
    if (uid == null || uid == _ownerUid) return;
    _requests.clear();
    _ownerUid = uid;
    await _channel.invokeMethod('stopBlocking');
  }
}
