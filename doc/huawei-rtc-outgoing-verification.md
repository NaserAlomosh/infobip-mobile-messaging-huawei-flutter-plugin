# Huawei RTC outgoing implementation verification

Verification date: 8 September 2026. **READY FOR HUAWEI DEVICE TESTING** for the
foreground outgoing extension, not a claim of device-verified production calls.

- Branch: `feature/huawei-rtc-core`.
- Base development commit: `a5cb643c046f42d40a542dab705cc42222504c0e`.
- Previous research / implementation parent: `bbee8577f8bfa442b7a87e67991bb1e0286192a9`.
- Implementation revision: the commit containing this report, titled
  `feat: add Huawei RTC Core outgoing calls` (the delivery report records its SHA).
- No changes to main/development-v2, merge, push, publishing or package version.

## Delivered contract

The separate Dart `HuaweiRtc` class adds `callApplication(HuaweiRtcCallRequest)`,
`hangup()`, `getActiveCall()` and `events`. Typed models are
`HuaweiRtcCallRequest`, `HuaweiRtcCallType`, `HuaweiRtcCall`,
`HuaweiRtcCallStatus`, `HuaweiRtcEvent`, `HuaweiRtcEventType` and
`HuaweiRtcException`. See [consumer documentation](huawei-rtc-outgoing.md).

Native `HuaweiRtcManager` owns a single application call; `HuaweiRtcBackend`
invokes the exact Core 2.5.28 public call API; `HuaweiRtcTokenProvider` invokes the
Huawei MM/shared API token flow. Main-thread state/result/event serialization,
cross-engine call/cleanup reservation, a dedicated token executor with bounded
waiting, terminal cleanup and detachable forwarding listeners cover plugin lifecycle.
The manager owns application Context and consults the plugin's current resumed
Activity only before new calls. Activity detach/recreation leaves active calls intact.

Audio uses `audio(true), video(false)`; video uses `audio(true), video(true)`.
Both invoke `callApplication`, with no RTC UI adapter or official API substitution.
Native `hangup()` is the only exposed control. Events are `state`, `ringing`,
`earlyMedia`, `established`, `finished`, `error`, `reconnecting`, `reconnected`.
Core errors are not assumed terminal; no connecting callback or failed state is
fabricated. Native status values are represented exactly.

Token flow: initialized Huawei MM → explicit identity or installation
pushRegistrationId → fresh `MobileApiResourceProvider.getMobileApiRtc(appContext)`
→ `getToken(TokenBody(identity, 43200L))` on the worker → native `TokenResponse.token`
→ Core request. The MM provider owns existing application authorization, base URI
and installation headers. No raw RTC token is passed to Dart or cached by the plugin.
Calls configuration is a separate required input from RTC push configuration.

Errors: `rtc_not_initialized`, `rtc_invalid_argument`, `rtc_permission_denied`,
`rtc_call_already_active`, `rtc_no_active_call`, `rtc_token_failed`,
`rtc_call_failed`, `rtc_invalid_state`. Messages are static/sanitized. Call reason
events carry only numeric Core error IDs. Native errors do not expose credentials,
raw backend text or exception details.

## Final runtime dependency findings

Both actual `debugRuntimeClasspath` and `releaseRuntimeClasspath` resolved:

| Check | Debug | Release |
|---|---|---|
| Huawei MM core / Chat / Inbox | 8.14.0 present | 8.14.0 present |
| Shared MM API / resources | 15.1.0 present | 15.1.0 present |
| RTC Core | 2.5.28 present | 2.5.28 present |
| Core media engine | `com.infobip:google-webrtc:1.0.45036` | Same |
| Standard MM Android core | ABSENT | ABSENT |
| RTC UI artifact and classes | ABSENT | ABSENT |
| Artifact records, including plugin | 154 | 154 |
| Unique external artifacts + plugin JAR | 147 + 1 | 147 + 1 |
| `org.infobip.mobile.messaging.*` classes | 718 | 718 |
| Duplicate MM classes | **0** | **0** |

The only repeated class archive entry outside MM is Java multi-release metadata
`META-INF/versions/9/module-info.class`. APK DEX/build verification also succeeds.
The dormant RTC UI reflection adapter/fake and non-transitive contract-test AAR
remain for existing tests; they are not used by the outgoing feature or packaged
as an RTC UI runtime.

