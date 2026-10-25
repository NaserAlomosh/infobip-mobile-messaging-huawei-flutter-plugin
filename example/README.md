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

## One private JSON configuration

Validated with Flutter 3.35.7 / Dart 3.9.2 and Java 21. Flutter 3.47.7
requires a newer Gradle wrapper than this branch provides; this task does not
upgrade the Android toolchain. Use the validated baseline for these commands.

From a fresh checkout:

```sh
git clone https://github.com/NaserAlomosh/infobip-mobile-messaging-huawei-flutter-plugin.git
cd infobip-mobile-messaging-huawei-flutter-plugin/example
flutter pub get
cp -n example_config.example.json config/example_config.local.json
```

Edit `config/example_config.local.json` using the field table below, then complete
[Huawei Android host setup](#huawei-android-host-setup). The `cp -n` command
preserves an existing file. Use JSON strings, numeric integers, booleans and an
object for `installationAttributes`, matching the template types. Then run:

```sh
flutter run
```

If multiple devices are connected, use `flutter devices`, then
`flutter run -d YOUR_HUAWEI_DEVICE_ID`. `lib/main.dart` is the canonical entry point.
It loads the optional private JSON from the declared `config/` asset directory.
The tracked directory marker allows a clean checkout to compile without private
files. Missing configuration uses empty defaults and the Test Center shows missing
prerequisites; malformed JSON or incorrect value types shows a safe configuration
error without printing values. No optional Dart import or launcher generation is used.

To update configuration, edit the same JSON file, stop the app, then run:

```sh
flutter run
```

A full stop/rebuild is required after adding or changing assets; hot reload is
insufficient. For missing Application Code, set `infobipApplicationCode`. For
blocked RTC, configure routing below and complete registration/permissions. If
values appear ignored, check the exact path and rebuild. JSON keys are case-sensitive.
The old uppercase `INFOBIP_*` JSON format is obsolete; use the current template.

Existing users: copy values from your private `lib/config/example_test_config.dart`
into the matching JSON keys once. The old private file and `main_local.dart` remain
ignored and are never overwritten, but are no longer needed. The Dart template is
retained only as a legacy field reference; new setup uses the JSON template.
All feature controllers still receive the same `ExampleConfig` object.

Private JSON and old private Dart files are excluded from Git and pub.dev packaging.
JSON assets are extractable from built apps: use only test values and keep APKs
private, just as with the former compiled Dart configuration. Do not place unrelated
private files in `config/`, because Flutter bundles that directory.

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

## Configure Infobip RTC Calls Routing

1. A **Calls Configuration ID** selects the application handling an outgoing RTC
   call. It is not a callee, Chat widget ID, Application Code, or push identifier.
   For a custom application, ask your backend administrator for the ID created
   through the [Calls Configuration API](https://www.infobip.com/docs/voice-and-video/calls).
2. Choose the destination with your administrator. Infobip documents
   [a built-in Conversations destination](https://github.com/infobip/infobip-rtc-android/wiki/InfobipCallsConfiguration):
   `InfobipCallsConfiguration.CONVERSATIONS.getCallsConfiguration()`. In the
   pinned RTC Android 2.5.28 SDK its literal value is `conversations`.
   This is a standard destination identifier, **not an account-generated ID**,
   but it is **not a universal working default**: your account must have
   Conversations calling enabled and the appropriate routing/receiving agents.
   The empty example default requires an explicit choice; use `conversations`
   only for an enabled Conversations integration, or your custom Calls ID.
3. Ask the account administrator to enable Web and In-app Calls and confirm the
   receiving destination. For Conversations, confirm the linked integration,
   routing/assignment and an available agent able to accept the call. For a custom
   Calls application, the backend needs event subscriptions and call-control logic
   to accept and connect the call. Generic Calls API events do not expose calls
   managed by Conversations. No unverified Portal menu path is assumed here.
4. Set `rtcCallsConfigurationId` in the example's private JSON. The example passes
   it unchanged to `HuaweiRtcCallRequest.callsConfigurationId`, through the channel
   and native `CallApplicationRequest`. A consumer uses the public API as follows:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<void> callConfiguredDestination(String callsConfigurationId) async {
  // Initialize Mobile Messaging, wait for registration, and grant microphone
  // permission first. Supply an administrator-confirmed destination ID.
  await HuaweiRtc.callApplication(HuaweiRtcCallRequest(
    callsConfigurationId: callsConfigurationId,
    type: HuaweiRtcCallType.audio,
  ));
}
```

5. The RTC token is obtained natively through initialized Mobile Messaging;
   there is no Dart RTC token field. Default caller identity is the registered
   installation; an explicit identity must be authorized. MM/Chat JWTs remain
   separate contracts. An **RTC Push Configuration ID** configures RTC push
   registration (`WebRTCUI.configurationId`), not outgoing routing. Do not pass
   it as this Calls ID. It does not enable background incoming HMS calls here.
6. Test on a physical Huawei device: initialize/register, grant permissions,
   have the intended agent ready, start audio, observe `established`, confirm
   the intended agent receives it and verify two-way media. Hang up and wait for
   `finished`. Repeat with video and camera permission. A returned call object
   or successful token request alone is not proof of routing or media delivery.

Troubleshooting: a blank ID is rejected locally; an unknown/unauthorized ID needs
administrator verification. For token failures, check initialization, registration
and authorized caller identity. If no agent receives the call, confirm the chosen
application, account entitlement, routing, agent availability and backend handling.
For permission/network/media errors, check device permissions and connectivity
separately. Do not replace the Calls ID with a Push ID, widget ID or guessed value.

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

Reused `ExampleController`, readiness/permissions, MM and Chat JWT signing helpers, Inbox, User, Installation, native/embedded Chat and existing outgoing RTC screens. `HuaweiRtc.callApplication`, `hangup`, `getActiveCall`, `events`, current-call controls and notification return consumption drive RTC. `HuaweiRtcVideoView` provides local/remote rendering; `HuaweiRtcScreenAsCamera` drives capture. Token acquisition remains native. Screen navigation alone does not hang up. Configuration loading changes only example startup; SDK authentication and RTC behavior are unchanged.

**Unsupported:** incoming Huawei HMS call signaling and official `enableCalls`/`enableChatCalls` parity, simulated incoming calls, multiparty video gallery, a separate screen-share track and configurable screen encoding resolution. Outgoing video requires peer confirmation of frames; outgoing audio requires real two-way media confirmation. Token success, routing, media release, background behavior and Activity recreation need real hardware/backend evidence. App cleanup should follow hangup/finished; outgoing screen navigation alone does not hang up. Incoming screen disposal requests termination as described below.

See the existing [RTC scope](../doc/huawei-rtc-outgoing.md), [verification](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/huawei-rtc-outgoing-verification.md), [device plan](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/webrtc-core-device-validation.md), [WebRTC safeguards](../doc/webrtc-configuration.md), and [compatibility matrix](../API_COMPATIBILITY.md). Existing upstream authorization logging concern documented there remains outside example scope: keep raw device/SDK logs private.

## Validation

From `example/`: `flutter analyze --no-pub`, `flutter test --no-pub`. For a privately configured device host, build/run `flutter build apk --debug` or the run command above. Root plugin: `flutter analyze --no-pub` and `flutter test --no-pub`. From `example/android/`, run `./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest` with Java 21 for Android 36 Robolectric coverage. Automated tests use synthetic fixtures only; they do not count as device report Passes. Rerun these checks for your checkout; old validation counts are not current release evidence.

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

## Live Chat identity for outgoing RTC

The audio/video screen keeps the configured `rtcIdentity` (or installation
fallback) by default. Enable **Use Live Chat customer identity** to demonstrate
the production opt-in `liveChatIdentity` request. Configure `chatWidgetId` to match
the Chat widget exactly and complete personalization as `externalUserId` first.
The native call flow resolves the registration; the example never handles or
displays it. Failures are sanitized and do not fall back to another identity.
See [Dart usage, failures and SDK compatibility](../doc/huawei-rtc-customer-identity.md).
Correct customer name/email was observed on Huawei devices; internal People
Person ID equality is not established. Every outgoing call may create a new
Conversation; no supported way to force reuse is verified. Agent-initiated
application calls use the separate experimental foreground flow described below.

## Experimental foreground incoming calls

The RTC screen supports explicit Start, audio acceptance, camera-enabled video
acceptance and Decline, with native ringtone and existing video/media controls.
Initialize and personalize the configured user, use the matching Chat widget,
grant call permissions and keep the Activity resumed. Follow the
[consumer guide](../doc/huawei-rtc-incoming.md) for states, errors and lifecycle
limitations. These APIs are unreleased additions, absent from published 1.0.1.

Background/terminated-app delivery is unsupported. Account changes and engine
detach invalidate the process-scoped registration; retry requires process
recreation. No supported token replacement or unregister exists. Offered media
type remains unknown; video acceptance is an explicit local camera choice.
Incoming auto-reconnect is disabled, and Conversation reuse is not established.
The example closes the incoming flow on screen disposal, requesting termination;
it does not unregister signaling. This differs from outgoing screen navigation.

## Support This Project

Support ongoing maintenance through [GitHub Sponsors](https://github.com/sponsors/NaserAlomosh).
