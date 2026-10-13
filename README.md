# Infobip Mobile Messaging Huawei for Flutter

A community-maintained Android Flutter plugin for Infobip Huawei Mobile Messaging
8.14.0 and RTC Core 2.5.28. This is not an official Infobip-maintained Flutter
package. Install the [published package on pub.dev](https://pub.dev/packages/infobip_mobilemessaging_huawei).
This checkout prepares the documentation update **1.0.1**; the current published
version is **1.0.0**. The public API and SDK dependencies are unchanged.

## Features

- HMS Push registration, messages, notification taps and action taps.
- User and installation management, personalization, custom events and Mobile Inbox.
- Native and embedded Chat, native attachments, unread counters and backend JWT providers.
- Outgoing RTC audio/video calls, local/remote rendering, call controls and notifications.
- Android Screen-as-Camera sharing with consent, capture notification and camera restoration.

## Supported Platforms

Android only, with HMS Push. iOS, web, desktop, FCM push transport and a Dart
background isolate are not supported. RTC Core has Firebase/GMS transitive
dependencies; Google-free operation is not certified.

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

Use the published version today:

```sh
flutter pub add infobip_mobilemessaging_huawei:^1.0.0
```

Or add it to your host application's `pubspec.yaml`, then run `flutter pub get`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  infobip_mobilemessaging_huawei: ^1.0.0
```

The caret constraint also accepts 1.0.1 once released. For reviewing this local
1.0.1 checkout, a path dependency is optional; it is not needed for normal installation.
Do not copy the example's path dependency into a production host.

## Quick Start

Complete these steps in order before calling Dart APIs:

1. Create the Huawei Android app, register your actual signing certificate,
   enable Push Kit, and download its configuration file.
2. Create an Infobip mobile application profile, enable Huawei push and save its
   matching Huawei credentials. Copy the **Application Code**.
3. Configure your Android host's JSON, numeric `app_id`, Gradle and permissions.
4. Initialize with the Application Code, subscribe to events, then register push.
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

Have your account/backend administrator create a **Calls Configuration** for
application calls and provide its `callsConfigurationId`. A custom Calls API
application needs event subscriptions and backend logic to accept/route the call
to its intended peer. Use the ID returned by that configuration's creation/API
response; do not copy a Push Configuration ID or assume a Chat widget routes calls.
The exact RTC configuration menu and account-specific routing are not verified
here. Consult [Calls configuration and subscriptions][calls-guide] or your
Infobip administrator for the supported configuration in your account.

The plugin fetches an RTC token natively through initialized Mobile Messaging.
There is no Dart RTC-token or API-key argument. An omitted `identity` uses the
registered installation's `pushRegistrationId`; wait for registration first.
An explicit identity is the authorized **caller/token subject**, not a callee.
Your backend/account must authorize it and the configuration. There is no callee
parameter; backend routing decides the destination. Outgoing calls do not need
`WebRTCUI`; incoming HMS calls and Chat calling remain unsupported.

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

## RTC Audio / Video Calls

Initialize MM, register if using the default installation identity, grant call
permissions and start from a resumed Activity. The native provider acquires RTC
tokens through initialized MM; your backend must authorize the identity and routing.
Calls configuration ID is distinct from RTC push configuration ID. Routing selects
the peer; there is no callee argument.

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
| RTC Push Configuration ID / `WebRTCUI.configurationId` | Infobip WebRTC | Push registration configuration | No active supported incoming HMS flow; do not pass as Calls ID | Not required for outgoing calls; incoming calls unsupported | Non-secret configuration ID |
| RTC Identity / request `identity` | Your backend or native installation | Authorized caller subject; default `pushRegistrationId` | Optional `HuaweiRtcCallRequest.identity` | Optional override; otherwise registration must complete | Identity / personal data; not destination |
| RTC token | Native MM backend response | Acquired natively for each outgoing call | Native SDK only; no Dart token argument | Outgoing RTC, automatic acquisition | Sensitive temporary token |
| HMS token / `pushServiceToken` and `pushRegistrationId` | HMS / Infobip SDK | Registration events or installation snapshot | Native SDK managed; inspect presence only | Push; registration ID also default RTC identity | Sensitive device identifiers; not manual configuration |
| `app_name` | Your app | App display name | Host `strings.xml` | Optional: SDK notification title | Non-secret |
| `defaultMessageStorage` | Your app | Storage/privacy decision | Before `initialize`, default `true` | Optional: default local message store | Non-secret setting |

The example-only TTL, content, Inbox filters, feature flags and installation
settings are listed in [the example configuration table](example/README.md#every-active-field).
They are test controls, not additional portal credentials.

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

## Documentation

- [Messaging, Push, Chat, user management and Inbox](doc/messaging-chat.md)
- [Outgoing RTC: events, rendering, controls and notifications](doc/huawei-rtc-outgoing.md)
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
