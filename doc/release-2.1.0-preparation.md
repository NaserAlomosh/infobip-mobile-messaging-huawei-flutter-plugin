# 2.1.0 release preparation — 2026-11-03

## Baseline and scope

Branch `release/2.1.0-preparation`, HEAD `2f65fe97ed8e96cf37fde22401682ebb438aabbb`.
`git fetch origin` succeeded; HEAD and freshly fetched `origin/development` have
zero commits on either side. Working tree was clean before preparation.
P1 commit `05937e6` (accuracy/API guidance) and P2 commit `d8a0c73`
(documentation organization and historical notices) are present through PR #94.

Published 2.0.0 archive SHA-256:
`4f41403fd3fa487dcd98768097f7a12c1d4ea0ecb5a917afa754eb769a83a0c4`.
All 273 published files byte-match tag `v2.0.0` (`ea8325e`).
Source: https://pub.dev/api/packages/infobip_mobilemessaging_huawei

## Compatibility assessment (completed before metadata updates)

**2.1.0 is SemVer-appropriate for the documented public API.** `patchUser`,
`UserPatch`, `FieldUpdate` and the two false-default personalization flags are
additive. Existing save semantics and legacy personalization signatures remain.
The email guard moves existing SDK rejection (>255 UTF-16 code units, code -10)
before SDK entry with a value-free message; it adds no email syntax normalization.
Neither SDK versions nor Dart/Flutter/Android build requirements change.
Internal `src/platform` subclasses overriding `personalize` need the new optional
named parameters; these classes are not exported by the public entry point.
See https://semver.org/ and [API assessment](../API_COMPATIBILITY.md).

Audit of all 45 changed files since published 2.0.0:

- G-01: sparse Dart patch encoding, channel dispatch, native request maps and
  omission/set/clear tests. Whole-map custom-attribute clearing is rejected;
  empty patches still reach SDK; backend deletion is unverified.
- Privacy: pre-SDK length checks on save/patch/personalize and legacy alias,
  safe failure mapping, boundary/logging/SDK-bytecode regression tests.
  Existing persisted pending values and SDK synchronization remain upstream risks.
- G-02: Dart options, channel validation and native five-argument forwarding,
  false defaults for existing callers, forwarding/privacy regression tests.
- Test infrastructure: Robolectric runtime Maven endpoint and full exception
  output, CI report retention. Historical CI root cause remains unproven.
- P1/P2: API/setup accuracy, current-guide navigation, historical report notices,
  security limitations, third-party attribution, simpler example guidance.
  No new RTC behavior, SDK update, or device/backend certification.

## Validation

Validated in a separate tracked-source copy at
`/private/tmp/release-2.1.0/source`, with template example configuration and no
private AG Connect JSON. Original private configuration was never copied or edited.
Flutter 3.44.4 / Dart 3.12.2 / JDK 21, AGP 9.1.1 / Gradle 9.3.1 / KGP 2.2.10.
Logs and machine-readable results: `/private/tmp/release-2.1.0/`.

| Check | Result |
| --- | --- |
| Flutter analysis | PASS; no issues |
| Plugin Dart tests | 253 passed, 0 failed, 0 skipped |
| Example Dart tests | 49 passed, 0 failed, 0 skipped |
| Native Debug unit tests | 433 passed, 0 failures/errors/skips; 57 XML suites |
| Native Release unit tests | 433 passed, 0 failures/errors/skips; 57 XML suites |
| Total | 1,168 passed |
| Formatting | 96 Dart files checked, 0 changes |
| Documentation | 240 local file targets and 55 current-guide anchors valid |
| Debug APK | PASS; 21.0s Gradle build |
| Release APK | PASS; 44.9s Gradle build, 88.0 MB reported |
| Package dry run in isolated copy | PASS, exit 0, 0 warnings |
| Package dry run in working checkout | Exit 65; only warning is intentionally uncommitted edits |
| Whitespace | `git diff --check` passed |

