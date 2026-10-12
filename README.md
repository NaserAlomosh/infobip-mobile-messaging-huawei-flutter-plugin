# Infobip Mobile Messaging Huawei for Flutter

A community-maintained Android Flutter package wrapping Infobip Huawei Mobile
Messaging 8.14.0 and RTC Core 2.5.28. It is not an official Infobip-maintained
Flutter package. Version **1.0.0** is being prepared for its first stable release;
this repository does not establish that it has been published.

## Features and platforms

- HMS Push registration, messages, notification taps and action taps.
- User/installation management, personalization, custom events and Mobile Inbox.
- Native and embedded Infobip Chat, native attachments, unread counters,
  view events, customization and backend JWT providers.
- Outgoing RTC application audio/video calls, local/remote camera rendering,
  microphone, audio routing and camera controls, and ongoing call notifications.
- Screen-as-Camera sharing with MediaProjection consent, foreground service,
  orientation compensation and lifecycle cleanup.

Only **Android** is registered. HMS Push needs a compatible Huawei Mobile
Services environment; validate on physical Huawei hardware. There is no iOS,
web, desktop, FCM push transport or incoming HMS RTC signaling implementation.
RTC Core retains its own legitimate Firebase/GMS transitive dependencies; this
package is not certified to be free of Google dependencies.

## Requirements

| Component | Repository requirement |
| --- | --- |
| Dart | `^3.9.0` (3.9 or later, before 4.0) |
| Flutter | `>=3.35.7` |
| Android | minSdk 26; compileSdk 36; example targetSdk 36 |
| Screen sharing | Android 10 / API 29 or later |
| Java compile target | 17; Android 36 Robolectric tests require Java 21 |
| Example tooling | AGP 8.13.0, Kotlin 2.1.0, Gradle 8.13 |
| Infobip Huawei MM / Inbox / Chat | 8.14.0 |
| Infobip RTC Core | 2.5.28 |

## Installation

For local evaluation before publication, use the checkout:

```yaml
dependencies:
  infobip_mobilemessaging_huawei:
    path: /path/to/mobile-messaging-huawei-flutter-plugin
```

Run `flutter pub get`. Once the owner has actually published 1.0.0, a hosted
`infobip_mobilemessaging_huawei: ^1.0.0` dependency can replace the path.
No release tag is assumed. Import the public library in the Dart examples below:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
```

## Huawei and Infobip host configuration

1. Register the host's exact Android application ID and signing certificate in
   AppGallery Connect, enable Push Kit, and configure the matching Huawei app
   credentials in the Infobip Mobile Messaging App Profile.
2. Place that app's private `agconnect-services.json` in `android/app/`.
   Follow [Huawei's Android integration guide](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides-V1/integrating-sdk-0000001052151811-V1)
   for host AGConnect configuration. The library declares the Huawei Maven
   repository; the host must also make it available in its repository settings.
3. Define a host-owned **numeric, nonzero `app_id` string resource** in
   `android/app/src/main/res/values/strings.xml`. It is the Huawei AppGallery App
   ID, distinct from the Infobip Application Code and Infobip Application ID.
   `HmsConfiguration` validates this resource; the JSON/manifest value alone
   does not replace it. Invalid/missing values produce `hms_configuration_missing`.
4. Use the Infobip Application Code for this App Profile in `initialize`.
   Configure the Chat widget and its installation/JWT security mode in Infobip.
   For RTC, configure a Calls routing configuration and a reachable receiving
   application/agent. Calls configuration ID is distinct from RTC push configuration ID.

Define `app_name` if you want it used for the SDK default notification title.
The plugin has no Application Code string-resource requirement.

Embedded Chat requires a host Activity derived from `FlutterFragmentActivity`:

```kotlin
package com.example.app
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity()
```

Keep the package declaration consistent with your own host. Declare/request
`POST_NOTIFICATIONS` on Android 13+, `RECORD_AUDIO` for RTC audio,
`CAMERA` for RTC video, and `BLUETOOTH_CONNECT` on Android 12+ for RTC routing.
The RTC APIs validate grants and do not request these runtime permissions.
The plugin manifest contributes microphone/camera/mediaProjection foreground
service permissions and private call/capture services. Review the merged manifest
and permission UX of your release host.

## Initialization and Chat activation recovery

```dart
Future<void> initializeMessaging(String applicationCode) async {
  InfobipMobileMessagingHuawei.defaultMessageStorage = true;
  await InfobipMobileMessagingHuawei.initialize(
    applicationCode: applicationCode,
  );
}
```

Initialize before using SDK features. Equivalent calls are idempotent; a
conflicting application code is rejected after initialization begins.
Initialization also activates Chat. If Chat activation fails, the Future rejects
with `chat_unavailable`, while Mobile Messaging remains initialized. Wait at
least one second and repeat `initialize` with the **same** application code to
retry activation without rebuilding Mobile Messaging. A retry during activation
or its cooldown returns `chat_activation_busy`. Bound retries in your host UI;
there is no autonomous infinite retry loop or separate public Chat initializer.

The default SQLite message store is enabled by default. Changing
`defaultMessageStorage` affects the next initialization after cleanup, not the
active SDK. This stores regular MM messages, not Inbox or Chat history.
`setJwt(jwt)` / `setJwt(null)` configure/clear memory-only Mobile Messaging
JWT authorization; this is separate from Chat authentication.

## HMS Push and notification events

After host notification permission handling:

```dart
Future<void> registerPush() async {
  await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
}

