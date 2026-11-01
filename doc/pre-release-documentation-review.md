# Pre-release documentation review — 25 October 2026

This is a maintainer record, excluded from pub.dev by `.pubignore`. The root
README is the primary integration guide; the six included consumer guides contain
advanced contracts and recipes. No runtime feature or release is introduced here.

## Baseline and scope

- Branch: `fix/rtc-chat-conversation-mismatch`.
- HEAD: `71c936c2ef96a4a7aaf57a9d1a5e8ddf555497cc`.
- Initial working tree: clean, including untracked files reported by Git.
- Package version remains **1.0.1**; planned **1.1.0** is not published or selected
  in pubspec. Unreleased identity/incoming examples explicitly require checkout code.
- Documentation and one obsolete `.pubignore` entry only. No branch switch,
  staging, stash, reset, commit, push, tag, dependency change or publication.

## Documentation inventory and decisions

Classes: A = consumer, B = maintainer, C = investigation/history, D = obsolete.
All paths below are repository-relative. There is no `docs/` directory.

| Document | Class | Decision and purpose |
| --- | --- | --- |
| `README.md` | A | Reorganized and expanded: navigable setup, support matrix, authentication, Push/Chat/RTC examples, ownership and errors |
| `example/README.md` | A | Retained; private configuration and physical-device execution; obsolete validation reference removed |
| `doc/messaging-chat.md` | A | Retained; duplicate package-install section replaced with actual installation-management recipes; added imports, customization, exceptions and native thread-list recipes |
| `doc/huawei-rtc-outgoing.md` | A | Retained; detailed events, rendering, controls, token and lifecycle contracts |
| `doc/huawei-rtc-customer-identity.md` | A | Retained; exact widget identity and Conversation boundaries; public import added |
| `doc/huawei-rtc-incoming.md` | A | Retained; experimental process lifetime, event states, permissions, ringtone and cleanup |
| `doc/screen-sharing.md` | A | Retained; consent, release flags, resolution and device checks; stale intended-1.0.0 wording removed |
| `doc/webrtc-configuration.md` | A/B | Retained; guarded official APIs and unsupported RTC UI rationale |
| `CHANGELOG.md` | B | Retained unchanged; all historical entries preserved |
| `CONTRIBUTING.md` | B | Retained unchanged; contributor workflow and checks |
| `SECURITY.md` | A/B | Retained unchanged; unresolved upstream logging, optional R8 limits and reporting |
| `LICENSE` | B | Retained unchanged |
| `THIRD_PARTY_NOTICES.md` | B | Retained unchanged; required third-party attribution |
| `API_COMPATIBILITY.md` | A/B | Retained unchanged; extensive compatibility and historical audit reference |
| `.pubignore` | B | Retained consumer allowlist; removed obsolete deleted-example exclusion |
| `doc/android-release-verification.md` | B/C | Retained; bytecode justification for narrow consumer rules |
| `doc/final-production-certification.md` | C | Retained; unique native/16 KB/security evidence; historical banner and removed-document links clarified |
| `doc/production-readiness-resolution.md` | C | Retained; compatibility decisions and unresolved Inbox/backend context |
| `doc/huawei-chat-api-reliability.md` | C | Retained; Chat deadlines and transactional cleanup evidence |
| `doc/huawei-rtc-background-investigation.md` | C | Retained; vendor transport/unregister/token-replacement blockers |
| `doc/huawei-rtc-call-controls.md` | C | Retained; SDK control and device-validation evidence |
| `doc/huawei-rtc-incoming-foreground-experiment.md` | C | Retained; dated incoming/ringtone/video implementation and operator evidence |
| `doc/huawei-rtc-ongoing-call.md` | C | Retained; foreground-service ownership and notification evidence |
| `doc/huawei-rtc-outgoing-verification.md` | C | Retained; binary/dependency and outgoing regression evidence |
| `doc/huawei-rtc-screen-as-camera-poc.md` | C | Retained; ownership and SDK-filter gate rationale |
| `doc/huawei-rtc-screen-orientation.md` | C | Retained; native orientation evidence |
| `doc/huawei-rtc-screen-performance.md` | C | Retained; measured versus unmeasured performance boundaries |
| `doc/huawei-rtc-screen-video-quality.md` | C | Retained; 640×480 and resize limitations with SDK evidence |
| `doc/inbox-set-seen-investigation.md` | C | Retained; unresolved backend persistence evidence; no speculative auth API |
| `doc/sec01-infobip-responsible-disclosure.md` | B/C | Retained; sanitized disclosure, not sent |
| `doc/sec01-release-logging-mitigation.md` | B/C | Retained; exact limited R8 evidence |
| `doc/webrtc-core-device-validation.md` | B/C | Retained; hardware validation plan and historical unsupported contracts |
| `doc/webrtc-core-research.md` | C | Retained; pinned SDK feasibility/transport evidence |
| `doc/evidence/webrtc-core/README.md` and all sibling probes/text inventories | B/C | Retained; reproducible SDK API/dependency evidence, excluded from archive |
| `doc/evidence/huawei-rtc-outgoing/README.md` and all sibling probes/text inventories | B/C | Retained; actual runtime-graph verification, excluded from archive |
| `doc/evidence/sec01/release-authorization-method.smali` | B/C | Retained; unique mitigation evidence, excluded from archive |
| `example/CONFIG_AUTH_AUDIT.md` | C | Retained; specific auth-claim/fixture provenance, excluded from archive |
| `doc/publication-readiness.md` | D | Deleted; obsolete 1.0.0/missing-license decision; current security/rights caveats retained in SECURITY, notices and this review |
| `doc/release-packaging.md` | D | Deleted; superseded packaging snapshot and missing-license gate; current checks below replace it |
| `doc/release-1.0.1-review.md` | D | Deleted; one-off documentation checklist and ephemeral logs; current integration remains in README/consumer guides |
| `example/VALIDATION.md` | D | Deleted; stale AGConnect/renderer claims and old counts; current host requirements and validation commands remain in example README |
| `doc/pre-release-documentation-review.md` | B | This inventory, capability assessment and validation record; excluded from archive |

