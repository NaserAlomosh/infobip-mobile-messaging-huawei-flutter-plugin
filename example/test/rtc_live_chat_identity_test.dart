import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/screens/huawei_rtc_screen.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';

import 'support/fake_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeSdk sdk;
  late ExampleController controller;
  final operations = <MethodCall>[];
  var failLookup = false;

  setUp(() async {
    sdk = FakeSdk()..install();
    controller = ExampleController(config: testConfig);
    operations.clear();
    failLookup = false;
    for (final name in [
      'infobip_mobilemessaging_huawei/huawei_rtc/events',
      'infobip_mobilemessaging_huawei/screen_as_camera/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(channel, (operation) async {
      operations.add(operation);
      if (operation.method == 'callApplication') {
        if (failLookup) {
          throw PlatformException(
            code: 'rtc_identity_unavailable',
            message: 'private-response',
          );
        }
        return {
          'id': 'test-call',
          'type': (operation.arguments as Map)['type'],
          'status': 'finished',
        };
      }
      return null;
    });
    await controller.initialize();
    await controller.personalize();
  });

  tearDown(() async {
    controller.dispose();
    await sdk.close();
    for (final name in [
      'infobip_mobilemessaging_huawei/huawei_rtc/events',
      'infobip_mobilemessaging_huawei/screen_as_camera/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> open(
    WidgetTester tester, {
    required bool video,
    bool liveChat = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HuaweiRtcScreen(controller: controller, video: video),
      ),
    );
    await tester.pumpAndSettle();
    if (liveChat) {
      await tester.tap(find.byKey(const ValueKey('rtc-live-chat-identity')));
      await tester.pumpAndSettle();
    }
    final button = find.widgetWithText(
      FilledButton,
      video ? 'Video call' : 'Audio call',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final video in [false, true]) {
    for (final liveChat in [false, true]) {
      testWidgets(
        'video=$video Live Chat identity=$liveChat preserves call request',
        (tester) async {
          await open(tester, video: video, liveChat: liveChat);
          final call =
              operations
                      .singleWhere((e) => e.method == 'callApplication')
                      .arguments
                  as Map;
          expect(
            call['callsConfigurationId'],
            testConfig.rtcCallsConfigurationId,
          );
          expect(call['type'], video ? 'video' : 'audio');
          expect(call.containsKey('identity'), isFalse);
          expect(
            call['liveChatIdentity'],
            liveChat
                ? {
                    'widgetId': testConfig.chatWidgetId,
                    'expectedExternalUserId': testConfig.externalUserId,
                  }
                : null,
          );
          expect(
            operations.where((e) => e.method.contains('Diagnostics')),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'failed native resolution displays sanitized error without fallback',
    (tester) async {
      failLookup = true;
      await open(tester, video: false, liveChat: true);
      expect(
        operations.where((e) => e.method == 'callApplication'),
        hasLength(1),
      );
      expect(find.textContaining('private-response'), findsNothing);
      expect(find.textContaining('rtc_identity_unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
