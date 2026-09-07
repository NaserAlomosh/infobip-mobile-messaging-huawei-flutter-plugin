import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class ShowChatPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final presentedModallyIOS = <bool>[];

  @override
  Stream<Object?> get events => const Stream.empty();

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
  }) async {}

  @override
  Future<void> showChat({required bool shouldBePresentedModallyIOS}) async {
    presentedModallyIOS.add(shouldBePresentedModallyIOS);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('global API defaults shouldBePresentedModallyIOS to true', () async {
    final platform = ShowChatPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;

    await InfobipMobileMessagingHuawei.showChat();

    expect(platform.presentedModallyIOS, [true]);
  });

  test('global API forwards explicit false without a Chat controller', () async {
    final platform = ShowChatPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;

    await InfobipMobileMessagingHuawei.showChat(
      shouldBePresentedModallyIOS: false,
    );

    expect(platform.presentedModallyIOS, [false]);
  });

  test('method channel sends the official boolean argument directly', () async {
    const channel = MethodChannel('show-chat-method-test');
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
      eventChannel: const EventChannel('show-chat-event-test'),
    );

    await platform.showChat(shouldBePresentedModallyIOS: true);
    await platform.showChat(shouldBePresentedModallyIOS: false);

    expect(
      calls.map((call) => call.method),
      everyElement(ChannelContract.showChat),
    );
    expect(calls.map((call) => call.arguments), [true, false]);
  });

  test('PlatformException from showChat propagates unchanged', () async {
    const channel = MethodChannel(ChannelContract.methodChannel);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'not_initialized',
        message: 'Initialize the Infobip SDK first',
      );
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    InfobipMobileMessagingHuaweiPlatform.instance =
        MethodChannelInfobipMobileMessagingHuawei();

    await expectLater(
      InfobipMobileMessagingHuawei.showChat(),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'not_initialized')
            .having(
              (error) => error.message,
              'message',
              'Initialize the Infobip SDK first',
            ),
      ),
    );
  });
}
