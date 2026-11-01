# Huawei SDK 9.3.0 migration — Phase 2

**Status: PASS for automated Android build validation only. Awaiting owner review.**

Validated 2026-11-01. The documented temporary AGP namespace exception resolves
both application manifest failures. Debug and optimized Release APKs build, all
1,107 existing tests pass, and packaged 64-bit ELF and APK ZIP alignment checks
pass. **SEC-01 remains unresolved. This is not production or device acceptance.**
The Release APK is unsigned; installation requires owner-controlled signing.

## A. Repository baseline and root cause

- Workspace: `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`.
- Origin: `https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin.git`.
  This configured repository name differs from the task's `infobip-` prefixed
  name; the required branch and exact Phase 1 implementation commit both match.
- Branch: `feature/infobip-huawei-sdk-9.3.0-upgrade`.
- Initial and final HEAD: `ad79cec72b74dc07ab33d7619b894f119b2048d6`.
- Initial `git status --short --untracked-files=all`: empty.
- Phase 1 report and committed implementation were reviewed before editing.
  Gradle settings, wrappers, app/plugin build files, properties, manifests and
  existing ProGuard/consumer rules were inspected. No AGENTS.md was found at the
  repository root or its ancestor directories.

The unchanged configuration reproduced **both** failures with exit 1:
`:app:processDebugMainManifest` and `:app:processReleaseMainManifest`.
The exact diagnostic, identical in each variant, is:

```text
Namespace 'com.infobip' is used in multiple modules and/or libraries: com.infobip:infobip-rtc:2.5.28, com.infobip:google-webrtc:1.0.45036. Please ensure that all modules and libraries have a unique namespace. For more information, See https://developer.android.com/studio/build/configure-app-module#set-namespace
Validation failed, exiting
```

Full task output and stack traces are retained in
`/tmp/infobip-huawei-phase2/baseline-manifests.log`. No other manifest error was
reported. Both resolved runtime dependency graphs were freshly captured, not
inferred from the Phase 1 report. They retain Huawei Core/Inbox/Chat 9.3.0,
API/resources 16.3.0, RTC 2.5.28 and WebRTC 1.0.45036; no resolution failure or
new vendor version was introduced.

Direct inspection of the published, cached AARs confirms:

| Artifact | Manifest | Java classes in embedded JARs |
| --- | --- | --- |
| `com.infobip:infobip-rtc:2.5.28` | `package="com.infobip"`; minSdk 21 and eight permissions; no application/components/metadata | 456 |
| `com.infobip:google-webrtc:1.0.45036` | Only `<manifest ... package="com.infobip"/>` | 391 |

The two Java class sets have **zero intersection**. Neither AAR declares a provider,
service, receiver, activity, authority or metadata entry, so there is no such
collision between them to hide. WebRTC declares no permissions. The full app
classpath duplicate checks also pass, including forced execution after the fix.

AAR SHA-256 provenance:

```text
infobip-rtc-2.5.28.aar
9303984b90dd14cb31458d94d35b26f5b494ae42017e3174ae135030c01314a4
google-webrtc-1.0.45036.aar
dcf8da69a1fbf3623eed6e01a8a213ebdaf44f5919a6f565ecd8966542dea07c
```

