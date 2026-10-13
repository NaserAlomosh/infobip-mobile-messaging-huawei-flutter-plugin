# Huawei RTC Core device validation plan

## Outgoing extension update — 8 September 2026

The separate [`HuaweiRtc` implementation](huawei-rtc-outgoing.md) is ready for
foreground Huawei **outgoing** device testing following code/unit/build checks.
The earlier incoming-contract research matrix below is retained as history.
It does not describe the new extension's implementation status.

| Feature | Source | Automated | This repository on Huawei hardware |
|---|---|---|---|
| Outgoing audio application call | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Outgoing video application call | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Hangup | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Native token delegation / permissions / lifecycle / events | CODE_VERIFIED | UNIT_VERIFIED | NOT_VERIFIED |
| Backend token issuance and routing | Client flow CODE_VERIFIED | Mock boundary only | NOT_VERIFIED |
| Background media / process recovery | Limited foreground implementation | No continuation guarantee | NOT_VERIFIED |
| Incoming HMS calls / enableCalls / enableChatCalls / disableCalls parity | UNSUPPORTED / guarded | Guards UNIT_VERIFIED | UNSUPPORTED |
| Video renderer / extra media controls | Not implemented | Not implemented | NOT_VERIFIED |

For the first device run:

1. Record the implementation commit, Huawei model/OS/HMS/GMS availability, network,
   permission grants and sanitized backend configuration reference.
2. Initialize the example with a test MM application and wait for registration.
   Grant Microphone, Camera for video and Nearby devices on Android 12+ in App info.
3. Open **Huawei outgoing RTC**. Supply a Calls configuration ID, not a push
   configuration ID; optionally supply an authorized test identity.
4. Start audio. Confirm real token issuance, routing, establishment and two-way
   audio at the peer. Reject a second call deterministically.
5. Hang up locally and remotely in separate runs; verify terminal reason/events,
   microphone release, and ability to place the next call.
6. Start video. Verify audio plus actual outgoing camera frames at the peer. This
   MVP intentionally has no preview/remote renderer in Flutter.
7. Deny/revoke microphone/camera/Nearby devices separately. Confirm safe errors,
   no fake success, and successful retry after explicit permission grant.
8. Rotate/recreate Activity, cancel/reattach the event listener and return from
   Android settings. Confirm active ownership survives; no stale Activity retained.
9. Exercise token failure/network loss and pending-call cleanup. Test engine
   destruction separately from Activity recreation and observe actual media cleanup.
10. Reject MM cleanup during a live call; hang up, await finished, clean up,
    initialize another authorized test account and place a new call.

Keep all results NOT_VERIFIED until that scenario is actually run with this
repository. External successful calls from another plugin are not DEVICE_VERIFIED
evidence here. Do not record raw SDK logs that may include the known upstream MM
authorization println. Backend authorization, rendered video, background operation
and HMS incoming signaling cannot be inferred from mock or build success.

## Historical incoming-contract research plan

Status on 8 September 2026: **NOT READY FOR DEVICE VALIDATION** for the requested
incoming-call APIs. See [the feasibility decision](webrtc-core-research.md).
This is a future acceptance plan, not evidence of implemented Core integration.

Evidence labels are deliberately separate: `CODE_VERIFIED` means inspected source
or bytecode; `UNIT_VERIFIED` means executed automated checks; `DEVICE_VERIFIED`
requires this plugin on real Huawei hardware; `UNSUPPORTED` means there is no
supported implementation in the current scope; `NOT_VERIFIED` means the scenario
has not been established. A static/automated result never implies device success.

Before a future run, record plugin commit, Core version, dependency report, Huawei
model/OS, HMS/GMS availability, app permissions and battery settings, network type,
backend configuration identifiers (redacted), and sanitized timestamps/results.
Use an authenticated test account and token source; never place a service API key
in the client. Distinguish RTC push configuration from outgoing Calls configuration.
Never save JWTs, application codes, FCM/HMS tokens or raw authorization logs.

