# Incoming RTC foreground experiment

**EXPERIMENTAL — NOT PRODUCTION READY**

## Current status — 2026-10-25

The implemented experimental foreground flow supports application audio/video
invitations, Accept/Decline, native ringtone with speaker routing, local/remote
video, microphone/camera/speaker controls and termination cleanup. The project
owner reports these capabilities physically verified on a Huawei device. This
documentation update did not repeat those device tests or establish a complete
Android/OEM, token-expiry or account-lifecycle acceptance matrix.

Use the concise [consumer guide](huawei-rtc-incoming.md) for the current contract.
Background and terminated-app calls remain unsupported. Registration is
process-scoped, with no supported renewal/unregister; incoming auto-reconnect is
disabled, offered media type is unknown and Conversation reuse is not established.

The sections below retain the investigation chronology. Earlier “not received”
or “NOT RUN” results describe their dated tests, not the latest owner-supplied
feature results. This report stays excluded from the published package.

## Version and API evidence

The current Android debug runtime dependency graph resolves:

| Component | Version |
| --- | --- |
| Huawei Mobile Messaging / Chat / Inbox | 8.14.0 |
| Infobip RTC Core | 2.5.28 |
| HMS Push (existing messaging dependency) | 6.7.0.300 |

No dependency or build configuration was changed for this experiment. The existing
RTC UI contract-inspection dependency is not an incoming runtime integration.

Before implementation, `javap` inspection of `classes.jar` from the cached
`com.infobip:infobip-rtc:2.5.28` AAR verified these public APIs:

- `InfobipRTC.registerForActiveConnection(String, Context, IncomingApplicationCallEventListener)`
- `IncomingApplicationCallEventListener.onIncomingApplicationCall(event.rtc.IncomingApplicationCallEvent)`
- `IncomingApplicationCallEvent.getIncomingApplicationCall()`
- `IncomingApplicationCall extends ApplicationCall`
- `IncomingApplicationCall.accept(ApplicationCallOptions)` and `decline()`
- `ApplicationCall.setEventListener(ApplicationCallEventListener)` and `hangup()`
- `ApplicationCallOptions.builder().audio(...).video(...).autoReconnect(...).build()`

The public interface provides no active-connection unregister or registration-ready
callback, nor an idle connection-state callback. The POC invokes no internal APIs,
reflection, disconnect methods, singleton resets, push registration or push handlers.
Inspection of implementation bytecode is evidence only; all runtime calls use the
public interface.

Core internally replaces its default singleton with an active-connection instance
on registration. Subsequent calls to `getInstance()` use that instance. The plugin
continues to use its existing backend and one process call slot; no second RTC
singleton is created. Registration is blocked while a call or outgoing preparation
owns that slot. Outgoing algorithm, identity resolution, token provider, rendering,
notification service, and control meanings are unchanged. Real outgoing behavior
in the SDK's active-connection mode still requires device regression testing.

## Scope and limitations

- **Explicit audio/video acceptance; offered media type unknown.** Core 2.5.28
  exposes `accept(ApplicationCallOptions)` with video, but no public remote-offer
  media accessor. Incoming constructors initialize `options()` with defaults.
  `videoSupported` describes the local acceptance path, not agent intent.
  `offeredCallType` is always `unknown`. See the incoming video update below.
- Application-call family only. The registered listener is explicitly
  `IncomingApplicationCallEventListener`. No peer/WebRTC call is cast into this
  family. A peer-call Portal configuration is incompatible with this experiment.
  Silence alone cannot diagnose the family; verify it in Portal/backend evidence.
- Foreground screen only; there is no HMS RTC push, FCM integration, background
  invitation UI, locked-screen delivery, process-death recovery, token refresh,
  automatic registration retry, or plugin-driven idle reconnection.
- One fixed customer and one start/preparation attempt per process. A failed or
  timed-out attempt requires process termination. Duplicate starts for the same
  valid identity reuse the experiment without fetching another token or registering.
- Closing the RTC screen hides invitations, declines a pending invitation or asks
  an accepted incoming call to hang up. Reopening requires explicit Start for the
  same identity. **Signaling remains registered.** Screen closure is not unregister.
- Foreground loss is checked every 250 ms. Invitations cannot be accepted while
  the Activity is not resumed. A recreation completed before the watchdog check
  can preserve an invitation; a longer pause asks it to end. The signaling owner
  holds application context, never Activity context.
- Plugin account/initialization/cleanup mutation invalidates the experiment
  synchronously through the existing identity-mutation boundary. Public MM identity
  broadcasts also trigger validation immediately (personalization/depersonalization
  invalidates even for the same user). A 250 ms guard
  additionally validates the resolved native user/installation snapshot and epoch.
  Every incoming delivery and accept/decline validates again. Direct SDK changes
  outside plugin methods are detected at these checks, not via an invented MM
  identity-change callback. Transient changes outside the plugin with no MM event that are reverted
  between checks cannot be proven observable.
- Logout, personalization change, user/installation change, engine replacement,
  or engine detach permanently invalidates the experiment. It hides invitations,
  rejects stale actions, and requests termination. **It does not unregister Core.**
  Terminate the process before testing another identity. Production logout/account
  switching is unsupported.
- A void accept/decline/hangup return is not an acknowledgment of establishment or
  termination. Terminal callbacks/status release the reservation. Unconfirmed
  termination retains ownership. Engine detach releases local views/media bindings
  and retains an uncertain incoming call in the process coordinator until terminal.
