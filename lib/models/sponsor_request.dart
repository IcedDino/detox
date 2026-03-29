import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isConsumed => status == 'consumed';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isEmailed => status == 'emailed';
  bool get isRejected => status == 'rejected';
  String get prettyType {
    switch (requestType) {
      case 'settings_unlock':
        return 'Settings changes';
      case 'zone_override':
        return 'Zone pause';
      case 'unlink_sponsor':
        return 'Sponsor unlink';
      case 'unlink_email':
        return 'Email unlink';
      default:
        return requestType;
    }
  }

  factory SponsorRequest.fromDoc(String id, Map<String, dynamic> map) {
    return SponsorRequest(
      id: id,
      requesterUid: map['requesterUid'] as String? ?? '',
      requesterName: map['requesterName'] as String? ?? 'Detox user',
      sponsorUid: map['sponsorUid'] as String? ?? '',
      requestType: map['requestType'] as String? ?? 'zone_override',
      status: map['status'] as String? ?? 'pending',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 15,
      code: map['code'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}
