# Phase 3.5.3 — final production validation and release certification

> Historical assessment from 2026-10-12, retained as investigation evidence.
> Its publication/version/licensing conclusions describe that checkout, not
> the current package. Use the [current README](../README.md) for installation
> and setup, and rerun release checks for the version being prepared.
> The root LICENSE now exists. Superseded publication snapshots were removed;
> missing-license findings and test counts below describe only the historical audit.


Audit date: 2026-10-12, Asia/Amman. Candidate: `fb359cb6f2c8609b03e2652b929a20020fcc8f21`.
**Production certification: NO-GO. Package publication is assessed separately
in [current integration and security guidance](../README.md).**

Publication documentation review, 2026-10-12: the original audit/build/test
results below are historical evidence, not new verification runs. Subsequent
[SEC-01 artifact evidence](sec01-release-logging-mitigation.md) establishes partial
removal of the MM header println in an unsigned optimized example APK. It does
not cover upstream RTC 2.5.28's signaling `printf`, which may expose temporary
TURN credentials; see the [sanitized Infobip disclosure draft](sec01-infobip-responsible-disclosure.md).
The current security matrix/checklist below reflects this limited mitigation;
the original section 13 describes the pre-mitigation baseline. Production
certification remains ungranted. The owner has decided not to submit a vendor
report before publication; disclosure is not a package publication gate.

## 1. Executive summary

Automated regression validation passes: 229 plugin Flutter tests, 42 example
Flutter tests, and 323 Kotlin tests in each of debug and release. The example
debug APK and unsigned release APK build successfully. The release build
actually executes R8 and resource shrinking. These results do not certify
on-device HMS, Chat authentication, RTC media or mandatory screen sharing.

Package publication is blocked by missing LICENSE. Separate production
acceptance gaps remain unresolved: reachable upstream
authorization-header logging, signed/minified device acceptance, and 16 KB
runtime/native compatibility disposition. The native audit finds nonzero RELRO
end alignment remainders in several 64-bit libraries despite successful LOAD
and ZIP alignment checks. This is a static compatibility concern, not an
observed device crash. No critical plugin-owned runtime defect was confirmed
by this audit; that is not proof that none exists.

Screen sharing is a required release feature. Its current contract is
Screen-as-Camera on Android 10+, with approximately 640×480 filtered output.
This report does not reclassify it as optional or experimental. Existing
notification text containing “Experimental” is a product-label inconsistency.

## 2. Repository identity, baseline and history

| Item | Verified value |
| --- | --- |
| Repository | `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin` |
| Required/current branch | `release/rtc-production-certification` |
| Required/current HEAD | `fb359cb6f2c8609b03e2652b929a20020fcc8f21` |
| Base | Local `development`; merge base `58ee312b12abea83c2d7204d466f1558a956e725` |
| Initial status | Clean: no staged, unstaged or untracked changes |
| Commits above local development | `c18351b` CHAT-01/CHAT-02/API-01; `fb359cb` Phase 3.5.2 |
| Earlier incorporated changes | `46b1c60` screen quality/orientation; `4b67b7a` performance; earlier RTC/capture history |
| Remote tracking snapshot | HEAD versus locally recorded origin release branch: 0/0; no fetch performed |

Commands: `git rev-parse --show-toplevel`, `git branch --show-current`,
`git rev-parse HEAD`, `git status --short`, `git log -6 --oneline`,
`git merge-base development HEAD`, `git log development..HEAD --oneline`,
`git show --stat c18351b`, `git show --stat fb359cb`. All executed successfully.
The branch/HEAD gate matched, so no Git-state correction was needed.

Phase 3.5.1 changes actual Dart/native JWT, activation and cleanup behavior and
adds regression tests. Phase 3.5.2 changes documentation, description and package
ignore rules; its two Dart source diffs are documentation comments only.
No unexpected executable change was found in Phase 3.5.2.

Public exports in `lib/infobip_mobilemessaging_huawei.dart:6` include core,
Chat, notification, Inbox and RTC call/control/rendering/screen APIs. Android
implementation and test directories exist; the example resolves the root plugin
through `path: ../`. Release/security guides, changelog and ignore rules exist.
Root LICENSE does not exist.

## 3. Package and toolchain versions

| Component | Candidate/local version |
| --- | --- |
| Package | `infobip_mobilemessaging_huawei 1.0.0` |
| Example | `1.0.0+1`; unpublished example |
| Dart requirement / executed | `^3.9.0` / 3.9.2 |
| Flutter requirement / executed | `>=3.35.7` / 3.35.7, framework `adc9010625`, engine `035316565a` |
| Runtime Dart direct dependency | `plugin_platform_interface 2.1.8` |
| Dart development dependencies | Flutter test SDK; `flutter_lints 5.0.0` |
| Example additional direct dependency | `crypto 3.0.7` |
| Huawei MM / Chat / Inbox | 8.14.0 each |
| RTC Core / WebRTC native | 2.5.28 / `com.infobip:google-webrtc:1.0.45036` |
| Huawei Push resolved | 6.7.0.300 |
| Shared Infobip API/resources | 15.1.0 |
| AGP / Kotlin / Gradle | 8.13.0 / 2.1.0 / 8.13 |
| Java compilation target / validation JVM | 17 / OpenJDK 21.0.11 |
| Plugin minSdk / compileSdk | 26 / 36 |
| Example minSdk / compileSdk / targetSdk | 26 / 36 / 36 |
| Screen sharing minimum | API 29 |
| Example desugaring library | 2.1.5 |
| Native test dependencies | JUnit 4.13.2; Mockito 5.20.0; ASM 9.8; Robolectric 4.16 |

