# Huawei SDK Test Center

A manual integration test application for a **physical Huawei device**, using the existing plugin on `feature/huawei-rtc-core`. All runtime results come from public SDK APIs, real events, or explicit tester confirmation. No physical-device test has been performed by this refactor.

## One editable Dart configuration

From `example/`:

```sh
flutter pub get
dart run tool/prepare_local.dart
```

Edit **`example/lib/config/example_test_config.dart`**. It is Git-ignored. The launcher creates it from the tracked empty `example_test_config.template.dart` only if it does not already exist, and never overwrites existing local values. Then run:

```sh
flutter run -t lib/main_local.dart -d YOUR_HUAWEI_DEVICE_ID
```

Use `flutter devices` to get the ID. No Dart defines or JSON test-data file is needed. Restart/rebuild after changing static fields. `lib/main.dart` uses the tracked empty template, so a clean checkout compiles and reports missing prerequisites. `main_local.dart` is an ignored entry point using the same mapping with the local file instead. All feature controllers receive that one configuration object. Running plain `flutter run` intentionally uses empty template values; use the command above for your device session. The old JSON template is retained only as historical reference and is no longer read.

Use controlled test credentials and decrypted values only. Signing secrets are extractable from test APKs; keep those APKs private. Production JWTs belong on a trusted backend. Never use the banking AppKey as a signing key. No decryption or banking encryption exists here.

### Every active field

| Section | Fields to fill / choose | Contract |
| --- | --- | --- |
| Application | `infobipApplicationCode` | Required for SDK initialization. Backend `ApplicationCode` → `INFOBIP_APPLICATION_CODE`. |
| Mobile Messaging JWT | `jwtToken` **or** `jwtKid`, `jwtSecretKey`, `jwtTtlSeconds` | Optional outside JWT Inbox tests. Signing secret is hex, at least 32 decoded bytes; TTL 1–300 seconds. Fresh locally generated token per Inbox request. A supplied token is reused only while valid: replace/rebuild when expired. Signature acceptance is determined by the backend, not local validation. |
| Chat authentication | `chatAuthMode` | `installation` or `jwt`, matching Portal widget security. Application Code still initializes the SDK. |
| Chat JWT | `chatJwtToken` **or** `chatWidgetId`, `chatKeyId`, `chatSecretKey`, `chatJwtTtlSeconds` | Separate widget token/provider. Signing secret is Base64, at least 32 decoded bytes; TTL 15–300 seconds. Matching personalized `externalUserId` required. Generated provider signs on every callback. Supplied tokens cannot be automatically renewed. Restart when changing authentication mode; no public provider-clear API is invented. |
| Chat controls | `chatMessage`, `chatContextualData`, `chatTheme` | Optional initial text for existing controls; use test-only content and an existing widget theme. Language buttons retain English/Arabic tests. |
| Test user | `externalUserId`, `firstName`, `lastName`, `email`, `phoneNumber` | Identity required for personalization/Inbox; name defaults available; email/phone optional for save-user testing. Use an isolated test identity. |
| Inbox | `inboxTopic`, `inboxLimit`, `invalidExternalUserId` | Optional topic, positive limit (default 20); separate intentionally invalid identity for negative tests. Configure an actually empty identity for empty Inbox tests. |
| Push comparisons | `expectedNotificationTitle`, `expectedNotificationBody`, `expectedDeepLink` | Optional match checks in events, never raw payload logging. Empty disables comparison. |
| Outgoing RTC | `rtcCallsConfigurationId`, `rtcIdentity`, `enableAudioTesting`, `enableVideoTesting` | Calls routing configuration, **not RTC Push Configuration ID**. Empty identity uses registered installation ID. Flags enable/disable normal call controls. Routing selects the peer; there is no callee API parameter. |
| Device/installation | `environmentName`, `installationPrimary`, `installationPushEnabled`, `installationAttributes` | Environment label; intended writable test installation state. Attributes must be supported SDK values. Changing push-enabled state affects subsequent delivery tests. |

