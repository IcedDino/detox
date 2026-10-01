import 'package:firebase_messaging/firebase_messaging.dart';

class SponsorPushNotice {
  const SponsorPushNotice({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;

  static SponsorPushNotice? fromMessage(RemoteMessage message) {
    if (message.data['type'] != 'sponsor') return null;
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return null;
    }
    final key = message.messageId ?? '$title:$body';
    return SponsorPushNotice(
      id: key.hashCode & 0x7fffffff,
      title: title,
      body: body,
    );
  }
}
