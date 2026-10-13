# Phase 3.5.1 — Chat and API reliability hardening

Date: 2026-10-12. Branch: `release/rtc-production-certification`.
Initial and final HEAD: `58ee312b12abea83c2d7204d466f1558a956e725`.
Initial working tree: clean. Changes are local and uncommitted.

## Scope and investigation

Reconfirmed CHAT-01, CHAT-02 and API-01 from the Phase 3.5 conversation audit
against the current production sources, channel dispatch and tests before edits.
No dependency, package-version, Gradle, RTC implementation, screen-sharing
implementation or example changes are included. No branch changes, fetch,
commit, push, reset, stash or cleanup of user files was performed.

Installed Huawei Chat 8.14.0 was inspected with `javap` without extracting or
modifying SDK binaries. Its public `InAppChat.activate()` returns void; installed
`InAppChatImpl.activate()` synchronously saves the activation flag. Public
`setWidgetJwtProvider`/`getWidgetJwtProvider` and `JwtProvider.provideJwt` with
`onJwtReady`/`onJwtError` callbacks were verified. There is no asynchronous
activation-completion callback to cancel or generation-check. Activation here
means local activation and error-listener installation, not successful remote
widget loading or authentication.

## CHAT-01: root cause and bounded requests

Previously Dart awaited the host provider indefinitely, while the native
UUID-to-callback map had neither expiry nor a capacity bound. Engine detach and
provider replacement cleared it, but an otherwise live engine could retain an
unresolved request indefinitely.

Each Dart request now has a request-local completion gate and a **25-second**
Timer. The native bridge independently applies a **30-second** deadline, so
missing Dart delivery, a hung provider, lost response or inactive Dart listener
cannot indefinitely retain the native pending-map entry while the process is
executing. Both layers admit at most **32 pending requests**; excess requests
fail safely. These are fixed, documented policies; public method signatures are
unchanged.

Dart uses one completer per request. Success, exception, invalid result, timeout
and lifecycle invalidation can settle it only once. Timers are cancelled in the
request's finally block and immediately on replacement/successful cleanup.
Empty/whitespace JWTs still fail validation. Host error handlers cannot prevent
native rejection. Errors sent to native use fixed text, never provider payloads.

Native expiry uses one process-wide daemon scheduler with remove-on-cancel.
Success, rejection, expiry, replacement and clear remove the UUID entry and its
scheduled task. UUID and generation checks remain authoritative. A response is
also checked against a monotonic deadline before acceptance, even if the timer
callback was delayed. Cleanup/detach/disposal clear pending callbacks; late
responses are stale. SDK callbacks retain their existing dispatch onto Android's
main thread. Callback invocation requires a responsive runtime/main thread; this
is not a hard real-time guarantee under process suspension or an ANR.

**Cancellation boundary:** the plugin cancels its waiting/completion gate and
scheduled expiry. It cannot cancel the host's underlying Dart Future or its
network work. Late success/failure is consumed by the settled request gate and
cannot reach current native state. The host should cancel its own work where its
network implementation supports cancellation. Native expiry does not require
Dart to cooperate. No JWT values, headers or sensitive payloads are logged.

## CHAT-02: root cause and recovery

Previously activation ran in an optional initializer after-success hook. Its
returned ChatFailure was ignored, and the hook was not repeated after Mobile
Messaging reached INITIALIZED. A failed Chat activation therefore had no normal
retry through initialize.

The plugin now completes Mobile Messaging initialization first and then invokes
Chat activation on the main thread before replying. Chat activation failure is
returned through the existing initialize MethodChannel/Future as
`chat_unavailable`. Mobile Messaging remains initialized; push/registration
state is not rebuilt or reset merely because Chat failed.

Repeat `initialize` with the **same application code after one second** to retry
Chat. The existing InitializationCoordinator preserves idempotent Mobile
Messaging initialization. A different code remains rejected. No new public Dart
API or SDK method is introduced.

Activation is synchronized and idempotent after success. A reentrant activation
is rejected; calls arriving within one second after failure receive
`chat_activation_busy`. There are no timers, automatic retry loops or hidden
reinitialization. The host owns whether/when to request another retry.

The existing exception bridge, unread stream and JWT provider are preserved
across activation/retry. Cleanup invalidates activation generation and resets
the cooldown. Engine disposal permanently invalidates the old ChatManager and
clears pending provider callbacks. Activity detach/reattach retains the same
application-context Chat owner; local activation does not require an Activity.
Embedded fragment recreation still requires physical validation.

Generation checks surround synchronous SDK activation and listener installation
so reentrant cleanup/disposal cannot mark an invalidated attempt active. Queued
initialization replies capture the initializer, ChatManager and lifecycle
generation. Engine detach completes pending replies as detached and suppresses
late completions exactly once.

## API-01: root cause and cleanup ordering

