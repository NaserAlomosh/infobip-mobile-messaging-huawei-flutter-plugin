# Huawei RTC Core outgoing calls

`HuaweiRtc` is a Huawei/plugin extension for **outgoing application audio/video
calls**, implemented directly with `com.infobip:infobip-rtc:2.5.28`. It does not
enable Mobile Messaging incoming calls. `enableCalls`, `enableChatCalls` and
`disableCalls` keep their existing guarded behavior. No HMS incoming registration,
RTC UI, Chat registration, incoming push bridge or iOS implementation is added.

## Consumer API

Initialize Huawei Mobile Messaging with your existing application configuration.
Your test account must have Web and In-app Calls enabled and a valid **Calls
configuration** that routes application calls to the intended backend application.
The routing target is determined by that backend configuration; this is not a
peer-identity `callWebrtc` API. Start calls from a resumed Flutter Activity.

```dart
final subscription = HuaweiRtc.events.listen(
  (event) {
    // Update your call state from event.type and event.call?.status.
    // event.nativeErrorCode is an optional numeric Core reason, never raw text.
  },
  onError: (Object error) {
    // Handle channel errors / malformed events without logging credentials.
  },
);

final call = await HuaweiRtc.callApplication(
  HuaweiRtcCallRequest(
    callsConfigurationId: yourCallsConfigurationId,
    type: HuaweiRtcCallType.audio, // use .video for audio + camera video
    // identity: authenticatedTestIdentity, // optional
  ),
);

final active = await HuaweiRtc.getActiveCall();
await HuaweiRtc.hangup();
// Wait for HuaweiRtcEventType.finished before MM cleanup or another account.
await subscription.cancel();
```

`HuaweiRtcCallRequest` validates a nonblank Calls configuration ID and a nonblank
identity when supplied. Native validation repeats those checks. Identity and
configuration contents are preserved; they are not silently trimmed. Missing
identity uses the current installation's `pushRegistrationId`. That requires MM
registration to have completed. Identity is a caller/token subject, not the
destination. The application/backend remains responsible for authenticating the
user and authorizing the identity; this extension adds no impersonation policy.

**`WebRTCUI.configurationId` is a push registration configuration. It is never
read or reused as `callsConfigurationId`.** Outgoing calls require no `WebRTCUI`
configuration and do not use its dormant reflection adapter.

`callApplication` resolves with a `HuaweiRtcCall` (`id`, requested `type`, native
`status`) only after Core returns an `ApplicationCall`. It does not claim the
remote endpoint answered. One active call **or pending token request** is permitted
across plugin engines. A second request receives `rtc_call_already_active`.
`getActiveCall` returns null while token acquisition is pending or no call exists.
`hangup` requires an existing native call; it does not cancel a pending token fetch.

## Permissions and media

The host must request dangerous permissions **before** calling:

