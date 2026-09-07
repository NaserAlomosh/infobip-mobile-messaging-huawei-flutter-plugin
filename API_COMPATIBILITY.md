# API Compatibility

This document summarizes the public API coverage of
`infobip_mobilemessaging_huawei` v1.0.0 against the Infobip Huawei
Mobile Messaging Android SDK 8.14.0.

The package is Android-only and targets Huawei Mobile Services (HMS).

## Status Legend

| Status | Meaning |
| --- | --- |
| **Supported** | Exposed with equivalent behavior. |
| **Adapted** | Supported through a Flutter-specific model, Future, Stream, or native Android bridge. |
| **Unsupported** | Not available in Huawei SDK 8.14.0 or not supported by this package. |
| **Intentionally omitted** | Available natively but intentionally not part of the stable v1 public API. |

---

## Core

| Capability | Status | Notes |
| --- | --- | --- |
| Initialize with Application Code | **Adapted** | Asynchronous and application-context scoped. |
| Configure JWT | **Adapted** | `setJwt` sets or clears the in-memory JWT used by supported requests. |
| SDK shutdown / reset | **Unsupported** | Flutter engine detachment does not reset the native SDK singleton. |

---

## Platform Support

| Capability | Status | Notes |
| --- | --- | --- |
| Android + Huawei Mobile Services | **Supported** | Android API 26+. |
| iOS | **Unsupported** | No iOS implementation is included. |
| Firebase / FCM | **Unsupported** | This package is specifically for Huawei/HMS. |

---

## Push Notifications

| Capability | Status | Notes |
| --- | --- | --- |
| Remote notification registration | **Adapted** | Host app owns runtime permission; Infobip SDK owns HMS token handling. |
| Message received | **Adapted** | Exposed through typed Flutter events. |
| Notification tapped | **Adapted** | Latest pending notification tap may replay once after subscription. |
| Notification action tapped | **Adapted** | Exposed through typed Flutter events. |
| Registration updates | **Adapted** | Exposes updated `Installation`. |
| Installation updates | **Adapted** | Exposes updated `Installation`. |
| Raw token injection | **Unsupported** | HMS and the Infobip SDK own token acquisition and refresh. |
| Background Dart isolate callback | **Unsupported** | Native processing remains available, but no Dart background handler is registered. |

---

## User Management

| Capability | Status | Notes |
| --- | --- | --- |
| Get cached user | **Supported** | Returns the locally cached SDK user. |
| Fetch user | **Supported** | Server fetch exposed as a `Future`. |
| Save user | **Supported** | Supported user properties and custom attributes can be updated. |
| Personalize user | **Adapted** | Maps Flutter identity and attributes to Huawei SDK models. |
| Depersonalize user | **Adapted** | Disconnects the current user identity. |
| Delete server user | **Unsupported** | Depersonalization is not server-side user deletion. |

---

## Installation Management

| Capability | Status | Notes |
| --- | --- | --- |
| Get cached installation | **Supported** | Returns local SDK installation state. |
| Fetch installation | **Supported** | Server refresh exposed as a `Future`. |
| Save installation | **Adapted** | Only supported writable fields are accepted. |
| Primary device state | **Adapted** | Can be updated where supported by the SDK. |
| Custom attributes | **Adapted** | Supports Huawei-compatible scalar/date/list values. |
| Delete installation | **Unsupported** | No public v1 installation-deletion API. |

---

## Mobile Inbox

| Capability | Status | Notes |
| --- | --- | --- |
| Fetch Inbox | **Adapted** | External user ID is explicit. |
| Filter messages | **Adapted** | Supports time, topic, and result-limit filters. |
| Inbox counters | **Adapted** | Returned with server-backed Inbox data. |
| Mark message as seen | **Adapted** | Uses the native Inbox SDK operation. |
| Optional request JWT | **Adapted** | Supported for authenticated Inbox requests. |
| Offline-authoritative Inbox | **Unsupported** | Inbox state remains server-backed. |
| Native Inbox event stream | **Intentionally omitted** | Not part of the stable v1 Flutter API. |

