import 'package:flutter/foundation.dart';
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
/// [returnToCall] is a validated ongoing-notification tap, not an SDK transition.
enum HuaweiRtcEventType {
  state,
  ringing,
  earlyMedia,
  established,
  finished,
  error,
  reconnecting,
  reconnected,

  /// A validated notification tap. Consume with HuaweiRtc.takeNotificationCall.
  returnToCall,
}

/// Opt-in customer identity for the exact configured Live Chat widget.
/// Resolution and token acquisition stay native, scoped to a single call.
/// Requires completed personalization as [expectedExternalUserId].
final class HuaweiRtcLiveChatIdentity {
  HuaweiRtcLiveChatIdentity({
    required this.widgetId,
    required this.expectedExternalUserId,
  }) {
    if (widgetId.trim().isEmpty || expectedExternalUserId.trim().isEmpty) {
      throw ArgumentError(
        'A Chat widget ID and expected external user are required',
      );
    }
  }

  final String widgetId;
  final String expectedExternalUserId;

  Map<String, String> _encode() => {
    'widgetId': widgetId,
    'expectedExternalUserId': expectedExternalUserId,
  };
}

/// Input for this plugin's outgoing extension, separate from WebRTCUI.
///
/// The Calls configuration routes an application call in the Infobip backend.
/// It is NOT the RTC push configuration ID from WebRTCUI.
/// Unless [liveChatIdentity] is selected, omitting [identity] uses the registered
/// MM installation's push registration ID as the token subject. Tokens never cross the Flutter channel.
final class HuaweiRtcCallRequest {
  HuaweiRtcCallRequest({
    required this.callsConfigurationId,
    required this.type,
    this.identity,
    this.liveChatIdentity,
  }) {
    if (identity != null && liveChatIdentity != null) {
      throw ArgumentError('Choose explicit identity or Live Chat identity');
    }
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

  /// Resolves a fresh registration for this widget, with no identity fallback.
  /// Cannot be combined with [identity]. Account changes before native call
  /// submission fail the request. Does not guarantee Conversation reuse.
  final HuaweiRtcLiveChatIdentity? liveChatIdentity;

  Map<String, Object> _encode() => {
    'callsConfigurationId': callsConfigurationId,
    'type': type.name,
    if (identity != null) 'identity': identity!,
    if (liveChatIdentity != null)
      'liveChatIdentity': liveChatIdentity!._encode(),
  };
}

/// Snapshot of a native application call. Success creating this object does not
/// mean the remote endpoint has answered; observe [HuaweiRtc.events].
final class HuaweiRtcCall {
  const HuaweiRtcCall._(this.id, this.type, this.status, this.duration);

  final String id;
  final HuaweiRtcCallType type;
  final HuaweiRtcCallStatus status;

  /// SDK duration since confirmed establishment; frozen by Core at termination.
  final Duration duration;

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
      Duration(seconds: _seconds(payload['durationSeconds'])),
    );
  }
}

/// A serialized Core callback, state snapshot, or validated notification tap.
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

int _seconds(Object? value) {
  if (value == null) {
    return 0; // Backward compatible with older native snapshots.
  }
  if (value is! int || value < 0) {
    throw const FormatException('Invalid RTC duration');
  }
  return value;
}

/// SDK audio device categories. Bluetooth availability depends on the device,
/// connected headset and existing Nearby devices permission.
enum HuaweiRtcAudioOutput { bluetooth, wiredHeadset, earpiece, speaker }

enum HuaweiRtcCameraOrientation { front, back }

/// Authoritative SDK readback. Refresh after errors and while controls are pending.
final class HuaweiRtcControls {
  const HuaweiRtcControls._(
    this.callId,
    this.microphoneMuted,
    this.speakerEnabled,
    this.cameraEnabled,
    this.cameraOrientation,
    this.audioOutput,
    this.availableAudioOutputs,
  );

  final String callId;
  final bool microphoneMuted;
  final bool speakerEnabled;
  final bool cameraEnabled;
  final HuaweiRtcCameraOrientation? cameraOrientation;
  final HuaweiRtcAudioOutput? audioOutput;
  final List<HuaweiRtcAudioOutput> availableAudioOutputs;

