# Infobip Mobile Messaging Huawei for Flutter

A community-maintained Android Flutter plugin for Infobip Huawei Mobile Messaging
8.14.0 and RTC Core 2.5.28. This is not an official Infobip-maintained Flutter
package. Version **1.0.0** is being prepared for publication.

## Features

- HMS Push registration, messages, notification taps and action taps.
- User and installation management, personalization, custom events and Mobile Inbox.
- Native and embedded Chat, native attachments, unread counters and backend JWT providers.
- Outgoing RTC audio/video calls, local/remote rendering, call controls and notifications.
- Android Screen-as-Camera sharing with consent, capture notification and camera restoration.

## Requirements

| Component | Requirement |
| --- | --- |
| Dart / Flutter | `^3.9.0` / `>=3.35.7` |
| Android | minSdk 26; compileSdk 36; example targetSdk 36 |
| Screen sharing | Android 10 / API 29+ |
| Java compilation | 17 |
| Example tooling | AGP 8.13.0, Kotlin 2.1.0, Gradle 8.13 |
| Infobip Huawei MM / Inbox / Chat | 8.14.0 |
| Infobip RTC Core | 2.5.28 |

HMS Push requires a compatible Huawei Mobile Services environment. Validate your
integration on physical Huawei hardware. Android 36 Robolectric tests require Java 21.

## Installation

Before publication, use a local checkout:

```yaml
dependencies:
  infobip_mobilemessaging_huawei:
    path: /path/to/mobile-messaging-huawei-flutter-plugin
```

Run `flutter pub get`. After 1.0.0 is published, replace the path dependency with
`infobip_mobilemessaging_huawei: ^1.0.0`.

## Android / Huawei Configuration

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

## Initialization

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<void> initializeMessaging(String applicationCode) async {
  await InfobipMobileMessagingHuawei.initialize(applicationCode: applicationCode);
}
```

Initialize before using SDK features. Initialization also activates Chat. If it
fails with `chat_unavailable`, Mobile Messaging remains initialized: wait at least
one second and retry with the **same** application code. A concurrent/cooldown
retry returns `chat_activation_busy`. Bound retries in your application.

The default message store is enabled. MM `setJwt` authorization is separate from
Chat JWT authentication. See [messaging and Chat integration](docs/messaging-chat.md)
for storage settings, user/installation examples, Inbox, JWTs and cleanup.

## Push Notifications

After requesting notification permission in your host:

```dart
Future<StreamSubscription<Message>> registerPush() async {
  final subscription = InfobipMobileMessagingHuawei.notifications
      .onNotificationTapped.listen((message) { /* Resolve allowed navigation. */ });
  await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
  return subscription;
}
```

Cancel subscriptions when their owner is disposed. HMS token acquisition/refresh
belongs to the native SDK. A pending notification tap can replay once on subscription;
other MM events do not replay. Treat payloads and deep links as untrusted input.
See [notification event examples](docs/messaging-chat.md#hms-push-and-notification-events).

## Chat Integration

After successful initialization, open native Chat:

```dart
Future<void> openChat() => InfobipMobileMessagingHuawei.showChat();
```

For embedded Chat, use `InfobipHuaweiChatView` with one
`InfobipHuaweiChatController` per attached view, bounded layout and a
`FlutterFragmentActivity` host. Native composer attachments are supported;
programmatic sending is text-only. Unread updates do not replay: query the current count.

Use `setChatJwtProvider` to retrieve fresh backend-issued widget/identity tokens.
MM/Inbox JWTs use separate contracts. Provider requests expire after 25 seconds in
Dart and 30 seconds natively, with 32 pending requests per side. Bound your backend
network work too. See [Chat examples and authentication](docs/messaging-chat.md#native-and-embedded-chat)
and the [API compatibility reference](API_COMPATIBILITY.md).

## RTC Audio / Video Calls

Initialize MM, register if using the default installation identity, grant call
permissions and start from a resumed Activity. The native provider acquires RTC
tokens through initialized MM; your backend must authorize the identity and routing.
Calls configuration ID is distinct from RTC push configuration ID. Routing selects
the peer; there is no callee argument.

```dart
StreamSubscription<HuaweiRtcEvent> observeCalls(
  void Function(HuaweiRtcEvent) updateCall,
) => HuaweiRtc.events.listen(
  updateCall,
  onError: (Object error) { /* Handle a safe call error. */ },
);

