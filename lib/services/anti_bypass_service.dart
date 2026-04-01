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

  final UsageService _usage = UsageService();
  Timer? _timer;

  Future<AntiBypassStatus> getStatus() async {
    final usage = await _usage.getPermissionStatus();
    final overlay = await AppBlockingService.instance.hasOverlayPermission();
    return AntiBypassStatus(usageReady: usage.usageReady, overlayReady: overlay);
  }

  Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) async {
      final status = await getStatus();
      if (status.healthy) {
        await AutomationService.instance.refresh();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