- Audio: `RECORD_AUDIO`.
- Video: `RECORD_AUDIO` and `CAMERA`.
- Android 12+: `BLUETOOTH_CONNECT` (Nearby devices), as required by the SDK
  [integration guide](https://github.com/infobip/infobip-rtc-android#permissions).

Core's manifest contributes the permissions, including normal network/audio
permissions. The plugin checks grants before requesting a token and again before
native call creation. Core also checks permissions and network status. No
permission dialog is launched by the plugin, and no Activity is passed to Core.

Audio uses the actual `ApplicationCallOptions.builder().audio(true).video(false)`.
Video uses `.audio(true).video(true)` and therefore requests real camera media.
Current controls include microphone mute, audio routing, speaker selection, camera
switching and camera enablement. `HuaweiRtcVideoView` renders local/remote camera
tracks; `HuaweiRtcScreenAsCamera` replaces camera output for sharing. See the
[current integration guide](../README.md), [screen-sharing guide](screen-sharing.md),
[rendering](#local-and-remote-video-rendering) and
[call controls and notifications](#rtc-call-controls-and-notifications).

## Token acquisition and privacy

The exact pinned source/artifact flow is:

1. Require successful Huawei MM initialization in this engine.
2. Resolve explicit identity or current registered installation identity.
3. On a dedicated executor, create a fresh
   `MobileApiResourceProvider().getMobileApiRtc(applicationContext)`.
4. Invoke the shared API 15.1.0 `getToken(TokenBody(identity, 43200L))`.
5. Read `TokenResponse.token` natively and supply it directly to
   `CallApplicationRequest(token, applicationContext, callsConfigurationId, listener)`.

The Huawei provider derives the API URI/application authorization from initialized
MM, with the existing installation/session request headers. The shared service
declares `POST /webrtc/1/token`. This is the same token body/lifespan used by the
pinned RTC UI token provider, without importing RTC UI or recreating its cache.
Each call fetches a fresh token; no plugin token persistence or Dart token input
is added. This establishes a supported client flow, **not successful backend
authorization on a real account**. Token issuance still needs device/backend testing.

Sources: [Huawei provider at the inspected revision][provider],
[shared MobileApiRtc 15.1.0][service], [RTC UI's token provider 15.1.0][token-provider],
and the repository-only [published API signatures](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/evidence/huawei-rtc-outgoing/api-evidence.txt).

The token wait has a 30-second plugin timeout. Cancellation, timeout, MM cleanup
and engine disposal invalidate late completions; stale responses cannot start a
call or complete a result twice. Thread interruption is best effort; the vendor
HTTP client owns its actual socket cancellation/timeouts. SDK tokens are retained
only where Core requires them; the plugin has no token cache.

Method exceptions contain stable codes/messages and no native details. Event
reasons contain **only `ErrorCode.id`**, with no native name/description, custom
data, participants or HTTP responses. Core logging is disabled through the public
process-wide `InfobipRTC.setLogLevel(Level.OFF)` before outgoing calls. The plugin
does not re-enable it on hangup; integrators should not enable raw SDK diagnostics
with real credentials.

Huawei 8.14.0 authorization-header logging and RTC 2.5.28 signaling stdout logging
remain unresolved upstream risks. The latter may expose temporary TURN credentials.
Disabling Core logging does not disable these direct stdout paths. See
[security guidance](../SECURITY.md) for the optional host R8 workaround and its limits.

## Events and lifecycle

`HuaweiRtc.events` is a shared broadcast stream over a dedicated EventChannel.
Every event has a typed `type`, optional call snapshot, optional numeric
`nativeErrorCode`, and a per-engine `sequence`.

| Event | Source / meaning |
|---|---|
| `state` | Actual Core status after creation or stream attach; null call means idle |
| `ringing` | `onRinging` |
| `earlyMedia` | `onEarlyMedia` |
| `established` | `onEstablished` |
| `finished` | `onHangup`, including numeric termination reason when available |
| `error` | `onError`; **not necessarily terminal** |
| `reconnecting` / `reconnected` | Corresponding Core callbacks |
| `returnToCall` | Validated ongoing-notification tap; consume `takeNotificationCall` |

Statuses map exactly to Core's `INITIALIZING`, `INITIALIZED`, `CALLING`, `RINGING`,
`CONNECTING`, `ESTABLISHED`, `FINISHING`, `FINISHED`. There is no separate
connecting callback, so the plugin does not synthesize one. There is no Core
`FAILED` status: creation failures reject the method future; later failures are
error/hangup callbacks. A finished event can represent a normal or unsuccessful
call; inspect the numeric reason. Querying/starting with an already `FINISHED`
native reference also reconciles terminal state, with no invented reason.

Native callback kinds are preserved in queue order. A snapshot's current status
may already have advanced while the callback waited for the main thread. Subscribe
before calling. Reattachment emits the current call snapshot or replays the last
event (which may have the same sequence); this is not a complete event journal.
Malformed payloads become sanitized `FormatException` stream errors; the stream
continues accepting later events.

| Boundary | Behavior |
|---|---|
| Flutter method results | Main thread, one completion per operation |
| Native callbacks | Always queued to the main thread; stale session callbacks ignored |
| Listener cancellation | Clears Dart sink only; active call survives |
| Terminal state | Detaches forwarding closure, installs a no-op SDK listener, releases call/slot |
| Activity config recreation | Clears old Activity, binds replacement, preserves active manager/call |
| Ordinary Activity detach | Clears Activity, preserves active call; prevents new calls until resumed |
| Detach during token fetch | If still detached when token arrives, fail safely without placing a call |
| MM `cleanup()` during a call | Reject `rtc_invalid_state`; hang up and await termination first |
| MM cleanup during token fetch | Cancel pending request once; discard late token |
| Engine/plugin detach | Best-effort native hangup, cancel token work, release sinks/listeners/executor |
| Native hangup exception | Return sanitized error and retain ownership for retry |
| Partial Core creation exception | Recover only this request's call by listener identity, attempt hangup, retain until terminal |

Core owns media/signaling. Engine destruction is not ordinary Activity recreation.
If engine-disposal hangup throws, disposal cannot report remote termination; the
Core singleton's active-call check prevents a new engine from overlapping the
remaining call. No undocumented singleton reset/unregister API is invoked.

The current extension starts a microphone/camera foreground call service before
media and supplies an ongoing notification with return-to-call/hangup actions.
Start from the foreground; notification permission is host-owned. See
[call controls and notifications](#rtc-call-controls-and-notifications). Background/locked-screen media
and process-death behavior require physical Huawei validation; continuation is
not guaranteed. Incoming HMS registration remains unsupported.

## Stable errors

| Code | Meaning |
|---|---|
| `rtc_not_initialized` | MM not initialized, or no default installation identity yet |
| `rtc_invalid_argument` | Invalid typed/channel input or native argument rejection |
| `rtc_permission_denied` | Missing grant, Core MissingPermissionsException, or SecurityException |
| `rtc_call_already_active` | Plugin reservation/Core active call, including native CallInProgressException |
| `rtc_no_active_call` | Hangup has no live native call |
| `rtc_token_failed` | Token fetch/timeout/empty response, invalid or expired native token |
| `rtc_call_failed` | Other native operation exception |
| `rtc_invalid_state` | Wrong lifecycle/Core state, pending cleanup, or cancellation/disposal |

Local request validation throws `ArgumentError`. Native operation errors become
`HuaweiRtcException`; neither it nor event decoding retains platform error details.
Existing official methods keep their `webrtc_*` guards (including
`webrtc_not_enabled` for disable without a session).

## Local and remote video rendering

```dart
Widget buildVideo(String callId) => Row(children: [
  Expanded(child: SizedBox(
    height: 240,
    child: HuaweiRtcVideoView(callId: callId, source: HuaweiRtcVideoSource.local),
  )),
  Expanded(child: SizedBox(
    height: 240,
    child: HuaweiRtcVideoView(callId: callId, source: HuaweiRtcVideoSource.remote),
  )),
]);
```

Use the current native video call ID and bounded dimensions. Remote rendering
pins one unambiguous camera endpoint; unavailable/ambiguous sources remain blank.
There is no multiparty gallery or separate remote screen-track selector.
Views suspend on inactive/paused/detached Flutter lifecycle and recreate on resume.
Disposing a view releases its renderer, not the SDK track or call. Local preview
shows the substituted screen during sharing; front-camera selfie mirroring is
restored after sharing stops.

## RTC call controls and notifications

```dart
Future<void> updateCallControls(String callId) async {
  await HuaweiRtc.setMicrophoneMuted(true, callId: callId);
  await HuaweiRtc.setSpeakerEnabled(true, callId: callId);
  final controls = await HuaweiRtc.getCallControls(callId: callId);
  if (controls.availableAudioOutputs.contains(HuaweiRtcAudioOutput.earpiece)) {
    await HuaweiRtc.selectAudioOutput(HuaweiRtcAudioOutput.earpiece, callId: callId);
  }
}

Future<void> updateVideoControls(String callId) async {
  await HuaweiRtc.setCameraEnabled(true, callId: callId);
  await HuaweiRtc.switchCamera(callId: callId);
}

Future<HuaweiRtcCall?> consumeCallNotification() =>
    HuaweiRtc.takeNotificationCall();
```

Mutations require an established foreground call and its current ID. Returned
`HuaweiRtcControls` are SDK readback, not optimistic state. Speaker-off selects
earpiece explicitly and fails if absent. Audio outputs depend on device/headset
and permissions. Camera controls require video; switching also requires the camera
enabled. Camera switching/toggling is locked while capture or its shutdown is busy.

A native microphone/camera foreground service starts before media. Its ongoing
notification offers return-to-call and hangup. Grant notification permission on
Android 13+ to see it in the drawer; denial does not waive foreground-service
requirements. Handle `returnToCall`, and check `takeNotificationCall()` on initial
attachment/resume; consume the tap and open your existing call screen, without
starting a new call. Stale taps return null. Navigation away does not hang up.
Activity recreation preserves call ownership; engine disposal attempts hangup.
Background media and vendor power-management behavior require physical testing.

## Device testing

Use the [current example guide](../example/README.md): configure the ignored local
Dart test fields and actual Huawei host, initialize, grant call permissions in
Setup, then open **Huawei RTC Audio** or **Huawei RTC Video**. Configure Calls
routing and an optional authorized token subject. Exercise rendering, controls,
notifications, sharing and hangup; leaving a route does not end the call.

No physical Huawei/backend test was performed by this documentation task.
Historical reports and supplied device observations retain their own scope;
unit tests do not establish live authentication, delivery or peer media.

[provider]: https://github.com/infobip/mobile-messaging-sdk-huawei/blob/5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824/infobip-mobile-messaging-huawei-sdk/src/main/java/org/infobip/mobile/messaging/mobileapi/MobileApiResourceProvider.java
[service]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-mobile-messaging-api-java/src/main/java/org/infobip/mobile/messaging/api/rtc/MobileApiRtc.java
[token-provider]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/core/TokenProvider.kt

## Optional Live Chat customer identity

Use the additive `HuaweiRtcCallRequest.liveChatIdentity` option to resolve the
Live Chat Registration ID for the exact configured widget and expected personalized
user. Explicit RTC identity and installation fallback remain compatible. See
[customer identity and failure behavior](huawei-rtc-customer-identity.md) for Dart
usage and Huawei 8.14.0 / RTC 2.5.28 compatibility. The tested outgoing flow
displayed correct name/email; equal internal People Person IDs are not guaranteed.
Calls may create new Conversations. No supported Conversation-reuse mechanism is
verified. Agent-initiated application calls use the separate
[experimental foreground incoming flow](huawei-rtc-incoming.md), which does not
add HMS push delivery or guarantee Conversation reuse.

## Calls routing setup

See [Configure Infobip RTC Calls Routing](../README.md#configure-infobip-rtc-calls-routing) for custom configuration IDs, the built-in `conversations` destination, account-side requirements and agent verification. An RTC Push Configuration ID is not an outgoing Calls Configuration ID.
