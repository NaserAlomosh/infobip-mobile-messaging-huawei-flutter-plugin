import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc');
  const name = 'infobip_mobilemessaging_huawei/huawei_rtc/incoming_experiment';
  const eventMethods = MethodChannel(name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final operations = <MethodCall>[];
  final state = <String, Object?>{
    'state': 'registrationRequested',
    'family': 'application',
    'handle': null,
    'audioSupported': false,
    'videoSupported': false,
    'registrationAttempted': true,
    'reason': null,
  };
  setUp(() {
    operations.clear();
    messenger.setMockMethodCallHandler(methods, (operation) async {
      operations.add(operation);
      if (operation.method == 'startForegroundIncomingExperiment') return state;
      if (operation.method == 'acceptExperimentalIncomingCall') {
        return {'id': 'native-call', 'type': 'audio', 'status': 'connecting'};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(eventMethods, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(eventMethods, null);
  });
  test('explicit start uses existing Live Chat identity request', () async {
    final event = await HuaweiRtc.startForegroundIncomingExperiment(
      HuaweiRtcLiveChatIdentity(
        widgetId: 'widget',
        expectedExternalUserId: 'expected',
      ),
    );
    expect(operations.single.method, 'startForegroundIncomingExperiment');
    expect(operations.single.arguments, {
      'widgetId': 'widget',
      'expectedExternalUserId': 'expected',
    });
    expect(event.state, 'registrationRequested');
    expect(event.handle, isNull);
    expect(event.registrationAttempted, isTrue);
  });
  test(
    'debug diagnostics allowlist drops payloads and malformed entries without losing state',
    () async {
      messenger.setMockMethodCallHandler(
        methods,
        (_) async => {
          ...state,
          'diagnostics': [
            {
              'sequence': 1,
              'timestampMillis': 1000,
              'event': 'token_request_returned',
              'token': 'private-token',
              'identity': 'private-identity',
            },
            {
              'sequence': 2,
              'timestampMillis': 2000,
              'event': 'call_error',
              'errorCode': 1002,
            },
            {
              'sequence': 3,
              'timestampMillis': 3000,
              'event': 'private-payload',
            },
            {
              'sequence': 'private',
              'timestampMillis': 4000,
              'event': 'invitation_callback',
            },
          ],
        },
      );
      final event = await HuaweiRtc.startForegroundIncomingExperiment(
        HuaweiRtcLiveChatIdentity(
          widgetId: 'widget',
          expectedExternalUserId: 'expected',
        ),
      );
      expect(event.state, 'registrationRequested');
      expect(event.diagnostics.map((e) => e.event), [
        'token_request_returned',
        'call_error',
      ]);
      expect(event.diagnostics.last.errorCode, 1002);
      expect(event.diagnostics.first.timestampMillis, 1000);
      expect(() => event.diagnostics.clear(), throwsUnsupportedError);
    },
  );
  test(
    'accept and decline send opaque handle and reuse existing call model',
    () async {
      final call = await HuaweiRtc.acceptExperimentalIncomingCall(
        handle: 'opaque',
      );
      expect(call.type, HuaweiRtcCallType.audio);
      expect(call.status, HuaweiRtcCallStatus.connecting);
      expect(operations.last.arguments, {'handle': 'opaque', 'video': false});
      await HuaweiRtc.declineExperimentalIncomingCall(handle: 'opaque');
      expect(operations.last.arguments, {'handle': 'opaque'});
      await HuaweiRtc.closeForegroundIncomingExperimentScreen();
      expect(operations.last.method, 'closeForegroundIncomingExperimentScreen');
    },
  );
  test(
    'explicit camera acceptance forwards video without inferring offer type',
    () async {
      messenger.setMockMethodCallHandler(methods, (operation) async {
        operations.add(operation);
        if (operation.method == 'acceptExperimentalIncomingCall') {
          return {'id': 'video-call', 'type': 'video', 'status': 'connecting'};
        }
        return {...state, 'videoSupported': true, 'offeredCallType': 'unknown'};
      });
      final invitation = await HuaweiRtc.startForegroundIncomingExperiment(
        HuaweiRtcLiveChatIdentity(
          widgetId: 'widget',
          expectedExternalUserId: 'expected',
        ),
      );
      expect(invitation.videoSupported, isTrue);
      expect(invitation.offeredCallType, 'unknown');
      final call = await HuaweiRtc.acceptExperimentalIncomingCall(
        handle: 'opaque',
        video: true,
      );
      expect(call.type, HuaweiRtcCallType.video);
      expect(operations.last.arguments, {'handle': 'opaque', 'video': true});
    },
  );
  test('errors use sanitized existing exception mapping', () async {
    messenger.setMockMethodCallHandler(methods, (_) async {
      throw PlatformException(
        code: 'rtc_invalid_state',
        message: 'private registration token',
        details: 'private',
      );
    });
    await expectLater(
      HuaweiRtc.acceptExperimentalIncomingCall(handle: 'stale'),
      throwsA(
        isA<HuaweiRtcException>().having(
          (e) => e.toString().contains('private'),
          'private data',
          false,
        ),
      ),
    );
  });
  test(
    'incoming stream handles invitation and terminal without altering outgoing event channel',
    () async {
      final events = <HuaweiRtcIncomingExperimentEvent>[];
      final errors = <Object>[];
      final subscription = HuaweiRtc.incomingExperimentEvents.listen(
        events.add,
        onError: errors.add,
      );
      await Future<void>.delayed(Duration.zero);
      Future<void> send(Object? value) async {
        final done = Completer<void>();
        messenger.handlePlatformMessage(
          name,
          const StandardMethodCodec().encodeSuccessEnvelope(value),
          (_) => done.complete(),
        );
        await done.future;
      }

      await send({
        ...state,
        'state': 'invitation',
        'handle': 'opaque',
        'audioSupported': true,
      });
      await send({'invalid': true});
      await send({...state, 'state': 'ended', 'reason': 'sdk_hangup_0'});
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.state), ['invitation', 'ended']);
      expect(events.first.handle, 'opaque');
      expect(events.first.videoSupported, isFalse);
      expect(errors.single, isFormatException);
      await subscription.cancel();
    },
  );
}
