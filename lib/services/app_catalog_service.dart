import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../models/installed_app_entry.dart';
import 'app_metadata_service.dart';

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
      final mapped = apps
          .map((AppInfo app) => InstalledAppEntry(name: app.name, packageName: app.packageName))
          .toList();

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

      final knownPackages = mapped.map((e) => e.packageName).toSet();
      for (final entry in popularPackages.entries) {
        if (knownPackages.contains(entry.key)) continue;
        final label = await AppMetadataService.instance.getLabel(entry.key);
        final resolvedName = (label != null && label.trim().isNotEmpty)
            ? label.trim()
            : entry.value;
        mapped.add(InstalledAppEntry(name: resolvedName, packageName: entry.key));
      }

      mapped.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _cache = mapped;
      return mapped;
    } catch (_) {
      _cache = const [];
      return _cache!;
    }
  }

  Future<List<InstalledAppEntry>> hydrateVisibleIcons(List<InstalledAppEntry> apps) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return apps;
    final out = <InstalledAppEntry>[];
    for (final app in apps) {
      final icon = await AppMetadataService.instance.getIcon(app.packageName);
      out.add(app.copyWith(iconBytes: icon));
    }
    return out;
  }
}
