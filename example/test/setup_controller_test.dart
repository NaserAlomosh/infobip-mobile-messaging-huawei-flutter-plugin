import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/example_config.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/feature_readiness.dart';
import 'support/fake_sdk.dart';
import 'jwt_helper_test.dart' show decodePart;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSdk sdk;
  late ExampleController c;
  setUp(() {
    sdk = FakeSdk()..install();
    c = ExampleController(config: testConfig);
  });
  tearDown(() async {
    c.dispose();
    await sdk.close();
  });

  test('initialization required before Next and any feature', () async {
    expect(c.canLeaveApplicationSetup, isFalse);
    for (final f in ExampleFeature.values) {
      expect(c.readiness(f).isReady, isFalse);
    }
    sdk.initializeError = PlatformException(
      code: 'initialization_failed',
      message: 'private',
    );
    await c.initialize();
    expect(c.initialized, isFalse);
    expect(c.canLeaveApplicationSetup, isFalse);
    sdk.initializeError = null;
    await c.initialize();
    expect(c.canLeaveApplicationSetup, isTrue);
    expect(sdk.named('getInstallation'), isNotEmpty);
    expect(sdk.named('fetchInstallation'), isNotEmpty);
    expect(sdk.named('getUser'), isNotEmpty);
    expect(sdk.named('fetchUser'), isNotEmpty);
  });
  test(
    'personalize configured identity only, refresh and invalidate after depersonalize',
    () async {
      await c.initialize();
      expect(c.personalized, isFalse);
      await c.personalize();
      expect(c.personalized, isTrue);
      expect(c.readiness(ExampleFeature.push).isReady, isTrue);
      final args = sdk.named('personalize').single.arguments as Map;
      expect((args['userIdentity'] as Map)['externalUserId'], 'test-user');
      expect(args['userAttributes'], isNull);
      await sdk.event('depersonalized', {});
      expect(c.personalized, isFalse);
      expect(c.readiness(ExampleFeature.push).isReady, isFalse);
    },
  );
  test('push registration callback alone does not prove readiness', () async {
    sdk.installation!.remove('pushRegistrationId');
    sdk.installation!.remove('pushServiceToken');
    sdk.permissions['notifications'] = false;
    await c.initialize();
    await c.personalize();
    await c.registerPush();
    expect(sdk.named('registerForRemoteNotifications'), hasLength(1));
    expect(sdk.permissionCalls.last.arguments, {'group': 'push'});
    expect(c.pushEnabled, isTrue);
    expect(c.readiness(ExampleFeature.push).isReady, isFalse);
    sdk.installation!['pushRegistrationId'] = 'test-id';
    sdk.installation!['pushServiceToken'] = 'test-token';
    sdk.permissions['notifications'] = true;
    await c.refresh();
    expect(c.readiness(ExampleFeature.push).isReady, isTrue);
    sdk.installation!['isPushRegistrationEnabled'] = false;
    await c.refresh();
    expect(c.readiness(ExampleFeature.push).isReady, isFalse);
  });
  test(
    'missing optional config does not block Next, User or Application Code Inbox',
    () async {
      c.dispose();
      c = ExampleController(
        config: const ExampleConfig(
          applicationCode: 'test-app',
          externalUserId: 'test-user',
        ),
      );
      await c.initialize();
      expect(c.canOpenFeatures, isTrue);
      expect(c.readiness(ExampleFeature.user).isReady, isTrue);
      expect(c.readiness(ExampleFeature.installation).isReady, isTrue);
      expect(c.readiness(ExampleFeature.inbox).isReady, isTrue);
      c.selectInboxAuth(InboxAuth.jwt);
      expect(c.readiness(ExampleFeature.inbox).isReady, isFalse);
      expect(
        c.readiness(ExampleFeature.inbox).missing.map((r) => r.title),
        contains('kid'),
      );
      expect(c.readiness(ExampleFeature.chat).isReady, isFalse);
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isFalse);
      expect(c.readiness(ExampleFeature.rtcVideo).isReady, isFalse);
    },
  );
  test('missing external user blocks both Inbox paths', () async {
    c.dispose();
    c = ExampleController(
      config: const ExampleConfig(applicationCode: 'test-app'),
    );
    await c.initialize();
    for (final auth in InboxAuth.values) {
      expect(c.readiness(ExampleFeature.inbox, auth: auth).isReady, isFalse);
    }
  });
  test(
    'Inbox JWT request always freshly signs; never sets global token',
    () async {
      await c.initialize();
      c.selectInboxAuth(InboxAuth.jwt);
      expect(c.readiness(ExampleFeature.inbox).isReady, isTrue);
      await c.fetchInbox();
      await c.fetchInbox();
      final tokens = sdk
          .named('fetchInbox')
          .map((call) => (call.arguments as Map)['jwt'] as String)
          .toList();
      expect(
        decodePart(tokens[0], 1)['jti'],
        isNot(decodePart(tokens[1], 1)['jti']),
      );
      expect(sdk.named('setJwt'), isEmpty);
      await c.testJwt();
      expect(c.jwtMetadata!.ttl.inSeconds, 15);
      expect(c.jwtMetadata.toString(), isNot(contains(tokens[0])));
    },
  );
  test(
    'Application Code clears global JWT first, passes no explicit JWT, propagates failure',
    () async {
      await c.initialize();
      await c.fetchInbox();
      final clear = sdk.named('setJwt').single;
      final fetch = sdk.named('fetchInbox').single;
      expect(sdk.calls.indexOf(clear), lessThan(sdk.calls.indexOf(fetch)));
      expect((clear.arguments as Map)['jwt'], isNull);
      expect((fetch.arguments as Map)['jwt'], isNull);
      sdk.failClearJwt = true;
      await expectLater(c.fetchInbox(), throwsA(isA<PlatformException>()));
      expect(sdk.named('fetchInbox'), hasLength(1));
    },
  );
  test(
    'Chat requires matching personalized subject and separate signing config',
    () async {
      await c.initialize();
      expect(c.readiness(ExampleFeature.chat).isReady, isFalse);
      await c.personalize();
      expect(c.readiness(ExampleFeature.chat).isReady, isTrue);
      expect(await c.prepareChat(), isTrue);
      for (var i = 0; i < 2; i++) {
        await sdk.event('chat_jwt_requested', {
          'requestId': 'test-$i',
          'generation': sdk.chatGeneration,
        });
      }
      final tokens = sdk
          .named('resolveChatJwt')
          .map((call) => (call.arguments as Map)['jwt'] as String)
          .toList();
      expect(tokens, hasLength(2));
      expect(
        decodePart(tokens[0], 1)['jti'],
        isNot(decodePart(tokens[1], 1)['jti']),
      );
      expect(decodePart(tokens[0], 1)['iss'], 'test-widget');
      expect(sdk.named('setJwt'), isEmpty);
    },
  );
  test('installation Chat explicitly selected needs no signing key', () async {
    c.dispose();
    c = ExampleController(
      config: const ExampleConfig(
        applicationCode: 'test-app',
        chatAuth: 'installation',
      ),
    );
    await c.initialize();
    expect(c.readiness(ExampleFeature.chat).isReady, isTrue);
    await c.prepareChat();
    expect(sdk.named('setChatJwtProvider'), isEmpty);
  });
  test(
    'RTC requires actual microphone, video camera, Nearby and fallback identity',
    () async {
      await c.initialize();
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isTrue);
      expect(c.readiness(ExampleFeature.rtcVideo).isReady, isTrue);
      sdk.permissions['camera'] = false;
      await c.refresh();
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isTrue);
      expect(c.readiness(ExampleFeature.rtcVideo).isReady, isFalse);
      sdk.permissions['microphone'] = false;
      await c.requestRtcPermissions(video: false);
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isFalse);
      sdk.permissions['microphone'] = true;
      sdk.permissions['nearbyDevices'] = false;
      await c.refresh();
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isFalse);
      sdk.permissions['nearbyDevices'] = true;
      sdk.installation!.remove('pushRegistrationId');
      await c.refresh();
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isFalse);
    },
  );
  test(
    'RTC explicit identity works without installation registration',
    () async {
      c.dispose();
      c = ExampleController(
        config: const ExampleConfig(
          applicationCode: 'test-app',
          rtcCallsConfigurationId: 'test-calls',
          rtcIdentity: 'test-identity',
        ),
      );
      sdk.installation = null;
      await c.initialize();
      expect(c.installationAvailable, isFalse);
      expect(c.readiness(ExampleFeature.rtcAudio).isReady, isTrue);
      expect(c.readiness(ExampleFeature.push).isReady, isFalse);
    },
  );
}
