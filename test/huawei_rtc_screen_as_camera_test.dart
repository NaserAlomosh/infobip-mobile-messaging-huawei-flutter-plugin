import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('infobip_mobilemessaging_huawei/huawei_rtc');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final payload = <String, Object?>{
    'callId': 'A',
    'state': 'stopped',
    'framesBlocked': true,
    'projectionTerminated': true,
    'resourcesReleased': true,
    'cameraOutputRestored': false,
    'error': null,
  };
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'start stop readback are call scoped and distinguish camera restoration',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return payload;
      });
      await HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: 'A');
      await HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: 'A');
      final state = await HuaweiRtcScreenAsCamera.getScreenAsCameraState(
        callId: 'A',
      );
      expect(calls.map((c) => c.method), [
        'startScreenAsCamera',
        'stopScreenAsCamera',
        'getScreenAsCameraState',
      ]);
      expect(calls.every((c) => (c.arguments as Map)['callId'] == 'A'), true);
      expect(state.projectionTerminated, true);
      expect(state.cameraOutputRestored, false);
    },
  );
  test(
    'unsupported platform and cancellation keep typed sanitized codes',
    () async {
      for (final code in [
        'screen_unsupported',
        'screen_permission_cancelled',
        'screen_stop_uncertain',
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: code, message: 'secret'),
        );
        await expectLater(
          HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: 'A'),
          throwsA(
            isA<ScreenAsCameraException>().having((e) => e.code, 'code', code),
          ),
        );
      }
    },
  );
  test('duplicate start rejected while stop remains available', () async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'startScreenAsCamera' ? await pending.future : payload,
    );
    final start = HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: 'A');
    await expectLater(
      HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: 'A'),
      throwsA(isA<ScreenAsCameraException>()),
    );
    await HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: 'A');
    pending.complete(payload);
    await start;
  });
  test('rejects stale call snapshots and malformed state', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {...payload, 'callId': 'B'},
    );
    await expectLater(
      HuaweiRtcScreenAsCamera.getScreenAsCameraState(callId: 'A'),
      throwsFormatException,
    );
    expect(
      () => ScreenAsCameraState.decode({...payload, 'state': 'invented'}),
      throwsFormatException,
    );
    expect(
      () => ScreenAsCameraState.decode({...payload, 'framesBlocked': 'true'}),
      throwsFormatException,
    );
  });
}