List<StreamSubscription<dynamic>> observeNotifications() {
  final n = InfobipMobileMessagingHuawei.notifications;
  return [
    n.onMessageReceived.listen((message) { /* Update UI safely. */ }),
    n.onNotificationTapped.listen((message) { /* Resolve allowed navigation. */ }),
    n.onNotificationActionTapped.listen((event) { /* Handle event.actionId. */ }),
    n.onRegistrationUpdated.listen((installation) { /* Refresh readiness. */ }),
    n.onInstallationUpdated.listen((installation) { /* Refresh UI. */ }),
  ];
}
```

Cancel host subscriptions when their owner is disposed. HMS token acquisition
and refresh belong to the native SDK. There is no raw token-injection API or Dart
background isolate. A pending notification tap can replay once on subscription;
other MM events are not replayed. Treat deep links and payloads as untrusted input.

## User

```dart
final cached = await InfobipMobileMessagingHuawei.getUser();
final current = await InfobipMobileMessagingHuawei.fetchUser();

final saved = await InfobipMobileMessagingHuawei.saveUser(
  UserData(firstName: 'Sam', lastName: 'Taylor'),
);

final personalized = await InfobipMobileMessagingHuawei.personalize(
  PersonalizeContext(
    userIdentity: UserIdentity(externalUserId: 'YOUR_EXTERNAL_USER_ID'),
    userAttributes: UserAttributes(firstName: 'Sam'),
  ),
);

await InfobipMobileMessagingHuawei.depersonalize();
```

`UserIdentity` supports an external user ID, phones, and emails. User attributes support names, gender, a date-only `String?` birthday in `YYYY-MM-DD` format, tags, and SDK-compatible custom attributes. Huawei custom lists use lists of records with consistent field names and scalar types; arbitrary nested JSON and scalar lists are not supported for writes. Record fields accept strings, numbers, booleans, and `DateTime`; Huawei serializes record dates as `YYYY-MM-DD` strings and date-times as ISO UTC strings, which remain strings when read back. Null values are retained where the native attribute container supports them.

Inbox results use `InboxMessage`, including rich content fields and the SDK's `sentTimestamp`. The separate `receivedTimestamp` remains available for compatibility. `depersonalizeInstallation` returns `Future<void>` and `setInstallationAsPrimary` returns `Future<List<Installation>?>`, matching official successful-null semantics.

Message `receivedTimestamp` and `seenDate` values are numeric Unix epoch milliseconds, matching the official Flutter model.

## Installation

```dart
final cached = await InfobipMobileMessagingHuawei.getInstallation();
final current = await InfobipMobileMessagingHuawei.fetchInstallation();