Sources: root/example `pubspec.yaml` and lockfiles,
`android/build.gradle.kts:12`, `example/android/settings.gradle.kts:39`,
`example/android/app/build.gradle.kts:18`, wrapper properties.
Java 21 runs Android 36 Robolectric; the production target remains Java 17.

## 4. Validation commands and exact results

Commands ran on this candidate. Logs are retained in
`/private/tmp/rtc-final-cert-20261012/`; these are local audit evidence,
not published artifacts. Native XML reports are in
`example/build/infobip_mobilemessaging_huawei/test-results/`.
No test exclusions, code fixes or version upgrades were used.

Root commands run from the repository, example commands from `example/`,
and Gradle commands from `example/android/`. In Gradle commands below, prefix
`JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home`.

| Validation | Exact command | Exit | Result |
| --- | --- | --- | --- |
| Plugin tests | `flutter test --no-pub --reporter expanded` | 0 | PASS: 229 passed; no failures |
| Example tests | `flutter test --no-pub --reporter expanded` | 0 | PASS: 42 passed; no failures |
| Root analysis | `flutter analyze --no-pub` | 1 | FAIL exit, baseline only: 21 informational deprecations, 0 warnings, 0 errors |
| Example analysis | `flutter analyze --no-pub` | 0 | PASS: no issues |
| Broad formatting | `dart format --output=none --set-exit-if-changed lib test example/lib example/test` | 1 | FAIL: 89 files checked; one would change, ignored private `example/lib/config/example_test_config.dart`; no file written |
| Tracked formatting | Python invokes `dart format --output=none --set-exit-if-changed` with every filename returned by `git ls-files '*.dart'` | 0 | PASS: 88 files; 0 changes |
| Full native suites and Kotlin compilation | `./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin --offline --rerun-tasks` | 0 | PASS: 323 tests per variant, 49 suites per variant; failures/errors/skips all 0; debug/release Kotlin compiled; 66 tasks executed |
| Initial offline APK attempt | `./gradlew :app:assembleDebug :app:assembleRelease --offline` | 1 | BLOCKED release: three Flutter release engine JARs absent from cache |
| Consumer builds and resolved graph | `./gradlew :app:assembleDebug :app:assembleRelease :app:dependencies --configuration releaseRuntimeClasspath` | 0 | PASS: debug and unsigned release APK; R8/resource shrinking executed; 176 tasks, 89 executed |
| Separate debug result | `./gradlew :app:assembleDebug --offline` | 0 | PASS |
| Publication snapshot | `flutter pub publish --dry-run` | 65 | BLOCKED: missing LICENSE; docs/doc advisory |
| Diff integrity | `git diff --check` | 0 | PASS |

Root diagnostics match the supplied 21-info baseline and Phase 3.5.2 record.
They concern retained deprecated User, InboxFilterOptions, pushRegistrationEnabled
and from aliases. No new root warning/error or example diagnostic was found.
The full diagnostic locations are preserved in `root-analysis.log`.

Native warnings: existing unchecked cast at `NullableNativeDataTest.kt:68`;
deprecated Robolectric methods at `HuaweiRtcCallServiceTest.kt:106,225`;
deprecated LocalBroadcastManager in `NativeEventBridge.kt`; JVM class-sharing
warnings. Build warnings include duplicate `com.infobip` namespace in RTC and
google-webrtc, and Gradle features deprecated for Gradle 9. No warning was fixed
or suppressed during this audit.

The first Flutter version invocation was blocked by sandbox cache permissions.
The initial ADB invocation was similarly blocked from starting its daemon.
Permitted reruns succeeded. These were environment restrictions, not candidate
regressions. The initial test XML collection used the wrong build directory;
final counts above come from the actual example build output, not that empty path.

## 5. Kotlin test evidence

323 distinct existing tests execute in each build variant: 646 executions, not
646 distinct test cases. All 49 suites pass in both variants, with no skipped
tests. Debug and release tasks were forced to rerun.

Key suites: ChatJwtDeadlineTest 6, ChatJwtBridgeTest 6,
ChatActivationRecoveryTest 10, ChatApiLifecycleTest 7,
CleanupManagerTest 3, InitializationCoordinatorTest 16, HmsConfigurationTest 2,
HuaweiBroadcastIntegrationTest 3, HuaweiRtcManagerTest 46,
HuaweiRtcCallServiceTest 18, HuaweiRtcControlsTest 7,
HuaweiRtcVideoBindingsTest 14, HuaweiRtcVideoPlatformViewTest 5,
HuaweiRtcPluginLifecycleTest 2, HuaweiRtcScreenAsCameraTest 18,
HuaweiRtcScreenOrientationTest 4, HuaweiRtcScreenPerformanceTest 8 and
HuaweiRtcScreenVideoQualityTest 7. These are JVM/Robolectric/synthetic-media tests.