- Registration can remain in “Registration requested / waiting for incoming
  signaling” indefinitely. No socket-ready or delivery-success event is fabricated.
  Call-level error/reconnecting callbacks are not idle registration readiness.
- No caller name is shown; no caller identifiers or raw custom data are read for UI.
  Registration ID and access token stay native. Diagnostic events contain only
  state, an opaque local handle, family, capability flags, attempted flag and a
  fixed reason or numeric SDK error. Existing SDK internal logging limitations are
  not remedied by this POC; do not collect/share unfiltered SDK or backend logs.
- This is not a multi-engine/multi-account experiment. Replacing an attached engine
  after Start invalidates it. There is no supported registration replacement.

## Flutter surface and native ownership

Opt in with `HuaweiRtc.startForegroundIncomingExperiment(HuaweiRtcLiveChatIdentity(...))`
using the configured widget and expected personalized external user. The production
`NativeLiveChatIdentityResolver` resolves that widget against the current MM
installation; its registration subject is passed to the existing native token
provider. Neither subject nor token is returned to Dart.

`HuaweiRtc.incomingExperimentEvents` uses a separate event channel and replays the
current pending invitation for late listeners. `acceptExperimentalIncomingCall`
and `declineExperimentalIncomingCall` require its opaque handle. Accepted audio/video
calls are transferred atomically to `HuaweiRtcManager`, reusing `HuaweiRtc.events`,
`getActiveCall`, `hangup`, microphone/speaker/output controls and terminal cleanup.
The experiment adds no incoming notification service. The normal outgoing service
behavior is unchanged. Hosts must call `closeForegroundIncomingExperimentScreen`
on screen disposal, as the example does.

## Portal prerequisites — require operator verification

Use a test tenant/application and authorized agent with Conversations Web/In-app
application calling configured. Initialize the example with the correct application
and Live Chat widget, then personalize the configured customer before starting.
The Portal conversation must belong to that same widget/customer/installation
mapping. The RTC token endpoint must authorize application calling for the native
resolved Chat registration subject. No Conversation ID is supplied to RTC.

**UNVERIFIED:** tenant routing/entitlement, Portal application-versus-peer call
family, token-to-customer identity mapping, and existing Conversation association.
An operator must verify these against their Portal configuration and Infobip
backend contract. This POC does not provide routing hacks, conversation merging or
Conversation ID injection.

## Physical Huawei procedure and result record

1. Use a physical Huawei device and a fresh application process. Initialize MM,
   wait for installation registration, then personalize the configured customer.
2. Grant microphone and Nearby devices (Android 12+) permissions in Android app
   settings. Keep the app foregrounded on the existing audio/video RTC screen.
3. In **Incoming RTC — Experimental**, tap **Start foreground incoming experiment**.
   Record preparation/attempt status. The expected non-authoritative state is
   **Registration requested / waiting for incoming signaling. Readiness unconfirmed.**
4. Open the existing customer conversation in Infobip Conversations Portal. Verify
   with the operator that the agent action uses application calling; initiate it.
5. Record whether an invitation actually appears. If it does, choose **Accept Audio**.
   Verify Connecting then Connected, bidirectional audio, microphone mute,
   speaker/audio output, local hangup and remote hangup. Record actual device results.
6. Repeat with the same identity: decline; cancel from Portal before acceptance;
   cancel while acceptance is in progress; interrupt network; leave/reopen the screen;
   recreate Activity; and detach engine. Check that stale actions cannot act on a
   new invitation and uncertain termination prevents a replacement call.
7. Place an outgoing call, then initiate an incoming call. Check safe decline/no
   takeover. Repeat outgoing audio/video and controls after registration and after
   incoming termination. Automated mocks do not establish SDK mode compatibility.
8. Record whether Portal retained the existing Conversation or created another one.
   Do not infer this from a received invitation or successful audio.
9. Before testing another user, **terminate the process**, relaunch, initialize and
   personalize again. Navigating away, logout or Flutter hot restart is insufficient.

If no invitation arrives, report all fields separately:

| Evidence | How to record |
| --- | --- |
| Registration attempted | `registrationAttempted` true/false; requested/failed reason |
| Socket connection | UNOBSERVABLE through selected public idle callbacks; do not infer from silence |
| Registered listener | `IncomingApplicationCallEventListener`, application-call overload |
| Portal application calling | VERIFIED by operator evidence, or UNVERIFIED |
| Identity mapping | VERIFIED by backend/device evidence, or UNVERIFIED |
| Incoming delivery | NOT RECEIVED during the stated foreground test interval |
| Existing Conversation association | Observed result, or UNVERIFIED |

Success requires an actual agent invitation delivered to the physical device while
foregrounded. Further success requires acceptance, two-way audio, decline,
cancellation/hangup handling and outgoing regression checks. Incoming video is
**PENDING** and not claimed by this implementation. Compilation and unit tests
prove neither delivery nor Portal association. All physical-device/Portal results
are currently **NOT RUN / UNVERIFIED**.

## Automated validation

Focused tests cover the one-attempt rule, resolved token subject, event privacy,
duplicate starts/deliveries, opaque handles, late listeners, audio adoption through
the existing manager, permission rejection, decline/terminal ownership, cancellation
before/during accept, stale actions, incoming/outgoing conflicts, account/installation
invalidation, screen/Activity/engine lifecycle, network-error state, timeout and
uncertain termination cleanup. Existing RTC tests exercise outgoing manager,
identity, controls, call service, video bindings/renderers and screen capture.

Commands (Flutter 3.35.7; JDK 21; existing Gradle/build settings unchanged):

