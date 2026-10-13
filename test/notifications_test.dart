import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class NotificationsPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final eventsController = StreamController<Object?>.broadcast();

  @override
  Stream<Object?> get events => eventsController.stream;

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {}
}

Map<String, Object?> envelope(String type, Map<String, Object?> payload) => {
  'version': ChannelContract.eventVersion,
  'type': type,
  'timestamp': 1,
  'payload': payload,
};

void main() {
  late NotificationsPlatform platform;

  setUp(() {
    platform = NotificationsPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
  });

  tearDown(() => platform.eventsController.close());

  test('decodes message received events', () async {
    final future =
        InfobipMobileMessagingHuawei.notifications.onMessageReceived.first;
    platform.eventsController.add(
      envelope(ChannelContract.messageReceived, {
        'message': {
          'messageId': 'message-1',
          'title': 'Title',
          'body': 'Body',
          'customPayload': {'orderId': 42},
          'deeplink': 'app://orders/42',
          'silent': true,
        },
      }),
    );
    final message = await future;
    expect(message.messageId, 'message-1');
    expect(message.customPayload, {'orderId': 42});
    expect(message.silent, isTrue);
  });

  test('decodes notification tapped events', () async {
    final future =
        InfobipMobileMessagingHuawei.notifications.onNotificationTapped.first;
    platform.eventsController.add(
      envelope(ChannelContract.notificationTapped, {
        'message': {
          'messageId': 'message-tapped',
          'title': 'Opened',
          'silent': false,
        },
      }),
    );

    final message = await future;
    expect(message.messageId, 'message-tapped');
    expect(message.title, 'Opened');
  });

  test('decodes action and registration events', () async {
    final actionFuture = InfobipMobileMessagingHuawei
        .notifications
        .onNotificationActionTapped
        .first;
    final registrationFuture =
        InfobipMobileMessagingHuawei.notifications.onRegistrationUpdated.first;
    platform.eventsController
      ..add(
        envelope(ChannelContract.notificationActionTapped, {
          'actionId': 'accept',
          'message': {'messageId': 'message-2', 'silent': false},
        }),
      )
      ..add(
        envelope(ChannelContract.registrationUpdated, {
          ChannelContract.installation: {
            ChannelContract.pushRegistrationEnabled: false,
          },
        }),
      );
    expect((await actionFuture).actionId, 'accept');
    expect((await registrationFuture).pushRegistrationEnabled, isFalse);
  });

  test('decodes installation updated events', () async {
    final future =
        InfobipMobileMessagingHuawei.notifications.onInstallationUpdated.first;
    platform.eventsController.add(
      envelope(ChannelContract.installationUpdated, {
        ChannelContract.installation: {
          ChannelContract.installationId: 'installation-1',
          ChannelContract.isPrimaryDevice: true,
        },
      }),
    );

    final installation = await future;
    expect(installation.installationId, 'installation-1');
    expect(installation.isPrimaryDevice, isTrue);
  });

  test(
    'ignores malformed and unknown events without closing the stream',
    () async {
      final future =
          InfobipMobileMessagingHuawei.notifications.onMessageReceived.first;
      platform.eventsController
        ..add({'version': 1, 'type': 'future_event', 'payload': {}})
        ..add(envelope(ChannelContract.messageReceived, {'message': 'bad'}))
        ..add(
          envelope(ChannelContract.messageReceived, {
            'message': {'messageId': 'valid', 'silent': false},
          }),
        );
      expect((await future).messageId, 'valid');
    },
  );

  test('ignores malformed booleans and nested payloads', () async {
    final future =
        InfobipMobileMessagingHuawei.notifications.onMessageReceived.first;
    platform.eventsController
      ..add(
        envelope(ChannelContract.messageReceived, {
          'message': {'messageId': 'bad-bool', 'silent': 'no'},
        }),
      )
      ..add(
        envelope(ChannelContract.messageReceived, {
          'message': {
            'messageId': 'bad-payload',
            'silent': false,
            'customPayload': {
              'nested': {1: 'invalid'},
            },
          },
        }),
      )
      ..add(
        envelope(ChannelContract.messageReceived, {
          'message': {'messageId': 'valid', 'silent': false},
        }),
      );

    expect((await future).messageId, 'valid');
  });

  test('decodes user updated and personalized events', () async {
    final updated =
        InfobipMobileMessagingHuawei.notifications.onUserUpdated.first;
    final personalized =
        InfobipMobileMessagingHuawei.notifications.onPersonalized.first;
    platform.eventsController
      ..add(
        envelope(ChannelContract.userUpdated, {
          ChannelContract.user: {
            ChannelContract.externalUserId: 'updated-user',
          },
        }),
      )
      ..add(
        envelope(ChannelContract.personalized, {
          ChannelContract.user: {
            ChannelContract.externalUserId: 'personalized-user',
            ChannelContract.firstName: 'Ada',
          },
        }),
      );

    expect((await updated).externalUserId, 'updated-user');
    expect((await personalized).firstName, 'Ada');
  });

  test('malformed user lifecycle payloads do not close streams', () async {
    final updated =
        InfobipMobileMessagingHuawei.notifications.onUserUpdated.first;
    final personalized =
        InfobipMobileMessagingHuawei.notifications.onPersonalized.first;
    platform.eventsController
      ..add(
        envelope(ChannelContract.userUpdated, {ChannelContract.user: 'bad'}),
      )
      ..add(
        envelope(ChannelContract.personalized, {ChannelContract.user: null}),
      )
      ..add(
        envelope(ChannelContract.userUpdated, {
          ChannelContract.user: {ChannelContract.externalUserId: 'valid'},
        }),
      )
      ..add(
        envelope(ChannelContract.personalized, {
          ChannelContract.user: {ChannelContract.externalUserId: 'valid'},
        }),
      );

    expect((await updated).externalUserId, 'valid');
    expect((await personalized).externalUserId, 'valid');
  });

  test('depersonalized emits without a user payload', () async {
    final emitted =
        InfobipMobileMessagingHuawei.notifications.onDepersonalized.first;
    platform.eventsController.add(envelope(ChannelContract.depersonalized, {}));
    await emitted;
  });
}
