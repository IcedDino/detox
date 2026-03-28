import 'package:cloud_firestore/cloud_firestore.dart';

class LinkRequest {
  const LinkRequest({
    required this.id,
    required this.requesterUid,
    required this.requesterName,
    required this.targetUid,
    required this.targetName,
    required this.status,
    this.createdAt,
    this.acceptedAt,
    this.rejectedAt,
    this.type = 'sponsor',
  });

  final String id;
  final String requesterUid;
  final String requesterName;
  final String targetUid;
  final String targetName;
  final String status;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String type;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  LinkRequest copyWith({
    String? id,
    String? requesterUid,
    String? requesterName,
    String? targetUid,
    String? targetName,
    String? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    String? type,
  }) {
    return LinkRequest(
      id: id ?? this.id,
      requesterUid: requesterUid ?? this.requesterUid,
      requesterName: requesterName ?? this.requesterName,
      targetUid: targetUid ?? this.targetUid,
      targetName: targetName ?? this.targetName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requesterUid': requesterUid,
      'requesterName': requesterName,
      'targetUid': targetUid,
      'targetName': targetName,
      'status': status,
      'type': type,
      'createdAt': createdAt == null
          ? null
          : Timestamp.fromDate(createdAt!),
      'acceptedAt': acceptedAt == null
          ? null
          : Timestamp.fromDate(acceptedAt!),
      'rejectedAt': rejectedAt == null
          ? null
          : Timestamp.fromDate(rejectedAt!),
    };
  }

  factory LinkRequest.fromMap(
      Map<String, dynamic> map, {
        required String id,
      }) {
    return LinkRequest(
      id: id,
      requesterUid: (map['requesterUid'] ?? '') as String,
      requesterName: (map['requesterName'] ?? '') as String,
      targetUid: (map['targetUid'] ?? '') as String,
      targetName: (map['targetName'] ?? '') as String,
      status: (map['status'] ?? 'pending') as String,
      type: (map['type'] ?? 'sponsor') as String,
      createdAt: _timestampToDateTime(map['createdAt']),
      acceptedAt: _timestampToDateTime(map['acceptedAt']),
      rejectedAt: _timestampToDateTime(map['rejectedAt']),
    );
  }

  factory LinkRequest.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};
    return LinkRequest.fromMap(data, id: doc.id);
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

}