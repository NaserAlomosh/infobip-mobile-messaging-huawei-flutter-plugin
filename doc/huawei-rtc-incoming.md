# Experimental foreground incoming RTC

Introduced in 1.1.0 and absent from version 1.0.1, this API remains
**experimental — not production ready**. It supports incoming application audio
and video calls while the host's incoming screen is open and Activity is resumed.
It does not implement background, locked-screen or terminated-app delivery,
HMS RTC push, or the guarded `enableCalls` / `enableChatCalls` APIs.

## Prerequisites and use

Initialize Mobile Messaging, wait for installation registration and complete
personalization. Use the exact configured Live Chat widget ID and expected
external user ID. See [identity setup](huawei-rtc-customer-identity.md).
Your Infobip administrator must configure application-call routing to that
customer. Peer-call delivery is a different SDK family and is unsupported here.

Subscribe to both `HuaweiRtc.incomingExperimentEvents` (invitation/preparation
state) and `HuaweiRtc.events` (accepted-call media lifecycle), with stream error
handlers, before starting. Obtain RECORD_AUDIO, CAMERA for video, and
BLUETOOTH_CONNECT on Android 12+ through the host. The plugin does not request
permissions. Start and accept only from an attached, resumed Android Activity.

```dart
final preparation = await HuaweiRtc.startForegroundIncomingExperiment(
  HuaweiRtcLiveChatIdentity(
    widgetId: configuredChatWidgetId,
    expectedExternalUserId: personalizedExternalUserId,
  ),
);
// preparation is a snapshot, not confirmation of signaling readiness.
```

Present actions only for an event with `state == 'invitation'` and a non-null
`handle`. Retain that opaque handle only for this invitation; never persist it.
After the user chooses an action:

```dart
final call = await HuaweiRtc.acceptExperimentalIncomingCall(
  handle: invitation.handle!,
  video: userChoseCameraEnabledVideo, // false requests audio only
);
// Wait for HuaweiRtc.events establishment before reporting connected media.
// Alternatively, for the same still-pending invitation:
// await HuaweiRtc.declineExperimentalIncomingCall(handle: invitation.handle!);
```

Automatic detection of the remote offered audio/video type is unavailable.
`offeredCallType` is `unknown`; `videoSupported` means local video acceptance is
available, not that the agent offered video. Video acceptance explicitly enables
local camera publication. A failed video acceptance does not fall back to audio.

Accepted calls reuse `HuaweiRtcVideoView` for local/remote video and existing
call-ID-scoped microphone, camera, camera-switching and speaker/output controls.
See [media controls](huawei-rtc-outgoing.md). Bidirectional audio/video, Accept,
Decline, native ringtone, speakerphone routing and termination are implemented.
Ringtone playback respects silent mode, volume and DND; speaker preference is
best-effort and yields to external/unknown outputs. Incoming acceptance sets
auto-reconnect to false. Reconnection callbacks do not promise idle registration
recovery or automatic call restoration.

## Events, errors and terminal state

The incoming stream replays a current snapshot on attachment and may repeat
snapshots. It is not durable history or a signaling-readiness acknowledgment.

| State | Meaning |
| --- | --- |
| `idle` | Preparation has not started. |
| `preparing` | Native identity lookup/token acquisition is pending. |
| `registrationRequested` | SDK registration invocation returned; readiness is unconfirmed. |
| `invitation` | A current invitation may be acted on while its handle and host remain valid. |
| `connecting` | Acceptance was initiated; connected media is not confirmed. |
| `connected` | An established/reconnected SDK callback was observed. |
| `reconnecting` | A call callback was observed; no recovery guarantee is added. |
| `declining`, `ending` | Termination was requested, not confirmed. |
| `ended` | Terminal callback/status was observed for the invitation. |
| `failed` | Listener/acceptance failed; native termination may still be pending. |
| `paused` | The screen was explicitly closed; signaling may remain registered. |
| `invalidated` | This process's incoming flow cannot be restarted. |

`paused` and `invalidated` can mask the underlying call phase. For accepted calls,
also observe `HuaweiRtc.events` for `finished`; do not infer terminal media cleanup
from the screen state. A successful accept/decline/hangup return is only a request
result. Unconfirmed termination retains call-slot ownership and can block another
call until the SDK confirms termination.

`reason` is nullable explanatory data, not an exception or a terminal flag. Current
values include `identity_changed`, `engine_detached`, `engine_replaced`,
`preparation_timeout`, `preparation_failed`, `registration_failed`, `listener_failed`,
`accept_failed`, `termination_unconfirmed`, `cancelled`, `sdk_finished`, and
`sdk_error_<number>` / `sdk_hangup_<number>`. Reasons can persist across snapshots;
handle unfamiliar values defensively. An SDK error need not mean a finished call.

Method-channel errors become `HuaweiRtcException`, including invalid state,
permissions, busy call-slot, and SDK failures. Identity construction rejects blank
values with `ArgumentError`; malformed channel snapshots produce `FormatException`.
Preparation failures after Start are reported by incoming state/reason, not
necessarily by the already completed Start future. Permission denial before
adoption leaves the invitation pending; retry only if its handle remains valid.

Diagnostics are bounded, allowlisted debug observations. They are absent from
normal release use, can be missing/dropped, and are not readiness, delivery or
media acknowledgments. Do not use diagnostic names or counts for application
logic. Tokens, registration IDs and raw SDK payloads are not exposed by this flow;
the existing [upstream security limitations](../SECURITY.md) remain unchanged.

## Registration lifetime and cleanup

- One fixed identity and one preparation/registration attempt are permitted per
  process. Repeating Start for the same still-valid identity reopens the screen;
  it does not fetch another token or re-register. Failed/timed-out preparation
  requires process recreation before retrying.
- Tokens are acquired natively. The requested lifetime is 43,200 seconds; actual
  issued expiry and long-running signaling availability are not guaranteed.
  No supported active-registration token replacement, refresh or unregister API
  is available. There is no automatic retry or idle connection-readiness signal.
- Logout, account/personalization changes, initialization/cleanup mutations and
  Flutter engine replacement/detachment invalidate the flow. Even switching back
  to the same user does not restore it. Recreate the application process before
  starting again; local invalidation is not proof of server-side revocation.
- Call `closeForegroundIncomingExperimentScreen()` when disposing the incoming
  screen and handle its future/errors. It hides invitations, declines a pending
  one or requests accepted-call hangup. It does not unregister native signaling.
  Canceling the event subscription alone does not close the flow.
- Activity pause/detach silences ringtone. Foreground loss is checked every
  250 ms and requests invitation/call termination. A quick Activity recreation
  can preserve an invitation; do not promise continuity. Engine detach also
  detaches local listeners/renderers and retains uncertain native ownership until
  terminal observation. Do not confuse these rules with outgoing call continuity.

Existing Infobip Conversation reuse is not established. Correct customer identity
or successful incoming media does not prove Conversation binding or future routing.

The project owner reports Huawei-device verification of outgoing/incoming
foreground audio/video, bidirectional media, Accept/Decline, ringtone/speaker
routing, camera/microphone controls and termination. That evidence does not certify
background delivery, token renewal, all Android versions or every lifecycle case.
