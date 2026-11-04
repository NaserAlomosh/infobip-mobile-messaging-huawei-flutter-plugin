# Documentation index

Start with the maintained guides below. Historical reports preserve their original
baselines and evidence limits; they do not certify the current release. This
repository index and engineering reports are excluded from the pub.dev package.

## Getting started and API references

- [Plugin overview, requirements and quick start](../README.md)
- [Huawei and Android host setup](../README.md#android-configuration)
- [Public API compatibility and current extensions](../API_COMPATIBILITY.md)
- [Example configuration and execution](../example/README.md)
- [Contributor setup and validation](../CONTRIBUTING.md)
- [Release changes](../CHANGELOG.md) and [third-party notices](../THIRD_PARTY_NOTICES.md)

## Messaging, users, Inbox and Chat

- [Messaging and Chat integration](messaging-chat.md)
- [Partial user updates and personalization](messaging-chat.md#user)
- [Inbox authentication and seen requests](messaging-chat.md#inbox)
- [Chat authentication and unread counters](messaging-chat.md#chat-unread-counters-and-jwt-authentication)

- [Chat notification routing](messaging-chat.md#chat-notification-routing)

## RTC and screen sharing

- [Outgoing calls, events, rendering and controls](huawei-rtc-outgoing.md)
- [Calls routing setup and troubleshooting](../README.md#configure-infobip-rtc-calls-routing)
- [Outgoing customer identity](huawei-rtc-customer-identity.md)
- [Experimental foreground incoming calls](huawei-rtc-incoming.md)
- [Screen sharing: privacy, lifecycle and validation](screen-sharing.md)
- [Guarded official call APIs and WebRTC configuration](webrtc-configuration.md)

## Security and privacy

- [Current security guidance and unresolved SEC-01](../SECURITY.md)
- [Current email validation guard and upstream limitations](../README.md#user-validation-privacy)
- [Email privacy engineering evidence](user-validation-privacy-report.md), including
  persisted pending data and SDK-managed synchronization risks

## Historical engineering reports and evidence

These are implementation snapshots, investigations or test plans. Follow the
maintained guides above for current API usage. Historical test counts, device
observations and publication decisions apply only to their recorded baselines.

| Area | Reports and evidence |
| --- | --- |
| User management | [G-01 patch semantics](g01-user-update-patch-report.md); [G-02 native flags](G-02_PERSONALIZATION_FLAGS.md); [email privacy](user-validation-privacy-report.md) |
| Inbox and Chat | [Inbox seen-context investigation](inbox-set-seen-investigation.md); [Chat/API reliability](huawei-chat-api-reliability.md); [example configuration/authentication audit](../example/CONFIG_AUTH_AUDIT.md) |
| SDK 9.4.0 and Chat routing | [Pre-upgrade audit](SDK_9_4_0_COMPATIBILITY_AUDIT.md); [upgrade snapshot](SDK_9_4_0_UPGRADE_VALIDATION.md); [notification regression evidence](chat-notification-routing.md) |
| Release and CI | [2.1.0 preparation](release-2.1.0-preparation.md); [2.2.0 preparation](release-2.2.0-preparation.md); [Production-readiness resolution](production-readiness-resolution.md); [production validation audit](final-production-certification.md); [Huawei 8.14 dependency assessment](android-release-verification.md); [Robolectric CI investigation](robolectric-ci-resolution.md) |
| RTC feasibility and outgoing implementation | [Core feasibility research](webrtc-core-research.md); [device-validation plan](webrtc-core-device-validation.md); [initial outgoing verification](huawei-rtc-outgoing-verification.md); [call controls](huawei-rtc-call-controls.md); [ongoing-call notification](huawei-rtc-ongoing-call.md) |
| Incoming RTC | [Foreground experiment chronology](huawei-rtc-incoming-foreground-experiment.md); [background incoming investigation](huawei-rtc-background-investigation.md) |
| Screen sharing | [Original POC](huawei-rtc-screen-as-camera-poc.md); [orientation](huawei-rtc-screen-orientation.md); [performance](huawei-rtc-screen-performance.md); [video quality and preview](huawei-rtc-screen-video-quality.md) |
| Security evidence | [Partial Release logging mitigation](sec01-release-logging-mitigation.md); [unsent responsible-disclosure draft](sec01-infobip-responsible-disclosure.md) |
| Reproduction probes | [RTC Core dependency research](evidence/webrtc-core/README.md); [outgoing runtime dependency evidence](evidence/huawei-rtc-outgoing/README.md) |

Neither native flag forwarding nor request-map tests establish backend lead,
primary-device or deletion behavior. SEC-01 remains unresolved upstream; historical
artifact mitigations do not establish safe logs in every shipping application.
