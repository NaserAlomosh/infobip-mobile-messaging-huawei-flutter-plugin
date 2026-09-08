# Infobip Mobile Messaging Huawei for Flutter

An Android-only Flutter plugin that integrates Flutter applications with the official Infobip Huawei Mobile Messaging SDK.

This community package wraps the official native Infobip Huawei SDK. It is not the official Infobip Flutter plugin and is not presented as an Infobip-maintained package.

## Features

- Asynchronous Mobile Messaging SDK initialization
- Infobip remote-notification registration through Huawei Push Kit
- Typed message, notification-tap, action-tap, registration, and installation events
- Cached and server-backed user and installation operations
- User personalization and depersonalization
- Global, memory-only JWT configuration for supported SDK requests
- Inbox retrieval, filtering, counters, and mark-as-seen operations
- Embedded native In-App Chat with its native composer and attachments
- Chat unread count and update stream
- View-scoped Chat text send, contextual data, language, widget theme, and back navigation

See [API compatibility](API_COMPATIBILITY.md) for the supported surface and explicit omissions.

## Requirements

| Component | Version |
| --- | --- |
| Flutter | 3.35.7 or later |
| Dart | 3.9.0 or later, before Dart 4 |
| Android compile SDK | 36 |
| Android minimum SDK | 26 |
| Android target SDK | 36 in the example host |
| Java | 17 |
| Kotlin Gradle Plugin | 2.1.0 |
| Android Gradle Plugin | 8.13.0 |
| Gradle | 8.13 |
| Infobip Huawei Mobile Messaging SDK | 8.14.0 |

Only Android is registered by this package. A Huawei device or an environment with compatible Huawei Mobile Services is required for production push behavior.

## Installation

After the package is published, add:

```yaml
dependencies:
  infobip_mobilemessaging_huawei: ^1.0.0
```

Until publication, applications can reference this repository explicitly:

```yaml
dependencies:
  infobip_mobilemessaging_huawei:
    git:
      url: https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin.git
      ref: v1.0.0
```

Then run `flutter pub get`.

## Huawei / AppGallery Connect setup

The plugin declares the Huawei Maven repository for its Android library dependencies. A real host application remains responsible for its own AppGallery Connect configuration:

1. Register the host Android application in AppGallery Connect with the exact application ID and signing certificate used for distribution.
2. Download that application's `agconnect-services.json` and place it in the host's `android/app/` directory.
3. Add Huawei's Maven repository to the host Android settings/plugin repositories as required by the current Huawei setup guide.
4. Declare the Huawei AGConnect Gradle plugin at the project level and apply `com.huawei.agconnect` to the host application module, using the plugin version approved by the host project.
5. Enable and configure Push Kit, then configure the matching application in Infobip.
6. Define a host-owned string named `app_id` in `android/app/src/main/res/values/strings.xml`, whose value is the exact numeric App ID from that application's AppGallery Connect configuration. Huawei 8.14 reads this resource as its sender ID; the JSON file alone does not supply the value to this SDK builder. Do not use the literal `APP_ID` or a placeholder. Missing or invalid values fail initialization with `hms_configuration_missing` before token acquisition.

The library supplies no `app_id`, `app_name`, or `infobip_application_code` placeholders. Define `app_name` in the host if you want it used as the SDK's default notification title. Pass the Infobip application code through `initialize(applicationCode: ...)`; no application-code resource is required by this plugin.

The repository example deliberately does not apply the AGConnect plugin or include `agconnect-services.json`; this keeps source validation independent of private host credentials. Do not commit AppGallery credentials, signing material, or secrets. The host application owns its package identity, signing configuration, permission UX, notification resources, and release configuration.

A typical Kotlin DSL application module adds the AGConnect plugin alongside its existing plugins after the plugin has been declared in the host project:

```kotlin
plugins {
    id("com.android.application")
    id("com.huawei.agconnect")
    id("dev.flutter.flutter-gradle-plugin")
}
```

Follow Huawei's current Push Kit integration documentation for the appropriate AGConnect plugin declaration and version.

## Android activity requirement

Embedded Chat hosts an Android fragment. The activity that displays it must extend `FlutterFragmentActivity`:

```kotlin
package com.example.app

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Ensure the package declaration matches the host application's namespace.

## Initialization

Initialize once before using any feature:

```dart
InfobipMobileMessagingHuawei.defaultMessageStorage = true;

