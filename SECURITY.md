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

**SEC-01 remains PARTIALLY MITIGATED.** Both findings originate in upstream SDKs;
no vendor binary is patched and no permanent fix is established.

- Huawei Mobile Messaging **8.14.0** logs authorization headers through its
  dependency's `AuthorizationUtils` (`System.out.println`). The owner reported
  release-device exposure; the upstream SDK remains unchanged.
- Infobip RTC **2.5.28** logs raw signaling messages through
  `SocketHandler.logMessage` (`System.out.printf`). That handler also parses ICE
  server `username` and `credential` fields, so logging may expose **temporary TURN
  credentials**. Cached bytecode corroborates the path; exposure on the exact signed
  candidate, credential lifetime, privileges and exploitation remain **UNVERIFIED**.

The plugin configures the RTC logger to OFF, but these direct stdout calls bypass
that setting. Plugin sanitization cannot guarantee safe vendor logs. Do not share
raw SDK/device logs containing real credentials.

The example's [optional Release-only R8 workaround](example/android/app/proguard-rules.pro)
removes matching `PrintStream.print/println` calls. Existing disassembly verifies
removal of the known MM header println only in the unsigned optimized example
Release APK; Debug retains it. Consumer applications must opt in and inspect their
own shipping artifacts. **The workaround does not cover RTC `printf` or guarantee
removal of all sensitive logs.** Signed-device verification remains UNVERIFIED.

Vendor disclosure, acknowledgment or remediation is **not a publication requirement**.
The owner decided not to send the retained optional draft before publication.
Vendor acknowledgment/fix status is UNVERIFIED; this decision does not resolve SEC-01.
Historical [artifact verification](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/blob/b5eba8081a8d4867e2b101fde2e5b58a2bcdf0c7/docs/sec01-release-logging-mitigation.md)
remains in Git and is excluded from the package.

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
Consumers must assess this unresolved production risk; an upstream fix remains
the permanent remediation goal.

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
See [screen sharing](doc/screen-sharing.md) for background/resize behavior.

## Reporting

The repository's [issue tracker](https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin/issues)
can receive sanitized non-sensitive reports. Never post credentials or exploit
material requiring confidential handling there. No dedicated private security
contact or security-response SLA is established by repository evidence; obtain an
owner-approved private reporting channel before sending sensitive details.