Source documentation under exported Dart APIs was checked against channel/native
implementations; it was not edited. Example runtime/configuration helpers were
preserved. The unused historical JSON template is configuration rather than a
consumer guide and remains untouched. Exclusion alone was never a deletion reason.

## Capability inventory

Common prerequisite **MM** means configured Huawei host/profile plus successful
`initialize(applicationCode:)`. **R** means completed registration. **P** means
personalized expected user. **F** means attached/resumed Activity. **E** means an
established call. MM/Chat native errors use `PlatformException`; RTC uses
`HuaweiRtcException`; Dart validation can raise `ArgumentError`. Stream owners
cancel subscriptions, but cancellation does not end native sessions. Native manager
names refer to `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/`.

| Capability / actual Dart API and required inputs | Setup and native implementation | Permissions / lifecycle / expected result / error boundary | Example and support |
| --- | --- | --- | --- |
| `initialize(applicationCode:)`, optional `defaultMessageStorage` | Huawei numeric app_id; core/MobileMessagingInitializer → Builder.withApplicationCode; channel carries no JWT | No runtime grant for initialization; same-code retry after Chat failure; hms_configuration_missing, chat_unavailable | README startup; example Setup; supported |
| `setJwt(String?)` | MM; inbox/InboxManager → MobileMessaging.setJwtSupplier | Memory-only; host refresh/clear; backend policy/expiry; not an initializer | README protected-user helper; example auth controls; supported |
| `registerForRemoteNotifications()` | MM; core initializer delegates SDK registration | Host notification grant Android 13+; async registration event/cached snapshot; registration_failed | README Push; example notifications; supported |
| `notifications.onMessageReceived/onNotificationTapped/onNotificationActionTapped` | NativeEventBridge, NotificationTapReceiver, PendingTapStore | Attach listener; one in-memory pending tap, no durable background Dart history; validate payload | README PushListeners; example notifications; supported |
| `getUser/fetchUser/saveUser(UserData)` and `personalize(PersonalizeContext)` | MM, applicable JWT policy; user/UserManager and mappers | Await server callbacks; serialize account changes against RTC; invalid input/backend errors | README identity, messaging guide; example user; supported |
| `depersonalize`, `depersonalizeInstallation(id)` | MM; UserManager/InstallationManager | Finish RTC before user change; no sign-out via implicit cleanup | Messaging guide; example user/installation; supported |
| `getInstallation/fetchInstallation/saveInstallation`, `setInstallationAsPrimary` | MM; InstallationManager | Only documented writable fields; tokens SDK-owned; onInstallationUpdated | README and messaging guide; example installation; supported |
| `markMessagesSeen(List<String>)` | MM; core/MessageOperations | Local acceptance, asynchronous reporting; no new permission | README Push; example notifications; supported |
| `fetchInbox(externalUserId:, jwt:, options:)`, `setInboxMessagesSeen` | MM; InboxManager; explicit → global → Application Code precedence | JWT per profile; seen has no JWT argument; fetch again to verify persistence | README/guide; example Inbox; supported with backend persistence limitation |
| `submitEvent`, `submitEventImmediately(InfobipHuaweiCustomEvent)` | MM, configured definitionId/properties; CustomEventManager | Queue versus callback semantics; backend rejection; no dedicated event-result stream | README custom events; supported; no dedicated custom-event example screen |
| `showChat()` | MM/R, linked widget, F; ChatManager/ChatOperations | Native UI, availability/auth errors; Activity lifecycle | README; example Chat; supported |
| `InfobipHuaweiChatView(controller:, onEvent:, onError:)` | MM/R, F, FlutterFragmentActivity; ChatPlatformView | Bounded layout; one controller per view; fragment/view disposal; chat_unavailable | README SupportChat; example Chat; supported |
| `setChatJwtProvider(Future<String> Function(), onError)` | MM/R/P, widget security; ChatJwtBridge | Backend refresh; 25s Dart/30s native bound; cleanup clears provider; no provider-clear API | README; example test-only signer/supplied tokens; supported |
| `chat.getUnreadMessageCount`, `onUnreadMessageCounterUpdated`, reset/availability | MM; ChatManager/NativeEventBridge | Subscribe plus initial query; cancel owner; no replay | README badge; example Chat; supported |
| Controller send/text, contextual data/strategy, language/theme, native thread list | Attached Chat view; ChatPlatformView maps to native fragment | Native composer for attachments; getters for readback; typed thread creation not exposed | Messaging guide; example Chat; supported |
| `setChatCustomization`, push title/body, `setChatExceptionHandler` | MM, configure before presentation; ChatManager/exception bridge | Null resets title/body/handler; cleanup clears handler; private contents | Messaging guide; example Chat; supported |
| `HuaweiRtc.callApplication(HuaweiRtcCallRequest(callsConfigurationId:, type:))` | MM/R unless explicit authorized identity, F; HuaweiRtcManager/Backend/TokenProvider | RECORD_AUDIO; CAMERA for video; BLUETOOTH_CONNECT API31+; one pending/live call; rtc_token_failed/busy | README audio/video; example RTC; supported |
| `HuaweiRtcLiveChatIdentity(widgetId:, expectedExternalUserId:)` | MM/R/P/exact widget; HuaweiRtcIdentityResolver | Account guard/no fallback; rtc_identity_unavailable; no Conversation reuse guarantee | Identity guide; example RTC opt-in; supported unreleased |
| `HuaweiRtc.events`, active snapshot, notification consumption | RTC manager, dedicated event channel/service | Subscribe before start; establishment/termination distinct; error not terminal; sequence replay | README/RTC guide; example RTC; supported |
| `HuaweiRtcVideoView(callId:, source:)` | Native video platform view/bindings; current video call | Bounded local/remote view, detach sinks on disposal; never releases SDK tracks/call | README/RTC guide; example RTC; supported |
| mute/speaker/camera/switch/output controls with callId | E/F; HuaweiRtcControls and backend | Current ID and grants; readback, unavailable routes; camera locked while sharing | README/RTC guide; example RTC; supported |
| `hangup()` | Existing call; HuaweiRtcManager | Await finished, not just method result; pending-token request is not active-call snapshot | README/guide; example RTC; supported |
| incoming Start(identity), accept(handle:, video:), decline(handle:) | MM/R/P/F; ForegroundIncomingExperiment and IncomingRingtone | Host call grants; explicit camera acceptance; fixed process identity, no unregister/renewal; readiness unconfirmed | README incoming controller + guide; example RTC; experimental unreleased |
| `closeForegroundIncomingExperimentScreen()` | Incoming flow | Requests termination, not signaling unregister; retain call listener through finished; process invalidation | README/guide; example dispose; experimental |
| Screen Start/Stop/query(callId:), states | E video/F/focused, API29+, camera enabled; capture controller/service/filter | Fresh MediaProjection consent; flags prove local release; screen_stop_uncertain needs retry | README/guide; example RTC; supported with 640×480 limitation |
| `cleanup()` | CleanupManager and Dart transactional cleanup | End call first; clears local SDK/provider after success; operation_in_progress/rtc_invalid_state | README/guide; supported |
| `WebRTCUI`, enableCalls/enableChatCalls/disableCalls | Guarded WebRtcOperations | No HMS background incoming support; no enabling workaround | Safeguards guide; unsupported official incoming contract |
| Composer draft setter; typed thread creation/selection; background RTC | No supported implementation | not_available or absent API; no speculative examples | Explicit limitations |

