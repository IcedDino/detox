/// A scheduled automation rule that blocks a set of apps during a time window.
class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.blockedPackages,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
    this.strictMode = false,
    this.onlyInsideZone = false,
  });

  final String id;
  final String name;

  /// Start of the blocking window in minutes since midnight (local time).
  final int startMinuteOfDay;

  /// End of the blocking window in minutes since midnight (local time).
  /// May be smaller than [startMinuteOfDay] for overnight windows
  /// (e.g. 22:00 -> 07:00).
  final int endMinuteOfDay;

  /// Weekdays when the rule applies. Uses [DateTime.weekday] values:
  /// Monday = 1 ... Sunday = 7.
  final List<int> weekdays;

  final List<String> blockedPackages;
  final bool enabled;
  final bool strictMode;

  /// When true, the rule only applies while the user is inside a
  /// concentration zone.
  final bool onlyInsideZone;

  AutomationRule copyWith({
    String? id,
    String? name,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    List<int>? weekdays,
    List<String>? blockedPackages,
    bool? enabled,
    bool? strictMode,
    bool? onlyInsideZone,
  }) {
    return AutomationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      weekdays: weekdays ?? this.weekdays,
      blockedPackages: blockedPackages ?? this.blockedPackages,
      enabled: enabled ?? this.enabled,
      strictMode: strictMode ?? this.strictMode,
      onlyInsideZone: onlyInsideZone ?? this.onlyInsideZone,
    );
  }

  bool appliesAt(DateTime now, {required bool insideZone}) {
    if (!enabled) return false;
    if (onlyInsideZone && !insideZone) return false;
    if (!weekdays.contains(now.weekday)) return false;

    final minuteOfDay = now.hour * 60 + now.minute;
    if (startMinuteOfDay <= endMinuteOfDay) {
      return minuteOfDay >= startMinuteOfDay && minuteOfDay < endMinuteOfDay;
    }
    // Overnight window (e.g. 22:00 -> 07:00).
    return minuteOfDay >= startMinuteOfDay || minuteOfDay < endMinuteOfDay;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'startMinuteOfDay': startMinuteOfDay,
      'endMinuteOfDay': endMinuteOfDay,
      'weekdays': weekdays,
      'blockedPackages': blockedPackages,
      'enabled': enabled,
      'strictMode': strictMode,
      'onlyInsideZone': onlyInsideZone,
    };
  }

  factory AutomationRule.fromJson(Map<String, dynamic> map) {
    return AutomationRule(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Schedule',
      startMinuteOfDay: (map['startMinuteOfDay'] as num?)?.toInt() ?? 0,
      endMinuteOfDay: (map['endMinuteOfDay'] as num?)?.toInt() ?? 0,
      weekdays: (map['weekdays'] as List<dynamic>?)
              ?.whereType<num>()
              .map((e) => e.toInt())
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      blockedPackages: (map['blockedPackages'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      enabled: (map['enabled'] as bool?) ?? true,
      strictMode: (map['strictMode'] as bool?) ?? false,
      onlyInsideZone: (map['onlyInsideZone'] as bool?) ?? false,
    );
  }
}