  static HuaweiRtcControls _decode(Object? payload) {
    if (payload is! Map ||
        payload['callId'] is! String ||
        (payload['callId'] as String).isEmpty ||
        payload['microphoneMuted'] is! bool ||
        payload['speakerEnabled'] is! bool ||
        payload['cameraEnabled'] is! bool ||
        payload['availableAudioOutputs'] is! List) {
      throw const FormatException('Invalid RTC control snapshot');
    }
    return HuaweiRtcControls._(
      payload['callId'] as String,
      payload['microphoneMuted'] as bool,
      payload['speakerEnabled'] as bool,
      payload['cameraEnabled'] as bool,
      payload['cameraOrientation'] == null
          ? null
          : _enumValue(
              HuaweiRtcCameraOrientation.values,
              payload['cameraOrientation'],
            ),
      payload['audioOutput'] == null
          ? null
          : _enumValue(HuaweiRtcAudioOutput.values, payload['audioOutput']),
      List.unmodifiable(
        (payload['availableAudioOutputs'] as List).map(
          (value) => _enumValue(HuaweiRtcAudioOutput.values, value),
        ),
      ),
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
    'rtc_control_unavailable': 'The requested RTC control is unavailable.',
    'rtc_permission_denied':
        'Grant microphone, camera for video, and Nearby devices on Android 12+ before calling.',
    'rtc_call_already_active': 'Another RTC call or call request is active.',
    'rtc_no_active_call': 'There is no active RTC call.',
    'rtc_token_failed': 'RTC access token acquisition failed.',
    'rtc_identity_unavailable':
        'Chat identity unavailable. Check connectivity, widget configuration and Chat registration.',
    'rtc_call_failed': 'RTC could not perform the call operation.',
    'rtc_foreground_service_failed':
        'RTC foreground service could not start. Return to the app and check permissions.',
    'rtc_invalid_state':
        'RTC cannot perform this operation in its current state.',
  };

  @override
  String toString() => 'HuaweiRtcException($code): $message';
}

/// EXPERIMENTAL debug-only, allowlisted observation, not an application contract.
///
/// Never contains SDK payloads, tokens or identities. Diagnostics are bounded and
/// may be absent or dropped; names/counts must not drive application logic.
/// A registration or transport observation does not confirm signaling readiness,
/// Dart receipt, invitation delivery or connected media.
final class HuaweiRtcIncomingDiagnostic {
  const HuaweiRtcIncomingDiagnostic._(
    this.sequence,
    this.timestampMillis,
    this.event,
    this.errorCode,
  );

  /// Native diagnostic order; not a durable sequence across process recreation.
  final int sequence;

  /// Native wall-clock timestamp in milliseconds since the Unix epoch.
  final int timestampMillis;

  /// Allowlisted diagnostic name; may evolve with the experimental implementation.
  final String event;

  /// Optional numeric SDK error code, without its raw payload or description.
  final int? errorCode;