## 6. Android builds, consumer integration and signing

The example is a real Flutter Android consumer of the local plugin. Its resolved
release graph, merged manifest and generated R8 configuration were inspected.
Consumer compilation/build compatibility is PASS for this host/toolchain.
A separate clean external consuming application and other host configurations
were NOT RUN.

Outputs:
- `example/build/app/outputs/apk/debug/app-debug.apk`.
- `example/build/app/outputs/apk/release/app-release-unsigned.apk`.
- Release APK SHA-256:
  `daac735883905796c1835b8211ea505292c9c336c8e2bc57f660c28360ef945c`.

No release signing configuration is present in the example build script.
`build-tools/36.0.0/apksigner verify .../app-release-unsigned.apk` exits 1:
“DOES NOT VERIFY”, missing META-INF/MANIFEST.MF. This confirms the generated
artifact is unsigned; it is not a signing regression. Owner production signing,
signed installation, AppGallery/Play distribution and AAB validation are
NOT RUN / NOT TESTED. No signing credentials were invented or borrowed.

## 7. R8 / ProGuard

**PASS — actual minified example consumer build.** The log contains
`:app:minifyReleaseWithR8`, resource conversion/optimization and packageRelease.
`example/build/app/outputs/mapping/release/configuration.txt` contains the
exported plugin consumer rules, Flutter rules and SDK/HMS/WebRTC rules.
Manifest-generated rules retain both plugin foreground service constructors.

`android/consumer-rules.pro:1` contains exact optional OEM, HiAnalytics and
BouncyCastle missing-class suppressions; no plugin-added broad package
suppression was introduced. Installed dependency regression tests pass.
SDK native/reflective contracts receive their dependency consumer rules; actual
build success is stronger than static rule inspection.

HMS Push, native/embedded Chat, JWT bridge, RTC, renderer, screen capture and
notification runtime behavior after shrinking remain UNVERIFIED. No minified
device call, push delivery or widget authentication was performed.
R8 mapping retains AuthorizationUtils source line 113; minification is not a
verified mitigation for the upstream logging defect.

## 8. Chat reliability certification

**CHAT-01 — PASS source and automated regression evidence.**
Dart `lib/src/core/infobip_mobilemessaging_huawei.dart:68,418,541` supplies a
25-second request timer, 32-request limit, completion guard, generation ownership,
bounded request bookkeeping and invalidation. The underlying host Future is not
cancellable and can outlive its timed-out wrapper; hosts must bound network work.
Error handlers receive host errors locally, but native rejection uses fixed text.

Native `ChatJwtBridge.kt:13,36,60,92` supplies a 30-second monotonic deadline,
32 pending requests, UUID correlation, generation validation, removal before
completion, late/duplicate rejection and cancellation of scheduled callbacks.
The daemon executor removes cancelled work. `ChatManager.kt:119` dispatches SDK
callbacks to main and rechecks ownership before returning a JWT.
Engine disposal at `ChatManager.kt:208` disables requests and invalidates
activation; `InfobipMobileMessagingHuaweiPlugin.kt:195` detaches channels/owners.
Tests exercise expiry even before the scheduled callback, capacity recovery,
out-of-order/duplicate responses, teardown, scheduler failure and stale results.
No plugin JWT/header logging was found in these paths.

**CHAT-02 — PASS source and regression evidence.**
`ChatManager.kt:35` rejects disposed/uninitialized activation, serializes
activation, prevents reentrant duplication and enforces a 1,000 ms retry cooldown.
Failure is observable as chat_unavailable while MM stays initialized.
`InfobipMobileMessagingHuaweiPlugin.kt:655` tracks pending initialization results,
engine generation and manager identity before Chat activation.
Same-code retry reuses the initializer and configured listener bridges.
Tests cover failure/retry, listener preservation, concurrent activation and engine
disposal. Backend/widget acceptance and physical fragment recreation are UNVERIFIED.

**API-01 — PASS tested ordering and rejection behavior.**
Dart `...huawei.dart:137` shares one cleanup Future, rejects conflicting
initialization/Chat configuration and discards Chat state only after native success.
Native plugin `:259` reserves cleanup, rejects active outgoing RTC ownership
without hanging up, checks stale callbacks, and releases reservations in finally.
`CleanupManager.kt:29` calls SDK cleanup before clearing plugin callbacks.
Tests cover rejected cleanup retaining pending JWT resolution, concurrent cleanup,
initialization races, active RTC and detached-engine callbacks.

Limitation: vendor cleanup is not transactional. If a later native step fails
after SDK cleanup has already succeeded, rollback of vendor state is not promised.
Preservation after rejection is verified for tested early rejection/SDK-throw
paths, not every possible partially committed vendor failure.

## 9. RTC certification

**PASS — local source, unit and consumer build evidence; runtime UNVERIFIED.**

