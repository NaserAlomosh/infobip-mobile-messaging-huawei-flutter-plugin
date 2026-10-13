import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannel channel;
  late List<MethodCall> calls;

  setUp(() {
    channel = const MethodChannel('custom-event-method-test');
    calls = <MethodCall>[];
    InfobipMobileMessagingHuaweiPlatform.instance =
        MethodChannelInfobipMobileMessagingHuawei(
          methodChannel: channel,
          eventChannel: const EventChannel('custom-event-event-test'),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('submitEvent maps definition and properties', () async {
    _handler(channel, calls, (_) => null);
    await InfobipMobileMessagingHuawei.submitEvent(
      InfobipHuaweiCustomEvent(
        definitionId: ' purchase ',
        properties: {'amount': 12.5, 'paid': true, 'at': DateTime.utc(2026)},
      ),
    );

    expect(calls.single.method, ChannelContract.submitEvent);
    expect(calls.single.arguments, {
      ChannelContract.customEvent: {
        ChannelContract.definitionId: 'purchase',
        ChannelContract.properties: {
          'amount': 12.5,
          'paid': true,
          'at': {
            ChannelContract.customValueType: ChannelContract.customDateType,
            ChannelContract.customValue: '2026-01-01T00:00:00.000Z',
          },
        },
      },
    });
  });

  test('submitEvent rejects malformed input', () async {
    expect(
      () => InfobipMobileMessagingHuawei.submitEvent(
        const InfobipHuaweiCustomEvent(definitionId: ' '),
      ),
      throwsArgumentError,
    );
    expect(
      () => InfobipMobileMessagingHuawei.submitEvent(
        const InfobipHuaweiCustomEvent(
          definitionId: 'event',
          properties: {'unsupported': Object()},
        ),
      ),
      throwsA(isA<PlatformException>()),
    );
  });

  test('submitEventImmediately waits for and maps native result', () async {
    _handler(
      channel,
      calls,
      (_) => {
        ChannelContract.definitionId: 'purchase',
        ChannelContract.eventId: 'event-1',
        ChannelContract.createdAt: '2026-09-05T12:00:00Z',
        ChannelContract.properties: {'amount': 20},
      },
    );

    final event = await InfobipMobileMessagingHuawei.submitEventImmediately(
      const InfobipHuaweiCustomEvent(definitionId: 'purchase'),
    );
    expect(calls.single.method, ChannelContract.submitEventImmediately);
    expect(event.eventId, 'event-1');
    expect(event.createdAt, DateTime.utc(2026, 9, 5, 12));
    expect(event.properties, {'amount': 20});
  });

  test('submitEventImmediately preserves native platform errors', () async {
    _handler(
      channel,
      calls,
      (_) => throw PlatformException(
        code: '42',
        message: 'Rejected',
        details: {'code': '42', 'message': 'Rejected'},
      ),
    );
    await expectLater(
      InfobipMobileMessagingHuawei.submitEventImmediately(
        const InfobipHuaweiCustomEvent(definitionId: 'purchase'),
      ),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', '42')
            .having((error) => error.message, 'message', 'Rejected')
            .having((error) => error.details, 'details', {
              'code': '42',
              'message': 'Rejected',
            }),
      ),
    );
  });

  test('submitEventImmediately rejects malformed native payload', () async {
    _handler(channel, calls, (_) => {'definitionId': 1});
    await expectLater(
      InfobipMobileMessagingHuawei.submitEventImmediately(
        const InfobipHuaweiCustomEvent(definitionId: 'purchase'),
      ),
      throwsFormatException,
    );
  });
}

void _handler(
  MethodChannel channel,
  List<MethodCall> calls,
  Object? Function(MethodCall) respond,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return respond(call);
      });
}
