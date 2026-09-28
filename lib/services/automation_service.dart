import 'dart:async';

import '../models/automation_rule.dart';
import 'app_blocking_service.dart';
import 'location_zone_service.dart';
import 'sponsor_service.dart';
import 'storage_service.dart';

class AutomationSnapshot {
  const AutomationSnapshot({
    required this.activeRules,
    required this.strictMode,
  });

  final List<AutomationRule> activeRules;
  final bool strictMode;

  bool get hasAnythingActive => activeRules.isNotEmpty;
}

class AutomationService {
  AutomationService._();
  static final AutomationService instance = AutomationService._();
  static const String _inactiveKey = '__inactive__';

  final StorageService _storage = StorageService();

  Timer? _timer;
  Timer? _midnightTimer;
  String? _activeKey;

  Future<void> start() async {
    _timer?.cancel();
    _activeKey = null;
    await refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(refresh());
    });
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      _scheduleMidnightRefresh();
      unawaited(refresh());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }

  Future<AutomationSnapshot> buildSnapshot() async {
    final results = await Future.wait<dynamic>([
      _storage.loadAutomationRules(),
      _storage.loadStrictModeEnabled(),
    ]);
    final rules = results[0] as List<AutomationRule>;
    final strictMode = results[1] as bool;
    final insideZone = LocationZoneService.instance.currentState.insideZone;
    final now = DateTime.now();

    final activeRules = rules
        .where((rule) => rule.appliesAt(now, insideZone: insideZone))
        .where((rule) => rule.blockedPackages.isNotEmpty)
        .toList();

    final completedAt = DateTime.now();
    if (completedAt.year != now.year ||
        completedAt.month != now.month ||
        completedAt.day != now.day) {
      return buildSnapshot();
    }

    return AutomationSnapshot(
      activeRules: activeRules,
      strictMode: strictMode || activeRules.any((e) => e.strictMode),
    );
  }

  Future<void> refresh() async {
    final snapshot = await buildSnapshot();
    if (!snapshot.hasAnythingActive) {
      // Clear saved automatic limits left by earlier builds that generated a
      // 30-minute limit as a side effect of adding an app.
      if (_activeKey != _inactiveKey) {
        await AppBlockingService.instance.stopShield(source: 'automation');
        _activeKey = _inactiveKey;
      }
      return;
    }

    final packages = <String>{};
    for (final rule in snapshot.activeRules) {
      packages.addAll(rule.blockedPackages.where((e) => e.isNotEmpty));
    }
    final sortedPackages = packages.toList()..sort();
    if (sortedPackages.isEmpty) return;

    final key = [
      sortedPackages.join(','),
      snapshot.strictMode ? 'strict' : 'soft',
      snapshot.activeRules.map((e) => e.id).join(','),
    ].join('|');

    if (key == _activeKey) return;

    final hasSponsor = await SponsorService.instance.hasSponsor();

    final started = await AppBlockingService.instance.startShield(
      blockedPackages: sortedPackages,
      reason: 'automation_rule',
      hasSponsor: hasSponsor,
      source: 'automation',
      strictModeOverride: snapshot.strictMode,
    );
    if (started) _activeKey = key;
  }
}
