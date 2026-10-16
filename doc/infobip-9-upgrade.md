# Infobip 9 upgrade — future major release preparation

Date: 2026-10-16. Package version remains **1.0.1**; these are unreleased
source changes, not a statement about the published 1.0.1 package.

## Repository verification

PASS: repository `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`,
branch `feature/update-infobip-dependencies`. The original upgrade began with a
clean tree; resumed validation began with 13 modified tracked files and this
untracked report. All existing changes were preserved, with no branch switch.
Starting commit: `d532c35` (previous Flutter/Dart compatibility upgrade).
No commit, push or publication is part of this task.
FVM-installed Flutter 3.47.7 / Dart 3.13.5 reverified locally. No global SDK upgrade.
The PATH default is older, so validation explicitly used
`/Users/apple/fvm/versions/3.47.7/bin/flutter`.

## Dependency and toolchain changes

| Component | Before | After |
| --- | --- | --- |
| Huawei Core / Chat / Inbox | 8.14.0 | 9.1.0, aligned |
| Shared Infobip API / resources | 15.1.0 | 16.1.0, SDK-selected |
| RTC Core | 2.5.28 | 2.5.41 |
| WebRTC | 1.0.45036 | 1.0.47976t, SDK-selected |
| compileSdk (plugin and example) | 36 | 37 |
| Example AGP | 8.13.0 | 9.1.1 |
| Gradle wrappers | 8.14 | 9.3.1 |
| Kotlin compiler integration | Separate KGP 2.2.20 | AGP built-in Kotlin 2.2.20 |
| Java bytecode target | 17 | 17 |
| minSdk / example targetSdk | 26 / 36 | 26 / 36 |
| Package Flutter / Dart minimum | 3.35.7 / ^3.9.0 | 3.47.0 / ^3.13.0 |
| HMS Push | SDK-selected | SDK-selected 6.7.0.300 |
| AGConnect | 1.9.1.301 | 1.9.1.301 |

PASS: Maven Central POMs and all four AARs were retrieved and inspected.
Each Huawei 9.1.0 AAR declares `minCompileSdk=37`; each has native minSdk 21,
so the plugin retains minSdk 26. RTC does not require raising targetSdk.
No unrelated dependency pins, broad exclusions, standard Android Messaging Core,
or production RTC UI were added. The pre-existing nontransitive RTC UI AAR
configuration remains exclusively a native test contract fixture.

