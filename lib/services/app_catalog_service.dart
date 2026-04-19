import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../models/installed_app_entry.dart';
import 'app_metadata_service.dart';
import 'app_visibility_filter_service.dart';

class AppCatalogService {
  static List<InstalledAppEntry>? _cache;

  Future<List<InstalledAppEntry>> loadInstalledApps() async {
    if (_cache != null) return _cache!;

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

      for (final AppInfo app in apps) {
        final entry = InstalledAppEntry(
          name: app.name,
          packageName: app.packageName,
        );

        final allowed = await AppVisibilityFilterService.instance.shouldShowApp(
          packageName: entry.packageName,
          resolvedLabel: entry.name,
        );

        if (allowed) {
          visible.add(entry);
        }
      }

      final popularPackages = <String, String>{
        'com.facebook.katana': 'Facebook',
        'com.facebook.orca': 'Messenger',
        'com.instagram.android': 'Instagram',
        'com.whatsapp': 'WhatsApp',
        'com.zhiliaoapp.musically': 'TikTok',
        'com.google.android.youtube': 'YouTube',
        'com.android.chrome': 'Chrome',
        'com.twitter.android': 'X',
        'com.snapchat.android': 'Snapchat',
      };

      final knownPackages = visible.map((e) => e.packageName).toSet();

      for (final entry in popularPackages.entries) {
        if (knownPackages.contains(entry.key)) continue;

        final label = await AppMetadataService.instance.getLabel(entry.key);
        final resolvedName = (label != null && label.trim().isNotEmpty)
            ? label.trim()
            : entry.value;

        final allowed = await AppVisibilityFilterService.instance.shouldShowApp(
          packageName: entry.key,
          resolvedLabel: resolvedName,
        );

        if (!allowed) continue;

        visible.add(
          InstalledAppEntry(
            name: resolvedName,
            packageName: entry.key,
          ),
        );
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

    final out = <InstalledAppEntry>[];
    for (final app in apps) {
      final icon = await AppMetadataService.instance.getIcon(app.packageName);
      out.add(app.copyWith(iconBytes: icon));
    }
    return out;
  }

  static void clearCache() {
    _cache = null;
  }
}