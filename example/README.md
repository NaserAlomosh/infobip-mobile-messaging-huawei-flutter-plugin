# Guided Huawei integration example

**Never embed signing secrets in a production mobile application.
This local configuration is for controlled SDK testing only.**

The signing helpers live only under `example/`; they are not plugin APIs.
Dart defines are compiled into the application and can be extracted from an APK.
Use a test account, keep the APK private, and generate production tokens on a
trusted backend. Never paste tokens, signing secrets, or Authorization headers
into logs, screenshots, issues, or source control.

## Configure and run

Complete the [Huawei host setup](../README.md) first, including the AppGallery
application, package/signing fingerprint, HMS configuration and App Profile.
Then, from `example/`:

```sh
cp example_config.example.json example_config.local.json
# Edit example_config.local.json locally; keep credentials out of shell history.
flutter pub get
flutter run --dart-define-from-file=example_config.local.json
```

The local JSON and any `example_config.local.dart` are ignored by Git. The safe
JSON template contains only empty values and TTL defaults. We retain environment
configuration instead of importing a missing ignored Dart file: a clean checkout
builds and displays missing prerequisites. No generator or local Dart import is
needed. `lib/config/example_config.dart` is the single configuration class;
`const ExampleConfig()` reads these compile-time values. Rebuild/restart after
changing configuration; hot reload does not reload Dart defines.

| ExampleConfig field | JSON / Dart define | Meaning |
| --- | --- | --- |
| `applicationCode` | `INFOBIP_APPLICATION_CODE` | Application Code from the Mobile Messaging App Profile. Base SDK initialization context; never call it applicationId. |
| `externalUserId` | `INFOBIP_EXTERNAL_USER_ID` | Your controlled test user's external identity. Used consistently for personalization, Inbox and authenticated Chat. |
| `jwtKid` | `INFOBIP_JWT_KID` | Mobile Messaging signing key ID from that App Profile. |
| `jwtSecretKey` | `INFOBIP_JWT_SECRET_KEY` | Hex-encoded Mobile Messaging signing secret from the same App Profile; at least 32 decoded bytes. |
| `jwtTtl` | `INFOBIP_JWT_TTL_SECONDS` | Default 15; example accepts 1–300 whole seconds. |
| `rtcCallsConfigurationId` | `INFOBIP_RTC_CALLS_CONFIGURATION_ID` | Outgoing Calls routing configuration ID, distinct from an RTC push configuration ID. |
| `rtcIdentity` | `INFOBIP_RTC_IDENTITY` | Optional explicit test identity. Empty uses the registered installation's push registration ID. |
| `chatAuth` | `INFOBIP_CHAT_AUTH` | Set `installation` or `jwt` to match your Portal widget security setting. Empty disables Chat until explicitly configured. |
| `chatWidgetId` | `INFOBIP_CHAT_WIDGET_ID` | Live Chat widget issuer for Chat JWT. |
| `chatKeyId` | `INFOBIP_CHAT_KEY_ID` | Widget secret key ID, used as `ski`. |
| `chatSecretKey` | `INFOBIP_CHAT_SECRET_KEY` | Separate Base64-encoded widget secret, at least 32 decoded bytes. |
| `chatJwtTtl` | `INFOBIP_CHAT_JWT_TTL_SECONDS` | Default 60; example accepts 15–300 whole seconds. |

JWT and Chat signing fields are optional for unrelated features. Empty values,
invalid secret encodings and invalid TTLs appear as missing prerequisites.
Never fill the committed JSON template with real credentials.

## Three primary stages

1. **Application Setup:** verify the masked Application Code status and select
   **Initialize SDK**. Next stays disabled until the native initialization call
   succeeds. Initialization does not prove push registration completed.
2. **User & Installation Setup:** inspect cached/server installation data;
   register for remote notifications; grant Android notification permission;
   personalize the configured external user; optionally expand the JWT section
   and test local generation. Expand the authentication explanation as needed.
3. **Features:** seven cards open Push Notifications, Inbox, Chat, Outgoing RTC
   Audio, Outgoing RTC Video, User and Installation. Every card lists missing
   prerequisites and disables its open button until those are satisfied.