**Not used by active flows:** backend `AppKey` → `INFOBIP_APP_KEY`, `InfobipApplicationId` → `INFOBIP_APPLICATION_ID`, `InfobipBaseUrl` → `INFOBIP_BASE_URL`. The inspected public initialization contract has no parameters for these fields. They are documented rather than invented in SDK requests. **Huawei AppGallery App ID is a separate Android host value**, unrelated to Infobip Application Code or Infobip Application ID.

## Huawei Android host setup

1. In AppGallery Connect create/select your Android application. Its package must match `example/android/app/build.gradle.kts`: `com.infobip.mobilemessaging.huawei.example`, or change that `applicationId` to your registered test package.
2. Register the SHA-256 fingerprint of the certificate actually signing your installed debug APK. Use `cd android && ./gradlew :app:signingReport` to inspect it; do not assume a release fingerprint covers debug builds.
3. Enable HMS Push Kit and configure the matching Huawei credentials in the Infobip Mobile Messaging App Profile. Match the Infobip Application Code to that profile.
4. Download the real **`agconnect-services.json`** into **`example/android/app/agconnect-services.json`**. Git ignores it. Do not create a fake file. The AppGallery App ID comes from its `client.app_id`; Gradle provides the HMS manifest app-id metadata from this value and conditionally applies the AppGallery Connect plugin. Empty checkouts build but cannot establish real HMS registration.
5. Huawei Maven repositories are configured in `example/android/settings.gradle.kts`; the AGC classpath and conditional plugin application are in `example/android/app/build.gradle.kts`. AGC tooling is loaded only when the real local file is present. No production plugin Gradle/source files are changed.
6. The host already extends **FlutterFragmentActivity** and requests runtime permissions through its example-only channel. Manifest permissions cover notifications (Android 13+), microphone, camera, and Nearby devices/Bluetooth connect (Android 12+). Grant notifications during Push registration and call permissions in Setup. Verify notification channels, Huawei battery/background settings and HMS Core availability on the device.
7. The main screen reports host App ID resource presence only, not credential correctness or device readiness. A real installation ID/HMS token and Portal delivery are required to confirm setup.