[Android's API-level matrix](https://developer.android.com/build/releases/about-agp)
sets the minimum AGP for API 37 to **9.1.1**, not 9.1.0.
[AGP 9.1 compatibility](https://developer.android.com/build/releases/agp-9-1-0-release-notes)
requires Gradle 9.3.1, JDK >=17, and Build Tools 36.0.0; it defaults to Kotlin 2.2.10.
Flutter 3.47.7 rejects Kotlin <2.2.20. The example retains a **non-applied**
`org.jetbrains.kotlin.android` 2.2.20 declaration in settings to select AGP's
compiler runtime on its shared plugin classpath. Neither module applies the
legacy Kotlin Android plugin. The compiler version must be selected on the shared settings classpath,
where AGP is resolved; its selection is verified by Flutter's enabled dependency
checker. This keeps the previous
compiler version and does not suppress validation.

Validation uses local JDK 21.0.11 because the existing API 36 Robolectric tests
need Java 21; Java/Kotlin compilation targets remain 17.

### Host migration / build compatibility break

Remove application of `org.jetbrains.kotlin.android` from host and plugin
modules; use `kotlin.compilerOptions` with JVM target 17. Select AGP >=9.1.1,
Gradle >=9.3.1, Kotlin compiler runtime >=2.2.20 and compileSdk >=37 in the host.
Use the example settings declaration with `apply false` to select Kotlin 2.2.20
without applying `org.jetbrains.kotlin.android` to any module. Enable
`android.builtInKotlin=true` and retain `android.newDsl=false` while Flutter still
requires its legacy AGP DSL. The latter is Flutter's documented migration setting,
not suppression of dependency/API compatibility checks.

The [Flutter plugin migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)
gives a general plugin migration floor of Flutter 3.44 / Dart 3.12, but that older
path uses built-in Kotlin disabled and the legacy KGP bridge. This checkout
requires the supported **enabled built-in Kotlin** configuration, whose official
floor is **Flutter 3.47**, with associated Dart **3.13**. The floor is 3.47.0,
not the installed patch version 3.47.7. The exact minimum patch combination has
not been runtime-tested; validation here uses 3.47.7 / 3.13.5.
See also the [host migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

Install Android SDK Platform 37 explicitly. The example sets
`android.builder.sdkDownload=false` so builds report missing components instead
of installing Android SDK components automatically.

## Inspected artifact identities

| Maven Central AAR | SHA-256 |
| --- | --- |
| [infobip-mobile-messaging-huawei-sdk:9.1.0](https://repo.maven.apache.org/maven2/com/infobip/infobip-mobile-messaging-huawei-sdk/9.1.0/infobip-mobile-messaging-huawei-sdk-9.1.0.aar) | `cfd606035ea549580a16bfd45dfbb13079962c3713874768a12c901d36eb114b` |
| [infobip-mobile-messaging-huawei-chat-sdk:9.1.0](https://repo.maven.apache.org/maven2/com/infobip/infobip-mobile-messaging-huawei-chat-sdk/9.1.0/infobip-mobile-messaging-huawei-chat-sdk-9.1.0.aar) | `9d8d67ee65532ba98a6dd8146ace4d390be0645c98a24a52a40a5b8211114752` |
| [infobip-mobile-messaging-huawei-inbox-sdk:9.1.0](https://repo.maven.apache.org/maven2/com/infobip/infobip-mobile-messaging-huawei-inbox-sdk/9.1.0/infobip-mobile-messaging-huawei-inbox-sdk-9.1.0.aar) | `2e581a4197a46f4e3d96e657c43e5d44d30a59975f7294d04047daed34b9c2ac` |
| [infobip-rtc:2.5.41](https://repo.maven.apache.org/maven2/com/infobip/infobip-rtc/2.5.41/infobip-rtc-2.5.41.aar) | `42760d5e339d0fa421f41e9812e190e24acb2806884a998570d5abe05130c44a` |
| [google-webrtc:1.0.47976t](https://repo.maven.apache.org/maven2/com/infobip/google-webrtc/1.0.47976t/google-webrtc-1.0.47976t.aar) | `be7cdefb34d663ec817fdd8b42851d800ea7a7f90ba4e1bfcbc15f7e9e19f635` |

## Native compatibility and behavior boundaries

PASS (artifact inspection): shared API 16.1.0's full `WidgetInfo` constructor
adds `boolean useNewDesign` between `callsEnabled` and `themeNames`. The native
fixture supplies `false`; channel mapping and its expected map remain unchanged.
No Dart API or method/event payload changes were made.

The example explicitly enables `buildFeatures.resValues` because AGP 9 disables
that feature by default and the existing Huawei application-ID resource uses
`resValue`. The value and initialization behavior are unchanged.

Artifact signature comparison found no removed public top-level Core or Inbox
signatures. Chat removed widget API overloads (`loadWidget` and one
`send` overload); this plugin does not call those removed overloads. Its fragment
`send(MessagePayload)` remains available. RTC removed a WhatsApp endpoint
constructor unused by this outgoing application-call integration. Signature
inspection is supplemental evidence, not a substitute for native compilation.

PASS (artifact inspection): the upgraded RTC
`BitmapToVideoFrameConverter` and WebRTC `YuvConverter` produce identical
`javap -c -p` output to the previous versions. Existing horizontal compensation,
rotation, frame ownership, fresh output bitmaps, sink ownership and preview
behavior remain unchanged. The existing bytecode contract/native orientation
tests now pass in both debug and release (see results below). This does
not validate GLES execution, device capture, encoding or remote rendering.

All production Kotlin, Dart, manifest and ProGuard source is preserved. Existing
initialization/HMS/token/event, Chat/JWT/theme/attachment/lifecycle, Inbox,
call/session/token ownership, foreground service and cleanup behavior is retained
in plugin source; upstream runtime behavior still requires acceptance testing.

## Automated validation

Flutter resolution, analysis and Dart-test PASS rows are retained from the prior
upgrade phase. Android results were refreshed in this resumed run; Flutter/Dart
SDK identity was also reverified.

| Check | Status | Result |
| --- | --- | --- |
| Flutter 3.47.7 / Dart 3.13.5 identity | PASS | Verified installed FVM SDK |
| Root `flutter pub get` | PASS | Resolves package and example |
| Example `flutter pub get` | PASS | Resolves successfully |
| Root `flutter analyze` | PASS | No issues; also checked with original analyzer configuration restored |
| Root `flutter test` | PASS | 229 tests, same passing count as baseline |
| Example `flutter analyze` | PASS | No issues |
| Example `flutter test` | PASS | 42 tests |
| AGP/Gradle configuration (`help`) | PASS | Both modules configure with built-in Kotlin; compatibility checks remain enabled |
| Actual debug/release runtime dependency reports | PASS | Both resolve; no unresolved graph entries |
| Published SDK artifact graph | PASS | 144 resolved artifacts; no duplicate classes across 11,404 class names |
| Actual plugin debug runtime artifact scan | PASS | 150 artifacts; no duplicate classes across 12,530 class names |
| Android SDK Platform 37 | PASS | `platforms;android-37.0`, revision 2, API 37.0, extension 22; android.jar present and accepted by AGP |
| Kotlin debug/release compilation | PASS | Both plugin variants compiled; example Kotlin/Java also compiled during native tests/builds |
| Native debug and release unit tests | PASS | 323 debug + 323 release = 646 executions; 49 suites per variant; zero failures/errors/skips; example test tasks have NO-SOURCE |
| Example debug APK | PASS | Flutter assembleDebug completed; 179,067,756 bytes |
| Example release APK | PASS | Flutter assembleRelease completed; 74,133,667 bytes; unsigned under existing configuration |
| AGP debug/release duplicate-class tasks | PASS | Both completed in APK builds and were up-to-date in the explicit follow-up check |
| Debug/release merged manifests | PASS | Both generated; HMS service/app-ID metadata and RTC service declarations inspected; packaged release manifest also inspected |
| R8/ProGuard packaged release | PASS | R8 9.1.31, min API 26; fresh configuration/mapping/usage/seeds/resources; single DEX; no missing-rules file |
| Diff whitespace | PASS | `git diff --check` |
| Physical Huawei/backend testing | NOT RUN | Outside this validation stage |
| Flutter analysis / Dart tests in this resumed run | NOT RUN | Prior PASS results above retained; no Dart or production-code changes in this run |
| Release signing | NOT RUN | No signing configured or changed; read-only signature check confirms unsigned output |

Initial Android attempts failed on concurrent build locks, Flutter's Kotlin
minimum, AGP's disabled `resValues`, and absent release unit-test components.
Those setup issues were corrected during the original upgrade. After Platform
37.0 installation, all previously blocked Android validation above passed. No
failing tests or warnings were suppressed. Native reports, manifests, APKs and R8
outputs cited here were regenerated during the resumed validation.

The example sets `android.onlyEnableUnitTestForTheTestedBuildType=false` to retain
both debug and release test components under AGP 9's changed default. This expands
test coverage; it does not disable a compatibility check. See the
[AGP 9 behavior changes](https://developer.android.com/build/releases/agp-9-0-0-release-notes#behavior-changes).

### Dependency conflicts and packaging limits

PASS (resolved graph and class scan): only Huawei Core/Chat/Inbox, shared
API/resources, RTC Core and a single `com.infobip:google-webrtc:1.0.47976t` are
present among Infobip runtime modules. Standard Android Messaging Core and RTC UI
are absent. Firebase Messaging 22.0.0 and Google Play services remain legitimate
RTC transitives; their presence is not a second push transport or Google-free
certification. No duplicate Infobip, WebRTC or Kotlin classes were found.

Kotlin stdlib resolves to 2.2.20. Legacy stdlib-jdk7/jdk8 1.8.22 forwarding
artifacts remain in the graph without duplicate classes. Chat selects AndroidX
viewbinding 9.2.0, coroutines 1.11.0, constraintlayout 2.2.2, activity 1.11.0,
core 1.16.0 and lifecycle 2.9.3. No version was forced to suppress resolution
conflicts. Inspected runtime AAR metadata fits compileSdk 37 / AGP 9.1.1;
viewbinding's version number alone does not impose AGP 9.2.

The artifact scan examines class entries in resolved JARs and AAR embedded JARs,
excluding module descriptors and multi-release metadata. It is supplemental to
AGP's duplicate-class task and does not validate DEX, APK native libraries,
resource/manifest merging, runtime linkage, R8 or 16 KB loading.

### Remaining warnings

- Flutter 3.47.7 accepts Kotlin 2.2.20 but warns that support will soon be dropped,
  recommending >=2.3.20. Retain 2.2.20 as the smallest currently accepted compiler.
- `android.newDsl=false` / legacy DSL interfaces are deprecated for AGP 10;
  the current Flutter migration requires this setting.
- Settings repositories take precedence over repositories added by Flutter/plugin.
- Installed Android tooling reports SDK XML schema 4 while its reader understands
  up to 3. No system command-line tools were installed or upgraded.
- Initial compilation of Flutter's own Gradle plugin reported annotation-target,
  legacy Android API and unchecked-cast warnings. No global Flutter source edits.
- Kotlin reports a Chat listener parameter-name mismatch (`widgetView`) and
  deprecated LocalBroadcastManager; tests report existing unchecked casts and
  deprecated Android test APIs. All remain visible; no source edits were needed.
- Flutter's selected Java launcher emits restricted-native-access warnings. Native
  compilation/tests used JDK 21.0.11; the release Gradle daemon was explicitly
  selected with `GRADLE_OPTS=-Dorg.gradle.java.home=<JDK21>`. No global JDK setting
  was changed.
- SEC-01 remains **PARTIALLY MITIGATED**: release DEX confirms the identified
  AuthorizationUtils print/println call is removed, while RTC SocketHandler's
  PrintStream.printf call remains. Successful R8 does not prove sensitive-log absence.

### Resumed Android validation — 2026-10-16

**PASS for this automated Android validation stage.** No upgrade-related build or
test failures required repository code changes. Platform 37.0 is installed at
`/Users/apple/Library/Android/sdk/platforms/android-37.0`; its `package.xml`
identifies `platforms;android-37.0` and its 43,044,472-byte `android.jar` is present.
Platform 37.2 is also installed, but the existing compileSdk 37 selects 37.0.
Gradle 9.3.1 / AGP 9.1.1 accepted this platform without automatic SDK installation.

From `example/android`, with JDK 21 selected, these completed successfully:

```sh
./gradlew :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin
./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest :app:testDebugUnitTest :app:testReleaseUnitTest
./gradlew :app:dependencies --configuration debugRuntimeClasspath
./gradlew :app:dependencies --configuration releaseRuntimeClasspath
./gradlew :app:checkDebugDuplicateClasses :app:checkReleaseDuplicateClasses
./gradlew :app:processDebugMainManifest :app:processReleaseMainManifest
```

From `example`, the explicit Flutter 3.47.7 executable completed
`flutter build apk --debug` and `flutter build apk --release`. Native tests took
3m 38s, debug APK 120.8s and release APK 53.2s. Initial dependency downloads
accounted for part of this time. All 646 native test executions passed without
skips, including RTC orientation, screen-as-camera, lifecycle and bytecode
contract checks. Example native test tasks report NO-SOURCE; these add no tests.

Both runtime dependency trees contain no FAILED entries. Fresh external-artifact
scans found zero duplicate classes: 153 artifacts / 12,530 class names for each
app variant and 150 / 12,530 for each plugin variant. The scan excludes local
project artifacts; AGP's duplicate-class tasks and successful APK builds also
cover the app integration. A temporary inspection script initially hit AGP 9
project-variant ambiguity; selecting external components corrected the inspection
without changing project configuration. This was an evidence-script issue, not
an application build failure.

Huawei Core/Chat/Inbox resolve to 9.1.0; API/resources to 16.1.0; RTC to 2.5.41;
WebRTC to a single 1.0.47976t; Kotlin stdlib to 2.2.20. HMS push/opendevice select
6.7.0.300 with SDK-selected base 6.6.0.300 and network 6.0.2.300 modules. AndroidX
and Kotlin version requests converge through normal Gradle resolution, without
new forces or exclusions. Runtime AAR metadata requires at most compileSdk 37
and AGP 8.9.1, within the selected toolchain. No standard Infobip Android core or
RTC UI entered the production runtime. Firebase/GMS remain RTC transitives.
This establishes static/build compatibility, not Huawei runtime acceptance.

Both merged manifests retain minSdk 26 / targetSdk 36, the HMS messaging service,
non-exported RTC call (`microphone|camera`) and screen (`mediaProjection`)
services, notification receiver and permissions. There are no unresolved
placeholders. The release APK's binary manifest was decoded and inspected too.
No `agconnect-services.json` is present: app-ID metadata resolves to `appid=`.
Actual HMS registration requires host credentials and remains outside this stage.

R8 9.1.31 generated fresh configuration, mapping, seeds, usage and resource
reports under `example/build/app/outputs/mapping/release`. Optimization,
shrinking and obfuscation remain enabled; no `-dontoptimize`, `-dontshrink` or
`-dontobfuscate` was introduced. Existing narrow Huawei optional-dependency
consumer rules and the example's PrintStream print/println rule are included.
No missing-rules output or R8 missing-class failure occurred. APK inspection
confirms one release DEX and one WebRTC native library for each of arm64-v8a,
armeabi-v7a and x86_64. ZIP alignment with `zipalign -c -P 16 -v 4` passes;
this does not establish ELF page-size compatibility or device loading.
AuthorizationUtils DEX has no print/println invocation; RTC SocketHandler still
has a printf invocation. Existing SEC-01 limitations therefore remain open.

| Fresh APK | SHA-256 |
| --- | --- |
| `example/build/app/outputs/flutter-apk/app-debug.apk` | `5e1d995fded56be56137eb89cc3a5f759bb21bb9551b598cc8627de2108df4f6` |
| `example/build/app/outputs/flutter-apk/app-release.apk` | `335e2550237900f413a8e6ade47de4808cb4938f74a85ee7d161a80ee80033a3` |

The release APK is unsigned: `apksigner verify` reports missing
`META-INF/MANIFEST.MF`. Compilation, shrinking and packaging PASS; signing and
installability are not certified. No signing keys/configuration were added.
Temporary logs, artifact lists, class scan, APK identities and DEX inspections
are at `/tmp/infobip37-validation/` (local temporary evidence, not tracked).

Only this report changed in the resumed run. All 13 pre-existing modified tracked
files matched their starting SHA-256 hashes. Flutter automatically changed
`example/analysis_options.yaml`; that generated migration was restored to its
original content. Public Dart APIs, channels, production Kotlin, HMS behavior,
RTC screen sharing, ProGuard source, package version and dependency pins remain
as they were at the start of this run. No commit, push or publication occurred.

### Modified files

- `android/build.gradle.kts`: SDK upgrades, compileSdk 37, built-in Kotlin DSL.
- `android/gradle/wrapper/gradle-wrapper.properties`: Gradle 9.3.1.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/chat/ChatRuntimeEventMapperTest.kt`: new constructor argument.
- `example/android/settings.gradle.kts`: AGP 9.1.1 and retained compiler runtime selection.
- `example/android/app/build.gradle.kts`: compileSdk 37, built-in Kotlin, resValues.
- `example/android/gradle.properties`: built-in Kotlin, Flutter legacy DSL,
  explicit SDK provisioning, both native test variants.
- `example/android/gradle/wrapper/gradle-wrapper.properties`: Gradle 9.3.1.
- `pubspec.yaml`, `example/pubspec.yaml`: Flutter/Dart minimum constraints.
- `pubspec.lock`, `example/pubspec.lock`: resolution with preferred Flutter SDK;
  six Flutter-SDK-pinned test/framework transitives updated, not a broad upgrade.
- `README.md`, `CHANGELOG.md`, `doc/infobip-9-upgrade.md`: unreleased requirements,
  host migration, validation and manual acceptance.

Original analyzer configuration is preserved; Flutter's automatic exclusion
migration was reverted. No production Dart/Kotlin, manifest or ProGuard source
files changed.


## Physical Huawei acceptance checklist — NOT RUN

Use an appropriately signed host with matching AGConnect app/certificate and
Infobip Portal setup, working backend/JWT/token providers, a physical Huawei
phone and a second RTC endpoint. Record OS/HMS version, signing/build type and
results for both debug and release.

- [ ] Clean initialization, HMS registration, installation ID/token callback and restart.
- [ ] Push delivery foreground/background/terminated; token refresh and re-registration.
- [ ] Notification tap/action delivery, cold start, existing activity and exactly-once handling.
- [ ] Installation fetch/save, user fetch/save, personalization and cleanup/reinitialize.
- [ ] Native and embedded Chat, JWT success/expiry/failure/retry, contextual data and themes.
- [ ] Unread counts and runtime events; camera/gallery/file attachments and permissions.
- [ ] Chat detach/reattach, back navigation, background/resume, logout and cleanup failure retry.
- [ ] Inbox JWT authentication, fetch, topic/date filters, message mapping, seen/unseen and errors.
- [ ] RTC outgoing audio/video authentication, ringing/established/failure/end, hangup and duration.
- [ ] Mute/unmute, speaker/earpiece, camera enable/switch, Bluetooth connect/disconnect and routing.
- [ ] Local/remote video attach/detach, endpoint selection, orientation and no leaked SDK tracks/EGL.
- [ ] Screen consent/cancel, local/remote orientation and text readability, portrait/landscape,
      resize-triggered Stop, capture notification Stop, camera restoration and repeated sharing.
- [ ] Foreground call notification, return-to-call, hangup action, background/resume and permissions.
- [ ] Call end, rejected/failed calls, activity/engine detach and cleanup with no retained capture,
      microphone/camera use, foreground notification, stale callback or duplicate session.
- [ ] Signed release/R8 behavior and 16 KB native library acceptance on supported hardware.

## Release readiness

**PASS for the requested Android automated validation stage; no remaining
Android compilation, unit-test, APK, manifest, R8 or dependency blockers.**

**BLOCKED for production release approval** pending signed-host configuration,
Huawei/backend acceptance and resolution or explicit acceptance of existing
security findings. Physical-device testing was not required for this stage and
remains NOT RUN. These changes prepare a future major release; no runtime, security,
Google-free, signing or publication certification is claimed. Existing SEC-01
findings concern older artifacts and remain open; this upgrade is not evidence
that upstream sensitive logging is fixed. Reassess the new binaries separately.
