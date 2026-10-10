# SDK Test Center validation — 10 October 2026

Branch: `feature/huawei-rtc-core`. Working tree was clean at entry. Only `example/` was changed. No commit, push or merge. Plugin production implementation and incoming RTC safeguards were preserved.

| Check | Executed result |
| --- | --- |
| Dart formatting, `example/lib`, `test`, `tool` | PASS |
| `flutter analyze` from example | PASS, no issues |
| Clean-checkout analysis without ignored local config/entrypoint | PASS, no issues; files restored byte-for-byte |
| `flutter test` from example | PASS, 25 tests |
| `flutter test` from repository root | PASS, 200 tests |
| `flutter analyze` from repository root | 21 existing deprecation info findings in untouched production/test files; no example findings |
| Local config, entrypoint and AGC file Git ignore checks | PASS |
| `git diff --check`; production-source diff check | PASS; no changes outside example |
| Android debug arm64 compilation | PASS, `BUILD SUCCESSFUL` (21 seconds), Kotlin compilation and APK packaging completed |
| Real Huawei device / Portal / peer tests | NOT RUN |

Successful Android command from `example/android/`:

```sh
./gradlew :app:assembleDebug --offline -Ptarget=lib/main_local.dart -Ptarget-platform=android-arm64 --console=plain
```

The first online all-architecture build attempts waited without progress and were canceled. The offline all-architecture retry identified missing cached Flutter `armeabi_v7a_debug` and `x86_64_debug` engine JARs. Narrowing to the cached arm64 engine completed the build. Existing Gradle repository/deprecation and Android SDK XML tooling warnings remained. This validates the empty-Huawei-credentials build path, not AGC processing with a real downloaded configuration.

The example tests retain JWT byte/signature/freshness, setup/readiness, denied permissions, Inbox authentication ordering and unchanged set-seen arguments, separate Chat provider callbacks, and old feature-control navigation. Added coverage verifies persisted manual outcomes, unsupported outcome protection, sanitized report fields, supplied JWT subject/expiry, the new center UI and that initialization never auto-passes a device test. Widget scrolling fixtures were adjusted for explicit scroll targets and visibility.

## Audit and reuse

Inspected the existing example Dart screens/controller/JWT helpers, Android manifest/host/build configuration, example README and JSON template, `lib/src/rtc/huawei_rtc.dart`, `API_COMPATIBILITY.md`, and the four requested RTC configuration/verification/device-plan documents. Checked public User, Installation, Inbox, Chat and notification contracts.

Reused the existing three-stage readiness surface under Open controls, controller, two separate JWT signing helpers, native/embedded Chat, Inbox filters/seen updates, user/installation controls, Android permission bridge and outgoing RTC. Added a 71-row manual catalog across SDK/AUTH/PUSH/USER/INSTALLATION/INBOX/CHAT/RTC, bounded application-scoped sanitized logs, private local result persistence and JSON clipboard exports. The two unsupported RTC rows cannot be marked Pass.

The credential file is ignored; tracked empty static defaults are injected through the standard entrypoint so a checkout without local files compiles. The local launcher injects the same mapping using the developer's single local static Dart file. No new Flutter dependency was introduced. AGC build tooling is conditionally loaded only when the real local Android host file exists.

## Remaining device blockers

Supply test Application Code/user and optional separate MM/Chat JWT credentials, real AGC file/package/signing fingerprint, enabled Push Kit/HMS Core, matching Infobip App Profile, Chat widget/agent, Calls routing configuration and reachable peer. Grant notification/microphone/camera/Nearby permissions as required. Test AGC processing with those real host values.

Backend authorization, real registration/delivery, Chat connectivity/attachments, native token issuance, peer media, Activity recreation and actual media cleanup remain unverified. Supplied JWTs expire and cannot be renewed without replacing/rebuilding; generated helpers sign fresh tokens per request/callback. Logs do not survive process death, although sanitized test outcomes do; cold-start taps use actual plugin replay. Incoming HMS signaling, official incoming-call APIs and video preview/remote renderer remain unsupported. Existing upstream authorization logging concern remains outside example scope; keep raw device/SDK diagnostics private.
