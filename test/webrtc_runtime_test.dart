import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class WebRtcPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  String? identity;
  var chatCalls = 0;
  var disableCallCount = 0;

  @override
  Stream<Object?> get events => const Stream.empty();

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {}

  @override
  Future<void> enableCalls(String identity) async {
    this.identity = identity;
  }

  @override
  Future<void> enableChatCalls() async {
    chatCalls++;
  }

  @override
  Future<void> disableCalls() async {
    disableCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public WebRTC APIs delegate without changing identity', () async {
    final platform = WebRtcPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;

    await InfobipMobileMessagingHuawei.enableCalls('  identity  ');
    await InfobipMobileMessagingHuawei.enableChatCalls();
    await InfobipMobileMessagingHuawei.disableCalls();

    expect(platform.identity, '  identity  ');
    expect(platform.chatCalls, 1);
    expect(platform.disableCallCount, 1);
  });

  test(
    'method channel uses official WebRTC method names and arguments',
    () async {
      const channel = MethodChannel('webrtc-runtime-method-test');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final platform = MethodChannelInfobipMobileMessagingHuawei(
        methodChannel: channel,
        eventChannel: const EventChannel('webrtc-runtime-event-test'),
      );

      await platform.enableCalls('identity');
      await platform.enableChatCalls();
      await platform.disableCalls();

      expect(calls[0].method, ChannelContract.enableCalls);
      expect(calls[0].arguments, 'identity');
      expect(calls[1].method, ChannelContract.enableChatCalls);
      expect(calls[1].arguments, isNull);
      expect(calls[2].method, ChannelContract.disableCalls);
      expect(calls[2].arguments, isNull);
    },
  );
}