  static const _events = {
    'start_received',
    'start_rejected_arguments',
    'start_rejected_foreground',
    'start_rejected_busy',
    'start_reused',
    'identity_resolution_started',
    'identity_resolution_returned',
    'identity_resolution_failed',
    'token_request_started',
    'token_request_returned',
    'token_request_failed',
    'preparation_result_discarded',
    'registration_preflight',
    'singleton_mode_unobservable',
    'singleton_reference_changed',
    'singleton_reference_unchanged_prior_registration_possible',
    'singleton_observation_failed',
    'registration_invoked',
    'registration_returned_readiness_unconfirmed',
    'registration_threw',
    'idle_connection_authentication_unobservable',
    'peer_family_unobserved',
    'invitation_callback',
    'duplicate_invitation_ignored',
    'rejected_invalidated',
    'rejected_not_started',
    'rejected_screen_hidden',
    'rejected_host_unready',
    'rejected_pending_invitation',
    'rejected_call_slot_busy',
    'rejection_decline_returned',
    'rejection_decline_failed',
    'invitation_published',
    'invitation_listener_failed',
    'accept_requested',
    'accept_adoption_failed',
    'accept_returned',
    'accept_failed',
    'decline_requested',
    'decline_returned',
    'decline_failed',
    'call_error',
    'call_reconnecting',
    'call_reconnected',
    'call_established',
    'call_finished',
    'experiment_invalidated',
    'screen_closed',
    'event_sink_attached',
    'event_sink_detached',
    'event_sink_write_returned',
    'event_sink_write_failed',
  };
  static HuaweiRtcIncomingDiagnostic? _decode(Object? value) {
    if (value is! Map ||
        value['sequence'] is! int ||
        (value['sequence'] as int) <= 0 ||
        value['timestampMillis'] is! int ||
        (value['timestampMillis'] as int) < 0 ||
        (value['timestampMillis'] as int) > 8640000000000000 ||
        !_events.contains(value['event']) ||
        (value['errorCode'] != null && value['errorCode'] is! int)) {
      return null;
    }
    return HuaweiRtcIncomingDiagnostic._(
      value['sequence'] as int,
      value['timestampMillis'] as int,
      value['event'] as String,
      value['errorCode'] as int?,
    );
  }
}

/// EXPERIMENTAL — NOT PRODUCTION READY. Safe application-call invitation state.
/// No caller identifiers, registration IDs, custom data, or tokens are retained.
///
/// Snapshots may repeat. Observe [HuaweiRtc.events] for accepted-call lifecycle;
/// this object is neither durable call history nor signaling-readiness proof.
final class HuaweiRtcIncomingExperimentEvent {
  HuaweiRtcIncomingExperimentEvent._(Map payload)
    : state = payload['state'] as String,
      handle = payload['handle'] as String?,
      family = payload['family'] as String,
      audioSupported = payload['audioSupported'] as bool,
      videoSupported = payload['videoSupported'] as bool,
      registrationAttempted = payload['registrationAttempted'] as bool,
      reason = payload['reason'] as String?,
      diagnostics = List.unmodifiable(
        kDebugMode && payload['diagnostics'] is List
            ? (payload['diagnostics'] as List)
                  .take(100)
                  .map(HuaweiRtcIncomingDiagnostic._decode)
                  .whereType<HuaweiRtcIncomingDiagnostic>()
            : <HuaweiRtcIncomingDiagnostic>[],
      );

  /// Current presentation/preparation phase: `idle`, `preparing`,
  /// `registrationRequested`, `invitation`, `connecting`, `connected`,
  /// `reconnecting`, `declining`, `ending`, `ended`, `failed`, `paused`, or
  /// `invalidated`. Handle unfamiliar values defensively.
  ///
  /// Registration requested is not ready signaling. Declining/ending are requests,
  /// not confirmed termination. Failed may retain native ownership. Paused and
  /// invalidated can mask call phase; use accepted-call finished events as well.
  final String state;

  /// Opaque handle exposed only for a visible, actionable invitation.
  /// Never persist it. Cancellation, acceptance, foreground loss or invalidation
  /// can make it stale before an action reaches native code.
  final String? handle;

  /// Currently `application`; peer-call invitations are not supported.
  final String family;

  /// Local audio acceptance capability, not readiness or handle validity.
  final bool audioSupported;

  /// Whether explicit local video acceptance is supported; not remote offer metadata.
  final bool videoSupported;

  /// Always `unknown` with Core 2.5.28; no reliable remote offer detection exists.
  String get offeredCallType => 'unknown';

  /// Whether SDK registration was invoked, even if it threw; not readiness proof.
  final bool registrationAttempted;

  /// Nullable explanation, not an exception or terminal-state guarantee.
  /// Current reasons include identity_changed, engine_detached, engine_replaced,
  /// preparation_timeout, preparation_failed, registration_failed,
  /// listener_failed, accept_failed, termination_unconfirmed, cancelled,
  /// sdk_finished, `sdk_error_<number>` and `sdk_hangup_<number>`.
  /// A reason may persist across snapshots; SDK errors need not be terminal.
  final String? reason;

  /// At most 100 valid debug observations; empty in non-debug Dart builds.
  /// Native diagnostics also require a debuggable Android host. Never use them
  /// for readiness checks or as a complete event history.
  final List<HuaweiRtcIncomingDiagnostic> diagnostics;

