import 'dart:typed_data';

class InstalledAppEntry {
  const InstalledAppEntry({
    required this.name,
    required this.packageName,
    this.iconBytes,
  });

  final String name;
  final String packageName;
  final Uint8List? iconBytes;

  InstalledAppEntry copyWith({
    String? name,
    String? packageName,
    Uint8List? iconBytes,
  }) {
    return InstalledAppEntry(
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }
}