final saved = await InfobipMobileMessagingHuawei.saveInstallation(
  Installation(
    isPrimaryDevice: true,
    customAttributes: current.customAttributes,
  ),
);
```

Only `isPrimaryDevice`, `isPushRegistrationEnabled`, and `customAttributes` are writable. Identifiers, registration state, device data, application data, and SDK data are native-managed snapshots.

## Inbox

```dart
final inbox = await InfobipMobileMessagingHuawei.fetchInbox(
  externalUserId: 'YOUR_EXTERNAL_USER_ID',
  options: FilterOptions(
    topics: const ['support'],
    limit: 20,
  ),
);

await InfobipMobileMessagingHuawei.setInboxMessagesSeen(
  externalUserId: 'YOUR_EXTERNAL_USER_ID',
  messageIds: inbox.messages
      .map((message) => message.messageId)
      .whereType<String>()
      .toList(),
);
```

`fetchInbox` also accepts a request-scoped `jwt`. Topic and topics filters are mutually exclusive. Counts come from the server response; the plugin does not provide an authoritative offline Inbox or Inbox event stream.

## Native and embedded Chat

After successful initialization/activation, open the native screen:

```dart
Future<void> openChat() => InfobipMobileMessagingHuawei.showChat();
```

`shouldBePresentedModallyIOS` is a compatibility parameter ignored on Android.
For embedded Chat, keep one controller scoped to its attached view and provide
bounded layout:

```dart
Widget buildEmbeddedChat(InfobipHuaweiChatController controller) {
  return SizedBox(
    height: 480,
    child: InfobipHuaweiChatView(
      controller: controller,
      withInput: true,
      withToolbar: false,
      onError: (error) { /* Show a safe error. */ },
      onEvent: (event) { /* Handle typed view events. */ },
    ),
  );
}

Future<void> sendChatText(InfobipHuaweiChatController controller) async {
  await controller.send(const InfobipHuaweiChatMessagePayload.text('Hello'));
  await controller.sendContextualData('{"source":"support"}');
  await controller.setLanguage('en-US');
  await controller.setWidgetTheme('YOUR_WIDGET_THEME');
}

Future<void> closeEmbeddedChat(
  BuildContext context,
  InfobipHuaweiChatController controller,
) async {
  final handled = await controller.navigateBackOrCloseChat();
  if (!handled && context.mounted) Navigator.of(context).pop();
}
```

Create the controller with `InfobipHuaweiChatController()`. View commands require
an attached native view. Attachments remain available through the native composer;
programmatic sending is text-only. View events include loading success/failure,
connection changes, exit, theme/widget information, view changes, attachment
preview and opaque raw received messages. Handle raw content privately.
Thread-management commands and composer draft setters are unavailable.
Global `setChatCustomization` differs from view-scoped widget themes; apply global
customization before presenting Chat. See [API compatibility](API_COMPATIBILITY.md).

## Chat unread counters and JWT authentication

```dart
Future<int> readChatUnread() =>
    InfobipMobileMessagingHuawei.chat.getUnreadMessageCount();

StreamSubscription<int> observeChatUnread(void Function(int) updateBadge) =>
    InfobipMobileMessagingHuawei.chat.onUnreadMessageCounterUpdated.listen(
      updateBadge,
    );