---

## In-App Chat

### UI

| Capability | Status | Notes |
| --- | --- | --- |
| Embedded native Chat UI | **Adapted** | Uses `InAppChatFragment` through a Flutter PlatformView. |
| Native message composer | **Supported** | Composer remains fully native. |
| Native attachment picker | **Supported** | Attachment handling remains native. |
| Chat back navigation | **Adapted** | Controller reports whether native Chat consumed the back action. |
| Chat scrolling | **Adapted** | Flutter gesture handling is configured for the embedded native view. |

### Chat APIs

| Capability | Status | Notes |
| --- | --- | --- |
| Unread message count | **Adapted** | Current value exposed as a `Future`. |
| Unread count updates | **Adapted** | Exposed as a Flutter stream. |
| Send text message | **Adapted** | Requires an attached Chat view. |
| Send contextual data | **Adapted** | Requires an attached Chat view. |
| Set draft message | **Adapted** | Sets the native composer draft for the active conversation; an empty string clears it. |
| Language | **Adapted** | View-scoped native widget configuration. |
| Widget theme | **Adapted** | View-scoped native widget configuration. |
| Chat exception handler | **Adapted** | `setChatExceptionHandler` maps Huawei `InAppChat.setExceptionHandler` exceptions to nullable `message` and `name` fields. A custom handler replaces Huawei's default exception presentation; passing `null` restores it. Android/Huawei only. |
| Programmatic attachments | **Unsupported** | The pinned official Flutter API has no public programmatic attachment contract to reproduce. Huawei 8.14.0 exposes attachment handling only through its native Chat component contract; the plugin does not invent a Dart file/URI model. |
| Thread APIs | **Intentionally omitted** | Stable thread models are not exposed in v1. |
| Raw Chat messages | **Intentionally omitted** | v1 does not expose raw component messages. |
| Additional Chat runtime events | **Intentionally omitted** | Only stable v1 Chat events are exposed. |

### Contextual Data Audit

The public behavior was compared with the official Flutter plugin at commit
`8b630d0f736d400635317131d549c345349bd54d`. Its public API defines
`ChatMultithreadStrategies` with `ACTIVE`, `ALL`, and `ALL_PLUS_NEW`, keeps the
boolean `sendContextualData` API deprecated, and defaults
`sendContextualDataWithStrategy` to `ACTIVE`. Its Android implementation maps
the public strategy to the Android Chat SDK multithread strategy. The iOS
implementation is relevant to cross-platform parity, but this package remains
Android/Huawei-only.

Huawei Mobile Messaging SDK 8.14.0 source commit
`5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824` exposes
`InAppChatFragment.sendContextualData(String, MultithreadStrategy)` and all
three `MultithreadStrategy` values used below.

| Official Flutter strategy | Huawei 8.14 native strategy | Classification | Semantics and requirements |
| --- | --- | --- | --- |
| `ACTIVE` | `MultithreadStrategy.ACTIVE` | **EXACT** | Applies to the active conversation. This is the default and the behavior of the package's pre-existing `sendContextualData(String)` API. |
| `ALL` | `MultithreadStrategy.ALL` | **EXACT** | Applies to all existing conversations. It has multithread significance only when the configured widget is multithread. |
| `ALL_PLUS_NEW` | `MultithreadStrategy.ALL_PLUS_NEW` | **EXACT** | Applies to all existing conversations and conversations created later. It has multithread significance only when the configured widget is multithread. |

The operation remains view-scoped: a controller must be attached to a live
`InAppChatFragment`. The plugin does not retain a global Fragment or force the
widget into multithread mode. In single-thread mode, behavior remains entirely
SDK-defined. Contextual data is opaque and forwarded byte-for-byte as a Dart
`String`; empty or whitespace-only values continue to be rejected before the
native call, preserving the package's existing contract.

The existing `sendContextualData(String)` method remains source compatible and
delegates to `ACTIVE`. Dart cannot overload that method with the official
deprecated `sendContextualData(String, bool)` signature, so adding the boolean
signature would break existing callers. `sendContextualDataWithStrategy` is the
non-conflicting official-compatible API.