[Official AGP 9 release notes](https://developer.android.com/build/releases/agp-9-0-0-release-notes)
document `android.uniquePackageNames` changing from false to true, enforcing
separate library package names, and permit disabling it during migration when
unique names cannot yet be provided. The installed AGP 9.1.1 accepts the opt-out:
with only that build property changed, the same namespace diagnostic becomes a
warning and both app manifests succeed. This establishes namespace validation as
the blocker, independently of duplicate classes or component merging.

A final control run explicitly restored `-Pandroid.uniquePackageNames=true` and
again failed both manifests with the same error; `--info --stacktrace` output is
in `namespace-enforcement-control.log`. A subsequent default-property run passed
both tasks (`final-manifests.log`). No file was toggled for this control.

## B. Narrow fix and consumer impact

Changed files:

1. `example/android/gradle.properties`: added only the following exception/comment;
   existing AGP 9 transition properties remain unchanged.
2. `README.md`: host migration instructions, temporary-property limitations and
   link to this report.
3. `doc/huawei-9.3.0-phase2-report.md`: this validation record.

```properties
# Temporary AGP 9 exception: RTC 2.5.28 and WebRTC 1.0.45036 both declare com.infobip.
# Remove when vendor artifacts provide unique namespaces; see the Phase 2 report.
android.uniquePackageNames=false
```

This is an acceptable **temporary build compatibility exception for this inspected
graph**, not a vendor namespace correction. It restores AGP's earlier namespace
validation behavior across the host build. Duplicate-class checks and ordinary
manifest conflict validation remain enabled. Other host dependencies still require
review: the opt-out is project-wide, not restricted to these two coordinates.
No AAR was modified/repacked, no dependency/toolchain version changed, and no new
keep/dontwarn/logging rule was added.

**Every consuming host using AGP 9's default uniqueness enforcement with these
retained RTC/WebRTC artifacts needs the setting in its own
`<flutter-app>/android/gradle.properties`.** If the host already disables this
check, another entry is unnecessary. Older AGP configurations that do not enforce
uniqueness do not need this opt-out; they are not newly certified by this run.
The plugin's `android/gradle.properties` does **not** configure downstream hosts
and was deliberately left unchanged. The example's property only configures the
example host.

The exception is temporary because the vendor artifacts should provide distinct
namespaces. Remove it after an independently approved vendor correction/upgrade,
then rerun host manifests, duplicate classes, optimized APK checks and runtime
acceptance with default uniqueness enforcement. No removal release/date is assumed;
continued availability in future AGP versions is not guaranteed. This phase does
not authorize RTC/WebRTC upgrades. The existing Flutter 3.44.4 legacy-KGP migration
properties are still required for the selected route. Public Flutter APIs and
package version 1.1.0 are unchanged.

## C. Toolchain, commands and validation matrix

| Component | Verified selection |
| --- | --- |
| Flutter / Dart | 3.44.4 (`ad70ec4617`) / 3.12.2 |
| Flutter executable | `/Users/apple/fvm/versions/3.44.4/bin/flutter` |
| AGP / Gradle wrapper | 9.1.1 / 9.3.1 |
| Application/plugin KGP | Legacy 2.2.10; built-in Kotlin disabled |
| Java runtime | Homebrew JDK 21.0.11 |
| Java/Kotlin bytecode | 17 / 17, unchanged |
| compileSdk / minSdk / targetSdk | 37 / 26 / 36, unchanged |
| APK alignment tool | Android Build Tools 37.0.0 `zipalign` |
| ELF header tool | NDK 28.2.13676358 `llvm-readelf -Wl` |
| R8 output compiler | 9.1.31 |

Local evidence directory: `/tmp/infobip-huawei-phase2/` (temporary, not committed).
An initial successful Debug/Release pair selected JDK 17 because Flutter's saved
`jdk-dir` takes precedence over `JAVA_HOME`. Those logs are explicitly named
`flutter-*-jdk17-initial.log` and are **not** the target-toolchain acceptance.
Both builds were repeated with an isolated Flutter config selecting JDK 21;
`flutter-doctor-jdk21.log` and verbose build logs verify the selected Java binary.
The user's saved Flutter configuration was not changed. Native tests and a forced
R8 run independently print the actual Gradle JVM as JDK 21.

Commands, from repository root unless a directory is specified:

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:/Users/apple/fvm/versions/3.44.4/bin:$PATH"
# Isolated settings file contains only {"jdk-dir": "<JAVA_HOME above>"}.
export XDG_CONFIG_HOME=/tmp/infobip-huawei-phase2/flutter-config
FLUTTER=/Users/apple/fvm/versions/3.44.4/bin/flutter
"$FLUTTER" --no-version-check --version
"$FLUTTER" --no-version-check doctor -v
(cd example/android && ./gradlew --version)
# Before editing; exit 1, both manifest failures reproduced:
(cd example/android && ./gradlew :app:processDebugMainManifest :app:processReleaseMainManifest :app:checkDebugDuplicateClasses :app:checkReleaseDuplicateClasses --continue --offline --console=plain --stacktrace)
(cd example/android && ./gradlew :app:dependencies --configuration debugRuntimeClasspath --offline --console=plain)
(cd example/android && ./gradlew :app:dependencies --configuration releaseRuntimeClasspath --offline --console=plain)
# After editing; exit 0:
(cd example/android && ./gradlew :app:processDebugMainManifest :app:processReleaseMainManifest :app:checkDebugDuplicateClasses :app:checkReleaseDuplicateClasses --offline --console=plain --info)
(cd example && "$FLUTTER" --no-version-check build apk --debug -v)
(cd example && "$FLUTTER" --no-version-check build apk --release -v)
(cd example/android && ./gradlew :app:processDebugMainManifest :app:processReleaseMainManifest :app:checkDebugDuplicateClasses :app:checkReleaseDuplicateClasses :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest :app:minifyReleaseWithR8 --init-script /tmp/infobip-huawei-phase2/force-validation.gradle --offline --console=plain --info)
"$FLUTTER" --no-version-check test --reporter expanded
"$FLUTTER" --no-version-check analyze
(cd example && "$FLUTTER" --no-version-check test --reporter expanded)
# Final packaging after forced R8 output; exit 0:
(cd example && "$FLUTTER" --no-version-check build apk --release -v)
python3 /tmp/infobip-huawei-phase2/check-apks.py
python3 /tmp/infobip-huawei-phase2/inspect-dex.py
# Causality control (exit 1), followed by the fixed default (exit 0):
(cd example/android && ./gradlew :app:processDebugMainManifest :app:processReleaseMainManifest -Pandroid.uniquePackageNames=true --continue --offline --console=plain --info --stacktrace)
(cd example/android && ./gradlew :app:processDebugMainManifest :app:processReleaseMainManifest --offline --console=plain --info)
git diff --check
```

The temporary init script sets `outputs.upToDateWhen { false }` on both Test tasks,
Debug/Release app main manifest and duplicate-class tasks, and `minifyReleaseWithR8`.
It prints Release minify/shrink/namespace/compileSdk and `java.home`. It changes no
inputs, dependencies, assertions, test selection or compatibility flags. An initial
inspection-script error assumed the Flutter included build also contained `:app`;
that attempt stopped during configuration before tests. The script was corrected
to use `findProject(':app')` and skip inspection for included builds without it.
The complete rerun succeeded (`native-r8-validation.log`, 1m 11s). This harness
failure required no repository change. No test failed, was disabled or skipped.

`--no-version-check` avoids Flutter's unrelated upstream version check, as in
Phase 1. No `--android-skip-build-dependency-validation` was used. Flutter still
warns about future legacy-KGP removal/upcoming Kotlin 2.2.20 minimum; the selected
KGP remains 2.2.10. Gradle deprecation and unmatched vendor ProGuard-rule infos
remain visible; they do not prevent the target builds. No warning was hidden.

| Validation | Status | Result / evidence |
| --- | --- | --- |
| Baseline app manifest reproduction | PASS | Both fail specifically on RTC/WebRTC namespace validation before fix |
| Resolved Debug/Release dependency graphs | PASS | `debug-dependencies.log`, `release-dependencies.log`; pinned vendor closure |
| Debug/Release app manifest processing | PASS | Both freshly executed after fix; merged and packaged XML inspected |
| Debug/Release duplicate classes | PASS | Both forced to execute; no duplicate classes |
| Debug APK | PASS | JDK 21 build, `flutter-debug.log` |
| Release APK | PASS | JDK 21 build and final packaging, `flutter-release-final.log` |
| R8 | PASS | Forced JDK 21 execution; mapping reports R8 9.1.31; no additional rules required |
| Resource shrinking | PASS | `shrink=true`; R8 shrunk resource archive/report and binary conversion/package output |
| SDK/JWT/Chat/Inbox/RTC static DEX retention | PASS | 17 selected classes disassembled successfully, `dex-retention.json`; runtime reflection NOT_RUN |
| Native library packaging | PASS | Debug 7 / Release 9 libraries; three Flutter target ABIs; CRC and unique ZIP names pass |
| ARM64/x86_64 16 KB ELF LOAD alignment | PASS | Every packaged 64-bit library has >=16384 alignment and congruent file/virtual offsets |
| Debug/Release APK ZIP alignment | PASS | Build Tools 37.0.0 `zipalign -v -c -P 16 4`, both exit 0 |
| Native Debug tests | PASS | 410 / 52 suites; zero failures, errors or skips |
| Native Release tests | PASS | 410 / 52 suites; zero failures, errors or skips |
| Plugin Dart tests | PASS | 238, `plugin-test.log` |
| Example Dart tests | PASS | 49, `example-test.log` |
| Flutter analyzer | PASS | No issues, `analyze.log` |
| Security logging inspection | PASS | Inspection completed; MM Release println removed, RTC printf retained; SEC-01 OPEN |
| Release signing verification | FAIL | Existing unsigned configuration: `apksigner verify` exit 1, missing `META-INF/MANIFEST.MF`; signing not configured/changed |
| Physical Huawei/HMS/backend/minified runtime | NOT_RUN | No device execution or real credentials |
| Physical 16 KB page-size runtime | NOT_RUN | ELF/ZIP checks do not establish device runtime behavior |
| Diff / API / package version preservation | PASS | Only the three scoped files changed; no Dart/native source, tests or pubspec changes |

Unsigned output is an existing packaging limitation, not an automated build failure
or an attempt at signed-release acceptance. Signing is required before installing
this Release candidate. No key or signing configuration was added.

## D. Merged manifests, R8 and APK evidence

### Manifest review beyond task exit codes

Fresh merger decision and blame reports are retained alongside pre-packaging
merged XML and decoded **actual APK** manifests. Each variant contains 45
components: 8 activities, 14 services, 17 receivers and 6 providers. Neither has
duplicate component keys, provider authorities, permission declarations or
uses-permission declarations. The same permission appearing once as a declaration
and once as a request is normal and was not counted as a duplicate.

Application ID remains `com.infobip.mobilemessaging.huawei.example`; app namespace
is the same and plugin namespace remains `com.infobip.mobilemessaging.huawei`.
Both packaged manifests preserve minSdk 26 and targetSdk 36. All components with
intent filters have explicit `exported` attributes. Chat activities without
filters retain their default non-exported behavior. No attribute override or
manifest component removal was introduced by this phase.

All six authorities use the example application ID as prefix, with suffixes:
`fileprovider`, `firebaseinitprovider`, `androidx-startup`, `huawei.push.provider`,
`aaidinitprovider`, and `AGCInitializeProvider`. The Chat file provider is
non-exported and grants URI permissions; Huawei PushProvider remains exported
with its vendor read/write permission gates. HMS push receivers remain protected
by the host PROCESS_PUSH_MSG permission. The exported HMS message service is a
retained vendor declaration; it is not newly introduced or certified as secure by
this namespace fix. Other exported framework/FCM entries retain their existing
DUMP/BIND_JOB_SERVICE/C2DM permission gates.

`MobileMessagingHmsService` and HMS Push services/receivers/providers are present.
Plugin RTC call and screen services remain non-exported, with respective
`microphone|camera` and `mediaProjection` foreground-service types. Their required
foreground-service permissions and POST_NOTIFICATIONS remain present, together
with camera/audio/Bluetooth/network permissions. Existing vendor storage, phone
state and boot permissions remain; no new permission policy was introduced.

FirebaseMessagingService, FirebaseInstanceIdReceiver, FirebaseInitProvider,
ComponentDiscoveryService, GMS version metadata and Google transport entries are
present and trace through **retained RTC 2.5.28 → Firebase Messaging 22.0.0** in the
graph/merger reports. They are expected transitives, not an accidental addition of
standard Mobile Messaging Firebase core. Google-free operation and background
incoming RTC delivery are not certified. No unexpected Firebase/GMS source was
found in the inspected graphs/manifests.

### Effective R8 and reflection-sensitive retention

The evaluated Release DSL reports `minify=true` and `shrink=true`; Flutter 3.44.4
sets these and includes optimized Android rules, Flutter rules and the existing
example ProGuard file. `:app:minifyReleaseWithR8` actually executed under JDK 21.
The final package uses its optimized DEX and resource outputs, not native unit-test
bytecode. Evidence is in `example/build/app/outputs/mapping/release/`:
`configuration.txt`, `mapping.txt`, `seeds.txt`, `usage.txt`, and `resources.txt`.
The linked resource archive is 1,439,053 bytes; R8's shrunk proto archive is 929,087
bytes, followed by `convertShrunkResourcesToBinaryRelease` and APK packaging.
The subsequent `optimizeReleaseResources` output's `resources.arsc` matches the
actual Release APK byte-for-byte. The earlier binary conversion output differs
because this final AAPT resource optimization still runs before packaging.

The effective configuration includes the unchanged plugin's exact optional
Huawei/BC dontwarn entries and published vendor rules. Existing vendor rules
preserve MM public APIs/models, Chat APIs/callbacks and serialized widget fields,
Inbox models/mappers, HMS classes, WebRTC JNI classes and RTC APIs. Gson generic
signature/annotation rules and the WorkDatabase generated-constructor rule are
present. No new broad keep/dontwarn or constructor workaround was needed.

Using final R8 mapping plus APK Analyzer DEX disassembly verified these selected
classes and their members in the actual Release APK:

- `JwtSupplier` and `JwtProvider$JwtCallback` (one and two callback methods).
- `Installation`, `Message`, `User`, `mobileapi.common.ResultWrapper`.
- Chat `LivechatWidgetThread`, Inbox `Inbox` and `InboxMessage`.
- `WorkDatabase_Impl` including its constructor and `MobileMessagingHmsService`.
- RTC `InfobipRTC`, WebRTC `PeerConnection`, and plugin ChatJwtBridge / HuaweiRtcManager
  (the latter two correctly located through obfuscated names `kf` / `jb0`).
- AuthorizationUtils and the obfuscated RTC SocketHandler, inspected below.

Static retention and constructor/member inspection support build compatibility;
they do **not** prove every reflective call, Gson data shape, persisted Room state,
JNI invocation, JWT callback, Chat/Inbox backend response or minified runtime path.
Those remain Phase 3 acceptance work. The existing native optional-dependency tests
also passed against the resolved artifacts. No keep rule was changed based on
speculation or a successful build alone.

### APKs and native libraries

| Variant | Artifact | Bytes | SHA-256 |
| --- | --- | --- | --- |
| Debug | `example/build/app/outputs/flutter-apk/app-debug.apk` | 189406003 | `0428e5ffaab5e64401bf54c70db7fd3a9ecb0c9f9234957f72791b2aea26c0fa` |
| Release | `example/build/app/outputs/flutter-apk/app-release.apk` | 88011460 | `811263d25a6e83bd7251df8a90da70cb8e53635fdaf479c5bba542a6c4997747` |

Standard Gradle outputs also reside under `example/build/app/outputs/apk/debug/`
and `release/`. No output APK was manually repacked or aligned in place. ZIP CRCs
and unique entry names pass. All native entries are uncompressed.

| Variant / ABI | Packaged native libraries | ELF LOAD alignment |
| --- | --- | --- |
| Debug ARM64 | libflutter.so, libjingle_peerconnection_so.so, libVkLayer_khronos_validation.so | 65536 / 16384 / 65536 |
| Debug ARMv7 | libflutter.so, libjingle_peerconnection_so.so | 65536 / 4096 |
| Debug x86_64 | libflutter.so, libjingle_peerconnection_so.so | 65536 / 16384 |
| Release ARM64 | libapp.so, libflutter.so, libjingle_peerconnection_so.so | 65536 / 65536 / 16384 |
| Release ARMv7 | libapp.so, libflutter.so, libjingle_peerconnection_so.so | 16384 / 65536 / 4096 |
| Release x86_64 | libapp.so, libflutter.so, libjingle_peerconnection_so.so | 65536 / 65536 / 16384 |

Every 64-bit LOAD segment has suitable alignment and congruent file/virtual
addresses modulo 16384. ARMv7 WebRTC's 4096 alignment is recorded separately;
32-bit ABI support is not a 16 KB device-runtime claim. Vendor x86 (32-bit) is not
packaged because the Flutter APK targets ARMv7/ARM64/x86_64. The validation layer
is Flutter Debug tooling and is absent from Release. WebRTC library SHA-256 values
match the corresponding original AAR entries in both APKs.

[Android's 16 KB verification guidance](https://developer.android.com/guide/practices/page-sizes)
separates ELF alignment from APK ZIP alignment. Both were checked on the packaged
libraries, using `llvm-readelf -Wl` plus parsed ELF program headers, and:

```sh
SDK=/Users/apple/Library/Android/sdk
"$SDK/build-tools/37.0.0/zipalign" -v -c -P 16 4 example/build/app/outputs/flutter-apk/app-debug.apk
"$SDK/build-tools/37.0.0/zipalign" -v -c -P 16 4 example/build/app/outputs/flutter-apk/app-release.apk
```

Both report `Verification successful`. Inventory, per-library hashes/program
headers and per-APK alignment output are in `apk-validation.json`, `debug/lib/`,
`release/lib/`, `debug-zipalign.log` and `release-zipalign.log` under the evidence
directory. No physical 16 KB device was exercised.

## E. Security and updated R01–R12 dispositions

**SEC-01 remains OPEN.** No production tokens or real credentials were used.
Fresh `javap -p -c` inspection of the published 9.3.0 MM classes confirms the
AuthorizationUtils stdout println; retained RTC SocketHandler directly prints
received signaling with printf. The upstream artifacts remain unchanged.

Actual final APK DEX inspection distinguishes:

| Path | Observed result | Limitation |
| --- | --- | --- |
| MM authorization stdout, Debug | Header prefix and one PrintStream.println retained | Debug exposure remains |
| MM authorization stdout, example Release | Zero print/println invocations and no logging prefix; authorization method and Bearer/App paths remain | Removed by optimization with the **existing** example-only rule; not automatic consumer protection |
| RTC signaling stdout, Release | SocketHandler maps to `oa1`; DEX contains `[PORTUNUS] Received message: %s%n` and one PrintStream.printf | Still present; logger OFF does not establish suppression |
| Runtime logging | NOT_RUN | Static presence/removal is not execution evidence or absence of all sensitive logs |

The pre-existing example PrintStream print/println assumption is unchanged and
applies across that application when optimized; it does not cover printf or other
logging APIs and is not exported by plugin consumer rules. No global stdout
suppression, new security workaround, token handling or feature change was added.
Security artifact inspection passed as an inspection; security remediation did
not pass. Vendor remediation and safe synthetic device verification remain needed.

| Risk | Phase 2 disposition |
| --- | --- |
| R01 compilation/dependency closure | PASS for automated scope: graphs, manifests, duplicate checks and both APKs pass with the documented exception; vendor namespace defect remains |
| R02 Flutter/AGP/Kotlin matrix | PASS only for measured 3.44.4/3.12.2, AGP 9.1.1/Gradle 9.3.1, legacy KGP 2.2.10, JDK 21; future transition warnings remain |
| R03 MM authorization stdout | OPEN: upstream/Debug exposure; removal proven only in this example optimized Release using its existing rule; device behavior NOT_RUN |
| R04 RTC signaling printf | OPEN: retained in actual Release DEX; no runtime mitigation proof |
| R05 Chat new design/PDF/attachments/lifecycle | OPEN: tests/static retention pass; physical Huawei/backend UI acceptance NOT_RUN |
| R06 tokens/TTL/identity/routing/conversation/error text | OPEN: callbacks/models statically retained and regression tests pass; backend/JWT runtime acceptance NOT_RUN |
| R07 HMS token/notification/restart delivery | OPEN: manifest/retention checks pass; physical HMS delivery NOT_RUN |
| R08 incoming RTC transport/wake-up | OPEN: experimental/foreground-only boundary unchanged; background support not certified |
| R09 screen-as-camera/rendering/FGS/teardown | OPEN: local tests and service declarations pass; permissions/media/device behavior NOT_RUN |
| R10 minification/signing/native packaging/16 KB | PARTIAL overall: R8/resource shrinking/packaging/ELF/ZIP checks PASS; unsigned Release signature FAIL as expected; signing/install/physical 16 KB checks remain |
| R11 persisted-state upgrade/downgrade/rollback | OPEN: installation/state-transition testing NOT_RUN |
| R12 older Flutter/Dart support | Narrowed contract remains 3.44.4/3.12.2; this host now passes automated APK acceptance; older versions and built-in-Kotlin alternatives NOT_RUN |

## F. Phase 3 readiness

**Ready to proceed to owner review and Phase 3 physical Huawei validation preparation;
no remaining automated Android build blocker for the measured configuration.**
The Release candidate must first be signed through the owner's existing process
before installation. Signing was not performed in this phase. SEC-01 stays open
and requires explicit follow-up; automated PASS is not security acceptance.

Phase 3 must exercise the actual signed/minified candidate using synthetic data:
HMS registration and push after restart; JWT refresh/error and identity flows;
Chat/Inbox including serialized models, attachments/PDF and lifecycle; RTC audio,
video, routing, screen sharing and FGS teardown; persisted-state migration and
rollback; and 16 KB runtime where applicable. Foreground-only incoming RTC limits
remain. Do not infer physical Huawei, backend, signing, release or production
readiness from these automated results. Stop here for owner review.

## G. Final Git status and preservation

Branch and HEAD remain as recorded in section A. Expected final status:

```text
 M README.md
 M example/android/gradle.properties
?? doc/huawei-9.3.0-phase2-report.md
```

Initial checkout was clean; there was no existing tracked/untracked work to move
or overwrite. All Phase 1 committed changes and historical audit/security reports
were preserved. The Phase 1 report SHA-256 remains
`89cde6e3c194f23852b209dcee9d83864062b2f09d532fe82960b3014b458193`.
Only ignored build/test outputs and temporary evidence/configuration were generated.
No reset, clean, stash, branch switch, commit, push, merge, publication, release,
package version change, public Dart API change, vendor upgrade/repackaging or
minSdk/targetSdk change occurred. `git diff --check` passes.
