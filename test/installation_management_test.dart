import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('installation-management-test');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    InfobipMobileMessagingHuaweiPlatform.instance =
        MethodChannelInfobipMobileMessagingHuawei(
          methodChannel: channel,
          eventChannel: const EventChannel('installation-management-events'),
        );
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  void respond(Object? Function(MethodCall) response) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return response(call);
        });
  }

  test(
    'depersonalizeInstallation accepts populated response without requiring a list result',
    () async {
      respond(
        (_) => [
          {ChannelContract.pushRegistrationId: 'one'},
          {
            ChannelContract.pushRegistrationId: 'two',
            ChannelContract.isPrimaryDevice: true,
          },
        ],
      );
      await InfobipMobileMessagingHuawei.depersonalizeInstallation(' token ');
      expect(calls.single.method, ChannelContract.depersonalizeInstallation);
      expect(calls.single.arguments, {
        ChannelContract.pushRegistrationId: 'token',
      });
    },
  );

  test('installation APIs reject empty ids', () {
    expect(
      () => InfobipMobileMessagingHuawei.depersonalizeInstallation('  '),
      throwsArgumentError,
    );
    expect(
      () => InfobipMobileMessagingHuawei.setInstallationAsPrimary(
        pushRegistrationId: '',
        isPrimary: true,
      ),
      throwsArgumentError,
    );
  });

  for (final primary in [true, false]) {
    test('setInstallationAsPrimary forwards isPrimary=$primary', () async {
      respond(
        (_) => [
          {
            ChannelContract.pushRegistrationId: 'token',
            ChannelContract.isPrimaryDevice: primary,
          },
        ],
      );
      final result =
          await InfobipMobileMessagingHuawei.setInstallationAsPrimary(
            pushRegistrationId: ' token ',
            isPrimary: primary,
          );
      expect(calls.single.arguments, {
        ChannelContract.pushRegistrationId: 'token',
        ChannelContract.isPrimary: primary,
      });
      expect(result!.single.isPrimaryDevice, primary);
    });
  }

  test('successful null installation mutations stay successful', () async {
    respond((_) => null);
    await InfobipMobileMessagingHuawei.depersonalizeInstallation('token');
    expect(
      await InfobipMobileMessagingHuawei.setInstallationAsPrimary(
        pushRegistrationId: 'token',
        isPrimary: true,
      ),
      isNull,
    );
  });

  test('installation operation preserves native error', () async {
    respond((_) => throw PlatformException(code: '17', message: 'Rejected'));
    await expectLater(
      InfobipMobileMessagingHuawei.depersonalizeInstallation('token'),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', '17')
            .having((error) => error.message, 'message', 'Rejected'),
      ),
    );
  });
}