## Authentication conclusions

Application Code **without JWT is implemented and publicly exposed today**.
The README startup example calls only `initialize(applicationCode:)` and is
statically checked against the public export. JWT-only initialization is not
exposed: JWT authorization follows Application Code initialization. Native
`InboxManager.setJwt` installs the MM supplier and keeps the Inbox fallback;
Chat uses a separate asynchronous provider. RTC still authenticates with an
access token acquired natively through `MobileApiRtc.getToken(TokenBody(...))`.
There is no Dart RTC-token parameter or production signing-key parameter.

A beginner can follow README setup for Notifications and Chat with their own
Huawei/Infobip configuration. RTC client setup is covered, but account-specific
Calls provisioning/routing and a receiving peer remain administrator/backend
prerequisites; the README does not pretend to provision those or prove delivery.
Advanced lifecycle details intentionally link to included consumer guides.

## Validation

Results apply to this documentation candidate, not a signed production release.

| Check | Status | Result |
| --- | --- | --- |
| Root `flutter analyze --no-pub` | FAIL — pre-existing diagnostics | 21 deprecation infos; no errors/warnings; baseline and final diagnostic sets identical |
| Example `flutter analyze --no-pub` | PASS | No issues |
| Root `flutter test --no-pub` | PASS | 238 tests |
| Example `flutter test --no-pub` | PASS | 48 tests |
| Native debug unit tests | PASS | 410 tests, 52 suites, zero failures/errors/skips |
| Native release unit tests | PASS | 410 tests, 52 suites, zero failures/errors/skips |
| Example debug Kotlin compilation | PASS | `:app:compileDebugKotlin` |
| Example release Kotlin compilation | PASS | `:app:compileReleaseKotlin` |
| README Dart snippets | PASS | All 16 blocks analyzed independently against actual public exports |
| Supplemental messaging/identity recipes | PASS | 12 blocks checked in an async/import harness; only harness unused declarations suppressed |
| Repository Markdown links/anchors | PASS | 185 local links across retained tracked Markdown; no missing targets/anchors |
| External consumer documentation URLs | PASS — reachability | 19 URLs returned HTTP 200; not proof of current portal content or tenant setup |
| Actual checkout `flutter pub publish --dry-run` | FAIL — intentional working-tree warnings | Exit 65; two warnings: four deleted tracked files treated as ignored and five modified included documents; no missing consumer content |
| Clean export publication dry-run | PASS | Exit 0; 272 files, 977 KB compressed, zero warnings |
| Archive-relative documentation links | PASS | All local targets included in proposed archive |
| Archive exclusion/privacy screening | PASS — scoped | Six consumer guides included; no internal evidence, private host config/launcher, signing material or app/SDK binaries; no private-key/JWT literals found |
| `git diff --check` | PASS | No whitespace errors |
| Runtime/public API/dependency/version diff | PASS | No changes in lib, android, example runtime/host, pubspecs or tracked lockfiles |
| Physical Huawei, Portal, peer, signing/minified/16 KB acceptance | NOT RUN | No device/backend/security certification claimed |

