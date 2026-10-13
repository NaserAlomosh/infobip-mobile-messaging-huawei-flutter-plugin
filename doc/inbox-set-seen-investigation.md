# Inbox set-seen investigation

## A. Executive conclusion

**ROOT CAUSE NOT YET PROVEN.**

The plugin's set-seen transport did not change between the v1.0.0 release
baseline (`153b552`) and development (`8e0316b`). The observed successful Huawei
callback proves that the SDK reporter accepted the request; it does not prove
that a later JWT-scoped Inbox read addresses the same application/user context
or that its unread state was changed.

The strongest remaining hypothesis is a host/backend configuration mismatch:
the JWT read and the installation-scoped write address different Infobip
application contexts. This cannot be promoted to a confirmed root cause without
a correlated request/response trace or Infobip server-side confirmation.

The comparison uses `153b552` as the main baseline because it is the repository's
v1.0.0 release merge. The supplied checkout contained no `main` or `development`
refs and network access was unavailable, so the current remote branch tips could
not be independently fetched. Development HEAD does contain merged PRs #54 and
#55 as stipulated by the issue.

## B. main vs development call graph

Both compared revisions use the same set-seen graph:

```text
InfobipMobileMessagingHuawei.setInboxMessagesSeen
  -> InfobipMobileMessagingHuaweiPlatform.instance.setInboxMessagesSeen
  -> MethodChannelInfobipMobileMessagingHuawei.setInboxMessagesSeen
  -> MethodChannel.invokeMethod("setInboxMessagesSeen", {
       "externalUserId": externalUserId,
       "messageIds": messageIds
     })
  -> InfobipMobileMessagingHuaweiPlugin.onMethodCall
  -> InboxManager.setSeen(externalUserId, messageIds)
  -> InboxMapper.requiredExternalUserId + InboxMapper.messageIds
  -> MobileInbox.getInstance(context).setSeen(externalUserId, ids, listener)
  -> MobileInboxImpl.setSeen
  -> MobileMessagingCore.enrichMessageIdsWithTimestamp
  -> inboxSeenStatusReporter().reportSeen
  -> POST /mobile/2/messages/seen
```

The public API validates a nonblank user ID and a nonempty `List<String>` whose
items are nonblank. It then makes an unmodifiable list before delegation. The
method-channel layer uses the shared contract keys without transforming values.
Android validates the same constraints, converts the list to an array without
altering its strings, and calls Huawei `MobileInbox.setSeen`.

## C. Exact code differences relevant to setSeen

`git diff 153b552..8e0316b` shows no change to:

- the public `setInboxMessagesSeen` implementation;
- the platform-interface signature;
- the method-channel implementation;
- `setInboxMessagesSeen`, `externalUserId`, or `messageIds` contract values;
- native method dispatch;
- `InboxManager.setSeen`; or
- `InboxMapper.messageIds`.

The only development change in `InboxManager` adds `clearJwtState`, used by the
new explicit cleanup API. Inbox mapper changes affect only response decoding
(`receivedTimestamp`, `deeplink`, and `silent`); they are not on the set-seen
request path. Message `internalData` mapping from PR #55 is also outside this
path.

The initialization builder remains the same: it passes the caller's application
code to `MobileMessaging.Builder.withApplicationCode`, configures the same
message store, in-app support, and notification settings, and completes from the
same init listener. Development adds reset behavior only when the newly exposed
`cleanup` method is invoked. Registration remains an explicit, separate method.
Chat additions do not replace the shared `MobileMessaging` instance or its
application code.

No plugin method automatically reorders `initialize`, registration,
personalization, `setJwt`, fetch, or set-seen. Those calls remain controlled by
the host application. `depersonalize` clears the plugin JWT after the native
operation succeeds; `cleanup` clears it and resets initialization state.

## D. Huawei 8.14.0 internal setSeen flow

