# Contributing

## Development approach

- Keep public Dart APIs minimal, strongly typed, documented, and independent of channel details.
- Route platform operations through the platform interface and central channel contract.
- Keep Android code lifecycle-safe, release handlers and listeners on detach, and avoid retaining an activity beyond its attachment lifecycle.
- Do not add iOS or non-Huawei transport support without an explicit supported-platform decision.
- Treat published names, models, channel behavior, and errors as compatibility commitments.

## Dependencies

The native implementation targets Infobip Huawei Mobile Messaging Core, Inbox and Chat SDKs 9.3.0 (RTC Core remains 2.5.28). Do not upgrade Infobip, Huawei, Flutter, Kotlin, Gradle, or Android Gradle Plugin dependencies silently. Review release notes, transitive dependencies, repository requirements, host impact, and `API_COMPATIBILITY.md` for every SDK change. Do not add copied AARs, application-specific SDKs, signing configuration, or unrelated build plugins.

## Formatting and validation

Use the [documented Flutter/Android toolchain](README.md#requirements). Select
JDK 21 through `JAVA_HOME` for native tests: the API 36 Robolectric tests require
Java 21, while Java/Kotlin bytecode targets remain 17.

From a fresh checkout, resolve dependencies and generate the existing safe example
configuration before formatting, analysis, tests or builds. The setup script
preserves an existing private configuration; never commit that file.

Run from the repository root before opening a pull request:

```sh
flutter pub get --no-example
(
  cd example
  flutter pub get
  dart run tool/setup_config.dart
)
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze --no-pub
flutter test --no-pub
(
  cd example
  flutter test --no-pub
)
(
  cd example/android
  ./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest --console=plain
  ./gradlew :infobip_mobilemessaging_huawei:testReleaseUnitTest --console=plain
)
(
  cd example
  flutter build apk --debug --no-pub
  flutter build apk --release --no-pub
)
flutter pub publish --dry-run
git diff --check
```

The formatting command checks without rewriting files. Root analysis includes the
example. These local checks do not establish hosted CI success, publication, or
physical-device/backend acceptance.

Add focused Dart tests for public and platform-channel behavior. Add native tests when Kotlin behavior changes. Device-dependent functionality must be validated on a supported Huawei device with the contributor's own ignored host configuration.

## Pull requests

Use a focused branch and a concise commit message. Describe public API or host-configuration impact, tests performed, device coverage, and any remaining limitations. Do not combine SDK upgrades with unrelated changes.

## Security

Never commit or log `agconnect-services.json`, Application Codes, JWTs, API keys, push tokens, user data, production payloads, keystores, private keys, signing passwords, Chat content, contextual data, or attachment paths. Keep host identity and AppGallery Connect configuration outside the reusable plugin. Verify ignored files and staged changes before every commit.

## Native implementation

The Android module is a library and must not declare an `applicationId`. Keep channel and method identifiers centralized, use explicit model mapping, sanitize platform errors, dispatch SDK work according to its threading requirements, and invoke features only after successful SDK initialization. Embedded Chat requires an attached `FragmentActivity` and must dispose its fragment and view-scoped channel cleanly.