Flutter 3.35.7 / Dart 3.9.2; Android validation used installed JDK 21. Native command
from `example/android`:

```sh
./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest \
  :infobip_mobilemessaging_huawei:testReleaseUnitTest \
  :app:compileDebugKotlin :app:compileReleaseKotlin \
  --offline -Ptarget-platform=android-arm64 --console=plain
```

`--no-pub` avoids unnecessary dependency resolution for analysis/tests; dry-run
performs normal resolution without upgrading constraints or changing tracked locks.
Native warnings concern existing Flutter/vendor deprecations, repository policy
and test unchecked casts, not changed runtime code. APK/AAB rebuilds were NOT RUN:
Kotlin compilation and unit checks satisfy the requested documentation regression
scope; no native/runtime/build configuration changed.

The first restricted Flutter/Dart attempts could not write normal installed-cache
or telemetry state; the checks completed with tool access. The initial clean export
attempt inherited the parent repository's ignored `build/` directory, hiding its
package. Rerunning with `GIT_CEILING_DIRECTORIES` set to the repository's `build`
directory isolated Git discovery and validated the real export. No Git repository
was initialized and no existing Git state was changed. The actual checkout warning
was not hidden or described as a clean publication pass.

Validation logs, extracted snippet harnesses, proposed archive inventory and
HTTP results are under ignored `build/docs-*`. The temporary export was removed
after validation because Flutter analysis recursively discovered its unresolved
example package; that validation-only artifact produced 197 extra diagnostics.
Final analysis was rerun after removing the export.
The export was created inside this repository, without copying ignored credentials.
The archive audit used Pub's proposed file inventory, not a published package.
The sole expected Gradle wrapper JAR is tooling covered by third-party notices.
Private-key/token screening is bounded evidence, not a complete security audit.

