import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final state = <String, Object?>{
    'callId': 'call-1',
    'microphoneMuted': true,
    'speakerEnabled': false,
    'cameraEnabled': true,
    'cameraOrientation': 'back',
    'audioOutput': 'bluetooth',
    'availableAudioOutputs': [
      'bluetooth',
      'earpiece',
      'speaker',
      'wiredHeadset',
    ],
  };
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return state;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('all controls bind to call ID and decode authoritative state', () async {
    final results = [
      await HuaweiRtc.getCallControls(callId: 'call-1'),
      await HuaweiRtc.setMicrophoneMuted(true, callId: 'call-1'),
      await HuaweiRtc.setSpeakerEnabled(false, callId: 'call-1'),
      await HuaweiRtc.switchCamera(callId: 'call-1'),
      await HuaweiRtc.setCameraEnabled(false, callId: 'call-1'),
      await HuaweiRtc.selectAudioOutput(
        HuaweiRtcAudioOutput.bluetooth,
        callId: 'call-1',
      ),
    ];
    expect(calls.map((c) => c.method), [
      'getCallControls',
      'setMicrophoneMuted',
      'setSpeakerEnabled',
      'switchCamera',
      'setCameraEnabled',
      'selectAudioOutput',
    ]);
    expect(calls.map((c) => c.arguments), [
      {'callId': 'call-1'},
      {'callId': 'call-1', 'enabled': true},
      {'callId': 'call-1', 'enabled': false},
      {'callId': 'call-1'},
      {'callId': 'call-1', 'enabled': false},
      {'callId': 'call-1', 'output': 'bluetooth'},
    ]);
    for (final result in results) {
      expect(result.microphoneMuted, isTrue);
      expect(result.speakerEnabled, isFalse);
      expect(result.cameraEnabled, isTrue); // Readback, not requested false.
      expect(result.cameraOrientation, HuaweiRtcCameraOrientation.back);
      expect(result.audioOutput, HuaweiRtcAudioOutput.bluetooth);
      expect(
        result.availableAudioOutputs,
        contains(HuaweiRtcAudioOutput.wiredHeadset),
      );
      expect(
        () => result.availableAudioOutputs.clear(),
        throwsUnsupportedError,
      );
    }
  });
  test('blank call and mismatched result rejected', () async {
    await expectLater(HuaweiRtc.switchCamera(callId: ' '), throwsArgumentError);
    expect(calls, isEmpty);
    await expectLater(
      HuaweiRtc.switchCamera(callId: 'old-call'),
      throwsFormatException,
    );
  });
  test('native unavailable and stale failures sanitized', () async {
    for (final code in [
      'rtc_control_unavailable',
      'rtc_invalid_state',
      'rtc_permission_denied',
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: code, message: 'secret'),
      );
      await expectLater(
        HuaweiRtc.setCameraEnabled(true, callId: 'call-1'),
        throwsA(
          isA<HuaweiRtcException>()
              .having((e) => e.code, 'code', code)
              .having(
                (e) => e.toString().contains('secret'),
                'sanitized',
                false,
              ),
        ),
      );
    }
  });
  test(
    'duration decodes additively and legacy snapshots retain zero',
    () async {
      for (final seconds in [null, 0, 65]) {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {
            'id': 'call-1',
            'type': 'audio',
            'status': 'established',
            if (seconds != null) 'durationSeconds': seconds,
          },
        );
        expect(
          (await HuaweiRtc.getActiveCall())!.duration.inSeconds,
          seconds ?? 0,
        );
      }
    },
  );
  test('malformed readback rejected', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {...state, 'microphoneMuted': 'true'},
    );
    await expectLater(
      HuaweiRtc.getCallControls(callId: 'call-1'),
      throwsFormatException,
    );
  });
}
