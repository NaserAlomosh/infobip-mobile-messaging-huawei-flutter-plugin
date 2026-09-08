import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/example_config.dart';
import 'package:infobip_mobilemessaging_huawei_example/platform/example_permissions.dart';

// Synthetic test fixtures; never usable as account credentials.
const testConfig = ExampleConfig(
  applicationCode: 'test-application',
  externalUserId: 'test-user',
  jwtKid: 'test-kid',
  jwtSecretKey:
      '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
  rtcCallsConfigurationId: 'test-calls',
  chatAuth: 'jwt',
  chatWidgetId: 'test-widget',
  chatKeyId: 'test-chat-key',
  chatSecretKey: 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
);

class FakeSdk {
  static const methods = MethodChannel(
    'com.infobip.mobilemessaging.huawei/methods',
  );
  static const events = MethodChannel(
    'com.infobip.mobilemessaging.huawei/events',
  );
  final calls = <MethodCall>[];
  final permissionCalls = <MethodCall>[];
  Map<String, Object?>? installation = {
    'pushRegistrationId': 'test-installation',
    'pushServiceToken': 'test-hms',
    'isPushRegistrationEnabled': true,
    'notificationsEnabled': true,
    'deviceModel': 'Test device',
    'isPrimaryDevice': true,
  };
  Map<String, Object?> user = {};
  Map<String, bool> permissions = {
    'microphone': true,
    'camera': true,
    'nearbyDevices': true,
    'notifications': true,
  };
  Object? initializeError;
  bool failClearJwt = false;
  int chatGeneration = 0;
  List<Object?> inboxMessages = [];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(ExamplePermissions.channel, (
      call,
    ) async {
      permissionCalls.add(call);
      return permissions;
    });
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          if (initializeError != null) throw initializeError!;
          return null;
        case 'getInstallation':
        case 'fetchInstallation':
          return installation;
        case 'getUser':
        case 'fetchUser':
          return user;
        case 'personalize':
          final identity = (call.arguments as Map)['userIdentity'] as Map;
          user = {'externalUserId': identity['externalUserId']};
          return user;
        case 'depersonalize':
          user = {};
          return null;
        case 'setJwt':
          if (failClearJwt) throw PlatformException(code: 'native_error');
          return null;
        case 'fetchInbox':
          return {
            'countTotal': inboxMessages.length,
            'countUnread': inboxMessages.length,
            'countTotalFiltered': inboxMessages.length,
            'countUnreadFiltered': inboxMessages.length,
            'messages': inboxMessages,
          };
        case 'setChatJwtProvider':
          chatGeneration++;
          return null;
        case 'isChatAvailable':
          return true;
        default:
          return null;
      }
    });
  }

  List<MethodCall> named(String name) =>
      calls.where((c) => c.method == name).toList();
  Future<void> event(String type, Map<String, Object?> payload) async {
    await messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'version': 1,
        'type': type,
        'timestamp': 1,
        'payload': payload,
      }),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> close() async {
    await InfobipMobileMessagingHuawei.cleanup();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
    messenger.setMockMethodCallHandler(ExamplePermissions.channel, null);
  }
}
