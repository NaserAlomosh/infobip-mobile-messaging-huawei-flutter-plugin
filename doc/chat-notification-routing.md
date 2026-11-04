# Chat notification navigation regression

Status: implementation and automated tests pass; real Huawei push acceptance is NOT VERIFIED.
No app build was installed and no actual push was generated during this repair.

## Root cause in this checkout

The previous override replaced the SDK's action navigation with a callback-Activity
launch. It retained a thread string and relied on the generic `NOTIFICATION_TAPPED`
event to finish navigation. The example's listener in
`example/lib/setup/example_controller.dart` only called
`recordPush('Notification tapped', message)`. It never called a Flutter Navigator.
`example/lib/app.dart` had an RTC return handler but no Chat return handler.
A threadless Chat notification also produced no retained thread target at all.

Therefore, the handoff stopped between the Flutter notification listener and
Flutter Navigator. An Activity launch is not a Flutter Chat route transition.
There is no evidence that the SDK stopped broadcasting taps: the published SDK
broadcaster tests deliver them, and SDK 9.4.0 calls its interaction handler before
broadcasting `NOTIFICATION_TAPPED`. The old tests asserted the callback Activity
and tap envelope, without asserting a `ChatScreen` or a Navigator transition.
That coverage gap let the incomplete handoff pass.

This explains the regression in the available implementation. No correlated trace
from the reported failed device tap was supplied, so the new diagnostics must
also confirm the runtime path on that device. Do not mark physical acceptance PASS
from the automated results below.

## Complete path after the repair

1. HMS push delivery and notification construction remain SDK-owned.
2. The SDK notification PendingIntent starts `NotificationTapReceiverActivity`.
   Its bundled Message reaches the Chat module's `messageTapped` method.
3. The existing startup provider installs the interaction override before a cold
   notification Activity runs. Embedded mode queues an explicit navigation request
   **including requests without a thread** before bringing the Flutter host forward.
   The callback Activity is used when configured; a launcher Intent is the fallback.
4. The existing EventChannel signals `chat_notification_navigation_requested`.
   The queue retains requests when no engine/listener exists, when a signal is
   missed, or when an engine detaches. Signal delivery never consumes the request.
5. Flutter subscribes at app level and also queries pending requests on the
   existing MethodChannel after the first frame, on resume, and after setup changes.
   Those queries recover a missed EventChannel signal.
6. The example handler waits for a resumed app, a Navigator, SDK initialization
   and the existing Chat preparation/authentication checks. It does not create
   another user identity or bypass setup. Failure leaves the request pending.
7. The Navigator opens named `/embedded-chat` or reuses the existing named route,
   including a route opened manually. The handler serializes processing and waits
   for a frame before acknowledging successful route opening.
8. The acknowledgement hands the preserved SDK-parsed thread target to the
   existing fragment-target mechanism and removes the navigation request.
   `ChatScreen` hosts `InfobipHuaweiChatView`, which creates `InAppChatFragment`.
   A target waits for fragment loading and is then shown in multithread mode.

Generic SDK tap events remain available for observation. Applications using this
handler must keep Chat Navigator ownership in the dedicated navigation handler.
Subscribing only to generic taps still does not install a navigation policy for
an arbitrary Flutter application's Navigator. The example app is wired; other host
apps must integrate the same query/open-or-reuse/acknowledge contract.

Native mode delegates to `getDefaultNotificationInteractionHandler()` and never
queues a Flutter Chat request. This preserves the SDK's original payload-dependent
behavior: SDK 9.4.0 uses its callback Activity for a Chat message without a parsed
action, and `InAppChatActivity` for a parsed `OpenLivechatAction`. Explicit
`showChat()` continues to present the SDK Activity.

## Request ownership and duplication

Each new request has a random correlation UUID. A pending duplicate with the same
SDK message ID reuses its original correlation and can wake the host again. Only
acknowledgement marks it handled; the last 64 completed SDK IDs are retained in
memory to suppress duplicate navigation. Distinct notifications remain queued in
arrival order. Missing SDK message IDs are treated as new requests rather than
suppressing a valid tap. SDK cleanup clears pending navigation/target state.

Mode selection is persisted. Pending navigation is process-memory metadata; no
message bodies, credentials or payloads are persisted by this repair. It survives
engine recreation, not an additional process death after the tap has already been
intercepted. A cold launch from an actual notification recreates the request through
the SDK tap path. This is not a durable event journal or a delivery guarantee for
force-stopped applications.

## Temporary diagnostics

Debug builds log only stage names, generated correlation IDs, and the resolved mode:

- `CHAT_NOTIFICATION_TAPPED`
- `CHAT_ACTION_INTERCEPTED`
- `CHAT_MODE_RESOLVED mode=embedded` (or `native`)
- `CHAT_EVENT_QUEUED`
- `CHAT_EVENT_DELIVERED_TO_FLUTTER` (EventChannel signal or MethodChannel query)
- `CHAT_EVENT_RECEIVED_BY_FLUTTER`
- `CHAT_NAVIGATION_REQUESTED`
- `CHAT_ROUTE_OPENED`
- `CHAT_FRAGMENT_ATTACHED` (new committed fragment or reuse of a loaded fragment)

