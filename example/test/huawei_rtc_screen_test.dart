import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei_example/screens/huawei_rtc_screen.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/example_controller.dart';
import 'support/fake_sdk.dart';
import 'package:infobip_mobilemessaging_huawei_example/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc');
  const eventName = 'infobip_mobilemessaging_huawei/huawei_rtc/events';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FakeSdk sdk;
  late ExampleController controller;
  late Map<String, Object?> call;
  late Map<String, Object?> controls;
  bool failMute = false;
  Map<String, Object?>? notificationTap;
  Completer<Object?>? pending;
  final operations = <MethodCall>[];
  setUp(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel(
        'infobip_mobilemessaging_huawei/huawei_rtc/incoming_experiment',
      ),
      (_) async => null,
    );
    sdk = FakeSdk()..install();
    controller = ExampleController(config: testConfig);
    call = {
      'id': 'call-1',
      'type': 'video',
      'status': 'established',
      'durationSeconds': 65,
    };
    controls = {
      'callId': 'call-1',
      'microphoneMuted': false,
      'speakerEnabled': false,
      'cameraEnabled': true,
      'cameraOrientation': 'front',
      'audioOutput': 'earpiece',
      'availableAudioOutputs': ['earpiece', 'speaker', 'bluetooth'],
    };
    failMute = false;
    notificationTap = null;
    pending = null;
    operations.clear();
    messenger.setMockMethodCallHandler(
      const MethodChannel(eventName),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel(
        'infobip_mobilemessaging_huawei/screen_as_camera/events',
      ),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(channel, (operation) async {
      operations.add(operation);
      if (operation.method == 'takeNotificationCall') {
        final tap = notificationTap;
        notificationTap = null;
        return tap;
      }
      if (operation.method == 'getActiveCall') return call;
      if (operation.method == 'getScreenAsCameraState') {
        return {
          'callId': 'call-1',
          'state': 'idle',
          'framesBlocked': true,
          'projectionTerminated': true,
          'resourcesReleased': true,
          'cameraOutputRestored': false,
          'error': null,
        };
      }
      if (operation.method == 'getCallControls') return controls;
      if (operation.method == 'setMicrophoneMuted') {
        if (pending != null) return pending!.future;
        if (failMute) {
          throw PlatformException(code: 'rtc_call_failed', message: 'private');
        }
        controls = {
          ...controls,
          'microphoneMuted': (operation.arguments as Map)['enabled'],
        };
      }
      if (operation.method == 'setCameraEnabled') {
        controls = {
          ...controls,
          'cameraEnabled': (operation.arguments as Map)['enabled'],
        };
      }
      if (operation.method == 'switchCamera') {
        controls = {...controls, 'cameraOrientation': 'back'};
      }
      return controls;
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(
      const MethodChannel(
        'infobip_mobilemessaging_huawei/huawei_rtc/incoming_experiment',
      ),
      null,
    );
    controller.dispose();
    await sdk.close();
    messenger.setMockMethodCallHandler(const MethodChannel(eventName), null);
    messenger.setMockMethodCallHandler(
      const MethodChannel(
        'infobip_mobilemessaging_huawei/screen_as_camera/events',
      ),
      null,
    );
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: HuaweiRtcScreen(controller: controller, video: true)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mute microphone'), 200);
  }

  testWidgets(
    'experimental section preserves call UI and truthful idle state',
    (tester) async {
      await open(tester);
      expect(
        find.text('Experimental: Screen as Camera (Android 10+)'),
        findsOneWidget,
      );
      expect(find.text('Start Screen as Camera'), findsOneWidget);
      expect(find.text('Stop Screen as Camera'), findsOneWidget);
      expect(find.text('Hang up'), findsOneWidget);
      expect(find.textContaining('projection ended: true'), findsOneWidget);
    },
  );

  OutlinedButton button(WidgetTester tester, String text) =>
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, text));
  Future<void> event(
    WidgetTester tester,
    String type,
    Map<String, Object?> next,
  ) async {
    final completed = Completer<void>();
    messenger.handlePlatformMessage(
      eventName,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': type,
        'call': next,
        'nativeErrorCode': null,
        'sequence': 2,
      }),
      (_) => completed.complete(),
    );
    await completed.future;
    await tester.pumpAndSettle();
  }

  testWidgets(
    'notification return opens active call once and reuses its existing route',
    (tester) async {
      await tester.pumpWidget(ExampleApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byType(HuaweiRtcScreen), findsNothing);
      notificationTap = call;
      await event(tester, 'returnToCall', call);
      expect(find.byType(HuaweiRtcScreen), findsOneWidget);
      final existing = tester.state(find.byType(HuaweiRtcScreen));
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Overlay')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      notificationTap = call;
      await event(tester, 'returnToCall', call);
      expect(find.text('Overlay'), findsNothing);
      expect(tester.state(find.byType(HuaweiRtcScreen)), same(existing));
      expect(operations.where((o) => o.method == 'callApplication'), isEmpty);
      notificationTap = null;
      await event(tester, 'returnToCall', call);
      expect(tester.state(find.byType(HuaweiRtcScreen)), same(existing));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'notification return waits for resumed app before constructing video views',
    (tester) async {
      await tester.pumpWidget(ExampleApp(controller: controller));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      notificationTap = call;
      await event(tester, 'returnToCall', call);
      expect(find.byType(HuaweiRtcScreen), findsNothing);
      expect(notificationTap, isNotNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(HuaweiRtcScreen), findsOneWidget);
      expect(notificationTap, isNull);
      expect(operations.where((o) => o.method == 'callApplication'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'initial notification return restores screen without starting another call',
    (tester) async {
      notificationTap = call;
      await tester.pumpWidget(ExampleApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byType(HuaweiRtcScreen), findsOneWidget);
      expect(operations.where((o) => o.method == 'callApplication'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'connected controls render duration and camera state; failed mute stays unmuted',
    (tester) async {
      await open(tester);
      expect(find.text('Call duration: 01:05'), findsOneWidget);
      expect(button(tester, 'Mute microphone').onPressed, isNotNull);
      expect(find.byType(HuaweiRtcVideoView), findsNWidgets(2));
      failMute = true;
      await tester.tap(find.text('Mute microphone'));
      await tester.pumpAndSettle();
      expect(find.text('Unmute microphone'), findsNothing);
      expect(button(tester, 'Mute microphone').onPressed, isNotNull);
      failMute = false;
      notificationTap = null;
      await tester.tap(find.text('Mute microphone'));
      await tester.pumpAndSettle();
      expect(find.text('Unmute microphone'), findsOneWidget);
      await tester.tap(find.text('Camera off'));
      await tester.pumpAndSettle();
      expect(button(tester, 'Switch camera').onPressed, isNull);
      expect(find.text('Camera on'), findsOneWidget);
      expect(find.byType(HuaweiRtcVideoView), findsNWidgets(2));
      await tester.tap(find.text('Camera on'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch camera'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Facing: back'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'ringing audio call disables controls and camera; unavailable earpiece disables speaker off',
    (tester) async {
      call = {
        ...call,
        'type': 'audio',
        'status': 'ringing',
        'durationSeconds': 0,
      };
      controls = {
        ...controls,
        'cameraEnabled': false,
        'speakerEnabled': true,
        'audioOutput': 'speaker',
        'availableAudioOutputs': ['speaker'],
      };
      await open(tester);
      expect(button(tester, 'Mute microphone').onPressed, isNull);
      expect(button(tester, 'Camera on').onPressed, isNull);
      expect(find.text('Call duration: 00:00'), findsOneWidget);
      call = {...call, 'status': 'established'};
      await event(tester, 'established', call);
      expect(button(tester, 'Mute microphone').onPressed, isNotNull);
      expect(button(tester, 'Speaker off').onPressed, isNull);
      expect(button(tester, 'Camera on').onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pending control disables actions; replacement discards old response and terminal duration freezes',
    (tester) async {
      await open(tester);
      pending = Completer<Object?>();
      await tester.tap(find.text('Mute microphone'));
      await tester.pump();
      expect(button(tester, 'Mute microphone').onPressed, isNull);
      call = {...call, 'id': 'call-2', 'durationSeconds': 3};
      controls = {...controls, 'callId': 'call-2'};
      await event(tester, 'state', call);
      pending!.complete({
        ...controls,
        'callId': 'call-1',
        'microphoneMuted': true,
      });
      await tester.pumpAndSettle();
      expect(find.text('Unmute microphone'), findsNothing);
      expect(find.text('Call duration: 00:03'), findsOneWidget);
      call = {...call, 'status': 'finished', 'durationSeconds': 4};
      await event(tester, 'finished', call);
      final count = operations.length;
      await tester.pump(const Duration(seconds: 3));
      expect(operations.length, count);
      expect(find.text('Call duration: 00:04'), findsOneWidget);
      expect(button(tester, 'Mute microphone').onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'incoming experiment offers explicit camera acceptance with unknown offer type',
    (tester) async {
      sdk.user = {'externalUserId': testConfig.externalUserId};
      await controller.initialize();
      final incomingState = <String, Object?>{
        'state': 'registrationRequested',
        'family': 'application',
        'handle': null,
        'audioSupported': false,
        'videoSupported': false,
        'registrationAttempted': true,
        'reason': null,
      };
      messenger.setMockMethodCallHandler(channel, (operation) async {
        operations.add(operation);
        if (operation.method == 'getActiveCall') return null;
        if (operation.method == 'startForegroundIncomingExperiment') {
          return incomingState;
        }
        if (operation.method == 'acceptExperimentalIncomingCall') {
          return {
            'id': 'incoming-native',
            'type': 'video',
            'status': 'connecting',
          };
        }
        return null;
      });
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: HuaweiRtcScreen(controller: controller, video: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        operations.where(
          (o) => o.method == 'startForegroundIncomingExperiment',
        ),
        isEmpty,
      );
      await tester.scrollUntilVisible(
        find.text('Start foreground incoming experiment'),
        100,
      );
      await tester.tap(find.text('Start foreground incoming experiment'));
      await tester.pumpAndSettle();
      expect(
        operations
            .where((o) => o.method == 'startForegroundIncomingExperiment')
            .length,
        1,
      );
      expect(
        find.textContaining('Registration requested / waiting'),
        findsOneWidget,
      );
      final done = Completer<void>();
      messenger.handlePlatformMessage(
        'infobip_mobilemessaging_huawei/huawei_rtc/incoming_experiment',
        const StandardMethodCodec().encodeSuccessEnvelope({
          ...incomingState,
          'state': 'invitation',
          'handle': 'opaque',
          'audioSupported': true,
          'videoSupported': true,
          'diagnostics': [
            {
              'sequence': 1,
              'timestampMillis': 1000,
              'event': 'invitation_callback',
              'token': 'must-never-display',
              'identity': 'must-never-display',
            },
            {
              'sequence': 2,
              'timestampMillis': 1100,
              'event': 'invitation_published',
            },
          ],
        }),
        (_) => done.complete(),
      );
      await done.future;
      await tester.pumpAndSettle();
      expect(
        find.text('Incoming call — offered media type unknown'),
        findsOneWidget,
      );
      expect(find.text('Accept Audio'), findsOneWidget);
      expect(find.text('Accept with camera'), findsOneWidget);
      expect(find.text('Incoming diagnostics — debug only'), findsOneWidget);
      expect(
        find.textContaining('native #1 invitation_callback'),
        findsOneWidget,
      );
      expect(
        find.textContaining('flutter_event_received native_sequence=2'),
        findsOneWidget,
      );
      expect(find.textContaining('1970-01-01T00:00:01.000Z'), findsOneWidget);
      expect(find.textContaining('must-never-display'), findsNothing);
      expect(find.text('Decline'), findsOneWidget);
      await tester.ensureVisible(find.text('Accept with camera'));
      await tester.tap(find.text('Accept with camera'));
      await tester.pumpAndSettle();
      expect(
        operations
            .where((o) => o.method == 'acceptExperimentalIncomingCall')
            .single
            .arguments,
        {'handle': 'opaque', 'video': true},
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(
        operations
            .where((o) => o.method == 'closeForegroundIncomingExperimentScreen')
            .length,
        1,
      );
    },
  );
}
