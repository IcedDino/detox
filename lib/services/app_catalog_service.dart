import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../models/installed_app_entry.dart';
import 'app_metadata_service.dart';
import 'app_visibility_filter_service.dart';

class AppCatalogService {
  static List<InstalledAppEntry>? _cache;
  static Future<List<InstalledAppEntry>>? _loadFuture;

  Future<List<InstalledAppEntry>> loadInstalledApps() {
    if (_cache != null) return Future.value(_cache!);
    final pending = _loadFuture;
    if (pending != null) return pending;

    late final Future<List<InstalledAppEntry>> future;
    future = _loadInstalledAppsInternal().whenComplete(() {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    });
    _loadFuture = future;
    return future;
  }

  Future<List<InstalledAppEntry>> _loadInstalledAppsInternal() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _cache = const [
        InstalledAppEntry(name: 'Instagram', packageName: 'com.instagram.android'),
        InstalledAppEntry(name: 'TikTok', packageName: 'com.zhiliaoapp.musically'),
        InstalledAppEntry(name: 'YouTube', packageName: 'com.google.android.youtube'),
        InstalledAppEntry(name: 'WhatsApp', packageName: 'com.whatsapp'),
        InstalledAppEntry(name: 'Chrome', packageName: 'com.android.chrome'),
        InstalledAppEntry(name: 'Facebook', packageName: 'com.facebook.katana'),
        InstalledAppEntry(name: 'X', packageName: 'com.twitter.android'),
      ];
      return _cache!;
    }

    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );

      final visible = <InstalledAppEntry>[];
      final addedPackages = <String>{};

      for (final AppInfo app in apps) {
        final packageName = app.packageName.trim();
        final appName = app.name.trim();

        if (packageName.isEmpty || appName.isEmpty) {
          continue;
        }

        if (addedPackages.contains(packageName)) {
          continue;
        }

        if (!AppVisibilityFilterService.instance.shouldShowPackageName(
          packageName,
        )) {
          continue;
        }

        if (!AppVisibilityFilterService.instance.shouldShowResolvedLabel(
          appName,
        )) {
          continue;
        }

        visible.add(
          InstalledAppEntry(
            name: appName,
            packageName: packageName,
          ),
        );
        addedPackages.add(packageName);
      }

      visible.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _cache = visible;
      return visible;
    } catch (_) {
      _cache = const [];
      return _cache!;
    }
  }

  Future<List<InstalledAppEntry>> hydrateVisibleIcons(
    List<InstalledAppEntry> apps,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return apps;

    return Future.wait(
      apps.map((app) async {
        final icon = await AppMetadataService.instance.getIcon(app.packageName);
        return app.copyWith(iconBytes: icon);
      }),
    );
  }

  static void clearCache() {
    _cache = null;
    _loadFuture = null;
  }
}