  static HuaweiRtcIncomingExperimentEvent _decode(Object? value) {
    if (value is! Map ||
        value['state'] is! String ||
        value['family'] != 'application' ||
        value['audioSupported'] is! bool ||
        value['videoSupported'] is! bool ||
        value['registrationAttempted'] is! bool ||
        (value['handle'] != null && value['handle'] is! String) ||
        (value['reason'] != null && value['reason'] is! String)) {
      throw const FormatException('Invalid incoming experiment event');
    }
    return HuaweiRtcIncomingExperimentEvent._(value);
  }
}

/// Android application audio/video calls and experimental foreground invitations.
///
/// Initialize Huawei Mobile Messaging first. Start calls with a resumed Flutter
/// Activity after the host has requested microphone, camera (video only), and
/// Nearby devices (Android 12+) permissions. This API never requests permissions.
/// Only one call/request is allowed in the process. No incoming HMS push,
/// official enableCalls/enableChatCalls parity or call UI is added. For outgoing
/// calls, a microphone/camera foreground service starts before SDK media; grant
/// notification
/// permission on Android 13+ to see its notice in the drawer. Observe returnToCall
/// and consume takeNotificationCall to navigate to your current call screen.
/// Outgoing Activity recreation preserves calls. Engine disposal attempts hangup and
/// detaches listeners. Hang up and wait for finished before MM cleanup/relogin.
/// Experimental incoming calls have stricter foreground/process lifetime rules;
/// see [startForegroundIncomingExperiment] and
/// [closeForegroundIncomingExperimentScreen].
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

  /// EXPERIMENTAL — NOT PRODUCTION READY. Replays the current invitation when
  /// a listener attaches. Registration requested does not establish readiness.
  ///
  /// Subscribe before Start and handle stream errors: native platform failures
  /// become [HuaweiRtcException]; malformed events produce [FormatException].
  /// Snapshots can repeat and are not durable history. Canceling a subscription
  /// only detaches its sink; it does not close the screen or unregister signaling.
  /// Accepted calls also use [events] for media establishment and termination.
  static final Stream<HuaweiRtcIncomingExperimentEvent>
  incomingExperimentEvents =
      const EventChannel(
            'infobip_mobilemessaging_huawei/huawei_rtc/incoming_experiment',
          )
          .receiveBroadcastStream()
          .map(HuaweiRtcIncomingExperimentEvent._decode)
          .handleError((Object error) {
            if (error is PlatformException) throw HuaweiRtcException._(error);
            throw error;
          });

  /// EXPERIMENTAL explicit opt-in from an attached, resumed Android Activity.
  ///
  /// Initialize Mobile Messaging, wait for installation registration, personalize
  /// the expected external user and configure the exact Live Chat widget first.
  /// Subscribe to [incomingExperimentEvents] and [events] before starting.
  /// The returned preparation snapshot is not confirmed signaling readiness;
  /// later preparation failures arrive through incoming state/reason.
  ///
  /// Exactly one fixed identity and preparation/registration attempt per process.
  /// Repeating Start for the same valid identity reopens presentation without
  /// token refresh or registration retry. Failure/timeout, account mutation,
  /// logout or engine detachment/replacement requires process recreation before
  /// retrying. Core 2.5.28 has no supported active-registration token replacement
  /// or unregister API. The native token request asks for 43,200 seconds; actual
  /// issued expiry and continued signaling availability are not guaranteed.
  ///
  /// No background or terminated-app delivery is supported. Activity foreground
  /// loss can end an invitation/call; fast recreation may preserve it. There is
  /// no incoming auto-reconnect or guarantee of existing Conversation reuse.
  ///
  /// Native state/busy failures throw [HuaweiRtcException]; malformed snapshots
  /// throw [FormatException]. [HuaweiRtcLiveChatIdentity] rejects blank inputs
  /// with [ArgumentError]. Permissions are host-owned and checked on acceptance.
  static Future<HuaweiRtcIncomingExperimentEvent>
  startForegroundIncomingExperiment(HuaweiRtcLiveChatIdentity identity) async =>
      HuaweiRtcIncomingExperimentEvent._decode(
        await _invoke('startForegroundIncomingExperiment', identity._encode()),
      );

