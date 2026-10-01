import 'package:detox/services/sponsor_push_notice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a sponsor push with visible content creates a notice', () {
    final sponsor = RemoteMessage(
      messageId: 'event-123',
      data: const {'type': 'sponsor'},
      notification: const RemoteNotification(title: 'Detox', body: 'Solicitud'),
    );
    final notice = SponsorPushNotice.fromMessage(sponsor);
    expect(notice, isNotNull);
    expect(notice!.title, 'Detox');
    expect(notice.body, 'Solicitud');
    expect(notice.id, 'event-123'.hashCode & 0x7fffffff);

    expect(
      SponsorPushNotice.fromMessage(
        const RemoteMessage(
          data: {'type': 'other'},
          notification: RemoteNotification(title: 'Other', body: 'Message'),
        ),
      ),
      isNull,
    );
    expect(
      SponsorPushNotice.fromMessage(
        const RemoteMessage(data: {'type': 'sponsor'}),
      ),
      isNull,
    );
  });
}
