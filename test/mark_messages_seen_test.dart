import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class MessageSeenPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final calls = <List<String>>[];

  @override
  Stream<Object?> get events => const Stream.empty();

  @override
  Future<void> initialize({required String applicationCode}) async {}

  @override
  Future<void> markMessagesSeen(List<String> messageIds) async {
    calls.add(messageIds);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public facade forwards message IDs', () async {
    final platform = MessageSeenPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
    final ids = <String>['one', 'two'];

    await InfobipMobileMessagingHuawei.markMessagesSeen(ids);

    expect(platform.calls, [ids]);
  });

  test('method channel sends one ID as a direct list', () async {
    final calls = await invokeWith(<String>['one']);

    expect(calls.single.method, ChannelContract.markMessagesSeen);
    expect(calls.single.arguments, <String>['one']);
    expect(calls.single.arguments, isA<List<Object?>>());
  });

  test(
    'method channel preserves opaque strings, order, and duplicates',
    () async {
      final ids = <String>[
        'second',
        '1788547032704145206',
        'second',
        '  spaced  ',
        'message:🚀/\u0000',
      ];

      final calls = await invokeWith(ids);

      expect(calls.single.arguments, ids);
    },
  );

  test('empty list is sent for native validation', () async {
    final calls = await invokeWith(<String>[]);

    expect(calls.single.arguments, isEmpty);
  });

  test('PlatformException propagates unchanged', () async {
    const channel = MethodChannel('mark-messages-seen-error-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'invalid_argument',
        message: 'messageIds must not be empty',
      );
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('mark-messages-seen-error-events'),
    );

    await expectLater(
      platform.markMessagesSeen(<String>[]),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_argument',
        ),
      ),
    );
  });

  test('ignores a native response payload for Future<void>', () async {
    const channel = MethodChannel('mark-messages-seen-response-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => <String, Object?>{
      'unexpected': true,
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('mark-messages-seen-response-events'),
    );

    await expectLater(platform.markMessagesSeen(<String>['one']), completes);
  });
}

Future<List<MethodCall>> invokeWith(List<String> messageIds) async {
  const channel = MethodChannel('mark-messages-seen-method-test');
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return null;
  });
  final platform = MethodChannelInfobipMobileMessagingHuawei(
    methodChannel: channel,
    eventChannel: const EventChannel('mark-messages-seen-method-events'),
  );

  await platform.markMessagesSeen(messageIds);
  messenger.setMockMethodCallHandler(channel, null);
  return calls;
}
