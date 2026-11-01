# Example startup, RTC configuration and Sponsors validation

Date: 2026-10-25. Branch: `fix/rtc-chat-conversation-mismatch`.
HEAD before/after: `71c936c2ef96a4a7aaf57a9d1a5e8ddf555497cc`.
No branch change, commit, push, tag, publication, version bump or SDK runtime change.

## Architecture and setup

Previously `main.dart` imported empty Dart constants; `prepare_local.dart` generated
an ignored alternate entry point importing private Dart constants. Now `main.dart`
loads an optional JSON asset from a tracked asset directory. Missing assets use
safe defaults and existing prerequisite UI. Invalid JSON/types/unknown keys stop
startup with a generic configuration message, without displaying private content.
The configuration object and all feature controllers/authentication/RTC paths remain.

```sh
git clone https://github.com/NaserAlomosh/infobip-mobile-messaging-huawei-flutter-plugin.git
cd infobip-mobile-messaging-huawei-flutter-plugin/example
flutter pub get
cp -n example_config.example.json config/example_config.local.json
# Edit private JSON and complete Huawei host setup in example/README.md.
flutter run
```

Use Flutter 3.35.7 / Dart 3.9.2 for this branch's existing Gradle wrapper.
To update configuration, edit the same JSON, stop the app and run `flutter run`.
`main_local.dart` is no longer needed. Its existing private copy and the original
private Dart constants were retained byte-for-byte. Every original constant was
copied to the new ignored JSON and equality was checked without outputting values.
Other developers can transfer their constants using the matching JSON field names.

The JSON and legacy private files are explicitly excluded from pub packaging;
Git ignore checks passed. Test credentials remain extractable from built APKs,
as with compiled Dart constants. Keep configured test artifacts private. The clean
export APK contains no private configuration asset. No private values were added
to tracked files. The optional asset avoids importing a nonexistent Dart file.

## RTC findings

Official Android documentation defines the Conversations enum destination:
https://github.com/infobip/infobip-rtc-android/wiki/InfobipCallsConfiguration
https://github.com/infobip/infobip-rtc-android/wiki/InfobipRTC

Bytecode inspection of this branch's pinned RTC 2.5.28 confirms its string is
`conversations`. It is a standard built-in identifier, not an account-generated
value, but is not universally usable without account enablement/routing/agents.
Custom Calls applications use their own administrator-supplied configuration ID.
The already-empty public default remains empty to require an explicit destination.
The existing local `conversations` value was preserved.

Both READMEs contain **Configure Infobip RTC Calls Routing**, including the public
Flutter API, account setup, native token ownership, Push ID distinction, receiving
agent tests and troubleshooting. The outgoing consumer guide links to it. Generic
Calls API orchestration must not be confused with Conversations-managed calls.
No runtime validation/signaling/authentication changes were made.

## Sponsors

https://github.com/sponsors/NaserAlomosh returned HTTP 200 with the GitHub title
“ Sponsor @NaserAlomosh on GitHub Sponsors ”. Owner also matches repository metadata.
Both READMEs now link to Sponsors; `.github/FUNDING.yml` contains
`github: [NaserAlomosh]`, with Ruby YAML parsing verified. The remote Sponsor button
is not changed until the maintainer publishes these repository changes.

## Validation

| Check | Result |
| --- | --- |
| Root/example dependency resolution | PASS |
| Example analysis, Flutter 3.35.7 and 3.47.7 | PASS, no issues |
| Root analysis, Flutter 3.47.7 | PASS, no issues |
| Root analysis, Flutter 3.35.7 | Exit 1: 21 deprecation infos, zero errors/warnings; all affected files match HEAD |
| Plugin tests, both Flutter versions | PASS, 238 |
| Example tests, both Flutter versions | PASS, 51, including 3 new loader tests |
| Clean export default-entry debug APK, Flutter 3.35.7 | PASS, no private files |
| Clean export debug/release app Kotlin compilation, Java 21 | PASS |
| Native debug unit tests | PASS, 410; zero failures/errors/skips |
| Native release unit tests | PASS, 410; zero failures/errors/skips |
| Working-tree publish dry-run | 2 warnings for modified/deleted tracked files; no publication |
| Clean export publish dry-run | PASS, zero warnings |
| README/consumer guide local link targets | PASS |
| Sponsors URL, funding syntax, ignore rules, private-value preservation | PASS |
| git diff --check | PASS |
| Physical device / backend / agent routing / two-way media | NOT RUN |

Flutter 3.47.7 clean Android build fails because it requires Gradle >=8.14 while
this branch pins 8.13. No validation bypass or toolchain upgrade was introduced.
Flutter 3.35.7 clean build succeeds. Tool-generated lock/analyzer collateral from
the newer Flutter run was removed after verifying those files were initially clean.
No claim of all possible runtime regressions being excluded is made.

## Files changed by this task

Added: `.github/FUNDING.yml`, `example/config/README.txt`,
`example/lib/config/load_example_config.dart`,
`example/test/example_config_loading_test.dart`, this report.

Modified: `.pubignore`, `README.md`, `example/.gitignore`, `example/README.md`,
`example/example_config.example.json`, `example/lib/config/example_config.dart`,
`example/lib/config/example_test_config.template.dart`, `example/lib/main.dart`,
`example/pubspec.yaml`, `doc/huawei-rtc-outgoing.md`.

Deleted: `example/tool/prepare_local.dart` (obsolete launcher generator).
Ignored local addition: `example/config/example_config.local.json`.
Pre-existing documentation edits/deletions remain, including the README overhaul.
Historical audit records may mention the old launcher as past evidence, not setup.

## Explicit answers

- Can a new developer use `flutter run`? Yes, with the validated Flutter baseline;
  real service testing also requires Huawei/account/device configuration.
- Is `main_local.dart` needed? No.
- Is RTC configuration documented without requiring Kotlin reading? Yes.
- Are private credentials preserved? Yes; original files and migrated values checked.
- Is Sponsors present? Yes in local README and funding metadata; remote unchanged.

## Final Git status

```text
 M .pubignore
 M README.md
 M doc/final-production-certification.md
 M doc/huawei-rtc-customer-identity.md
 M doc/huawei-rtc-outgoing.md
 M doc/messaging-chat.md
 D doc/publication-readiness.md
 D doc/release-1.0.1-review.md
 D doc/release-packaging.md
 M doc/screen-sharing.md
 M example/.gitignore
 M example/README.md
 D example/VALIDATION.md
 M example/example_config.example.json
 M example/lib/config/example_config.dart
 M example/lib/config/example_test_config.template.dart
 M example/lib/main.dart
 M example/pubspec.yaml
 D example/tool/prepare_local.dart
?? .github/
?? doc/example-startup-cleanup-validation.md
?? doc/pre-release-documentation-review.md
?? example/config/
?? example/lib/config/load_example_config.dart
?? example/test/example_config_loading_test.dart
```
