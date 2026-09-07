import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class FakePlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  String? initializedWith;

  @override
  Stream<Object?> get events => const Stream.empty();

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {
    initializedWith = applicationCode;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the method-channel implementation by default', () {
    expect(
      InfobipMobileMessagingHuaweiPlatform.instance,
      isA<MethodChannelInfobipMobileMessagingHuawei>(),
    );
  });

  test('allows a verified platform implementation', () {
    final platform = FakePlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
    expect(InfobipMobileMessagingHuaweiPlatform.instance, same(platform));
  });

  test('centralizes stable channel names', () {
    expect(
      ChannelContract.methodChannel,
      'com.infobip.mobilemessaging.huawei/methods',
    );
    expect(
      ChannelContract.eventChannel,
      'com.infobip.mobilemessaging.huawei/events',
    );
  });

  test(
    'forwards message storage configuration with initialization',
    () async {
      const channelName = 'initialization-method-test';
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(channelName);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final platform = MethodChannelInfobipMobileMessagingHuawei(
        methodChannel: channel,
        eventChannel: const EventChannel('initialization-event-test'),
      );
      await platform.initialize(
        applicationCode: 'test-code',
        defaultMessageStorage: false,
      );

      expect(calls.single.method, ChannelContract.initialize);
      expect(calls.single.arguments, <String, Object>{
        ChannelContract.applicationCode: 'test-code',
        ChannelContract.defaultMessageStorage: false,
      });
    },
  );

  test(
    'forwards cleanup over the method channel',
    () async {
      const channelName = 'cleanup-method-test';
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(channelName);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final platform = MethodChannelInfobipMobileMessagingHuawei(
        methodChannel: channel,
        eventChannel: const EventChannel('cleanup-event-test'),
      );
      await platform.cleanup();

      expect(calls.single.method, ChannelContract.cleanup);
      expect(calls.single.arguments, isNull);
    },
  );

  test('forwards nested WebRTC initialization configuration', () async {
    const channelName = 'webrtc-initialization-method-test';
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('webrtc-initialization-event-test'),
    );

    await platform.initialize(
      applicationCode: 'test-code',
      webRTCUI: const WebRTCUI(configurationId: ' rtc-id '),
    );

    expect(calls.single.arguments, <String, Object?>{
      ChannelContract.applicationCode: 'test-code',
      ChannelContract.defaultMessageStorage: true,
      ChannelContract.webRTCUI: <String, Object?>{
        ChannelContract.configurationId: ' rtc-id ',
      },
    });
  });

  test('preserves a null WebRTC configuration ID', () async {
    const channelName = 'null-webrtc-initialization-method-test';
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('null-webrtc-initialization-event-test'),
    );

    await platform.initialize(
      applicationCode: 'test-code',
      webRTCUI: const WebRTCUI(),
    );

    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments[ChannelContract.webRTCUI], <String, Object?>{
      ChannelContract.configurationId: null,
    });
  });

  test(
    'forwards remote notification registration over the method channel',
    () async {
      const channelName = 'registration-method-test';
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(channelName);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final platform = MethodChannelInfobipMobileMessagingHuawei(
        methodChannel: channel,
        eventChannel: const EventChannel('registration-event-test'),
      );
      await platform.registerForRemoteNotifications();

      expect(
        calls.single.method,
        ChannelContract.registerForRemoteNotifications,
      );
      expect(calls.single.arguments, isNull);
    },
  );

  test(
    'shares one native event subscription and supports re-subscription',
    () async {
      const eventChannelName = 'platform-interface-test-events';
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final nativeCalls = <String>[];
      messenger.setMockMessageHandler(eventChannelName, (message) async {
        nativeCalls.add(codec.decodeMethodCall(message).method);
        return codec.encodeSuccessEnvelope(null);
      });
      addTearDown(
        () => messenger.setMockMessageHandler(eventChannelName, null),
      );

      final platform = MethodChannelInfobipMobileMessagingHuawei(
        eventChannel: const EventChannel(eventChannelName),
      );
      final firstEvents = <Object?>[];
      final secondEvents = <Object?>[];
      final first = platform.events.listen(firstEvents.add);
      final second = platform.events.listen(secondEvents.add);
      await pumpEventQueue();

      await messenger.handlePlatformMessage(
        eventChannelName,
        codec.encodeSuccessEnvelope('first'),
        (_) {},
      );
      await pumpEventQueue();
      expect(firstEvents, ['first']);
      expect(secondEvents, ['first']);
      expect(nativeCalls, ['listen']);

      await first.cancel();
      expect(nativeCalls, ['listen']);
      await second.cancel();
      await pumpEventQueue();
      expect(nativeCalls, ['listen', 'cancel']);

      final reSubscribedEvents = <Object?>[];
      final reSubscribed = platform.events.listen(reSubscribedEvents.add);
      await pumpEventQueue();
      await messenger.handlePlatformMessage(
        eventChannelName,
        codec.encodeSuccessEnvelope('second'),
        (_) {},
      );
      await pumpEventQueue();
      expect(reSubscribedEvents, ['second']);
      expect(nativeCalls, ['listen', 'cancel', 'listen']);

      await reSubscribed.cancel();
    },
  );
}
