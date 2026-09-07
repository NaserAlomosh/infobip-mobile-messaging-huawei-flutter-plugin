import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/inbox/inbox_codec.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodes filters as UTC instants and preserves absent filters', () {
    expect(InboxCodec.encodeOptions(null), isNull);
    final encoded = InboxCodec.encodeOptions(
      InboxFilterOptions(
        from: DateTime.parse('2026-09-01T15:00:00+03:00'),
        to: DateTime.parse('2026-09-02T12:00:00Z'),
        topics: const ['offers', 'news'],
        limit: 20,
      ),
    );
    expect(encoded, {
      'from': '2026-09-01T12:00:00.000Z',
      'to': '2026-09-02T12:00:00.000Z',
      'topic': null,
      'topics': ['offers', 'news'],
      'limit': 20,
    });
  });

  test('rejects invalid filters', () {
    expect(
      () => InboxCodec.encodeOptions(
        InboxFilterOptions(
          from: DateTime.utc(2026, 2),
          to: DateTime.utc(2026, 1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => InboxCodec.encodeOptions(const InboxFilterOptions(topic: ' ')),
      throwsArgumentError,
    );
    expect(
      () => InboxCodec.encodeOptions(const InboxFilterOptions(limit: 0)),
      throwsArgumentError,
    );
  });

  test('decodes Inbox counters, messages, timestamp, and nested payload', () {
    final inbox = InboxCodec.decode({
      'countTotal': 4,
      'countUnread': 2,
      'countTotalFiltered': 3,
      'countUnreadFiltered': 1,
      'messages': [
        {
          'messageId': 'message-1',
          'title': 'Title',
          'body': 'Body',
          'topic': 'news',
          'seen': false,
          'receivedTimestamp': 1788264000000,
          'customPayload': {
            'nested': {'enabled': true},
          },
          'deeplink': 'app://inbox',
          'silent': true,
        },
      ],
    });
    expect(inbox.countTotal, 4);
    expect(inbox.countUnread, 2);
    expect(inbox.countTotalFiltered, 3);
    expect(inbox.countUnreadFiltered, 1);
    expect(inbox.messages.single.messageId, 'message-1');
    expect(inbox.messages.single.receivedTimestamp, 1788264000000);
    expect(inbox.messages.single.customPayload?['nested'], {'enabled': true});
    expect(inbox.messages.single.seen, isFalse);
    expect(inbox.messages.single.silent, isTrue);
  });

  test('rejects conflicting or invalid topic filters', () {
    expect(
      () => InboxCodec.encodeOptions(
        const InboxFilterOptions(topic: 'one', topics: ['two']),
      ),
      throwsArgumentError,
    );
    expect(
      () => InboxCodec.encodeOptions(const InboxFilterOptions(topics: [])),
      throwsArgumentError,
    );
    expect(
      () => InboxCodec.encodeOptions(const InboxFilterOptions(topics: [' '])),
      throwsArgumentError,
    );
  });

  test('rejects invalid Inbox identity and message identifiers', () {
    expect(
      () => InfobipMobileMessagingHuawei.fetchInbox(externalUserId: ' '),
      throwsArgumentError,
    );
    expect(
      () => InfobipMobileMessagingHuawei.setInboxMessagesSeen(
        externalUserId: '',
        messageIds: const ['one'],
      ),
      throwsArgumentError,
    );
    expect(
      () => InfobipMobileMessagingHuawei.setInboxMessagesSeen(
        externalUserId: 'user',
        messageIds: const [' '],
      ),
      throwsArgumentError,
    );
  });

  test('decodes null native messages as an empty list', () {
    final inbox = InboxCodec.decode({
      'countTotal': 0,
      'countUnread': 0,
      'countTotalFiltered': 0,
      'countUnreadFiltered': 0,
      'messages': null,
    });

    expect(inbox.messages, isEmpty);
  });

  test('decodes a null native Inbox as an empty Inbox', () {
    final inbox = InboxCodec.decode(null);

    expect(inbox.countTotal, 0);
    expect(inbox.countUnread, 0);
    expect(inbox.countTotalFiltered, 0);
    expect(inbox.countUnreadFiltered, 0);
    expect(inbox.messages, isEmpty);
  });

  test('decodes null Inbox counts as zero', () {
    final inbox = InboxCodec.decode({
      'countTotal': null,
      'countUnread': null,
      'countTotalFiltered': null,
      'countUnreadFiltered': null,
      'messages': const [],
    });

    expect(inbox.countTotal, 0);
    expect(inbox.countUnread, 0);
    expect(inbox.countTotalFiltered, 0);
    expect(inbox.countUnreadFiltered, 0);
  });

  test('converts numeric Inbox counts to integers', () {
    final inbox = InboxCodec.decode({
      'countTotal': 4.0,
      'countUnread': 2.0,
      'countTotalFiltered': 3.0,
      'countUnreadFiltered': 1.0,
      'messages': const [],
    });

    expect(inbox.countTotal, 4);
    expect(inbox.countUnread, 2);
    expect(inbox.countTotalFiltered, 3);
    expect(inbox.countUnreadFiltered, 1);
  });

  test('rejects malformed native Inbox results', () {
    expect(
      () => InboxCodec.decode({
        'countTotal': '1',
        'countUnread': 0,
        'countTotalFiltered': 1,
        'countUnreadFiltered': 0,
        'messages': const [],
      }),
      throwsFormatException,
    );
    expect(
      () => InboxCodec.decode({
        'countTotal': 1,
        'countUnread': 0,
        'countTotalFiltered': 1,
        'countUnreadFiltered': 0,
        'messages': const ['bad'],
      }),
      throwsFormatException,
    );
    expect(
      () => InboxCodec.decode({
        'countTotal': 1,
        'countUnread': 0,
        'countTotalFiltered': 1,
        'countUnreadFiltered': 0,
        'messages': [
          {'messageId': 'message', 'seen': false, 'silent': 'no'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('delegates application-code fetch and seen operations', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(ChannelContract.methodChannel),
      (call) async {
        calls.add(call);
        if (call.method == ChannelContract.fetchInbox) {
          return {
            'countTotal': 0,
            'countUnread': 0,
            'countTotalFiltered': 0,
            'countUnreadFiltered': 0,
            'messages': <Object?>[],
          };
        }
        return null;
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel(ChannelContract.methodChannel),
        null,
      ),
    );

    final inbox = await InfobipMobileMessagingHuawei.fetchInbox(
      externalUserId: 'user',
      options: const InboxFilterOptions(topic: 'news', limit: 10),
    );
    await InfobipMobileMessagingHuawei.setInboxMessagesSeen(
      externalUserId: 'user',
      messageIds: ['one', 'two'],
    );

    expect(inbox.messages, isEmpty);
    expect(calls.map((call) => call.method), [
      ChannelContract.fetchInbox,
      ChannelContract.setInboxMessagesSeen,
    ]);
    expect(calls.first.arguments, {
      ChannelContract.externalUserId: 'user',
      ChannelContract.jwt: null,
      ChannelContract.options: {
        'from': null,
        'to': null,
        'topic': 'news',
        'topics': null,
        'limit': 10,
      },
    });
    expect(calls.last.arguments, {
      ChannelContract.externalUserId: 'user',
      ChannelContract.messageIds: ['one', 'two'],
    });
  });

  test('trims and delegates an explicit fetch JWT', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(ChannelContract.methodChannel),
      (call) async {
        calls.add(call);
        return {
          'countTotal': 0,
          'countUnread': 0,
          'countTotalFiltered': 0,
          'countUnreadFiltered': 0,
          'messages': <Object?>[],
        };
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel(ChannelContract.methodChannel),
        null,
      ),
    );

    await InfobipMobileMessagingHuawei.fetchInbox(
      externalUserId: 'user',
      jwt: '  header.payload.signature  ',
    );
    await InfobipMobileMessagingHuawei.fetchInbox(
      externalUserId: 'user',
      jwt: '   ',
    );

    expect(
      (calls.first.arguments as Map)[ChannelContract.jwt],
      'header.payload.signature',
    );
    expect((calls.last.arguments as Map)[ChannelContract.jwt], isNull);
  });

  test(
    'sets and clears the global JWT without exposing it elsewhere',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(ChannelContract.methodChannel),
        (call) async => calls.add(call),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel(ChannelContract.methodChannel),
          null,
        ),
      );

      await InfobipMobileMessagingHuawei.setJwt('  current-token  ');
      await InfobipMobileMessagingHuawei.setJwt(null);

      expect(calls.map((call) => call.method), [
        ChannelContract.setJwt,
        ChannelContract.setJwt,
      ]);
      expect(calls.first.arguments, {ChannelContract.jwt: 'current-token'});
      expect(calls.last.arguments, {ChannelContract.jwt: null});
    },
  );

  test('rejects an empty seen update without invoking native code', () {
    expect(
      () => InfobipMobileMessagingHuawei.setInboxMessagesSeen(
        externalUserId: 'user',
        messageIds: const [],
      ),
      throwsArgumentError,
    );
  });

  test('propagates native PlatformException', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(ChannelContract.methodChannel),
      (_) => throw PlatformException(
        code: 'ACCESS_TOKEN_MISSING',
        message: 'Access token not provided',
      ),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel(ChannelContract.methodChannel),
        null,
      ),
    );

    await expectLater(
      InfobipMobileMessagingHuawei.fetchInbox(externalUserId: 'user'),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'ACCESS_TOKEN_MISSING')
            .having(
              (error) => error.message,
              'message',
              'Access token not provided',
            ),
      ),
    );
  });
}
