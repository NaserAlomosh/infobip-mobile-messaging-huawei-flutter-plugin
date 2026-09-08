# Direct RTC Core feasibility decision

Historical research record at `bbee8577f8bfa442b7a87e67991bb1e0286192a9`.
The subsequent [Huawei outgoing extension](huawei-rtc-outgoing.md) implements a
separate contract on this branch. The stop decision below still applies to the
official incoming-call APIs; statements about an unchanged baseline describe the
research commit, not the later outgoing implementation.

Research performed 7–8 September 2026 on `feature/huawei-rtc-core`, based on
`development` commit `a5cb643c046f42d40a542dab705cc42222504c0e`.
Fetching `origin development` confirmed that both branches already pointed to that
commit. The existing feature branch was reused. The working tree was initially clean.

**Decision: NOT READY FOR DEVICE VALIDATION under the requested public contract.**
The request explicitly requires stopping if direct Core cannot safely reproduce
`enableCalls` or `enableChatCalls`. That condition is met. No production code,
dependency declaration, public API, package version, or guard was changed. This
branch records research and reproducible dependency evidence. Nothing was merged
or published.

Direct Core is a credible basis for a separately scoped outgoing-call integration.
It does not, by itself, implement the existing Mobile Messaging incoming-call
contract. The user's successful Huawei audio/video evidence with Core 2.5.20 is
consistent with the API inspection; it is not device verification of this plugin.

## Verified sources

Fresh archives were downloaded from GitHub using these exact commit IDs; old audit
conclusions were not used as substitutes for source inspection:

- [Official Flutter `8b630d0`](https://github.com/infobip/mobile-messaging-flutter-plugin/tree/8b630d0f736d400635317131d549c345349bd54d), especially [WebRTCUI.java][flutter-rtc].
- [Huawei 8.14.0 `5822d18`](https://github.com/infobip/mobile-messaging-sdk-huawei/tree/5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824). This is the only Huawei source revision used.
- [Standard Android 15.1.0 `d275530`](https://github.com/infobip/mobile-messaging-sdk-android/tree/d2755309de0b3f68d1ef1ed8302d65d75b3526c6), especially [InfobipRtcUiImpl][rtc-impl], [CallsDelegate][calls-delegate], [TokenProvider][token-provider], [Injector][injector], [Cache][cache], [CallRegistrationWorker][registration-worker], and [the manifest][rtc-manifest].
- Published Maven AARs/POMs for Core [2.5.20][pom20], [2.5.28][pom28], and [2.5.41][pom41]; actual `classes.jar` files inspected with `javap -public` and `javap -c -p`.
- [Official Core integration guide][core-guide] and [current Infobip push setup documentation][push-guide]. Mutable documentation supplements, rather than overrides, the inspected artifacts. For example, the Core README still mentions a server key; current setup documentation requires the FCM private-key JSON configuration.

## Technical blockers

### 1. Official enableCalls registers incoming calls through push

The Flutter wrapper builds RTC UI with `configurationId`, then invokes
`withCalls(identity, ListenType.PUSH, success, error)`. Blank identity uses the
default overload, which obtains the Mobile Messaging `pushRegistrationId` and can
wait for a registration broadcast. It does not place an outgoing call. RTC UI
obtains an RTC access token for the identity and reports push-enable success only
after Core returns `EnablePushNotificationResult` with `Status.SUCCESS`.
See [the wrapper][flutter-rtc] and [the implementation][rtc-impl].

In **all three inspected Core versions**, `enablePushNotification` calls
`PushRegistrationService.registerForPush`, which directly invokes
`FirebaseMessaging.getInstance().getToken()`. The public API accepts an RTC access
token, Context, and push configuration ID; it has no HMS device-token/transport
parameter. The official platform documentation identifies Android incoming-call
push as FCM. A Huawei MM installation ID is not an FCM token.

Core exposes `isIncomingCall(Map)`, `handleIncomingCall(Map, Context, listener)`
and their application-call equivalents. These accept an already delivered RTC
payload. Their Map parameter is not evidence of an HMS registration or delivery
contract. No documented safe HMS bridge was established, and no HMS payload was
routed into those methods. [Core guide][core-guide], [push setup][push-guide].

### 2. WebSocket registration cannot satisfy the required lifecycle

The inspected `InfobipRTC` public interfaces expose:

```java
void registerForActiveConnection(String token, Context context,
    IncomingCallEventListener listener);
void registerForActiveConnection(String token, Context context,
    IncomingApplicationCallEventListener listener);
```

They provide no public active-connection unregister/close, listener removal,
registration success/error callback, or session handle. `javap` also establishes
that `DefaultInfobipRTC.registerForActiveConnection` replaces the singleton only
when it is still a `PushInfobipRTC`. Once it is an `ActiveConnectionInfobipRTC`,
subsequent registrations return without installing the new token/listener. This
applies to 2.5.20, 2.5.28, and 2.5.41, including sequential registration through
the two different listener overloads.

There is a `disconnect()` method on the **implementation** class, outside the
`InfobipRTC` public interface. Its bytecode delegates to the gateway; it does not
reset the singleton or clear the listener fields. Calling implementation methods
by downcast/reflection would not establish a supported unregister/reinitialize
contract. `getActiveCall().hangup()` ends a call, not an incoming-call subscription.

Core stores the supplied Context directly. A future manager must supply an
application Context and keep Activity ownership separate. A stable forwarding
listener could prevent retaining a Flutter Activity, but cannot unregister the
socket, acknowledge registration, replace its authenticated identity, or wake a
killed process. Returning success from `enableCalls`/`disableCalls` around such a
listener would misrepresent the requested behavior.

### 3. Huawei Chat lacks the official registration hook

Official Chat's [LivechatRegistrationChecker][chat-checker] obtains a livechat
registration ID and emits `LIVECHAT_REGISTRATION_ID_UPDATED`. RTC UI's
[LcRegIdBroadcastReceiver][chat-receiver] caches it and, in Chat mode, schedules
re-registration with the new identity after disabling the previous one.

The pinned Huawei [InAppChatSynchronizer][huawei-chat-sync] only synchronizes
widget configuration. Its [InAppChatEvent][huawei-chat-event] and broadcaster
do not expose this registration event, and there is no equivalent checker in
the inspected source/artifact. The Huawei widget's `callsEnabled` setting alone
does not supply that identity/signaling integration. Core has no Chat integration
method, and its FCM limitation remains even if an identity were available.

**Token acquisition itself is not the blocker:** Huawei 8.14.0 exposes
[`MobileApiResourceProvider.getMobileApiRtc(Context)`][huawei-token] and already
depends on `infobip-mobile-messaging-api-java:15.1.0`, including `TokenBody` and
`TokenResponse`. A compile-only probe confirmed these symbols coexist with Core
2.5.28. Backend authorization and token issuance were not exercised.

## Implementation matrix prepared before any behavior change

`EXACT` means the existing data contract can be preserved; `MAPPABLE` means a
corresponding native primitive exists; `PARTIAL` means important semantics are
missing; `UNSUPPORTED` means no supported implementation was established within
this scope; `REQUIRES_RUNTIME_VALIDATION` is not a production-support claim.

| Behavior | Official behavior | Direct Core + Huawei classification and finding |
|---|---|---|
| `enableCalls(identity)` | Token acquisition and incoming PUSH registration; async registration result | **UNSUPPORTED** as a Huawei incoming-call contract: FCM registration has no HMS alternative |
| Identity | Explicit nonblank identity; blank selects installation identity | **MAPPABLE** token subject/default installation lookup; no registration implemented. Current plugin rejects non-string channel arguments and preserves string contents |
| `enableChatCalls()` | Wait for livechat identity, register PUSH, track identity changes | **UNSUPPORTED**: missing Huawei hook and HMS RTC transport |
| `disableCalls()` | Fetch token, invoke Core push-disable, clear identity/mode, callback on main dispatcher | **PARTIAL**: 2.5.28 has no push-disable completion callback and no public socket unregister; cannot guarantee requested shutdown |
| `configurationId` | RTC **push configuration** ID; builder/cache or native resource fallback | **PARTIAL**: maps to Core push-enable's third argument, which is FCM. No meaning for socket registration. It is not `CallApplicationRequest.callsConfigurationId` |
| Dart configuration forwarding | Optional nested `webRTCUI.configurationId` during initialization | **EXACT** existing plugin encoding; preserved, not activation |
| RTC token provider | MM `MobileApiRtc.getToken(TokenBody(identity, 43200L))` | **MAPPABLE** via Huawei's existing shared API; backend **REQUIRES_RUNTIME_VALIDATION** |
| Incoming registration | PUSH for Flutter; native UI also has an active-connection mode | **PARTIAL** Core offers FCM or socket registration; neither is a safe substitute for the Huawei public contract |
| Outgoing audio/video | Not exposed by these three Flutter APIs | **MAPPABLE** through `callApplication` and audio/video options; **REQUIRES_RUNTIME_VALIDATION**, no new Dart API added |
| Push signaling | FCM service recognizes RTC payload and starts incoming-call flow | **UNSUPPORTED** for HMS; Core payload parsers do not establish delivery support |
| Active WebSocket signaling | Native UI registers incoming listeners with an RTC token | **PARTIAL**: native primitive exists, but no public unregister, listener replacement or registration acknowledgement |
| Foreground incoming | RTC UI listeners, permission handling, call UI and notifications | **PARTIAL** Core socket callbacks possible with an active authenticated process; **REQUIRES_RUNTIME_VALIDATION**; no plugin handler/UI implemented |
| Background incoming | FCM receiver plus UI notification/foreground call service | **UNSUPPORTED** for HMS push; a live socket is **PARTIAL** while the process/network survives, not a wakeup guarantee |
| Killed-process incoming | Supported FCM host may be awakened; not a guarantee for force-stop | **UNSUPPORTED** for HMS; a terminated process has no live socket |
| Chat-originated incoming | Livechat identity changes drive push re-registration | **UNSUPPORTED** for this Huawei stack |
| Lifecycle registration/unregistration | App Context singleton; manifest receivers and workers; explicit UI disable | **PARTIAL**: Core retains Context/listeners without a complete public socket cleanup API |
| Listener ownership/replacement | RTC UI owns call listeners and temporarily cached mode callbacks | **PARTIAL**: repeated Core socket registration does not replace listeners |
| Repeated enable | Wrapper invokes builder again; UI can re-register; worker skips an unchanged identity | **PARTIAL**: cannot claim deterministic account replacement through Core socket API |
| Repeated disable | UI errors when cached identity is empty | **PARTIAL**: not officially idempotent; no working native registration to disable in this plugin |
| Cleanup/reinitialization | UI clears call identity/mode; configuration/livechat cache remains for SDK lifetime | **PARTIAL**: Core offers no public socket reset; enable → disable → enable cannot be guaranteed |
| Activity detach/reattach | UI uses application Context and its own call Activity; Flutter wrapper has no RTC teardown on engine detach | **PARTIAL**: future manager must outlive Activities without retaining them; this does not solve Core session lifetime |
| Error completion | UI push-enable callback; UI disable reports after dispatching Core's void call | **PARTIAL**: 2.5.28 cannot acknowledge server push deletion; 2.5.41 adds that callback only for FCM |

The official UI's `disableCalls` success does **not** prove server unregistration:
it calls Core's void method, clears the UI cache, and posts success. The older
Core implementation starts a background deletion thread. This upstream behavior
does not satisfy the stronger verified-shutdown requirement in this task.

## Version and dependency decision

**No runtime version was selected for shipping.** `2.5.28` was selected as the
isolated compatibility candidate because RTC UI 15.1.0's published POM pins it,
and Huawei 8.14.0 pins the shared Android API/resources at 15.1.0. Its Core AAR
has minSdk 21, below this plugin's 26; the outgoing API and Huawei token-provider
symbols compile together with Java 17 and Android 36. This establishes limited
binary/API compatibility, not a reason to enable the blocked contract.

| Core version | Evidence | Decision |
|---|---|---|
| 2.5.20 | User's separate Huawei device evidence; inspected API/AAR/POM; FCM dependency; no socket unregister or push-disable callback | Useful historical comparison; not blindly adopted |
| 2.5.28 | Exact RTC UI 15.1.0 dependency; resolved debug/release candidate graphs and compile-only probe; same transport/lifecycle limitations | Preferred pinned-stack research candidate; not shipped |
| 2.5.41 | Maven metadata's latest release when checked; actual AAR/API/POM inspected; adds push-disable result callback, still FCM and no public socket unregister/replacement; changes media dependency to `google-webrtc:1.0.47976t` | Does not remove the blockers; no full graph/build/device compatibility claim for this version |

All three POMs declare `firebase-messaging:22.0.0`. Core legitimately uses it in
its push implementation; excluding it is not verified runtime-safe. No excludes
were added. `com.infobip:google-webrtc` is the media engine artifact, distinct from
Google Play Services. Core 2.5.28 also directly declares nv-websocket-client 2.5,
Retrofit/converter-gson 2.9.0, EventBus 3.3.1, and AndroidX Core 1.8.0; Gradle's
normal conflict resolution with the host determines final versions.

Actual resolved graphs and class scans:

| Check | Baseline debug/release | Isolated Core 2.5.28 candidate debug/release |
|---|---|---|
| Unique external artifact files | 119 / 119 | 147 / 147 |
| Huawei MM core/chat/inbox | 8.14.0 present | 8.14.0 present |
| Shared API / Android resources | 15.1.0 present | 15.1.0 present |
| Standard MM Android **core** | Absent | Absent |
| RTC UI | Absent at runtime | Absent |
| RTC Core / media engine | Absent | 2.5.28 / 1.0.45036 |
| Firebase Messaging | Absent | 22.0.0 |
| Google Play Services modules | Absent | basement 17.0.0, cloud-messaging 16.0.0, stats 17.0.0, tasks 17.0.0 |
| `org.infobip.mobile.messaging` class names | 718 | 718 |
| Duplicate MM classes | 0 | 0 |

The scanner examined `classes.jar`, embedded `libs/*.jar`, and external JARs,
deduplicating identical resolved file paths. The only repeated class entry outside
MM was Java multi-release metadata `META-INF/versions/9/module-info.class`, also
present in baseline. This is an archive inventory, not a candidate APK/R8 test.
The probe intentionally excludes local project artifacts; unchanged plugin classes
use the `com.infobip.mobilemessaging.huawei` namespace, not the vendor namespace.

See [dependency evidence](evidence/webrtc-core/dependency-evidence.txt),
[baseline release graph](evidence/webrtc-core/baseline-release-dependencies.txt),
[candidate release graph](evidence/webrtc-core/candidate-release-dependencies.txt),
and [API/bytecode evidence](evidence/webrtc-core/api-evidence.txt).

**InfobipRtcUi was not completely removed.** Its dormant reflection adapter,
fake, and isolated non-transitive contract-test AAR remain unchanged. Neither it
nor Core is on the shipped runtime classpath. Huawei MM remains the only Mobile
Messaging core. The shared `api-java` and `android-resources` artifacts are existing
Huawei dependencies, not the conflicting standard Mobile Messaging core.

## Verification performed

Commands ran in the repository root unless stated otherwise. Android commands ran
in `example/android`. Full local logs are in `/private/tmp/huawei-rtc-core-research`.
These results verify the **unchanged, RTC-disabled baseline**, not an RTC-enabled app.

| Command | Actual result |
|---|---|
| `git fetch origin development` | Exit 0 after filesystem permission escalation; HEAD and fetched development both `a5cb643c046f42d40a542dab705cc42222504c0e` |
| `git merge-base --is-ancestor a5cb643c046f42d40a542dab705cc42222504c0e origin/development` | Exit 0 |
| `flutter pub get` | Exit 0 |
| `dart format --output=none --set-exit-if-changed .` | Exit 0; 62 files, 0 changed |
| `flutter analyze` | Exit 1; 21 informational deprecations, **0 warnings, 0 errors**; not labelled PASS |
| `flutter test` | Exit 0; 182 tests passed |
| `./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest --rerun-tasks --console=plain` | Exit 0; 161 tests, 0 failures/errors/skips; 35 tasks executed |
| `./gradlew :app:assembleDebug --console=plain` | Exit 0; 75 tasks, 11 executed / 64 up-to-date |
| `./gradlew :app:assembleRelease --console=plain` | Exit 0; 104 tasks, 12 executed / 92 up-to-date; existing outputs reused, not a fresh R8 run |
| `./gradlew :app:dependencies --configuration debugRuntimeClasspath --console=plain` | Exit 0; baseline graph |
| `./gradlew -I /private/tmp/huawei-rtc-core-research/probe.gradle :app:rtcCoreResearchDebug :app:rtcCoreResearchRelease :app:dependencies --configuration releaseRuntimeClasspath --console=plain` | Exit 0; baseline/candidate external artifact inventories and baseline release graph |
| `./gradlew -I /private/tmp/huawei-rtc-core-research/probe.gradle :app:dependencies --configuration rtcCoreResearchRelease --console=plain` | Exit 0; isolated candidate release graph |
| `python3 /private/tmp/huawei-rtc-core-research/scan_artifacts.py` | Exit 0; dependency assertions and actual AAR/JAR duplicate scan |
| `./gradlew -I ../../docs/evidence/webrtc-core/resolve.gradle -PrtcResearchOutput=/private/tmp/huawei-rtc-core-research :app:rtcCoreResearchDebug :app:rtcCoreResearchRelease --console=plain` | Exit 0; corrected committed probe rerun |
| `python3 docs/evidence/webrtc-core/inspect_artifacts.py /private/tmp/huawei-rtc-core-research --aar <2.5.20 AAR> --aar <2.5.28 AAR> --aar <2.5.41 AAR>` | Exit 0; corrected committed scanner, with actual absolute artifact paths; hashes retained in evidence |
| `javap -public` / `javap -c -p` on inspected Core JARs | Public APIs and FCM/singleton bytecode inspected for 2.5.20, 2.5.28, 2.5.41 |
| `javac -source 17 -target 17 -cp <resolved candidate JARs + android-36/android.jar> -d <temporary output> CoreApiProbe.java` | Exit 0 after declaring SDK checked exceptions; compile-only, not loaded, no network calls |
| `./gradlew :app:assembleRelease -PinfobipWebRtcEnabled=true --console=plain` | Exit 1, **expected guard refusal**; not an RTC build PASS |

Research tooling attempts before the successful probe also exited 1: the first
included Flutter's own Gradle build, which has no `:app`; the second requested
ambiguous local project artifact variants. The corrected probe scopes itself to
the host app and inventories external module artifacts. The first Java probe
failed for undeclared checked SDK exceptions and was corrected. These failures
were probe errors, not evidence against SDK compatibility. Initial sandboxed
fetch/download attempts were denied or could not resolve DNS; authorized retries
succeeded. No verification result was inferred from a previous audit run.

No new production/native lifecycle or Dart behavior tests were added after the
stop condition. The committed research probes assert dependency isolation and
compile native symbols only. Existing tests cover channel forwarding, configuration
capture, dormant adapter delegation, repeated operations and callback cleanup;
they do not verify direct Core, Activity recreation with Core, incoming calls,
account switching, or actual media. There is no claim that the full requested new
implementation test matrix passed.

Changed files are `README.md`, `docs/webrtc-configuration.md`, this report,
`docs/webrtc-core-device-validation.md`, and the eight research/evidence files in
[`docs/evidence/webrtc-core`](evidence/webrtc-core/README.md). The probes are outside
production and test source sets. All Kotlin, Dart, manifests, Gradle build files,
dependency declarations and package versions remain at the base revision.

## Current public API and device status

| API/state | Behavior on this branch |
|---|---|
| `enableCalls(identity)` | Unchanged: `not_initialized` / `webrtc_not_configured` preconditions, then `webrtc_unsupported`; non-string native arguments get `invalid_argument` |
| `enableChatCalls()` | Same preconditions, then `webrtc_unsupported`; no Chat registration or false success |
| `disableCalls()` | `webrtc_not_enabled` without a session; no production Core session is created |
| `WebRTCUI(configurationId: ...)` | Accepted/forwarded unchanged and retained on successful MM initialization; cleared on successful cleanup; no RTC activation |
| Foreground / background / terminated incoming | Unimplemented in this plugin; HMS incoming-call push unsupported by the inspected integration |

The [23-scenario device plan](webrtc-core-device-validation.md) records the evidence
levels separately. No scenario is marked `DEVICE_VERIFIED`. No direct Core feature
is production-supported by this branch, and no credentials or Huawei hardware were
used to exercise backend registration or calls.

## Safest architecture alternatives and prerequisites

1. **Obtain a supported vendor incoming-call contract.** Require a documented HMS
   registration/delivery/token-refresh path, or an explicit public socket session
   with readiness/failure callbacks, unregister, identity/token refresh and listener
   removal. Huawei Chat also needs a supported livechat identity/change hook. Require
   backend unregistration completion and define behavior after process death. Keep
   Huawei MM as the sole core; request a supported FCM-free artifact if available.
2. **Scope a separate outgoing-only integration.** Core's `callApplication` can be
   used without incoming push registration, with authenticated short-lived RTC
   tokens, a separate Calls configuration, call UI/media controls, permissions and
   lifecycle ownership. Add a deliberate extension/API only in a separately agreed
   scope. It cannot be exposed as successful `enableCalls` or `enableChatCalls`.
   The candidate still includes Firebase transitively; a runtime-safe vendor
   packaging solution or explicitly accepted dependency policy is needed.
3. **Consider a foreground socket experiment only after vendor lifecycle support.**
   Label it as active-process incoming signaling, supply application Context, and
   test actual readiness, account replacement, cancellation, detach/reattach and
   disable acknowledgements. A forwarding listener or private-field reset alone
   cannot provide the missing session contract. It cannot promise background or
   terminated delivery.

No standard MM core restoration, manifest-only workaround, exclusion of referenced
Firebase classes, or undocumented HMS payload adaptation is recommended.

Security: no tokens, application codes, authorization headers or backend responses
were used in the probes. Native failure payloads remain sanitized by existing
plugin code. The known Huawei 8.14.0 `AuthorizationUtils` header `System.out.println`
is a vendor issue and remains **NEXT/out of scope**; no SDK patch/redistribution was
performed. Core bytecode also contains FCM device-token log messages, so a future
integration needs an explicit logging review and must not forward raw SDK errors.

[flutter-rtc]: https://github.com/infobip/mobile-messaging-flutter-plugin/blob/8b630d0f736d400635317131d549c345349bd54d/android/src/main/java/org/infobip/plugins/mobilemessaging/flutter/infobip_mobilemessaging/WebRTCUI.java
[rtc-impl]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/core/InfobipRtcUiImpl.kt
[calls-delegate]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/delegate/CallsDelegate.kt
[token-provider]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/core/TokenProvider.kt
[injector]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/core/Injector.kt
[cache]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/core/Cache.kt
[registration-worker]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/core/CallRegistrationWorker.kt
[rtc-manifest]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/AndroidManifest.xml
[chat-receiver]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/receiver/LcRegIdBroadcastReceiver.kt
[chat-checker]: https://github.com/infobip/mobile-messaging-sdk-android/blob/d2755309de0b3f68d1ef1ed8302d65d75b3526c6/infobip-mobile-messaging-android-chat-sdk/src/main/java/org/infobip/mobile/messaging/chat/mobileapi/LivechatRegistrationChecker.kt
[huawei-chat-sync]: https://github.com/infobip/mobile-messaging-sdk-huawei/blob/5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824/infobip-mobile-messaging-huawei-chat-sdk/src/main/java/org/infobip/mobile/messaging/chat/mobileapi/InAppChatSynchronizer.kt
[huawei-chat-event]: https://github.com/infobip/mobile-messaging-sdk-huawei/blob/5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824/infobip-mobile-messaging-huawei-chat-sdk/src/main/java/org/infobip/mobile/messaging/chat/core/InAppChatEvent.java
[huawei-token]: https://github.com/infobip/mobile-messaging-sdk-huawei/blob/5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824/infobip-mobile-messaging-huawei-sdk/src/main/java/org/infobip/mobile/messaging/mobileapi/MobileApiResourceProvider.java
[pom20]: https://repo.maven.apache.org/maven2/com/infobip/infobip-rtc/2.5.20/infobip-rtc-2.5.20.pom
[pom28]: https://repo.maven.apache.org/maven2/com/infobip/infobip-rtc/2.5.28/infobip-rtc-2.5.28.pom
[pom41]: https://repo.maven.apache.org/maven2/com/infobip/infobip-rtc/2.5.41/infobip-rtc-2.5.41.pom
[core-guide]: https://github.com/infobip/infobip-rtc-android
[push-guide]: https://www.infobip.com/docs/voice-and-video/webrtc/get-started-with-rtc-sdk