`HuaweiRtcBackend.kt:27` uses installed Core public callApplication APIs and
disables Core diagnostic logging. `HuaweiRtcTokenProvider.kt:20` obtains tokens
through initialized MM's MobileApiRtc, using explicit identity or registered
installation identity; there is no public Dart RTC token output.
`HuaweiRtcManager.kt:172` owns a single session/process slot, fetches tokens on
its executor with a 30-second response bound, rechecks Activity/permissions and
starts foreground support before media creation. Callback dispatch is serialized
on main and rejects obsolete session ownership.

`HuaweiRtcManager.kt:245,333,369,396,426` handles partial call creation,
terminal events, listener/task/render cleanup, active-call cleanup rejection and
engine disposal. A hangup failure can retain SDK activity: verified ownership
and failure handling do not guarantee native termination without SDK/device evidence.
Activity detach invalidates rendering/capture without being engine disposal.

`HuaweiRtcControls.kt:9,23` uses SDK readback for mic/camera/speaker/routes;
speaker-off selects available earpiece. Manager guards call ID and state.
`HuaweiRtcVideoBindings.kt:63,82,89` removes old sinks before replacement,
pins a sole remote endpoint, blanks ambiguity and releases owned renderers
idempotently. It does not dispose SDK-owned tracks/shared EGL.
`HuaweiRtcCallService.kt:98,134,179` checks session/call IDs for actions,
uses immutable PendingIntents, private generic call notification content and a
non-sticky service. Terminal fallback retains uncertain call ownership.

No new confirmed mandatory plugin-owned RTC production defect was isolated.
Remaining risks: vendor/JNI races, real GL/surface teardown, background/OEM
termination, reconnects and actual camera/microphone/audio-route release.
Synthetic tests and APK builds do not measure leaks, ANRs or device media quality.

## 10. Mandatory screen sharing certification

**PASS — source and existing regression contracts; runtime acceptance UNVERIFIED.**

| Requirement | Actual evidence and boundary |
| --- | --- |
| Consent/no silent start | `HuaweiRtcScreenCaptureController.kt:103,136,139`: focused Activity, fresh OS consent intent; cancelled/stale result rejected; one-shot consent retained only for startup |
| Established video/enabled camera | Controller `:109` requires established video call and hasCameraVideo |
| Foreground service | Controller `:151` waits for foreground promotion before acquiring projection; `HuaweiRtcScreenCaptureService.kt:25,43`; manifest declares mediaProjection type/permission |
| Existing outgoing camera substitution | Controller `:111` installs public VideoFilter; `HuaweiRtcScreenVideoFilter.kt:49` submits screen Bitmap through camera cadence; no separate screen track |
| Frame ownership | `HuaweiRtcScreenFrameProcessor.kt:13` acquireLatestImage/use closes images, reusable private scratch, independent transfer; filter retains one latest frame and recycles replacement/rejected capture frames |
| Output allocations | Filter creates one immutable result per SDK camera callback; submitted Bitmaps are not recycled/reused without consumption callback. No plugin unbounded frame queue, but SDK retention/GC/RSS bounds remain UNVERIFIED |
| Orientation/preview | Filter `:58` compensates installed output transform, uses display-oriented fit-center content; bindings `:48,132` disable local mirroring and apply fit preview during sharing |
| Resize | Controller `:182`: initial resize establishes reference; changed subsequent size stops capture; restart requires fresh consent |
| Stop/restoration | Controller `:219,238`: blocks filter generation before cleanup; camera-frame callback records restoration independently from resource release; remote receipt is not acknowledged |
| Bounded worker cleanup | Controller `:34,254`: quitSafely/join(500) off main, at most three automatic attempts with retained failed resource ownership; uncertain stop reported after 3 seconds; Dart fallback 5 seconds |
| Stale ownership | Session identity/call identity/epoch checks reject obsolete start/frame/restore results; old capture cleanup still must release its own resources |
| Public API | Exported `HuaweiRtcScreenAsCamera` start/stop/state/events and screen-aware local video preview are present |

Independent binary inspection of installed
`com.infobip.webrtc.sdk.impl.call.handler.CameraVideoMediaHandler` confirms literal
640 and 480 passed to DefaultVideoFilterManager.start and camera startCapture.
Source filter output uses supplied dimensions; capture longest edge is at most
640. Approximately 640×480 remains accurate for this pinned filtered path, not
a promise of negotiated/received resolution or arbitrary screen resolution.
Small portrait text is reduced by scaling/letterboxing. Actual encoder/peer
resolution and readability were NOT MEASURED.

Thread shutdown is bounded at the plugin join boundary; arbitrary vendor calls
such as projection.stop or sink removal are not proven latency-bounded.
Process death cannot be certified from in-process state flags.

## 11. Android compatibility

**STATICALLY VERIFIED:** declared SDK/toolchain, permission gates, merged
permissions/service types, focused foreground start, consent ordering,
non-sticky service and current source API guards.
**RUNTIME VERIFIED during this audit:** connected device identity/OS/page size
only, not plugin functionality.