Native tasks ran with `--rerun-tasks`; counts are from newly generated XML,
not historical reports. Dart counts exclude hidden loading events. Commands:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --machine
(cd example && flutter test --no-pub --machine)
(cd example/android && ./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest --rerun-tasks --console=plain)
(cd example && flutter build apk --debug --no-pub)
(cd example && flutter build apk --release --no-pub)
dart format --output=none --set-exit-if-changed lib test example/lib example/test example/tool
flutter pub publish --dry-run
```

## Package contents and security

Dry-run manifest: 282 files; all tracked. Compared with the published archive,
9 intended implementation/test files added, none removed. Existing native/Dart
tests, example sources and public guides remain included deliberately. Internal
engineering reports are excluded by `.pubignore`. No private example config,
AG Connect JSON, local properties, generated builds, lockfiles, signing material
or secret directories appeared. Credential-pattern scan found no private-key,
AWS access-key, GitHub-token, Google-key or JWT matches; values were suppressed.
Sensitive-assignment candidates were channel-key names and synthetic test fixtures
(including the explicitly labeled deterministic test signing key), not account
credentials. This is a package review, not proof that arbitrary future credentials are absent.

**SEC-01 remains PARTIALLY MITIGATED, unresolved upstream.** No classification,
owner decision, or vendor status was changed. The prior optional host R8 rule
and historical artifact inspection do not establish safe logging in the current
signed host application. No vendor disclosure, security certification, or new
release-risk authorization is implied by this preparation.

## Outstanding validation and limitations

- Physical Huawei/HMS registration, token refresh, push and tap behavior under
  foreground/background/terminated states; real account routing and authorization.
- Real backend patch omission/set/clear/deletion, custom-attribute null entries,
  persistence across fetch/restart, and empty-patch/pending-data behavior.
- Lead retention, primary-device selection and persistence across multiple
  registered devices; identity changes, JWT policy and depersonalization.
- Candidate signed install, upgrade from published 2.0.0 with persisted state,
  rollback policy, real Release logging capture with redacted evidence.
- Chat/Inbox authentication and events, RTC routing/media/foreground incoming,
  screen capture lifecycle on physical hardware. Conversation reuse and
  background incoming calls remain unsupported/unverified as documented.
- SEC-01 upstream remediation and signed-device verification remain unresolved;
  no production security certification. Existing namespace workaround, legacy
  Kotlin/AGP transition/deprecation warnings and known sub-16KB armeabi-v7a ELF
  alignment limitation require host/toolchain review.
- Hosted CI was not triggered; local success does not establish hosted execution
  or the historical Robolectric failure's root cause. No publishing actions run.

## Changed release-preparation files

`pubspec.yaml`, `CHANGELOG.md`, `README.md`, `API_COMPATIBILITY.md`,
`example/README.md`, and this report. No production source changes during preparation.
No commit, push, tag, publication, PR or merge performed.

## Final verdict

**READY FOR INDEPENDENT REVIEW.** No preparation blocker remains. The required
uncommitted state causes the checkout dry-run warning; isolated package validation
passes with zero warnings. Device/backend/host security acceptance and hosted CI
remain outstanding as listed above and must not be inferred from local results.

## Complete baseline change inventory

- `.github/workflows/ci.yml`
- `API_COMPATIBILITY.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `README.md`
- `SECURITY.md`
- `THIRD_PARTY_NOTICES.md`
- `android/build.gradle.kts`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/InfobipMobileMessagingHuaweiPlugin.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/plugin/ChannelContract.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacy.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserManager.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserMapper.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/PersonalizationFlagsTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacyTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPatchTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPersonalizationPrivacyTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPrivacySdkBytecodeTest.kt`
- `doc/G-02_PERSONALIZATION_FLAGS.md`
- `doc/README.md`
- `doc/g01-user-update-patch-report.md`
- `doc/huawei-chat-api-reliability.md`
- `doc/huawei-rtc-call-controls.md`
- `doc/huawei-rtc-customer-identity.md`
- `doc/huawei-rtc-ongoing-call.md`
- `doc/huawei-rtc-outgoing-verification.md`
- `doc/huawei-rtc-screen-as-camera-poc.md`
- `doc/huawei-rtc-screen-orientation.md`
- `doc/huawei-rtc-screen-performance.md`
- `doc/huawei-rtc-screen-video-quality.md`
- `doc/inbox-set-seen-investigation.md`
- `doc/messaging-chat.md`
- `doc/robolectric-ci-resolution.md`
- `doc/user-validation-privacy-report.md`
- `doc/webrtc-core-device-validation.md`
- `example/README.md`
- `lib/src/core/infobip_mobilemessaging_huawei.dart`
- `lib/src/platform/channel_contract.dart`
- `lib/src/platform/infobip_mobilemessaging_huawei_platform.dart`
- `lib/src/platform/method_channel_infobip_mobilemessaging_huawei.dart`
- `lib/src/user/user.dart`
- `lib/src/user/user_codec.dart`
- `test/personalization_flags_test.dart`
- `test/user_patch_test.dart`
- `test/user_validation_privacy_test.dart`

Debug APK SHA-256: `a14d59e8195d5ffe971a7d15a13c538b66dd8e317de9f155846dfe4d61322544`.

Release APK SHA-256: `da032d509f66169a41683afee59b6a1f9048cbb5bda3cb3d17ea2d1b5be10db4`.