### Chat Draft Messages

The draft-message API was audited against the official Flutter plugin at commit
`8b630d0f736d400635317131d549c345349bd54d` and Huawei Mobile Messaging SDK
8.14.0 source commit `5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824` before the bridge was added.

The official Flutter contract is the one-way
`Future<void> setChatDraftMessage(String draftMessage)` operation. A draft is a
plain, non-nullable `String`; there is no draft model, getter, thread identifier,
timestamp, or separate clear API. The official Android implementation forwards
the string to the Android Chat SDK's `setDraftMessage(String)` API. It does not
trim or transform the value. An empty string clears the composer draft.

Huawei 8.14.0 exposes `InAppChatFragment.setDraftMessage(String)`. The operation
updates the native widget composer and is therefore view-scoped and
active-conversation-scoped. In multithread mode it applies to the conversation
currently displayed by the fragment. It cannot select a thread by identifier,
set drafts for all threads, or retrieve drafts. On the thread list there is no
active composer to update. A newly created or subsequently selected thread is
not assigned a Flutter-maintained copy of an earlier draft.

This package exposes the same method name and string contract on
`InfobipHuaweiChatController`. Controller placement is an architectural
adaptation because the package embeds `InAppChatFragment` instead of exposing
the official plugin's global Chat presentation flow. The existing view channel
and fragment lifecycle remain the source of truth; no Dart or Android duplicate
draft state is retained.

| Official API / field | Huawei 8.14 API | Classification | Notes |
| --- | --- | --- | --- |
| `setChatDraftMessage(String draftMessage)` | `InAppChatFragment.setDraftMessage(String)` | **MAPPABLE** | Same one-way value semantics, scoped to the attached embedded view. |
| `draftMessage` (`String`, non-null) | `String` | **EXACT** | Whitespace and all other string content are preserved. |
| Empty string clearing | `setDraftMessage("")` | **EXACT** | Clears the active native composer. |
| Null draft | No nullable overload | **NOT_AVAILABLE** | Rejected by the Dart type system and by native channel validation. |
| Draft getter/model | No official API | **NOT_AVAILABLE** | No getter or fabricated model is exposed. |
| Explicit thread selection | No official API; active fragment conversation only | **NOT_AVAILABLE** | The bridge does not invent thread IDs or global storage. |
| iOS implementation | No iOS implementation in this Huawei plugin | **IOS_ONLY** | Package remains Huawei Android-only. |

Draft operations require an attached, non-disposed controller and a live added
fragment. Calls made before attachment or after disposal fail with the existing
`chat_unavailable` platform error. Native runtime failures use `native_error`
and are returned to the caller; they are not sent through the Chat exception
handler. Calls are posted through the existing view lifecycle guard, preventing
a queued operation from targeting a replaced or disposed fragment.

### Chat Attachments

**Feature classification: PARTIALLY_SUPPORTED.** Attachment sending is
available from the embedded Huawei native composer. There is no semantically
equivalent public programmatic attachment API to add to Dart at the pinned
official Flutter revision, so this audit does not add a controller method,
attachment model, channel command, or custom upload implementation.

The official Flutter plugin was inspected at commit
`8b630d0f736d400635317131d549c345349bd54d`. Its public Chat surface contains
text sending through `sendChatMessage(String)`, but it does not export
`sendAttachment`, `sendChatAttachment`, `ChatAttachment`, or another public
file/URI attachment input. Its Android and iOS Chat presentation integrations
leave attachment selection and sending to their respective native Chat UI.
Consequently there are no official public attachment constructor fields,
enums, serialization rules, completion result, progress callback, or
deprecated attachment methods to reproduce.

Huawei Mobile Messaging SDK 8.14.0 was inspected at source commit
`5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824`. The Chat module contains
`InAppChatAttachment` and `AttachmentSource`, and `InAppChatFragment` owns the
native input and its attachment workflow. The component also accepts
`MessagePayload` through `send(MessagePayload)`, but the pinned sources do not
establish an official-Flutter-compatible public file/URI contract. These native
types are therefore not exposed over the MethodChannel and are not projected
into a fabricated Dart model.