Host configuration placement follows [Huawei's Flutter Android integration guide](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides-V1/integrating-sdk-0000001052151811-V1). The no-file build path does not validate real AGC credentials/plugin processing; verify the downloaded file on your device build.

## Guided execution order

1. **Setup:** initialize; inspect readiness and host status. Grant call permissions through the reused three-stage setup controls.
2. **Authentication:** clear optional Mobile Messaging JWT for Application Code tests; separately validate MM JWT and configure Chat JWT when needed. Application Code and JWT are not interchangeable and there is no invented universal auth switch.
3. **Push Notifications:** register, fetch installation, personalize in User Management, then send from the Infobip Portal to the configured test App Profile/external identity. Observe foreground, background, notification tap/action, custom payload and deep-link match flags. Repeated registration/network failures are separate tests.
4. **User / Installation:** read cache and server, save configured test values, personalize/depersonalize, verify server matches. Installation primary/push registration/custom attributes are tested through actual writable fields.
5. **Mobile Inbox:** run both auth paths; verify filters, limits, unread counters, mark-seen/re-fetch, empty results, invalid identity and auth errors. Mark-seen retains its existing installation context with no invented JWT argument.
6. **In-App Chat:** open embedded/global Chat, send/reply with a real agent, attachments in native composer, unread count/stream, contextual data, language, theme, draft, events/errors, back navigation and reopening.
7. **Huawei RTC:** configure Calls routing and a reachable peer; start audio/video, observe establishment and native errors, confirm media at peer, hang up and await `finished`. Run repeated calls, second-call rejection, permission denial, network interruption, Activity recreation, active snapshots and media cleanup. Rejection probes call the same guarded public API; no safeguard is bypassed.
8. **Event Logs / Test Report:** inspect sanitized evidence and explicitly confirm Pass/Fail or mark Blocked. Copy/Export writes sanitized JSON to clipboard; paste it into a local `.json` file. Export before uninstall/clear-data.

Every catalog row has a stable ID, description, configuration, permissions, auth context, steps, expected and actual result, status, error, timestamp and elapsed duration. Successful method completion produces `REQUIRES_MANUAL_VERIFICATION`, never automatic Pass. Missing prerequisites produce Blocked; unexpected operation errors produce Fail and require a re-run before Pass. Expected negative-test errors remain awaiting manual comparison before confirmation. Statuses are NOT_RUN, RUNNING, PASS, FAIL, BLOCKED, UNSUPPORTED and REQUIRES_MANUAL_VERIFICATION. The report includes all status counts, per-test auth mode, device model/Android version, timestamps/durations and sanitized errors.

Sanitized test outcomes persist in private Android preferences. Process death does not erase completed outcomes. Logs are application-scoped and bounded to 500 events, held in memory; no capture is claimed while the process is dead. Cold-start taps rely on the plugin's actual replay stream. Distinguish background, swipe-away/OS termination and force-stop: force-stop may suppress delivery until explicit relaunch. For restart tests, begin observation before leaving, relaunch, inspect actual tap evidence, then record the outcome.

The event store omits raw notification bodies, titles, deep links, payloads, user PII, registration tokens, JWTs, keys, headers and raw exception text. It retains presence/match flags, counts, stable errors and RTC enums/numeric reasons. No free-text report notes are accepted, preventing accidental credential export. Verify raw payload contents only through controlled Portal/device observations, then manually confirm the corresponding test.

## Reused features and unsupported boundaries

Reused `ExampleController`, readiness/permissions, MM and Chat JWT signing helpers, Inbox, User, Installation, native/embedded Chat and existing outgoing RTC screens. `HuaweiRtc.callApplication`, `hangup`, `getActiveCall`, and `events` remain the only RTC integration; token acquisition remains native. Production source and public APIs are untouched.

**Unsupported:** incoming Huawei HMS call signaling and official `enableCalls`/`enableChatCalls` parity, simulated incoming calls, local video preview/remote renderer and extra RTC media controls not exposed by this branch. Outgoing video requires peer confirmation of frames; outgoing audio requires real two-way media confirmation. Token success, routing, media release, background behavior and Activity recreation need real hardware/backend evidence. App cleanup should follow hangup/finished; screen navigation alone does not hang up.

See the existing [RTC scope](../docs/huawei-rtc-outgoing.md), [verification](../docs/huawei-rtc-outgoing-verification.md), [device plan](../docs/webrtc-core-device-validation.md), [WebRTC safeguards](../docs/webrtc-configuration.md), and [compatibility matrix](../API_COMPATIBILITY.md). Existing upstream authorization logging concern documented there remains outside example scope: keep raw device/SDK logs private.

## Validation

From `example/`: `dart format lib test tool`, `flutter analyze`, `flutter test`, `flutter build apk --debug -t lib/main_local.dart`. Also validate root plugin analysis/tests without changing production code. Automated tests use synthetic fixtures only; they do not count as device report Passes. Current executed results are recorded in `VALIDATION.md`.

## Final configuration/authentication audit

See [CONFIG_AUTH_AUDIT.md](CONFIG_AUTH_AUDIT.md) for source-confirmed contracts, scoped defect fixes, validation and remaining UNVERIFIED items. Supplied JWTs are checked against their separate MM/widget claims and expiry; signature/backend acceptance is not inferred. An omitted Chat `exp` uses the documented `iat + 15` default. User writes use the configured identity/contacts and server re-fetch. Once Chat is prepared, restart before changing identity; hang up and await finished before user changes during RTC. A null active-call snapshot does not prove no token request is pending, so finish direct RTC call attempts before leaving to change users. Restored test outcomes are historical evidence; re-run after changing profile/user/configuration.
