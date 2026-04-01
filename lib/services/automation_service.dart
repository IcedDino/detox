import 'dart:async';
import '../services/sponsor_service.dart';
import '../models/app_limit.dart';
import '../models/automation_rule.dart';
import 'app_blocking_service.dart';
import 'location_zone_service.dart';

import 'storage_service.dart';
import 'usage_service.dart';

class AutomationSnapshot {
  const AutomationSnapshot({
    required this.activeRules,
    required this.overLimitPackages,
    required this.strictMode,
  });

  final List<AutomationRule> activeRules;
  final List<String> overLimitPackages;
  final bool strictMode;

  bool get hasAnythingActive => activeRules.isNotEmpty || overLimitPackages.isNotEmpty;
}

class AutomationService {
  AutomationService._();
  static final AutomationService instance = AutomationService._();

  final StorageService _storage = StorageService();
  final UsageService _usage = UsageService();

  Timer? _timer;
  String? _activeKey;

  Future<void> start() async {
    _timer?.cancel();
    await refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      refresh();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<AutomationSnapshot> buildSnapshot() async {
    final rules = await _storage.loadAutomationRules();
    final appLimits = await _storage.loadAppLimits();
    final strictMode = await _storage.loadStrictModeEnabled();
    final insideZone = LocationZoneService.instance.currentState.insideZone;
    final now = DateTime.now();

    final activeRules = rules
        .where((rule) => rule.appliesAt(now, insideZone: insideZone))
        .where((rule) => rule.blockedPackages.isNotEmpty)
        .toList();

    final usageEntries = await _usage.getTodayAppUsageEntries();
    final limitMap = <String, AppLimit>{
      for (final item in appLimits)
        if ((item.packageName ?? '').isNotEmpty) item.packageName!: item,
    };

    final overLimitPackages = usageEntries
        .where((entry) => (entry.packageName ?? '').isNotEmpty)
        .where((entry) {
          final limit = limitMap[entry.packageName!];
          return limit != null && entry.minutes >= limit.minutes;
        })
        .map((e) => e.packageName!)
        .toSet()
        .toList()
      ..sort();

    return AutomationSnapshot(
      activeRules: activeRules,
      overLimitPackages: overLimitPackages,
      strictMode: strictMode || activeRules.any((e) => e.strictMode),
    );
  }

  Future<void> refresh() async {
    final snapshot = await buildSnapshot();
    if (!snapshot.hasAnythingActive) {
      if (_activeKey != null) {
        await AppBlockingService.instance.stopShield(source: 'automation');
        _activeKey = null;
      }
      return;
    }

    final packages = <String>{};
    for (final rule in snapshot.activeRules) {
      packages.addAll(rule.blockedPackages.where((e) => e.isNotEmpty));
    }
    packages.addAll(snapshot.overLimitPackages.where((e) => e.isNotEmpty));
    final sortedPackages = packages.toList()..sort();
    if (sortedPackages.isEmpty) return;

    final key = [
      sortedPackages.join(','),
      snapshot.strictMode ? 'strict' : 'soft',
      snapshot.activeRules.map((e) => e.id).join(','),
      snapshot.overLimitPackages.join(','),
    ].join('|');

    if (key == _activeKey) return;

    final reasons = <String>[];
    if (snapshot.activeRules.isNotEmpty) {
      reasons.add('Schedule active');
    }
    if (snapshot.overLimitPackages.isNotEmpty) {
      reasons.add('Daily app limit reached');
    }

    final hasSponsor =
        (await SponsorService.instance.getCurrentSponsorProfile()) != null;

    await AppBlockingService.instance.startShield(
      blockedPackages: packages.toList(),
      reason: 'automation_rule',
      hasSponsor: hasSponsor,
      source: 'automation',
      strictModeOverride: snapshot.strictMode,
    );
    _activeKey = key;
  }
}
