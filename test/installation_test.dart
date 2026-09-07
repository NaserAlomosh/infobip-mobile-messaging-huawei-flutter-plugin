import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ChannelContract.methodChannel);
  final calls = <MethodCall>[];
  late MethodChannelInfobipMobileMessagingHuawei platform;

  setUp(() {
    calls.clear();
    platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('installation-test-events'),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return <String, Object?>{
            ChannelContract.installationId: 'installation-1',
            ChannelContract.pushRegistrationId: 'managed-id',
            ChannelContract.isPushRegistrationEnabled: true,
            ChannelContract.notificationsEnabled: false,
            ChannelContract.language: 'en',
            ChannelContract.customAttributes: <String, Object?>{
              'created': <String, Object?>{
                ChannelContract.customValueType: ChannelContract.customDateType,
                ChannelContract.customValue: '2026-09-01T10:15:30.000Z',
              },
            },
          };
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('delegates local and server-backed installation reads', () async {
    final local = await platform.getInstallation();
    await platform.fetchInstallation();
    expect(local.pushRegistrationEnabled, isTrue);
    expect(local.installationId, 'installation-1');
    expect(local.notificationsEnabled, isFalse);
    expect(
      local.customAttributes?['created'],
      DateTime.utc(2026, 9, 1, 10, 15, 30),
    );
    expect(calls.map((call) => call.method), [
      ChannelContract.getInstallation,
      ChannelContract.fetchInstallation,
    ]);
  });

  test('save sends only writable installation properties', () async {
    await platform.saveInstallation(
      Installation(
        pushRegistrationId: 'must-not-be-sent',
        deviceModel: 'must-not-be-sent',
        isPrimaryDevice: true,
        customAttributes: {'when': DateTime.utc(2026, 9, 1)},
      ),
    );
    final arguments = calls.single.arguments as Map;
    final payload = arguments[ChannelContract.installation] as Map;
    expect(
      payload.keys,
      containsAll(<String>[
        ChannelContract.isPrimaryDevice,
        ChannelContract.customAttributes,
      ]),
    );
    expect(payload, isNot(contains(ChannelContract.pushRegistrationId)));
    expect(payload, isNot(contains(ChannelContract.deviceModel)));
    expect(payload, isNot(contains(ChannelContract.pushRegistrationEnabled)));
    expect(payload, isNot(contains(ChannelContract.language)));
  });

  test('rejects malformed installation fields', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{
            ChannelContract.isPushRegistrationEnabled: 'yes',
          },
        );
    expect(platform.getInstallation(), throwsFormatException);
  });

  test(
    'rejects unsupported custom attribute values before delegation',
    () async {
      expect(
        platform.saveInstallation(
          Installation(customAttributes: {'bad': Object()}),
        ),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
