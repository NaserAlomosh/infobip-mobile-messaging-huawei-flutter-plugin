# Screen sharing through Screen-as-Camera

Screen-as-Camera is supported by the current plugin. This guide
reflects the current implementation; the POC, performance, orientation and quality
reports remain historical audit evidence. Support does not imply completed device
or security certification.

## Architecture and prerequisites

```text
Screen
  → MediaProjection VirtualDisplay
  → ImageReader (RGBA_8888; latest image, two buffers)
  → Bitmap (worker scratch + independent visible crop)
  → VideoFilter (latest screen snapshot; camera-driven frame cadence)
  → Infobip RTC Core camera publication
```

The existing outgoing **camera stream** is replaced. There is no separate
screen-sharing track, custom RTC source or remote screen-track selector. The camera
must remain enabled because SDK camera callbacks drive filter output and timestamps.
Camera switching/toggling is locked while capture/shutdown is busy; audio controls
remain subject to their normal established-foreground-call checks.

Requirements: Android 10/API 29+, initialized MM, an established outgoing video
call, microphone/camera and applicable Nearby devices grants, enabled camera,
a focused attached Activity, and no competing camera `VideoFilter`. The current
native call ID is mandatory. An audio call, stale ID or disabled camera is rejected.

## Public API

Import `package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart`.
These expressions belong in an async call-screen handler with its current `callId`:

```dart
final subscription = HuaweiRtcScreenAsCamera.states.listen((state) {
  // Update your call screen from state.phase and termination/resource flags.
});
final started = await HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: callId);
final current = await HuaweiRtcScreenAsCamera.getScreenAsCameraState(callId: callId);
final stopped = await HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: callId);
await subscription.cancel();
```

Phases are `idle`, `requestingPermission`, `starting`, `sharing`, `stopping`,
`stopped`, `cancelled`, and `error`. States carry `callId`, `framesBlocked`,
`projectionTerminated`, `resourcesReleased`, `cameraOutputRestored` and a safe
`error` code. `sharing` means the first substituted frame was submitted to the
SDK, not that a peer acknowledged its rendering. `busy` includes unresolved
projection/resource shutdown; it must not be interpreted from phase alone.
The event stream is not a durable history; query state when restoring a screen.

## Consent, foreground service and privacy

Every start opens Android MediaProjection consent. Cancellation/denial returns
`screen_permission_cancelled`. Consent results remain in a one-shot native closure;
they are not persisted or reused. After consent, the plugin starts its private
`HuaweiRtcScreenCaptureService` with foreground service type `mediaProjection`
before acquiring the projection. The plugin manifest declares the normal and
media-projection foreground service permissions. The host owns notification
permission UX on Android 13+ and must inspect its merged manifest.

The capture service supplies a visible foreground notification with **Stop**.
Its existing Android channel/title still contains “Experimental”; the example also
retains that runtime label. These are compatibility/UI strings in the unchanged
runtime, not this release's support classification. Changing them is outside this
documentation-only task.

Explain what the user is sharing before consent. Screen capture can expose content
outside the app, including personal information. Respect protected-content/OS
restrictions, keep credentials and private documents off-screen, and expose Stop
in the call UI. Notification permission denial does not remove Android foreground
service/privacy requirements. Do not claim hidden or silent screen capture.

## Background and lifecycle

Capture may continue after backgrounding while the Activity remains attached and
Android permits projection/media. It does not automatically stop merely because
Flutter becomes paused. Local/remote video views suspend their renderers while
inactive/paused and recreate on resume. OS/OEM restrictions, battery policies or
projection revocation can interrupt capture; verify on physical Huawei hardware.

Activity detach (including recreation), call end, filter stop and OS revocation
request capture shutdown. The capture service is non-sticky and uses `stopWithTask`;
there is no automatic capture resurrection or consent reuse. Call ownership and
capture ownership are distinct: Activity recreation can preserve the RTC call
while stopping its capture. Navigation away from a Flutter route alone does not
hang up the call.

## Stop, resource cleanup and camera restoration

Stop blocks screen frames immediately using a generation guard and releases the
latest retained screen Bitmap. Teardown releases the virtual display, ImageReader,
projection callback, worker and service; conversion scratch is released only after
worker termination. Failed cleanup retains references for retry, and late callbacks
cannot feed a replacement capture/call. Native Stop replies have a **3-second**
deadline; Dart applies an independent **5-second** fallback. Both can report
`screen_stop_uncertain`; this is a failure to confirm shutdown, not proof of release.
Query `getScreenAsCameraState`, retry Stop, or use Android capture controls.

Successful Stop waits for projection termination and resource release. It may
report `cameraOutputRestored=false` until a normal camera Bitmap is submitted.
That flag is local SDK submission evidence, not peer acknowledgment. Observe later
state updates and confirm camera restoration at the receiving endpoint. Stop does
not hang up. Hang up and wait for RTC `finished` before MM cleanup/account changes.
MM cleanup rejects a live call; vendor-internal cleanup is not rollback-capable.

## Orientation, output and readability

Capture dimensions use the display metrics with longest edge at most **640**.
The independent crop removes ImageReader row padding. The filter uses the SDK's
output dimensions; the pinned RTC Core 2.5.28 camera path supplies **640×480**.
This is a limitation of this integration path, not a universal Infobip platform
resolution claim. The public Flutter API has no screen-resolution setting.

Screen pixels use display orientation, rotation zero and horizontal compensation
for the inspected SDK bitmap conversion. Fit-center drawing preserves aspect with
black bars rather than stretching. Camera facing does not determine screen
orientation. Destination geometry is cached; blocked generations skip conversion,
latest images replace older ones, and worker scratch is reused. Fresh independent
output Bitmaps remain necessary because the public SDK gives no consumption
callback; device CPU, memory and frame-rate gains are not quantified here.

Portrait output fits within the 480-pixel frame height, leaving little horizontal
text detail. For example, a 1080×2400 display scales to a 288×640 capture and roughly
216×480 fitted content. Landscape and larger text are easier to read; sharing is
not a high-resolution document/presentation channel.

The local camera preview disables selfie mirroring during screen substitution and
uses fit scaling. After Stop it restores front-camera selfie mirroring/back-camera
unmirrored behavior. Remote renderer and publication settings remain independent.
Validate local and remote text/corner orientation on hardware; unit tests cannot
certify device GL/JNI behavior.

On Android captured-content resize callbacks, the first valid report establishes
the baseline. A subsequent changed size stops capture (`capture_size_changed`).
There is no automatic virtual-display recreation or seamless rotation restart;
restart requires fresh consent. Behavior depends on callbacks supplied by Android.

## Validation and evidence

Use the [example device checklist](../example/README.md) to check consent denial,
notifications, backgrounding, rotation, Stop, camera restoration, repeated sharing,
OS revocation and local/remote hangup. Automated tests cover filters, ownership,
cleanup failures, orientation and preview policy, not real projection/peer delivery.
See [security guidance](../SECURITY.md). Historical implementation and validation
reports remain in the Git repository and are excluded from the pub.dev package.
