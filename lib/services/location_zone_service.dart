import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/app_limit.dart';
import '../models/concentration_zone.dart';
import 'app_blocking_service.dart';
import 'storage_service.dart';
import 'sponsor_service.dart';

class ZoneState {
  const ZoneState({
    required this.enabled,
    required this.insideZone,
    this.zoneName,
    this.message,
    this.overrideActive = false,
  });

  final bool enabled;
  final bool insideZone;
  final String? zoneName;
  final String? message;
  final bool overrideActive;
}

class _ZoneConfigCache {
  const _ZoneConfigCache({
    required this.zones,
    required this.appLimits,
    required this.loadedAt,
  });

  final List<ConcentrationZone> zones;
  final List<AppLimit> appLimits;
  final DateTime loadedAt;
}

class LocationZoneService {
  LocationZoneService._();
  static final LocationZoneService instance = LocationZoneService._();

  static const Duration _configCacheTtl = Duration(seconds: 30);
  static const Duration _recentPositionTtl = Duration(seconds: 20);
  static const Duration _overrideCheckTtl = Duration(seconds: 15);
  static const double _nearZonePaddingMeters = 200;
  static const double _mediumZonePaddingMeters = 600;

  final StorageService _storageService = StorageService();
  final StreamController<ZoneState> _stateController =
  StreamController<ZoneState>.broadcast();

  StreamSubscription<Position>? _positionSub;
  ZoneState _currentState = const ZoneState(enabled: false, insideZone: false);
  bool _monitoring = false;
  Timer? _overrideTimer;

  _ZoneConfigCache? _configCache;
  Position? _lastPosition;
  DateTime? _lastPositionAt;
  DateTime? _lastOverrideCheckedAt;
  DateTime? _overrideUntilCache;
  String? _activeShieldKey;
  String? _lastMatchedZoneId;
  LocationAccuracy? _currentAccuracy;
  int? _currentDistanceFilter;

  Stream<ZoneState> get states => _stateController.stream;
  ZoneState get currentState => _currentState;

