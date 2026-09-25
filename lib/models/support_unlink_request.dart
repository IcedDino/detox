import 'package:cloud_firestore/cloud_firestore.dart';

class SupportUnlinkRequest {
  const SupportUnlinkRequest({
    required this.id,
    required this.status,
    this.message,
    this.replyMessage,
    this.createdAt,
    this.decidedAt,
  });

  factory SupportUnlinkRequest.fromDoc(String id, Map<String, dynamic> data) {
    return SupportUnlinkRequest(
      id: id,
      status: data['status'] as String? ?? 'pending',
      message: (data['message'] as String?)?.trim(),
      replyMessage: (data['replyMessage'] as String?)?.trim(),
      createdAt: ((data['createdAt'] ?? data['updatedAt']) as Timestamp?)
          ?.toDate(),
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String status;
  final String? message;
  final String? replyMessage;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get hasMessage => message != null && message!.isNotEmpty;
  bool get hasReply => replyMessage != null && replyMessage!.isNotEmpty;
}