Previously Dart removed its provider, exception handlers and subscriptions before
awaiting native cleanup. The native RTC owner could reject cleanup for a live
call, leaving Dart state destroyed while native state remained active.

Dart now calls native cleanup first. On native rejection/exception, all Dart
Chat callbacks, request generations and subscriptions remain intact. Existing
unread subscriptions are caller-owned and are not cancelled. Pending JWT
requests remain usable after rejection, subject to their original deadlines.

Only after confirmed native success does Dart increment its JWT generation,
invalidate pending request gates, clear its provider/exception handler and cancel
its owned subscriptions. Late old completions cannot reach the next lifecycle.

Concurrent Dart cleanup calls share one Future/native operation. Initialization
and Chat-handler/provider configuration during cleanup fail with
`operation_in_progress`. Cleanup while initialization or Chat configuration is
in progress also rejects without entering native cleanup. Ordinary pending JWT
responses may still complete while cleanup is deciding; rejection leaves them
valid, successful native cleanup invalidates its native generation before the
Dart commit.

Native dispatch rejects cleanup during pending initialization or another cleanup,
and rejects initialize during cleanup. Existing `prepareCleanup()` continues to
reject live RTC calls and reserve RTC ownership. The reservation is retained
until native SDK cleanup returns and is released in finally. Active calls are
not terminated to make explicit cleanup succeed. Engine disposal remains a
separate teardown contract and retains its existing RTC hangup behavior.

CleanupManager now attempts SDK cleanup **before** destroying plugin callbacks
or clearing the SDK JWT supplier. An SDK exception at that boundary preserves
plugin-owned state and propagates a sanitized error. Successful cleanup clears
JWT/Chat state and resets initialization/activation. Sequential repeated cleanup
retains the native `not_initialized` contract after success; concurrent Dart
cleanup callers share one result. This does not invent idempotent SDK success.

**SDK atomicity limitation:** Huawei SDK cleanup synchronously mutates its own
modules/preferences and provides no transaction or rollback API. A third-party
exception after an internal mutation cannot be reversed by the plugin. Likewise,
a failure after SDK cleanup has committed cannot reconstruct erased SDK data.
These fixes prevent premature plugin/Dart clearing and serialize owned lifecycle
operations; they do not promise rollback of arbitrary SDK-internal side effects.
A host receiving such an SDK error should verify/recover the SDK state rather
than assume the whole SDK transaction rolled back.

## API compatibility

All public method signatures and channel payload shapes remain unchanged.
Documented behavioral corrections:

- initialize can now fail with a Chat activation error while Mobile Messaging
  remains initialized; repeat the same call after the cooldown for recovery.
- JWT requests expire instead of waiting indefinitely; excess pending requests
  fail instead of growing an unbounded queue.
- rejected cleanup preserves callbacks instead of destroying them.
- unsafe lifecycle overlaps now fail with `operation_in_progress`; concurrent
  cleanup callers share one Future.

Existing blank-code validation, application-code conflict, independent global
JWT configuration, caller-owned unread streams, Chat payload mapping and RTC
call ownership remain intact. No physical Huawei certification is inferred.

## Tests and exact validation

New Kotlin suites: 23 tests in three files:

- ChatJwtDeadlineTest: 6 deterministic fake-clock/scheduler tests for expiry,
  delayed timer execution, late/duplicate responses, out-of-order completion,
  clear/replacement, capacity/recovery and sanitized delivery/scheduler failure.
- ChatActivationRecoveryTest: 10 tests for idempotence, failure/retry/cooldown,
  reentrant and concurrent activation, cleanup/disposal invalidation, pending
  actual SDK JWT callback disposal, listener preservation, initialization gating
  and Activity detach/reattach.
- ChatApiLifecycleTest: 7 dispatch tests for observable activation failure/retry,
  initialization/cleanup overlap, live RTC rejection, reservation duration,
  cleanup failure/retry, engine disposal and stale completion rejection.

CleanupManagerTest's three existing regressions now verify commit-after-SDK
ordering and preservation when SDK cleanup throws. Existing JWT bridge tests
retain malformed/stale response, UUID correlation and generation coverage.

New Dart ChatApiReliabilityTest: 12 tests for never-completing/late providers,
controlled timeout advancement, timer cancellation, pending provider survival
on cleanup rejection, capacity bounds, active-RTC/native-error callback and
unread preservation, concurrent/repeated cleanup, initialization/configuration
races and activation-error propagation/retry. Existing JWT tests retain provider
success/throw/invalid result, out-of-order completion and old-generation
suppression; delayed-cleanup cases now verify the corrected configuration gate
and success-versus-failure ownership.

JDK 21; existing Flutter 3.35.7 / Dart 3.9.2; cached dependencies, no upgrades.
Initial sandbox checks could not write existing SDK/Gradle caches. Approved
cache-access execution then completed the checks. No approval rejection occurred.

