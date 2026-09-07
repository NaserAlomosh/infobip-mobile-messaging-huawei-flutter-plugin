import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(ChannelContract.methodChannel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Object? availabilityResult;
  Object? counterResult;
  PlatformException? resetFailure;

  setUp(() {
    calls = [];
    availabilityResult = true;
    counterResult = 3;
    resetFailure = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case ChannelContract.isChatAvailable:
          return availabilityResult;
        case ChannelContract.getChatUnreadMessageCount:
          return counterResult;
        case ChannelContract.resetChatMessageCounter:
          final failure = resetFailure;
          if (failure != null) throw failure;
          return null;
      }
      return null;
    });
    InfobipMobileMessagingHuaweiPlatform.instance =
        MethodChannelInfobipMobileMessagingHuawei();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('isChatAvailable preserves true and false', () async {
    expect(await InfobipMobileMessagingHuawei.chat.isChatAvailable(), isTrue);
    availabilityResult = false;
    expect(await InfobipMobileMessagingHuawei.chat.isChatAvailable(), isFalse);
  });

  test('isChatAvailable rejects a malformed native result', () async {
    availabilityResult = 1;

    await expectLater(
      InfobipMobileMessagingHuawei.chat.isChatAvailable(),
      throwsFormatException,
    );
  });

  test(
    'message counter parity method shares the existing native query',
    () async {
      expect(await InfobipMobileMessagingHuawei.chat.getMessageCounter(), 3);
      expect(
        await InfobipMobileMessagingHuawei.chat.getUnreadMessageCount(),
        3,
      );
      expect(
        calls.map((call) => call.method),
        everyElement(ChannelContract.getChatUnreadMessageCount),
      );
    },
  );

  test('resetMessageCounter completes after invoking native reset', () async {
    await InfobipMobileMessagingHuawei.chat.resetMessageCounter();

    expect(calls.single.method, ChannelContract.resetChatMessageCounter);
  });

  test('resetMessageCounter propagates native failure', () async {
    resetFailure = PlatformException(code: 'native_error');

    await expectLater(
      InfobipMobileMessagingHuawei.chat.resetMessageCounter(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'native_error',
        ),
      ),
    );
  });
}
