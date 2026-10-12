# Experimental screen-as-camera POC

This is a device-test POC, **not production-ready and not native Infobip screen sharing**.
Physical Huawei capture and Infobip Conversations delivery are **UNVERIFIED**.

## Scope and SDK gate

Inspected installed `com.infobip:infobip-rtc:2.5.28` public signatures and bytecode:

```java
ApplicationCall.setVideoFilter(VideoFilter)
ApplicationCall.getVideoFilter()
VideoFilter.start(int width, int height, int sourceFps, Context, VideoFilterManager)
VideoFilter.stop()
VideoFilter.applyFilter(Bitmap, int rotation, long timestampNs)
VideoFilterManager.notifyFrameProcessed(Bitmap, int rotation, long timestampNs)
```

The camera handler activates filtering only on API 29+, initially with 640x480
capture. Setting a different filter stops/recreates camera capture while retaining
the call. Processed bitmaps are converted asynchronously on the camera capture
handler, using the supplied rotation and timestamp. The SDK requests another
camera frame after processing output. Its public manager has no bitmap-consumed
callback. Submitted bitmaps therefore remain immutable and are GC-owned; the
plugin never recycles or mutates them after submission.

[Infobip's documented custom filters](https://github.com/infobip/infobip-rtc-extensions-android)
support processed bitmap output and asynchronous processing. Implementation uses
only those public interfaces, not inspected SDK implementation classes.

No native `startScreenShare`, `stopScreenShare`, or `resetScreenShare` calls,
private reflection, SDK modifications, dependency upgrades, or second connection
are introduced. Token acquisition, Calls configuration, destination, HMS and Chat
are unchanged.

## Architecture and ownership

`HuaweiRtcManager` remains the authoritative RTC session owner. The experimental
controller receives a call/session reference from it and cannot create a call.

1. Start requires a foreground Activity, an established video call, and enabled
   camera publication. An existing unrelated video filter is rejected.
2. Install one plugin-owned public `VideoFilter`. It initially passes camera
   bitmaps through normally. It stays installed in normal mode until call teardown,
   avoiding a second SDK camera restart when capture stops.
3. Request fresh Android capture consent using the Activity result listener.
4. After acceptance, start a dedicated projection foreground service. Acquire the
   projection only after that service has called `startForeground`.
5. The plugin acquires exactly one `MediaProjection` and registers its callback
   before creating its `VirtualDisplay`.
6. A dedicated capture worker reads the latest RGBA `ImageReader` image (maximum
   two images), closes every acquired image, and retains at most one screen bitmap.
7. SDK camera cadence drives filtering. Screen pixels are letterboxed into the
   SDK filter dimensions and submitted with the camera frame's timestamp and
   screen rotation value zero. A black frame is used until screen pixels arrive.
8. `sharing` is emitted only after a screen-derived bitmap is submitted to the
   SDK. This is **not** an acknowledgement of encoding or remote delivery.

The SDK-owned camera stays running underneath. Screen content replaces its output;
there are no simultaneous independent camera/screen publications. Camera flip and
camera on/off are blocked natively and disabled in the example while capture or
consent is active. Microphone, audio route, speaker, remote rendering, and hangup
remain available. Starting with camera disabled is rejected; the POC never silently
enables it. Camera orientation and enabled state consequently need no toggling to
restore the previous configuration.

## Independent stop and truthful state

Stop is independent of SDK media negotiation or signaling:

1. Under the filter lock, select normal-camera mode, increment the frame generation,
   and recycle the cached screen bitmap. Late capture frames are rejected/recycled.
2. Call `stop()` on the exact plugin-owned projection instance.
3. Release the virtual display; close the reader on its worker; quit the worker.
4. Observe `MediaProjection.Callback.onStop()` before claiming projection termination.
5. Unregister the callback and stop the dedicated capture service after confirmed
   termination and capture-resource release.

Duplicate stops join the same operation. Missing stop acknowledgement or failed
resource release produces `screen_stop_uncertain` after three seconds and retains
capture-operation ownership. It does not fabricate a successful stopped state.

Already-submitted SDK/transport frames cannot be withdrawn through this public API.
The agent can retain a last frame or receive an already-buffered frame after local
stop. The stop guarantee concerns **new local capture**, not erasure of remote pixels.

`cameraOutputRestored` means a normal camera bitmap was submitted after mode change;
it does not acknowledge remote rendering. It can remain false while SDK camera
frames are paused during reconnection. Use the existing `HuaweiRtc.getActiveCall()`
and RTC events separately to determine call status.

## Lifecycle

Capture requests carry a unique request number and owning RTC session identity.
Cancelled, detached, ended, or superseded permission results cannot start capture.
Call hangup (including the existing notification action), remote termination,
engine disposal, SDK filter teardown, system projection revocation, and capture
service destruction initiate the same capture cleanup.

Activity detach/recreation and post-start captured-content resize stop capture
conservatively. Restart requires a new explicit action and fresh consent. Ordinary
backgrounding does not itself detach the Activity and is supported by the capture
service. Process death cannot restart capture (`START_NOT_STICKY`, process-local
lease, no consent persistence). The dedicated service stops with task removal;
the existing ongoing-call service retains its original behavior.

## Android and foreground services

- API 26–28: explicit `screen_unsupported`; no consent request or fallback.
- API 29+: projection foreground-service type; existing microphone/camera call
  service remains separate. The additional notification has a capture-stop action.
  This service is capture coverage, not another RTC session owner.
- Android 12+: normal foreground-service launch restrictions apply. Start from
  the visible call screen; failed promotion prevents projection acquisition.
- Android 14+: `FOREGROUND_SERVICE_MEDIA_PROJECTION`, fresh consent, one projection
  acquisition and one virtual display per session. No consumed token is reused.
- Android 15/16 and target 36: no boot receiver or automatic restart. OS capture
  revocation/lock restrictions remain authoritative. Capture service promotion
  occurs before projection acquisition.

[Android projection restrictions](https://developer.android.com/media/grow/media-projection)
and [foreground-service requirements](https://developer.android.com/develop/background-work/services/fgs/service-types).

## Experimental Flutter API

```dart
await HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: activeCall.id);
await HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: activeCall.id);
final state = await HuaweiRtcScreenAsCamera.getScreenAsCameraState(callId: activeCall.id);
final subscription = HuaweiRtcScreenAsCamera.states.listen(observeState);
```

Typed `ScreenAsCameraState` exposes phase, call ID, frame blocking, projection
termination, resource release, camera-frame restoration and sanitized diagnostic
code. `ScreenAsCameraException` preserves native failure codes. Start is guarded
against duplicate Dart requests; native ownership remains authoritative. The
example labels the experiment, shows native state, and retains the existing UI.

## Known risks and upgrade considerations

- Remote Conversations compatibility and orientation are unverified. The installed
  SDK converter applies its own transforms; zero screen rotation requires device
  verification. Local preview may retain its camera mirroring configuration.
- Capture's longest dimension is capped at 640 pixels; output initially 640x480.
  Portrait text can be small because of letterboxing. This deliberately prioritizes
  bounded processing over readability in the first experiment.
- Bitmap allocation/conversion, SDK filter initialization/teardown, reconnection,
  background capture, OS revocation and camera restoration require hardware checks.
- Tests use mocks for projection acknowledgements and failure states. They cannot
  certify Android/OEM shutdown timing or remote media behavior.
- Public filter signatures were also inspected in 2.5.41. No upgrade is made or
  implied safe. Re-run signature, lifecycle and device tests for every RTC upgrade.
- No screenshots, recordings, consent payloads, or screen contents are persisted
  or logged. Protected content is handled by Android; there is no bypass.

## Manual Huawei + Conversations checklist

Record Android/Huawei build, app build, SDK version, elapsed stop time, expected
result, actual result and PASS/FAIL separately. **Every device result is currently
NOT RUN.** Use non-sensitive test screens.

1. Start a video Application Call; confirm normal camera reaches Conversations.
2. Tap Start Screen as Camera; approve official capture consent.
3. Confirm the agent sees screen content in the camera stream.
4. Check readable text, upright orientation, aspect ratio and local preview.
5. Navigate to other apps; confirm screen updates and microphone/audio continue.
6. Return through the existing call notification; verify no second call is created.
7. Stop; check `projectionTerminated=true`, `resourcesReleased=true`, Android capture
   indicator disappears, and the capture notification clears.
8. Check a normal camera frame resumes remotely and `cameraOutputRestored` becomes true.
9. Verify microphone, speaker, Bluetooth/earpiece selection and camera controls again.
10. Start again; verify fresh consent is shown.
11. Disconnect networking for at least a minute while capture is active.
12. Request Stop during reconnection; measure local indicator shutdown without
    waiting for networking. Camera restoration may remain pending.
13. Restore networking; verify the existing call recovers and ordinary camera resumes.
14. Revoke through Android system controls; verify cleanup and no automatic restart.
15. Deny consent, then press Back on a new prompt; verify no projection starts.
16. Repeat Start/Stop rapidly; verify single ownership and truthful state.
17. Rotate/recreate the Activity; verify conservative stop and fresh consent on restart.
18. Test screen lock/unlock and captured-app resizing; verify OS restrictions and no restart.
19. Hang up locally and remotely while capturing; verify indicator/resource cleanup.
20. End Call A with consent pending, start Call B, and deliver the old result; verify no capture.
21. Swipe away the task and separately kill the process; verify capture ends and does not resurrect.
22. Verify ongoing-call Mute/Unmute, End Call and Return actions before/after this experiment.

## Automated validation

Final validation on 2026-10-12:

| Command | Result |
| --- | --- |
| In `example/android`: `./gradlew -Dorg.gradle.java.home=/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin :infobip_mobilemessaging_huawei:testDebugUnitTest --offline` | PASS; 270 native tests, 0 failures/errors/skips; debug and release Kotlin compile |
| In plugin root: `flutter test --no-pub --reporter expanded` | PASS; 216 tests |
| In `example`: `flutter test --no-pub --reporter expanded` | PASS; 42 tests |
| In plugin root: `flutter analyze --no-pub` | Exit 1; 21 existing deprecation infos in unrelated files; no POC diagnostics |
| `flutter analyze --no-pub lib/src/rtc/huawei_rtc_screen_as_camera.dart test/huawei_rtc_screen_as_camera_test.dart` | PASS; no issues |
| In `example`: `flutter analyze --no-pub` | PASS; no issues |
| `git diff --check` | PASS |

Initial Java 17 native run could not run existing API 36 tests; installed Java 21
was selected through a command-line property without changing Gradle files.

## Files

Added:

- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenCaptureController.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenVideoFilter.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenCaptureService.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenAsCameraTest.kt`
- `lib/src/rtc/huawei_rtc_screen_as_camera.dart`
- `test/huawei_rtc_screen_as_camera_test.dart`
- `docs/huawei-rtc-screen-as-camera-poc.md`

Modified:

- `android/src/main/AndroidManifest.xml`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/InfobipMobileMessagingHuaweiPlugin.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManager.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcPluginLifecycleTest.kt`
- `lib/infobip_mobilemessaging_huawei.dart`
- `example/lib/screens/huawei_rtc_screen.dart`
- `example/test/huawei_rtc_screen_test.dart`

Existing staged/unstaged user changes were preserved: original staged binary-diff
SHA-256 `fa0d307933b3a86817b52ed7b22939c25befd8cc586e99b1f42aa5f93ab1c6c8`,
original unstaged paths SHA-256 `7b160643e2955e6e4271bd3006399cc5cdd5139cae214afe76293cd07959920f`.
Branch `feature/huawei-rtc-core`; HEAD `072aee3fdcacde430d71b6a221e9c5faa5274e1b`.
No commit or push.
