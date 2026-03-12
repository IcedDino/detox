import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/app_metadata_service.dart';
import '../theme/app_theme.dart';

class AppIconBadge extends StatefulWidget {
  const AppIconBadge({
    super.key,
    this.packageName,
    this.iconBytes,
    this.size = 42,
    this.borderRadius,
    this.fallbackIcon = Icons.apps_rounded,
  });

  final String? packageName;
  final Uint8List? iconBytes;
  final double size;
  final double? borderRadius;
  final IconData fallbackIcon;

  @override
  State<AppIconBadge> createState() => _AppIconBadgeState();
}

class _AppIconBadgeState extends State<AppIconBadge> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.iconBytes;
    _load();
  }

  @override
  void didUpdateWidget(covariant AppIconBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName || oldWidget.iconBytes != widget.iconBytes) {
      _bytes = widget.iconBytes;
      _load();
    }
  }

  Future<void> _load() async {
    if (_bytes != null || widget.packageName == null || widget.packageName!.isEmpty) return;
    final bytes = await AppMetadataService.instance.getIcon(widget.packageName);
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius ?? widget.size * 0.28);
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: DetoxColors.accent.withOpacity(0.16),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: _bytes == null
          ? Icon(widget.fallbackIcon, color: DetoxColors.accentSoft, size: widget.size * 0.52)
          : Image.memory(_bytes!, fit: BoxFit.cover),
    );
  }
}
