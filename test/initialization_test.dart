import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class InitializationPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  String? applicationCode;
  bool? defaultMessageStorage;
  WebRTCUI? webRTCUI;
  Object? error;
  var registrationCalls = 0;
  var cleanupCalls = 0;

  @override
  Stream<Object?> get events => const Stream.empty();

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {
    this.applicationCode = applicationCode;
    this.defaultMessageStorage = defaultMessageStorage;
    this.webRTCUI = webRTCUI;
    if (error case final Object error) throw error;
  }

  @override
  Future<void> registerForRemoteNotifications() async {
    registrationCalls++;
    if (error case final Object error) throw error;
  }

  @override
  Future<void> cleanup() async {
    cleanupCalls++;
    if (error case final Object error) throw error;
  }
}

void main() {
  late InitializationPlatform platform;

  setUp(() {
    InfobipMobileMessagingHuawei.defaultMessageStorage = true;
    platform = InitializationPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
  });

  test('rejects an empty application code before platform delegation', () {
    expect(
      () => InfobipMobileMessagingHuawei.initialize(applicationCode: '  '),
      throwsArgumentError,
    );
    expect(platform.applicationCode, isNull);
  });

  test('delegates initialization to the platform', () async {
    await InfobipMobileMessagingHuawei.initialize(applicationCode: 'test-code');
    expect(platform.applicationCode, 'test-code');
    expect(platform.defaultMessageStorage, isTrue);
    expect(platform.webRTCUI, isNull);
  });

  test('forwards optional WebRTC configuration unchanged', () async {
    const configuration = WebRTCUI(configurationId: 'rtc-configuration');

    await InfobipMobileMessagingHuawei.initialize(
      applicationCode: 'test-code',
      webRTCUI: configuration,
    );

    expect(platform.applicationCode, 'test-code');
    expect(platform.webRTCUI, same(configuration));
    expect(platform.webRTCUI?.configurationId, 'rtc-configuration');
  });

  test('accepts a WebRTC configuration with a null configuration ID', () async {
    await InfobipMobileMessagingHuawei.initialize(
      applicationCode: 'test-code',
      webRTCUI: const WebRTCUI(),
    );

    expect(platform.webRTCUI, isNotNull);
    expect(platform.webRTCUI?.configurationId, isNull);
  });

  test('uses the official default message storage value', () {
    expect(InfobipMobileMessagingHuawei.defaultMessageStorage, isTrue);
  });

  test('forwards disabled default message storage during initialization', () async {
    InfobipMobileMessagingHuawei.defaultMessageStorage = false;

    await InfobipMobileMessagingHuawei.initialize(applicationCode: 'test-code');

    expect(platform.defaultMessageStorage, isFalse);
  });

  test('delegates root cleanup to the platform', () async {
    await InfobipMobileMessagingHuawei.cleanup();
    expect(platform.cleanupCalls, 1);
  });

  test('delegates remote notification registration to the platform', () async {
    await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
    expect(platform.registrationCalls, 1);
  });

  test('propagates a registration platform failure', () async {
    platform.error = PlatformException(
      code: 'not_initialized',
      message: 'Initialize the Infobip SDK first',
    );
    await expectLater(
      InfobipMobileMessagingHuawei.registerForRemoteNotifications(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'not_initialized',
        ),
      ),
    );
  });

  test('completes when platform initialization succeeds', () async {
    await expectLater(
      InfobipMobileMessagingHuawei.initialize(applicationCode: 'test-code'),
      completes,
    );
  });

  test('propagates a structured platform failure', () async {
    platform.error = PlatformException(
      code: 'initialization_failed',
      message: 'Initialization failed',
    );
    await expectLater(
      InfobipMobileMessagingHuawei.initialize(applicationCode: 'test-code'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'initialization_failed',
        ),
      ),
    );
  });
}
