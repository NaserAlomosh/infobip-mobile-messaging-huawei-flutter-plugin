import 'package:flutter/services.dart';

/// Media requested when starting a Huawei RTC Core application call.
enum HuaweiRtcCallType { audio, video }

/// Exact statuses exposed by RTC Core 2.5.28, without inferred transitions.
enum HuaweiRtcCallStatus {
  initializing,
  initialized,
  calling,
  ringing,
  connecting,
  established,
  finishing,
  finished,
}

/// [state] is a native snapshot on call creation or event listener attachment.
/// [error] is an SDK error callback and is not necessarily terminal.
enum HuaweiRtcEventType {
  state,
  ringing,
  earlyMedia,
  established,
  finished,
  error,
  reconnecting,
  reconnected,
}

/// Input for this plugin's outgoing extension, separate from WebRTCUI.
///
/// The Calls configuration routes an application call in the Infobip backend.
/// It is NOT the RTC push configuration ID from WebRTCUI.
/// When [identity] is omitted, the registered MM installation's push registration
/// ID is used as the token subject. Tokens never cross the Flutter channel.
final class HuaweiRtcCallRequest {
  HuaweiRtcCallRequest({
    required this.callsConfigurationId,
    required this.type,
    this.identity,
  }) {
    if (callsConfigurationId.trim().isEmpty) {
      throw ArgumentError('callsConfigurationId must not be blank');
    }
    if (identity != null && identity!.trim().isEmpty) {
      throw ArgumentError('identity must be nonblank when supplied');
    }
  }

  final String callsConfigurationId;
  final HuaweiRtcCallType type;
  final String? identity;

  Map<String, Object> _encode() => {
    'callsConfigurationId': callsConfigurationId,
    'type': type.name,
    if (identity != null) 'identity': identity!,
  };
}

/// Snapshot of a native application call. Success creating this object does not
/// mean the remote endpoint has answered; observe [HuaweiRtc.events].
final class HuaweiRtcCall {
  const HuaweiRtcCall._(this.id, this.type, this.status);

  final String id;
  final HuaweiRtcCallType type;
  final HuaweiRtcCallStatus status;

  static HuaweiRtcCall _decode(Object? payload) {
    if (payload is! Map ||
        payload['id'] is! String ||
        (payload['id'] as String).trim().isEmpty) {
      throw const FormatException('Invalid Huawei RTC call payload');
    }
    return HuaweiRtcCall._(
      payload['id'] as String,
      _enumValue(HuaweiRtcCallType.values, payload['type']),
      _enumValue(HuaweiRtcCallStatus.values, payload['status']),
    );
  }
}

/// A serialized Core callback or state snapshot.
///
/// [nativeErrorCode] contains only Core's numeric ErrorCode.id. Native names,
/// descriptions, HTTP responses, identities and credentials are not forwarded.
/// [call] is null only for an idle [HuaweiRtcEventType.state] snapshot.
/// [sequence] orders events within one engine; attaching again may replay the
/// last event with the same sequence. This stream is not a durable call history.
final class HuaweiRtcEvent {
  const HuaweiRtcEvent._(
    this.type,
    this.call,
    this.nativeErrorCode,
    this.sequence,
  );

  final HuaweiRtcEventType type;
  final HuaweiRtcCall? call;
  final int? nativeErrorCode;
  final int sequence;

  static HuaweiRtcEvent _decode(Object? payload) {
    if (payload is! Map ||
        payload['sequence'] is! int ||
        (payload['sequence'] as int) < 0 ||
        (payload['nativeErrorCode'] != null &&
            payload['nativeErrorCode'] is! int)) {
      throw const FormatException('Invalid Huawei RTC event payload');
    }
    final type = _enumValue(HuaweiRtcEventType.values, payload['type']);
    final call = payload['call'] == null
        ? null
        : HuaweiRtcCall._decode(payload['call']);
    if (call == null && type != HuaweiRtcEventType.state) {
      throw const FormatException('Missing Huawei RTC event call');
    }
    return HuaweiRtcEvent._(
      type,
      call,
      payload['nativeErrorCode'] as int?,
      payload['sequence'] as int,
    );
  }
}

T _enumValue<T extends Enum>(List<T> values, Object? value) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw const FormatException('Invalid Huawei RTC enum value');
}

/// Stable, sanitized native operation failure. Does not retain native details.
final class HuaweiRtcException implements Exception {
  HuaweiRtcException._(PlatformException error)
    : code = _messages.containsKey(error.code) ? error.code : 'rtc_call_failed',
      message = _messages[error.code] ?? _messages['rtc_call_failed']!;

  final String code;
  final String message;

  static const _messages = {
    'rtc_not_initialized':
        'Initialize Huawei Mobile Messaging and wait for installation registration, or supply an identity.',
    'rtc_invalid_argument': 'Invalid RTC call arguments.',
    'rtc_permission_denied':
        'Grant microphone, camera for video, and Nearby devices on Android 12+ before calling.',
    'rtc_call_already_active': 'Another RTC call or call request is active.',
    'rtc_no_active_call': 'There is no active RTC call.',
    'rtc_token_failed': 'RTC access token acquisition failed.',
    'rtc_call_failed': 'RTC could not perform the call operation.',
    'rtc_invalid_state':
        'RTC cannot perform this operation in its current state.',
  };

  @override
  String toString() => 'HuaweiRtcException($code): $message';
}

/// Huawei/plugin extension for outgoing application audio/video calls on Android.
///
/// Initialize Huawei Mobile Messaging first. Start calls with a resumed Flutter
/// Activity after the host has requested microphone, camera (video only), and
/// Nearby devices (Android 12+) permissions. This API never requests permissions.
/// Only one call/request is allowed in the process. No incoming HMS registration,
/// official enableCalls/enableChatCalls parity, call UI, or video renderer is added.
/// Activity recreation preserves calls. Engine disposal attempts hangup and
/// detaches listeners. Hang up and wait for finished before MM cleanup/relogin.
abstract final class HuaweiRtc {
  static const _methods = MethodChannel(
    'infobip_mobilemessaging_huawei/huawei_rtc',
  );
  static const _eventChannel = EventChannel(
    'infobip_mobilemessaging_huawei/huawei_rtc/events',
  );

  /// Shared broadcast stream. Last subscriber cancellation detaches the native
  /// sink without ending the call. Malformed events are FormatException stream
  /// errors; later valid events still arrive. Subscribe before placing a call.
  static final Stream<HuaweiRtcEvent> events = _eventChannel
      .receiveBroadcastStream()
      .map(HuaweiRtcEvent._decode)
      .handleError((Object error) {
        if (error is PlatformException) throw HuaweiRtcException._(error);
        throw error;
      });

  /// Resolves when Core creates the native call, not when media is established.
  static Future<HuaweiRtcCall> callApplication(
    HuaweiRtcCallRequest request,
  ) async => HuaweiRtcCall._decode(
    await _invoke('callApplication', request._encode()),
  );

  /// Requests native hangup. Wait for the finished event for terminal state.
  static Future<void> hangup() async => _invoke('hangup');

  /// Returns null when no call object exists, including during token acquisition.
  static Future<HuaweiRtcCall?> getActiveCall() async {
    final payload = await _invoke('getActiveCall');
    return payload == null ? null : HuaweiRtcCall._decode(payload);
  }

  static Future<Object?> _invoke(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      throw HuaweiRtcException._(error);
    }
  }
}
