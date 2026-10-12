import 'package:flutter/services.dart';

/// Experimental camera-stream substitution, not Infobip native screen sharing.
enum ScreenAsCameraPhase {
  idle,
  requestingPermission,
  starting,
  sharing,
  stopping,
  stopped,
  cancelled,
  error,
}

final class ScreenAsCameraState {
  const ScreenAsCameraState._(
    this.callId,
    this.phase,
    this.framesBlocked,
    this.projectionTerminated,
    this.resourcesReleased,
    this.cameraOutputRestored,
    this.error,
  );
  final String? callId;
  final ScreenAsCameraPhase phase;
  final bool framesBlocked;
  final bool projectionTerminated;
  final bool resourcesReleased;

  /// A normal camera bitmap was submitted; remote rendering is not acknowledged.
  final bool cameraOutputRestored;
  final String? error;
  bool get busy =>
      !projectionTerminated ||
      !resourcesReleased ||
      phase == ScreenAsCameraPhase.requestingPermission ||
      phase == ScreenAsCameraPhase.starting;
  static ScreenAsCameraState decode(Object? value) {
    if (value is! Map ||
        (value['callId'] != null && value['callId'] is! String) ||
        (value['error'] != null && value['error'] is! String) ||
        [
          'framesBlocked',
          'projectionTerminated',
          'resourcesReleased',
          'cameraOutputRestored',
        ].any((key) => value[key] is! bool)) {
      throw const FormatException('Invalid screen-as-camera state');
    }
    final phases = ScreenAsCameraPhase.values.where(
      (p) => p.name == value['state'],
    );
    if (phases.length != 1) {
      throw const FormatException('Unknown capture phase');
    }
    return ScreenAsCameraState._(
      value['callId'] as String?,
      phases.single,
      value['framesBlocked'] as bool,
      value['projectionTerminated'] as bool,
      value['resourcesReleased'] as bool,
      value['cameraOutputRestored'] as bool,
      value['error'] as String?,
    );
  }
}

final class ScreenAsCameraException implements Exception {
  const ScreenAsCameraException(this.code);
  final String code;
  @override
  String toString() => 'ScreenAsCameraException($code)';
}

/// Device-test POC. Camera must remain enabled. Android 10+ only.
abstract final class HuaweiRtcScreenAsCamera {
  static const _methods = MethodChannel(
    'infobip_mobilemessaging_huawei/huawei_rtc',
  );
  static const _events = EventChannel(
    'infobip_mobilemessaging_huawei/screen_as_camera/events',
  );
  static final Stream<ScreenAsCameraState> states = _events
      .receiveBroadcastStream()
      .map(ScreenAsCameraState.decode);
  static final Set<String> _starting = {};
  static Future<ScreenAsCameraState> startScreenAsCamera({
    required String callId,
  }) async {
    if (!_starting.add(callId)) {
      throw const ScreenAsCameraException('screen_busy');
    }
    try {
      return await _invoke('startScreenAsCamera', callId);
    } finally {
      _starting.remove(callId);
    }
  }

  /// Resolves after projection termination callback and resource release.
  /// May report cameraOutputRestored=false until camera frames resume.
  static Future<ScreenAsCameraState> stopScreenAsCamera({
    required String callId,
  }) => _invoke('stopScreenAsCamera', callId);
  static Future<ScreenAsCameraState> getScreenAsCameraState({
    required String callId,
  }) => _invoke('getScreenAsCameraState', callId);
  static Future<ScreenAsCameraState> _invoke(String method, String id) async {
    if (id.trim().isEmpty) throw ArgumentError('callId must not be blank');
    try {
      final state = ScreenAsCameraState.decode(
        await _methods.invokeMethod<Object?>(method, {'callId': id}),
      );
      if (state.callId != id) {
        throw const FormatException('Capture state belongs to another call');
      }
      return state;
    } on PlatformException catch (error) {
      throw ScreenAsCameraException(error.code);
    }
  }
}