Recommended order: **Initialize → Installation → Push → Personalize → Features**.
Page 2 Next requires only successful SDK initialization, allowing testers to
inspect features while registration completes. Each card separately enforces its
requirements. The User and Installation drill-down screens retain their read,
write and personalization tests. Returning to the dashboard refreshes setup state.
Registration, installation and user events also update the shared controller;
returning from Android settings refreshes permission grants.

READY means checked local prerequisites, not verified service availability or
backend authorization. Cache reads may be followed by a failed server refresh;
read the Last operation result and retry. Unknown permissions never count as granted.

## Authentication contracts

There is **no universal Application Code vs JWT switch**. The Application Code
initializes Mobile Messaging. Mobile Messaging JWT supplies authorization for
supported MM/Inbox requests. Chat uses its own provider. The example does not
set a persistent global JWT or silently apply Inbox JWT to user APIs. App Profiles
requiring additional user-data authorization must be validated separately; a
personalization failure remains visible and blocks user-targeted tests.

### Mobile Messaging / Inbox JWT

Verified against the official [JWT structure and generation example](https://github.com/infobip/mobile-messaging-sdk-android/wiki/JsonWebToken-%28JWT%29-structure-and-generation-example),
linked by the [Huawei Inbox guide](https://github.com/infobip/mobile-messaging-sdk-huawei/wiki/Inbox).
Inspection date: 2026-09-08.

The requested claims and 15-second default match the official example. One
critical clarification: **decode the hex secret before signing**, rather than
signing with UTF-8 characters of the hex string. No claims were added or removed.
`ExampleJwtHelper.generate` produces compact, unpadded Base64url JWT segments:

```text
Header:  {alg: HS256, typ: JWT, kid: jwtKid}
Payload: {typ: Bearer, jti: UUID-v4, sub: externalUserId,
          iss: applicationCode, iat: unixSeconds, exp: unixSeconds + ttlSeconds,
          infobip-api-key: applicationCode}
Signature: HMAC-SHA256(decodedHexSecret, encodedHeader + '.' + encodedPayload)
```

Each generation uses `Random.secure()` for a new UUID v4 and integer UTC epoch
seconds. The helper validates inputs before decoding, and validation exceptions
never retain secret input. It never caches tokens. Generate/Test JWT keeps only
masked subject/time/TTL metadata; it discards the token and does not prove backend
authorization. Every actual fetch generates another fresh token.

### Chat JWT decision: DIFFERENT CONTRACT

The plugin's `setChatJwtProvider` delegates to native `setWidgetJwtProvider`.
The [official Live Chat authentication contract](https://www.infobip.com/docs/live-chat/users-and-authentication)
uses a widget issuer and Base64-decoded widget secret, with a matching personalized
user identity for mobile authentication:

```text
Header:  {alg: HS256, typ: JWT}
Payload: {iat: unixSeconds, iss: chatWidgetId, jti: UUID-v4,
          ski: chatKeyId, stp: externalPersonId, sub: externalUserId,
          exp: unixSeconds + chatTtlSeconds}
Signature: HMAC-SHA256(decodedBase64WidgetSecret, encodedHeader + '.' + encodedPayload)
```

`ChatJwtHelper` implements this separately. `prepareChat` installs a provider
that invokes the helper **on every callback**, including reconnect/re-authentication.
The default Chat TTL is 60 seconds for this test app; the documentation recommends
a longer mobile TTL than the 15-second default used in its web examples. No
optional session ID is invented. Chat JWT fields are required only when
`chatAuth=jwt`. `chatAuth=installation` is for a widget without required mobile
customer JWT authentication. Configure the Portal accordingly; the example cannot
infer that setting. Restart the app when changing Chat configuration.

Repository paths inspected: `lib/src/core/infobip_mobilemessaging_huawei.dart`,
`android/src/main/kotlin/com/infobip/mobilemessaging/huawei/inbox/InboxManager.kt`,
`chat/ChatManager.kt` in the same native package, and its `rtc/` sources.

## Test user-targeted portal push

Initialize, refresh Installation, register for remote notifications, grant
notification permission (Android 13+), then personalize. Wait for the push
registration ID and HMS token. Push readiness also requires an enabled push
registration flag, installation and Android notification status, and the current
user matching the configured external user ID. An enabled flag without an ID or
HMS token does not mean ready.

Open **Push Notifications**. **Send a notification to this external user from the
Infobip Portal.** Select the matching test App Profile and target the external
identity from your local configuration. The app receives and displays events; it
does not send the Portal push. Check foreground receipt, background notification,
tap, action tap and cold-start tap replay on a real Huawei device. Keep payloads
free of credentials. Inspect channel-specific Android settings if delivery works
but a visible notification does not appear.

## Test both Inbox paths

The dashboard and Inbox screen share an Inbox-only authentication selector.

- **Application Code:** the controller first awaits `setJwt(null)`, then calls
  `fetchInbox(externalUserId: ..., options: ...)` without an explicit JWT. A clear
  failure aborts the fetch. Use a sandbox App Profile configured to permit this
  path; it is not a bypass for profiles requiring JWT.
- **JWT:** immediately before every `fetchInbox`, generate a new token and pass
  it through the explicit `jwt:` argument. No generated token is passed to
  `setJwt`, kept between requests or displayed. Sign with keys belonging to the
  same test App Profile and external user.

Both paths require initialization and a configured external user. Filters,
counters and mark-seen controls remain available. `setInboxMessagesSeen` retains
its existing external-user/message-ID arguments with **no JWT argument**. Its
native installation context is unchanged. The follow-up fetch uses the selected
auth path and a fresh token when JWT is selected. A successful seen callback is
not proof of persistence in a differently scoped Inbox; re-fetch and confirm.
See the [existing set-seen investigation](../docs/inbox-set-seen-investigation.md).

## Test outgoing RTC

Configure `rtcCallsConfigurationId` and a test account with Web and In-app Calls
routing enabled. Grant Microphone and Nearby devices (Android 12+); Video also
requires Camera. Use the dashboard permission buttons or Android App settings.
Permissions are checked by an example-only host channel and rechecked before
calling; denial leaves the relevant action disabled. An explicit `rtcIdentity`
or a registered installation ID is required.

Open the corresponding audio/video card, start a call, then watch for
`established` and verify media at the receiving endpoint. This uses
`HuaweiRtc.callApplication`, never `enableCalls()`. Native RTC token acquisition
remains inside the plugin. Video retains the branch's existing limitation: no
local preview or remote renderer. Hang up and wait for `finished` before changing
user or leaving the test session. Leaving the RTC screen alone does not hang up.
Read [RTC device validation](../docs/huawei-rtc-outgoing.md) for the branch's runtime
scope, lifecycle limitations and routing setup.

## Dependencies, security and validation

The only added direct runtime dependency is [crypto 3.0.7](https://pub.dev/packages/crypto),
maintained under dart.dev, supporting Dart >=3.4 (the example requires >=3.9), for
HMAC-SHA256. Its BSD-3-Clause license permits redistribution subject to its notice
conditions; Flutter includes dependency license notices. Its transitive
`typed_data`/`collection` packages use BSD licenses. UUID generation uses Dart's
secure random generator without a new UUID or authentication framework package.

Application codes and identity IDs are masked. The example never logs signing
secrets, JWTs or Authorization headers. Error UI shows the operation and known
stable plugin code with a safe message, dropping raw backend messages, details
and traces. Configuration `toString` hides all values. The SDK may persist normal
installation/user state; the example never persists generated JWTs. Do not enable
HTTP/SDK verbose logging while supplying credentials or capture credentials in
build diagnostics. JSON defines and resulting APKs are test-only secret material.

From the repository root, run `flutter pub get`,
`dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and
`flutter test`. From `example/`, run `flutter pub get`, `flutter analyze`, and
`flutter test`. Tests verify signature structure/bytes, validation and freshness,
setup readiness, permission denial, Inbox call arguments and clear ordering, Chat
provider callbacks, three-stage navigation and disabled controls.

These tests use mocked native channels. They do not prove Infobip backend
acceptance, HMS registration, portal delivery, Chat connectivity, or RTC media.
See [verification results](../docs/guided-example-verification.md) for this change.