Firebase/GMS are legitimate RTC Core transitives and have **no unsafe exclusions**.
RTC Core's POM declares `firebase-messaging:22.0.0` for its FCM-oriented push
implementation. This extension does not invoke push registration, active incoming
registration, FCM token APIs or an HMS RTC bridge. Their presence is not evidence
of Huawei incoming signaling.

| Group | Resolved artifacts and versions in both variants |
|---|---|
| Firebase | messaging 22.0.0; annotations 16.0.0; common 20.0.0; components 17.0.0; datatransport 18.0.0; encoders-json 18.0.0; encoders 17.0.0; iid-interop 17.1.0; installations-interop 17.0.0; installations 17.0.0; measurement-connector 19.0.0 |
| GMS | play-services-basement 17.0.0; play-services-cloud-messaging 16.0.0; play-services-stats 17.0.0; play-services-tasks 17.0.0 |

`com.infobip:google-webrtc` is the media engine, separate from Google Play Services.
Evidence: [debug tree](evidence/huawei-rtc-outgoing/debug-dependencies.txt),
[release tree](evidence/huawei-rtc-outgoing/release-dependencies.txt),
[class scan and artifact hash](evidence/huawei-rtc-outgoing/dependency-evidence.txt).

## Commands actually executed

Flutter/Dart commands ran at repository root. Gradle commands ran in
`example/android`. Full local logs are in `/private/tmp/huawei-rtc-outgoing`, with
early implementation checks at `/private/tmp/huawei-rtc-*.log`. No device or backend
call was performed. These results were executed for this change, not copied from research.

| Command | Result |
|---|---|
| `flutter pub get` | Exit 0 after authorized SDK-cache retry |
| `dart format lib/src/rtc/huawei_rtc.dart test/huawei_rtc_test.dart` | Exit 0; 2 files formatted |
| `dart format example/lib/screens/huawei_rtc_screen.dart example/lib/screens/home_screen.dart` | Exit 0; 1 file formatted |
| `dart format --output=none --set-exit-if-changed .` | Exit 0; **65 files, 0 changed**, final run |
| `flutter analyze` | Final exit **1**, **0 errors, 0 warnings, 21 infos** (existing deprecations); not labelled PASS |
| `flutter test test/huawei_rtc_test.dart` | Exit 0; **18 tests passed** |
| `flutter test --reporter expanded` | Exit 0; **200 tests passed** |
| `./gradlew :infobip_mobilemessaging_huawei:compileDebugKotlin --console=plain` | Exit 0 after authorized Gradle-cache retry; real 2.5.28 compile |
| `./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest --console=plain` | Exit 0; early full plugin suite, **197 tests** at that point |
| `./gradlew testDebugUnitTest --console=plain` | Final exit 0; **200 tests**, 0 failures/errors/skips; app task has NO-SOURCE; plugin tests executed |
| `./gradlew :app:assembleDebug --console=plain` | Exit 0; RTC-enabled debug APK rebuilt |
| `./gradlew :app:assembleRelease --console=plain` | Exit 0; RTC-enabled release APK, R8 actually executed |
| `./gradlew -I ../../docs/evidence/huawei-rtc-outgoing/resolve.gradle -PrtcEvidenceOutput=/private/tmp/huawei-rtc-outgoing :app:rtcRuntimeDebug :app:rtcRuntimeRelease :app:dependencies --configuration debugRuntimeClasspath --console=plain` | Exit 0; actual debug/release artifact inventories plus debug dependency tree |
| `./gradlew :app:dependencies --configuration releaseRuntimeClasspath --console=plain` | Exit 0; actual release dependency tree |
| `python3 docs/evidence/huawei-rtc-outgoing/inspect_artifacts.py /private/tmp/huawei-rtc-outgoing` | Exit 0; both graphs and duplicate assertions pass |
| `javap -public` on the resolved Core, Huawei provider and shared token models | Exit 0; [retained signatures](evidence/huawei-rtc-outgoing/api-evidence.txt) |
| `javap -c -p` on Core call/default/listener/permission classes | Exit 0; implementation-time signature/behavior checks against 2.5.28 |
| `git diff --check` | Exit 0 |

