# Phase 3.4.3 screen-as-camera horizontal orientation

Investigation date: 2026-10-12. Branch: `feature/huawei-rtc-core`.
The user reports working physical Huawei sharing with horizontally mirrored text
in Conversations Portal in portrait and landscape. Post-fix physical verification
has not been performed in this workspace.

## Root cause and pipeline evidence

The display-oriented replacement uses `notifyFrameProcessed(result, 0, timestampNs)`.
In the installed RTC 2.5.28 bitmap conversion path, rotation zero is **not an
identity texture transform**. It produces a horizontal inversion before publishing:

1. `HuaweiRtcScreenCaptureController.acquire()` reads RGBA bytes with
   `copyPixelsFromBuffer`, then crops positive `(0, 0, w, h)` bounds. No reflection
   matrix, reversed row traversal or negative dimensions are present.
   `VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR` duplicates display content; it does not mean
   optical left/right reflection. See the [Android API reference](https://developer.android.com/reference/android/hardware/display/DisplayManager#VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR).
2. `HuaweiRtcScreenVideoFilter.applyFilter()` originally letterboxed the captured
   bitmap with positive destination bounds and submitted rotation zero, independently
   of camera facing and incoming camera rotation.
3. SDK `DefaultVideoFilterManager.notifyFrameProcessed()` posts to its handler,
   then to the capturer handler. Its `lambda$notifyFrameProcessed$4` calls
   `BitmapToVideoFrameConverter.convert(bitmap, rotation, timestampNs)` and sends
   the returned frame directly to `cameraCaptureObserver.onFrameCaptured()`.
4. SDK `BitmapToVideoFrameConverter.convert()` uploads the bitmap using
   `GLUtils.texImage2D`. Bytecode offsets 56–71 select
   `Matrix.postRotate(180f, .5f, .5f)` when supplied rotation equals zero.
   The matrix goes into an RGB `TextureBufferImpl`, then `YuvConverter.convert()`.
   The resulting I420 `VideoFrame` retains the supplied rotation (zero here).
5. Installed `com.infobip:google-webrtc:1.0.45036` `YuvConverter.convertInternal()`
   offsets 82–119 build a centered Y flip (`preScale(1f, -1f)`).
   `VideoFrameDrawer.drawTexture()` composes the texture matrix with this matrix.
   In normalized sampling coordinates:

   ```text
   Y flip:              (x, y) -> (x, 1-y)
   SDK 180 rotation:    (x, y) -> (1-x, 1-y)
   combined sampling:  (x, y) -> (1-x, y)
   ```

   Thus the submitted screen bitmap's horizontal order is reversed by the
   SDK/WebRTC conversion composition. This happens upstream of transport and
   Portal rendering, and does not depend on front/back camera selection.
6. SDK `CameraVideoMediaHandler.startCameraCapture()` wires the filter manager
   to the camera `VideoSource` capturer observer. Facing-dependent camera texture
   transforms in WebRTC Camera1/Camera2 sessions happen **before** the filter;
   the plugin substitutes independent screen pixels after that stage.
7. `HuaweiRtcVideoBindings` selects `setMirror(true)` only for a local front-camera
   renderer; `HuaweiRtcVideoPlatformView.initializeRenderer()` applies it to that
   view. It does not transform the published track. Local selfie preview is
   therefore not reliable evidence of remote screen orientation. Portal source,
   decoded remote pixels, and device GLES execution were not available for inspection;
   no claim is made that Portal has no additional rendering transform.

Inspection used `javap -p -c` on cached SDK/WebRTC classes, without modifying AARs
or calling private APIs. SDK AAR SHA-256:
`9303984b90dd14cb31458d94d35b26f5b494ae42017e3174ae135030c01314a4`.
Public `VideoFilterManager` exposes bitmap/rotation submission and cadence controls,
but no horizontal-mirror publishing switch. `VideoOptions` and `ApplicationCall`
expose camera selection/filter controls, not a publishing reflection option.
The public renderer mirror setting is a display operation.

## Smallest fix

Apply `canvas.scale(-1f, 1f, width / 2f, height / 2f)` while drawing substituted
screen pixels into the already allocated result bitmap. The converter's horizontal
inversion cancels this compensation. Keep rotation zero, dimensions, letterboxing,
timestamps, cadence, and allocation count unchanged. The non-sharing branch
continues forwarding the original camera bitmap, rotation and timestamp; capture
lifecycle and camera restoration are unchanged. No camera-facing conditional is
needed, and no second compensation is applied.

Files added/changed for this task:

- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenVideoFilter.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenOrientationTest.kt`
- `docs/huawei-rtc-screen-orientation.md`

## Automated verification

Four regressions cover actual Canvas drawing with native Robolectric graphics:
portrait and landscape asymmetric four-color corners after the modeled SDK
sampling transform, all four incoming camera rotations, black letterboxing,
unchanged output dimensions, camera pass-through before/after sharing, and a
bytecode guard for the installed converter/YUV transform assumptions.
The conversion model does not execute GLES, native encoding, network delivery,
or browser rendering.

Validation commands and results:

- In `example/android`, Gradle with JDK 21 and `--offline`:
  `:infobip_mobilemessaging_huawei:compileDebugKotlin`,
  `:infobip_mobilemessaging_huawei:compileReleaseKotlin`,
  `:infobip_mobilemessaging_huawei:testDebugUnitTest`,
  `:app:compileDebugKotlin`: **PASS**. 279 Kotlin tests, zero failures/errors/skips,
  including all 17 existing `HuaweiRtcScreenAsCameraTest` tests and 4 new tests.
- Plugin `flutter test --no-pub --reporter expanded`: **217 passed**.
- Example `flutter test --no-pub --reporter expanded`: **42 passed**.
- Plugin `flutter analyze --no-pub`: 21 informational deprecation diagnostics
  in unrelated, unmodified Dart files; no warnings/errors. Command exits 1.
- `git diff --check`: **PASS**. Existing staged/unstaged changes preserved;
  no commit or push.

## Remaining risks and physical Huawei checklist

The compensation is specific to the inspected converter behavior; re-check it
when upgrading SDK/WebRTC. The bytecode regression intentionally fails if those
assumptions change. Physical GPU and Portal results remain to be verified.
Local front-camera preview retains its existing selfie mirroring and can show
mirrored screen content even when published pixels are correct.

1. Show non-sensitive `LEFT ABC123 -> RIGHT` text with four distinct corner marks.
   Begin a fresh share in portrait, then separately in landscape. Confirm both
   words and corner placement in Portal; capture evidence of each.
2. Repeat starting with front camera and back camera (switch before sharing).
   Confirm identical remote screen orientation and no double mirroring.
3. Stop sharing each time. Confirm previous camera selection, natural remote
   camera orientation, existing local selfie behavior, and successful restart.
4. Repeat previously passing permission cancellation, duplicate start/stop,
   system revocation, Activity detach and hangup checks. Do not change expected
   capture-size-change lifecycle behavior to complete this orientation test.
5. If Portal still differs, compare the received stream in a temporary plain
   browser video element with no CSS transforms against the Portal tile. Record
   the tile/ancestor computed transforms. That comparison separates decoded
   stream orientation from Portal display behavior without adding another flip.