| Official API / field | Huawei 8.14 API | Classification | Notes |
| --- | --- | --- | --- |
| Native Chat composer attachment action | `InAppChatFragment` native input using `InAppChatAttachment` / `AttachmentSource` | **MAPPABLE** | Already available in `InfobipHuaweiChatView` when `withInput` is enabled; selection, upload, and native result handling remain SDK-owned. |
| Public programmatic attachment method | No official public Flutter method | **NOT_AVAILABLE** | No Dart controller method or channel command is added. |
| Public attachment model | No official public Flutter model | **NOT_AVAILABLE** | Native attachment objects are not serialized as untyped maps. |
| File path or URI argument | No official public Flutter argument | **NOT_AVAILABLE** | The bridge does not convert paths to URIs, resolve `content://` values, read bytes, or retain URI grants. |
| MIME type argument | No official public Flutter argument | **NOT_AVAILABLE** | MIME detection and validation remain inside the native composer/SDK workflow. |
| File-name argument | No official public Flutter argument | **NOT_AVAILABLE** | The plugin neither supplies nor fabricates a file name. |
| Upload progress | No official public Flutter callback | **NOT_AVAILABLE** | No progress event is exposed or simulated. |
| Programmatic send completion | No official public Flutter result | **NOT_AVAILABLE** | Native composer feedback remains native; the plugin makes no delivery or upload-completion guarantee. |
| Android native composer | Huawei Chat component | **ANDROID_ONLY** | This package supports Huawei Android only. |
| Official iOS native composer | Infobip iOS Chat UI | **IOS_ONLY** | Reviewed for parity awareness; no iOS implementation is included in this package. |

The native composer determines which configured attachment sources and media
types are offered. The audited public surfaces do not provide a portable,
exhaustive file-type list, and the plugin therefore does not claim support for
images, video, audio, PDF, generic documents, or arbitrary files individually.
No plugin-specific file-size limit is imposed; backend and SDK validation still
apply, and this document does not infer a limit that is not public in the
audited contract.

Attachment destination follows the native composer. In single-thread mode it
uses that conversation; in multithread mode it uses the conversation whose
composer is currently active. The plugin does not add a `threadId`, change the
active thread, or preserve an attachment across thread changes. On the thread
list there is no active conversation composer.

The operation remains bound to the existing `InAppChatFragment` and Android
view lifecycle. Disposal removes the fragment and its channel handler; the
plugin retains no `Activity`, `Context`, `Fragment`, `Uri`, path, MIME value, or
attachment metadata for later use. Native picker permission requests and URI
access remain owned by Huawei Chat and Android. The plugin adds no broad storage
permission, `FileProvider`, Storage Access Framework bridge, or persistable URI
grant. Applications should validate the native picker behavior on their
supported Android versions and devices.

---

## Public Models

### Notifications

`Message` mirrors the official shared notification model. Huawei-backed values
include message presentation, timestamps, seen state, URL actions, custom
payload, internal data, and Chat state. `originalPayload` remains nullable
because Huawei 8.14.0 cannot provide the iOS-specific value.
`PushMessage` is a deprecated source-compatible alias.

### User

- `UserData` (`User` remains a deprecated alias)
- `UserIdentity`
- `UserAttributes`

These models expose supported Infobip profile and identity fields.

Birthday values retain date-only semantics, while custom `DateTime` attributes
represent UTC timestamps.

### Installation

`Installation`

Represents SDK-managed device and registration information.

Only fields explicitly supported for modification by the plugin can be updated.

### Inbox

- `Inbox`
- `Message` (`InboxMessage` remains a deprecated alias)
- `FilterOptions` (`InboxFilterOptions` remains a deprecated alias)

Supports server counters, Inbox messages, time filters, topic filters, and result
limits.

### Chat

- `InfobipHuaweiChatMessagePayload`
- `InfobipHuaweiChatError`
- `ChatException`