```sh
# From example/android
JAVA_HOME=/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home ./gradlew \
  :infobip_mobilemessaging_huawei:testDebugUnitTest \
  --tests '*ForegroundIncomingExperimentTest' --tests '*HuaweiRtc*Test'

# From repository root
flutter test --no-pub test/huawei_rtc_incoming_experiment_test.dart \
  test/huawei_rtc_test.dart test/huawei_rtc_controls_test.dart \
  test/huawei_rtc_video_view_test.dart test/huawei_rtc_screen_as_camera_test.dart
flutter analyze --no-pub

# From example
flutter test --no-pub test/huawei_rtc_screen_test.dart test/rtc_live_chat_identity_test.dart
```

Validation on 2026-10-19:

| Check | Result |
| --- | --- |
| Kotlin compilation + focused RTC suites | PASS: 186 tests, including 30 incoming experiment tests; 0 failures/errors/skips |
| Dart RTC suites | PASS: 42 tests, including 4 incoming channel/model tests |
| Example RTC/identity widget suites | PASS: 13 tests, including explicit registration and invitation UI |
| `flutter analyze --no-pub` | 21 informational deprecations in unchanged files; no errors/warnings or experiment diagnostics (command exits nonzero for infos) |
| `git diff --check` | PASS |
| Original three local-change file hashes | Unchanged |
| Physical Huawei / Portal / bidirectional media | NOT RUN |
| Incoming video | PENDING; no reliable public offered-video flag verified |

Kotlin compilation emits deprecation warnings for the existing MM broadcast
mechanism (`LocalBroadcastManager`), which this experiment also uses. No dependency
or toolchain changes were made to silence warnings.

This document is an experiment procedure, not a release note or production support statement.

## Debug diagnostics (2026-10-22)

The physical foreground test was reported to receive no agent invitation. The
older NOT RUN record above describes the original automated-validation run, not
this subsequent device result. No correlated socket/backend trace was supplied.
The new diagnostics have not yet been validated on a physical Huawei device.

### Flow and privacy

`HuaweiRtcScreen._incomingAction` → `HuaweiRtc.startForegroundIncomingExperiment`
→ existing RTC MethodChannel → `HuaweiRtcManager.onMethodCall`
→ `ForegroundIncomingExperiment.start` → `NativeLiveChatIdentityResolver.resolve`
→ `HuaweiRtcTokenProvider.fetch` → Core `registerForActiveConnection`
→ application incoming listener → `receive` admission guards → existing experiment
EventChannel → Dart decoder → screen receipt marker. Accepted audio still uses
the original manager, media listener, controls and termination ownership.

Native diagnostic collection is enabled only when the host has Android
`ApplicationInfo.FLAG_DEBUGGABLE`; Dart decoding and the section in the example
screen additionally require `kDebugMode`. No new SDK logging is enabled. The
collector retains at most 100 fixed-code events in process memory and adds them
to the existing experiment snapshots. Entries contain only sequence number,
wall-clock UTC-compatible timestamp, fixed event code and optional numeric call
error code. No IDs (including call IDs), tokens, token claims, user details,
widget values, exception messages, stack traces, custom data or raw SDK payloads
are added. There is no persistence/export or network telemetry. The screen also
retains at most 100 timestamped lines and filters native event codes. Existing
invitation handles/state remain outside the diagnostic log.

Worker-stage timestamps reflect the time of occurrence; sequence numbers reflect
main-thread recording order. Device clock changes can change wall-clock order.
Native channel enqueue and Flutter receipt are deliberately separate events.
`event_sink_write_returned` only means `EventSink.success` returned. It appears
on the next snapshot; the screen's `flutter_event_received` proves that the Dart
subscription received a snapshot, not that an invitation arrived. Watchdog
snapshots and replayed history are deduplicated in the UI. Events older than the
100-entry window may be evicted.

### Core 2.5.28 inspection and limits

Inspected the cached original `infobip-rtc-2.5.28.aar` and its existing
`classes.jar` with `javap`; no SDK/dependency changes were made.

- `api.InfobipRTC`: separate public application and peer
  `registerForActiveConnection(String, Context, listener)` overloads. There is no
  combined registration overload, idle readiness/authentication/error listener,
  supported listener getter, active-mode getter, unregister or token replacement
  method. Call-level error/reconnecting/reconnected callbacks are observed through
  the existing listener after an invitation; they cannot diagnose idle signaling.
- `impl.DefaultInfobipRTC.registerForActiveConnection`: switches the singleton only
  when its current instance is `PushInfobipRTC`. Otherwise it returns without
  replacing the token/listener. A repeated call can therefore retain an older
  registration without throwing. This is implementation evidence, not a new API.
- `impl.ActiveConnectionInfobipRTC`: has an internal implementation constructor
  accepting both listener families, but the public registration API does not
  expose it. The application-only overload supplies null for the peer listener.
  Constructing/replacing this instance, registering another listener, reflection,
  and subscribing to the SDK's internal event bus are not used.
- `impl.DefaultInfobipRTC.onRTCConnectedEvent/onRTCDisconnectedEvent`: internal
  handlers do not expose a public idle observer. Internal `isConnected()` is not
  a member of `api.InfobipRTC` and is not called.

Debug preflight obtains a reference through public `InfobipRTC.getInstance()`;
it compares that reference with another public getInstance result after the
single existing registration invocation. It does not inspect class names,
fields, token contents or SDK internals. `singleton_reference_changed` is
consistent with the inspected default-to-active transition, **not proof of
connection or authentication**. An unchanged reference means prior active
registration is possible; it does not identify its owner, subject, token age or
listener. Pre-existing mode and captured token/listener remain **unobservable
through public APIs**. A failed singleton observation is diagnostic only and
never prevents or retries registration. Duplicate Start uses the existing
experiment and records `start_reused`; it does not obtain a replacement token.

