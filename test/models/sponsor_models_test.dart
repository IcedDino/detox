import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:detox/models/link_requests.dart';
import 'package:detox/models/sponsor_profile.dart';
import 'package:detox/models/sponsor_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SponsorProfile.fromUserDoc', () {
    test('uses displayName when present', () {
      final profile = SponsorProfile.fromUserDoc('u1', <String, dynamic>{
        'sponsorCode': 'ABCD12',
        'profile': <String, dynamic>{
          'displayName': 'Tutor',
          'email': 'tutor@example.com',
        },
      });

      expect(profile.uid, 'u1');
      expect(profile.displayName, 'Tutor');
      expect(profile.email, 'tutor@example.com');
      expect(profile.code, 'ABCD12');
    });

    test('falls back to email or a generic name', () {
      final fromEmail = SponsorProfile.fromUserDoc('u2', <String, dynamic>{
        'profile': <String, dynamic>{'email': 'fallback@example.com'},
      });
      final generic = SponsorProfile.fromUserDoc('u3', const <String, dynamic>{});

      expect(fromEmail.displayName, 'fallback@example.com');
      expect(generic.displayName, 'Detox user');
      expect(generic.code, isEmpty);
    });
  });

  group('LinkRequest mapping', () {
    test('accepts Timestamp and preserves ids and state flags', () {
      final createdAt = DateTime(2026, 4, 18, 9, 30);
      final acceptedAt = DateTime(2026, 4, 18, 10, 0);

      final request = LinkRequest.fromMap(
        <String, dynamic>{
          'requesterUid': 'child',
          'requesterName': 'Child',
          'targetUid': 'sponsor',
          'targetName': 'Sponsor',
          'status': 'accepted',
          'type': 'sponsor',
          'createdAt': Timestamp.fromDate(createdAt),
          'acceptedAt': acceptedAt,
        },
        id: 'req-1',
      );

      expect(request.id, 'req-1');
      expect(request.isAccepted, isTrue);
      expect(request.isPending, isFalse);
      expect(request.createdAt, createdAt);
      expect(request.acceptedAt, acceptedAt);
      expect(request.rejectedAt, isNull);

      final map = request.toMap();
      expect(map['status'], 'accepted');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['acceptedAt'], isA<Timestamp>());
    });
  });

  group('SponsorRequest', () {
    test('maps known pretty labels and expiration state', () {
      final request = SponsorRequest.fromDoc('unlock-1', <String, dynamic>{
        'requesterUid': 'child',
        'requesterName': 'Child',
        'sponsorUid': 'sponsor',
        'requestType': 'shield_pause',
        'status': 'approved',
        'durationMinutes': 15,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });

      expect(request.prettyType, 'App shield pause');
      expect(request.isApproved, isTrue);
      expect(request.isExpired, isTrue);
      expect(request.isPending, isFalse);
    });

    test('falls back safely when optional fields are missing', () {
      final request = SponsorRequest.fromDoc('unlock-2', const <String, dynamic>{});

      expect(request.requesterName, 'Detox user');
      expect(request.requestType, 'zone_override');
      expect(request.status, 'pending');
      expect(request.durationMinutes, 15);
      expect(request.code, isNull);
      expect(request.createdAt, isNull);
      expect(request.expiresAt, isNull);
    });
  });
}
