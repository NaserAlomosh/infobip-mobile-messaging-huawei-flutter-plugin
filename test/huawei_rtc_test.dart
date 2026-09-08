import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc');
  const eventName = 'infobip_mobilemessaging_huawei/huawei_rtc/events';
  const eventMethods = MethodChannel(eventName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final controls = <String>[];
  final nativeCall = <String, Object>{
    'id': 'call-1',
    'type': 'audio',
    'status': 'calling',
  };

  Future<void> send(Object? event) async {
    final completed = Completer<void>();
    messenger.handlePlatformMessage(
      eventName,
      const StandardMethodCodec().encodeSuccessEnvelope(event),
      (_) => completed.complete(),
    );
    await completed.future;
  }

  Map<String, Object?> event(String type, {Object? code}) => {
    'type': type,
    'call': nativeCall,
    'nativeErrorCode': code,
    'sequence': 1,
  };

  setUp(() {
    calls.clear();
    controls.clear();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'hangup') return null;
      return {
        ...nativeCall,
        if (call.arguments is Map) 'type': (call.arguments as Map)['type'],
      };
    });
    messenger.setMockMethodCallHandler(eventMethods, (call) async {
      controls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(eventMethods, null);
  });

  for (final type in HuaweiRtcCallType.values) {
    test(
      '${type.name} encodes distinct typed request and decodes call',
      () async {
        final result = await HuaweiRtc.callApplication(
          HuaweiRtcCallRequest(
            callsConfigurationId: 'calls-config',
            identity: 'test-subject',
            type: type,
          ),
        );
        expect(calls.single.method, 'callApplication');
        expect(calls.single.arguments, {
          'callsConfigurationId': 'calls-config',
          'identity': 'test-subject',
          'type': type.name,
        });
        expect(result.id, 'call-1');
        expect(result.type, type);
        expect(result.status, HuaweiRtcCallStatus.calling);
      },
    );
  }

  test('omitted identity delegates installation selection to native', () async {
    await HuaweiRtc.callApplication(
      HuaweiRtcCallRequest(
        callsConfigurationId: 'calls-config',
        type: HuaweiRtcCallType.audio,
      ),
    );
    expect((calls.single.arguments as Map).containsKey('identity'), isFalse);
  });

  test('blank required configuration and supplied identity reject locally', () {
    for (final value in ['', '  ', '\n']) {
      expect(
        () => HuaweiRtcCallRequest(
          callsConfigurationId: value,
          type: HuaweiRtcCallType.audio,
        ),
        throwsArgumentError,
      );
      expect(
        () => HuaweiRtcCallRequest(
          callsConfigurationId: 'calls-config',
          identity: value,
          type: HuaweiRtcCallType.video,
        ),
        throwsArgumentError,
      );
    }
    expect(calls, isEmpty);
  });

  for (final code in [
    'rtc_not_initialized',
    'rtc_invalid_argument',
    'rtc_permission_denied',
    'rtc_call_already_active',
    'rtc_no_active_call',
    'rtc_token_failed',
    'rtc_call_failed',
    'rtc_invalid_state',
  ]) {
    test('decodes $code without native credentials or details', () async {
      messenger.setMockMethodCallHandler(methods, (_) async {
        throw PlatformException(
          code: code,
          message: 'sensitive native response',
          details: {'token': 'sensitive token'},
        );
      });
      await expectLater(
        HuaweiRtc.hangup(),
        throwsA(
          isA<HuaweiRtcException>()
              .having((e) => e.code, 'code', code)
              .having(
                (e) => e.toString(),
                'sanitized',
                isNot(contains('sensitive')),
              ),
        ),
      );
    });
  }

  test('hangup invokes only the outgoing native operation', () async {
    await HuaweiRtc.hangup();
    expect(calls.single.method, 'hangup');
    expect(calls.single.arguments, isNull);
  });

  test('active call query supports native snapshot and no call', () async {
    expect((await HuaweiRtc.getActiveCall())!.id, 'call-1');
    messenger.setMockMethodCallHandler(methods, (_) async => null);
    expect(await HuaweiRtc.getActiveCall(), isNull);
  });

  test(
    'broadcast listeners attach once and detach after last subscriber',
    () async {
      final first = <HuaweiRtcEvent>[];
      final second = <HuaweiRtcEvent>[];
      final a = HuaweiRtc.events.listen(first.add);
      final b = HuaweiRtc.events.listen(second.add);
      await Future<void>.delayed(Duration.zero);
      expect(controls, ['listen']);
      await send(event('ringing'));
      expect(first.single.type, HuaweiRtcEventType.ringing);
      expect(second.single.call!.id, 'call-1');
      await a.cancel();
      expect(controls, ['listen']);
      await b.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(controls, ['listen', 'cancel']);
      final c = HuaweiRtc.events.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(controls.last, 'listen');
      await c.cancel();
    },
  );

  test('decodes all callbacks and numeric termination reason', () async {
    final received = <HuaweiRtcEvent>[];
    final subscription = HuaweiRtc.events.listen(received.add);
    await Future<void>.delayed(Duration.zero);
    for (final type in HuaweiRtcEventType.values) {
      await send(
        event(
          type.name,
          code: type == HuaweiRtcEventType.finished ? 1000 : null,
        ),
      );
    }
    expect(received.map((e) => e.type), HuaweiRtcEventType.values);
    expect(
      received
          .firstWhere((e) => e.type == HuaweiRtcEventType.finished)
          .nativeErrorCode,
      1000,
    );
    await subscription.cancel();
  });

  test(
    'idle snapshot is typed and malformed events do not kill stream',
    () async {
      final received = <HuaweiRtcEvent>[];
      final errors = <Object>[];
      final subscription = HuaweiRtc.events.listen(
        received.add,
        onError: errors.add,
      );
      await Future<void>.delayed(Duration.zero);
      for (final payload in [
        null,
        'sensitive untrusted payload',
        {'type': 'ringing'},
        {...event('unexpected')},
        {...event('ringing'), 'call': null},
        {...event('state'), 'sequence': -1},
        {...event('error'), 'nativeErrorCode': 'sensitive'},
        {
          ...event('state'),
          'call': {...nativeCall, 'status': 'made-up'},
        },
      ]) {
        await send(payload);
      }
      await send({'type': 'state', 'call': null, 'sequence': 0});
      await send(event('established'));
      expect(errors, hasLength(8));
      expect(errors.every((e) => e is FormatException), isTrue);
      expect(errors.join(), isNot(contains('sensitive')));
      expect(received.first.call, isNull);
      expect(received.last.type, HuaweiRtcEventType.established);
      await subscription.cancel();
    },
  );

  test('official RTC APIs preserve unsupported native responses', () async {
    const official = MethodChannel('official-rtc-guard-test');
    final platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: official,
    );
    messenger.setMockMethodCallHandler(official, (_) async {
      throw PlatformException(code: 'webrtc_unsupported');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(official, null));
    for (final operation in [
      () => platform.enableCalls('test-subject'),
      platform.enableChatCalls,
      platform.disableCalls,
    ]) {
      await expectLater(
        operation(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'webrtc_unsupported',
          ),
        ),
      );
    }
    expect(calls, isEmpty);
  });
}