| Android | Static assessment | Plugin runtime during audit |
| --- | --- | --- |
| 8 / API 26–27 | Meets minSdk; mic/camera permissions and notification channels; screen sharing deliberately returns screen_unsupported | NOT RUN |
| 9 / API 28 | FGS permission declared; no supported Screen-as-Camera below 29 | NOT RUN |
| 10 / API 29 | Supported screen gate; typed projection FGS and user consent | NOT RUN; Huawei ANA_NX9 device available |
| 11 / API 30 | Call FGS camera/mic types supplied; projection callback/cleanup inspected | NOT RUN |
| 12 / API 31–32 | Nearby devices gate and immutable PendingIntents; focused foreground call/capture start | NOT RUN |
| 13 / API 33 | POST_NOTIFICATIONS declared; host must request permission; denial cannot waive foreground-service obligations | NOT RUN |
| 14 / API 34 | Explicit camera/mic/projection permissions and types; callback before virtual display; fresh consent per start | NOT RUN |
| 15 / API 35 | 16 KB concerns and background/FGS/consent behavior require device validation | UNVERIFIED |
| 16 / API 36 | Compiles/targets 36; orientation/layout/FGS behavior needs real acceptance; Robolectric coverage is not OS compatibility | UNVERIFIED |

The merged release manifest has minSdk 26/targetSdk 36, required media permissions,
non-exported plugin services/receiver, allowBackup=false and usesCleartextTraffic=false.
Consumers own Huawei configuration, permission UX and host policies; the plugin
library alone cannot impose every consumer runtime setup.

