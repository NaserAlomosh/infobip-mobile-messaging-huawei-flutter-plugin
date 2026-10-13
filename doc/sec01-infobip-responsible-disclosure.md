# SEC-01 — responsible-disclosure draft for Infobip

Prepared: 2026-10-12 (Asia/Amman). **DRAFT — NOT SENT.** Intended recipient:
Infobip SDK/security maintainers through an owner-approved private channel.
No private recipient address or response SLA has been established. Vendor
acknowledgment, fixed-version availability and CVE assignment are **UNVERIFIED**.
Owner decision, 2026-10-12: do not submit a security report before publication.
This optional draft is retained as evidence; sending it, obtaining acknowledgment
or receiving a vendor fix is not a package publication gate. No report was sent.
This report contains no actual credentials, tokens, API keys or device logs.

## Summary and affected components

Two upstream SDK paths can emit sensitive authorization material to stdout:

| Component inspected | Finding | Evidence confidence |
| --- | --- | --- |
| `com.infobip:infobip-mobile-messaging-huawei-sdk:8.14.0@aar` | `org.infobip.mobile.messaging.util.AuthorizationUtils.getAuthorizationHeader` prints the constructed Bearer or App authorization header | Existing SEC-01 source/bytecode finding; known println removed in one unsigned optimized example APK |
| `com.infobip:infobip-rtc:2.5.28` | `com.infobip.webrtc.sdk.impl.gateway.socket.SocketHandler.logMessage` prints raw non-heartbeat signaling messages with `System.out.printf`; connection messages may contain temporary TURN credentials | Cached bytecode path verified in this documentation review; exact signed-device exposure **UNVERIFIED** |

The plugin is `infobip_mobilemessaging_huawei 1.0.0`, on branch
`release/rtc-production-certification`. Both findings originate in upstream
components; no vendor binary or plugin runtime change is included in this report.
Affected versions beyond those inspected are **UNVERIFIED**.

## Sanitized technical evidence

Cached AAR SHA-256 values:

- Huawei MM 8.14.0: `65c21c6fedb83efae658209104c5da4e04a3128fde90116037853d33182638dc`.
- Infobip RTC 2.5.28: `9303984b90dd14cb31458d94d35b26f5b494ae42017e3174ae135030c01314a4`.

MM: the existing audit identifies `AuthorizationUtils.java:113`, a direct
`System.out.println` of the constructed header. Callers include
`PersonalizeSynchronizer` and `UserDataReporter`. A valid MM JWT produces Bearer
authorization; the no-JWT fallback produces App authorization. Invalid/expired
JWTs return earlier. This does not establish that Chat JWTs traverse this method.
See [baseline audit section 13](final-production-certification.md#13-security-audit-and-upstream-finding)
and [optimized method disassembly](evidence/sec01/release-authorization-method.smali).

RTC: read-only `javap -p -c` inspection of cached `classes.jar` shows:

- `handleMessage(String)` parses JSON and invokes `logMessage(JSONObject, String)`
  at bytecode offset 12, passing the original message before event dispatch.
- `logMessage` skips heartbeat events, calls `Logger.info`, then reads
  `System.out` at offset 36 and invokes `PrintStream.printf(String, Object[])`
  at offset 50 with the raw message. There is no logger-level guard around printf.
- Connection-event parsing reads `iceServers`; `parseIceServers` reads `urls`,
  `username` and `credential` and constructs `IceServer` records. This establishes
  a path for TURN credential fields to reach the stdout log when supplied by the
  backend. Credential lifetime and actual backend payloads are **UNVERIFIED**.

No sensitive payload was needed for this static inspection. The inspected RTC
jar was checked to match the cached AAR's `classes.jar` exactly.

## Potential impact and limitations

Authorization headers and temporary TURN credentials may enter Android stdout /
Logcat or downstream diagnostic collections. Exposure depends on log access and
collection practices. Temporary credentials remain sensitive while valid; relay
permissions, expiry, unauthorized use and exploitation are **UNVERIFIED**.
No claim is made that ordinary Android apps can freely read another app's logs.
The owner previously reported MM release-device disclosure; this documentation
review performed no live credential operation, installation or Logcat capture.

Proposed severity: **HIGH for MM authorization logging**, subject to Infobip's
assessment of credential scope and access conditions. RTC severity requires
vendor assessment of TURN privileges, lifetime and logging reachability. No CVSS
score or demonstrated compromise is claimed.

## Safe reproduction plan for the vendor

1. Inspect the listed artifacts and methods without live credentials. Confirm the
   direct stdout sinks and their independence from SDK logger configuration.
2. In an isolated vendor test app/account, use disposable test authorization and
   exercise MM personalization/user-data fetch/save paths. Check both valid JWT
   and no-JWT fallback. Keep all payload values out of shared evidence.
3. Exercise an RTC connection with a controlled test signaling message containing
   ICE server username/credential fields. Check whether stdout receives the
   message with the public RTC logger configured OFF. Use only synthetic markers
   in an isolated harness; do not attempt authentication with fabricated secrets.
4. Compare Debug, unoptimized Release and optimized Release with the optional
   example rule. Record only pass/fail, build identity and sanitized field names;
   do not attach raw logs. Signed-device execution remains **UNVERIFIED** here.

## Current optional workaround and residual risk

The example app retains `-assumenosideeffects` for public void
`PrintStream.print/println` in `example/android/app/proguard-rules.pro`.
Consumers must opt in with their own Release-only rules file and enable R8 with
effective optimization; the plugin does not export the broad rule through
`android/consumer-rules.pro`. See [consumer instructions](../SECURITY.md#consumer-application-opt-in).

Existing [SEC-01 evidence](sec01-release-logging-mitigation.md) proves removal of
the known MM println in one unsigned optimized APK. The rule affects matching
PrintStream calls **application-wide**, including stderr and functional file /
stream output. It **does not cover RTC's printf**, other logging APIs, native or
Dart output, or guarantee removal of all sensitive logs. Logger OFF alone does
not prevent direct stdout. This is partial mitigation, not a vendor fix.

## Requested vendor action and disclosure handling

- Remove authorization-header and credential-bearing signaling output at source;
  ensure credentials are redacted before reaching any logger/subscriber/stdout.
- Ensure public logging controls govern diagnostic paths and add regression
  coverage for JWT/App headers and TURN username/credential fields, including
  logger OFF, Debug and Release configurations.
- Confirm affected versions, credential scope/expiry, recommended interim action
  and a fixed release with coordinates/release notes. Assess whether other SDK
  distributions share these paths; their exposure is currently **UNVERIFIED**.
- Agree on private tracking, acknowledgment and a coordinated advisory timeline
  with the reporter. No vendor response or disclosure deadline is invented here.

If the owner later chooses to report, confirm a private channel before sending.
No submission is authorized by this release preparation. Keep raw logs and private
artifacts out of public issues and the package archive. The owner decision permits
package publication without vendor disclosure; it does not close SEC-01, prove
production safety or establish security certification.
