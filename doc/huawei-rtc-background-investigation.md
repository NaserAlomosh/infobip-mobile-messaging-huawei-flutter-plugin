# Huawei RTC background incoming-call investigation

Date: 2026-10-25 (Asia/Amman). Target release: v1.1.0.
Repository: `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`.
Branch verified: `fix/rtc-chat-conversation-mismatch`.
Inspected HEAD: `673ec8518c109c043c0e3795fb437dd51fa03012`.

## 1. Executive summary

**Verdict: BLOCKED for a production claim of background incoming RTC over HMS.** The existing foreground application-call path works according to the user's physical Huawei audio/video tests. This investigation verifies its source and the installed SDK contracts; it does not repeat those device tests.

RTC Core 2.5.28 supports active-connection incoming calls and public push-payload processing. Its push registration is explicitly Firebase Cloud Messaging (FCM) based. No public HMS token registration, transport selection, or supported invitation lookup/recovery by call ID was found. The existing Huawei Mobile Messaging receiver handles HMS messages, but does not dispatch RTC invitations. A generic HMS notification is not an `IncomingApplicationCall` and cannot itself be accepted by RTC Core.

Background, lock-screen and Activity-destroyed operation are plausible future targets once transport, native ownership, Android policy and SDK lifecycle contracts are resolved. System-killed process delivery additionally requires a vendor-supported cold-start invitation reconstruction path. Force-stop is an unsupported availability state until user interaction removes the stopped state.

Recommended decision: retain the working foreground scope for v1.1.0 unless the vendor supplies a supported HMS registration/delivery/acceptance contract and an end-to-end physical-device proof passes. First obtain that contract; then prove a genuine invitation can arrive and be accepted after process recreation. Do not begin with an always-running service or a cosmetic incoming-call notification.

### Evidence classifications and limits

- **VERIFIED-SOURCE / VERIFIED-ARTIFACT:** directly inspected checkout or cached compiled classes; static evidence only.
- **VERIFIED-DOC:** official documentation retrieved during this investigation; not device or account provisioning evidence.
- **USER-REPORTED DEVICE PASS:** foreground audio/video and controls described in the task; not independently rerun.
- **INFERENCE / PROPOSED:** engineering interpretation or conditional architecture, not an implemented or certified capability.
- **Unknown / Requires Vendor Confirmation:** insufficient supported contract or runtime evidence.

Initial working tree was clean. Only this report was created. No builds, tests, dependency resolution, SDK upgrades, code/manifest edits, branch changes, commits, pushes, stash or reset were performed. No reflection or undocumented SDK operation was executed. Bytecode inspection of implementation classes was read-only evidence, not a proposed integration technique. No backend, Portal, credentials or device state was changed.

## 2. Current implementation architecture

All repository paths below are relative to the repository above; line numbers refer to the inspected HEAD.