  Future<LocationPermission> ensurePermissions() async {
    if (kIsWeb) return LocationPermission.denied;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'Location services are disabled.',
      ));
      return LocationPermission.denied;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<void> startMonitoring() async {
    if (_monitoring) return;

    final config = await _loadConfig(force: true);
    if (config.zones.where((e) => e.enabled).isEmpty) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'No concentration zones enabled.',
      ));
      return;
    }

    final permission = await ensurePermissions();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'Location permission is needed for concentration zones.',
      ));
      return;
    }

    _monitoring = true;
    await _restartPositionStream(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 120,
    );

    try {
      final current = await Geolocator.getCurrentPosition();
      _rememberPosition(current);
      await _handlePosition(current, cachedConfig: config);
    } catch (_) {}
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    _overrideTimer?.cancel();
    _overrideTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _activeShieldKey = null;
    _lastMatchedZoneId = null;
    _currentAccuracy = null;
    _currentDistanceFilter = null;
    _overrideUntilCache = null;
    _lastOverrideCheckedAt = null;
    _emit(const ZoneState(enabled: false, insideZone: false));
  }

  Future<void> refresh() async {
    try {
      final config = await _loadConfig(force: true);
      if (config.zones.where((e) => e.enabled).isEmpty) {
        await stopMonitoring();
        await AppBlockingService.instance.stopShield();
        return;
      }

      if (!_monitoring) {
        await startMonitoring();
        return;
      }

      final recent = _getRecentPosition();
      if (recent != null) {
        await _handlePosition(recent, cachedConfig: config);
        return;
      }

      final current = await Geolocator.getCurrentPosition();
      _rememberPosition(current);
      await _handlePosition(current, cachedConfig: config);
    } catch (_) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'Concentration zones were reset after an error.',
      ));
      await stopMonitoring();
      await AppBlockingService.instance.stopShield();
    }
  }

  Future<void> _restartPositionStream({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) async {
    if (_currentAccuracy == accuracy &&
        _currentDistanceFilter == distanceFilter &&
        _positionSub != null) {
      return;
    }

    _currentAccuracy = accuracy;
    _currentDistanceFilter = distanceFilter;

    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen((position) async {
      _rememberPosition(position);
      await _handlePosition(position);
    });
  }

  Future<_ZoneConfigCache> _loadConfig({bool force = false}) async {
    final now = DateTime.now();
    final cache = _configCache;
    if (!force &&
        cache != null &&
        now.difference(cache.loadedAt) <= _configCacheTtl) {
      return cache;
    }

    final zones = await _storageService.loadConcentrationZones();
    final appLimits = await _storageService.loadAppLimits();
    final next = _ZoneConfigCache(
      zones: zones,
      appLimits: appLimits,
      loadedAt: now,
    );
    _configCache = next;
    return next;
  }

  Position? _getRecentPosition() {
    final lastAt = _lastPositionAt;
    final last = _lastPosition;
    if (lastAt == null || last == null) return null;
    if (DateTime.now().difference(lastAt) > _recentPositionTtl) return null;
    return last;
  }

  void _rememberPosition(Position position) {
    _lastPosition = position;
    _lastPositionAt = DateTime.now();
  }

  Future<void> _handlePosition(
      Position position, {
        _ZoneConfigCache? cachedConfig,
      }) async {
    try {
      final config = cachedConfig ?? await _loadConfig();
      final enabledZones = config.zones.where((e) => e.enabled).toList();
      if (enabledZones.isEmpty) {
        _activeShieldKey = null;
        _lastMatchedZoneId = null;
        _emit(const ZoneState(enabled: false, insideZone: false));
        await AppBlockingService.instance.stopShield();
        return;
      }

      final evaluation = _evaluateZones(position, enabledZones);
      await _applyAdaptiveLocationSettings(evaluation.nearestEdgeDistanceMeters);

      final matched = evaluation.matchedZone;
      if (matched != null) {
        final overrideActive = await _hasActiveZoneOverride();
        if (overrideActive) {
          _scheduleOverrideRefresh();
          if (_activeShieldKey != null) {
            await AppBlockingService.instance.stopShield();
            _activeShieldKey = null;
          }
          _lastMatchedZoneId = matched.id;
          _emit(ZoneState(
            enabled: true,
            insideZone: false,
            zoneName: matched.name,
            overrideActive: true,
            message: 'Sponsor override active in ${matched.name}.',
          ));
          return;
        }

        _overrideTimer?.cancel();
        _overrideTimer = null;
        _overrideUntilCache = null;

        final packages = _resolvePackagesForZone(matched, config.appLimits);
        final shieldKey = _buildShieldKey(matched.id, packages);
        final hasSponsor = await SponsorService.instance.hasSponsor();

        if (packages.isNotEmpty && shieldKey != _activeShieldKey) {
          await AppBlockingService.instance.startShield(
            blockedPackages: packages,
            reason: 'Study zone: ${matched.name}',
            hasSponsor: hasSponsor,
          );
          _activeShieldKey = shieldKey;
        } else if (packages.isEmpty && _activeShieldKey != null) {
          await AppBlockingService.instance.stopShield();
          _activeShieldKey = null;
        }

        _lastMatchedZoneId = matched.id;
        _emit(ZoneState(
          enabled: true,
          insideZone: true,
          zoneName: matched.name,
          message: packages.isEmpty
              ? 'You are in ${matched.name}, but no apps are selected for this zone.'
              : 'Educational focus is active in ${matched.name}.',
        ));
      } else {
        if (_activeShieldKey != null) {
          await AppBlockingService.instance.stopShield();
          _activeShieldKey = null;
        }
        _lastMatchedZoneId = null;
        _emit(const ZoneState(
          enabled: true,
          insideZone: false,
          message: 'You are outside concentration zones.',
        ));
      }
    } catch (_) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'Zone automation was paused after an error.',
      ));
      await AppBlockingService.instance.stopShield();
      _activeShieldKey = null;
    }
  }

  Future<void> _applyAdaptiveLocationSettings(double nearestEdgeDistanceMeters) async {
    if (!_monitoring) return;

    if (nearestEdgeDistanceMeters <= _nearZonePaddingMeters) {
      await _restartPositionStream(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      );
      return;
    }

    if (nearestEdgeDistanceMeters <= _mediumZonePaddingMeters) {
      await _restartPositionStream(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 60,
      );
      return;
    }

    await _restartPositionStream(
      accuracy: LocationAccuracy.low,
      distanceFilter: 120,
    );
  }

  Future<bool> _hasActiveZoneOverride() async {
    final now = DateTime.now();
    final cachedUntil = _overrideUntilCache;
    final checkedAt = _lastOverrideCheckedAt;

    if (cachedUntil != null && cachedUntil.isAfter(now)) {
      return true;
    }

    if (checkedAt != null && now.difference(checkedAt) < _overrideCheckTtl) {
      return false;
    }

    final until = await SponsorService.instance.getZoneOverrideUntil();
    _lastOverrideCheckedAt = now;
    _overrideUntilCache = until;
    return until != null && until.isAfter(now);
  }

  List<String> _resolvePackagesForZone(
      ConcentrationZone zone,
      List<AppLimit> appLimits,
      ) {
    if (zone.blockedPackages.isNotEmpty) {
      return zone.blockedPackages.toSet().toList()..sort();
    }
    final packages = appLimits
        .where((e) => e.useInFocusMode && (e.packageName?.isNotEmpty ?? false))
        .map((AppLimit e) => e.packageName!)
        .toSet()
        .toList();
    packages.sort();
    return packages;
  }

  String _buildShieldKey(String zoneId, List<String> packages) {
    return '$zoneId|${packages.join(',')}';
  }

  void _scheduleOverrideRefresh() {
    _overrideTimer?.cancel();
    SponsorService.instance.getZoneOverrideUntil().then((until) {
      _overrideUntilCache = until;
      _lastOverrideCheckedAt = DateTime.now();
      if (until == null) return;
      final delay = until.difference(DateTime.now()).inMilliseconds;
      final safeDelay = delay < 0 ? 0 : delay + 750;
      _overrideTimer = Timer(Duration(milliseconds: safeDelay), () async {
        try {
          await refresh();
        } catch (_) {}
      });
    }).catchError((_) {});
  }

  _ZoneEvaluation _evaluateZones(
      Position position,
      List<ConcentrationZone> zones,
      ) {
    ConcentrationZone? matchedZone;
    var nearestEdgeDistanceMeters = double.infinity;

    for (final zone in zones) {
      final meters = _distanceMeters(
        position.latitude,
        position.longitude,
        zone.latitude,
        zone.longitude,
      );
      final edgeDistance = max(0.0, meters - zone.radiusMeters);
      if (edgeDistance < nearestEdgeDistanceMeters) {
        nearestEdgeDistanceMeters = edgeDistance;
      }
      if (matchedZone == null && meters <= zone.radiusMeters) {
        matchedZone = zone;
      }
    }

    if (nearestEdgeDistanceMeters == double.infinity) {
      nearestEdgeDistanceMeters = _mediumZonePaddingMeters + 1;
    }

    return _ZoneEvaluation(
      matchedZone: matchedZone,
      nearestEdgeDistanceMeters: nearestEdgeDistanceMeters,
    );
  }

  void _emit(ZoneState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  double _distanceMeters(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180.0;
}

class _ZoneEvaluation {
  const _ZoneEvaluation({
    required this.matchedZone,
    required this.nearestEdgeDistanceMeters,
  });

  final ConcentrationZone? matchedZone;
  final double nearestEdgeDistanceMeters;
}
