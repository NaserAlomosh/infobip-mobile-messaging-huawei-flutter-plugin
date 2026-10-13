import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/user/user_codec.dart';
import 'package:infobip_mobilemessaging_huawei/src/inbox/inbox_codec.dart';

void main() {
  test('empty native cached user decodes to valid UserData', () {
    final user = UserCodec.decode(<String, Object?>{});
    expect(user, isA<UserData>());
    expect(user.externalUserId, isNull);
    expect(user.birthday, isNull);
  });

  test('birthday round trip keeps the calendar string', () {
    final encoded = UserCodec.encode(UserData(birthday: '1995-06-20'));
    expect(encoded['birthday'], '1995-06-20');
    expect(UserCodec.decode(encoded).birthday, '1995-06-20');
  });

  test(
    'CustomList records preserve native schema and values symmetrically',
    () {
      final attributes = <String, Object?>{
        'records': [
          {
            'name': 'one',
            'number': 1,
            'bool': true,
            'date': '1995-06-20',
            'optional': null,
          },
          {
            'name': 'two',
            'number': 2.5,
            'bool': false,
            'date': '2000-01-01',
            'optional': null,
          },
        ],
        'deleted': null,
      };
      expect(
        UserCodec.decodeCustomAttributes(
          UserCodec.encodeCustomAttributes(attributes),
        ),
        attributes,
      );
      for (final invalid in [
        <Object>[1],
        [
          {
            'nested': {'x': true},
          },
        ],
        [
          {
            'nested': [1],
          },
        ],
      ]) {
        expect(
          () => UserCodec.encodeCustomAttributes({'records': invalid}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'InboxMessage exposes all rich fields and never substitutes received time',
    () {
      final fields = <String, Object?>{
        'messageId': '1788547032704145206',
        'topic': 'news',
        'seen': true,
        'title': 'Title',
        'body': 'Body',
        'sound': 'Sound',
        'vibrate': true,
        'silent': false,
        'category': 'category',
        'customPayload': {'x': true},
        'internalData': '{}',
        'contentUrl': 'content',
        'browserUrl': 'browser',
        'deeplink': 'deeplink',
        'webViewUrl': 'webview',
        'inAppOpenTitle': 'Open',
        'inAppDismissTitle': 'Dismiss',
        'sentTimestamp': 111,
        'receivedTimestamp': 222,
      };
      final message = InboxCodec.decode({
        'messages': [fields],
      }).messages.single;
      expect(message, isA<InboxMessage>());
      expect(message.messageId, '1788547032704145206');
      expect(message.topic, 'news');
      expect(message.seen, true);
      expect(message.title, 'Title');
      expect(message.body, 'Body');
      expect(message.sound, 'Sound');
      expect(message.vibrate, true);
      expect(message.silent, false);
      expect(message.category, 'category');
      expect(message.customPayload, {'x': true});
      expect(message.internalData, '{}');
      expect(message.contentUrl, 'content');
      expect(message.browserUrl, 'browser');
      expect(message.deeplink, 'deeplink');
      expect(message.webViewUrl, 'webview');
      expect(message.inAppOpenTitle, 'Open');
      expect(message.inAppDismissTitle, 'Dismiss');
      expect(message.sentTimestamp, 111);
      expect(message.receivedTimestamp, 222);
      expect(message.originalPayload, isNull);
      fields.remove('sentTimestamp');
      final absent = InboxCodec.decode({
        'messages': [fields],
      }).messages.single;
      expect(absent.sentTimestamp, isNull);
    },
  );
}