| Validation | Result |
| --- | --- |
| Baseline native suite | PASS, exit 0; task up-to-date, existing XML 300 tests / 46 classes |
| Focused Kotlin suite | PASS, exit 0; 32 tests, zero failures/errors/skips |
| Full Kotlin suite | PASS, exit 0; 323 tests / 49 classes, zero failures/errors/skips |
| Debug Kotlin compilation | PASS, exit 0 |
| Release Kotlin compilation | PASS, exit 0 |
| Focused Flutter tests | PASS, exit 0; 44 tests |
| Full Flutter plugin suite | PASS, exit 0; 229 tests |
| Full Flutter example suite | PASS, exit 0; 42 tests |
| Flutter analysis baseline/final | FAIL command exit 1; identical 21 informational deprecations, zero warnings/errors, zero added/removed diagnostics |
| git diff --check | PASS, exit 0 |
| Physical Huawei/backend tests | NOT TESTED |

Commands:

```sh
# From example/android; JDK 21 selected through JAVA_HOME:
./gradlew --offline :infobip_mobilemessaging_huawei:testDebugUnitTest --tests '*ChatJwt*Test' --tests '*ChatActivation*Test' --tests '*ChatApiLifecycleTest' --tests '*CleanupManagerTest'
./gradlew --offline :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin

# From repository root, using the existing Flutter 3.35.7 installation:
flutter test --no-pub --reporter expanded test/chat_api_reliability_test.dart test/chat_jwt_provider_test.dart test/chat_exception_handler_test.dart test/initialization_test.dart
flutter test --no-pub --reporter expanded
flutter analyze --no-pub

# From example:
flutter test --no-pub --reporter expanded

# From repository root:
git diff --check
```

Early implementation/test iterations exposed a constructor-call compile issue,
a deep-mock property assertion, nullable Mockito setup and a test-zone stream
cancellation hang. They were corrected; the final results above are from passing
runs. Full suites include existing HMS, Chat, RTC audio/video/notification,
rendering and screen-sharing regressions. No exclusions were applied. Existing
JVM class-sharing warnings remain; they do not fail the native build.

## Physical Huawei checklist

NOT TESTED in this phase. Record the exact model, regional firmware, Android API,
EMUI/HarmonyOS build, HMS Core version, artifact/commit, network and auth mode.
Use synthetic non-sensitive content and sanitized outcomes.

1. Fresh initialization: Mobile Messaging and push registration succeed.
2. Initial Chat activation: standard/embedded Chat loads successfully.
3. Controlled activation failure: observe a sanitized initialize error, verify
   Mobile Messaging remains initialized, then retry after one second. Where a
   local activation failure cannot be induced on hardware, retain the automated
   result and label this scenario NOT TESTED; do not invent an SDK failure API.
4. Authenticated Chat: a fresh backend-signed JWT succeeds.
5. Never-completing provider: timeout is observable and a later request succeeds.
6. Provider exception: safe error, no credential logging, successful recovery.
7. Standard Chat opening after initial activation/retry.
8. Embedded Chat opening, close/re-entry and composer/attachments.
9. Unread queries/events survive activation retry and rejected cleanup.
10. Established outgoing audio/video RTC call with two-way media.
11. Cleanup during live RTC returns rejection without hanging up.
12. Chat/JWT/exception listeners still work after that rejection.
13. RTC media, controls, rendering and notification actions still work.
14. Hang up, await finished, then cleanup successfully.
15. Reinitialize and re-register Chat providers/handlers after successful cleanup.
16. Background/foreground transitions and JWT refresh/reconnection.
17. Activity recreation: same Chat owner, reconstructed embedded view and no
    duplicated listeners; preserved RTC ownership.
18. Engine disposal with pending JWT: no retained request or stale success into
    a newly attached engine; existing RTC disposal behavior remains intact.
19. Push foreground/background/tap regression, token registration and unread.
20. Screen sharing Start/Stop, notification Stop, revocation, camera restoration,
    orientation/preview and repeated capture, with unchanged existing limitations.

## Production assessment and remaining scope

VERIFIED: the three targeted defects have local source/regression fixes, all
required native/Flutter suites pass, debug/release Kotlin compiles, and analyzer
findings match the baseline. Native SDK APIs were inspected rather than invented.

UNVERIFIED: live SDK/backend authentication, physical Huawei lifecycle, Activity
fragment recreation and cross-feature runtime performance. No performance gain
is claimed or estimated for these reliability changes.

The upstream Huawei authorization-header logging defect remains unresolved and
OUT OF SCOPE. No SDK binary patch, dependency upgrade, reflection-based SDK
bypass or stdout interception is included. The missing package LICENSE and
other Phase 3.5 release gates are also outside this task. Consequently these
fixes do not change the overall stable-release NO-GO decision. They are ready
for the above device acceptance checklist.