`InfobipHuaweiChatMessagePayload` represents outbound text messages.

`InfobipHuaweiChatError` represents typed Chat view lifecycle and availability
errors.

`ChatException` matches the official Flutter model's nullable `message` and
`name` fields. Huawei SDK 8.14.0 supplies both through its native Chat exception
callback; no stack trace, native object, HTTP status, identity, or credentials
are exposed.

### Chat exception mapping audit

The desired API is the official Flutter
`setChatExceptionHandler(Future<void> Function(ChatException)?, [onError])` at
commit `8b630d0f736d400635317131d549c345349bd54d`. The native audit is pinned to
Huawei commit `5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824`, corresponding to SDK
8.14.0.

| Official Flutter API / field | Huawei 8.14.0 source | Classification |
| --- | --- | --- |
| `setChatExceptionHandler(handler, onError)` | `InAppChat.setExceptionHandler` | **MAPPABLE** |
| Replace the current handler | Singleton `InAppChat` handler property | **EXACT** |
| `null` restores default handling | `InAppChat.setExceptionHandler(null)` | **EXACT** |
| `ChatException.message` (`String?`) | Native exception `message` | **EXACT** |
| `ChatException.name` (`String?`) | Native exception `name` | **EXACT** |
| iOS behavior | No iOS implementation in this Huawei plugin | **IOS_ONLY** |

---

## Data Type Constraints

Custom User and Installation attributes support Huawei SDK 8.14.0 compatible
values:

- `String`
- `bool`
- numeric values
- dates
- lists containing supported scalar values

Native Android SDK objects are converted into Flutter-safe models and are never
exposed directly.

---

## Event Delivery

Notification events are not treated as a persistent event queue.

The latest pending notification tap may be replayed once after Flutter
subscribes. Other notification events are delivered only while the Flutter
engine and event subscriber are active.

---

## Chat Requirements

In-App Chat requires:

- successful Infobip SDK initialization
- an Android `FragmentActivity`
- Chat enabled for the configured Infobip application/profile
- a compatible Huawei Android environment

Chat is exposed primarily as a native UI integration rather than a headless
conversation API.
## Model Parity

The audit is pinned to official Flutter commit
`8b630d0f736d400635317131d549c345349bd54d` and Huawei SDK 8.14.0
(reference revision `83786a498f165386041bf75e71488f1635f8af94`).

`Message.receivedTimestamp` and `Message.seenDate` are numeric milliseconds
since the Unix epoch. `UserData.birthday` and `UserAttributes.birthday` are
nullable `YYYY-MM-DD` strings. Huawei converts those strings to and from its
native `Date` representation without exposing `DateTime` in Dart.

`PushServiceType.APNS` is retained for official model parity but cannot be returned by the Huawei Android SDK. `PushServiceType.HMS` represents the Huawei transport and is never remapped to Firebase.

