import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class NavigationPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final controller = StreamController<Object?>.broadcast(sync: true);
  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {}
  @override
  Stream<Object?> get events => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('typed request rejects malformed native navigation envelopes', () {
    expect(ChatNotificationNavigationRequest.decode(null), isNull);
    expect(
      ChatNotificationNavigationRequest.decode({'correlationId': ''}),
      isNull,
    );
    expect(
      ChatNotificationNavigationRequest.decode({
        'correlationId': 'tap',
        'threadId': 42,
      }),
      isNull,
    );
    final request = ChatNotificationNavigationRequest.decode({
      'correlationId': 'tap',
      'threadId': 'thread',
    })!;
    expect(request.correlationId, 'tap');
    expect(request.threadId, 'thread');
  });
  test(
    'dedicated navigation stream preserves correlation and ignores generic taps',
    () async {
      final old = InfobipMobileMessagingHuaweiPlatform.instance;
      final platform = NavigationPlatform();
      InfobipMobileMessagingHuaweiPlatform.instance = platform;
      final seen = <ChatNotificationNavigationRequest>[];
      final subscription = InfobipMobileMessagingHuawei
          .chat
          .onNotificationNavigationRequested
          .listen(seen.add);
      platform.controller.add({
        'version': 1,
        'type': 'notification_tapped',
        'payload': {'correlationId': 'generic'},
      });
      platform.controller.add({
        'version': 1,
        'type': 'chat_notification_navigation_requested',
        'payload': {'correlationId': 'tap', 'threadId': 'thread'},
      });
      expect(seen.single.correlationId, 'tap');
      expect(seen.single.threadId, 'thread');
      await subscription.cancel();
      await platform.controller.close();
      InfobipMobileMessagingHuaweiPlatform.instance = old;
    },
  );
  test(
    'pending request query does not consume and ack uses the same correlation id',
    () async {
      const channel = MethodChannel('chat-navigation-methods-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getPendingChatNotificationNavigation') {
          return {'correlationId': 'tap', 'threadId': 'thread'};
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final old = InfobipMobileMessagingHuaweiPlatform.instance;
      InfobipMobileMessagingHuaweiPlatform.instance =
          MethodChannelInfobipMobileMessagingHuawei(
            methodChannel: channel,
            eventChannel: const EventChannel('chat-navigation-events-test'),
          );
      addTearDown(() {
        InfobipMobileMessagingHuaweiPlatform.instance = old;
      });
      expect(
        (await InfobipMobileMessagingHuawei.chat
                .getPendingNotificationNavigation())!
            .correlationId,
        'tap',
      );
      expect(
        (await InfobipMobileMessagingHuawei.chat
                .getPendingNotificationNavigation())!
            .threadId,
        'thread',
      );
      expect(
        await InfobipMobileMessagingHuawei.chat
            .acknowledgeNotificationNavigation('tap'),
        isTrue,
      );
      expect(calls.last.method, 'acknowledgeChatNotificationNavigation');
      expect(calls.last.arguments, 'tap');
    },
  );
}
