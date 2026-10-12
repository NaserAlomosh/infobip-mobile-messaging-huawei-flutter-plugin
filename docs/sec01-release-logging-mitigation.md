# SEC-01 — Release authorization-header logging mitigation

Verified 2026-10-12 on `release/rtc-production-certification`. Initial working tree
was clean; no branch switch, commit, push, publication, dependency upgrade, SDK
binary change, signing change, or Flutter/Kotlin runtime source change was made.

**Status: PARTIALLY MITIGATED.** The example Release APK removes the identified
Infobip Huawei Mobile Messaging 8.14.0 authorization-header println. Consumer apps
must opt in to Release optimization/rules and verify their own shipping artifact.
The upstream SDK is unchanged, and Debug retains the logging defect.

## Configuration and exact rule

Installed Flutter 3.35.7's `FlutterPlugin.kt:270–280` already configures Release
minification and resource shrinking and includes `proguard-android-optimize.txt`,
Flutter rules, and `example/android/app/proguard-rules.pro`. No duplicate Gradle
configuration was necessary. AGP remains 8.13.0; output mapping identifies R8
8.13.6 and min API 26. The merged Release configuration contains this added rule:

```proguard
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
```

The candidate's `public void printf(...)` was omitted: `PrintStream.printf`
returns `PrintStream` and is not the identified logging call. The installed R8
accepted the print/println rule and removed the call. No `-dontoptimize` appears
in the merged Release configuration. Existing SDK keep rules and plugin optional
dependency consumer rules remain unchanged; they did not prevent this removal.

`android/build.gradle.kts` already exports `consumer-rules.pro` in `defaultConfig`.
It does not export print suppression. Such consumer rules would also participate
in minified Debug builds. Follow the dedicated Release-only host opt-in in
[SECURITY.md](../SECURITY.md#consumer-application-opt-in); minification alone is
insufficient without the rule and effective optimization.

This app-wide rule can suppress stderr and functional PrintStream file/stream
output too. Hosts must assess that tradeoff before opting in. `printf`, `write`,
other log APIs and Dart/native output are outside this rule. Argument evaluation
and a null-receiver check may remain even after the output call is removed.
See Android's [assumption-rule guidance](https://developer.android.com/topic/performance/app-optimization/additional-rule-types)
and [library optimization guidance](https://developer.android.com/topic/performance/app-optimization/library-optimization).

## Actual APK evidence

Build command, from `example/`:

```sh
flutter build apk --release --target lib/main_local.dart --no-pub
```

Result: successful Release build, 85.9 MB. Optimized artifact:
`example/build/app/outputs/flutter-apk/app-release.apk`.
SHA-256: `dfc6d923f446ae93392039b223d4287302b50ad661393f69436ca642678f5a30`.
Mapping and merged rules: `example/build/app/outputs/mapping/release/`.
R8 8.13.6 compiled this artifact; its configuration contains the new rule.

APK Analyzer parsed the application ID/version successfully. ZIP CRC integrity,
the single DEX file's header length and SHA-1 signature passed. **The preserved
Release configuration produces an unsigned APK:** `apksigner verify` reports
missing `META-INF/MANIFEST.MF`. This is a structurally valid optimized build
artifact, not a signed, installable release package. No keys were added.

Read-only inspection command:

```sh
apkanalyzer dex code \
  --class org.infobip.mobile.messaging.util.AuthorizationUtils \
  example/build/app/outputs/flutter-apk/app-release.apk
```

The pre-change Release method contained `System.out`, the `header is ` prefix,
header construction, and `PrintStream.println(String)`. After rebuilding,
[saved method disassembly](evidence/sec01/release-authorization-method.smali)
contains **zero print/println calls** and no logging prefix. The method remains
present and returns both Bearer/JWT and App authorization headers; JWT validation,
error handling, and result-listener callbacks remain. A `System.out` read followed
by `Object.getClass()` remains as a null check, which cannot print the header.
Source line 113 remains in R8 mapping; mapping lines alone are not proof of a
logging call. The DEX instructions establish removal.

A fresh `flutter build apk --debug --target lib/main_local.dart --no-pub` also
passed. Debug method disassembly still contains exactly one
`PrintStream.println(String)` call and the logging prefix. Debug behavior and
plugin consumer rules were not changed.

## Regression checks

| Existing checks | Result |
| --- | --- |
| Plugin `flutter test --no-pub --reporter expanded` | 229 passed |
| Example `flutter test --no-pub --reporter expanded` | 42 passed |
| Native Debug unit suites, `--offline --rerun-tasks` | 323 tests / 49 suites; no failures, errors or skips |
| Native Release unit suites, `--offline --rerun-tasks` | 323 tests / 49 suites; no failures, errors or skips |

Native tasks: `:infobip_mobilemessaging_huawei:testDebugUnitTest` and
`:infobip_mobilemessaging_huawei:testReleaseUnitTest` from `example/android/`.
Existing initialization/HMS configuration, JWT/Chat, outgoing RTC, renderer,
screen sharing, controls and lifecycle suites cover local regression boundaries.
No runtime application/plugin code changed. These JVM/Flutter checks do not
establish live HMS registration, backend authorization, Chat or media behavior
on the newly optimized APK; those remain device acceptance work.

## Device verification and remaining risk

A Huawei ANA_NX9 device was connected. Targeted execution of **this artifact** was
not performed because it is unsigned and cannot be installed. Existing signing
configuration and device installation were preserved. No raw Logcat or credentials
were printed or saved. Static removal is proven; physical verification of this
new APK is **UNVERIFIED**.

After installing a properly signed copy of this Release build, open the example
and run Initialize/Refresh Setup to exercise the affected user-data path. Start
this command after launch and before those operations (stop with Ctrl-C):

```sh
adb logcat --pid="$(adb shell pidof -s com.infobip.mobilemessaging.huawei.example)" \
  -v raw System.out:I '*:S' | \
  awk '/header is (App |Bearer )/ { print "SEC-01 FAIL: header logging detected"; fflush() }'
```

The command emits only a fixed failure message, never the credential-bearing
line, and saves no logs. Confirm the affected operation actually executes;
silence alone does not establish a pass. Debug, unoptimized builds, consumers
without opt-in, other logging APIs, and future SDK changes remain risks.
The earlier certification/audit reports describe the pre-mitigation baseline;
this scoped artifact evidence supersedes their claim of no verified mitigation
only for the example's identified Release logging path. General security
certification and permanent vendor remediation are not claimed.
