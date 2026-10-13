# Huawei SDK Test Center

A manual integration test application for a **physical Huawei device**, using this checkout of the plugin via the example's local path dependency. All runtime results come from public SDK APIs, real events, or explicit tester confirmation. Automated tests do not establish Huawei device or Infobip backend acceptance.

## Start with the required values

Use the [main Getting Started guide](../README.md#quick-start) to create your
Huawei and Infobip applications before running the test center. Start with push;
Chat and RTC require separate optional service setup.

| To test | Minimum setup / where to obtain values |
| --- | --- |
| Initialize and Push | Huawei AGC app matching the installed package/certificate; Push Kit enabled; downloaded JSON and numeric `app_id`; Infobip Huawei profile configured with App ID/App Secret; profile's Application Code in `infobipApplicationCode` |
| Installation Chat | Registered installation; Live Chat widget linked to that Infobip profile, matching installation security mode and a reachable agent |
| JWT Chat | Above plus authenticated backend widget token in `chatJwtToken`, matching `externalUserId`, and `chatAuthMode = 'jwt'`; tokens must be replaced when expired/consumed |
| Mobile Inbox / protected user APIs | Test `externalUserId`; backend MM/Inbox JWT in `jwtToken` when profile policy requires it (Production Inbox requires JWT) |
| Outgoing RTC | Web and In-app Calls enabled; backend administrator supplies `rtcCallsConfigurationId` with working routing/receiver; optional authorized `rtcIdentity`, or wait for registered installation identity |

The preferred test path is supplied backend tokens. This example also contains
local signing helpers for isolated tests only; they are not a production pattern.
Keep generated APKs private if you use those helpers, and never commit keys.
The [configuration reference](../README.md#configuration-reference) explains ID,
token and signing-key ownership. App Key, Application ID and a base URL are not
initialization inputs for this plugin.

## One editable Dart configuration

From `example/`:

```sh
flutter pub get
dart run tool/prepare_local.dart
```

Edit **`example/lib/config/example_test_config.dart`**. It is Git-ignored. The launcher creates it from the tracked empty `example_test_config.template.dart` only if it does not already exist, and never overwrites existing local configuration values. It regenerates the ignored `lib/main_local.dart` launcher each time; preserve any custom launcher edits before rerunning it. Then run:

```sh
flutter run -t lib/main_local.dart -d YOUR_HUAWEI_DEVICE_ID
```

Use `flutter devices` to get the ID. No Dart defines or JSON test-data file is needed. Restart/rebuild after changing static fields. `lib/main.dart` uses the tracked empty template, so a clean checkout compiles and reports missing prerequisites. `main_local.dart` is an ignored entry point using the same mapping with the local file instead. This keeps the tracked template empty and preserves your private values. All feature controllers receive that one configuration object. Running plain `flutter run` intentionally uses empty template values; use the command above for your device session. The old JSON template is retained only as historical reference and is no longer read.

Use controlled test credentials and decrypted values only. Signing secrets are extractable from test APKs; keep those APKs private. Production JWTs belong on a trusted backend. Never use the banking AppKey as a signing key. No decryption or banking encryption exists here.

### Every active field

| Section | Fields to fill / choose | Contract |
| --- | --- | --- |
| Application | `infobipApplicationCode` | Required for SDK initialization. Backend `ApplicationCode` → `INFOBIP_APPLICATION_CODE`. |
| Mobile Messaging JWT | `jwtToken` **or** `jwtKid`, `jwtSecretKey`, `jwtTtlSeconds` | Required for Production Inbox and profile-protected MM requests; optional only when the profile policy allows Application Code. Signing secret is hex, at least 32 decoded bytes; TTL 1–300 seconds. Fresh locally generated token per Inbox request. A supplied token is reused only while valid: replace/rebuild when expired. Signature acceptance is determined by the backend, not local validation. |
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
3. Enable HMS Push Kit and configure the matching Huawei App ID and App Secret in the Infobip Mobile Messaging App Profile. Match the Infobip Application Code to that profile.
4. Download the real **`agconnect-services.json`** into **`example/android/app/agconnect-services.json`**. Git ignores it. Do not create a fake file. The AppGallery App ID comes from its `client.app_id`; The current app Gradle file reads this value into manifest metadata and `example_huawei_app_id`; it does **not** populate the required `app_id` resource. Replace the literal `APP_ID` in `example/android/app/src/main/res/values/strings.xml` (or `android/app/src/main/res/values/strings.xml` when working inside `example/`) with your numeric, nonzero Huawei App ID. The plugin validates this resource before initialization. Keep it consistent with the downloaded file. Empty checkouts compile but initialization fails with `hms_configuration_missing` until this is configured.
5. Huawei Maven repositories are configured in `example/android/settings.gradle.kts`; AGConnect `1.9.1.301` is declared with `apply false` in settings. The current app module does **not** apply it, conditionally or otherwise. For the documented AGConnect setup, add `id("com.huawei.agconnect")` to the existing plugins block in `example/android/app/build.gradle.kts` as a private host configuration change. Do not assume downloading JSON applies AGConnect. The tracked example remains unchanged; follow the [Gradle snippets](../README.md#gradle-kotlin-dsl) for your private setup.
6. The host already extends **FlutterFragmentActivity** and requests runtime permissions through its example-only channel. Manifest permissions cover notifications (Android 13+), microphone, camera, and Nearby devices/Bluetooth connect (Android 12+). Grant notifications during Push registration and call permissions in Setup. Verify notification channels, Huawei battery/background settings and HMS Core availability on the device.
7. The main screen reports host App ID resource presence only, not credential correctness or device readiness. A real installation ID/HMS token and Portal delivery are required to confirm setup.

Host configuration placement follows [Huawei's Flutter Android integration guide](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides-V1/integrating-sdk-0000001052151811-V1). The no-file build path does not validate real AGC credentials/plugin processing; verify the downloaded file, numeric `app_id`, host plugin application and signing configuration on your device build. The existing `app_name` and `infobip_application_code` strings are placeholders; initialization uses the Dart `infobipApplicationCode`, not that application-code resource.

## Guided execution order

1. **Setup:** initialize; inspect readiness and host status. Grant call permissions through the reused three-stage setup controls.
2. **Authentication:** clear optional Mobile Messaging JWT for Application Code tests; separately validate MM JWT and configure Chat JWT when needed. Application Code and JWT are not interchangeable and there is no invented universal auth switch.
3. **Push Notifications:** register, fetch installation, personalize in User Management, then send from the Infobip Portal to the configured test App Profile/external identity. Observe foreground, background, notification tap/action, custom payload and deep-link match flags. Repeated registration/network failures are separate tests.
4. **User / Installation:** read cache and server, save configured test values, personalize/depersonalize, verify server matches. Installation primary/push registration/custom attributes are tested through actual writable fields.
5. **Mobile Inbox:** run both auth paths; verify filters, limits, unread counters, mark-seen/re-fetch, empty results, invalid identity and auth errors. Mark-seen retains its existing installation context with no invented JWT argument.
6. **In-App Chat:** open embedded/global Chat, send/reply with a real agent, attachments in native composer, unread count/stream, contextual data, language, theme, draft, events/errors, back navigation and reopening.
7. **Huawei RTC:** use native local/remote previews and controls for mute, speaker/audio output and camera enable/switch; configure Calls routing and a reachable peer; start audio/video, observe establishment and native errors, confirm media at peer, hang up and await `finished`. Run repeated calls, second-call rejection, permission denial, network interruption, Activity recreation, active snapshots and media cleanup. Rejection probes call the same guarded public API; no safeguard is bypassed.
8. **Screen Sharing:** follow the dedicated checklist below.
9. **Event Logs / Test Report:** inspect sanitized evidence and explicitly confirm Pass/Fail or mark Blocked. Copy/Export writes sanitized JSON to clipboard; paste it into a local `.json` file. Export before uninstall/clear-data.

Every catalog row has a stable ID, description, configuration, permissions, auth context, steps, expected and actual result, status, error, timestamp and elapsed duration. Successful method completion produces `REQUIRES_MANUAL_VERIFICATION`, never automatic Pass. Missing prerequisites produce Blocked; unexpected operation errors produce Fail and require a re-run before Pass. Expected negative-test errors remain awaiting manual comparison before confirmation. Statuses are NOT_RUN, RUNNING, PASS, FAIL, BLOCKED, UNSUPPORTED and REQUIRES_MANUAL_VERIFICATION. The report includes all status counts, per-test auth mode, device model/Android version, timestamps/durations and sanitized errors.

Sanitized test outcomes persist in private Android preferences. Process death does not erase completed outcomes. Logs are application-scoped and bounded to 500 events, held in memory; no capture is claimed while the process is dead. Cold-start taps rely on the plugin's actual replay stream. Distinguish background, swipe-away/OS termination and force-stop: force-stop may suppress delivery until explicit relaunch. For restart tests, begin observation before leaving, relaunch, inspect actual tap evidence, then record the outcome.

The event store omits raw notification bodies, titles, deep links, payloads, user PII, registration tokens, JWTs, keys, headers and raw exception text. It retains presence/match flags, counts, stable errors and RTC enums/numeric reasons. No free-text report notes are accepted, preventing accidental credential export. Verify raw payload contents only through controlled Portal/device observations, then manually confirm the corresponding test.

## Reused features and unsupported boundaries

Reused `ExampleController`, readiness/permissions, MM and Chat JWT signing helpers, Inbox, User, Installation, native/embedded Chat and existing outgoing RTC screens. `HuaweiRtc.callApplication`, `hangup`, `getActiveCall`, `events`, current-call controls and notification return consumption drive RTC. `HuaweiRtcVideoView` provides local/remote rendering; `HuaweiRtcScreenAsCamera` drives capture. Token acquisition remains native. Screen navigation alone does not hang up. This documentation task changes no runtime behavior.

**Unsupported:** incoming Huawei HMS call signaling and official `enableCalls`/`enableChatCalls` parity, simulated incoming calls, multiparty video gallery, a separate screen-share track and configurable screen encoding resolution. Outgoing video requires peer confirmation of frames; outgoing audio requires real two-way media confirmation. Token success, routing, media release, background behavior and Activity recreation need real hardware/backend evidence. App cleanup should follow hangup/finished; screen navigation alone does not hang up.

See the existing [RTC scope](../doc/huawei-rtc-outgoing.md), [verification](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/huawei-rtc-outgoing-verification.md), [device plan](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/webrtc-core-device-validation.md), [WebRTC safeguards](../doc/webrtc-configuration.md), and [compatibility matrix](../API_COMPATIBILITY.md). Existing upstream authorization logging concern documented there remains outside example scope: keep raw device/SDK logs private.

## Validation

From `example/`: `flutter analyze --no-pub`, `flutter test --no-pub`. For a privately configured device host, build/run `flutter build apk --debug -t lib/main_local.dart` or the run command above. Root plugin: `flutter analyze --no-pub` and `flutter test --no-pub`. From `example/android/`, run `./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest` with Java 21 for Android 36 Robolectric coverage. Automated tests use synthetic fixtures only; they do not count as device report Passes. [Release packaging results](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/release-packaging.md) record this task; `VALIDATION.md` remains historical.

## Final configuration/authentication audit

See [CONFIG_AUTH_AUDIT.md](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/example/CONFIG_AUTH_AUDIT.md) for source-confirmed contracts, scoped defect fixes, validation and remaining UNVERIFIED items. Supplied JWTs are checked against their separate MM/widget claims and expiry; signature/backend acceptance is not inferred. An omitted Chat `exp` uses the documented `iat + 15` default. User writes use the configured identity/contacts and server re-fetch. Once Chat is prepared, restart before changing identity; hang up and await finished before user changes during RTC. A null active-call snapshot does not prove no token request is pending, so finish direct RTC call attempts before leaving to change users. Restored test outcomes are historical evidence; re-run after changing profile/user/configuration.

## Chat recovery and screen-sharing device checklist

Chat JWTs use separate widget credentials, never the MM key. Dart provider timeout
is 25 seconds, native deadline 30 seconds, with at most 32 pending requests per
side. A supplied static token cannot refresh itself. Test fresh JWT retrieval,
expiry, network failure and safe recovery. For Chat activation failure, wait at
least one second and retry Setup initialization with the same Application Code;
`chat_activation_busy` signals the cooldown or concurrent activation. Successful
method completion alone does not prove widget/backend authentication.

Screen-as-Camera is supported for the intended stable release. The current example
button heading still says “Experimental”; that is a retained runtime UI label,
not the current support classification. Runtime UI edits are outside this task.

1. Use a physical Huawei device with Android 10+, real HMS/MM configuration,
   authorized Calls routing and a receiving agent. Grant microphone/camera and
   applicable Nearby devices/notification permissions.
2. Open **Huawei RTC Video**, start a call and wait for `established`. Confirm
   two-way audio, local preview and real remote camera frames. Exercise controls;
   route availability is device-specific.
3. Keep the camera enabled and Activity focused. Press **Start Screen as Camera**,
   grant fresh Android consent and confirm the agent receives display content in
   the existing camera stream. There is no separate screen track. Validate the
   foreground capture notification, Stop action and OS privacy indicator.
4. Check asymmetric text/corner markers, portrait and landscape readability,
   aspect-preserving black bars and unmirrored local screen preview. Output is
   640×480 through the pinned RTC Core camera filter path.
5. Rotate/change captured size: a changed resize report after the initial report
   stops capture. Restart manually with new consent. Confirm no automatic reuse.
6. Stop from the example and from the notification. Confirm `framesBlocked`,
   `projectionTerminated` and `resourcesReleased`; wait for normal camera frames
   and `cameraOutputRestored`. Remote restoration still requires agent confirmation.
7. Test background capture, OS projection revocation, Activity detach/recreation,
   local/remote hangup, repeated start/stop and permission cancellation. Detach/end
   stops sharing; backgrounding alone may leave projection active. OS/vendor
   restrictions can interrupt it. Protect confidential content during testing.
8. On `screen_stop_uncertain`, do not record successful shutdown. Query capture
   state, retry Stop or use Android capture controls, and record actual results.
   Native Stop has a 3-second deadline; the Dart fallback is 5 seconds.
9. Hang up and wait for `finished` before MM cleanup/account changes. Export only
   sanitized evidence. See [screen-sharing guide](../doc/screen-sharing.md).

There are no production RTC token/signing secrets to fill in Dart. The native
provider asks the backend for a token through initialized MM. Local Chat/MM signing
helpers are controlled-test conveniences only; production issuance belongs on a
trusted backend. This run does not supply credentials or claim physical testing.