  /// EXPERIMENTAL. Accepts the current opaque invitation while foregrounded.
  /// The handle must still identify the visible pending invitation; cancellation,
  /// account changes or lifecycle loss can invalidate it before native dispatch.
  /// Media uses existing [events], video views and call-ID-scoped controls.
  /// `video: true` explicitly opts into local camera publication. Core 2.5.28
  /// cannot identify the remote offered media type; this is not offer detection.
  /// Grant microphone, camera for video, and Nearby devices on Android 12+ first.
  /// Permission denial before adoption leaves the invitation pending; retry only
  /// while its handle remains valid. No automatic audio fallback occurs if video
  /// acceptance fails. Incoming auto-reconnect is disabled.
  ///
  /// Success returns a call snapshot, not established bidirectional media; wait
  /// for [events]. Native stale-state, permission, busy and SDK failures throw
  /// [HuaweiRtcException]; malformed snapshots throw [FormatException]. An SDK
  /// acceptance failure requests hangup but may retain ownership until terminal.
  static Future<HuaweiRtcCall> acceptExperimentalIncomingCall({
    required String handle,
    bool video = false,
  }) async => HuaweiRtcCall._decode(
    await _invoke('acceptExperimentalIncomingCall', {
      'handle': handle,
      'video': video,
    }),
  );

  /// EXPERIMENTAL. Requests decline of the current visible invitation and stops
  /// its ringtone. Requires a still-valid opaque handle and resumed Activity.
  /// Stale handles or native failures throw [HuaweiRtcException].
  ///
  /// Success is not confirmed termination: observe [incomingExperimentEvents]
  /// for terminal state. Native ownership is retained until terminal observation.
  /// A failed decline also stops ringtone but does not prove the call has ended.
  static Future<void> declineExperimentalIncomingCall({
    required String handle,
  }) async => _invoke('declineExperimentalIncomingCall', {'handle': handle});

  /// EXPERIMENTAL. Call on incoming-screen disposal to hide invitations, silence
  /// ringtone and request decline/hangup of pending/accepted incoming calls.
  /// Handle the future and [HuaweiRtcException] for native channel/state failures.
  /// SDK termination failure may instead appear as `termination_unconfirmed` in
  /// incoming snapshots; successful completion is not terminal acknowledgment.
  /// Observe [events] for accepted-call termination and retain cleanup handling.
  ///
  /// This does not unregister native signaling. Start can reopen only the same
  /// still-valid experiment. Account changes/logout or engine detach invalidate
  /// it permanently for this process. Engine detach also releases local rendering
  /// bindings while uncertain native ownership remains reserved until terminal.
  static Future<void> closeForegroundIncomingExperimentScreen() async =>
      _invoke('closeForegroundIncomingExperimentScreen');

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

  /// Consumes a notification tap for the current native session. Navigate to the
  /// existing call screen without placing a new call. Returns null for stale taps.
  /// Check after app resume and initial Activity attachment.
  static Future<HuaweiRtcCall?> takeNotificationCall() async {
    final payload = await _invoke('takeNotificationCall');
    return payload == null ? null : HuaweiRtcCall._decode(payload);
  }

  /// Call IDs are required so queued controls cannot affect a replacement call.
  static Future<HuaweiRtcControls> getCallControls({required String callId}) =>
      _control('getCallControls', callId);

  static Future<HuaweiRtcControls> setMicrophoneMuted(
    bool muted, {
    required String callId,
  }) => _control('setMicrophoneMuted', callId, {'enabled': muted});

  /// Selects speaker when enabled, earpiece when disabled. An unavailable
  /// earpiece (e.g. a tablet) produces rtc_control_unavailable.
  static Future<HuaweiRtcControls> setSpeakerEnabled(
    bool enabled, {
    required String callId,
  }) => _control('setSpeakerEnabled', callId, {'enabled': enabled});

  static Future<HuaweiRtcControls> switchCamera({required String callId}) =>
      _control('switchCamera', callId);

  static Future<HuaweiRtcControls> setCameraEnabled(
    bool enabled, {
    required String callId,
  }) => _control('setCameraEnabled', callId, {'enabled': enabled});

  static Future<HuaweiRtcControls> selectAudioOutput(
    HuaweiRtcAudioOutput output, {
    required String callId,
  }) => _control('selectAudioOutput', callId, {'output': output.name});

  static Future<HuaweiRtcControls> _control(
    String method,
    String callId, [
    Map<String, Object> values = const {},
  ]) async {
    if (callId.trim().isEmpty) throw ArgumentError('callId must not be blank');
    final result = HuaweiRtcControls._decode(
      await _invoke(method, {'callId': callId, ...values}),
    );
    if (result.callId != callId) {
      throw const FormatException(
        'RTC control snapshot belongs to another call',
      );
    }
    return result;
  }

  static Future<Object?> _invoke(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      throw HuaweiRtcException._(error);
    }
  }
}
