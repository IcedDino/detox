import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

class NativeBlockAction {
  static const String requestShieldPause = 'request_shield_pause';
  static const String suspendShield15 = 'suspend_shield_15';
}

class _ShieldSourceState {
  const _ShieldSourceState({
    required this.blockedPackages,
    required this.reason,
    required this.hasSponsor,
    required this.strictMode,
  });

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
  final Map<String, _ShieldSourceState> _activeSources =
  <String, _ShieldSourceState>{};

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
    required bool hasSponsor,
    String source = 'default',
    bool? strictModeOverride,
  }) async {
    if (!_isAndroid) return;

    final normalized = blockedPackages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (normalized.isEmpty) {
      await stopShield(source: source);
      return;
    }

    try {
      final strictMode = strictModeOverride ?? await _storage.getStrictMode();
      _activeSources[source] = _ShieldSourceState(
        blockedPackages: normalized,
        reason: reason,
        hasSponsor: hasSponsor,
        strictMode: strictMode,
      );
      await _applyMergedShieldState();
    } catch (e) {
      debugPrint('startShield error: $e');
    }
  }

  Future<void> stopShield({String source = 'default'}) async {
    if (!_isAndroid) return;
    try {
      _activeSources.remove(source);
      await _applyMergedShieldState();
    } catch (e) {
      debugPrint('stopShield error: $e');
    }
  }

  Future<void> suspendForMinutes(int minutes) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('suspendBlockingForMinutes', {
        'minutes': minutes,
      });
    } catch (e) {
      debugPrint('suspendForMinutes error: $e');
    }
  }

  Future<String?> consumePendingNativeAction() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('consumePendingBlockAction');
    } catch (e) {
      debugPrint('consumePendingNativeAction error: $e');
      return null;
    }
  }

  Future<void> syncSponsorState(bool hasSponsor) async {
    if (!_isAndroid) return;
    try {
      final strictMode = await _storage.getStrictMode();

      await _channel.invokeMethod('syncSponsorState', {
        'hasSponsor': hasSponsor,
        'strictMode': strictMode,
      });

      if (_activeSources.isNotEmpty) {
        final keys = _activeSources.keys.toList(growable: false);
        for (final key in keys) {
          final current = _activeSources[key];
          if (current == null) continue;
          _activeSources[key] = _ShieldSourceState(
            blockedPackages: current.blockedPackages,
            reason: current.reason,
            hasSponsor: hasSponsor,
            strictMode: current.strictMode,
          );
        }
        await _applyMergedShieldState();
      }
    } catch (e) {
      debugPrint('syncSponsorState error: $e');
    }
  }

  Future<void> _applyMergedShieldState() async {
    if (_activeSources.isEmpty) {
      await _channel.invokeMethod('stopBlocking');
      return;
    }

    final mergedPackages = <String>{};
    var hasSponsor = false;
    var strictMode = false;
    final reasons = <String>[];

    for (final state in _activeSources.values) {
      mergedPackages.addAll(state.blockedPackages);
      hasSponsor = hasSponsor || state.hasSponsor;
      strictMode = strictMode || state.strictMode;
      if (state.reason.trim().isNotEmpty) {
        reasons.add(state.reason.trim());
      }
    }

    final normalizedPackages = mergedPackages.toList()..sort();
    if (normalizedPackages.isEmpty) {
      await _channel.invokeMethod('stopBlocking');
      return;
    }

    await _channel.invokeMethod('startBlocking', {
      'blockedPackages': normalizedPackages,
      'reason': reasons.isEmpty ? 'focus_session' : reasons.join(' • '),
      'hasSponsor': hasSponsor,
      'strictMode': strictMode,
    });
  }
}