Signal replay/query can repeat delivery/receipt markers for the same correlation.
That is not another navigation request. Native mode does not produce the embedded
queue/route markers. `CHAT_HOST_UNAVAILABLE` identifies failure to resolve any host
Activity. `CHAT_NAVIGATION_DEFERRED` identifies a Flutter exception without printing
the exception or SDK data.

Native diagnostics are gated by the host's debuggable flag; Flutter diagnostics by
`kDebugMode`. No tokens, authentication data, message bodies, SDK message IDs,
thread IDs or raw payloads are logged. Retain these temporary markers until device
acceptance; remove them in a separate cleanup after acceptance.

## Automated verification

| Requested scenario | Evidence | Physical acceptance |
| --- | --- | --- |
| No existing conversation | Native queue accepts a null thread; cold-start widget opens Chat and acknowledges | NOT RUN |
| Existing thread | Published SDK payload round-trip; navigation retains thread; fragment-target test | NOT RUN |
| Foreground | EventChannel wake causes an actual Navigator push in widget test | NOT RUN |
| Background | Widget lifecycle blocks route/ack until resumed | NOT RUN |
| Terminated application | Startup-provider and queued-before-app-mount tests simulate the cold path | NOT RUN |
| Engine absent | Native request remains through absent listener, detach and reattach until ack | NOT RUN |
| Duplicate tap | Same SDK ID retains original request, then suppresses completed duplicate; duplicate Flutter wakes reuse route | NOT RUN |
| Embedded Chat open | Both notification-opened and manually opened routes are reused in widget tests | NOT RUN |
| Native mode | SDK default-handler destination tests and no embedded route on informational tap | NOT RUN |
| Repeated taps | Distinct requests queue in order; repeated Flutter events reuse Chat | NOT RUN |

Full suite results:

- Android: PASS, 453 tests using installed Java 21.
- Plugin Flutter: PASS, 259 tests.
- Example Flutter: PASS, 57 tests, including eight new Navigator regression tests.
- Flutter analysis: PASS, no issues.
- `git diff --check`: PASS.

The tests use published SDK classes, Robolectric and real Flutter Navigators in
widget tests. They do not establish physical HMS delivery, vendor task behavior,
visual WebView readiness, backend authentication or actual thread selection.

## Real Huawei verification

1. Build/install a debug example or host app containing **both** this native code
   and the Flutter navigation handler. Use the existing local app/HMS configuration.
   Run SDK setup and the existing Chat personalization/auth checks successfully.
2. Explicitly select embedded mode before sending the test push:

   ```dart
   await InfobipMobileMessagingHuawei.chat.setNotificationPresentationMode(
     ChatNotificationPresentationMode.embedded,
   );
   ```

3. Start a private local trace. Do not enable payload/token logging:

   ```sh
   adb logcat -v threadtime InfobipChatNavigation:D flutter:I '*:S' | rg 'CHAT_(NOTIFICATION_TAPPED|ACTION_INTERCEPTED|MODE_RESOLVED|EVENT_QUEUED|EVENT_DELIVERED_TO_FLUTTER|EVENT_RECEIVED_BY_FLUTTER|NAVIGATION_REQUESTED|ROUTE_OPENED|FRAGMENT_ATTACHED|NAVIGATION_DEFERRED|HOST_UNAVAILABLE)'
   ```

4. Send a real chat push using the matching Infobip installation. Tap once. Confirm
   one correlation reaches `CHAT_ROUTE_OPENED` and `CHAT_FRAGMENT_ATTACHED`, the
   embedded screen is visible, and **no `InAppChatActivity` opens**. Confirm the
   correct conversation visually without putting its identifiers into logs.
5. Repeat for a fresh test conversation before outgoing messages, then after
   sending one message and receiving another push. Use an appropriate separate
   test installation/conversation when needed; do not erase live user data.
6. Repeat foreground, background, and absent-process cases. For the latter,
   background the initialized app and use `adb shell am kill <applicationId>`;
   verify the process is absent before sending/tapping. Do not substitute
   `am force-stop`, which changes delivery eligibility. Record any Huawei battery
   or task-management restrictions separately.
7. While Embedded Chat is already open, send and tap another notification. Confirm
   the same Flutter route/fragment is reused and the correct thread is selected.
   Exercise rapid repeated taps and several distinct notifications; confirm one
   route and no suppressed first valid request.
8. Exercise engine recreation/delayed startup and setup failure followed by recovery.
   Confirm the request remains pending until route opening; delivery markers may
   replay with the same correlation. A missing route acknowledgement must not
   remove it.
9. Select native mode and repeat both payload shapes. Compare with the SDK's
   default behavior; there must be no dedicated embedded navigation request.
10. Record PASS/FAIL for every scenario above, with a private trace and visual
    confirmation. Until a real Huawei tap visibly opens Embedded Chat, the
    regression's physical resolution remains **UNVERIFIED**.
