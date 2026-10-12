# Security integration guidance and unresolved upstream issue

This package is **not security-certified**. Local tests verify plugin behavior;
they do not certify backend authorization, device privacy or third-party SDKs.

## Token and credential handling

- Issue Chat JWTs on a trusted backend after authenticating/authorizing the user.
  `setChatJwtProvider` should retrieve a fresh widget/identity-specific token with
  a host network timeout. MM/Inbox JWTs and Chat JWTs use separate contracts.
- RTC tokens are backend-issued: the native `HuaweiRtcTokenProvider` obtains them
  through the initialized MM API and passes them directly to RTC Core. No public
  Dart RTC token input/output exists. Authorize the token subject/account/routing;
  supplying an arbitrary `identity` is not an authentication policy.
- Never hardcode production signing keys, JWTs or credentials. The example's local
  signing helpers are controlled-test conveniences; signing secrets are extractable
  from APKs. Keep private test APKs, AppGallery configuration and signing material
  out of source control and published package archives.
- Do not log authorization headers, tokens, raw SDK errors, payloads, PII, Chat
  messages or captured content. Redact device evidence before sharing. Host provider
  and view callbacks are responsible for their own safe error/content handling.

## SEC-01: upstream Infobip SDK sensitive logging and optional R8 workaround

Huawei Mobile Messaging SDK **8.14.0** contains authorization-header logging in
its own dependency's `AuthorizationUtils` path (`System.out.println`). It is outside
plugin-owned code; the upstream SDK remains unchanged. Release-device disclosure
was reported by the owner. Original evidence is recorded in
[RTC investigation](docs/webrtc-core-research.md) and
[outgoing verification](docs/huawei-rtc-outgoing-verification.md).

Infobip RTC SDK **2.5.28** also contains a direct stdout logging path:
`SocketHandler.handleMessage` passes the received signaling message to
`logMessage`, which calls `System.out.printf` for non-heartbeat events. The same
handler parses ICE server `username` and `credential` fields from connection
messages. RTC logging may therefore expose **temporary TURN credentials** when
these fields are present. This is upstream RTC code, not plugin-owned logging.
Cached SDK bytecode corroborates the path; exposure on the exact signed candidate,
credential lifetime, privileges and exploitation are **UNVERIFIED**.

Disabling RTC Core logging through its public API does **not** fix this independent
MM logging path or RTC's direct stdout call. The plugin already configures the RTC
logger to OFF; direct stdout bypasses that setting. Plugin sanitization cannot
guarantee that vendor logs are safe.
No SDK binary/AAR patch, reflection bypass, stdout interception or dependency
upgrade is included. Do not distribute raw SDK/device logs with real credentials.
The example uses an **optional Release-only R8 workaround** in
[`example/android/app/proguard-rules.pro`](example/android/app/proguard-rules.pro)
to remove matching `PrintStream.print/println`
calls. APK disassembly proves the known `getAuthorizationHeader` println is absent
from the optimized Release artifact and remains present in Debug. **SEC-01 is
PARTIALLY MITIGATED:** consumer applications require their own opt-in configuration.
See [artifact evidence and verification](docs/sec01-release-logging-mitigation.md).
The workaround **does not guarantee removal of all sensitive logs** and does not
cover the RTC `printf` path. A sanitized
[responsible-disclosure report for Infobip](docs/sec01-infobip-responsible-disclosure.md)
is retained as an optional draft and has not been sent. The owner has decided
not to submit it before publication; vendor disclosure, acknowledgment or a fix
is not a package publication gate. Vendor acknowledgment/fix status is
**UNVERIFIED**. This decision does not resolve SEC-01 or certify production safety.

### Consumer application opt-in

Copy the following into a dedicated host file, `release-logging-rules.pro`:

```proguard
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
```

Add that file only to the host's Release build type, preserving existing rules
and signing configuration (Kotlin DSL):

```kotlin
android {
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "release-logging-rules.pro",
            )
        }
    }
}
```

**R8 must be enabled for the workaround to take effect.** Optimization must remain
enabled; `-dontoptimize`, keep rules that block relevant
optimization, or disabling shrinking can defeat removal. Resource shrinking is
independent of this mitigation. Reinspect each actual shipping APK after changes.

The plugin deliberately does **not** export this rule through `consumerProguardFiles`:
consumer rules participate whenever the host enables R8, including minified Debug
builds. This policy must remain a host Release opt-in. Do not add the dedicated
file to `defaultConfig`, Debug, or a shared rules file used by Debug.

The rule affects matching calls throughout the optimized host, including stderr
and other `PrintStream` instances; it is not limited to Infobip or stdout. Hosts
that rely on `PrintStream.print/println` for functional file/stream output must
assess this before opting in and run their Release regressions. It does not remove
`printf` (including the upstream RTC signaling log),
`write`, Android logging, native logging, or Dart output, and does not certify other
SDK logging paths. Debug still contains the upstream sensitive logging path.
An upstream vendor fix remains the permanent remediation goal; this mitigation
does not permanently fix the SDK or establish general security certification.
A vendor report or fix is not required for pub.dev publication under the owner
decision. Consumers must assess the unresolved risk for their own production use.

## Android and MediaProjection privacy

Request microphone/camera, notification and applicable Nearby devices permissions
through the host UX. Begin RTC/capture with the required foreground Activity and
honor OS restrictions. The merged manifest contains microphone/camera and
mediaProjection foreground services. Explain their ongoing notifications and
provide hangup/Stop controls; notification denial does not waive service rules.

Screen-as-Camera requires fresh MediaProjection consent for every start. It can
capture private content outside the app. Keep consent one-shot, respect secure
content, and never imply invisible capture. Verify `projectionTerminated` and
`resourcesReleased` after Stop. On uncertain shutdown, inspect state/retry or use
system capture controls. `cameraOutputRestored` does not acknowledge remote display.
See [screen sharing](docs/screen-sharing.md) for background/resize behavior.

## Reporting

The repository's [issue tracker](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/issues)
can receive sanitized non-sensitive reports. Never post credentials or exploit
material requiring confidential handling there. No dedicated private security
contact or security-response SLA is established by repository evidence; obtain an
owner-approved private reporting channel before sending sensitive details.
