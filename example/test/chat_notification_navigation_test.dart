import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei_example/app.dart';
import 'package:infobip_mobilemessaging_huawei_example/screens/chat_screen.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';
import 'support/fake_sdk.dart';

void main() {
  late FakeSdk sdk;
  late ExampleController controller;
  setUp(() {
    sdk = FakeSdk()..install();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(
            'infobip_mobilemessaging_huawei/huawei_rtc/events',
          ),
          (_) async => null,
        );
    sdk.user = {'externalUserId': testConfig.externalUserId};
    controller = ExampleController(config: testConfig);
  });
  tearDown(() async {
    controller.dispose();
    await sdk.close();
  });
  Map<String, Object?> request(String id, [String? thread]) => {
    'correlationId': id,
    'threadId': thread,
  };
  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(ExampleApp(controller: controller));
    await tester.pumpAndSettle();
  }

  void wake() => unawaited(
    sdk.event(
      'chat_notification_navigation_requested',
      Map<String, Object?>.from(sdk.chatNavigation.first),
    ),
  );

  for (final thread in <String?>[null, 'existing-thread']) {
    testWidgets(
      'cold startup opens embedded Chat and acknowledges target $thread',
      (tester) async {
        sdk.chatNavigation.add(request('cold-tap', thread));
        await mount(tester);
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(find.byType(InfobipHuaweiChatView), findsOneWidget);
        expect(sdk.chatNavigation, isEmpty);
        expect(
          sdk.named('acknowledgeChatNotificationNavigation').single.arguments,
          'cold-tap',
        );
        expect(sdk.named('showChat'), isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'foreground event opens Chat and duplicate wakes reuse the open route',
    (tester) async {
      await mount(tester);
      expect(find.byType(ChatScreen), findsNothing);
      sdk.chatNavigation.add(request('foreground', 'thread'));
      wake();
      await tester.pumpAndSettle();
      final first = tester.state(find.byType(ChatScreen));
      sdk.chatNavigation.add(request('second', 'thread'));
      final repeated = Map<String, Object?>.from(sdk.chatNavigation.first);
      unawaited(sdk.event('chat_notification_navigation_requested', repeated));
      unawaited(sdk.event('chat_notification_navigation_requested', repeated));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ChatScreen)), same(first));
      expect(sdk.named('acknowledgeChatNotificationNavigation').length, 2);
      expect(sdk.named('showChat'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('notification reuses a manually opened named Chat route', (
    tester,
  ) async {
    await mount(tester);
    await controller.initialize();
    expect(await controller.prepareChat(), isTrue);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: ChatScreen.routeName),
          builder: (_) => ChatScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.state(find.byType(ChatScreen));
    sdk.chatNavigation.add(request('manual-reuse', 'thread'));
    wake();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ChatScreen)), same(original));
    expect(sdk.chatNavigation, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'failed SDK setup retains the first request without a retry loop',
    (tester) async {
      sdk.initializeError = PlatformException(
        code: 'test_initialization_failure',
      );
      sdk.chatNavigation.add(request('setup-pending'));
      await mount(tester);
      expect(find.byType(ChatScreen), findsNothing);
      expect(sdk.chatNavigation, hasLength(1));
      expect(sdk.named('initialize'), hasLength(1));
      sdk.initializeError = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(sdk.chatNavigation, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'background request waits for resume instead of acknowledging early',
    (tester) async {
      await mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      sdk.chatNavigation.add(request('background', 'thread'));
      wake();
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsNothing);
      expect(sdk.chatNavigation, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(sdk.chatNavigation, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'failed acknowledgement is retried without pushing a duplicate Chat',
    (tester) async {
      sdk.chatNavigation.add(request('retry', 'thread'));
      sdk.failChatNavigationAck = true;
      await mount(tester);
      final first = tester.state(find.byType(ChatScreen));
      expect(sdk.chatNavigation, hasLength(1));
      sdk.failChatNavigationAck = false;
      wake();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ChatScreen)), same(first));
      expect(sdk.chatNavigation, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('native mode informational tap does not open an embedded route', (
    tester,
  ) async {
    await mount(tester);
    unawaited(
      sdk.event('notification_tapped', {
        'message': {'messageId': 'native', 'chat': true},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    expect(sdk.named('acknowledgeChatNotificationNavigation'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
