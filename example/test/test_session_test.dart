import 'dart:convert';
import 'package:infobip_mobilemessaging_huawei_example/auth/example_jwt_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/app.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';
import 'package:infobip_mobilemessaging_huawei_example/testing/test_session.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/example_config.dart';
import 'support/fake_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'report persists explicit manual outcomes and restores interrupted runs safely',
    () async {
      String? saved;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(TestSession.host, (call) async {
        if (call.method == 'saveTestReport') {
          saved = (call.arguments as Map)['report'] as String;
        }
        if (call.method == 'readTestReport') return saved;
        if (call.method == 'deviceInfo') {
          return {
            'model': 'Test Huawei',
            'androidVersion': '14',
            'huaweiConfigured': true,
          };
        }
        return null;
      });
      final s = TestSession();
      final t = s.tests.first;
      s.begin(t, 'Application Code');
      s.complete(
        t,
        TestStatus.REQUIRES_MANUAL_VERIFICATION,
        'SDK responded; peer confirmation pending.',
      );
      expect(s.count(TestStatus.PASS), 0);
      s.complete(t, TestStatus.PASS, 'Tester confirmed expected behavior.');
      await s.persist();
      final report = jsonDecode(saved!) as Map;
      expect((report['tests'] as List).first['status'], 'PASS');
      expect((report['tests'] as List).first['durationMs'], isA<int>());
      expect(saved, isNot(contains('secretKey')));
      final restored = TestSession();
      await restored.restore();
      expect(restored.tests.first.status, TestStatus.PASS);
      expect(restored.deviceModel, 'Test Huawei');
      final unsupported = restored.tests.firstWhere(
        (t) => t.status == TestStatus.UNSUPPORTED,
      );
      restored.complete(
        unsupported,
        TestStatus.PASS,
        'Cannot overwrite unsupported',
      );
      expect(unsupported.status, TestStatus.UNSUPPORTED);
      s.dispose();
      restored.dispose();
      messenger.setMockMethodCallHandler(TestSession.host, null);
    },
  );

  test(
    'supplied JWT accepts only matching unexpired claims; separate Chat token',
    () {
      final token = ExampleJwtHelper.generate(
        applicationCode: testConfig.applicationCode,
        externalUserId: testConfig.externalUserId,
        kid: testConfig.jwtKid,
        secretKey: testConfig.jwtSecretKey,
      );
      final c = ExampleController(
        config: ExampleConfig(
          applicationCode: testConfig.applicationCode,
          externalUserId: 'test-user',
          jwtToken: token,
        ),
      );
      expect(c.jwtConfigReady, true);
      expect(c.generateInboxJwt(), token);
      expect(c.validSuppliedJwt('private.invalid.token'), false);
      expect(c.config.chatJwtToken, isEmpty);
      c.dispose();
    },
  );

  testWidgets(
    'center exposes guided sections; initialize never automatically passes',
    (tester) async {
      final sdk = FakeSdk()..install();
      final c = ExampleController(config: testConfig);
      await tester.pumpWidget(ExampleApp(controller: c));
      expect(find.text('Huawei SDK Test Center'), findsOneWidget);
      expect(find.textContaining(testConfig.jwtSecretKey), findsNothing);
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SDK-001 · Initialize SDK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Run'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      expect(c.initialized, true);
      expect(
        c.session.tests.first.status,
        TestStatus.REQUIRES_MANUAL_VERIFICATION,
      );
      expect(c.session.count(TestStatus.PASS), 0);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await sdk.close();
    },
  );
}