Initial sandboxed Flutter/format and Gradle compile attempts exited 1 because their
SDK/cache stamp/lock files were outside the writable roots; authorized retries
succeeded. The first analysis run exited 1 with 22 infos, including a new example
style info; that issue was fixed and the final result is the 21 pre-existing infos.
The staged whitespace check also identified trailing blank lines in the two captured dependency trees; those were removed before the final staged check. No Android build/test failure was hidden. Tests/builds were repeated after material
listener and cross-engine cleanup fixes. Gradle reports existing repository/deprecation
warnings and a shared `com.infobip` namespace warning between RTC/media AARs; release
R8 required no new dontwarn rules, keep rules or dependency excludes.

## Tests added

- **18 Dart tests**: distinct audio/video request encoding; optional/default identity;
  required parameters; all eight stable native errors with private details discarded;
  hangup; active snapshots/null; broadcast attach/cancel/reattach; every event kind;
  numeric termination reason; malformed events without stream loss; official guard propagation.
- **39 Android tests**: 28 manager tests, 9 published native boundary/token/permission
  tests, 2 plugin lifecycle tests. Includes exact request/options/context delegation,
  fresh token subject/lifespan, error sanitation, permission revocation, main-thread
  completion, process-wide ownership, second-call rejection, hangup failures,
  native terminal cleanup, nonterminal errors, listener detachment, Activity recreation,
  engine disposal, stale token cancellation, 30-second timeout, partial native creation,
  synchronous/duplicate callbacks, broken sinks and cross-engine cleanup reservation.
- Existing native official guard test extended to verify disable still rejects
  without a supported incoming session. Baseline counts were 182 Dart / 161 Android;
  final counts are **200 / 200**. Mocked tests do not prove an actual Huawei call works.

## Device status and limits

| Feature | Code | Unit | Huawei device |
|---|---|---|---|
| Outgoing audio | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Outgoing video | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Hangup | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Token delegation / lifecycle / events | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Actual token issuance / backend routing / media | Client flow inspected | Mock boundary only | NOT_VERIFIED |
| Incoming HMS / enableCalls / enableChatCalls / disableCalls parity | UNSUPPORTED / guarded | Guards verified | UNSUPPORTED |

There is no video renderer/preview, foreground call service, persistent notification,
additional media control, incoming signaling or process restoration. Background media
and real camera/microphone release on Huawei remain unverified. Engine-disposal
hangup is best effort; a native failure cannot be called remote termination.
An application needs its own authenticated test identity and backend Calls configuration.
External Huawei evidence from another plugin does not count as DEVICE_VERIFIED here.

Security: no new credential logging, Dart token input/output or credential persistence;
Core diagnostic logging disabled via its public API. The existing upstream Huawei
8.14.0 AuthorizationUtils header println remains an unresolved, documented security
concern and was explicitly outside scope. Do not publish raw device logs. No production
credentials or vendor binaries were added to the commit.

Recommendation: **READY FOR HUAWEI DEVICE TESTING**, following the
[outgoing checklist](webrtc-core-device-validation.md). Device/backend results must
precede claims of verified real-world calling.

## Changed files

The implementation commit contains these 29 text files:

- `API_COMPATIBILITY.md`
- `README.md`
- `android/build.gradle.kts`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/InfobipMobileMessagingHuaweiPlugin.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcBackend.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcContract.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManager.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcTokenProvider.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcBoundaryTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManagerTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcPluginLifecycleTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/webrtc/WebRtcOperationsTest.kt`
- `docs/evidence/huawei-rtc-outgoing/README.md`
- `docs/evidence/huawei-rtc-outgoing/api-evidence.txt`
- `docs/evidence/huawei-rtc-outgoing/debug-dependencies.txt`
- `docs/evidence/huawei-rtc-outgoing/dependency-evidence.txt`
- `docs/evidence/huawei-rtc-outgoing/inspect_artifacts.py`
- `docs/evidence/huawei-rtc-outgoing/release-dependencies.txt`
- `docs/evidence/huawei-rtc-outgoing/resolve.gradle`
- `docs/huawei-rtc-outgoing-verification.md`
- `docs/huawei-rtc-outgoing.md`
- `docs/webrtc-configuration.md`
- `docs/webrtc-core-device-validation.md`
- `docs/webrtc-core-research.md`
- `example/lib/screens/home_screen.dart`
- `example/lib/screens/huawei_rtc_screen.dart`
- `lib/infobip_mobilemessaging_huawei.dart`
- `lib/src/rtc/huawei_rtc.dart`
- `test/huawei_rtc_test.dart`
