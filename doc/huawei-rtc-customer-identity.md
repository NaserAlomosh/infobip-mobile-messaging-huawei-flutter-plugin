# Outgoing RTC customer identity

## Identity modes and compatibility

Existing `HuaweiRtcCallRequest(identity: ...)` behavior is unchanged: the explicit
subject is passed to the native RTC token provider. Use this for a caller subject
authorized by your existing RTC integration. Omitting both identity options keeps
the original registered installation `pushRegistrationId` fallback. An External
User ID is not interchangeable with a Live Chat Registration ID.

Opt in with `liveChatIdentity` when outgoing customer calls should use the
customer identity associated with your Live Chat widget. This is additive; the
plugin never enables it implicitly for existing consumers. Supplying both modes
is rejected. No registration ID is returned to Dart. This option is an unreleased
addition and is not available in published version 1.0.1.

```dart
Future<HuaweiRtcCall> callCustomerSupport({
  required String callsConfigurationId,
  required String configuredChatWidgetId,
  required String personalizedExternalUserId,
  required bool video,
}) => HuaweiRtc.callApplication(HuaweiRtcCallRequest(
  callsConfigurationId: callsConfigurationId,
  type: video ? HuaweiRtcCallType.video : HuaweiRtcCallType.audio,
  liveChatIdentity: HuaweiRtcLiveChatIdentity(
    widgetId: configuredChatWidgetId,
    expectedExternalUserId: personalizedExternalUserId,
  ),
));
```

Initialize Mobile Messaging, wait for installation registration, complete
personalization for the expected user, and prepare the configured Live Chat
widget before calling. Subscribe to `HuaweiRtc.events` and obtain the existing
call permissions. Pass the exact same widget ID used by your Chat integration;
this API cannot infer it from Calls routing. Widget IDs and external user IDs
are compared exactly, including case and whitespace; there is no first-widget
or default-widget fallback.

## Resolution and failure behavior

One native call reservation covers resolution, token acquisition and submission.
The resolver fetches `getLivechatContactInformation(pushRegistrationId)` using the
current Huawei Mobile Messaging installation and application. Exactly one
`liveChatDestinations` entry must match `widgetId`, and its `registrationId` must
be nonblank. That registration ID becomes the subject of the existing
`MobileApiRtc.getToken(TokenBody(subject, 43200L))` flow. Audio/video options,
Calls routing, renderer and call ownership are unchanged.

The installation and expected personalized user are checked around lookup and
again before native call submission, including foreground-service startup.
Plugin initialize, cleanup, saveUser, personalize and depersonalize operations
invalidate pending Chat-associated requests. A process-wide epoch detects even
logout/relogin to the same user through another plugin engine. Calls in this mode
are rejected while one of those operations is pending. Explicit identity calls
retain their existing behavior. Account operations after call submission do not
retarget or automatically end an established call; hang up before switching users.
Hosts that also use native SDK APIs must serialize account changes through the
plugin; direct native SDK account mutations bypass its operation tracking.

There is no identity cache across calls or account changes. Registration IDs,
tokens, response payloads and personal data are not logged or exposed by the
plugin in this flow. Existing upstream SDK logging limitations remain documented
in [SECURITY.md](../SECURITY.md); this change does not certify SDK log suppression.
Engine disposal cancels pending requests; late results cannot submit a call.
Resolution and token acquisition share a 30-second preparation deadline. Task
interruption is best effort for an SDK network request already in progress; its
late result is discarded. There is no automatic retry or identity fallback.

| Error | Meaning / recovery |
|---|---|
| `rtc_invalid_argument` | Supply a nonblank widget and expected user; choose only one identity mode. |
| `rtc_not_initialized` | Initialize MM and wait for installation registration. |
| `rtc_invalid_state` | Expected personalization is absent/changed, an account operation is pending, the plugin was disposed, or the existing foreground/lifecycle checks failed. Complete the account operation and retry explicitly. |
| `rtc_identity_unavailable` | Missing/ambiguous widget destination, missing registration ID, network failure or lookup timeout. Check Chat setup/connectivity and retry explicitly. |
| `rtc_token_failed` | Existing token acquisition failure or timeout after resolution. |

Dart receives sanitized `HuaweiRtcException` messages, with no native response
body or identity. Existing permission, active-call and native call errors remain.

## Supported evidence and limitations

The supplied Huawei real-device results established working Live Chat, outgoing
audio and outgoing video. Using the resolved Live Chat Registration ID displayed
the customer's correct name and email in Infobip Conversations; using External
User ID displayed incorrect caller identity in that tested flow. Correct display
name/email does not guarantee equal internal People Person IDs. Automated tests
exercise resolution and lifecycle behavior; they do not replace repeating device
and backend validation after this hardening.

Infobip Conversations may create a new Conversation for each outgoing call; this
was observed in the supplied tests. The plugin has no verified supported mechanism
for forcing reuse of an existing Conversation. No Conversation ID, customData,
entityId, Portal settings or routing changes are introduced. Agent-initiated
application calls are available through the separate
[experimental foreground incoming flow](huawei-rtc-incoming.md); that flow does
not establish Conversation reuse. No RTC UI dependency is added.

This implementation uses the branch's pinned Huawei Core/Chat/Inbox **8.14.0**
and RTC Core **2.5.28** SDK APIs. No dependency upgrade is required or performed;
compatibility with other SDK versions is not certified here.