| Model | Field | Official Flutter type | Huawei native type/source | Old plugin type | New plugin type | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `Message` | `messageId` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `title` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `body` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `sound` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `icon` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `category` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `internalData` | `String?` | `Message.getInternalData()` | `String?` | `String?` | **EXACT** |
| `Message` | `contentUrl` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `browserUrl` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `deeplink` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `webViewUrl` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `inAppOpenTitle` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `inAppDismissTitle` | `String?` | `Message / MessageJson` | `String?` | `String?` | **EXACT** |
| `Message` | `vibrate` | `bool?` | `Message / MessageJson` | `bool?` | `bool?` | **EXACT** |
| `Message` | `silent` | `bool?` | `Message / MessageJson` | `bool?` | `bool?` | **EXACT** |
| `Message` | `seen` | `bool?` | `Message / MessageJson` | `bool?` | `bool?` | **EXACT** |
| `Message` | `chat` | `bool?` | `Message / MessageJson` | `bool?` | `bool?` | **EXACT** |
| `Message` | `customPayload` | `Map<String, dynamic>?` | `Message.customPayload (JSONObject)` | `Map<String, Object?>?` | `Map<String, dynamic>?` | **CONVERTED** |
| `Message` | `originalPayload` | `Map<String, dynamic>?` | `Not available on Huawei Android` | `Map<String, Object?>?` | `Map<String, dynamic>?` | **NULL_ON_HUAWEI** |
| `Message` | `receivedTimestamp` | `num?` | `MessageJson numeric epoch milliseconds` | `DateTime?` | `num?` | **CONVERTED** |
| `Message` | `seenDate` | `num?` | `MessageJson numeric epoch milliseconds` | `DateTime?` | `num?` | **CONVERTED** |
| `Message` | `topic` | `String?` | `InboxMessage.topic` | `String?` | `String?` | **HUAWEI_EXTENSION** |
| `Installation` | `installationId` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `pushRegistrationId` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `pushServiceToken` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `sdkVersion` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `appVersion` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `os` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `osVersion` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `deviceManufacturer` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `deviceModel` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `language` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `deviceTimezoneOffset` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `applicationUserId` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `deviceName` | `String?` | `Installation / InstallationJson` | `String?` | `String?` | **EXACT** |
| `Installation` | `pushServiceType` | `PushServiceType?` | `PushServiceType (HMS on Huawei)` | `PushServiceType? (FCM alias)` | `PushServiceType? (GCM, Firebase, APNS, HMS)` | **CONVERTED** |
| `Installation` | `isPrimaryDevice` | `bool?` | `Installation / InstallationJson` | `bool?` | `bool?` | **EXACT** |
| `Installation` | `isPushRegistrationEnabled` | `bool?` | `Installation / InstallationJson` | `bool?` | `bool?` | **EXACT** |
| `Installation` | `notificationsEnabled` | `bool?` | `Installation / InstallationJson` | `bool?` | `bool?` | **EXACT** |
| `Installation` | `deviceSecure` | `bool?` | `Installation / InstallationJson` | `bool?` | `bool?` | **EXACT** |
| `Installation` | `customAttributes` | `Map<String, dynamic>?` | `Installation.customAttributes` | `Map<String, Object?>?` | `Map<String, dynamic>?` | **CONVERTED** |
| `UserData` | `externalUserId` | `String?` | `User / UserJson` | `String? final` | `String? mutable` | **CONVERTED** |
| `UserData` | `firstName` | `String?` | `User / UserJson` | `String? final` | `String? mutable` | **CONVERTED** |
| `UserData` | `lastName` | `String?` | `User / UserJson` | `String? final` | `String? mutable` | **CONVERTED** |
| `UserData` | `middleName` | `String?` | `User / UserJson` | `String? final` | `String? mutable` | **CONVERTED** |
| `UserData` | `birthday` | `String?` | `Date? formatted by UserJson as yyyy-MM-dd` | `DateTime? final` | `String? mutable` | **CONVERTED** |
| `UserData` | `gender` | `Gender?` | `UserAttributes.Gender` | `Gender? including unknown` | `Gender? (Male, Female)` | **CONVERTED** |
| `UserData` | `type` | `Type?` | `User.Type` | `Type? with non-official names` | `Type? (LEAD, CUSTOMER)` | **CONVERTED** |
| `UserData` | `phones` | `List<String>?` | `Set<String>? serialized by UserJson` | `List<String>?` | `List<String>?` | **EXACT** |
| `UserData` | `emails` | `List<String>?` | `Set<String>? serialized by UserJson` | `List<String>?` | `List<String>?` | **EXACT** |
| `UserData` | `tags` | `List<String>?` | `Set<String>? serialized by UserJson` | `List<String>?` | `List<String>?` | **EXACT** |
| `UserData` | `customAttributes` | `Map<String, dynamic>?` | `Map<String, CustomAttributeValue>?` | `Map<String, Object?>?` | `Map<String, dynamic>?` | **CONVERTED** |
| `UserData` | `installations` | `List<Installation>?` | `List<Installation>?` | `List<Installation>?` | `List<Installation>?` | **EXACT** |
| `UserIdentity` | `externalUserId` | `String?` | `UserIdentity.externalUserId` | `String? final` | `String? mutable` | **CONVERTED** |
| `UserIdentity` | `phones` | `List<String>?` | `Set<String>?` | `List<String>? final` | `List<String>? mutable` | **CONVERTED** |
| `UserIdentity` | `emails` | `List<String>?` | `Set<String>?` | `List<String>? final` | `List<String>? mutable` | **CONVERTED** |
| `UserAttributes` | `firstName` | `String?` | `UserAttributes; birthday is native Date` | `birthday was DateTime?; fields final` | `String? mutable` | **CONVERTED** |
| `UserAttributes` | `lastName` | `String?` | `UserAttributes; birthday is native Date` | `birthday was DateTime?; fields final` | `String? mutable` | **CONVERTED** |
| `UserAttributes` | `middleName` | `String?` | `UserAttributes; birthday is native Date` | `birthday was DateTime?; fields final` | `String? mutable` | **CONVERTED** |
| `UserAttributes` | `birthday` | `String?` | `UserAttributes; birthday is native Date` | `birthday was DateTime?; fields final` | `String? mutable` | **CONVERTED** |
| `UserAttributes` | `gender` | `Gender?` | `UserAttributes.Gender` | `Gender? final including unknown` | `Gender? mutable (Male, Female)` | **CONVERTED** |
| `UserAttributes` | `tags` | `List<String>?` | `Set<String>?` | `List<String>? final` | `List<String>? mutable` | **CONVERTED** |
| `UserAttributes` | `customAttributes` | `Map<String, dynamic>?` | `Map<String, CustomAttributeValue>?` | `Map<String, Object?>?` | `Map<String, dynamic>? mutable` | **CONVERTED** |
| `PersonalizeContext` | `forceDepersonalize` | `bool` | `PersonalizeContext.forceDepersonalize` | `bool` | `bool` | **EXACT** |
| `PersonalizeContext` | `userIdentity` | `UserIdentity` | `UserIdentity` | `UserIdentity` | `UserIdentity` | **EXACT** |
| `PersonalizeContext` | `userAttributes` | `UserAttributes?` | `UserAttributes?` | `UserAttributes?` | `UserAttributes?` | **EXACT** |
| `Inbox` | `countTotal` | `int` | `Inbox counters` | `int` | `int` | **EXACT** |
| `Inbox` | `countUnread` | `int` | `Inbox counters` | `int` | `int` | **EXACT** |
| `Inbox` | `countTotalFiltered` | `int` | `Inbox counters` | `int` | `int` | **EXACT** |
| `Inbox` | `countUnreadFiltered` | `int` | `Inbox counters` | `int` | `int` | **EXACT** |
| `Inbox` | `messages` | `List<Message>` | `List<InboxMessage> mapped to Message JSON` | `List<Message>` | `List<Message>` | **EXACT** |
| `FilterOptions` | `fromDateTime` | `DateTime?` | `MobileInboxFilterOptions Date?` | `DateTime?` | `DateTime?` | **EXACT** |
| `FilterOptions` | `toDateTime` | `DateTime?` | `MobileInboxFilterOptions Date?` | `DateTime?` | `DateTime?` | **EXACT** |
| `FilterOptions` | `topic` | `String?` | `MobileInboxFilterOptions topic` | `String?` | `String?` | **EXACT** |
| `FilterOptions` | `limit` | `int?` | `MobileInboxFilterOptions limit` | `int?` | `int?` | **EXACT** |
| `FilterOptions` | `topics` | `Not in official API` | `Huawei list-topic constructor` | `List<String>?` | `List<String>?` | **HUAWEI_EXTENSION** |

### Compatibility aliases

Deprecated aliases preserve pre-v1 source compatibility for `PushMessage`,
`User`, `InboxMessage`, `InboxFilterOptions`, `deepLink`, `isSilent`,
`pushRegistrationEnabled`, `applicationVersion`, `operatingSystem`,
`operatingSystemVersion`, `deviceTimezoneId`, and `appUserId`. Canonical code
should use the official-style names.
