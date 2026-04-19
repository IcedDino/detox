import 'app_metadata_service.dart';

class AppVisibilityFilterService {
  AppVisibilityFilterService._();

  static final AppVisibilityFilterService instance =
  AppVisibilityFilterService._();

  static const Set<String> _blockedPackages = {
    'com.android.packageinstaller',
    'com.google.android.packageinstaller',
    'com.android.permissioncontroller',
    'com.google.android.permissioncontroller',
    'com.android.systemui',
    'com.android.settings',
    'com.android.launcher3',
    'com.hihonor.android.launcher',
    'com.huawei.android.launcher',
    'com.google.android.apps.nexuslauncher',
    'com.sec.android.app.launcher',
    'com.miui.home',
    'com.android.vending',
    'com.google.android.gms',
    'com.google.android.gsf',
    'com.google.android.ext.services',
    'com.google.android.ondevicepersonalization.services',
    'com.iceddino.detox',
  };

  static const List<String> _blockedLabelFragments = [
    'instalador de paquetes',
    'package installer',
    'controlador de permisos',
    'permission controller',
    'system ui',
    'inicio honor',
    'launcher',
    'pixel launcher',
    'google play store',
    'play store',
    'ajustes',
    'settings',
    'servicios de google play',
    'google play services',
    'google services framework',
    'Detox',
  ];

  Future<bool> shouldShowApp({
    required String packageName,
    String? resolvedLabel,
  }) async {
    final normalizedPackage = packageName.trim().toLowerCase();
    if (normalizedPackage.isEmpty) return false;

    if (_blockedPackages.contains(normalizedPackage)) {
      return false;
    }

    final label = (resolvedLabel?.trim().isNotEmpty ?? false)
        ? resolvedLabel!.trim()
        : (await AppMetadataService.instance.getLabel(packageName) ?? '').trim();

    if (label.isNotEmpty) {
      final normalizedLabel = label.toLowerCase();
      for (final fragment in _blockedLabelFragments) {
        if (normalizedLabel.contains(fragment)) {
          return false;
        }
      }
    }

    return true;
  }
}