Official setup references were checked against the
[Infobip Huawei AGC guide](https://github.com/infobip/mobile-messaging-sdk-huawei/wiki/Configure-Huawei-application-in-AppGallery-Connect),
[mobile profile guide](https://www.infobip.com/docs/mobile-push/get-started/mobile-application-profile),
[Chat authentication](https://www.infobip.com/docs/live-chat/users-and-authentication),
[widget configuration](https://www.infobip.com/docs/live-chat/widget-customization),
and [Calls configuration](https://www.infobip.com/docs/voice-and-video/calls).
Huawei's dynamic page returned HTTP 200 but no extractable document text in the
browser reader. Logical setup sections are retained rather than claiming verified
live AGC menu names. Account routing, entitlement and token issuance remain external.

## Missing APIs/examples and remaining release work

- No JWT-only initializer, Dart RTC token input, HMS background RTC bridge,
  registration renewal/unregister, Conversation-reuse selector or Chat
  provider-clear API. These are explicit limitations, not additions for this task.
- The example has no production token backend and no dedicated custom-event screen;
  the README now includes a custom-event helper. Its existing test signing helpers
  remain test-only. No example runtime rewrite was necessary.
- Embedded native thread-list navigation is implemented and now documented;
  broader typed thread management remains absent. This corrects an overly broad
  prior documentation statement without changing API behavior.
- Re-run final-candidate publication checks after an explicitly authorized release
  preparation/version decision. This task keeps 1.0.1 and does not publish 1.1.0.
- Supply private Huawei configuration/signing and Infobip entitlement, routing,
  backend token endpoints, real notifications/Chat/peer media and lifecycle evidence.
- SEC-01 remains partially mitigated. Preserve security disclosures, review the
  exact signed/minified host, and do not infer legal/security clearance from tests.
- Background incoming RTC and existing Conversation reuse remain unsupported or
  unverified as described in the consumer guides.

## Final Git scope

Seven existing files modified: `.pubignore`, `README.md`,
`doc/final-production-certification.md`, `doc/huawei-rtc-customer-identity.md`,
`doc/messaging-chat.md`, `doc/screen-sharing.md`, `example/README.md`.
Four obsolete files deleted as listed above. This maintainer review is new and
untracked. All changes are unstaged; branch and HEAD remain the baseline values.