### Manual Huawei procedure

1. Use a physical Huawei device with the debug example build and configured test
   tenant/widget/customer. Completely terminate the previous application process;
   hot restart, navigation and logout are insufficient to clear Core registration.
2. Initialize Mobile Messaging, wait for installation registration, personalize
   the test customer and open the RTC screen. Grant the existing audio permissions.
   Keep the Activity resumed, the screen open and outgoing calls idle. Do not
   change user, initialization or installation during the attempt.
3. Expand/scroll to **Incoming diagnostics — debug only**. Press **Start foreground
   incoming experiment** once. Record the UTC interval and sanitized diagnostic
   lines. Expect identity lookup, token acquisition and registration invocation
   stages, ending in `registration_returned_readiness_unconfirmed`. A Start return
   in `preparing` is expected; it is not completed registration.
4. Record whether the singleton reference changed. If unchanged on this first
   Start, repeat only after fully terminating the process. Do not press Start
   repeatedly or try the peer registration overload.
5. Ask the authorized operator to verify that the existing Live Chat Conversation
   belongs to the same configured customer/widget/installation, and that the agent
   action is application calling. Place exactly one call after registration has
   returned. Keep the foreground screen idle for 60 seconds. Record whether
   `invitation_callback`, `invitation_published` and a subsequent
   `flutter_event_received` appear. Readiness remains unconfirmed during the wait.
6. If an invitation appears, accept Audio and verify Connecting → Connected,
   two-way audio and local/remote hangup. On separate invitations test Decline and
   agent cancellation. Preserve the distinction between method return and terminal
   callbacks. Incoming video remains unverified and disabled.
7. If no native callback appears, correlate the UTC interval with Infobip/backend
   traces: authenticated socket subject/application, connection close/auth failure,
   agent invitation destination, call family and delivery result. Exchange any
   identifiers only through the authorized support channel; they are deliberately
   absent from the debug screen. Check device/build clock against server time.
8. For regression, after a fresh process verify outgoing audio and video using
   their existing identity modes, controls and hangup. Then repeat outgoing after
   incoming registration/termination. SDK active-mode compatibility still requires
   this physical check; automated tests are insufficient.
9. Confirm the diagnostics section is absent in a profile/release Flutter build;
   a non-debuggable Android host must not serialize diagnostic entries. Do not
   change configuration, install Firebase/HMS RTC push, or alter routing as part
   of collecting this baseline.

### Interpretation table

| Last evidence | Interpretation / next check |
| --- | --- |
| `flutter_start_requested` only | Start may be awaiting example refresh/personalization, or channel invocation failed; inspect `flutter_operation_failed` and native Start receipt. |
| `start_rejected_*` | Local argument, foreground or call-slot gate blocked registration. Correct that prerequisite. |
| `identity_resolution_failed` | Live Chat lookup or its local identity/unique-widget checks failed. Check initialization/personalization/widget/registration with the operator. No credentials are exposed. |
| `token_request_failed` | Token provider failed. Check Mobile Messaging token authorization/backend response through authorized traces. |
| `preparation_result_discarded` / invalidated state | Timeout or lifecycle/identity mutation made preparation stale. A fresh process is required. |
| `registration_invoked` then `registration_threw` | SDK invocation threw synchronously; no success is claimed. Exception contents are suppressed. |
| `singleton_reference_unchanged_prior_registration_possible` | SDK may already retain an earlier token/listener. Mode/ownership cannot be confirmed publicly. Repeat with a fresh process and correlate server registration. |
| `singleton_reference_changed` | Singleton transition observed, not authenticated connection. |
| `registration_returned_readiness_unconfirmed`, no callback | Locally indistinguishable: socket/auth failure, identity/application mismatch, wrong call family, or routing failure. Obtain server traces. |
| `peer_family_unobserved` | Application listener only. Peer invitation delivery is not observed, and a second listener is not installed. Verify agent call family on the server. |
| `invitation_callback` + `rejected_*` | SDK delivered an application invitation; local invalidation, visibility, readiness, pending invitation or call-slot guard rejected it. The reason identifies the guard. |
| `rejection_decline_failed` | Local decline threw; remote termination is not established. |
| `invitation_listener_failed` | Invitation arrived but installing its existing call listener failed; presentation termination is attempted. |
| `invitation_published` + `event_sink_write_failed` | Native invitation exists but EventChannel delivery threw. Reattachment replays buffered diagnostics/current state. |
| `event_sink_write_returned`, no Flutter receipt | Transport enqueue returned; verify Dart subscription, decode/UI state and engine lifecycle. This is not a delivery acknowledgment. |
| `flutter_event_received` after invitation event | Dart received the snapshot. Check invitation UI/admission state separately. |
| `accept_adoption_failed` | Existing media manager rejected adoption (for example permission or ownership checks); no new media path was added. |
| `call_error` / `call_reconnecting` / `call_reconnected` | Actual call-level SDK callback; optional numeric error code is safe. Not an idle registration callback. |
| `accept_returned` / `decline_returned` | Method returned; wait for established/finished callback or terminal status. |

All diagnostics identify boundaries; none establish why a server failed to route
an invitation or whether an existing Conversation was reused.

### Diagnostic validation (2026-10-22)