Future<void> configureChatJwt(
  Future<String> Function() fetchBackendChatJwt,
) async {
  await InfobipMobileMessagingHuawei.setChatJwtProvider(
    fetchBackendChatJwt,
    (error) { /* Show a safe authentication error; never log tokens. */ },
  );
}
```

The backend must authenticate your user and issue a short-lived JWT for the
configured widget/identity. Personalize with the matching external user ID where
required by widget security. The provider is invoked when native Chat requests a
token; it should fetch a fresh token with its own network timeout. It is independent
of `setJwt` and request-scoped Inbox JWTs. No public provider-clear method exists;
successful cleanup clears it, and replacing the provider invalidates old requests.

**JWT deadlines:** Dart bounds each provider request at **25 seconds**, while the
native bridge independently expires it at **30 seconds**. Each side permits at
most **32 pending requests**. Errors, blank tokens, timeouts and overflow reject
requests safely; late results cannot complete a superseded request. An underlying
Dart Future cannot be cancelled, so timeout does not stop your backend request.
The optional error callback receives provider failures; do not log sensitive errors.
Unread updates do not replay; query the current count when attaching a badge.
`getMessageCounter`, `resetMessageCounter`, and `isChatAvailable` also exist.

## Outgoing RTC configuration, audio and video

Initialize MM, complete registration if using its default identity, grant call
permissions, and start from a resumed Activity. Calls use backend-issued tokens
acquired **natively** through initialized MM; no Dart token setter is exposed.
The host/backend must authorize any supplied identity. An omitted identity uses
the installation's `pushRegistrationId`. Routing chooses the peer; there is no
callee parameter. Do not pass `WebRTCUI` to enable this outgoing extension.
Official `enableCalls`, `enableChatCalls` and `disableCalls` remain guarded;
`infobipWebRtcEnabled=true` is rejected by Gradle.

```dart
StreamSubscription<HuaweiRtcEvent> observeCalls(
  void Function(HuaweiRtcEvent) updateCall,
) => HuaweiRtc.events.listen(
  updateCall,
  onError: (Object error) { /* Handle a safe call error. */ },
);

Future<HuaweiRtcCall> startAudio(String callsConfigurationId) =>
    HuaweiRtc.callApplication(HuaweiRtcCallRequest(
      callsConfigurationId: callsConfigurationId,
      type: HuaweiRtcCallType.audio,
    ));

Future<HuaweiRtcCall> startVideo(String callsConfigurationId) =>
    HuaweiRtc.callApplication(HuaweiRtcCallRequest(
      callsConfigurationId: callsConfigurationId,
      type: HuaweiRtcCallType.video,
    ));
```

Subscribe before starting. Completion means a native call object exists, not
that the peer answered. Use `established` and `finished` events and native status.
Events also include state snapshots, ringing, early media, errors, reconnecting,
reconnected and notification return. SDK errors are numeric `nativeErrorCode`;
an error callback is not necessarily terminal. Snapshots include SDK duration.
There is one active call **or pending request** per process. A second start is
rejected. The token wait is bounded at 30 seconds. `getActiveCall()` may be null
while token acquisition is pending; this does not authorize a second call.

## Local and remote video rendering

```dart
Widget buildVideo(String callId) => Row(children: [
  Expanded(child: SizedBox(
    height: 240,
    child: HuaweiRtcVideoView(callId: callId, source: HuaweiRtcVideoSource.local),
  )),
  Expanded(child: SizedBox(
    height: 240,
    child: HuaweiRtcVideoView(callId: callId, source: HuaweiRtcVideoSource.remote),
  )),
]);
```

Use the current native video call ID and bounded dimensions. Remote rendering
pins one unambiguous camera endpoint; unavailable/ambiguous sources remain blank.
There is no multiparty gallery or separate remote screen-track selector.
Views suspend on inactive/paused/detached Flutter lifecycle and recreate on resume.
Disposing a view releases its renderer, not the SDK track or call. Local preview
shows the substituted screen during sharing; front-camera selfie mirroring is
restored after sharing stops.

## RTC call controls and notifications

```dart
Future<void> updateCallControls(String callId) async {
  await HuaweiRtc.setMicrophoneMuted(true, callId: callId);
  await HuaweiRtc.setSpeakerEnabled(true, callId: callId);
  final controls = await HuaweiRtc.getCallControls(callId: callId);
  if (controls.availableAudioOutputs.contains(HuaweiRtcAudioOutput.earpiece)) {
    await HuaweiRtc.selectAudioOutput(HuaweiRtcAudioOutput.earpiece, callId: callId);
  }
}

