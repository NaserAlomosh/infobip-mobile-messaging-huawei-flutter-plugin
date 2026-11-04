# Infobip Huawei SDK 9.4.0 — controlled upgrade

Date: 2026-11-04. Recommendation: **READY FOR DEVICE VALIDATION**. No physical Huawei or backend runtime validation was performed. This is not release approval.

## Baseline and preservation

- Starting branch: `feature/infobip-huawei-sdk-9.4.0-upgrade`.
- Starting and final HEAD: `8d195fa45d857ec972dc9bd634e51d85f40c4f7c`.
- Dedicated implementation branch: `codex/infobip-huawei-sdk-9.4.0-controlled-upgrade`, created with `git switch -c` without resetting, stashing or discarding work.
- Initial tracked working tree was clean. The existing untracked `doc/SDK_9_4_0_COMPATIBILITY_AUDIT.md` was preserved byte-for-byte; SHA-256 `e80e201c7d6e70fb156a7d0525b718a57dd73904c821b509269d05d057b26535`.
- Plugin version remains 2.1.0. Java/Kotlin bytecode target 17, compileSdk 37, minSdk 26, Gradle 9.3.1, example AGP 9.1.1 and Kotlin 2.2.10 remain unchanged. Native tests use installed Java 21 because existing Android-36 Robolectric tests require it.

## Implementation

Only `android/build.gradle.kts` changes production build configuration:

| Artifact, group com.infobip | Before | After |
|---|---|---|
| infobip-mobile-messaging-huawei-sdk | 9.3.0@aar, transitive=true | 9.4.0@aar, transitive=true |
| infobip-mobile-messaging-huawei-inbox-sdk | 9.3.0 | 9.4.0 |
| infobip-mobile-messaging-huawei-chat-sdk | 9.3.0 | 9.4.0 |

Other direct versions remain: RTC 2.5.28; inspection-only RTC UI 15.1.0@aar; constraintlayout 2.1.4; localbroadcastmanager 1.1.0; fragment-ktx 1.8.9; JUnit 4.13.2; Mockito 5.20.0; ASM 9.8; Robolectric 4.16. RTC UI enablement remains rejected by the existing Huawei guard.

No compatibility source edits were needed. Public Dart APIs, channel methods/events/payloads, G-01 mapping, G-02 flag defaults/order, and pre-SDK email validation are unchanged. No new thread-routing API was introduced. `pubspec.yaml`, security findings and release metadata are unchanged.

Files changed/added by this task:

1. `android/build.gradle.kts` — three native SDK version selections.
2. `doc/SDK_9_4_0_UPGRADE_VALIDATION.md` — this implementation/validation record.

The compatibility audit remains a pre-existing untracked file, unchanged by this implementation. Example `flutter pub get` refreshed its path dependency's stale lockfile version from 2.0.0 to the existing 2.1.0; that task-generated incidental change was removed. Final lockfiles match the initial checkout.

## Independent verification of audit findings

The audit was read first, then checked against the official local source checkout and resolved Gradle-cache AARs:

- [9.3.0 → 9.4.0 official comparison](https://github.com/infobip/mobile-messaging-sdk-huawei/compare/9.3.0...9.4.0), tag SHAs `12bdabeec686e4bf8b3218d343fbf65ccb387699` and `1d96196d2f00225d42431a537f0555e7b675959e`.
- Tagged `OpenLivechatAction.java` and `InAppChatActivity.kt` confirm thread parsing/navigation changes; tagged `InAppChatImpl.java` confirms the existing default handler selects native Chat when an action parses.
- Recompiling the actual checkout and running its tests validated existing Kotlin calls against 9.4.0. No source-level break was found. This does not prove runtime/back-end compatibility.
- AAR manifests, `proguard.txt`, and AAR metadata were compared with 9.3.0 and are identical for Core, Inbox and Chat. Source-tag ProGuard changes must not be described as newly delivered artifact fixes.
- Release `dependencyInsight` confirms all three Huawei artifacts select 9.4.0. The audit's API/resources transitive bump 16.3.0 → 16.5.0 is recorded in published POMs; all three resolved AAR SHA-256 hashes match the previously downloaded Maven artifacts:

| Module | Resolved AAR SHA-256 |
|---|---|
| Core | `35bf4d03cee596d04fb96d75ed69e4450aed4e8b91dba74d452f0dbd26c46bbf` |
| Inbox | `2e581a4197a46f4e3d96e657c43e5d44d30a59975f7294d04047daed34b9c2ac` |
| Chat | `8bfbb2a2acf8615334312e902c3bab177aec2b854be1a1a5b35a9f41b7cd4008` |

## Exact validation commands and results

Working directory unless specified: `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`.

Flutter executable `F=/Users/apple/fvm/versions/3.44.4/bin/flutter`; Java directory `J=/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home`. The following commands are the executed commands with these two absolute paths abbreviated by F/J. Each output was redirected to the named log in `/private/tmp/fin-huawei-940-implementation/`.

| Directory | Command | Result | Log |
|---|---|---|---|
| root | `$F pub get --no-example` | PASS, exit 0 | pub-get-plugin.log |
| example | `$F pub get` | PASS, exit 0 | pub-get-example.log |
| root | `$F analyze --no-pub` | PASS, no issues | analyze.log |
| root | `$F test --no-pub` | PASS, 253 tests | dart-tests.log |
| example | `$F test --no-pub` | PASS, 49 tests | example-tests.log |
| example/android | `JAVA_HOME=$J ./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest --console=plain` | PASS, BUILD SUCCESSFUL in 39s; 433 Debug + 433 Release tests, zero failures/errors/skips | native-tests.log |
| example/android | `JAVA_HOME=$J ./gradlew :app:dependencyInsight --dependency infobip-mobile-messaging-huawei --configuration releaseRuntimeClasspath --console=plain` | PASS, all three SDK modules select 9.4.0 | dependency-insight.log |
| example | `JAVA_HOME=$J $F build apk --debug --no-pub` | PASS | build-debug.log |
| example | `JAVA_HOME=$J $F build apk --release --no-pub` | PASS, assembleRelease completed in 44.9s | build-release.log |
| root | `git diff --check` | PASS | terminal check |

Total existing automated tests: **1,168 passing** (253 + 49 + 433 + 433). Native XML results: `example/build/infobip_mobilemessaging_huawei/test-results/testDebugUnitTest/` and `testReleaseUnitTest/`. Existing G-01/G-02/privacy and RTC contract tests run as part of these suites; no new tests were added for the three version-only changes.

Build outputs: `example/build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk`; inspect the final build result below for Release status. These are build artifacts, not signed-install or production certification evidence. Do not assume Flutter's Release output is a production-signed APK.

Toolchain warnings include Flutter's future Kotlin >=2.2.20 recommendation and legacy Kotlin-plugin/AGP integration warnings. No toolchain migration is included in this upgrade.

## Behavioral review and required acceptance tests

No public Dart/channel breaking change or automated regression was detected. A user-visible navigation change exists:

- In 9.3.0, a Chat notification without an openLiveChat action generally follows the callback-activity path. In 9.4.0, a nonblank thread ID in a Chat message's custom payload creates a parsed action, causing the default handler to open native `InAppChatActivity`.
- In multithread mode, 9.4.0 shows the specified thread and sends any optional keyword to that thread. Without a thread ID, keyword creates a new thread; without keyword, the new-thread screen opens for an openLiveChat action. A Chat push with neither parseable action nor valid thread ID retains callback-activity fallback.
- Single-thread mode ignores thread ID and sends optional keyword to the current chat. Non-Chat messages do not gain Chat routing just by containing threadId; existing explicit openLiveChat actions still apply.
- Existing Flutter consumers expecting every push tap to land in a Flutter route can observe a different destination. No Flutter-only navigation override is supplied by this version update. Product acceptance is required.
- Widget arguments now use JSON string serialization instead of raw single-quoted interpolation. Verify quotes, backslashes, Unicode, long IDs and optional/null inputs with the live widget. Existing invalid/foreign/stale thread handling is not established by local tests.

Physical Huawei/backend checklist (all outstanding):

- [ ] Register an HMS device; send ordinary and Chat pushes; verify permission denied/granted, token refresh/re-registration and delivery.
- [ ] Tap thread-bearing pushes in foreground, background, killed process and lock screen; confirm the correct native screen/thread and expected back stack to Flutter.
- [ ] Tap multiple notifications for distinct threads, including while Chat is already open; confirm newest target, no stale target reuse and acceptable unread/seen state.
- [ ] Cover valid/missing/blank/null/malformed/stale/foreign thread IDs and non-Chat payloads with threadId; reject unauthorized access server-side and confirm safe visible failures.
- [ ] Exercise multithread and single-thread modes, keyword present/absent, explicit openLiveChat actions, and callback fallback.
- [ ] Check native theme/back navigation, embedded Chat coexistence, attachments, special-character IDs and new language codes rw-RW/lg-UG/sw-KE/sw-TZ.
- [ ] Verify Inbox fetch/seen readback and JWT expiry/error behavior against the backend.
- [ ] Verify G-01 omission/set/clear and custom-attribute deletion by backend readback; empty patch with pending data; offline retry/restart. Empty patch is not guaranteed to be a no-op.
- [ ] Verify G-02 false/omitted defaults, both flags independently/together, forceDepersonalize and legacy APIs; backend lead/primary-device state.
- [ ] Verify 255/256 UTF-16 email boundaries, value-free -10 errors and absence of SDK calls for rejected inputs; test existing pending data separately.
- [ ] Exercise outgoing RTC audio/video, permissions, controls, reconnect, token renewal and screen sharing. Do not infer new HMS background incoming-call support.
- [ ] Perform a signed 2.1.0 → candidate upgrade preserving registration/user queue/Chat state; assess rollback with a controlled test plan.
- [ ] Inspect signed shipping artifact and capture runtime logs with synthetic credentials/user data. Complete explicit SEC-01 release disposition and hosted CI on the eventual implementation commit.

## Security review

**SEC-01 remains PARTIALLY MITIGATED and unresolved.** No existing security classification or mitigation was edited.

The actual resolved 9.4.0 Core AAR was opened, its classes.jar extracted, and this command executed:

```sh
javap -c -classpath /private/tmp/fin-huawei-940-implementation/resolved-core-classes.jar org.infobip.mobile.messaging.util.AuthorizationUtils
```

`getAuthorizationHeader` still contains the static `header is` string, appends the header, and calls `java/io/PrintStream.println`. Saved bytecode: `/private/tmp/fin-huawei-940-implementation/authorization-bytecode.txt`. This was static inspection; no real token or credential was printed. [Tagged source](https://github.com/infobip/mobile-messaging-sdk-huawei/blob/9.4.0/infobip-mobile-messaging-huawei-sdk/src/main/java/org/infobip/mobile/messaging/util/AuthorizationUtils.java) corroborates it.

The example's existing Release-only print/println suppression remains unchanged and is not exported as plugin consumer policy. It requires effective R8 optimization and host opt-in. Release build success alone does not verify sensitive-log absence in the shipping APK. Existing RTC 2.5.28 signaling/printf and possible TURN-credential exposure remain; the print/println rule does not cover printf. Default Chat notification logging can include message body, and action stringification includes thread ID. The pre-SDK email guard is unchanged and does not sanitize SDK-managed pending data or every logging path.

## Final build result and recommendation

**READY FOR DEVICE VALIDATION.** Dependency resolution, static analysis, all existing automated tests, both native test variants and both Flutter APK builds passed. Release assembly completed in 44.9 seconds and produced an 88.0 MB Flutter APK. No production compatibility fix beyond the three dependency selections was needed. There is no local build/test blocker; device/backend behavior and signed-artifact security clearance remain outstanding.

Final HEAD remains the baseline SHA on the dedicated branch. Existing audit contents are unchanged. Only the dependency file and this report were changed/added by this task. No commit, push, merge, tag or publication was performed.

app-debug.apk SHA-256: `331d97e2bf6e32b6f198f8237d43b8d4a6b811866bf100824115fa16b42478b2`.

app-release.apk SHA-256: `333c5a30c939084a299848c4f11bb1df06ccd0f238d0526558329f2ad2017001`.
