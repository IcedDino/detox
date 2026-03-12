import 'dart:convert';

class AppLimit {
  AppLimit({
    required this.appName,
    required this.minutes,
    this.packageName,
    this.useInFocusMode = true,
  });

  final String appName;
  final int minutes;
  final String? packageName;
  final bool useInFocusMode;

  AppLimit copyWith({
    String? appName,
    int? minutes,
    String? packageName,
    bool? useInFocusMode,
  }) {
    return AppLimit(
      appName: appName ?? this.appName,
      minutes: minutes ?? this.minutes,
      packageName: packageName ?? this.packageName,
      useInFocusMode: useInFocusMode ?? this.useInFocusMode,
    );
  }

  Map<String, dynamic> toMap() => {
        'appName': appName,
        'minutes': minutes,
        'packageName': packageName,
        'useInFocusMode': useInFocusMode,
      };

  factory AppLimit.fromMap(Map<String, dynamic> map) => AppLimit(
        appName: map['appName'] as String,
        minutes: map['minutes'] as int,
        packageName: map['packageName'] as String?,
        useInFocusMode: map['useInFocusMode'] as bool? ?? true,
      );

  String toJson() => jsonEncode(toMap());

  factory AppLimit.fromJson(String source) =>
      AppLimit.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
