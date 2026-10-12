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

## Unresolved Huawei Mobile Messaging SDK 8.14.0 logging issue

Huawei Mobile Messaging SDK **8.14.0** contains authorization-header logging in
its own dependency's `AuthorizationUtils` path (`System.out.println`). It is outside
plugin-owned code and remains unresolved. Existing evidence is recorded in
[RTC investigation](docs/webrtc-core-research.md) and
[outgoing verification](docs/huawei-rtc-outgoing-verification.md).

Disabling RTC Core logging through its public API does **not** fix this independent
MM logging path. Plugin sanitization cannot guarantee that vendor logs are safe.
No SDK binary/AAR patch, reflection bypass, stdout interception or dependency
upgrade is included. Do not distribute raw SDK/device logs with real credentials.
The owner must obtain a vendor resolution or explicitly review/dispose of this risk
before stable release; this documentation does not accept it on the owner's behalf.

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
