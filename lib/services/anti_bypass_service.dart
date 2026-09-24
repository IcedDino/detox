import 'dart:async';

import 'app_blocking_service.dart';
import 'automation_service.dart';
import 'usage_service.dart';

class AntiBypassStatus {
  const AntiBypassStatus({required this.usageReady, required this.overlayReady});
  final bool usageReady;
  final bool overlayReady;
  bool get healthy => usageReady && overlayReady;
}

class AntiBypassService {
  AntiBypassService._();
  static final AntiBypassService instance = AntiBypassService._();

  static const Duration _pollInterval = Duration(seconds: 75);
  final UsageService _usage = UsageService();
  Timer? _timer;
  bool? _lastHealthy;

  Future<AntiBypassStatus> getStatus() async {
    final usage = await _usage.getPermissionStatus();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    return AntiBypassStatus(usageReady: usage.usageReady, overlayReady: overlay);
  }

  Future<void> start() async {
    _timer?.cancel();
    _lastHealthy = (await getStatus()).healthy;
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    final status = await getStatus();
    final recovered = status.healthy && _lastHealthy == false;

    _lastHealthy = status.healthy;

    if (recovered) {
      await AutomationService.instance.refresh();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastHealthy = null;
  }
}
