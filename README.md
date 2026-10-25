# Infobip Mobile Messaging Huawei for Flutter

A community-maintained Android Flutter plugin for Infobip Huawei Mobile Messaging
8.14.0 and RTC Core 2.5.28. This is not an official Infobip-maintained Flutter
package. Install the [published package on pub.dev](https://pub.dev/packages/infobip_mobilemessaging_huawei).
This README describes the current checkout, including unreleased RTC additions.
Published **1.0.1** does not include the Live Chat identity option or experimental
foreground incoming APIs described below. The installation example remains on
the published version until a new release is prepared.

## Contents

- [Features and support](#features-and-support)
- [Requirements](#requirements) and [installation](#installation)
- [Quick start](#quick-start)
- [Huawei AppGallery Connect setup](#huawei-appgallery-connect-setup)
- [Infobip Portal setup](#infobip-portal-setup)
- [Android configuration and permissions](#android-configuration)
- [SDK initialization and authentication](#flutter-initialization)
- [Push notifications](#push-notifications)
- [Live Chat and lifecycle](#chat-integration)
- [User, installation, Inbox and custom events](#inbox-and-user-management)
- [Outgoing RTC audio and video](#rtc-audio--video-calls)
- [RTC rendering and controls](#rtc-rendering-and-controls)
- [Experimental foreground incoming RTC](#experimental-foreground-incoming-rtc)
- [Screen sharing](#screen-sharing)
- [Configuration reference](#configuration-reference)
- [Error handling](#error-handling) and [troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)
- [Example application](#example-application)
- [Security](#security), [documentation](#documentation), and [license](#license)

## Features and support

“Supported” describes implemented APIs, not certification of your device or account.
Unreleased rows require this repository checkout; they are absent from pub.dev 1.0.1.

| Feature | Status | Entry point |
| --- | --- | --- |
| Application Code initialization, optional MM JWT | Supported | `initialize`, `setJwt` |
| HMS Push, registration, messages, taps and action taps | Supported; delivery depends on HMS/OS | `notifications`, `registerForRemoteNotifications` |
| User, installation, personalization, custom events, Inbox | Supported | `personalize`, `saveUser`, `saveInstallation`, `submitEvent`, `fetchInbox` |
| Native/embedded Live Chat, attachments, events, JWT provider | Supported | `showChat`, `InfobipHuaweiChatView`, `setChatJwtProvider` |
| Outgoing application audio/video and media controls | Supported | `HuaweiRtc.callApplication` |
| Live Chat identity for outgoing RTC | Supported, unreleased opt-in | `HuaweiRtcLiveChatIdentity` |
| Foreground incoming audio/video, Accept/Decline, ringtone | Experimental, unreleased | `startForegroundIncomingExperiment` |
| Screen-as-Camera | Supported, Android 10+; 640×480 output | `HuaweiRtcScreenAsCamera` |
| Background/terminated incoming RTC, HMS RTC push | Unsupported | No supported API |
| Official RTC UI `enableCalls` / `enableChatCalls` | Guarded, unsupported | Do not enable `WebRTCUI` |
| iOS, web, desktop, FCM push, Dart background isolate | Unsupported | Android/HMS only |

RTC Core has Firebase/GMS transitive dependencies; Google-free operation is not certified.

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

Install the package from pub.dev:

```sh
flutter pub add infobip_mobilemessaging_huawei
```

Or add it to your host application's `pubspec.yaml`, then run `flutter pub get`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  infobip_mobilemessaging_huawei: ^1.0.1
```

The example uses a local path dependency to test the repository checkout. Use
the hosted dependency above for released APIs. To evaluate the unreleased rows,
clone this repository and point your host at that checkout instead:

```yaml
dependencies:
  infobip_mobilemessaging_huawei:
    path: ../infobip-mobile-messaging-huawei-flutter-plugin
```

Replace the relative path with your actual checkout location. Do not declare both
hosted and path dependencies. A `^1.0.1` install does not provide unreleased APIs.

## Quick Start

Complete these steps in order before calling Dart APIs:

1. Create the Huawei Android app, register your actual signing certificate,
   enable Push Kit, and download its configuration file.
2. Create an Infobip mobile application profile, enable Huawei push and save its
   matching Huawei credentials. Copy the **Application Code**.
3. Configure your Android host's JSON, numeric `app_id`, Gradle and permissions.
4. Attach event listeners, initialize with the Application Code, then register push.
5. Confirm registration and deliver one test push on a physical Huawei device.
6. Add Chat or RTC only after configuring those optional services in Infobip.

The examples below use the public package import. Application codes and routing
IDs are configuration, not JWT signing keys. Pass values from your application's
configuration; never put production signing secrets in Dart or build defines.

## Huawei AppGallery Connect Setup

You need a Huawei developer account with access to AppGallery Connect (AGC).
Menu labels can vary; the following uses logical sections rather than assuming
an exact current portal layout. See [Huawei's Android integration guide][huawei-guide]
and [Infobip's AGC setup guide][agc-guide].

1. Sign in to AppGallery Connect and create or select a project for your app.
2. Add an **Android / mobile phone** application to that project. Enter its name
   and the exact package name from `applicationId` in your host's
   `android/app/build.gradle.kts` (or `build.gradle`). `namespace` alone is not
   the installed package. Each flavor/application-ID suffix must match its AGC app.
3. Obtain the SHA-256 fingerprint of the certificate signing the installed APK:

   ```sh
   cd android
   ./gradlew :app:signingReport
   ```

   Add that fingerprint in the app's signing-certificate information in AGC.
   Configure debug and release certificates as appropriate; with store signing,
   use the certificate signing the delivered app. Never upload a private keystore.
4. In the project's API/service management, enable **Push Kit** for the app.
   Complete any Push Kit activation or data-location prompts shown by AGC.
5. Download **`agconnect-services.json`** from this Android app's configuration
   information after the package/signing/service settings are saved. Refresh the
   download when configuration changes. Place it at:

   ```text
   your_flutter_app/android/app/agconnect-services.json
   ```

   Keep environment-specific files private and out of public source control.
6. Find the **Huawei App ID** in the app information, or `client.app_id` in the
   downloaded JSON. It is a numeric ID. Copy it to the host string resource
   described below. Do not use the app secret, client ID or package name there.
7. Find the matching Huawei **App Secret** in the app's credential information.
   Configure this only in the Infobip profile's Huawei push settings; it is not
   a Flutter initialization argument. Do not paste it into the README or Dart.
8. Configure Gradle as below and install on a physical Huawei device with a
   compatible, updated **HMS Core**. Check HMS Core in the device's installed apps
   and resolve service/update prompts. An emulator or successful compilation
   does not establish HMS availability. This plugin has no public HMS-availability
   check method; verify registration and delivery using the Push section.

**Huawei App ID, Infobip Application Code, Infobip Application ID and RTC Calls
Configuration ID are different values and cannot be substituted for one another.**

## Infobip Portal Setup

You need an Infobip account with access to Mobile App Messaging and the products
you intend to use. Ask your account administrator to enable the products and
assign appropriate permissions. Chat additionally needs the Live Chat/Conversations
setup and an available agent; RTC requires Web and In-app Calls entitlement.

### Mobile Messaging and Huawei push

1. Open the mobile application profiles section of the Infobip web interface.
   Create a Sandbox profile for testing; use a separate Production profile when
   appropriate. Give it a recognizable name.
2. Enable its **Huawei** environment and supply the matching Huawei **App ID**
   and **App Secret** from AGC in the Huawei push credential settings. These are
   server-side push credentials, not Google Firebase credentials. Save the profile.
3. Copy its generated **Application Code** to Dart's `applicationCode`. Keep the
   profile, JSON, Android package, Huawei ID and signing fingerprint aligned.
4. Review profile security for user-data operations and Mobile Inbox. JWT policy
   may require backend-issued tokens. Production Inbox uses JWT authorization;
   Sandbox can use Application Code or JWT. Never weaken policy to hide an auth failure.
5. After installation registration, send a test push to that profile's test device
   using Infobip's push messaging tools. Confirm receipt and a notification tap.

See [mobile application profiles][profile-guide] for current account configuration.
The Android environment there describes Firebase; this plugin uses **Huawei**.

### Optional Chat

Create a Live Chat widget, connect it to your Mobile Messaging profile, and
configure routing/agent availability. Select the widget's installation/security
mode to match your app. Widget configuration is synchronized through the native
SDK: `initialize` activates Chat; this plugin does not take a widget ID in initialization.

Installation-based Chat uses the registered installation context. For a widget
requiring **JWT authentication**, your backend authenticates the user and signs
fresh widget tokens using that widget's key. Personalize the installation with a
matching user identity before opening authenticated Chat. Supply tokens through
`setChatJwtProvider`, as shown below. The **Widget ID** and **key ID** identify the
signing configuration; the **widget secret key** remains on the backend.
Chat JWT is independent of Mobile Messaging JWT and Inbox JWT.
See [widget setup][widget-guide] and [Chat authentication][chat-auth-guide].

### Optional Mobile Inbox and user management

Use the same Mobile Messaging profile and its user/Inbox authorization policies.
Your backend must authorize access to the requested `externalUserId`. Configure
JWT signing on the backend when required by the profile. `setJwt` configures MM
request authorization; `fetchInbox(jwt: ...)` can override it for one request.
Inbox is a message feature, distinct from the agent contact-center product.
See [user and Inbox examples](doc/messaging-chat.md#inbox).

### Optional outgoing RTC Calls

Choose the built-in Conversations destination or an administrator-supplied custom
Calls Configuration ID. Follow [Configure Infobip RTC Calls Routing](#configure-infobip-rtc-calls-routing)
for the distinction, account setup and verification steps.

The plugin fetches an RTC token natively through initialized Mobile Messaging.
There is no Dart RTC-token or API-key argument. An omitted `identity` uses the
registered installation's `pushRegistrationId`; wait for registration first.
An explicit identity is the authorized **caller/token subject**, not a callee.
Your backend/account must authorize it and the configuration. There is no callee
parameter; backend routing decides the destination. Outgoing calls do not need
`WebRTCUI`; incoming HMS push and the official `enableCalls` / `enableChatCalls`
APIs remain unsupported. The experimental foreground flow below is separate.

## Android Configuration

All paths here are relative to **your Flutter host**, not the plugin's `android/`
library. The example host uses the same layout under `example/android/`.

### App ID resource and metadata

Create or update `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="app_id" translatable="false">YOUR_NUMERIC_HUAWEI_APP_ID</string>
    <string name="app_name">My app</string>
</resources>
```

Replace `YOUR_NUMERIC_HUAWEI_APP_ID` with the actual nonzero digits from AGC before
building. The literal placeholder is invalid. The plugin explicitly validates
`app_id`; JSON or manifest metadata alone cannot replace this resource.
`app_name` is optional for the SDK's default notification title. No
`infobip_application_code` resource is required: the code comes from Dart.

AGConnect processes app metadata from JSON. Check the merged manifest's
`com.huawei.hms.client.appid` value against your Huawei ID. If your host already
sets it explicitly, the value must be `appid=YOUR_NUMERIC_HUAWEI_APP_ID`; avoid
conflicting duplicate metadata. The repository example sets this metadata from
JSON itself, but still requires a separately configured `app_id` string.

### Gradle (Kotlin DSL)

Merge these entries into existing files; keep Flutter's plugin loader,
`includeBuild`, Android/Kotlin plugins and repository setup. This matches the
repository's AGConnect declaration **1.9.1.301**; it is not a claim that this is
Huawei's latest release. Do not add the standard Infobip Android core or RTC UI
alongside this Huawei plugin.

In `android/settings.gradle.kts`, inside the existing `pluginManagement`:

```kotlin
resolutionStrategy {
    eachPlugin {
        if (requested.id.id == "com.huawei.agconnect") {
            useModule("com.huawei.agconnect:agcp:${requested.version}")
        }
    }
}
repositories {
    maven("https://developer.huawei.com/repo/")
    google()
    mavenCentral()
    gradlePluginPortal()
}
```

In the existing settings `plugins` block:

```kotlin
id("com.huawei.agconnect") version "1.9.1.301" apply false
```

Ensure the **dependency repositories** also contain Huawei Maven. If your host
uses `dependencyResolutionManagement` in settings, merge into its repositories:

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io")
        maven("https://developer.huawei.com/repo/")
    }
}
```

If repositories instead live in `android/build.gradle.kts` under
`allprojects.repositories`, add Huawei Maven there. Keep one coherent repository
policy; `FAIL_ON_PROJECT_REPOS` conflicts with this plugin's project repositories.

In `android/app/build.gradle.kts`, apply AGConnect in the existing plugins block
and set Android levels in the existing Android block:

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.huawei.agconnect")
}
android {
    compileSdk = 36
    defaultConfig {
        minSdk = 26
        targetSdk = 36 // example host target; follow your release target policy
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
```

For Groovy hosts, use `maven { url 'https://developer.huawei.com/repo/' }` and
`id 'com.huawei.agconnect'` with the equivalent declaration in settings. Follow
[Huawei's integration guide][huawei-guide] for your existing Gradle style.
The repository example declares AGConnect with `apply false` but does not apply
it in its app module: configuring the example privately is a separate step.

### Activity and permissions

Embedded Chat requires `FlutterFragmentActivity` in
`android/app/src/main/kotlin/<your/package>/MainActivity.kt`:

```kotlin
package com.example.app // replace with your host package
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity()
```

In `android/app/src/main/AndroidManifest.xml`, review these permissions outside
`<application>` (the merged SDK/plugin manifest may already contribute them):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

Request notification permission on Android 13+, microphone for audio calls,
microphone and camera for video, and Bluetooth connect on Android 12+ for RTC
routing. Use your host's Android permission implementation or chosen permission
package and handle denial in the UI. The plugin does not request call permissions.
The example's permission channel is example-only, not a public plugin API.

The plugin contributes private microphone/camera/mediaProjection foreground
services and their normal permissions. Review the merged manifest and start calls
from a resumed Activity. Screen sharing additionally shows fresh Android capture
consent each time; no static permission replaces that consent.

## Flutter Initialization

### Application Code, without JWT

**Yes: Application Code initialization is exposed by the Flutter plugin today.**
`initialize(applicationCode: ...)` requires no JWT, API key, Infobip Application ID
or Calls Configuration ID. Native Android builds Mobile Messaging with
`withApplicationCode(applicationCode)`. Complete the Huawei host setup first.
This minimal startup function can be called before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<bool> initializeMessaging(
  String applicationCode,
  void Function(String) showSafeError,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await InfobipMobileMessagingHuawei.initialize(applicationCode: applicationCode);
    return true;
  } on PlatformException catch (error) {
    showSafeError(error.code); // Never log raw details.
    return false;
  } on ArgumentError {
    showSafeError('missing_application_code');
    return false;
  }
}
```

Call this once during app startup and enable feature controls only after success.
Surface a safe setup message when it returns false. For native UI operations,
wait until your app is visible and its Activity resumed.

Initialize before using SDK features. Initialization also activates Chat. If it
fails with `chat_unavailable`, Mobile Messaging remains initialized: wait at least
one second and retry with the **same** application code. A concurrent/cooldown
retry returns `chat_activation_busy`. Bound retries in your application.

The default message store is enabled. MM `setJwt` authorization is separate from
Chat JWT authentication. See [messaging and Chat integration](doc/messaging-chat.md)
for storage settings, user/installation examples, Inbox, JWTs and cleanup.

### JWT authorization after initialization

JWT is not an alternative initializer: there is no `initialize(jwt: ...)` API.
Always initialize with the Application Code. For a profile requiring MM JWT,
fetch a token from your authenticated backend and install it before protected
requests. Call this from your signed-in session setup after initialization:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<UserData> loadProtectedUser(
  Future<String> Function() fetchMessagingJwt,
) async {
  final jwt = await fetchMessagingJwt().timeout(const Duration(seconds: 10));
  if (jwt.trim().isEmpty) throw StateError('Backend returned an empty token');
  await InfobipMobileMessagingHuawei.setJwt(jwt);
  return InfobipMobileMessagingHuawei.fetchUser();
}
```

The caller handles backend/network and `PlatformException` failures. `setJwt`
installs an in-memory native JWT supplier; it does not renew the token. Refresh
through your backend before expiry, then call `setJwt` again. `setJwt(null)` clears
it; this does not bypass a profile's JWT requirement.

| Authentication | Required value and sequence | Renewal owner |
| --- | --- | --- |
| Mobile Messaging initialization | Application Code → `initialize` | App configuration |
| Protected MM requests | Initialize → backend MM JWT → `setJwt` → request | Host/backend |
| Inbox | Initialize → `fetchInbox(externalUserId:, jwt:)`; explicit token overrides global JWT, otherwise Application Code if policy allows | Host/backend |
| JWT-enabled Chat | Initialize/register → personalize → `setChatJwtProvider` → open Chat | Backend provider, called again by native Chat |
| RTC | Initialize/register or authorized identity → native token fetch → call | Native token provider; no Dart token input |

Application Code alone does not remove RTC token authentication. Chat JWT,
MM/Inbox JWT, and RTC access tokens have separate contracts; do not interchange them.
Do not sign production tokens on the device.

## Push Notifications

Initialize first and request Android notification permission in your host. Then
subscribe **before** requesting registration:

```dart
import 'dart:async';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<StreamSubscription<Installation>> registerPush(
  void Function(Installation) onRegistration,
  void Function(Object) onError,
) async {
  final subscription = InfobipMobileMessagingHuawei.notifications
      .onRegistrationUpdated.listen(onRegistration, onError: onError);
  try {
    await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
    return subscription;
  } catch (_) {
    await subscription.cancel();
    rethrow; // Caller shows a safe failure and offers retry.
  }
}
```

Registration is asynchronous: method completion alone does not prove HMS token
acquisition or delivery. In `onRegistration`, check for nonempty
`pushRegistrationId` and `pushServiceToken` without printing them. Registration
updates do not replay: use `getInstallation()` to inspect the cached state after
reattachment. Observe `notifications.onMessageReceived` and
`notifications.onNotificationTapped`, send a test push from the matching Infobip
profile, and verify foreground/background receipt and tap behavior on device.
Never set the HMS token manually; the native SDK acquires and refreshes it.

Cancel subscriptions when their owner is disposed. HMS token acquisition/refresh
belongs to the native SDK. A pending notification tap can replay once on subscription;
other MM events do not replay. Treat payloads and deep links as untrusted input.
See [notification event examples](doc/messaging-chat.md#hms-push-and-notification-events).

### Receive messages, taps and actions

Create this owner once for your app/session before initialization so early events
can be observed. Pass UI callbacks that validate payloads and queue navigation
until your navigator and signed-in session are ready. Call `dispose` when replacing
that owner. Stream cancellation does not unregister HMS.

```dart
import 'dart:async';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

class PushListeners {
  PushListeners({
    required void Function(Message) onMessage,
    required void Function(Message) onTap,
    required void Function(NotificationActionEvent) onAction,
    required void Function(Object) onError,
  }) {
    final events = InfobipMobileMessagingHuawei.notifications;
    _subscriptions.addAll([
      events.onMessageReceived.listen(onMessage, onError: onError),
      events.onNotificationTapped.listen(onTap, onError: onError),
      events.onNotificationActionTapped.listen(onAction, onError: onError),
    ]);
  }
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
```

`Message` exposes nullable `messageId`, `title`, `body`, `customPayload`, `deeplink`,
`browserUrl`, `webViewUrl`, `silent`, and numeric millisecond timestamps.
`NotificationActionEvent` supplies `actionId` and `message`. Allowlist routes/URL
schemes, validate custom fields, and require authorization before navigation.
After the user actually reads a regular message, pass its non-null ID to
`markMessagesSeen([id])`; completion is local acceptance, not server confirmation.

| App state | Native notification path | Flutter callback expectation |
| --- | --- | --- |
| Foreground, engine/listener attached | Native MM handles received push and configured notification display | Receive message/tap/action events while attached |
| Background, process alive | HMS/Android and SDK govern delivery/display | Only a live attached engine/listener can receive events; no background Dart worker |
| Process absent or swiped away | Vendor/OS delivery depends on device restrictions and payload | No Dart callback while absent; supported pending tap may replay after launch/attachment |
| Force-stopped | Do not rely on delivery until explicit relaunch | No callback guarantee |

There is no durable message-event replay or delivery guarantee for killed apps.
Do not add a second local notification for every event without considering the
SDK's own display behavior. On physical Huawei hardware, send a unique test
message from the matching Infobip profile in each state above, tap it, and verify
receipt, allowed navigation, action handling and registration after relaunch.
Check token presence again after refresh without logging its value. Compilation
and registration-method success do not substitute for these checks.

## Chat Integration

Configure/link the widget in Infobip, initialize and confirm installation
registration first. For JWT mode, personalize and install the provider before
opening Chat. Then open native Chat from a visible screen:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<bool> openChat() async {
  try {
    await InfobipMobileMessagingHuawei.showChat();
    return true;
  } catch (_) {
    return false; // Show safe availability/authentication feedback in your UI.
  }
}
```

For embedded Chat, use `InfobipHuaweiChatView` with one
`InfobipHuaweiChatController` per attached view, bounded layout and a
`FlutterFragmentActivity` host. Native composer attachments are supported;
programmatic sending is text-only. Unread updates do not replay: query the current count.

Use `setChatJwtProvider` to retrieve fresh backend-issued widget/identity tokens.
MM/Inbox JWTs use separate contracts. Provider requests expire after 25 seconds in
Dart and 30 seconds natively, with 32 pending requests per side. Bound your backend
network work too. See [Chat examples and authentication](doc/messaging-chat.md#native-and-embedded-chat)
and the [API compatibility reference](API_COMPATIBILITY.md).

For JWT-enabled widgets, use an authenticated backend request with a network
timeout. This helper accepts your app's token-fetch function; implement it on
your backend/API client, never by signing JWTs in Flutter:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<void> configureAuthenticatedChat(
  String externalUserId,
  Future<String> Function() fetchBackendChatJwt,
  void Function(Object) onAuthError,
) async {
  await InfobipMobileMessagingHuawei.personalize(PersonalizeContext(
    userIdentity: UserIdentity(externalUserId: externalUserId),
  ));
  await InfobipMobileMessagingHuawei.setChatJwtProvider(
    () => fetchBackendChatJwt().timeout(const Duration(seconds: 10)),
    onAuthError,
  );
}
```

Handle personalization/provider setup failures in the calling UI. Return a fresh,
nonempty token per callback, with a subject matching the personalized identity.

### Embedded Chat, events and ownership

After the same initialization, registration and optional authentication steps,
mount this widget in a bounded page. It owns one controller for its lifetime;
the plugin view detaches its native fragment and callbacks on disposal. There is
no public controller `dispose` method to call.

```dart
import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

class SupportChat extends StatefulWidget {
  const SupportChat({super.key, required this.onEvent, required this.onError});
  final void Function(InfobipHuaweiChatEvent) onEvent;
  final void Function(InfobipHuaweiChatError) onError;
  @override
  State<SupportChat> createState() => _SupportChatState();
}

class _SupportChatState extends State<SupportChat> {
  final controller = InfobipHuaweiChatController();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 480,
    child: InfobipHuaweiChatView(
      controller: controller,
      withInput: true,
      withToolbar: true,
      onEvent: widget.onEvent,
      onError: widget.onError,
    ),
  );
}
```

Handle typed loaded, connection, exit, widget/theme, view, attachment-preview and
raw-message events through `onEvent`. A successful load is not proof of agent
availability. Verify a real agent reply and an attachment from the native composer.
Do not log raw-message or attachment contents. Use `navigateBackOrCloseChat()` for
native back handling before popping the Flutter route.

For an app-wide badge, subscribe before querying its initial value:

```dart
import 'dart:async';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<StreamSubscription<int>> attachChatBadge(
  void Function(int) update,
  void Function(Object) onError,
) async {
  final chat = InfobipMobileMessagingHuawei.chat;
  final subscription = chat.onUnreadMessageCounterUpdated.listen(
    update, onError: onError,
  );
  try {
    update(await chat.getUnreadMessageCount());
    return subscription;
  } catch (_) {
    await subscription.cancel();
    rethrow;
  }
}
```

Cancel the returned subscription when its owner ends. Use `isChatAvailable()` to
query availability and `resetMessageCounter()` only when your UX considers the
messages read. For sending text/context, language, theme, global customization
and exception handling, see the [maintained Chat recipes](doc/messaging-chat.md#native-and-embedded-chat).

### Widget selection and login/logout

The Mobile Messaging profile supplies the widget; neither `initialize` nor
`showChat` accepts a widget ID. No public multi-widget selector or independent
parallel Chat sessions are exposed. The widget ID used by Chat JWT signing and
RTC identity resolution must match that configured widget; passing a different
RTC widget ID does not switch the Chat UI.

On login, await personalization and install a provider bound to the current
user before showing Chat. On logout, close Chat views, finish pending RTC work,
hang up and await `finished`, then await `depersonalize()` and clear MM JWT with
`setJwt(null)`. Prevent further Chat access with the old provider. There is no
provider-clear API: replace it for a newly authenticated user before reopening,
or use successful `cleanup()` and reinitialize when a full local SDK reset is
intended. Cleanup removes local SDK state and clears the Chat provider/handler;
it is not the normal sign-out operation. Incoming preparation is invalidated by
account changes and needs process recreation. Handle failures before moving on.

## Inbox and User Management

Use `personalize(PersonalizeContext(...))` for a signed-in user's identity,
`fetchUser()` for server refresh and `depersonalize()` at logout. Do not use SDK
cleanup as a logout shortcut. Install `setJwt` before protected MM user requests.
For Production Inbox, fetch a backend-issued Inbox JWT, then call:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<Inbox> loadInbox(String externalUserId, String backendInboxJwt) =>
    InfobipMobileMessagingHuawei.fetchInbox(
      externalUserId: externalUserId,
      jwt: backendInboxJwt,
      options: FilterOptions(limit: 20),
    );
```

Handle request failures and expired tokens in the caller. Never accept a client
user ID as sufficient backend authorization. A Sandbox profile configured for
Application Code auth may omit `jwt`; a global `setJwt` value still takes
precedence. `setInboxMessagesSeen` retains installation context and has no JWT
parameter. See [user, installation and Inbox examples](doc/messaging-chat.md).

### Installation settings and custom events

After initialization, inspect cached installation with `getInstallation()` or
refresh from the server with `fetchInstallation()`. Only primary-device status,
push-enabled status and custom attributes are writable; tokens are native-managed.
This helper belongs in an explicit notification-preferences action:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<Installation> setPushEnabled(bool enabled) async {
  final installation = await InfobipMobileMessagingHuawei.getInstallation();
  installation.isPushRegistrationEnabled = enabled;
  return InfobipMobileMessagingHuawei.saveInstallation(installation);
}

Future<InfobipHuaweiCustomEvent> reportEvent(String configuredDefinitionId) =>
    InfobipMobileMessagingHuawei.submitEventImmediately(
      InfobipHuaweiCustomEvent(
        definitionId: configuredDefinitionId,
        properties: const {'source': 'support_screen'},
      ),
    );
```

Define the event and its property schema in Infobip first. Handle backend rejection
in the caller; `submitEvent` queues an event, while `submitEventImmediately` awaits
the native result. There is no custom-event result stream to dispose. Observe
`onInstallationUpdated`, `onUserUpdated`, `onPersonalized`, and `onDepersonalized`
for future state updates and cancel those listeners with their owner. Use the
[user/installation recipes](doc/messaging-chat.md#user) for profile attributes,
primary-device changes and installation depersonalization.

## RTC Audio / Video Calls

Initialize MM, register if using the default installation identity, grant call
permissions and start from a resumed Activity. The native provider acquires RTC
tokens through initialized MM; your backend must authorize the identity and routing.
Calls configuration ID is distinct from RTC push configuration ID. Routing selects
the peer; there is no callee argument.

For Chat-associated customer identity, opt in with
`HuaweiRtcCallRequest(liveChatIdentity: HuaweiRtcLiveChatIdentity(widgetId: configuredChatWidgetId,
expectedExternalUserId: personalizedExternalUserId), ...)`. Resolution uses exactly
that widget and the current personalized installation, stays native, and fails
without fallback if lookup or account validation fails. Existing explicit
`identity` and omitted-identity behavior are unchanged. See the
[customer identity guide](doc/huawei-rtc-customer-identity.md) for complete Dart
usage, lifecycle failures and pinned SDK compatibility. The supplied Huawei tests
confirmed correct customer name/email for this outgoing flow; internal People
Person ID equality is not guaranteed. Each call may create a new Conversation;
there is no verified supported way to force reuse. Agent-initiated incoming calls
are available through the separate
[experimental foreground flow](doc/huawei-rtc-incoming.md).

Subscribe before starting and grant the host permissions described above.
Use the Calls Configuration ID supplied by your backend/account administrator:

```dart
import 'dart:async';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

StreamSubscription<HuaweiRtcEvent> observeCalls(
  void Function(HuaweiRtcEvent) updateCall,
  void Function(Object) onError,
) => HuaweiRtc.events.listen(updateCall, onError: onError);

Future<HuaweiRtcCall?> startAudio(
  String callsConfigurationId,
  void Function(String) showSafeError,
) async {
  try {
    return await HuaweiRtc.callApplication(HuaweiRtcCallRequest(
      callsConfigurationId: callsConfigurationId,
      type: HuaweiRtcCallType.audio,
    ));
  } on HuaweiRtcException catch (error) {
    showSafeError(error.code);
    return null;
  } on ArgumentError {
    showSafeError('invalid_call_configuration');
    return null;
  }
}
```

For video, additionally grant camera permission:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<HuaweiRtcCall?> startVideo(
  String callsConfigurationId,
  void Function(String) showSafeError,
) async {
  try {
    return await HuaweiRtc.callApplication(HuaweiRtcCallRequest(
      callsConfigurationId: callsConfigurationId,
      type: HuaweiRtcCallType.video,
    ));
  } on HuaweiRtcException catch (error) {
    showSafeError(error.code);
    return null;
  } on ArgumentError {
    showSafeError('invalid_call_configuration');
    return null;
  }
}
```

Keep the event subscription through the call and cancel it when its owner is
disposed. Use an authorized `identity` in the request only if your backend
requires one; otherwise these examples use the registered installation identity.

Subscribe before starting. Method completion means a native call object exists;
await `established` for connection and `finished` for termination. Only one active
call or pending request is allowed. `getActiveCall()` can be null during token fetch.

Use `HuaweiRtcVideoView` for bounded local/remote views and `HuaweiRtc` controls
for mute, speaker/audio routes and camera enable/switch. Mutations require the
current ID and an established foreground call. Handle `returnToCall` and consume
`takeNotificationCall()` on attachment/resume to restore your existing call screen.
Navigation away does not hang up. Hang up and await `finished` before MM cleanup
or account changes. See the [RTC integration guide](doc/huawei-rtc-outgoing.md)
for rendering, controls, notifications, events and errors.

## RTC rendering and controls

There is no separate `HuaweiRtc.initialize` call. The Mobile Messaging setup
above supplies native token access. Audio/video start examples belong in a call
screen or app-scoped call owner; subscribe before calling, retain the returned
call ID, and render/update only the current call. For video, use bounded views:

```dart
import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Widget callVideo(String callId) => Column(children: [
  SizedBox(width: 320, height: 240, child: HuaweiRtcVideoView(
    callId: callId, source: HuaweiRtcVideoSource.remote,
  )),
  SizedBox(width: 160, height: 120, child: HuaweiRtcVideoView(
    callId: callId, source: HuaweiRtcVideoSource.local,
  )),
]);

Future<HuaweiRtcControls> muteCall(String callId, bool muted) =>
    HuaweiRtc.setMicrophoneMuted(muted, callId: callId);
Future<HuaweiRtcControls> useSpeaker(String callId, bool enabled) =>
    HuaweiRtc.setSpeakerEnabled(enabled, callId: callId);
Future<HuaweiRtcControls> enableCamera(String callId, bool enabled) =>
    HuaweiRtc.setCameraEnabled(enabled, callId: callId);
Future<HuaweiRtcControls> switchCamera(String callId) =>
    HuaweiRtc.switchCamera(callId: callId);
Future<void> endCall() => HuaweiRtc.hangup();
```

Wire each function to a user action and await it with `HuaweiRtcException` handling.
Use the returned `HuaweiRtcControls` snapshot to update buttons, rather than
assuming a requested state took effect. Query `getCallControls(callId: ...)` after
reattachment/errors; `selectAudioOutput(output, callId: ...)` accepts an output
from `availableAudioOutputs`. Unavailable routes produce `rtc_control_unavailable`.
Camera changes require video and are locked during screen capture/shutdown.

`HuaweiRtc.events` reports state, ringing, early media, established, finished,
error, reconnecting, reconnected and return-to-call. An error is not necessarily
terminal. Deduplicate replayed events using `sequence`; it is not durable history.
Video views release renderers on disposal, never the call. Remote rendering
requires a single unambiguous camera endpoint; this is not a multiparty gallery.

Keep an app-scoped listener until termination so leaving a screen does not lose
call ownership. On explicit End, await `hangup()` and then the matching `finished`
event before resetting the SDK or changing accounts. On owner disposal, cancel
its `StreamSubscription` with `await subscription.cancel()` after handing off or
ending the call. Never interpret a canceled listener as a hangup.

Test audio in both directions, remote video frames, mute, route changes, camera
controls, return-to-call notification and terminal media release with a real peer.
A call object, preview or token response alone does not prove those outcomes.

## Experimental foreground incoming RTC

The unreleased incoming flow supports application audio/video invitations,
Accept/Decline, native ringtone with best-effort speaker routing, explicit
camera-enabled acceptance, local/remote video rendering, microphone mute,
camera switching/on/off, speakerphone controls, and call termination/cleanup.
Start it explicitly from a resumed Activity using the personalized user's exact
Live Chat widget. See the [incoming consumer guide](doc/huawei-rtc-incoming.md)
for usage, permissions, event states, errors and cleanup.

Use this controller from your incoming screen after its prerequisites are met.
The UI receives state updates and shows Accept/Decline only for `invitation` with
a non-null handle. The call-event callback should belong to your app's call owner.

```dart
import 'dart:async';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

class IncomingScreenSession {
  IncomingScreenSession(this.onInvitation, this.onError);
  final void Function(HuaweiRtcIncomingExperimentEvent) onInvitation;
  final void Function(Object) onError;
  StreamSubscription<HuaweiRtcIncomingExperimentEvent>? _subscription;

  Future<void> start(String widgetId, String externalUserId) async {
    _subscription ??= HuaweiRtc.incomingExperimentEvents.listen(
      onInvitation, onError: onError,
    );
    try {
      await HuaweiRtc.startForegroundIncomingExperiment(
        HuaweiRtcLiveChatIdentity(
          widgetId: widgetId, expectedExternalUserId: externalUserId,
        ),
      );
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  Future<HuaweiRtcCall> accept(String currentHandle, {required bool video}) =>
      HuaweiRtc.acceptExperimentalIncomingCall(
        handle: currentHandle, video: video,
      );
  Future<void> decline(String currentHandle) =>
      HuaweiRtc.declineExperimentalIncomingCall(handle: currentHandle);

  Future<void> close() async {
    try {
      await HuaweiRtc.closeForegroundIncomingExperimentScreen();
    } finally {
      await _subscription?.cancel();
      _subscription = null;
    }
  }
}
```

Before `start`, attach the `observeCalls` listener shown above. Keep it alive
through accepted-call termination; close the incoming screen explicitly and await
`close()` from the navigation owner. If Flutter `dispose` cannot await cleanup,
hand its future/error handling to that app owner. Closing is not unregistering.

Pass the current event's opaque handle only; never store it across sessions.
Choose `video: false` for audio, or `true` only after camera permission and explicit
user consent. The native ringtone respects silent mode, volume and DND; speaker
routing is best-effort. It stops on acceptance/decline/foreground loss. Do not
start a second Flutter ringtone. Handle preparation failures through the incoming
state/reason stream as well as method errors. `registrationRequested` does not
prove signaling readiness; use a real agent invitation to validate it.

This remains **experimental**, not production-ready background telephony:

- Background and terminated-app incoming calls are unsupported.
- Registration is process-scoped. Logout, account changes and engine detach
  invalidate it; retry after invalidation requires process recreation.
- There is no supported active-registration token replacement or unregister API.
  Closing the incoming screen does not unregister native signaling.
- Preparation success does not confirm signaling readiness; accept success does
  not confirm connected bidirectional media. Observe lifecycle events.
- Offered audio/video type is unknown. Choose audio or camera-enabled video
  explicitly; `videoSupported` describes local capability, not the remote offer.
- Incoming auto-reconnect is disabled. Existing Conversation reuse is not established.

## Screen Sharing

Screen-as-Camera replaces the outgoing camera stream on Android 10+; it does not
create a separate screen track. Start with an established video call, enabled
camera and focused Activity:

```dart
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<ScreenAsCameraState> startScreen(String callId) =>
    HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: callId);

Future<ScreenAsCameraState> stopScreen(String callId) =>
    HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: callId);
```

Subscribe to `HuaweiRtcScreenAsCamera.states` before Start, with an `onError`
handler; retain and cancel that subscription when its owner ends. Render state
from `phase` and release flags. Use `getScreenAsCameraState(callId: ...)` when
reattaching. `sharing` confirms local frame submission, not peer delivery.

Every start requires fresh Android consent. Capture has a foreground notification
and Stop action. Backgrounding may leave capture active; Activity detach, call end,
revocation or a changed resize report triggers Stop. Restart requires new consent.

Output is **640×480**, fitted with black bars; portrait text has limited detail.
Camera switching/toggling is locked during capture/shutdown. Confirm
`projectionTerminated` and `resourcesReleased` after Stop. On
`screen_stop_uncertain`, query state and retry Stop or use Android capture controls.
`cameraOutputRestored` confirms local submission, not remote display.
See the [screen-sharing guide](doc/screen-sharing.md) for states, privacy and device checks.

## Configuration Reference

Only the Application Code is required by the Dart `initialize` signature. Huawei
host configuration is also required for this plugin's Android initialization.
Rows marked optional apply only when you enable that feature. Non-secret IDs
still identify your environment; do not publish private customer configuration.

| Configuration | Provider | Where to obtain | Where to configure | Required for | Secret / Non-secret |
| --- | --- | --- | --- | --- | --- |
| Android `applicationId` / package name | Your app / Huawei | Host app Gradle; register exactly in AGC | `android/app/build.gradle.kts` and AGC app | Required: matching Huawei app | Non-secret |
| Signing certificate SHA-256 | Your signing certificate | `:app:signingReport` / release certificate | AGC signing-certificate information | Required: installed build's Huawei configuration | Non-secret fingerprint; private keystore is secret |
| Huawei App ID / `app_id` | Huawei AGC | App information / JSON `client.app_id` | Host `strings.xml`, AGC metadata and Infobip Huawei profile | Required: host initialization and push | Non-secret numeric ID |
| `agconnect-services.json` | Huawei AGC | Download Android app configuration | `android/app/agconnect-services.json` | Required: documented Huawei host setup | Private configuration; may contain credential material, do not publish |
| Huawei App Secret | Huawei AGC | App credential information | Infobip profile's Huawei push settings only | Required: Infobip sends HMS push | Secret; no Dart input |
| Infobip Application Code / `applicationCode` | Infobip | Saved mobile application profile | `initialize(applicationCode: ...)` | Required: MM initialization, basis for Chat/RTC | Client-distributed authorization value; protect from logs, not a backend signing key |
| Infobip Application ID | Infobip / your backend | App/profile or backend provisioning record | Backend tools if needed; no plugin input | Not required by this plugin's initialization | Non-secret ID; not Huawei App ID |
| App Key / backend `AppKey` | Your backend | Backend provisioning; exact meaning belongs to your backend contract | No plugin input; backend-owned | Not required by this plugin | Treat as sensitive; not assumed to be an Infobip API key or JWT key |
| Infobip API key | Infobip | Account API-key management | Backend API client only | Optional: server-side push, Calls or other API provisioning | Secret; never a Flutter initialization input |
| Infobip base URL | Infobip / your backend | Account/API configuration | Backend API client if needed | Not a Dart plugin parameter; native MM owns its endpoint configuration | Non-secret endpoint |
| Chat widget configuration / linkage | Infobip Live Chat | Widget configuration | Connect widget to Mobile Messaging profile in Infobip | Optional: Chat | Non-secret configuration |
| Chat Widget ID / `chatWidgetId` | Infobip Live Chat | Widget configuration | Backend Chat JWT issuer; example test field only for local signing | Optional: JWT-enabled Chat, not `initialize` | Non-secret ID |
| Chat key ID / `chatKeyId` (`ski`) | Infobip Live Chat | Widget's generated secret-key record | Backend JWT claims / isolated example test config | Optional: Chat JWT signing | Non-secret key identifier |
| Chat secret key / `chatSecretKey` | Infobip Live Chat | Widget security / generated keys | Backend signer only in production | Optional: Chat JWT signing | Secret Base64 key; never ship in production Flutter |
| Chat JWT / `chatJwtToken` | Your authenticated backend | Fresh token endpoint | `setChatJwtProvider` callback | Optional: widget JWT authentication | Sensitive short-lived token; distinct from MM JWT |
| Mobile Messaging JWT / `jwtToken` | Your authenticated backend | MM token endpoint | `setJwt(jwt)` | Optional: profile security requires JWT for MM requests | Sensitive token |
| Inbox JWT / request `jwt` | Your authenticated backend | Inbox-authorized token endpoint | `fetchInbox(jwt: ...)` or global `setJwt` | Required: Production Inbox; optional per Sandbox policy | Sensitive token; not a Chat JWT |
| MM/Inbox key ID and signing key / `jwtKid`, `jwtSecretKey` | Infobip profile / backend | Profile JWT authorization key configuration | Backend signer; isolated example local signing fields only | Optional: issuing MM/Inbox JWTs | ID non-secret; key secret (example expects hex) |
| User identity / `externalUserId` | Your identity backend | Authenticated account record | `UserIdentity`, Inbox request; match JWT subject | Optional: personalization, protected Chat/Inbox | Personal data; not a password or signing key |
| RTC Calls Configuration ID / `callsConfigurationId` | Infobip Calls | Calls configuration creation/API response or administrator | `HuaweiRtcCallRequest` | Required: outgoing RTC | Non-secret routing ID |
| RTC Push Configuration ID / `WebRTCUI.configurationId` | Infobip WebRTC | Push registration configuration | No supported incoming HMS push flow; do not pass as Calls ID | Not used by outgoing or experimental foreground incoming calls | Non-secret configuration ID |
| RTC Identity / request `identity` | Your backend or native installation | Authorized caller subject; default `pushRegistrationId` | Optional `HuaweiRtcCallRequest.identity` | Optional override; otherwise registration must complete | Identity / personal data; not destination |
| RTC token | Native MM backend response | Acquired natively for each outgoing call | Native SDK only; no Dart token argument | Outgoing RTC, automatic acquisition | Sensitive temporary token |
| HMS token / `pushServiceToken` and `pushRegistrationId` | HMS / Infobip SDK | Registration events or installation snapshot | Native SDK managed; inspect presence only | Push; registration ID also default RTC identity | Sensitive device identifiers; not manual configuration |
| `app_name` | Your app | App display name | Host `strings.xml` | Optional: SDK notification title | Non-secret |
| `defaultMessageStorage` | Your app | Storage/privacy decision | Before `initialize`, default `true` | Optional: default local message store | Non-secret setting |

The example-only TTL, content, Inbox filters, feature flags and installation
settings are listed in [the example configuration table](example/README.md#every-active-field).
They are test controls, not additional portal credentials.

## Error Handling

Await every configuration/control operation and handle errors at the UI/session
boundary. Messaging/Chat method failures normally use `PlatformException`;
RTC methods use `HuaweiRtcException`. Invalid Dart arguments can throw
`ArgumentError`, and malformed RTC event snapshots can raise `FormatException`.
Install `onError` on streams and keep later valid events usable. Show a safe code
and retry guidance; never display or log raw native details or credentials.

```dart
import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<void> runSdkAction(
  Future<void> Function() action,
  void Function(String) showSafeError,
) async {
  try {
    await action();
  } on HuaweiRtcException catch (error) {
    showSafeError(error.code);
  } on PlatformException catch (error) {
    showSafeError(error.code);
  } on ArgumentError {
    showSafeError('invalid_configuration');
  } on Object {
    showSafeError('operation_failed');
  }
}
```

Bound retries and disable overlapping actions. A successful method often means
“request accepted”; registration, Chat connectivity, RTC establishment and media
release require their documented events or state checks. `cleanup()` rejects
conflicting lifecycle work with `operation_in_progress`; a failed cleanup preserves
Dart Chat providers. Do not proceed as though it succeeded.

## Troubleshooting

| Symptom | Check / next step |
| --- | --- |
| `hms_configuration_missing` | Host `app_id` must contain actual digits, nonzero, without spaces; JSON/manifest alone is insufficient |
| Huawei dependencies cannot resolve | Add Huawei Maven to both plugin resolution and dependency repositories; check repository policy and connectivity |
| AGConnect processing fails | Apply its app plugin, place the correct JSON in `android/app/`, and match the variant's package |
| Registration never arrives | HMS Core availability, package/signing fingerprint, Push Kit enabled, network; inspect cached installation without logging tokens |
| Registered but no push | Matching Infobip Huawei credentials/profile, correct recipient, push enabled, notification permission/channels and Huawei background restrictions |
| `chat_unavailable` | Check linked widget, registration, account service and connectivity; MM stays initialized, retry same code after at least one second with a bounded retry |
| `chat_activation_busy` | Concurrent activation or one-second cooldown; wait and avoid parallel initialization retries |
| Chat authentication failure | Widget mode, fresh backend Chat JWT, matching personalized identity and widget key; MM JWT is not a replacement |
| User/Inbox authorization rejected | Profile policy, token expiry and authorized external user ID; Production Inbox requires JWT |
| `rtc_not_initialized` | Initialize MM; omitted identity additionally needs completed installation registration |
| `rtc_permission_denied` | Host must obtain microphone/camera and Android 12+ Bluetooth connect grants before calling |
| `rtc_token_failed` / numeric 10300 | Verify account authorization, caller identity and backend routing with Infobip; the rejection predicate is not proven by a client error alone |
| `rtc_call_already_active` | One call or pending token request allowed; await `finished` before another call |
| Call object returned but no media | Wait for `established`; confirm backend routing/peer, permissions and network; method completion is not answer confirmation |
| Embedded Chat fails | Use `FlutterFragmentActivity`, bounded layout and one controller per attached view |
| `screen_stop_uncertain` | Query state, retry Stop or use Android capture controls; do not claim capture ended until release flags confirm it |

Never paste raw SDK errors, headers, tokens or user messages into public bug reports.
Use sanitized codes and a description of the setup checks performed.

## Known Limitations

- Android only; no iOS, web, desktop, FCM push transport or Dart background isolate.
- Incoming HMS RTC and official `enableCalls`/`enableChatCalls` parity are unsupported.
  `infobipWebRtcEnabled=true` is rejected; see [WebRTC safeguards](doc/webrtc-configuration.md).
- RTC Core retains Firebase/GMS transitive dependencies; Google-free operation is not certified.
- No multiparty gallery, separate screen track, screen-resolution setting or seamless resize.
- Typed Chat thread creation/selection models and composer draft setters are unavailable.
  Embedded `isMultithread()` and `showThreadsList()` are supported.
- Real backend acceptance, HMS delivery, signed/minified hosts, OEM lifecycle,
  GL/JNI behavior, 16 KB runtime compatibility and performance require device validation.

Follow the [example guide](example/README.md) for private configuration and manual checks.
Selected investigation evidence remains in Git and is excluded from the pub.dev package.

## Example Application

The [example setup guide](example/README.md) covers private configuration and the
Test Center. From `example/`, run:

```sh
dart run tool/setup_config.dart # once; preserves an existing private file
flutter pub get
# Edit static const fields in lib/config/example_test_config.dart.
# Complete the Huawei host setup in the example guide.
flutter run
```

Fresh clones require the one-time setup to copy safe defaults from the tracked Dart
template. Plain `flutter run` then uses the private `ExampleTestConfig` constants
through a synchronous mapper. Stop and rebuild after editing values. The private
file is ignored by Git and excluded from pub.dev; never force-add it. To restore
safe defaults, intentionally remove it and rerun setup. Hardcoded test credentials
are extractable from APKs and must never be production secrets.

Follow Setup → Push → User/Installation → Chat/Inbox → RTC → Screen Sharing.
The example covers Application Code initialization, separate MM/Chat JWT flows,
notification callbacks, embedded/native Chat, incoming/outgoing RTC and cleanup.
Its JWT signing helpers are isolated test conveniences, not a production backend.
A production token endpoint, real account routing and physical device results
must be supplied by the integrating team. See [contributing](CONTRIBUTING.md)
for local checks and [CHANGELOG](CHANGELOG.md) for released/unreleased differences.

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

## Documentation

- [Messaging, Push, Chat, user management and Inbox](doc/messaging-chat.md)
- [Outgoing RTC: events, rendering, controls and notifications](doc/huawei-rtc-outgoing.md)
- [RTC customer identity](doc/huawei-rtc-customer-identity.md)
- [Experimental foreground incoming RTC](doc/huawei-rtc-incoming.md)
- [Screen sharing: privacy, lifecycle and device checks](doc/screen-sharing.md)
- [Incoming-call safeguards](doc/webrtc-configuration.md)
- [Public API compatibility](API_COMPATIBILITY.md)
- [Physical-device example setup](example/README.md)
- [Security](SECURITY.md) and [third-party notices](THIRD_PARTY_NOTICES.md)

The guides describe this package's API. Upstream examples may use different
Flutter/native APIs or newer SDK versions; do not copy their initialization
flags, dependencies or incoming-call methods into this integration.

## License

The [MIT License](LICENSE), copyright (c) 2026 Naser Alomosh, applies to code and
content the repository owner has the right to license. Third-party SDKs, libraries,
generated files and other third-party materials remain subject to their respective
licenses and notices; MIT does not grant additional redistribution rights for them.
See [third-party notices](THIRD_PARTY_NOTICES.md) for the bundled Gradle wrapper
and Flutter-generated registration code.

[huawei-guide]: https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides-V1/integrating-sdk-0000001052151811-V1
[agc-guide]: https://github.com/infobip/mobile-messaging-sdk-huawei/wiki/Configure-Huawei-application-in-AppGallery-Connect
[profile-guide]: https://www.infobip.com/docs/mobile-push/get-started/mobile-application-profile
[widget-guide]: https://www.infobip.com/docs/live-chat/widget-customization
[chat-auth-guide]: https://www.infobip.com/docs/live-chat/users-and-authentication
[calls-guide]: https://www.infobip.com/docs/voice-and-video/calls

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
4. Set `rtcCallsConfigurationId` in the private `ExampleTestConfig` Dart class. The example passes
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

## Support This Project

If this plugin helps your project, consider supporting its ongoing development
and maintenance through [GitHub Sponsors](https://github.com/sponsors/NaserAlomosh).
