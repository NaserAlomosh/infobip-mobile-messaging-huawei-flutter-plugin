import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/auth/example_jwt_helper.dart';
import 'package:infobip_mobilemessaging_huawei_example/auth/chat_jwt_helper.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/example_config.dart';
import 'package:infobip_mobilemessaging_huawei_example/screens/test_center_screen.dart';
import 'package:infobip_mobilemessaging_huawei_example/screens/user_screen.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/safe_display.dart';
import 'package:infobip_mobilemessaging_huawei_example/testing/test_session.dart';
import 'support/fake_sdk.dart';

String tokenWith(
  Map<String, Object> claims, {
  Map<String, Object> header = const {
    'alg': 'HS256',
    'typ': 'JWT',
    'kid': 'test-kid',
  },
}) =>
    signTestJwt(header: header, payload: claims, key: List<int>.filled(32, 1));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSdk sdk;
  late ExampleController c;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    sdk = FakeSdk()..install();
    c = ExampleController(config: testConfig);
  });
  tearDown(() async {
    c.dispose();
    await sdk.close();
  });

  test('supplied MM token requires MM headers, issuer, identity and times', () {
    final now = DateTime.now();
    final sec = now.millisecondsSinceEpoch ~/ 1000;
    final claims = <String, Object>{
      'typ': 'Bearer',
      'sub': 'test-user',
      'iss': 'test-application',
      'infobip-api-key': 'test-application',
      'iat': sec,
      'exp': sec + 60,
      'jti': 'test-jti',
    };
    expect(c.validSuppliedJwt(tokenWith(claims), now: now), true);
    for (final key in [
      'typ',
      'sub',
      'iss',
      'infobip-api-key',
      'iat',
      'exp',
      'jti',
    ]) {
      final missing = Map<String, Object>.from(claims)..remove(key);
      expect(
        c.validSuppliedJwt(tokenWith(missing), now: now),
        false,
        reason: key,
      );
    }
    expect(
      c.validSuppliedJwt(tokenWith({...claims, 'iss': 'wrong-app'}), now: now),
      false,
    );
    expect(
      c.validSuppliedJwt(
        tokenWith({...claims, 'sub': 'different-user'}),
        now: now,
      ),
      false,
    );
    expect(
      c.validSuppliedJwt(tokenWith({...claims, 'exp': sec}), now: now),
      false,
    );
    expect(
      c.validSuppliedJwt(tokenWith({...claims, 'iat': sec + 30}), now: now),
      false,
    );
    expect(
      c.validSuppliedJwt(
        tokenWith(
          claims,
          header: {'alg': 'none', 'typ': 'JWT', 'kid': 'test-kid'},
        ),
        now: now,
      ),
      false,
    );
    expect(c.validSuppliedJwt('e30.e30.signature', now: now), false);
  });

  test(
    'supplied Chat JWT stays separate and expires without silent fallback',
    () {
      final now = DateTime.now();
      final chat = ChatJwtHelper.generate(
        widgetId: testConfig.chatWidgetId,
        externalUserId: testConfig.externalUserId,
        keyId: testConfig.chatKeyId,
        secretKey: testConfig.chatSecretKey,
        now: now,
      );
      expect(c.validSuppliedJwt(chat, chat: true, now: now), true);
      expect(c.validSuppliedJwt(chat, now: now), false);
      expect(
        c.validSuppliedJwt(
          chat,
          chat: true,
          now: now.add(const Duration(seconds: 61)),
        ),
        false,
      );
      final mm = ExampleJwtHelper.generate(
        applicationCode: testConfig.applicationCode,
        externalUserId: testConfig.externalUserId,
        kid: testConfig.jwtKid,
        secretKey: testConfig.jwtSecretKey,
      );
      expect(c.validSuppliedJwt(mm, chat: true), false);
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(chat.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
      final noExp = tokenWith(
        Map<String, Object>.from(claims)..remove('exp'),
        header: const {'alg': 'HS256', 'typ': 'JWT'},
      );
      expect(c.validSuppliedJwt(noExp, chat: true, now: now), true);
      expect(
        c.validSuppliedJwt(
          noExp,
          chat: true,
          now: now.add(const Duration(seconds: 15)),
        ),
        false,
      );
    },
  );

  test(
    'identity save uses configured identity and contacts, not cached user',
    () async {
      c.dispose();
      c = ExampleController(
        config: const ExampleConfig(
          applicationCode: 'test-app',
          externalUserId: ' configured-user ',
          firstName: 'Configured',
          lastName: 'User',
          email: 'test@example.invalid',
          phoneNumber: '+000000000',
        ),
      );
      sdk.user = {'externalUserId': 'old-user', 'firstName': 'old'};
      await c.initialize();
      await c.saveConfiguredUser();
      final user =
          (sdk.named('saveUser').single.arguments as Map)['user'] as Map;
      expect(user['externalUserId'], 'configured-user');
      expect(user['emails'], ['test@example.invalid']);
      expect(user['phones'], ['+000000000']);
      expect(user['firstName'], 'Configured');
      expect(sdk.calls.last.method, 'fetchUser');
    },
  );

  test(
    'missing identity blocks writes; active call blocks identity mutations',
    () async {
      c.dispose();
      c = ExampleController(
        config: const ExampleConfig(applicationCode: 'test-app'),
      );
      await c.initialize();
      await expectLater(c.saveConfiguredUser(), throwsA(isA<ExampleBlocked>()));
      expect(await c.personalize(), false);
      expect(sdk.named('personalize'), isEmpty);
      c.dispose();
      c = ExampleController(config: testConfig);
      await c.initialize();
      messenger.setMockMethodCallHandler(
        const MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc'),
        (_) async => {
          'id': 'test-call',
          'type': 'audio',
          'status': 'established',
        },
      );
      expect(await c.personalize(), false);
      await expectLater(c.depersonalizeUser(), throwsA(isA<ExampleBlocked>()));
      expect(sdk.named('depersonalize'), isEmpty);
      expect(c.operationBlocker, contains('Hang up'));
    },
  );

  test(
    'prepared Chat blocks identity change and provider failures are visible',
    () async {
      await c.initialize();
      await c.personalize();
      expect(await c.prepareChat(), true);
      await expectLater(c.depersonalizeUser(), throwsA(isA<ExampleBlocked>()));
      await sdk.event('depersonalized', {});
      await sdk.event('chat_jwt_requested', {
        'requestId': 'audit-request',
        'generation': sdk.chatGeneration,
      });
      expect(sdk.named('rejectChatJwt'), isNotEmpty);
      expect(c.result, contains('Chat JWT provider'));
      expect(c.session.exportLogs(), isNot(contains(testConfig.chatSecretKey)));
    },
  );

  test('safe failures keep numeric service codes but omit raw messages', () {
    final safe = safeFailure(
      'Fetch',
      PlatformException(
        code: '401',
        message: 'Bearer private.jwt secret',
        details: 'private-key',
      ),
    );
    expect(safe, contains('401'));
    expect(safe, isNot(contains('private')));
    expect(
      safeFailure('Fetch', PlatformException(code: 'Bearer private-token')),
      isNot(contains('private-token')),
    );
  });

  test(
    'all catalog prerequisites and unsupported results cannot falsely pass',
    () async {
      expect(c.session.tests, hasLength(71));
      final initialize = c.session.tests.first;
      final empty = ExampleController();
      expect(empty.testBlocker(initialize), contains('infobipApplicationCode'));
      empty.dispose();
      await c.initialize();
      final chatAuth = c.session.tests.firstWhere((t) => t.id == 'AUTH-003');
      expect(c.testBlocker(chatAuth), contains('personalized'));
      final t = c.session.tests.first;
      c.session.begin(t, 'Inbox: Application Code; Chat: jwt');
      c.session.complete(t, TestStatus.BLOCKED, 'Missing configuration');
      c.session.complete(t, TestStatus.PASS, 'Must not pass');
      expect(t.status, TestStatus.BLOCKED);
      c.session.begin(t, 'Inbox: Application Code; Chat: jwt');
      c.session.complete(
        t,
        TestStatus.FAIL,
        'Unexpected failure',
        error: 'operation_failed',
      );
      c.session.complete(t, TestStatus.PASS, 'Must re-run');
      expect(t.status, TestStatus.FAIL);
      final negative = c.session.tests.firstWhere(
        (t) => t.action == 'invalidInbox',
      );
      c.session.begin(negative, 'Inbox: JWT; Chat: jwt');
      c.session.complete(
        negative,
        TestStatus.REQUIRES_MANUAL_VERIFICATION,
        'Expected rejection',
        error: 'inbox_fetch_failed',
      );
      c.session.complete(
        negative,
        TestStatus.PASS,
        'Tester confirmed rejection',
      );
      expect(negative.status, TestStatus.PASS);
    },
  );

  test(
    'restoration retains sanitized evidence and never overwrites a new run',
    () async {
      final old = TestSession();
      final prior = old.tests[1];
      old.begin(prior, 'Inbox: JWT; Chat: jwt');
      old.complete(
        prior,
        TestStatus.REQUIRES_MANUAL_VERIFICATION,
        'Manual evidence',
        error: 'operation_failed',
      );
      final saved = old.report();
      final read = Completer<String>();
      final readStarted = Completer<void>();
      String? written;
      messenger.setMockMethodCallHandler(TestSession.host, (call) async {
        if (call.method == 'deviceInfo') {
          return {'model': 'Test device', 'androidVersion': '14'};
        }
        if (call.method == 'readTestReport') {
          readStarted.complete();
          return read.future;
        }
        if (call.method == 'saveTestReport') {
          written = (call.arguments as Map)['report'] as String;
        }
        return null;
      });
      final restored = TestSession();
      final restoring = restored.restore();
      await readStarted.future;
      restored.begin(
        restored.tests.first,
        'Inbox: Application Code; Chat: installation',
      );
      read.complete(saved);
      await restoring;
      await restored.persist();
      expect(restored.tests.first.status, TestStatus.RUNNING);
      expect(restored.tests[1].actual, 'Manual evidence');
      expect(restored.tests[1].error, 'operation_failed');
      expect(
        (jsonDecode(written!) as Map)['tests'][1]['actualResult'],
        'Manual evidence',
      );
      old.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'User controls cannot save stale identity or expose returned names',
    (tester) async {
      await c.initialize();
      sdk.user = {
        'externalUserId': 'old-user',
        'firstName': 'private-server-name',
      };
      await tester.pumpWidget(MaterialApp(home: UserScreen(controller: c)));
      await tester.tap(find.text('Fetch from server'));
      await tester.pumpAndSettle();
      expect(find.text('private-server-name'), findsNothing);
      await tester.tap(find.text('Save user'));
      await tester.pumpAndSettle();
      expect(
        ((sdk.named('saveUser').single.arguments as Map)['user']
            as Map)['externalUserId'],
        testConfig.externalUserId,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Inbox test records selected JWT mode, not the previous selection',
    (tester) async {
      await c.initialize();
      final t = c.session.tests.firstWhere((t) => t.name == 'JWT: Fetch Inbox');
      await tester.pumpWidget(
        MaterialApp(
          home: TestSectionScreen(
            controller: c,
            category: 'INBOX',
            title: 'Inbox',
          ),
        ),
      );
      final tile = find.text('${t.id} · ${t.name}');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final card = find.ancestor(of: tile, matching: find.byType(Card));
      final run = find.descendant(
        of: card,
        matching: find.widgetWithText(FilledButton, 'Run'),
      );
      await tester.scrollUntilVisible(
        run,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(run);
      await tester.pumpAndSettle();
      expect(t.authMode, 'Inbox: JWT; Chat: jwt');
      expect(t.status, TestStatus.REQUIRES_MANUAL_VERIFICATION);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