| Check | Result |
| --- | --- |
| Native focused incoming + existing `HuaweiRtc*` regression suites, JDK 21 / cached Gradle dependencies | PASS: 195 tests, zero failures/errors/skips (39 incoming experiment tests) |
| Dart incoming/outgoing/control/video/screen-as-camera suites | PASS: 43 tests |
| Example RTC screen and Live Chat identity widget suites | PASS: 13 tests |
| Static analysis | No errors or warnings; 21 existing deprecation infos in untouched files; analyzer exits nonzero for infos |
| Diagnostic privacy/gating | Tests cover fixed codes, sensitive exception/payload exclusion, disabled collection, bounded history, singleton unchanged/changed, call error codes, channel failure/replay and Flutter rendering |
| Diff/whitespace and preservation | PASS; unrelated tracked file hashes unchanged from the start-of-task snapshot; branch/HEAD unchanged |
| Physical Huawei, Portal routing, socket authentication, audio/video regression on device | NOT RUN in this task; use the manual procedure above |

Changes remain uncommitted and unpushed.

## Incoming ringtone (2026-10-22)

Updated device evidence supplied by the user: the agent invitation reaches the
foreground Huawei application, Accept/Decline appear, acceptance succeeds and
bidirectional call audio works. The remaining reported problem was missing
pre-acceptance ringing. These user-reported results supersede earlier delivery
uncertainty for that tested setup; no new physical-device test was performed by
this implementation task. **The new ringtone playback is not device-verified.**

### Implementation and ownership

`IncomingRingtone.kt` adds the small `AndroidIncomingRingtone` controller. The
process-owned incoming experiment constructs it with application context only.
It uses `RingtoneManager.getActualDefaultRingtoneUri(TYPE_RINGTONE)` and
`RingtoneManager.getRingtone`. If loading the selected sound fails/returns null,
it tries the default ringtone URI alias, allowing Android's built-in fallback.
A null actual URI represents an intentionally silent default and does not trigger
fallback. It never substitutes an alarm or notification to bypass silence.

