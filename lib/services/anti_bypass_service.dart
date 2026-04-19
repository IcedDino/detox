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
  static const Duration _automationRefreshInterval = Duration(minutes: 5);

  final UsageService _usage = UsageService();
  Timer? _timer;
  bool? _lastHealthy;
  DateTime? _lastAutomationRefreshAt;

  Future<AntiBypassStatus> getStatus() async {
    final usage = await _usage.getPermissionStatus();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    return AntiBypassStatus(usageReady: usage.usageReady, overlayReady: overlay);
  }

  Future<void> start() async {
    _timer?.cancel();
    await _poll();
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    final status = await getStatus();
    final now = DateTime.now();
    final shouldRefreshAutomation =
        status.healthy &&
        (_lastHealthy != true ||
            _lastAutomationRefreshAt == null ||
            now.difference(_lastAutomationRefreshAt!) >=
                _automationRefreshInterval);

    _lastHealthy = status.healthy;

    if (shouldRefreshAutomation) {
      await AutomationService.instance.refresh();
      _lastAutomationRefreshAt = now;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastHealthy = null;
    _lastAutomationRefreshAt = null;
  }
}
