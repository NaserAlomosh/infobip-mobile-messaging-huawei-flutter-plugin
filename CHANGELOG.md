# 1.0.0

First public release preparation. The development API defines the initial
public API for version 1.0.0; earlier branch APIs were unpublished.

- Added Huawei HMS Push registration and Infobip Mobile Messaging initialization.
- Added message, notification tap/action, registration, installation and user events.
- Added user personalization, installation management, custom events and Mobile Inbox.
- Added native and embedded Infobip Chat, native attachments, unread counters,
  view-scoped text/context/language/theme/back navigation, typed runtime events,
  global customization and Chat notification overrides.
- Added Chat JWT provider authentication, separate from Mobile Messaging JWTs.
- Added outgoing RTC Core application audio/video calls with native backend token
  acquisition, typed lifecycle events and active-call snapshots.
- Added local/remote video rendering, microphone mute, audio routing, speaker,
  camera enable/switch controls and SDK duration/readback.
- Added ongoing RTC foreground notifications with return-to-call and hangup actions.
- Added Android 10+ Screen-as-Camera sharing through MediaProjection and VideoFilter,
  fresh consent, capture foreground notification/Stop and camera restoration.
- Hardened call/capture ownership, cleanup retries, bounded Stop, late callback
  rejection and Activity/engine lifecycle handling.
- Reduced screen-capture work with reused conversion scratch storage, latest-frame
  draining, blocked-generation rejection and cached geometry. SDK output Bitmaps
  remain independent; physical CPU/memory improvements are not quantified.
- Improved screen publication orientation, aspect-preserving fit-center output,
  resize-triggered Stop and unmirrored local screen preview. RTC Core 2.5.28 camera
  output remains 640×480, limiting portrait readability.
- Bounded Chat JWT requests at 25 seconds in Dart and 30 seconds natively, with
  32-request limits, safe failure and stale-result protection (CHAT-01).
- Made failed Chat activation retryable with the same application code after a
  one-second cooldown while retaining Mobile Messaging initialization (CHAT-02).
- Made plugin cleanup failure-safe: clear callbacks/state after native success,
  share concurrent cleanup and reject conflicting lifecycle operations (API-01).
  Vendor-internal cleanup is not guaranteed to roll back partial failures.
- Aligned public Message, Installation, UserData, PersonalizeContext, Inbox and
  FilterOptions names with the official Flutter models; retained deprecated aliases.
- Added release integration/security guides and explicit package exclusions.

The root MIT LICENSE and third-party notices are included. Owner-controlled
provenance and redistribution confirmations remain separate from technical
merge readiness. Publication requires explicit owner authorization.
Known unresolved risks: Huawei Mobile Messaging 8.14.0 authorization-header logging
and RTC 2.5.28 signaling logging that may expose temporary TURN credentials.
SEC-01 remains PARTIALLY MITIGATED; the optional host Release R8 workaround does
not cover RTC printf or guarantee removal of all sensitive logs. The owner has
decided not to submit a vendor report before publication; disclosure is not a
publication gate. Physical Huawei/backend, signed-host and 16 KB runtime acceptance
remain UNVERIFIED production checks. No security certification or publication is
claimed. See [security guidance](SECURITY.md).
