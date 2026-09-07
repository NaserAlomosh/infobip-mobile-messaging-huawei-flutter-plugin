# WebRTC status for Huawei

**RTC UI 15.1.0 is unsupported for Huawei-only production use in this plugin.**
The optional Dart configuration and call APIs remain source-visible, but call enablement
returns `webrtc_unsupported`. `-PinfobipWebRtcEnabled=true` fails Gradle configuration
with an explicit explanation. The baseline app does not package RTC or the conflicting
standard Mobile Messaging Android core.

This is an intentional production safeguard, not verified HMS incoming-call support.
A vendor-supported integration and Huawei device/backend evidence are required before
removing the guard. No HMS RTC transport or replacement Mobile Messaging service is invented.

## Published 15.1.0 integration evidence

The exact [RTC Firebase service source](https://github.com/infobip/mobile-messaging-sdk-android/blob/15.1.0/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/service/InfobipRtcUiFirebaseService.kt)
contains direct calls to `MobileMessagingFirebaseService.onMessageReceived` and
`MobileMessagingFirebaseService.onNewToken`. Huawei 8.14 does not supply that class.
The [RTC manifest](https://github.com/infobip/mobile-messaging-sdk-android/blob/15.1.0/infobip-rtc-ui/src/main/AndroidManifest.xml)
registers `DefaultInfobipRtcUiFirebaseService`, which inherits those calls.

The public companion exposes FCM message/token delegation, so a custom Firebase service
is possible for supported Firebase hosts. It provides no documented HMS transport. Removing
the default service from the manifest alone is insufficient: the
[published consumer rules](https://github.com/infobip/mobile-messaging-sdk-android/blob/15.1.0/infobip-rtc-ui/proguard-rules.pro)
retain the public service classes and their direct missing-core references. Reintroducing
`com.infobip:infobip-mobile-messaging-android-sdk` duplicates Huawei core classes. No safe
supported narrow integration was established from these APIs.

The service also logs raw FCM tokens in `onNewToken`; the disabled integration avoids
shipping that path. Any future vendor-approved integration must address this logging.

`PublishedRtcAarTest` inspects the actual `com.infobip:infobip-rtc-ui:15.1.0` AAR in an
isolated, non-transitive test configuration. It verifies the public final-step interface,
the private implementation, and both unresolved standard-core service calls. That artifact
is never an app runtime dependency.

## Reflection correction

The retained reflection adapter invokes `build()` through the public
`InfobipRtcUi.BuilderFinalStep` interface, not the private implementation class.
The fake also has a private implementation, so dispatcher tests reproduce the access boundary.
The adapter retains the built instance, uses the public UI contract for `disableCalls`,
and preserves configuration ID, identity, blank-identity overload, `ListenType.PUSH`, and
Chat call mode. This verifies access and argument forwarding, not real call registration.

## Lifecycle contract

The lifecycle coordinator is tested with an injected native runtime:

- A successful repeat enable for the same identity/mode/configuration is idempotent.
- Enabling during a pending operation or changing identity requires completing disable first.
- Cleanup/disable cancels the Flutter enable completion exactly once. It waits for a pending
  native enable response, then unregisters the actual returned UI instance.
- Mobile Messaging cleanup runs only after RTC unregistration succeeds. Failure retains
  the instance for retry and prevents a false cleanup success.
- Engine detach requests the same teardown without a Flutter completion; it does not simply
  forget an active instance. Late callbacks cannot complete a newer session.
- Native exception text is not copied into platform errors, since it may contain credentials.

The native SDK exposes no cancellation API and can wait for registration broadcasts.
If its callback never arrives, teardown can remain pending; an unregistration/network
failure cannot be claimed as server cleanup. Engine-detach unregistration is best effort.
These are further reasons the production Huawei RTC path remains disabled.

Optional initialization still accepts `WebRTCUI(configurationId: ...)`. Configuration is
retained after successful Mobile Messaging initialization and cleared after successful
cleanup. It does not authorize or activate an RTC transport.
