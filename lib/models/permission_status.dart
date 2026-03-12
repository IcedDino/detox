class PermissionStatusModel {
  const PermissionStatusModel({
    required this.usageReady,
    required this.platformMessage,
  });

  final bool usageReady;
  final String platformMessage;
}
