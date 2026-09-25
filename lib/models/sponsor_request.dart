import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n_app_strings.dart';

class SponsorRequest {
  const SponsorRequest({
    required this.id,
    required this.requesterUid,
    required this.requesterName,
    required this.sponsorUid,
    required this.requestType,
    required this.status,
    required this.durationMinutes,
    this.code,
    this.createdAt,
    this.expiresAt,
    this.message,
    this.replyMessage,
  });

  final String id;
  final String requesterUid;
  final String requesterName;
  final String sponsorUid;
  final String requestType;
  final String status;
  final int durationMinutes;
  final String? code;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Optional note the requester writes to explain the request.
  final String? message;

  /// Optional answer the sponsor writes when accepting or denying.
  final String? replyMessage;

  bool get hasMessage => message != null && message!.trim().isNotEmpty;
  bool get hasReply => replyMessage != null && replyMessage!.trim().isNotEmpty;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isConsumed => status == 'consumed';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isEmailed => status == 'emailed';
  bool get isRejected => status == 'rejected';
  /// Human label for the request type, in the language the user chose.
  String get prettyType {
    final t = AppStrings.current;
    switch (requestType) {
      case 'settings_unlock':
        return t.requestTypeSettingsUnlock;
      case 'zone_override':
        return t.requestTypeZoneOverride;
      case 'shield_pause':
        return t.requestTypeShieldPause;
      case 'unlink_sponsor':
        return t.requestTypeUnlinkSponsor;
      case 'unlink_email':
        return t.requestTypeUnlinkEmail;
      default:
        return requestType;
    }
  }

  factory SponsorRequest.fromDoc(String id, Map<String, dynamic> map) {
    return SponsorRequest(
      id: id,
      requesterUid: map['requesterUid'] as String? ?? '',
      requesterName:
          map['requesterName'] as String? ?? AppStrings.current.defaultUserName,
      sponsorUid: map['sponsorUid'] as String? ?? '',
      requestType: map['requestType'] as String? ?? 'zone_override',
      status: map['status'] as String? ?? 'pending',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 15,
      code: map['code'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      message: (map['message'] as String?)?.trim(),
      replyMessage: (map['replyMessage'] as String?)?.trim(),
    );
  }
}
