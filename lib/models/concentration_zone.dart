import 'dart:convert';

class ConcentrationZone {
  const ConcentrationZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.enabled = true,
    this.blockedPackages = const [],
    this.blockedAppNames = const [],
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool enabled;
  final List<String> blockedPackages;
  final List<String> blockedAppNames;

  ConcentrationZone copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? enabled,
    List<String>? blockedPackages,
    List<String>? blockedAppNames,
  }) {
    return ConcentrationZone(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      enabled: enabled ?? this.enabled,
      blockedPackages: blockedPackages ?? this.blockedPackages,
      blockedAppNames: blockedAppNames ?? this.blockedAppNames,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'enabled': enabled,
        'blockedPackages': blockedPackages,
        'blockedAppNames': blockedAppNames,
      };

  factory ConcentrationZone.fromMap(Map<String, dynamic> map) => ConcentrationZone(
        id: map['id'] as String,
        name: map['name'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radiusMeters'] as num).toDouble(),
        enabled: map['enabled'] as bool? ?? true,
        blockedPackages: (map['blockedPackages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const [],
        blockedAppNames: (map['blockedAppNames'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const [],
      );

  String toJson() => jsonEncode(toMap());

  factory ConcentrationZone.fromJson(String source) =>
      ConcentrationZone.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