Official references consulted:
[MediaProjection](https://developer.android.com/media/grow/media-projection),
[Android 14 foreground service requirements](https://developer.android.com/about/versions/14/changes/fgs-types-required),
[Android 15 changes](https://developer.android.com/about/versions/15/behavior-changes-15),
[Android 16 changes](https://developer.android.com/about/versions/16/behavior-changes-16).
These define platform review boundaries; they do not verify this plugin on devices.

## 12. 16 KB native-library assessment

Commands: extract each packaged .so to an audit temporary directory, run installed
NDK 28.2.13676358 `llvm-readelf -lW <library>`, and run Build Tools 36.0.0
`zipalign -c -P 16 4 <APK>` separately for debug and unsigned release.
ELF inventories are retained in `elf-debug.json` and `elf-release.json`.

**PASS:** both APK ZIP alignment checks exit 0. Every packaged arm64-v8a/x86_64
PT_LOAD alignment is at least 0x4000. Release results:

| Native library | ABI | PT_LOAD alignment | (RELRO VirtAddr + MemSiz) modulo 0x4000 |
| --- | --- | --- | --- |
| libapp.so | arm64-v8a / x86_64 | 0x10000 | No RELRO segment |
| libflutter.so | arm64-v8a | 0x10000 | 0x1000 |
| libflutter.so | x86_64 | 0x10000 | 0x2000 |
| libjingle_peerconnection_so.so | arm64-v8a | 0x4000 | 0x2000 |
| libjingle_peerconnection_so.so | x86_64 | 0x4000 | 0 |

armeabi-v7a WebRTC PT_LOAD alignment is 0x1000; the cited 16 KB native review
targets 64-bit ABIs. Debug also contains the Flutter Vulkan validation layer.
Its arm64 RELRO remainder is 0x3000. Debug Flutter and arm64 WebRTC also have
nonzero RELRO remainders.

**FAIL — additional static RELRO criterion; runtime consequence UNVERIFIED.**
The [current Android native page-size guide](https://developer.android.com/guide/practices/page-sizes)
includes a RELRO end-alignment check in addition to LOAD/ZIP checks.
The nonzero values above fail that criterion. Obtain toolchain/vendor disposition
and test the exact signed production artifact on a 16 KB environment before
certifying compatibility. This audit did not reproduce a linker crash and does
not claim every nonzero remainder has been demonstrated to crash on this stack.

WebRTC library provenance is the cached
`com.infobip:google-webrtc:1.0.45036` AAR, not plugin-authored native code.
Flutter library provenance is the installed Flutter engine.
No SDK libraries were patched or rebuilt.

ADB succeeds and identifies Huawei ANA_NX9, Android 10/API 29, PAGE_SIZE=4096.
Only device property queries were run; no app installation, app launch, call,
capture or real 16 KB test occurred. **UNVERIFIED — 16 KB runtime compatibility.**

## 13. Security audit and upstream finding

**SEC-UP-01 — HIGH; release-blocking pending resolution. CONFIRMED SOURCE DEFECT
with installed-bytecode corroboration; POTENTIAL RUNTIME EXPOSURE.**

Installed Huawei MM 8.14.0 AAR SHA-256:
`65c21c6fedb83efae658209104c5da4e04a3128fde90116037853d33182638dc`.
Read-only extraction and `javap -p -c -l` on AuthorizationUtils confirms
`getAuthorizationHeader`, source `AuthorizationUtils.java:113`, obtains
System.out and calls PrintStream.println with the full constructed header.

Valid MM JWT produces Bearer authorization; absent MM JWT produces App
application-code authorization. Invalid/expired JWT returns earlier.
The println is independent of the vendor logger level: Core Level.OFF does not
disable it. Caller bytecode in PersonalizeSynchronizer and UserDataReporter
invokes this method; plugin UserManager exposes personalize/fetch/save operations.
Thus the path is statically reachable through supported plugin features.
This is not evidence that Chat widget JWT or every RTC request traverses it.

Impact: authorization material can be emitted to Android stdout/log collection
during affected user operations. Capture/access conditions determine exposure;
no hostile log access, credential theft or exploitation was demonstrated.
No live sensitive operation or raw device-log capture was used to verify it.
**VERIFIED RUNTIME EXPOSURE: not established during this audit.**

Only Huawei MM/Chat/Inbox 8.14.0 versions are cached locally. No locally installed
fixed vendor version or verified mitigation was found. Current external vendor
fix availability and CVE data are UNVERIFIED. Documentation disclosure and avoiding
raw-log distribution reduce secondary sharing risk but do not fix the logging.
R8 mapping preserves the method/line; no verified log-removal mitigation exists.
Ownership is upstream Infobip; severity and release safety remain independent.

Plugin-owned reviewed paths use fixed sanitized failures and avoid logging tokens,
JWTs, screen pixels or raw SDK HTTP exceptions. Initialization logs an SDK enum
and numeric code, not a raw exception body. Callback payloads deliberately carry
business data to the host; host callbacks/loggers remain an integration boundary.
RTC identities require backend authorization; an arbitrary client identity is
not an authorization policy.

MediaProjection consent is one-shot; capture can include other apps/private content.
Secure-surface behavior, notification privacy and actual stop on revocation/process
death require device evidence. No claim of security certification is issued.

Tracked-file/package inventory found no private AGConnect JSON, signing key,
APK/AAB/AAR or local private configuration filenames. The package dry-run reports
no sensitive-file warning. The example has controlled-test credential/signing
facilities documented in SECURITY.md; generated private-host APKs are local build
evidence, not cleared for public distribution. No production-credential extraction
or disclosure was performed.

## 14. Publication audit

**BLOCKED.** Root pubspec, README, CHANGELOG, SECURITY, API exports, example,
.pubignore and documentation are present; root LICENSE is missing.
Repository/issue metadata point to the existing repository. Version is 1.0.0.

To preserve user-owned lockfiles/private configuration, the dry-run used a new
temporary tracked-file snapshot plus copies of current root/example lockfiles.
No Git metadata or ignored private credentials were copied. Pub resolved only
in that snapshot. This is package-content validation, not publisher-account,
package-name availability or real-checkout dirty-state validation.

`flutter pub publish --dry-run` executes, exits 65, archive 1018 KB:
- Error: root LICENSE required.
- Advisory: top-level docs should follow singular doc convention.
- No additional publication error or sensitive-file warning was reported.

The snapshot contains public Dart/native source/resources/manifest/consumer rules,
example, tests and historical documentation/evidence. Ignore rules exclude build
output, SDK binaries, private AGC/signing/configuration and lockfiles from the
archive. Example Gradle wrapper JAR is tooling. This report was written after that
dry-run and is the only intended added source file; it contains no credentials.
No LICENSE was created or chosen, and no publication occurred.
[Official Dart publication requirements](https://dart.dev/tools/pub/publishing).

## 15. Dependency audit

Resolved runtime graph was generated by Gradle during the successful consumer
build. Huawei MM remains the only MM core; official RTC UI 15.1.0 is inspection-only,
not a shipped runtime integration. Enabling that unsupported integration is guarded
in `android/build.gradle.kts:80`. No conflicting standard MM core was found.

RTC Core retains Firebase Messaging 22.0.0 and GMS basement/cloud messaging/tasks
transitives; their presence does not prove incoming HMS RTC support.
Resolved Kotlin stdlib is 2.1.0, coroutines 1.10.2 and AndroidX core 1.16.0; conflict
resolution raises older transitive requests to these selected versions.
Compilation/native tests and example R8 build pass this exact graph. Runtime/OEM
interaction and arbitrary other consumer graphs remain UNVERIFIED.

Dart runtime dependency is plugin_platform_interface 2.1.8; most root transitives
are Flutter test tooling. Example adds crypto 3.0.7 and typed_data 1.4.0.
Local lockfile inspection records async 2.13.1, collection 1.19.1, meta 1.16.0,
path 1.9.1, test_api 0.7.6 and vm_service 15.3.0 among the test transitives.

**UNVERIFIED:** current newest versions, vendor advisories, full dependency
vulnerability inventory and newer-version compatibility. No stale historical
“latest” number is represented as current. No CVEs invented; no dependency
upgrade, lockfile edit or removal of GMS/Firebase transitives was performed.

## 16. Device evidence and its limits

| Evidence category | This audit |
| --- | --- |
| Automated Dart/unit tests | PASS, executed 229 plugin / 42 example |
| Flutter widget tests | Included in passing suites; simulated channels/UI |
| Native unit/Robolectric tests | PASS, 323 each debug/release |
| Consumer APK/R8 build | PASS debug and unsigned minified release |
| Integration/device tests | NOT RUN |
| Physical Huawei functional acceptance | NOT RUN; connected device properties only |
| Backend authentication/call/push tests | NOT RUN |
| Signed minified runtime acceptance | NOT RUN |
| 16 KB environment runtime | UNVERIFIED; connected device is 4 KB |

The task supplies earlier physical Huawei confirmation of RTC and screen sharing.
That is accepted as historical user-reported evidence only; the reviewed quality/
performance records explicitly leave post-change physical acceptance outstanding.
There is no candidate-SHA, signed-artifact, device/backend acceptance record in the
reviewed material that closes those gates. Earlier RTC/screen success is not extended
to Phase 3.5.1 JWT deadlines, activation retries or cleanup race behavior.
Historical Inbox setSeen persistence remains unresolved as a backend/context
investigation in `docs/inbox-set-seen-investigation.md`; it is not a newly proven
plugin defect or proof of a vendor bug.

## 17. Findings and release blocker matrix

Severity estimates impact; confidence and ownership are separate. No CRITICAL
finding was confirmed. Security/device/build/native findings below concern
production acceptance; PKG-01 is the package publication blocker. Vendor disclosure
is optional under the owner decision and does not close SEC-01.

| ID | Severity / category | Evidence / exact location | Impact and reproduction conditions | Ownership | Mitigation / blocking |
| --- | --- | --- | --- | --- | --- |
| SEC-UP-01 / SEC-01 | HIGH, upstream security | MM AuthorizationUtils.java:113; RTC 2.5.28 SocketHandler.logMessage printf; SEC-01 artifact record and disclosure draft | Authorization headers and signaling with temporary TURN credentials may reach stdout; exact signed-candidate exposure/exploitation UNVERIFIED | Infobip Huawei MM 8.14.0 / RTC 2.5.28 | PARTIALLY MITIGATED: known MM println removed in unsigned example Release; RTC printf outside optional rule; upstream fix and signed verification missing; production security unresolved; vendor disclosure not a publication gate |
| PKG-01 | HIGH, publication | Missing root LICENSE; publish.log exit 65 | Every pub.dev publication dry-run fails requirement | Package owner/legal authority | No license selected; BLOCKING |
| DEVICE-01 | HIGH, validation gap | ChatManager.kt:35,119; plugin.kt:259,655; sections 8/16 | Actual SDK/backend JWT timeout, retry and cleanup behavior not accepted on candidate | Plugin/host validation owners | Unit coverage passes; device/backend acceptance missing; BLOCKING production acceptance |
| DEVICE-02 | HIGH, required feature gap | ScreenCaptureController.kt:103,182,219,254; quality/performance docs physical checklists | Signed device RTC/rendering/capture, orientation/resize, stop/revoke/background/end/engine teardown unverified after current changes | Plugin/host validation owners | Historical user evidence only; BLOCKING production acceptance |
| BUILD-01 | HIGH, release validation gap | example/android/app/build.gradle.kts; unsigned APK; apksigner verification | Production signing, signed minified installation and runtime cannot be certified from unsigned build | Host release owner | R8 build PASS; signed/runtime NOT TESTED; BLOCKING production acceptance |
| NATIVE-01 | HIGH, upstream binary/validation concern | Release APK lib/arm64-v8a/libflutter.so, lib/x86_64/libflutter.so, lib/arm64-v8a/libjingle_peerconnection_so.so; section 12 | Nonzero RELRO-end modulo 16 KB fails current documented static criterion; actual failure on 16 KB device unverified | Flutter engine / Infobip WebRTC artifact; consumer integration owner | LOAD/ZIP PASS; vendor disposition and 16 KB runtime missing; BLOCKING production acceptance |
| API-LIMIT-01 | MEDIUM, supported feature limitation | RTC CameraVideoMediaHandler.startCameraCapture; filter.kt:49 | SD output/letterboxing reduces small-text readability during required sharing | SDK capability / product acceptance | Documented; needs explicit readability acceptance, no arbitrary-resolution claim |
| PLUGIN-UI-01 | LOW, plugin-owned label inconsistency | ScreenCaptureService.kt:34,40 | Every capture notification labels required supported sharing “Experimental” | Plugin | Unchanged; nonblocking label correction in separately authorized work |
| FORMAT-01 | LOW, local artifact | Ignored example/lib/config/example_test_config.dart; format.log | Broad formatter finds one would-change file | Private example configuration owner | Source not written; tracked format PASS; nonblocking |
| PKG-02 | INFORMATIONAL, packaging | docs/ directory; dry-run advisory | Pub convention/tool discovery warning | Package owner | Documented; nonblocking |
| ANALYSIS-01 | INFORMATIONAL, baseline | root-analysis.log; deprecated aliases in library/tests | Root analyzer exits 1 for 21 infos | Plugin compatibility API/test owners | Baseline unchanged; nonblocking under supplied baseline |
| DEP-01 | INFORMATIONAL, dependency uncertainty | Resolved graph; section 15 | Latest/advisory data unavailable to local audit | Vendor / consumer owners | UNVERIFIED; does not imply confirmed vulnerability |

No plugin-owned mandatory runtime defect beyond these verified observations was
confirmed. Automated success does not close the validation-gap findings.

## 18. Current publication and production decisions

**Package publication: NO-GO** because the root LICENSE and owner authorization
of provenance/redistribution rights are missing. Final dry-run success and upload
authorization must be confirmed; see [current integration and security guidance](../README.md).

**Production security certification: not granted.** SEC-01 remains PARTIALLY
MITIGATED, with RTC printf outside the optional workaround. Signed-device/backend
and 16 KB runtime acceptance remain UNVERIFIED. Publishing the source package
would not certify those outcomes. The owner has decided not to submit a report
before publication; vendor disclosure, acknowledgment or a fix is not a package
publication gate.

## 19. Next steps by scope

For package publication, obtain explicit owner authorization for a specific
license, copyright attribution and redistribution rights, add the approved root
LICENSE, rerun the checks and review the archive. Confirm the publishing account
and package/version availability. No license approval has been inferred.

For production acceptance, retain the upstream security finding and assess both
MM header and RTC signaling logging on the exact signed host using disposable
credentials and sanitized evidence. A permanent upstream fix remains desirable;
the disclosure draft is optional and unsent. The R8 workaround removes only
matching print/println application-wide and does not cover RTC printf.

Investigate the native RELRO concern and validate on a real 16 KB environment;
complete signed Huawei/backend acceptance and SD sharing readability checks.
SDK/toolchain or runtime changes require separate scoped work. These production
checks are distinct from source-package publication.

No vendor report, commit, push or publication is authorized by this document.

## 20. Final acceptance checklist

The first item is a package publication requirement. The remaining items are
production/host acceptance requirements and optional workaround validation; they
do not require vendor disclosure before publication.

- [ ] Owner-approved LICENSE/provenance and redistribution rights recorded; add
      the root LICENSE, then rerun `flutter pub publish --dry-run` on the final
      candidate and review its archive for secrets/private artifacts. Last recorded
      run failed for missing LICENSE; the current publication review also failed
      with exit 65. Successful post-LICENSE dry-run remains UNVERIFIED; see
      [current validation procedure](../CONTRIBUTING.md#formatting-and-validation).
- [ ] For production security acceptance, assess upstream MM authorization-header
      and RTC temporary TURN-credential logging and record residual risk / verified
      remediation. SEC-01 remains PARTIALLY MITIGATED; vendor fix and signed-device
      sensitive-log absence UNVERIFIED. Optional draft retained, not sent; owner
      declines prepublication reporting. Vendor response is not a publication gate.
- [ ] If the host opts into R8 suppression, keep print/println rules in host Release
      configuration with R8/optimization enabled, outside plugin consumer rules;
      inspect the shipping artifact and accept application-wide stream-output
      regressions/residual printf and other logging risk. Host verification UNVERIFIED.
- [ ] Exact signed minified artifact SHA, signing provenance, device/OS and backend
      configuration recorded; clean install and upgrade/startup accepted.
- [ ] HMS init/token registration, delivery, foreground/background and cold/warm
      notification taps; permission denial/regrant; unread/native/embedded Chat.
- [ ] Chat JWT success/invalid/never-completing/late/out-of-order/capacity paths;
      provider replacement/engine detach; activation failure then same-code retry
      before/after cooldown; preserve pending provider/listener on rejected cleanup.
      Physical Huawei/backend acceptance of the exact signed candidate UNVERIFIED.
- [ ] Cleanup concurrency/init races and active RTC rejection accepted without
      resetting live call/auth state.
- [ ] Audio/video calls, mute/camera/speaker/routes, local/remote preview, reconnect,
      notification controls, Activity reattach and engine teardown accepted.
- [ ] Required sharing: fresh consent/cancel; portrait/landscape asymmetrical text;
      expected bars/readability; scroll/motion; unmirrored local/remote publication;
      resize stop then fresh consent; Flutter/notification Stop, revocation,
      background/lock/task removal/call end; resources/projection released and
      camera publication restored. Repeat cycles and profile memory/thread growth.
- [ ] Android 12+ permissions, 13 notification denial and 14–16 projection/FGS/
      background enforcement accepted on representative devices.
- [ ] 16 KB native gate cleared and exact signed artifact launch/call/share tested
      without relying on standard 4 KB-device success. Historical LOAD/ZIP checks
      passed but RELRO concern remains; vendor/toolchain disposition and 16 KB
      runtime compatibility UNVERIFIED.
- [ ] Inbox setSeen historical backend/context issue disposition recorded if Inbox
      persistence is part of the release acceptance scope.

## 21. Final Git and artifact integrity

Final checks execute after writing this report:
`git status --short`, `git diff --check`, `git diff --name-only`,
`git diff --cached --name-only`, `git ls-files --others --exclude-standard`,
`git rev-parse HEAD`, and SHA-256 comparisons of package/lockfiles/Gradle files
and the ignored private example configuration.

Intended and only added source file:
`docs/final-production-certification.md`.
Production code, tests, manifests, package/dependency versions and both checkout
lockfiles remain unchanged. No staged changes, commit, push, branch switch,
tag, publication or SDK binary modification occurred. HEAD is still the exact
required commit. Tracking divergence is 0/0 against local origin metadata.

Generated Flutter/Gradle outputs and caches are retained; existing user/private
files were not deleted or reformatted. Audit temporary extraction/snapshot/log
files remain under `/private/tmp/rtc-final-cert-20261012/`. Source equality is
checked against the initially clean candidate; ignored generated cache content
is outside that source-integrity assertion.
