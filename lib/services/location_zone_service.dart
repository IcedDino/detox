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

class LocationZoneService {
  LocationZoneService._();
  static final LocationZoneService instance = LocationZoneService._();

  final StorageService _storageService = StorageService();
  final StreamController<ZoneState> _stateController =
      StreamController<ZoneState>.broadcast();

  StreamSubscription<Position>? _positionSub;
  ZoneState _currentState = const ZoneState(enabled: false, insideZone: false);
  bool _monitoring = false;

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
    final zones = await _storageService.loadConcentrationZones();
    if (zones.where((e) => e.enabled).isEmpty) {
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
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 50,
      ),
    ).listen((position) async {
      await _handlePosition(position);
    });

    try {
      final current = await Geolocator.getCurrentPosition();
      await _handlePosition(current);
    } catch (_) {}
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    await _positionSub?.cancel();
    _positionSub = null;
    _emit(const ZoneState(enabled: false, insideZone: false));
  }

  Future<void> refresh() async {
    try {
      final zones = await _storageService.loadConcentrationZones();
      if (zones.where((e) => e.enabled).isEmpty) {
        await stopMonitoring();
        await AppBlockingService.instance.stopShield();
        return;
      }
      if (!_monitoring) {
        await startMonitoring();
      } else {
        final current = await Geolocator.getCurrentPosition();
        await _handlePosition(current);
      }
    } catch (e) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'Concentration zones were reset after an error.',
      ));
      await stopMonitoring();
      await AppBlockingService.instance.stopShield();
    }
  }

  Future<void> _handlePosition(Position position) async {
    try {
      final zones = await _storageService.loadConcentrationZones();
      final enabledZones = zones.where((e) => e.enabled).toList();
      if (enabledZones.isEmpty) {
        _emit(const ZoneState(enabled: false, insideZone: false));
        await AppBlockingService.instance.stopShield();
        return;
      }

      ConcentrationZone? matched;
      for (final zone in enabledZones) {
        final meters = _distanceMeters(
          position.latitude,
          position.longitude,
          zone.latitude,
          zone.longitude,
        );
        if (meters <= zone.radiusMeters) {
          matched = zone;
          break;
        }
      }

      if (matched != null) {
        final overrideActive = await SponsorService.instance.hasActiveZoneOverride();
        if (overrideActive) {
          await AppBlockingService.instance.stopShield();
          _emit(ZoneState(
            enabled: true,
            insideZone: false,
            zoneName: matched.name,
            overrideActive: true,
            message: 'Sponsor override active in ${matched.name}.',
          ));
          return;
        }

        final appLimits = await _storageService.loadAppLimits();
        final packages = _resolvePackagesForZone(matched, appLimits);
        if (packages.isNotEmpty) {
          await AppBlockingService.instance.startShield(
            blockedPackages: packages,
            reason: 'Study zone: ${matched.name}',
          );
        }
        _emit(ZoneState(
          enabled: true,
          insideZone: true,
          zoneName: matched.name,
          message: packages.isEmpty
              ? 'You are in ${matched.name}, but no apps are selected for this zone.'
              : 'Educational focus is active in ${matched.name}.',
        ));
      } else {
        await AppBlockingService.instance.stopShield();
        _emit(const ZoneState(
          enabled: true,
          insideZone: false,
          message: 'You are outside concentration zones.',
        ));
      }
    } catch (e) {
      _emit(const ZoneState(
        enabled: false,
        insideZone: false,
        message: 'Zone automation was paused after an error.',
      ));
      await AppBlockingService.instance.stopShield();
    }
  }

  List<String> _resolvePackagesForZone(
    ConcentrationZone zone,
    List<AppLimit> appLimits,
  ) {
    if (zone.blockedPackages.isNotEmpty) {
      return zone.blockedPackages.toSet().toList();
    }
    return appLimits
        .where((e) => e.useInFocusMode && (e.packageName?.isNotEmpty ?? false))
        .map((AppLimit e) => e.packageName!)
        .toSet()
        .toList();
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
