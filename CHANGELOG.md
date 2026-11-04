## 2.2.1 - 2026-11-04

### Fixed

- Corrected release metadata and documentation inconsistencies.

### Changed

- Updated package documentation for the v2.2.1 release.

## 2.2.0 - 2026-11-04

### Added

- Public Chat notification presentation modes and pending-navigation query,
  event and acknowledgement APIs for host-owned Flutter navigation.
- Example app startup/resume recovery, ordered request handling, duplicate
  suppression and reuse of the embedded Chat route.

### Changed

- Upgrade Infobip Huawei Core, Inbox and Chat from 9.3.0 to 9.4.0.
  RTC Core remains 2.5.28; Flutter/Android build requirements are unchanged.
- Native SDK-owned notification presentation remains the default when no mode
  is saved. Embedded routing requires explicit opt-in and a host navigation handler;
  previously saved native or embedded choices remain unchanged.
  Pending navigation survives engine recreation, but is not persisted across
  another process death after interception.

### Fixed

- Use hybrid composition and container-based fragment attachment for embedded
  Chat; report a 30-second loading timeout and detach callbacks during disposal.
- Preserve SDK-parsed thread targets until route acknowledgement, including
  threadless notification requests and delayed Flutter startup.

### Security

- Preserve pre-SDK email validation and existing logging mitigations. SEC-01
  remains PARTIALLY MITIGATED; SDK 9.4.0 does not resolve upstream sensitive logging.

### Documentation

- Align current SDK/version references and document native versus embedded
  notification ownership, lifecycle limitations and release validation evidence.

No public API removals or new host build requirements. Physical Huawei push,
visual Chat readiness, backend behavior and signed upgrade/rollback remain
unverified by automated checks.

## 2.1.0

- Add typed `patchUser` updates that preserve omitted fields and explicit clears without changing `saveUser`.
- Add optional `PersonalizeContext.keepAsLead` and `setDeviceAsPrimary`, both
  defaulting to false, forwarded to Huawei SDK 9.3.0. Backend lead retention,
  primary-device selection and persistence still require device/backend validation.
- Reject newly supplied emails longer than 255 UTF-16 code units in `saveUser`,
  `patchUser`, `personalize` and legacy `personalizeUser` before SDK entry, with
  code `-10` and a value-free message. Accepted values remain unchanged; no syntax
  validation, trimming or normalization is added. Previously pending emails and
  SDK-managed synchronization remain upstream risks; SEC-01 remains unresolved.
- Correct API/setup documentation, distinguish current guides from historical
  reports, and retain native CI test reports for failure diagnosis.
- Preserve SDK versions, host requirements, and the PARTIALLY MITIGATED SEC-01
  classification; automated checks do not establish device/backend acceptance.

## 2.0.0

- Upgrade Huawei Mobile Messaging Core, Inbox and Chat to 9.3.0; retain RTC
  2.5.28 and WebRTC 1.0.45036.
- **Breaking build requirements:** Flutter >=3.44.4, Dart ^3.12.2, compileSdk 37;
  validated with AGP 9.1.1, Gradle 9.3.1 and legacy Kotlin 2.2.10.
- Document required host AGP transition flags and the temporary shared vendor
  namespace exception. Preserve minSdk 26, targetSdk 36 and public Dart APIs.
- Adapt native Chat compatibility and update integration documentation.
- SEC-01 remains unresolved upstream and only partially mitigated by the existing
  optional host Release R8 rule. The owner acknowledges the logging risk and has
  approved release preparation; this is not security certification.

## 1.1.0

- Added opt-in `HuaweiRtcCallRequest.liveChatIdentity` with
  `HuaweiRtcLiveChatIdentity` for outgoing customer audio/video calls. Resolves
  the exact Chat widget registration natively with account/lifecycle validation,
  bounded preparation and no identity fallback or registration-ID exposure.
- Preserved explicit RTC identity and installation fallback behavior. Conversation
  reuse remains unverified/unsupported. Huawei 8.14.0 and RTC Core 2.5.28
  dependencies are unchanged.
- Added experimental foreground incoming application audio/video calls with
  Accept/Decline, native ringtone with best-effort speaker routing, explicit local
  camera acceptance, local/remote video, existing media controls and termination
  cleanup. Invitations require explicit foreground registration; background and
  terminated-app incoming calls are unsupported. Offered media type is unknown,
  incoming auto-reconnect is disabled, and registration is process-scoped with no
  supported token replacement or unregister API. Account changes and engine
  detachment invalidate the flow and require process recreation before retrying.
- Corrected current incoming RTC documentation and documented its experimental
  lifecycle contract. Included consumer identity and incoming guides in package
  contents while retaining internal investigation exclusions.
- Simplified example startup to direct `ExampleTestConfig` Dart constants, mapped
  synchronously into the existing controller. Added a one-time safe-default setup
  command that preserves existing private files; removed JSON configuration assets,
  runtime loading and alternate-launcher setup.
- Expanded Huawei, Infobip, Inbox authentication and RTC routing documentation;
  added GitHub Sponsors configuration.
- Kept private test configuration and internal audit artifacts out of package
  contents. Hardcoded test credentials remain extractable from test APKs.

Existing public APIs remain source-compatible; SDK/toolchain dependencies are unchanged.
The new identity option is additive. Incoming RTC remains experimental and
foreground-only. SEC-01 upstream sensitive logging remains partially mitigated;
see [security guidance](SECURITY.md).

## 1.0.1

### Documentation

- Added complete Huawei AppGallery Connect setup instructions.
- Added Infobip Portal configuration instructions.
- Added a configuration reference for required credentials.
- Improved installation and initialization examples.
- Improved Chat, Push, and RTC onboarding.
- Updated documentation for the published package.

This update changes documentation and the package version only. SDK dependencies,
public APIs and runtime behavior are unchanged.

## 1.0.0

First public release. The development API defines the initial
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
