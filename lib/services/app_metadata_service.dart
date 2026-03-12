import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppMetadataService {
  AppMetadataService._();

  static final AppMetadataService instance = AppMetadataService._();
  static const MethodChannel _channel = MethodChannel('detox/device_control');

  final Map<String, Uint8List?> _iconCache = <String, Uint8List?>{};
  final Map<String, String> _labelCache = <String, String>{};

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Uint8List?> getIcon(String? packageName) async {
    if (!_isAndroid || packageName == null || packageName.isEmpty) return null;
    if (_iconCache.containsKey(packageName)) return _iconCache[packageName];
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      _iconCache[packageName] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('getIcon error for $packageName: $e');
      _iconCache[packageName] = null;
      return null;
    }
  }

  Future<String?> getLabel(String? packageName) async {
    if (!_isAndroid || packageName == null || packageName.isEmpty) return null;
    if (_labelCache.containsKey(packageName)) return _labelCache[packageName];
    try {
      final label = await _channel.invokeMethod<String>('getAppLabel', {
        'packageName': packageName,
      });
      if (label != null && label.trim().isNotEmpty) {
        _labelCache[packageName] = label;
      }
      return label;
    } catch (e) {
      debugPrint('getLabel error for $packageName: $e');
      return null;
    }
  }
}