Future<void> updateVideoControls(String callId) async {
  await HuaweiRtc.setCameraEnabled(true, callId: callId);
  await HuaweiRtc.switchCamera(callId: callId);
}

Future<HuaweiRtcCall?> consumeCallNotification() =>
    HuaweiRtc.takeNotificationCall();
```

Mutations require an established foreground call and its current ID. Returned
`HuaweiRtcControls` are SDK readback, not optimistic state. Speaker-off selects
earpiece explicitly and fails if absent. Audio outputs depend on device/headset
and permissions. Camera controls require video; switching also requires the camera
enabled. Camera switching/toggling is locked while capture or its shutdown is busy.

A native microphone/camera foreground service starts before media. Its ongoing
notification offers return-to-call and hangup. Grant notification permission on
Android 13+ to see it in the drawer; denial does not waive foreground-service
requirements. Handle `returnToCall`, and check `takeNotificationCall()` on initial
attachment/resume; consume the tap and open your existing call screen, without
starting a new call. Stale taps return null. Navigation away does not hang up.
Activity recreation preserves call ownership; engine disposal attempts hangup.
Background media and vendor power-management behavior require physical testing.

## Screen sharing

Screen-as-Camera is a supported feature of the intended stable release on
Android 10+. It replaces outgoing camera video through a public `VideoFilter`:
**Screen → MediaProjection → ImageReader → Bitmap → VideoFilter → Infobip RTC**.
The camera must remain enabled; this is not a separate screen-sharing track.

```dart
Future<ScreenAsCameraState> startScreen(String callId) =>
    HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: callId);

Future<ScreenAsCameraState> stopScreen(String callId) =>
    HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: callId);