| Area | Evidence | Current behavior |
|---|---|---|
| Dependencies | `android/build.gradle.kts:68-74` | Huawei MM/Chat/Inbox 8.14.0; RTC Core 2.5.28. Library compile SDK 36, min SDK 26 (`:16-21`). Example targets 36 (`example/android/app/build.gradle.kts:21`). |
| Messaging initialization | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/core/MobileMessagingInitializer.kt:25-50,127-138` | Validates HMS app ID, builds MM with application code and Huawei sender ID, exposes remote-notification registration. |
| Engine/Activity adapter | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/InfobipMobileMessagingHuaweiPlugin.kt:67-100,113-141,220-238,263-271` | Creates native manager/channels, tracks Activity, silences ringtone on pause/stop/destroy and detach. |
| Incoming signaling owner | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/ForegroundIncomingExperiment.kt:141-225,442-466` | Explicit process-scoped experiment, fixed identity, one registration attempt; uses application context and `registerForActiveConnection`. |
| Identity | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcIdentityResolver.kt:35-48,60-76` | Resolves one widget-specific Live Chat registration ID and validates account snapshot and identity epoch. External user ID is not automatically the RTC subject. |
| Token | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcTokenProvider.kt:18-32` | Obtains native token through `MobileApiRtc.getToken(TokenBody(subject,43200L))`. Falls back to MM installation ID only when caller supplies no identity. No refresh scheduler. |
| Media/backend | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcBackend.kt:24-51` | Uses Core singleton; outgoing application request; active-call checks; permission checks. `recoverCall` only retrieves an in-process call whose listener matches. |
| Adoption | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManager.kt:42-70,166-187` | Checks readiness/permissions, atomically transfers the existing call slot, installs current media listener, exposes opaque-handle actions. |
| Call slot | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcContract.kt:62-80` | Main-thread process singleton; only current owner may transfer/release. Covers incoming and outgoing contention. |
| Ringtone | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/IncomingRingtone.kt:27-56,67-125` | Invitation-owned looping MediaPlayer; respects silent/ringer/DND policy; preferred speaker route without global audio-route/focus changes. |
| Ongoing-call service | `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcCallService.kt:33-62,72-131,134-180,201-216` | Process-local observation lease, low-importance ongoing notification, End/Mute controls; `START_NOT_STICKY`; task removal asks to end call. Not an invitation delivery service. |
| Manifest | `android/src/main/AndroidManifest.xml:2-21` | Microphone/camera/mediaProjection FGS declarations, notification permission, notification-tap receiver. No incoming full-screen Activity, Telecom service or incoming-call receiver. |
| Flutter API | `lib/src/rtc/huawei_rtc.dart:448-494` | Explicit foreground opt-in, invitation event stream, opaque accept/decline handle, screen-close termination. |

### Actual invitation route

1. Flutter requests `startForegroundIncomingExperiment` with widget and expected user.
2. Native code captures identity epoch, resolves Live Chat subject, obtains RTC token on worker executor.
3. Main-thread validation precedes `InfobipRTC.getInstance().registerForActiveConnection(token, applicationContext, IncomingApplicationCallEventListener)`.
4. Core's active signaling connection delivers a native `IncomingApplicationCall`; the process listener posts it to main (`ForegroundIncomingExperiment.kt:85-87`).
5. Experiment validates identity, deduplicates by object/call ID, and acquires the process slot (`:258-281`). It installs its listener, starts ringtone and publishes a Flutter snapshot.
6. Accept validates the opaque handle and current SDK state, transfers ownership to `HuaweiRtcManager`, then calls `accept(ApplicationCallOptions.audio(true).video(userChoice).autoReconnect(false))` (`:309-348`). Decline is a native command, not terminal acknowledgement (`:352-362`).
7. Terminal callback/status polling releases ownership and presentation resources (`:365-397`). Failed/uncertain termination retains reservation until terminal evidence rather than allowing overlapping calls.

This route does **not** use HMS or FCM. Successful foreground testing therefore proves media/signaling for that registered identity and tested call family, not push delivery.

### Exact foreground restrictions

- `canStartCall` requires an attached, non-finishing/non-destroyed Activity that is RESUMED (or has window focus): plugin `:121-124`.
- Host readiness additionally requires initialized messaging and a non-disposed/non-cleaning manager: manager `:43-49`.
- Incoming receipt declines when the screen is hidden, host unready, experiment invalidated, another invitation pending, or slot busy: experiment `:265-279`.
- The 250 ms watchdog stops ringing and calls `endPresentation` when visibility/readiness disappears: `:89-105`. `endPresentation` requests decline for pending calls and hangup for accepted calls (`:377-384`). Thus merely retaining a socket does not preserve an incoming call in the background.
- Activity lifecycle callbacks silence playback immediately. Engine detach invalidates the experiment (`:112-120`); uncertain native calls can retain reservation (`:123-134`). Reattaching a Dart event sink only replays in-memory state.
- The process singleton contains the native object and opaque handle. Neither is persisted or reconstructible from a Flutter snapshot.
- The existing ongoing service does not create invitations. In particular, incoming `adopt` at manager `:48-69` does not call the outgoing service-start path at `:310-340`. The presence of that service is not proof that accepted incoming calls have background media coverage.

### Channels and receivers

RTC MethodChannel: `infobip_mobilemessaging_huawei/huawei_rtc`; media EventChannel: suffix `/events` (manager `:573-574`); invitation EventChannel: suffix `/incoming_experiment` (experiment `:443`). Screen capture has its separate event adapter (plugin `:136-140`). These channels require a Flutter engine and do not launch one on push receipt.

`plugin/NativeEventBridge.kt:34-60,78-92` forwards ordinary MM message and registration broadcasts to Dart. It is not an RTC receiver. The experiment's local broadcast receiver watches registration/user/personalization changes (`:456-466`), not push invitations. `NotificationTapReceiver` in the plugin manifest handles ordinary notification taps. Screen capture service concerns MediaProjection only.

The cached MM AAR manifest also supplies `MobileMessagingHmsService` for `com.huawei.push.action.MESSAGING_EVENT`, `MobileMessagingJobService`, connectivity and notification-action receivers and tap Activities. HMS/FCM library components appearing in a merged manifest do not establish RTC routing. An existing example merged manifest was inspected but has a different application ID from current source; it is stale build evidence and is not used to certify the current app configuration.

## 3. RTC Core 2.5.28: installed-artifact findings

Inspected cached AAR:
`/Users/apple/.gradle/caches/modules-2/files-2.1/com.infobip/infobip-rtc/2.5.28/8209d0e0570912b71838bed2e06b58cf8b316022/infobip-rtc-2.5.28.aar`

SHA-256: `9303984b90dd14cb31458d94d35b26f5b494ae42017e3174ae135030c01314a4`.

Public APIs and bytecode were read with `javap` from an existing Gradle runtime JAR. All class bytes were compared with the AAR's embedded `classes.jar` and matched. No artifact extraction or dependency resolution was needed.

| Question | Finding and evidence |
|---|---|
| Foreground invitations | **VERIFIED-ARTIFACT:** `InfobipRTC.registerForActiveConnection(String,Context,IncomingApplicationCallEventListener)` and corresponding peer-call listener overload. ActiveConnection implementation connects using the supplied access token. |
| Background mechanism | **VERIFIED-DOC/ARTIFACT:** push registration plus a message-service callback and matching payload handler; remaining socket connectivity is not a guaranteed background service. Official examples use FirebaseMessagingService. |
| Push support | Yes, but the verified registration transport is FCM. |
| FCM dependence | `impl.push.PushRegistrationService.registerForPush` bytecode offsets 8/11 invoke `FirebaseMessaging.getInstance()` / `getToken()`. The public `enablePushNotification` overloads accept token, context, configuration identifier and optional completion listener, not an HMS token/provider. |
| Manual processing | Public `isIncomingCall(Map<String,String>)`, `handleIncomingCall(Map,Context,IncomingCallEventListener)`, `isIncomingApplicationCall(Map)` and `handleIncomingApplicationCall(Map,Context,IncomingApplicationCallEventListener)` exist. |
| Can HMS data be passed? | The parameter is a Java Map, so a type-compatible map can be supplied. **That does not prove supported HMS use.** An arbitrary map or generic call ID lacks the genuine server-issued invitation contract. No documented end-to-end HMS path was found. |
| Registration/provider binding | Current registration obtains its own FCM token. MM's HMS installation registration is a separate subsystem. No public transport selector or external push-token injection was found. |
| Server-side dependency | RTC push needs RTC-side registration/configuration tied to the intended identity. Existing MM registration does not demonstrate this association. Exact Huawei backend provisioning is **Unknown / Requires Vendor Confirmation**. |
| Call families | Application calls and direct peer WebRTC calls have distinct classifiers, handlers, event listeners and options. Both have public push-handler APIs. The current plugin listens only for application calls; peer-call examples cannot certify Conversations application-call routing. |
| Process recreation | A genuine delivered RTC push can enter a handler in a fresh process under the documented push flow. No public `restoreInvitation(callId)` or pending-call fetch API was found. Active getters return current runtime objects; they are not durable server recovery. HMS cold-start recovery remains unverified. |

Official SDK API reference describes the push handlers through Firebase service callbacks: [InfobipRTC wiki](https://github.com/infobip/infobip-rtc-android/wiki/InfobipRTC). The table's exact signatures and negative API findings are independently based on installed classes.

### Lifecycle contract gaps

`DefaultInfobipRTC.registerForActiveConnection` checks whether the process singleton is a `PushInfobipRTC` before replacing it with an active-connection instance (bytecode offsets 14-33). Once already active, another registration call does not replace the token/listener through this branch. Public `InfobipRTC` exposes no active-registration unregister, token replacement, readiness acknowledgement or listener replacement API.

Do not call implementation-only disconnect/reset functions, reflect into the singleton, or assume `disablePushNotification` tears down an active socket. Push disabling and active registration are different operations. Coexistence/switching between push and active modes requires a vendor contract, particularly duplicate delivery and changing login identity.

`IncomingApplicationCall` exposes `from`, `fromDisplayName`, accept overloads and decline overloads. Video acceptance uses an explicit local choice; the plugin correctly reports offered type as unknown. Established-call reconnect callbacks and `autoReconnect` options do not prove restoration of a pending invitation after process death. The current incoming accept explicitly disables auto reconnect.

The 43,200-second token request is a requested 12-hour lifetime, not measured issued expiry or evidence that idle registration survives renewal. Long-running registration, expiration during ringing, logout and re-personalization require vendor-supported renewal/revocation behavior.

## 4. Existing HMS capabilities and reuse boundary

**VERIFIED-ARTIFACT**, Huawei MM 8.14.0:

- `cloud.hms.HmsRegistrationTokenHandler.acquireNewToken` calls `HmsInstanceId.getInstance(context).getToken(senderId,"HCM")`.
- `handleNewToken` rejects empty tokens, broadcasts token receipt and calls `RegistrationTokenHandler.sendRegistrationToServer`.
- That base handler compares the stored token/registration/service type, stores changed cloud tokens and invokes MM `sync()`; unchanged registrations use `lazySync()`.
- `MobileMessagingHmsService.onNewToken` forwards to `MobileMessagingCloudService.enqueueNewToken` with MM's sender ID.
- `onMessageReceived` maps Huawei `RemoteMessage` with `HmsMessageMapper.createMessage`; recognized messages are enqueued through `MobileMessagingCloudService.enqueueNewMessage`. This inspected path contains no RTC classifier or handler call.

These are native entry points and do not depend on Dart being visible. They verify token and ordinary messaging integration, not delivery latency or cold-start guarantees. [Infobip Huawei SDK integration](https://github.com/infobip/mobile-messaging-sdk-huawei/blob/master/README.md) and [Huawei Push Kit codelab](https://developer.huawei.com/consumer/en/codelab/HMSPushKit/index.html) document Huawei app configuration and token setup.

### Message delivery and wake-up

HMS supports notifications and data delivery, but notification-center presentation is different from application code executing a data callback. Huawei's [HMS data-security guidance](https://developer.huawei.com/consumer/en/doc/hmscore-guides-v5/sdk-data-security-0000001050042177-V5) describes caching/encryption of data messages when not foreground. This is not a universal latency or process-start guarantee.

The detailed HMS Android receive-message guide could not be retrieved through the available browser tool. Searches did not establish a current official, device/version-specific high-priority data wake-up entitlement applicable to this application. Claims that a special urgency value can always restart a killed app are therefore **Unknown / Requires Vendor Confirmation**. Native HarmonyOS Push Kit documentation is not evidence for this Android APK integration; Huawei devices running an OS without Android APK support are outside scope.

For background, locked and process-killed states, separately verify: notification display, native data callback, permitted process wake-up, network access, real SDK invitation creation, and acceptance before expiration. No evidence establishes that Infobip RTC currently sends its invitations through this installation's HMS channel.

### Safe reuse proposal

Reuse the established Huawei app configuration and token lifecycle only through a documented MM extension/custom-service forwarding contract. Preserve one effective receiver for the Huawei messaging action. If Infobip approves a dispatcher, route authenticated RTC envelopes to the correct Core public handler and ordinary MM payloads to the existing MM handler exactly once; forward every token rotation to its existing owner. Do not register competing receivers or redirect all MM payloads into RTC. The inspected static forwarding methods are technical hooks, not sufficient evidence of a supported RTC integration.

Additional configuration would need an RTC-to-HMS identity/device mapping, server push credentials/configuration and a genuine invitation payload or supported retrieval API. Whether Infobip can provide this without a customer backend remains unresolved. Never delete or replace the regular MM token to implement RTC logout.

## 5. Android and Huawei constraints

### Foreground services and media

Android 12+ restricts background FGS starts. The documented high-priority push exemption names **FCM**; it must not be assumed to cover HMS. User interaction with a notification is a relevant allowed route, but its exact implementation still must satisfy media permissions. Android 14 checks while-in-use microphone/camera eligibility at service creation, separately from the general start exemption. A background service is not permission to open camera/microphone. [Background FGS restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

Declare appropriate types and permissions. Microphone and camera types require their runtime permissions; a `phoneCall` service requires `FOREGROUND_SERVICE_PHONE_CALL` and qualifying dialer/own-call prerequisites and is intended for ongoing Telecom calls. It is not an indefinite idle socket type. `remoteMessaging` is for text-message continuity, not a general VoIP keepalive. Android 15 restricts launching a phone-call FGS from BOOT_COMPLETED. [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types).

**Proposed:** ringing must not start microphone/camera capture. Prefer bringing a user-accepted call into a visible Activity before media starts; prove any Telecom-based alternative independently. Continue an already legitimately started media service only under the appropriate platform rules. Do not assume audio eligibility grants video eligibility. Verify promotion order for incoming acceptance; the outgoing service implementation cannot simply be assumed to cover it.

### Incoming UI, notifications and lock screen

Use a distinct high-importance incoming-call channel with appropriate sound policy; the existing low-importance ongoing channel cannot serve this role. Android 12+ `CallStyle` supports incoming Answer/Decline actions; it does not deliver the invitation. [CallStyle](https://developer.android.com/develop/ui/compose/notifications/call-style).

Android 13+ normally requires POST_NOTIFICATIONS for visible alerts. FGS can start without that grant but must still provide its notification; denial can suppress drawer visibility. A self-managed call exemption requires MANAGE_OWN_CALLS, ConnectionService and registered PhoneAccount together. The plugin does not implement those prerequisites. [Notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).

Full-screen incoming-call UI needs USE_FULL_SCREEN_INTENT and platform eligibility. Android 14 introduces permission checks such as `canUseFullScreenIntent`; the user can deny access. Google Play default-grant policy and Huawei store/device policy are separate. Fall back to an allowed heads-up/notification surface when full-screen use is unavailable. [Android 14 changes](https://developer.android.com/about/versions/14/behavior-changes-14).

A native incoming Activity can be designed to show over the keyguard and turn the screen on where permitted; this must not bypass authentication or expose sensitive details. Showing over lock screen does not itself unlock the device. No such Activity exists in the inspected plugin. For Android 15+ audit PendingIntent creator/sender background-activity-launch privileges; do not directly launch an Activity from an arbitrary push callback or use a notification trampoline. [Activity launch security](https://developer.android.com/guide/components/activities/secure-bal).

### Telecom and battery policy

Self-managed ConnectionService is worth evaluating after delivery works: it coordinates calls with system telephony and audio routes, but requires PhoneAccount registration and correct incoming/answer/reject/disconnect handling. It is not a push transport and cannot reconstruct an Infobip invitation. Preserve Core media ownership and evaluate conflicts with existing speaker/microphone controls. [ConnectionService](https://developer.android.com/reference/android/telecom/ConnectionService).

Doze/App Standby can defer network activity; an FGS does not make every socket continuously reachable or prevent process termination. Battery exclusions are neither automatic nor a delivery SLA. [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby). Test Huawei App launch/secondary launch/background settings, power-saving modes, screen-off duration, region, EMUI/HarmonyOS Android compatibility and HMS Core versions. Those settings are test variables, not prerequisites that justify claiming universal reliability.

Force-stop is distinct from Activity destruction, task swiping and system process reclamation. Android's stopped state persists until qualifying user interaction; Android 15 cancels pending intents on force-stop. Do not promise an FGS, job, boot receiver or push will autonomously defeat it. [Android stopped-state behavior](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state).

## 6. Compatibility matrix

This matrix describes **new incoming calls**, not an already established outgoing call. “HMS delivery” separates ordinary messaging capability from an RTC invitation. Proposed feasibility is not release support.

| App State | RTC Connection | HMS Delivery | Incoming UI | Accept/Decline | Feasibility |
|---|---|---|---|---|---|
| Foreground | Active connection implemented; user reports audio/video device success | Ordinary HMS path exists; RTC-over-HMS **Unknown / Requires Vendor Confirmation** and unnecessary for current route | Existing visible Flutter RTC screen and native ringtone | Existing native invitation handle and Core accept/decline; user-reported pass | Supported only within tested foreground experiment conditions |
| Background | Socket may remain while process alive; continuity unverified; current readiness guard rejects arrivals | Ordinary native callback exists; timely data delivery unverified; RTC routing **Unknown / Requires Vendor Confirmation** | Current incoming UI unavailable; conditional future native call notification | Current foreground guard blocks actions; future supported object + user action required | Current: unsupported. Future: conditional, not proven |
| Locked screen | Connection survival depends on process/network; current Activity normally not resumed | RTC HMS path **Unknown / Requires Vendor Confirmation**; lock/Doze timing unverified | No lock-screen call UI; future notification/full-screen subject to permissions | Current guard prevents normal locked acceptance; future media eligibility must be verified | Current: unsupported. Future: conditional |
| Activity destroyed, process alive | Process registration may remain; Activity missing; engine detach can invalidate | MM native service independent of Activity; RTC path **Unknown / Requires Vendor Confirmation** | No usable Flutter host; proposed native presentation can outlive Activity | Current host/handle guard rejects; no independent background action coordinator | Current: unsupported. Future: conditional on native ownership and delivery |
| Process killed by system | In-memory socket, listeners, call object and slot lost | Wake/data callback and authentic RTC payload recovery **Unknown / Requires Vendor Confirmation** | Ordinary system notification is not an RTC call UI; no current cold-start call path | No current invitation to accept; no public recovery-by-ID found | Blocked pending vendor cold-start delivery/recovery and physical proof |
| Force-stopped | Process/socket absent; stopped-package restrictions | No reliable automatic app callback/revival supported; vendor notification display would not prove executable RTC delivery | No reliable automatic incoming-call UI contract | Unsupported until user interaction restores app availability and a fresh valid invitation exists | Excluded from unattended incoming-call support |

No background row has an established end-to-end delivery → valid SDK object → acceptance → bidirectional media path in this investigation.

## 7. Strategy comparison

| Option | Verified basis | Missing requirement / risk | Recommendation |
|---|---|---|---|
| A. Core 2.5.28 + HMS | Public map handlers and existing HMS receiver | RTC registration is FCM based; no supported HMS server registration/payload route demonstrated | Block production implementation until vendor supplies complete contract |
| B. Backend integration | Calls API can control and observe calls owned by your calls configuration | Conversations-managed calls are excluded from those low-level webhooks; custom push cannot recreate SDK objects | Conditional design only; require product-specific event/recovery support |
| C. Persistent RTC socket in FGS | Core active registration works in foreground | Idle FGS type/policy, battery/network/process loss, no public active token/listener replacement/unregister | Do not recommend as production background delivery architecture |
| D. SDK upgrade | Official release listing identifies 2.5.41; cached artifact inspected | 2.5.41 retains FCM registration and active-registration replacement limitation; no HMS contract found | No upgrade justified as an HMS fix; evaluate separately if vendor identifies a supported release |

### Option A: existing SDK and HMS

Required chain: RTC identity/device registration with HMS transport → Infobip sends authentic invitation through HMS → native data receiver runs → correct Core handler returns live call object → user accepts through supported media path. Only the map-handler primitive and generic HMS entry point are currently established. A configuration ID is not an HMS token. Neither adding Huawei credentials to MM nor enabling FCM dependencies proves the missing links.

### Option B: backend orchestration

[Infobip Calls API](https://www.infobip.com/docs/voice-and-video/calls) supports event-driven call control, WEBRTC identity endpoints and events scoped to the customer's callsConfigurationId. It explicitly excludes calls controlled by Infobip applications including Conversations. Thus a generic Calls webhook must not be proposed as a way to intercept the current Portal invitation. [WebRTC with Calls](https://www.infobip.com/docs/voice-and-video/calls/webrtc-with-calls) is a separate orchestration integration, not a promise of Conversations call recovery.

A vendor-approved backend design would need:

1. An authorized event source for the actual call family/product and a stable original invitation/call-leg identifier.
2. Authenticated device registration mapping account, RTC subject, installation, Huawei token and token generation. Keep server credentials off devices.
3. A call-state store, idempotent webhook processing, short TTL, cancellation tombstones and multi-device answer arbitration.
4. HMS dispatch through an approved direct or Infobip channel, with delivery/callback monitoring and rate controls.
5. **A supported Core entry point for the original invitation**: vendor-generated transferable payload, documented fetch/claim/resume operation, or explicitly supported delayed dialing after device readiness. None is established here for the current integration.
6. Server verification at answer time that account/identity/device match and the call remains pending. Cancellation/expiry must win races with late answer.

A notification may tell a user to open the app or request a callback. That is a different product flow, not acceptance of the original invitation. Do not fabricate Core payloads, replay expired payloads or assume a new outgoing call is the same Conversation/call leg.

### Option C: persistent connection

Technically, a live process and connected SDK may receive signaling away from its Activity. A user-visible availability service could be experimentally evaluated if a legitimate FGS use/type exists. However, the present experiment deliberately declines when backgrounded, and indefinite idle use of microphone/camera/phoneCall service types is not established as compliant.

Persistent notification, socket heartbeats, radio use, network handovers, Doze and Huawei process controls impose battery/reliability costs. Service restart cannot restore a dead call object. Token refresh is particularly blocked by one-time singleton registration and missing public replacement/unregister. Listener ownership must survive engines, and logout must stop availability safely. No public readiness result establishes that an idle socket is authenticated. This option cannot cover force-stop and is not a substitute for cold-start push.

### Option D: newer SDK evidence

The [official Android releases listing](https://github.com/infobip/infobip-rtc-android/releases) retrieved on the investigation date lists 2.5.41 as Latest; its stated change concerns WhatsApp endpoint identifiers, not HMS. 2.5.40 mentions Gradle 9 support. Direct Maven metadata retrieval was unavailable, so the release-list observation is not a claim that all publishing channels were exhaustively enumerated.

Cached 2.5.41 AAR:
`/Users/apple/.gradle/caches/modules-2/files-2.1/com.infobip/infobip-rtc/2.5.41/fd8bdd90985a2be08f9c6bc5f3cc4185958cd723/infobip-rtc-2.5.41.aar`

SHA-256: `42760d5e339d0fa421f41e9812e190e24acb2806884a998570d5abe05130c44a`.

Runtime class bytes match the AAR. Public interface comparison shows a disable-push completion overload; bytecode still calls FirebaseMessaging.getToken and conditionally replaces only PushInfobipRTC on active registration. Neither inspected version contains a `com/huawei` class reference. This supports the narrow conclusion that upgrading to this inspected version does not supply native HMS registration; it is not proof about future vendor releases.

Any eventual upgrade needs a separate compatibility review: transitive WebRTC/media changes, renderer/EGL and track ownership, screen-as-camera behavior, audio routing/Bluetooth, camera controls, reconnect and terminal callback ordering, Kotlin/Gradle requirements, R8 rules, native ABI packaging and MM/Chat dependency compatibility. Existing foreground device success must be repeated; this investigation made no upgrade or compatibility-build claim.

## 8. Recommended architecture (conditional, not implemented)

Prefer a vendor-supported push-triggered native call coordinator. Keep the existing manager as the sole media owner and preserve the process call slot. Flutter is a presentation/control client, not the component required to receive or retain invitations.

Proposed sequence after vendor approval:

1. Native receiver classifies a supported, authenticated RTC envelope while preserving normal MM dispatch.
2. A process coordinator validates identity, expiry and duplicate/cancellation state, then invokes only the documented Core handler/recovery mechanism.
3. Reserve the existing slot for the real invitation; reject competing calls consistently. Do not reserve indefinitely for an unverified push hint.
4. Present a native call notification, using full-screen UI only when allowed; no microphone/camera before user consent.
5. On Answer, revalidate server/SDK pending state and identity. Bring up permitted native/Flutter call UI, satisfy media permissions and FGS/Telecom rules, then transfer the slot once to the existing manager and accept.
6. Decline/cancel/timeout removes alert and ringtone; release the slot only on confirmed terminal state or a documented reconciliation outcome. Flutter attachment observes current native state instead of creating a second call.
7. After process death, discard local object handles. Treat persisted correlation data as a hint requiring authenticated server/SDK reconciliation. If no supported recovery exists, show expired/missed/unavailable state instead of an actionable stale call.

Use an explicit call state machine: hint → validated invitation → ringing → accepting → connected → ending → terminal, with cancellation/expiry transitions before connection. Terminal state is monotonic. An SDK error is not automatically terminal, matching current ownership rules.

## 9. Required Infobip/backend changes and blockers

| Blocker | Resolution required |
|---|---|
| B1: FCM-bound RTC push registration | Official HMS registration/provider support or supported server integration for this RTC identity and app |
| B2: No verified RTC payload over MM HMS | Documented envelope, callback path, app configuration and exact application-call delivery proof |
| B3: No demonstrated cold-start invitation recovery | Supported original-invitation payload processing/retrieval with TTL/cancellation semantics after process death |
| B4: Active singleton lifecycle gaps | Supported token renewal, deregistration, identity/listener replacement and push/active coexistence |
| B5: Current foreground-only ownership/presentation | Separately authorized native coordinator, notification/lock-screen actions and media lifecycle work |
| B6: Android/Huawei execution eligibility | Device/version proof of callback wake-up, allowed UI/service start and microphone/camera access |
| B7: Conversations event visibility | Conversations-specific vendor API/events; generic Calls API cannot observe those calls |

A customer backend is **not proven mandatory for every possible vendor solution**. It is required for Option B orchestration, but is insufficient without B2/B3/B7. A vendor-native HMS solution might avoid a custom backend. No available configuration change alone is established as sufficient.

## 10. Security and reliability requirements

| Concern | Existing evidence / required behavior |
|---|---|
| RTC expiry | 12-hour request, no idle refresh schedule; require vendor expiry/renewal contract and expiry-during-ring tests. Never log bearer tokens. |
| HMS token rotation | MM already forwards/synchronizes replacements. Any RTC mapping must update atomically by installation generation and revoke old associations without deleting MM ownership. |
| Identity/logout | Preserve epoch checks and widget-specific subject. Revalidate after async work and before every answer; prohibit old-account push from creating a new-account call. Process epoch alone is not a durable account generation. |
| Duplicate invitations | Current object/ID duplicate check is process-local. Future push/socket deduplication needs vendor-stable ID + account/installation generation and bounded durable tombstones. Do not decline a duplicate wrapper if that would terminate the valid original call. |
| Cancellation/missed calls | Cancel alerts promptly; late cancellation/answer ordering must reconcile with authoritative state. Store minimal missed-call metadata, not a reusable invitation. |
| Timeout | Existing 30-second timer covers preparation, not a specified invitation ring TTL. Use vendor expiry plus bounded local alert timeout; timeout presentation is not proof of native termination. |
| Simultaneous calls | Keep one slot for pending/outgoing/accepted operations. Define busy handling and multi-device answer arbitration; do not create a second SDK/media owner. |
| Process recreation | Do not serialize SDK objects or trust saved Dart handles. Authenticate restored account and re-fetch/reprocess only supported, unexpired state. |
| Push/socket races | Vendor must specify coexistence and same-invitation IDs. Serialize transitions on main; stale callbacks must not release another session's reservation. |
| Spoofing | Explicit immutable action PendingIntents bound to call/generation; non-exported app components where possible; reject untrusted intents, schema abuse and replay. `isIncomingApplicationCall` is classification, not an application security guarantee. |
| Sensitive data | Minimal opaque correlation/expiry in notifications; no access token, raw identity, SDP, ICE/TURN credentials or personal details in public lock-screen content. Server credentials remain server-side. |
| Logging | Inspected MM service bytecode passes tokens/messages to verbose logger calls. Future RTC routing must not add sensitive payloads to those paths; verify release logging and Core diagnostics on device separately. |
| Permissions/network failure | Explicit unavailable state for denied notifications, expired auth, disconnected network, blocked full-screen or denied camera/microphone; no silent audio fallback or success claim. |
| Cleanup | One owner for ringtone, notification, SDK listener, media and reservation. Preserve terminal confirmation and current track/EGL ownership; never release shared SDK resources speculatively. |

## 11. Questions requiring vendor confirmation

1. Does RTC Android Core support HMS-only devices for incoming **application calls from Conversations**, and in which released version? Supply an official integration/sample and supported device/OS list.
2. How is an HMS token associated with RTC subject, application and push configuration? Can MM installation registration be reused, and where is that association provisioned?
3. Does Conversations send an authentic RTC invitation through the Huawei MM channel? Which payload type, delivery priority, TTL and cancellation mechanism apply?
4. Is `handleIncomingApplicationCall(Map,Context,listener)` officially supported for a genuine payload transported via HMS? Is transformation required, and who supplies/signs that payload?
5. Can that handler produce the original pending invitation in a fresh process with no prior active registration? What credentials, persistence and initialization are required?
6. Is there a supported fetch/claim/recover-pending-call API? What happens if the caller cancels while the receiver starts?
7. How are active registration readiness, token expiration, reconnect, token replacement, unregister and account switching supported without process termination?
8. Can push mode and active registration coexist, and how are duplicate callbacks, multiple devices and first-answer-wins resolved?
9. Which Conversations-specific webhooks/API expose pending/canceled calls? Confirm generic Calls API exclusions for this account/product.
10. How is the offered audio/video type exposed reliably for incoming application calls? Are permissions and camera publication expected before or after user answer?
11. Which documented MM custom-HMS-service forwarding mechanism preserves ordinary notifications and token rotation?
12. Which Huawei high-priority/wake-up entitlement and server settings, if any, apply to this app? Distinguish process killed, task removed and Settings force-stop.
13. Does the vendor support a Telecom/ConnectionService integration and Android 14-16 incoming media-start sequence on no-GMS hardware?

## 12. Suggested implementation phases

All implementation below is future work requiring separate authorization; none was performed here.

1. **Contract gate first:** provide this evidence to Infobip/Huawei, obtain answers to B1-B4/B7 and exact payload/recovery documentation. Preserve current foreground baseline.
2. **Delivery proof:** on a dedicated physical no-GMS Huawei test device, prove genuine server call → HMS callback in background/system-killed state → Core incoming application-call object → accept/decline → correct remote call leg. Generic push receipt alone fails this gate.
3. **Native ownership:** implement coordinator behind opt-in configuration, integrating existing slot and identity lifecycle; test duplicates, cancellation, logout and engine/Activity recreation before UI polish.
4. **System presentation:** incoming channel, native call actions, conditional lock-screen UI, notification permissions and FGS/Telecom design. Prove lawful media-start order for both audio and video.
5. **Reliability and security:** token rotation/expiry, reconnect and server reconciliation; safe notification actions, logging verification and missed-call behavior.
6. **Release certification:** run the matrix below with documented device coverage and regression evidence. Publish only rows proven end to end; exclude force-stop. If any transport/recovery gate fails, retain foreground-only incoming support for v1.1.0.

## 13. Physical Huawei test plan

**NOT RUN in this investigation.** Existing foreground success is user-reported. No automated test, build, device or Portal action was performed.

Record model, Android API, EMUI/HarmonyOS build and APK compatibility, HMS Core version, region, app package/signing configuration, target SDK, notification/FSI permissions, battery/launch settings, network and authenticated identity generation. Confirm absence of GMS; a GMS-equipped emulator cannot prove HMS-only behavior.

| Test group | Procedure | Evidence / pass condition |
|---|---|---|
| Foreground regression | Repeat outgoing/incoming audio/video, Accept/Decline, two-way media, loudspeaker ringtone, camera switch/toggle, mute, speaker and cleanup | Same expected behavior as current physical baseline; no extra registration/token/media owner |
| Background | Home button, another app foreground; short and extended idle | Real HMS callback and original SDK invitation, timely notification, user answer and bidirectional media; no forbidden service/activity launch |
| Lock screen | Secure keyguard, screen off, immediate and long idle | Allowed alert surface, redacted content, working decline/answer, correct media permissions; no unlock bypass |
| Activity destroyed | Destroy Activity while confirming PID remains alive; separately test engine retained and detached | Single native invitation owner, no stale Flutter dependency, correct reattachment and actions |
| System kill | Reclaim/kill background process without force-stop; verify stopped flag remains false and PID changes | Push wakes allowed entry point; original invitation reconstructed and accepted before expiry, or clean unavailable outcome |
| Force-stop | Settings Force Stop; verify stopped state; send call; later explicitly relaunch | No unsupported automatic-delivery promise; no stale call resurrection on relaunch |
| Task removal | Swipe task independently of system kill/force-stop | Document actual Huawei behavior and current onTaskRemoved hangup; do not relabel as process-kill evidence |
| Permissions | Deny notification, block incoming channel, revoke FSI, microphone/camera, Nearby devices; repeat lock/background | Honest unavailable/fallback state, no crash or unauthorized media; Decline behavior defined |
| Huawei power | Default/managed App launch, secondary launch/background switches, battery saver and long screen-off; test unplugged | Record delivery distribution and misses, not just one successful ring |
| Network | Wi-Fi/cellular handover, offline arrival, delayed reconnection, unstable network | Expired calls cannot ring indefinitely or be accepted; safe reconnect ownership |
| Token/identity | HMS rotation, RTC expiry before/during invitation, logout/login same or different account, personalization change | No old-account delivery/acceptance, no token leaks, correct mapping generation and supported refresh |
| Races | Duplicate push, push plus socket, cancellation before/after display, cancel during answer, double tap, simultaneous outgoing/incoming, second incoming | Exactly one accepted call and slot owner; no wrong-session cleanup; terminal state remains terminal |
| Cold start/stale state | Kill after receipt, during ringing and while answering; relaunch after expiration; reboot separately | No serialized-object reuse; original call is reconciled or shown expired/missed |
| MM coexistence | Interleave ordinary push/Chat notification with RTC invites and token rotation | Ordinary delivery/tap/storage behavior unchanged; no duplicate or swallowed messages |
| Audio/video system integration | Bluetooth/wired route changes, other telephony call, DND/silent, screen lock during accepted video | Correct arbitration/ringtone cleanup; no unintended camera capture or shared resource disposal |

For each attempt collect sanitized timestamps for server creation, HMS dispatch, native callback, SDK callback, notification, user action, remote establishment and termination. Record original call correlation using an approved redacted test identifier. Measure median/tail arrival and answer latency against vendor invitation TTL; agree acceptance thresholds before claiming reliability. Keep payloads, tokens, personal identifiers and media credentials out of logs. Save permission/device outcomes separately from server-delivery evidence.

## 14. Official reference index and retrieval limitations

References were consulted on 2026-10-25. Live documentation can evolve independently of pinned 2.5.28 artifacts; artifact evidence takes precedence for that version's API signatures.

- [Infobip RTC Android public API wiki](https://github.com/infobip/infobip-rtc-android/wiki/InfobipRTC): active registration, push classification/processing and active-call getters; examples name FCM.
- [Infobip RTC Android releases](https://github.com/infobip/infobip-rtc-android/releases): 2.5.41 listed as Latest in retrieved page; no HMS feature established.
- [Infobip Huawei MM SDK](https://github.com/infobip/mobile-messaging-sdk-huawei/blob/master/README.md): HMS integration prerequisites.
- [Infobip Calls API concepts](https://www.infobip.com/docs/voice-and-video/calls): own-configuration call orchestration and explicit Conversations exclusions.
- [Infobip WebRTC with Calls](https://www.infobip.com/docs/voice-and-video/calls/webrtc-with-calls): backend orchestration integration.
- [Huawei Push Kit](https://developer.huawei.com/consumer/en/hms/huawei-pushkit/) and [Android codelab](https://developer.huawei.com/consumer/en/codelab/HMSPushKit/index.html): HMS setup and cloud/device messaging.
- [Huawei HMS data security](https://developer.huawei.com/consumer/en/doc/hmscore-guides-v5/sdk-data-security-0000001050042177-V5): data/notification distinction and caching/security considerations; not a wake-up SLA.
- [Android background FGS restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) and [service types](https://developer.android.com/develop/background-work/services/fgs/service-types).
- [Android CallStyle](https://developer.android.com/develop/ui/compose/notifications/call-style), [notification permissions](https://developer.android.com/develop/ui/compose/notifications/notification-permission), [Android 14 full-screen restrictions](https://developer.android.com/about/versions/14/behavior-changes-14).
- [Android background Activity security](https://developer.android.com/guide/components/activities/secure-bal), [ConnectionService](https://developer.android.com/reference/android/telecom/ConnectionService), [Doze](https://developer.android.com/training/monitoring-device-state/doze-standby), [Android 15 stopped state](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state).

The detailed Huawei Android receive-message guide and direct Maven metadata were unavailable through the retrieval tools; shell network lookup also failed. These gaps are explicitly retained as unresolved delivery/version-enumeration questions. Third-party summaries, HarmonyOS-native documentation and cached prior investigations were not used to certify Android HMS wake-up behavior. No Infobip vendor response or customer-account server configuration was available.
