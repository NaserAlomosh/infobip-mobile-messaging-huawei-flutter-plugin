import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class ChatPushPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final titles = <String?>[];
  final bodies = <String?>[];

  @override
  Stream<Object?> get events => const Stream.empty();

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
  }) async {}

  @override
  Future<void> setChatPushTitle(String? title) async => titles.add(title);

  @override
  Future<void> setChatPushBody(String? body) async => bodies.add(body);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('global APIs forward values without a Chat controller or view', () async {
    final platform = ChatPushPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;

    await InfobipMobileMessagingHuawei.setChatPushTitle('Support');
    await InfobipMobileMessagingHuawei.setChatPushTitle(null);
    await InfobipMobileMessagingHuawei.setChatPushTitle('');
    await InfobipMobileMessagingHuawei.setChatPushTitle('  Support  ');
    await InfobipMobileMessagingHuawei.setChatPushBody('New message');
    await InfobipMobileMessagingHuawei.setChatPushBody(null);
    await InfobipMobileMessagingHuawei.setChatPushBody('');
    await InfobipMobileMessagingHuawei.setChatPushBody('  New message  ');

    expect(platform.titles, ['Support', null, '', '  Support  ']);
    expect(platform.bodies, ['New message', null, '', '  New message  ']);
  });

  test('method channel sends nullable strings directly and unchanged', () async {
    const channel = MethodChannel('chat-push-method-test');
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
      eventChannel: const EventChannel('chat-push-event-test'),
    );

    for (final value in <String?>['Support', null, '', '  Support  ']) {
      await platform.setChatPushTitle(value);
    }
    for (final value in <String?>['New message', null, '', '  New message  ']) {
      await platform.setChatPushBody(value);
    }

    expect(
      calls.take(4).map((call) => call.method),
      everyElement(ChannelContract.setChatPushTitle),
    );
    expect(
      calls.take(4).map((call) => call.arguments),
      ['Support', null, '', '  Support  '],
    );
    expect(
      calls.skip(4).map((call) => call.method),
      everyElement(ChannelContract.setChatPushBody),
    );
    expect(
      calls.skip(4).map((call) => call.arguments),
      ['New message', null, '', '  New message  '],
    );
  });

  test('PlatformException propagates unchanged', () async {
    const channel = MethodChannel('chat-push-error-method-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final error = PlatformException(code: 'native_error', message: 'failed');
    messenger.setMockMethodCallHandler(channel, (_) async => throw error);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('chat-push-error-event-test'),
    );

    await expectLater(
      platform.setChatPushTitle('Support'),
      throwsA(same(error)),
    );
    await expectLater(
      platform.setChatPushBody('New message'),
      throwsA(same(error)),
    );
  });
}
