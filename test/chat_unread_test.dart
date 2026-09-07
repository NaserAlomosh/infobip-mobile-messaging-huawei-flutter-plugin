import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class ChatPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final eventsController = StreamController<Object?>.broadcast();
  Object unreadResult = 0;

  @override
  Stream<Object?> get events => eventsController.stream;

  @override
  Future<int> getChatUnreadMessageCount() async {
    final result = unreadResult;
    if (result is Exception) throw result;
    if (result is! int) throw const FormatException('Invalid result');
    return result;
  }

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
  }) async {}
}

Map<String, Object?> unreadEnvelope(Object? count) => {
  'version': ChannelContract.eventVersion,
  'type': ChannelContract.chatUnreadMessageCounterUpdated,
  'timestamp': 1,
  'payload': {'count': count},
};

void main() {
  late ChatPlatform platform;

  setUp(() {
    platform = ChatPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
  });

  tearDown(() => platform.eventsController.close());

  test('returns zero and positive unread message counts', () async {
    expect(
      await InfobipMobileMessagingHuawei.chat.getUnreadMessageCount(),
      0,
    );
    platform.unreadResult = 4;
    expect(
      await InfobipMobileMessagingHuawei.chat.getUnreadMessageCount(),
      4,
    );
  });

  for (final code in ['not_initialized', 'chat_unavailable', 'native_error']) {
    test('preserves $code failures', () async {
      platform.unreadResult = PlatformException(code: code);
      await expectLater(
        InfobipMobileMessagingHuawei.chat.getUnreadMessageCount(),
        throwsA(isA<PlatformException>().having((error) => error.code, 'code', code)),
      );
    });
  }

  test('preserves malformed native result as failure', () async {
    platform.unreadResult = '0';
    await expectLater(
      InfobipMobileMessagingHuawei.chat.getUnreadMessageCount(),
      throwsFormatException,
    );
  });

  test('emits zero, positive, and duplicate updates to every listener', () async {
    final first = <int>[];
    final second = <int>[];
    final subscriptions = [
      InfobipMobileMessagingHuawei.chat.onUnreadMessageCounterUpdated.listen(
        first.add,
      ),
      InfobipMobileMessagingHuawei.chat.onUnreadMessageCounterUpdated.listen(
        second.add,
      ),
    ];
    platform.eventsController
      ..add(unreadEnvelope(0))
      ..add(unreadEnvelope(3))
      ..add(unreadEnvelope(3));
    await Future<void>.delayed(Duration.zero);
    expect(first, [0, 3, 3]);
    expect(second, first);
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  });

  test('ignores malformed, negative, and unrelated events and stays alive', () async {
    final future = InfobipMobileMessagingHuawei
        .chat
        .onUnreadMessageCounterUpdated
        .first;
    platform.eventsController
      ..add(unreadEnvelope(-1))
      ..add(unreadEnvelope('3'))
      ..add({'version': 1, 'type': ChannelContract.messageReceived, 'payload': {}})
      ..add(unreadEnvelope(2));
    expect(await future, 2);
  });
}