The player uses `USAGE_NOTIFICATION_RINGTONE` / `CONTENT_TYPE_SONIFICATION`, checks
normal ringer mode and nonzero `STREAM_RING` volume, and never requests audio
focus, changes AudioManager mode/volume/routing, toggles speakerphone, or touches
microphone/camera controls. Silent/vibrate/zero ring volume suppress playback;
there is no added vibration. Android DND and OEM audio policies remain in force.
See Android's [RingtoneManager](https://developer.android.com/reference/android/media/RingtoneManager)
and [Ringtone](https://developer.android.com/reference/android/media/Ringtone)
API documentation.

API 28+ uses native `setLooping(true)`. On supported API 26–27 devices, the existing
250 ms experiment watchdog replays the same player only after it reports playback
finished. It also checks ringer mode/volume changes. There is no separate timer,
media service, resource cursor, Activity reference or external dependency.

Start/stop are idempotent. Successful stop drops the Ringtone reference; the
AudioManager is acquired only for settings reads, with no audio-focus lease to
release. If platform stop throws, the controller retains that uncertain player,
suppresses creation of another player and retries stop on watchdog updates or
subsequent lifecycle/termination cleanup. It never overlaps a replacement sound.
Persistent platform stop failure cannot be guaranteed recoverable by app code;
process termination is the final fallback. Lookup/playback errors are contained
and do not escape into RTC or log URIs, payloads or identities.

### Start and stop boundaries

| Boundary | Ringtone behavior |
| --- | --- |
| Registration/token preparation | No sound. |
| Valid invitation passes identity/foreground/call-slot guards, gets its call listener, and enters `invitation` state | Start once, unless SDK status is already connecting, established, finishing or finished. |
| Duplicate invitation for the current call | No restart or second player. |
| Rejected/stale/invalid/finished invitation | Never starts. A finishing call retains its native reservation until actual termination. |
| Valid Accept Audio | Stop before manager adoption/permissions or SDK acceptance, including adoption/accept failures. |
| Valid Decline | Stop before SDK decline, including SDK decline errors. |
| Remote cancellation / SDK hangup / terminal status | Stop in the existing incoming listener or terminal cleanup. Watchdog status polling covers missing callbacks. |
| SDK error or established callback | Stop; no automatic ringtone restart. |
| Screen closure / identity invalidation / engine detach/replacement | Stop through experiment cleanup. |
| Host Activity pause/stop/destroy/detach | Stop immediately through application ActivityLifecycleCallbacks, without disposing the RTC manager or changing outgoing calls. |
| Ringer becomes silent/vibrate or ring volume reaches zero | Stop at the next watchdog update; changing back does not restart this invitation. |
| Next independent invitation after previous termination | Can ring using a new playback instance. |

The plugin registers its Activity lifecycle callback while attached and unregisters
it on detach/replacement. The callback acts only on the currently attached host
Activity; it owns no extra Activity reference. The existing foreground/watchdog
and call ownership rules remain unchanged. Resuming/reopening does not restart
ringing for an already silenced invitation. There are no changes to outgoing
request construction, token selection, media options, notifications or controls.

### Physical Huawei ringtone checks

1. Install/run the updated example on the same physical Huawei device and tenant
   where incoming audio was confirmed. Start with a fresh process, initialize,
   personalize, open the experimental RTC screen and register once.
2. In Android sound settings choose an audible default ringtone, normal sound
   mode and nonzero **ring** volume. Keep the screen foregrounded. Have the agent
   place one application call. Confirm the pending invitation UI and one looping
   ringtone before accepting; registration itself must stay silent.
3. Tap Accept Audio. Confirm sound stops on the tap, before call audio starts;
   verify two-way audio, microphone mute, speaker/output controls and remote/local
   hangup. Confirm no ringtone returns after establishment or termination.
4. On separate incoming calls test Decline, agent cancellation before acceptance,
   remote hangup, network failure and repeated calls after terminal completion.
   Each valid new invitation may ring; none may overlap or resume after ending.
5. While ringing, close the experiment screen, press Home, lock the device and
   recreate the Activity (for example rotate where supported). Confirm playback
   stops. Resume/reopen and confirm there is no unsolicited ringtone restart.
   Also test identity change and engine disposal through the existing example
   flows. A new account experiment still requires process restart.
6. Repeat with silent mode, vibrate mode, zero ring volume and the device's
   deliberately silent/None default ringtone. Expect no sound and working
   invitation controls. Change sound mode/volume while ringing and confirm stop.
   Verify DND behavior against the device's own allowed-call policy.
7. Where possible, test an unavailable custom ringtone to exercise the Android
   default fallback. Test Android 26–27 separately if those devices are supported;
   short gaps between replays are possible on this older API path.
8. Regression: from a fresh process place outgoing audio and video calls, then
   repeat after incoming acceptance/termination and after ringing was silenced.
   Confirm routing, speakerphone, microphone, camera, video rendering and hangup.

Automated tests cannot establish audible playback, DND/OEM behavior, route
selection or absence of real RTC audio interference on the physical device.

### Ringtone automated validation

- Native JDK 21 / offline Gradle run: `IncomingRingtoneTest`,
  `ForegroundIncomingExperimentTest`, and existing `HuaweiRtc*Test` suites:
  **215 passed; zero failures/errors/skips**. Includes 9 controller tests, 49
  experiment tests and 5 plugin lifecycle tests.
- Existing Dart incoming/outgoing/control/video/screen-as-camera suites:
  **43 passed**.
- Existing example RTC/Live Chat identity widget suites: **13 passed**.
- Diff/whitespace checks passed. Baseline hashes verified that all unrelated
  pre-existing tracked/untracked files are unchanged. Branch and HEAD unchanged;
  no commits, pushes, dependency or manifest changes.
- Physical ringtone playback and real-device audio regression: **NOT RUN**.

## Scoped ringtone routing update (2026-10-23)

The user confirmed that the original native ringtone is audible on physical Huawei
hardware, but through the call earpiece. The new loudspeaker preference described
below has **not been physically verified**. This section supersedes the previous
Ringtone implementation and older Android 26–27 replay description.

### Inspected cause and timing

Cached RTC Core 2.5.28 `classes.jar` inspection (`javap -c -p`) established:

- `impl.util.EventFactory.incomingApplicationCall(...)` constructs
  `DefaultIncomingApplicationCall` before constructing the application invitation
  event delivered to the plugin.
- `DefaultIncomingApplicationCall` invokes the `DefaultApplicationCall`
  constructor. That constructor creates `DefaultAudioDeviceManager` and invokes
  `start()` before returning. Thus RTC configures audio before our pending-state
  ringtone and before customer acceptance.
- `DefaultAudioDeviceManager.<init>` chooses EARPIECE as the default when present,
  saves previous system state, calls `AudioManager.setMode(3)`
  (`MODE_IN_COMMUNICATION`), `setSpeakerphoneOn(false)`, unmutes the microphone
  and requests audio focus. `setNewAudioDevice` can subsequently use mode 2 for
  EARPIECE or mode 3 for other routes. The actual mode/device at ringing time must
  be read on the physical device; the constructor value is not a runtime guarantee.
- Existing `HuaweiRtcControls.setSpeakerEnabled` delegates to the SDK's
  `selectAudioDevice`; the ringtone must not invoke that control. Outgoing and
  accepted-call controls remain unchanged.
- The previous `Ringtone` uses `USAGE_NOTIFICATION_RINGTONE` but exposes no public
  per-player preferred output setter. Its placement after SDK audio initialization
  explains why platform/OEM communication routing can affect it. The exact Huawei
  audio-policy decision is not provable from local source alone.

### Implemented strategy

Only `IncomingRingtone.kt`, `IncomingRingtoneTest.kt` and this guide change in this
update. The existing invitation, Accept/Decline, cancellation, error, watchdog and
Activity/plugin cleanup hooks remain intact.

`RingtoneManager` still resolves whether the user's default ringtone is deliberately
Silent. For an audible selection, its default URI alias is loaded by a scoped
`MediaPlayer`, using Android's cached/default URI handling. Playback uses ringtone
AudioAttributes and native looping on all supported Android versions. Preparation
is asynchronous so Accept/cancel can release the player while it is loading.
Stale prepared/error callbacks cannot start or release a subsequent invitation's
player. Setup/preparation/playback failures release the owned player and remain
contained; no credentials, file URI or exception text are logged.

On Android 28+, when output enumeration contains only the built-in speaker and/or
earpiece, the controller requests the available built-in speaker with
`MediaPlayer.setPreferredDevice`. Rejection, absence of the speaker or enumeration
failure leaves default routing. If any other output type is present (including
Bluetooth, wired or USB), no speaker preference is requested. This deliberately
conservative rule protects connected external devices even when they are not the
current route. Devices are rechecked before actual start and by the existing
250 ms watchdog. A newly connected external device clears only the ringtone
player's preference. Clearing failure releases playback instead of forcing a route.
Disconnecting that device does not reassert speaker preference for the same call.

On Android 26–27, MediaPlayer's public preferred-output API is unavailable, so
playback uses default routing and logs that limitation in debuggable builds.
No AudioManager mode/speakerphone/communication-device/volume/microphone setters,
SCO controls or audio-focus requests are used. No global state is saved/restored;
cleanup therefore cannot overwrite a newer SDK routing decision. Audio focus,
echo processing and call routing remain owned by RTC. Player release removes the
local preference before SDK acceptance. No dependencies or permissions were added.

Silent/vibrate/zero ring volume and an explicitly silent default suppress playback.
For DND, this standalone player takes a conservative approach: any interruption
filter other than ALL suppresses playback, including Priority mode even if that
mode might allow certain phone callers. The app cannot establish caller-specific
DND eligibility for this standalone RTC invitation, and never bypasses the policy.
Android/Huawei may also apply stricter policies. System volume and DND rules are
not modified.

Android documents MediaPlayer's per-player selector as API 28+, and distinguishes
preferred output from the actual routed device. A successful setter is **not proof
of loudspeaker output**: OEM policy may ignore the preference in communication
mode. See [MediaPlayer API](https://developer.android.com/reference/android/media/MediaPlayer)
and [routing semantics](https://developer.android.com/reference/android/media/AudioRouting).
No global-route workaround is attempted if Huawei ignores this preference.

### Safe debug diagnostics

Logcat tag: `HuaweiRtcRingtone`; enabled only for a debuggable Android host. Logs
are per-start/per-stop or emitted only when observed route changes, not every tick:

- `preplay api=... mode=... outputs=[numeric types]`;
- API 31+: `communication_device_type=...` (read only, may be null);
- `speaker_preference_accepted` or a fixed unsupported/fallback/failure message;
- `playback_start_returned_route_unconfirmed`;
- `observed_output_type=...` while playing on API 28+ (`0` means unknown);
- `player_released`, or fixed setup/playback/release/routing failure messages.

No device ID, product name, address, user/call identifier, URI, token or payload
is logged. Debug observation failures do not change registration or global routing.

### Physical Huawei routing verification

1. Use the updated debug example on the previously working Huawei device. Start
   a fresh process, initialize/personalize and register the foreground experiment.
   Select an audible default ringtone, normal mode, nonzero ring volume and DND
   off. Disconnect Bluetooth, wired and USB audio outputs for the first test.
2. Record Android version and sanitized `HuaweiRtcRingtone` logs. Place an agent
   call and confirm the invitation appears. Check `preplay` mode/output types and
   speaker-preference result. Verify audibly that ringing comes from the external
   loudspeaker. If available, compare `observed_output_type=2` (built-in speaker)
   versus `1` (earpiece); neither a method return nor a null route proves success.
3. Tap Accept while ringing, including once immediately after invitation arrival
   to exercise asynchronous preparation cancellation. Confirm immediate silence,
   expected default RTC route, two-way audio, microphone mute and speakerphone
   toggle both ways. Observe the call's existing route readback separately from
   ringtone logs. Verify local and remote hangup and no ringtone restart.
4. On separate calls verify Decline, agent cancellation, network error, repeated
   independent invitations, screen close, Home/lock, Activity recreation and
   engine cleanup. Confirm no lingering sound or overlapping players.
5. Repeat with Bluetooth and wired/USB audio connected before the call, then connect
   a headset during ringing and during preparation. Confirm no forced loudspeaker
   preference in the first case and clearing of the player's preference in the
   latter. Verify actual headset/default behavior and call-route controls after
   Accept. Attachment detection may take up to one watchdog interval (250 ms).
6. Repeat silent mode, vibrate, zero ring volume, Silent default ringtone and DND
   None/Alarms/Priority. Expect suppressed ringtone with usable invitation controls.
   Change volume/DND while ringing and verify stop on the next watchdog update.
7. Repeat outgoing audio and video from a fresh process and after incoming
   termination, including speakerphone, headset routing and microphone controls.
   No new ringtone should start during outgoing calls.
8. If testing API 26–27, expect default routing only; do not claim speaker selection.
   If API 28+ still routes to the earpiece despite an accepted preference, retain
   the sanitized logs and report an OEM/platform routing limitation. Do not force
   communication mode/device or speakerphone as a workaround.

### Routing update validation

- Native focused ringtone + incoming + existing `HuaweiRtc*` suites, JDK 21 /
  offline cached dependencies: **222 passed, zero failures/errors/skips**, including
  API 26 default-route fallback, API 28 speaker preference, API 31 read-only
  communication-device diagnostics, external-device protection, no global routing
  writes, late callback isolation, release and DND/silence tests.
- Existing Dart RTC suites: **43 passed**. Example RTC/identity suites:
  **13 passed**. Accept/Decline, duplicate delivery, remote cancellation, lifecycle
  cleanup, outgoing controls/video and repeated invitations remain covered.
- `git diff --check`: PASS. Hash comparison against this task's baseline confirms
  all unrelated pre-existing files unchanged. Branch and HEAD unchanged; changes
  remain uncommitted/unpushed. No dependency, Gradle or manifest changes.
- Physical Huawei loudspeaker routing, headset behavior and post-accept audio:
  **NOT RUN for this routing change**. An accepted preference is not device proof.

## Incoming video update (2026-10-25)

This section supersedes earlier audio-only limitations. Existing audio and ringtone
hardware results were supplied by the user; incoming video hardware testing is NOT
RUN by this change. Foreground-only and process/identity restrictions still apply.

### Verified SDK capability and implementation

Inspection of the installed RTC Core **2.5.28** AAR using `javap` verified public
`IncomingApplicationCall.accept(ApplicationCallOptions)`, `cameraVideo(boolean)`,
`cameraOrientation(...)`, `localCameraTrack()`, `remoteVideos()`, and camera/participant
video callbacks. Bytecode inspection verified that incoming constructors supply
builder-default options and that accept installs the requested options before
starting media. Private SDP exists internally but is never accessed by this plugin.
There is no public offered-video flag; custom data is not treated as a media contract.
Automatic audio/video invitation classification is BLOCKED by that SDK limitation.

The existing `acceptExperimentalIncomingCall(handle: ..., video: true)` is now
supported. No new method or dependency is needed. `videoSupported` means the local
video acceptance path is available, not that the remote party offered video.
The additive `offeredCallType` event field and Dart getter report `unknown`.
Older native payloads remain decodable. The example shows a generic invitation,
explains the unknown offer type, and offers **Accept Audio**, **Accept with camera**,
and **Decline**. Camera acceptance requires explicit user action.

```dart
// Subscribe to incomingExperimentEvents before starting the experiment.
// On a current invitation, after the user explicitly chooses camera acceptance:
final call = await HuaweiRtc.acceptExperimentalIncomingCall(
  handle: invitation.handle!,
  video: true,
);
// Observe HuaweiRtc.events and use existing HuaweiRtcVideoView instances keyed
// by call.id for local and remote sources, exactly as for outgoing video.
```

Grant RECORD_AUDIO, CAMERA for video, and BLUETOOTH_CONNECT on Android 12+ through
the host's permission flow/settings before Accept. The plugin checks permissions;
it does not request them. Denial leaves the invitation available until cancellation
or expiry. Ringtone stops before adoption/acceptance, including permission failure.
No automatic audio retry follows camera/SDK failure. Synchronous acceptance failure
requests hangup and retains the shared slot until terminal confirmation. Asynchronous
media errors use existing RTC error events; an error alone is not terminal.

Acceptance transfers the same invitation and reservation to HuaweiRtcManager.
Its existing listener, video bindings, local/remote view ownership, stale callback
checks and terminal sink cleanup are reused. Microphone, speaker/output, camera
switching, camera enable/disable and hangup keep their existing meanings. Decline
uses the same invitation validation, ringtone stop and terminal-confirmed release.
No background delivery, HMS RTC push, token changes or Conversation routing changes
are included. Foreground loss, Activity/engine detach, duplicate invitations,
identity invalidation and occupied-call rejection retain the existing guards.

Core exposes camera publication enable/disable, but this does not establish an
arbitrary audio-call-to-video renegotiation contract. The existing controls operate
on calls accepted as video; audio-to-video upgrade is not introduced. Disabling the
camera on a video call does not change its session type or pause remote video.
Remote negotiation, camera availability, network recovery and agent behavior must
be verified on hardware. A successful accept return does not prove connection or
video publication.

### Physical Huawei validation procedure

1. Use the current branch build, a fresh process and the same proven tenant/widget
   and personalized customer. Grant microphone, camera and Nearby devices where
   required. Keep the RTC screen resumed; start the foreground experiment once.
2. From the existing Portal Conversation, initiate an application video call.
   Expect an invitation with **offered media type unknown**, ringtone and both
   acceptance choices. Confirm no caller type is guessed from SDK defaults.
3. Select **Accept with camera**. Verify ringtone stops immediately, Connecting
   advances to Connected, local preview appears and remote video is visible.
   Verify the agent sees the device camera and both parties hear each other.
4. Switch front/back cameras; disable/re-enable camera; mute/unmute microphone;
   toggle speakerphone and test connected headsets. Verify remote video continues
   while local camera is disabled. Test local and remote hangup and view cleanup.
5. Repeat with camera denied, then microphone denied (separate calls). Expect no
   SDK acceptance and no silent fallback. Restore permissions and accept a still
   valid invitation, or decline it. Test camera unavailable/in use and record SDK
   error/termination behavior; do not infer camera success from accept return.
6. Test Decline, Portal cancellation before Accept, cancellation during Accept,
   expiry, duplicate signaling, incoming while another call owns the slot and
   network interruption during connection/established video. Verify stale handles
   cannot act and uncertain termination prevents another call taking ownership.
7. During ringing and during video, press Home/lock, pause/recreate Activity, close
   the screen and detach the Flutter engine. Verify ringtone silence, requested
   termination, released local views and retained slot until terminal confirmation.
8. Make consecutive incoming audio/video calls with the same identity, then run
   outgoing audio/video before and after incoming acceptance. Recheck audio,
   ringtone loudspeaker routing, camera/renderers and every existing control.
9. Record device/Android version, Portal call mode, permissions, actual media in
   both directions, sanitized errors and termination results for each case.
   Verify Conversation association independently. Restart the process for another
   identity. These steps are a test procedure, not completed hardware evidence.

### Automated validation for this update

- Full plugin native debug unit suite, JDK 21, cached offline Gradle: **410 passed;
  zero failures/errors/skips**. Includes existing ringtone, incoming, ownership,
  outgoing, rendering, camera controls and lifecycle coverage, plus explicit video
  options, video permission guard/retry, initialization exception without fallback,
  duplicate/conflicting invitations, terminal release and video-to-next-audio tests.
- Full plugin Flutter suite: **238 passed**. Includes camera acceptance forwarding
  and unknown offered-type semantics, plus existing incoming/audio/outgoing tests.
- Full example Flutter suite: **48 passed**, including explicit camera acceptance UI.
- `git diff --check`: PASS. Device video tests: **NOT RUN**.
- No version/dependency/build configuration changes, branch changes, commits or pushes.
