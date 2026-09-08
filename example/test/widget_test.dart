import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/app.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/example_config.dart';
import 'package:infobip_mobilemessaging_huawei_example/screens/inbox_screen.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/feature_readiness.dart';
import 'support/fake_sdk.dart';
import 'jwt_helper_test.dart' show decodePart;

void main() {
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

  testWidgets(
    'missing app config disables initialize and Next; credentials never rendered',
    (tester) async {
      c.dispose();
      c = ExampleController(config: const ExampleConfig());
      await tester.pumpWidget(ExampleApp(controller: c));
      expect(find.text('Application Setup'), findsOneWidget);
      expect(
        find.textContaining('provide INFOBIP_APPLICATION_CODE'),
        findsOneWidget,
      );
      for (final button in tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets(
    'exact three primary stages, Next after init and no JWT config required',
    (tester) async {
      c.dispose();
      c = ExampleController(
        config: const ExampleConfig(applicationCode: 'test-application'),
      );
      await tester.pumpWidget(ExampleApp(controller: c));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('next')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Initialize SDK'));
      await tester.pumpAndSettle();
      expect(find.text('SDK Initialized ✅'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('User & Installation Setup'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      // All seven cards exist and independently disable actions.
      for (final feature in ExampleFeature.values) {
        final finder = find.byKey(ValueKey('open-${feature.title}'));
        await tester.scrollUntilVisible(finder, 250);
        final button = tester.widget<FilledButton>(finder);
        expect(
          button.onPressed != null,
          feature == ExampleFeature.user ||
              feature == ExampleFeature.installation,
        );
      }
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('User & Installation Setup'), findsOneWidget);
    },
  );
  testWidgets('ready dashboard opens existing User screen and masks config', (
    tester,
  ) async {
    await c.initialize();
    await c.personalize();
    await tester.pumpWidget(ExampleApp(controller: c));
    expect(find.textContaining(testConfig.applicationCode), findsNothing);
    expect(find.textContaining(testConfig.jwtSecretKey), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final userButton = find.byKey(const ValueKey('open-User'));
    await tester.scrollUntilVisible(userButton, 250);
    await tester.tap(userButton);
    await tester.pumpAndSettle();
    expect(find.text('Read user'), findsOneWidget);
  });
  testWidgets(
    'JWT Inbox fetch and seen refresh each generate fresh token; seen API unchanged',
    (tester) async {
      sdk.inboxMessages = [
        {
          'messageId': 'test-message',
          'topic': 'test-topic',
          'seen': false,
          'title': 'Test message',
        },
      ];
      await c.initialize();
      c.selectInboxAuth(InboxAuth.jwt);
      await tester.pumpWidget(MaterialApp(home: InboxScreen(controller: c)));
      await tester.tap(find.widgetWithText(FilledButton, 'Fetch Inbox'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Mark seen'), 200);
      await tester.tap(find.text('Mark seen'));
      await tester.pumpAndSettle();
      final tokens = sdk
          .named('fetchInbox')
          .map((call) => (call.arguments as Map)['jwt'] as String)
          .toList();
      expect(tokens, hasLength(2));
      expect(
        decodePart(tokens[0], 1)['jti'],
        isNot(decodePart(tokens[1], 1)['jti']),
      );
      expect(sdk.named('setInboxMessagesSeen').single.arguments, {
        'externalUserId': 'test-user',
        'messageIds': ['test-message'],
      });
      for (final token in tokens) {
        expect(find.textContaining(token), findsNothing);
      }
    },
  );
  testWidgets('JWT selection disables fetch when signing config missing', (
    tester,
  ) async {
    c.dispose();
    c = ExampleController(
      config: const ExampleConfig(
        applicationCode: 'test-app',
        externalUserId: 'test-user',
      ),
    );
    await c.initialize();
    await tester.pumpWidget(MaterialApp(home: InboxScreen(controller: c)));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(DropdownButton<InboxAuth>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auth: JWT').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('Missing: kid'), findsOneWidget);
  });
}
