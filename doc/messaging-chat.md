# Messaging, Inbox and Chat integration

Complete [Android/Huawei setup](../README.md#android--huawei-configuration) first.
The examples use the imports shown in the [README](../README.md#initialization).

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
customization before presenting Chat. See [API compatibility](../API_COMPATIBILITY.md).

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