The Huawei source reference is
[`5822d18`](https://github.com/infobip/mobile-messaging-sdk-huawei/tree/5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824).
At that revision, `MobileInboxImpl.setSeen` validates the external user ID and
IDs, enriches each ID through
`MobileMessagingCore.enrichMessageIdsWithTimestamp`, and calls
`InboxSeenStatusReporter.reportSeen`. The reporter uses
`POST /mobile/2/messages/seen`.

The request contains enriched strings, conventionally
`<message-id>,<adjusted-timestamp>`. This is expected SDK behavior and is not
evidence of corruption. The timestamp uses the SDK's current time adjusted by
its stored server-time delta (`timestampDelta`), rather than an Inbox model
field supplied by Flutter.

The reporter is part of the core Mobile Messaging transport. It obtains request
identity/authentication from the initialized Mobile Messaging installation and
application configuration. The external user ID used for SDK validation is not
an explicit field in the reporter payload; the reported values are the enriched
message IDs. The `JwtSupplier` participates in JWT-capable Inbox fetches, but
Huawei 8.14.0 exposes no JWT-taking `setSeen` overload and the reporter does not
switch to the explicit fetch JWT.

The callback reports successful completion of this reporter request. Neither
the Huawei API contract nor the plugin callback performs a follow-up Inbox read,
compares `countUnread`, or establishes equivalence between the native
installation context and an independently issued JWT user context. Therefore a
success callback is not a persistence assertion for the subsequent JWT fetch.

## E. Authentication/context findings

Inbox fetch has two paths. Without a token it calls the application-code overload;
with an explicit or stored token it calls Huawei's JWT overload. Set-seen always
uses the single Huawei 8.14.0 set-seen API and its native Mobile Messaging
transport. Adding a JWT argument would invent an unsupported SDK API and is not
a valid fix.

An Infobip JWT credential identifier and a Mobile Messaging application code
are different kinds of identifiers; textual inequality alone does not prove
misconfiguration. However, the native write is bound to the initialized
Mobile Messaging application/installation, while the read is authorized for
the JWT context. If those credentials were issued for different applications
or profiles, the observed split (successful write, unchanged JWT read) is a
plausible outcome. Exact cross-application server mutation semantics are not
defined in the inspected client source, so this remains a hypothesis.

## F. Root cause with evidence

No plugin regression is demonstrated:

1. The complete Flutter-to-Huawei set-seen path is identical across baselines.
2. Values are passed unchanged, and invalid/null entries are rejected.
3. The raw server response remains unseen, ruling out response-model decoding.
4. Huawei uses different authentication paths for JWT fetch and native
   installation-scoped reporting by design.

To confirm the leading configuration hypothesis, Infobip support or backend
observability must correlate both requests and verify that the application code
used to initialize the SDK, the installation, the external user, and the JWT's
issuing application/profile all resolve to the same Inbox scope.

## G. Fix implemented, if any

No production behavior was changed. A speculative REST fallback, synthetic JWT
parameter, SDK upgrade, local seen-state mutation, or model rollback would hide
the context mismatch without proving server persistence.

## H. Files changed

- This investigation report.
- `InboxMapperTest`, strengthened to prove exact ID preservation and rejection
  of null/non-string IDs.

## I. Tests added/updated

The existing Dart channel test proves that `externalUserId` and `messageIds` are
sent under the exact contract keys and unchanged. Dart's `List<String>` public
signature prevents nullable IDs at compile time, while runtime validation rejects
empty/blank IDs. The Android mapper test now covers exact preservation (including
no implicit trimming) and rejects empty, null, and non-string values.

This is intentionally not described as a server-persistence test. A local mock
cannot validate Infobip Inbox state.

## J. Runtime reproduction result

Not run: this environment has no app credentials, test user/JWT, Android device,
or access to Infobip services. Use a development account and capture one
correlated scenario:

1. Record `git rev-parse HEAD` and `flutter pub deps`.
2. Initialize once with the intended application code; register and personalize
   as required by the host lifecycle.
3. Set the JWT (log only `jwtPresent=true`, never its value).
4. Fetch Inbox and record external user ID, `countUnread`, selected ID, and seen.
5. Call set-seen; record callback success/failure.
6. After a short delay, fetch with the same JWT/user/options and record the same
   fields.
7. Correlate both native HTTP requests server-side, including installation and
   application scope. Never log authorization headers, API keys, secrets, push
   tokens, message bodies, or custom payloads.

## K. flutter analyze result

Not run: `flutter` is not installed or available on `PATH` in the supplied
environment (`bash: command not found: flutter`).

## L. flutter test result

Not run for the same missing-Flutter environment limitation.

## M. Android unit test result

Attempted with JDK 17. Gradle stopped while reading settings because
`example/android/local.properties` is absent. No unit tests executed.

## N. assembleDebug result

Attempted with JDK 17. Gradle stopped at the same missing
`example/android/local.properties` prerequisite. No APK was assembled.

## O. Remaining hypotheses, ranked by probability

1. **JWT/native application-context mismatch (high).** Best fits a successful
   installation-scoped write followed by an unchanged JWT-scoped read; requires
   server correlation to prove.
2. **Host lifecycle/context mismatch (medium).** A cleanup, depersonalization,
   reinitialization, or use of different external user IDs/application codes
   between operations can split contexts. The plugin does not reorder calls.
3. **Backend propagation or reporter semantics (low to medium).** Success may
   acknowledge receipt without guaranteeing the later view has converged. This
   cannot be established from the client implementation alone.
4. **Huawei SDK 8.14.0 defect (low).** Possible, but there is no transport change
   or evidence isolating the same credentials/context against a direct native
   reproduction.
5. **Flutter Inbox/model parity regression (very low).** Raw server data remains
   unseen and the response mapper is not on the request path.

### Runtime source/dependency verification

The example declares `path: ../`, and its lockfile resolves this package to `..`;
it does not reference a Git branch or hosted copy. The Android dependencies pin
all Infobip Huawei modules to 8.14.0.

Before reproducing, run:

```bash
git status --short --branch
git rev-parse HEAD
git log -1 --oneline
flutter pub get
flutter pub deps | sed -n '/infobip_mobilemessaging_huawei/,+3p'
cd example
flutter pub get
flutter pub deps | sed -n '/infobip_mobilemessaging_huawei/,+3p'
cd android
./gradlew :app:dependencies --configuration debugRuntimeClasspath \
  | sed -n '/infobip-mobile-messaging-huawei/,+8p'
```

If resolution is stale, first use `flutter pub get` and Gradle's dependency
report. Remove only the affected package entry from `.dart_tool`/pub cache or
the specific Gradle module cache after proving it is stale; do not blindly clear
global caches.