StreamSubscription<ScreenAsCameraState> observeScreen(
  void Function(ScreenAsCameraState) update,
) => HuaweiRtcScreenAsCamera.states.listen(update);
```

Start with an established video call, enabled camera and focused Activity.
Every start requests fresh Android user consent; tokens are never saved/reused.
A mediaProjection foreground service provides a capture notification and Stop
action. Capture may continue in the background while the Activity remains
attached; Activity detach, call end or OS projection revocation triggers Stop.
Stopping restores normal camera output as frames resume.

Output through RTC Core 2.5.28 is **640×480**. Aspect-preserving fit-center drawing
uses black bars; portrait text has limited horizontal detail. Screen publication
compensates the SDK's horizontal transformation. During substitution the local
preview is unmirrored and uses fit scaling; normal front-camera mirroring returns
on Stop. Real resize callbacks after the initial size report trigger Stop, requiring
fresh consent to restart; rotation is not seamless capture resizing.

See the [screen-sharing guide](docs/screen-sharing.md) for shutdown deadlines,
state flags, privacy and device checks. Earlier POC/audit reports are historical
records, not the current support statement.

## Cleanup

Request `HuaweiRtc.hangup()` and await its `finished` event before MM cleanup,
relogin or changing users. Screen Stop is independently awaitable. Confirm
`projectionTerminated` and `resourcesReleased`; a successful Stop can still report
`cameraOutputRestored=false` until a normal camera frame arrives. On
`screen_stop_uncertain`, query `getScreenAsCameraState(callId: ...)` and retry Stop
or use Android capture controls; do not assume the projection has ended.

`InfobipMobileMessagingHuawei.cleanup()` removes local SDK data/state; use
`depersonalize()` for normal sign-out. Concurrent cleanup calls share one Future.
Initialization and Chat configuration during cleanup reject with
`operation_in_progress`. Rejection preserves Dart Chat callbacks/subscriptions;
success clears providers/handlers and requires reinitialization. Native cleanup
runs before plugin state is cleared. The vendor SDK's internal cleanup is not
rollback-capable: a partial vendor failure is not guaranteed to be atomic.
Cancel your own view/event subscriptions when disposing their owner.

## Security and limitations

Use backend-issued RTC/Chat JWTs; never hardcode production keys, signing secrets,
JWTs or user credentials. Avoid logging tokens, authorization headers, raw SDK
errors, private messages or screen content. Keep test APKs and logs private.
MediaProjection may capture confidential content outside the app: explain scope,
provide Stop, and respect OS secure-content restrictions.

**Unresolved upstream security issue:** Huawei Mobile Messaging SDK **8.14.0**
contains authorization-header logging in its own `AuthorizationUtils` dependency.
The upstream Infobip RTC SDK **2.5.28** also logs raw signaling messages through
stdout; these may expose temporary TURN usernames and credentials. Both behaviors
originate in upstream SDK components. Setting the RTC logger to OFF does not
disable their direct stdout calls.

An **optional R8 workaround** is retained in
[`example/android/app/proguard-rules.pro`](example/android/app/proguard-rules.pro).
It removes matching `PrintStream.print/println` calls **application-wide**, including
stderr and functional stream/file output. Consuming applications can copy the rule
to a dedicated Release rules file and enable R8 with optimization; follow the
[consumer opt-in instructions](SECURITY.md#consumer-application-opt-in).
R8 must be enabled and optimization effective for the workaround to take effect.
The plugin does **not** impose it through `android/consumer-rules.pro`.

The rule **does not guarantee removal of all sensitive logs**: RTC's direct
`printf` call and other logging APIs are outside its scope. Existing disassembly
proves removal only of the identified MM println in the example's unsigned
optimized Release APK; signed-device verification is **UNVERIFIED**. Debug retains
the upstream paths. See [SEC-01 evidence](docs/sec01-release-logging-mitigation.md)
and the [sanitized Infobip disclosure draft](docs/sec01-infobip-responsible-disclosure.md).
SEC-01 is **PARTIALLY MITIGATED**; this package is **not security-certified**.
The owner has decided not to submit a vendor report before publication. Vendor
disclosure, acknowledgment or remediation is not a package publication gate.
This decision records the unresolved risk; it does not close SEC-01 or establish
production security certification. See [security guidance](SECURITY.md) and the
[current publication checklist](docs/publication-readiness.md).

Other limits: no incoming HMS RTC, screen-track API, configurable screen encoding
resolution or background Dart handler. Real backend token acceptance, Huawei
notifications/media, JNI/surface behavior and device performance are unverified
by unit tests. A LICENSE is currently missing and blocks publication.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `hms_configuration_missing` | Numeric host `app_id`; JSON alone is insufficient |
| No push | Registered package/signing certificate, Push Kit/App Profile, HMS Core, permissions, network and Huawei battery settings |
| `chat_unavailable` / `chat_activation_busy` | Initialization, widget configuration; retry same code after one second |
| Chat JWT timeout | Backend latency, separate widget credentials/identity, 25s Dart and 30s native deadlines |
| Embedded Chat unavailable | FragmentActivity, bounded attached native view, successful Chat activation |
| RTC rejection / numeric 10300 | Account/token authorization and Calls routing; numeric reason alone does not establish root cause |
| RTC controls unavailable | Current call ID, established foreground state, permission and available route |
| `screen_camera_required` / `screen_camera_locked` | Established video, camera enabled/focused Activity; finish Stop before camera changes |
| Screen stops on rotation | Resize-triggered Stop is intentional; restart with new consent |
| Tiny portrait text | 640×480 output and aspect-preserving bars; use landscape or larger text |
| `screen_stop_uncertain` | Inspect projection/resource state; retry Stop or use OS capture controls |

## Example and release preparation

Follow [example/README.md](example/README.md) for the actual ignored Dart
configuration, host setup, running on a physical Huawei device, and Push/Chat/RTC/
screen-sharing checks. It uses `tool/prepare_local.dart` and `main_local.dart`,
not JSON Dart defines. No real credentials are included in this documentation.

[Release packaging report](docs/release-packaging.md) records validation results
and remaining publication gates. Historical research and device audit records
remain in `docs/`; their earlier scope/results must not be read as current
feature omissions or present-day certification.