await InfobipMobileMessagingHuawei.initialize(
  applicationCode: 'YOUR_APPLICATION_CODE',
);
```

Equivalent calls are idempotent. A conflicting application code is rejected after initialization begins; a failed call can be retried with the same code.
The default message store is enabled by default. Configure it before initialization;
changing the value does not alter the active SDK instance, but is used by the first
initialization after cleanup. This stores regular Mobile Messaging messages, not
Mobile Inbox or Chat history.

**Outgoing audio/video calls:** the separate [`HuaweiRtc` extension](docs/huawei-rtc-outgoing.md)
uses RTC Core 2.5.28 and internally acquires RTC tokens through initialized Huawei
Mobile Messaging. It provides typed application-call requests, events, active-call
snapshots and hangup. It is code/unit verified; Huawei device validation is pending.

**Official incoming-call APIs remain unsupported/guarded:** `enableCalls`,
`enableChatCalls` and `disableCalls` do not place outgoing calls. RTC UI 15.1.0
integration remains disabled because of unresolved Firebase linkage and HMS transport support. See
[the direct RTC Core investigation](docs/webrtc-core-research.md) for verified API/dependency limitations, and
[`docs/webrtc-configuration.md`](docs/webrtc-configuration.md) for initialization,
runtime usage, and dependency configuration.

For deployments that require JWT authorization, set or clear the SDK's memory-only JWT without logging it:

```dart
await InfobipMobileMessagingHuawei.setJwt(jwt);
await InfobipMobileMessagingHuawei.setJwt(null);
```

## Push and notifications

The host must declare and request Android notification permission where required. After permission is granted, request Infobip registration:

```dart
await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
```

Observe typed native events while the Flutter engine is running:

```dart
final notifications = InfobipMobileMessagingHuawei.notifications;

notifications.onMessageReceived.listen((message) {});
notifications.onNotificationTapped.listen((message) {});
notifications.onNotificationActionTapped.listen((event) {});
notifications.onRegistrationUpdated.listen((installation) {});
notifications.onInstallationUpdated.listen((installation) {});
```

The latest notification tap can be buffered natively and replayed once when Dart subscribes. Other events are not replayed. The SDK owns HMS token acquisition and refresh; this plugin does not expose raw token injection or a Dart background handler.

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

## Chat

Initialize the SDK before creating the view, use a bounded layout, and keep the controller scoped to that view:

```dart
final controller = InfobipHuaweiChatController();

InfobipHuaweiChatView(
  controller: controller,
  withInput: true,
  withToolbar: false,
  onError: (error) {},
)
```

The view uses the native Infobip composer and attachment workflow. Forward Flutter back navigation before popping the route:

```dart
final handled = await controller.navigateBackOrCloseChat();
if (!handled && context.mounted) {
  Navigator.of(context).pop();
}
```

Supported view commands are:

```dart
await controller.send(
  const InfobipHuaweiChatMessagePayload.text('Hello'),
);
await controller.sendContextualData('{"source":"support"}');
await controller.setLanguage('en-US');
final language = await controller.getLanguage();
await controller.setWidgetTheme('YOUR_WIDGET_THEME');
final theme = await controller.getWidgetTheme();
```

Global unread state is independent of a view:

```dart
final count =
    await InfobipMobileMessagingHuawei.chat.getUnreadMessageCount();
final subscription = InfobipMobileMessagingHuawei
    .chat
    .onUnreadMessageCounterUpdated
    .listen((count) {});
```

Chat does not expose thread commands, programmatic attachments, raw received-message models, or additional component lifecycle events. Programmatic sending is text-only; attachments remain available through the native composer. Language and theme settings are view-scoped and require an attached view.

## Example

The example covers initialization, notifications, user, installation, Inbox, and Chat. Supply a non-production application code at runtime:

```sh
cd example
flutter run \
  --dart-define=INFOBIP_APPLICATION_CODE=YOUR_APPLICATION_CODE
```

It intentionally contains neither a real Infobip Application Code nor Huawei credentials. Add your own ignored `android/app/agconnect-services.json` and host Gradle configuration before testing HMS push on a device.

## Limitations

- Android/Huawei only; there is no iOS implementation or FCM transport.
- There is no background Dart isolate. Native SDK processing may continue while Dart is not running.
- A compatible HMS environment, correctly configured Huawei and Infobip applications, network access, and applicable notification permission are required.
- Embedded Chat requires `FlutterFragmentActivity`, an attached activity, successful initialization, and backend Chat configuration.
- Chat thread APIs, raw-message events, headless history, and programmatic attachments are intentionally omitted.
- PlatformView behavior such as keyboard resizing, accessibility, attachment permissions, activity recreation, and route re-entry should be verified on supported physical devices.

## Security

- Never log application codes, JWTs, push tokens, Chat content, contextual data, identity data, or attachment paths.
- Do not commit Application Codes when they are sensitive in your deployment model.
- Do not commit `agconnect-services.json` when project policy treats it as sensitive.
- Never commit keystores, private keys, signing passwords, API keys, or other credentials.
- Validate and allow-list deep links before navigation.