| # | Scenario | Code/unit evidence now | Runtime status now | Future acceptance check |
|---|---|---|---|---|
| 1 | `enableCalls` | UNIT_VERIFIED: controlled unsupported response in existing native tests | UNSUPPORTED | Native supported transport confirms registration before Dart success; invalid identity fails safely |
| 2 | `disableCalls` | UNIT_VERIFIED: existing no-session rejection and fake-runtime teardown | UNSUPPORTED | Server/session unregister completes, callbacks/listeners released; repeated disable follows documented contract |
| 3 | enable → disable → enable | UNIT_VERIFIED: existing dormant adapter with fake runtime only | NOT_VERIFIED | Same identity and different identity both work; old identity cannot receive calls |
| 4 | Outgoing audio | CODE_VERIFIED: Core `callApplication`/audio option; compile-only probe | NOT_VERIFIED | Two-way audio established with real peer; failures propagate without secrets |
| 5 | Outgoing video | CODE_VERIFIED: Core video option; compile-only probe | NOT_VERIFIED | Local/remote video and audio work; camera permission rejection is handled |
| 6 | Foreground incoming | CODE_VERIFIED: Core active-connection listener API | NOT_VERIFIED | Supported session is ready; exactly one UI/event, no stale Activity or duplicate accept |
| 7 | Background incoming | CODE_VERIFIED: Core FCM registration; no HMS registration API found | UNSUPPORTED for HMS push; NOT_VERIFIED for live socket | Separate live-process socket delivery from push wakeup; test locked screen and battery restrictions |
| 8 | Incoming from terminated app | CODE_VERIFIED: no active-process socket can survive termination | UNSUPPORTED | Requires documented vendor HMS wakeup path; test OS kill, swipe-away and force-stop separately |
| 9 | Accept | CODE_VERIFIED: Core incoming call interfaces | NOT_VERIFIED | Media starts once; duplicate/late taps cannot accept a different call |
| 10 | Decline | CODE_VERIFIED: Core incoming call interfaces | NOT_VERIFIED | Remote endpoint receives decline; local notification/UI/session state cleared |
| 11 | Remote hangup | CODE_VERIFIED: Core call event interface | NOT_VERIFIED | UI, audio route, microphone and camera released; next call works |
| 12 | Local hangup | CODE_VERIFIED: Core `Call.hangup()` | NOT_VERIFIED | Remote endpoint ends; call cleanup does not falsely claim subscription unregister |
| 13 | Microphone | CODE_VERIFIED: Core call mute controls | NOT_VERIFIED | Permissions, two-way audio and mute/unmute on Huawei hardware |
| 14 | Speaker | CODE_VERIFIED: Core speakerphone control | NOT_VERIFIED | Earpiece/speaker switching during real audio/video calls |
| 15 | Camera | CODE_VERIFIED: Core local-video controls | NOT_VERIFIED | Front/back camera, disable/enable, denial/revocation and release on call end |
| 16 | Audio → video | CODE_VERIFIED: Core local video control; no plugin flow | NOT_VERIFIED | Supported backend/call type permits upgrade; permission and remote renegotiation verified |
| 17 | Network loss/recovery | CODE_VERIFIED: Core application-call autoReconnect option | NOT_VERIFIED | Wi-Fi/mobile changes, disconnect and recovery give bounded, truthful state updates |
| 18 | Background during active call | NOT_VERIFIED: no new foreground service or UI implemented | NOT_VERIFIED | Audio/video behavior and foreground service remain valid under Huawei restrictions |
| 19 | Activity recreation | CODE_VERIFIED: existing plugin clears/replaces its Activity field, RTC gets application Context | NOT_VERIFIED | Rotate/recreate during registration and call; no old Activity retention or duplicate listeners |
| 20 | Process restart | CODE_VERIFIED: Core singleton is process-local | NOT_VERIFIED | Explicit reinitialization uses current account/configuration, with no false restoration claim |
| 21 | `enableChatCalls` | UNIT_VERIFIED: current native unsupported response | UNSUPPORTED | Requires vendor Huawei identity hook and supported incoming transport; never accept a no-op success |
| 22 | Chat-originated incoming | CODE_VERIFIED: Huawei lacks official livechat-registration event | UNSUPPORTED | Verify exact Conversations/Chat identity, registration changes, incoming media and cleanup |
| 23 | Cleanup/relogin/account switching | UNIT_VERIFIED: existing fake-runtime late-callback and cleanup tests only | NOT_VERIFIED | Unregister old identity, complete pending requests once, reinitialize new identity; old calls cannot reach new account |

No row is `DEVICE_VERIFIED`. The separate user-provided outgoing-call evidence for
a different Core 2.5.20 plugin is not transferred to this matrix. Accept/decline,
media controls and socket callbacks being present in Core do not make them exposed
or implemented in this package. Unsupported rows require an architecture/API
change before a device run can validate working calls.