Future<HuaweiRtcCall> startVideo(String callsConfigurationId) =>
    HuaweiRtc.callApplication(HuaweiRtcCallRequest(
      callsConfigurationId: callsConfigurationId,
      type: HuaweiRtcCallType.video, // Use .audio for an audio-only call.
    ));
```

Subscribe before starting. Method completion means a native call object exists;
await `established` for connection and `finished` for termination. Only one active
call or pending request is allowed. `getActiveCall()` can be null during token fetch.

Use `HuaweiRtcVideoView` for bounded local/remote views and `HuaweiRtc` controls
for mute, speaker/audio routes and camera enable/switch. Mutations require the
current ID and an established foreground call. Handle `returnToCall` and consume
`takeNotificationCall()` on attachment/resume to restore your existing call screen.
Navigation away does not hang up. Hang up and await `finished` before MM cleanup
or account changes. See the [RTC integration guide](docs/huawei-rtc-outgoing.md)
for rendering, controls, notifications, events and errors.

## Screen Sharing

Screen-as-Camera replaces the outgoing camera stream on Android 10+; it does not
create a separate screen track. Start with an established video call, enabled
camera and focused Activity:

```dart
Future<ScreenAsCameraState> startScreen(String callId) =>
    HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: callId);

Future<ScreenAsCameraState> stopScreen(String callId) =>
    HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: callId);
```

Every start requires fresh Android consent. Capture has a foreground notification
and Stop action. Backgrounding may leave capture active; Activity detach, call end,
revocation or a changed resize report triggers Stop. Restart requires new consent.

Output is **640×480**, fitted with black bars; portrait text has limited detail.
Camera switching/toggling is locked during capture/shutdown. Confirm
`projectionTerminated` and `resourcesReleased` after Stop. On
`screen_stop_uncertain`, query state and retry Stop or use Android capture controls.
`cameraOutputRestored` confirms local submission, not remote display.
See the [screen-sharing guide](docs/screen-sharing.md) for states, privacy and device checks.

## Known Limitations

- Android only; no iOS, web, desktop, FCM push transport or Dart background isolate.
- Incoming HMS RTC and official `enableCalls`/`enableChatCalls` parity are unsupported.
  `infobipWebRtcEnabled=true` is rejected; see [WebRTC safeguards](docs/webrtc-configuration.md).
- RTC Core retains Firebase/GMS transitive dependencies; Google-free operation is not certified.
- No multiparty gallery, separate screen track, screen-resolution setting or seamless resize.
- Chat thread management and composer draft setters are unavailable.
- Real backend acceptance, HMS delivery, signed/minified hosts, OEM lifecycle,
  GL/JNI behavior, 16 KB runtime compatibility and performance require device validation.

Follow the [example guide](example/README.md) for private configuration and manual checks.
Historical audit reports remain in Git and are excluded from the pub.dev package.

## Security

**SEC-01 remains PARTIALLY MITIGATED; this package is not security-certified.**
Huawei MM 8.14.0 logs authorization headers upstream. RTC 2.5.28 logs signaling
messages that may expose temporary TURN credentials; setting its logger to OFF
does not disable direct stdout calls.

The optional host Release R8 workaround removes matching `print/println` calls
**application-wide**, including functional stream/file output. It requires R8
optimization, does not cover RTC `printf`, and does not guarantee removal of all
sensitive logs. Read [SECURITY.md](SECURITY.md) before production integration.
Vendor reporting is not a publication requirement and does not resolve this issue.

Use backend-issued tokens; never embed production signing secrets or log tokens,
headers, messages, raw SDK errors or captured content. Explain MediaProjection's
scope and provide Stop: it can capture private content outside your app.

## License

A root LICENSE has not yet been authorized or added. Publication remains blocked
until the owner supplies the license and confirms redistribution rights. No license
or third-party permission is inferred from this repository.
