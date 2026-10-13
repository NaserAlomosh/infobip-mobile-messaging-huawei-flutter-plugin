# Phase 3.4.4 — RTC Screen-as-Camera video quality and orientation

Date: 2026-10-12. **VERIFIED** denotes current source, installed-artifact
inspection or automated tests. **ESTIMATED** denotes a code-derived expectation
without measurements. **UNVERIFIED** denotes hardware, transport or Portal
behavior that was not exercised here.

## Repository and prerequisites

**VERIFIED:** repository `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`,
branch `feature/rtc-screen-video-quality`, initial HEAD `b388b34`. Initial
`git status --short` was empty. The branch check preceded implementation.
No branch was created/switched, no fetch/pull, commit/push, merge/cherry-pick,
reset/stash/clean/rebase, or modification of development was performed.

Phase 3.4.3 is present in executable source: worker-owned padded scratch in
`HuaweiRtcScreenFrameProcessor`, rejection before plane reads, independent
capture snapshots, cached destination bounds, fresh SDK output and latest-only
replacement. Its eight performance regression tests remain and pass.

Phase 3.4.2 is present: native per-Stop 3-second deadline, Dart 5-second timeout,
retryable resource cleanup, projection/service/session ownership, filter epochs,
generation-scoped camera restoration, resize termination and fresh consent.
Existing lifecycle checks pass. The controller still releases scratch only after
worker termination; failed cleanup retains references for retry. Capture service,
notification behavior, termination and network call cleanup paths are unchanged.

The user's physical Huawei validation of the preceding implementation is accepted
as supplied context; it is not claimed as physical validation of this change.

## Actual rendering pipeline

**VERIFIED, source and installed SDK:**

```text
Display pixels
  → MediaProjection VirtualDisplay (display-oriented, longest edge ≤640)
  → ImageReader (RGBA_8888, two buffers, acquireLatestImage)
  → worker scratch ARGB_8888 Bitmap, row padding retained during copy
  → independent crop of visible positive [0,w) × [0,h) bounds
  → filter's single latest snapshot (replaced snapshots recycled)
  → SDK camera callback drives applyFilter
  → fresh output ARGB_8888 Bitmap, SDK start(w,h) dimensions
  → black background + filtered fit-center draw + existing X compensation
  → notifyFrameProcessed(result, rotation=0, incoming timestamp)
  → asynchronous SDK GL bitmap conversion / WebRTC YUV conversion
  → camera video source / encoding / transport
  → Conversations Portal
```

Only the camera stream is replaced. The camera must remain enabled. No separate
screen track, custom WebRTC source, permissions or SDK implementation API is added.

Capture uses `resources.displayMetrics`: `s=min(1,640/max(displayW,displayH))`,
`captureW=max(1,floor(displayW*s))`, similarly for height. The actual device
display dimensions were **NOT MEASURED**. Floor rounding can slightly alter the
display aspect ratio at capture by less than one pixel per dimension; the filter
preserves the resulting captured Bitmap's aspect exactly within raster coverage.
Row padding is removed by the crop, not by rescaling. There is no plugin rotation
of display pixels or reversed row traversal in capture.

## Installed SDK resolution capability

**VERIFIED:** `com.infobip:infobip-rtc:2.5.28`; AAR SHA-256
`9303984b90dd14cb31458d94d35b26f5b494ae42017e3174ae135030c01314a4`.
Inspected public class signatures and relevant bytecode with `javap`; neither
SDK binaries nor AARs were modified. Implementation inspection is evidence only;
production code calls public interfaces.

`CameraVideoMediaHandler.startCameraCapture` supplies literal **640,480** to
`DefaultVideoFilterManager.start` on the supported filtered path, and requests
640,480 from its camera capturer. The manager passes those dimensions to
`VideoFilter.start` and its own camera ImageReader provider. The plugin creates
outputs using those supplied dimensions. A new bytecode regression guards these
initialization constants. Actual selected sensor and encoded/received resolutions
remain **UNVERIFIED**; network adaptation can reduce effective detail.

| Public API inspected | Resolution capability |
| --- | --- |
| `VideoOptions.Builder` | Camera orientation, video mode, video filter, camera/screen frame rate; no size/constraints/quality profile setter |
| `ApplicationCall` | Camera/filter/track and call controls; no camera capture size or resolution setter |
| `VideoFilterManager` | Submission, error and cadence controls; no output resolution configuration |
| `VideoRenderer` / inherited `SurfaceViewRenderer` | Public display mirroring and fit scaling; renderer settings do not configure publication |

**VERIFIED limitation:** this installed camera/filter pipeline initializes at SD
and provides no supported public configuration for higher resolution. This is
not a claim that the entire Infobip platform enforces a universal 640×480 limit.
The submission signature accepts a Bitmap but does not establish a documented
resolution renegotiation contract for arbitrary larger replacement frames. No
larger Bitmap workaround was attempted.

Infobip's [Android RTC guide](https://github.com/infobip/infobip-rtc-android)
and [official filter examples](https://github.com/infobip/infobip-rtc-extensions-android)
describe public renderer/filter use. Its [platform feature guide](https://www.infobip.com/docs/voice-and-video/webrtc/configure-webrtc-features)
lists frame-rate control and general SD/HD bandwidth examples; those examples
do not prove an Android 2.5.28 camera resolution setter. The individual official
VideoOptions/VideoRenderer/VideoFilter wiki pages could not be fetched by the web
tool in this run; findings for this version rely on the actual installed APIs.

## Scaling, readability and orientation

**VERIFIED:** fit-center already uses
`scale=min(outputW/sourceW,outputH/sourceH)` and centered floating-point bounds.
Positive equal scale in both axes prevents stretch. The whole source rectangle
is drawn; unused output is black. Geometry is recalculated only for a source
shape change or restarted SDK output dimensions. No pixel snapping or rounding
of destination bounds is added: independent integer rounding could distort ratio.

| Strategy | Screen content consequence | Decision |
| --- | --- | --- |
| Existing fit-center | Full captured screen, correct proportions, letterboxing | Preserve |
| Center-crop | Fills output but removes edges and potentially readable content | Reject |
| Stretch to output | Full screen with distorted letters and proportions | Reject |

Portrait generally uses the 480-pixel output height and side bars. Landscape
generally uses the 640-pixel width and top/bottom bars when wider than 4:3.
For a hypothetical 1080×2400 display, capture is 288×640 and output content
is 216×480. For its landscape counterpart, capture/output content is 640×288.
These are **VERIFIED formula examples**, not device measurements. Tall phone
screens therefore use much less than 640 pixels of horizontal text detail.

Quality losses occur at the VirtualDisplay downscale to ≤640, the second filter
downscale (especially portrait), and downstream conversion/codec/network/display
resampling. No SDK bitrate or Portal transform measurement was performed.

The existing `Paint.FILTER_BITMAP_FLAG` enables filtered Bitmap sampling. A
synthetic alternating-stroke downsampling test confirms intermediate coverage
rather than nearest-neighbor aliasing. Anti-aliasing flags for vector edges would
not recover lost Bitmap text detail. ARGB_8888 remains throughout plugin processing;
no new color conversion, dither, sharpening, intermediate Bitmap or image filter
is introduced. Color fidelity after YUV conversion and encoding is **UNVERIFIED**.
No measured sharpness/readability improvement is claimed for outgoing video.

The existing rotation-zero X compensation remains essential: the inspected SDK
bitmap conversion applies 180 degrees, followed by WebRTC's Y sampling inversion,
which together reverse X. The filter's existing X reversal cancels that conversion.
It is not a fix for local preview mirroring. Existing bytecode/corner tests guard
this assumption, including all incoming camera rotations. See
[the orientation investigation](huawei-rtc-screen-orientation.md).

## Rotation lifecycle

**VERIFIED:** captured pixels remain display-oriented; incoming camera sensor
rotation does not rotate replacement pixels. Output dimensions remain those of
the SDK filter session. Android's captured-content resize callback accepts the
initial positive report and duplicates; a subsequent genuine size change stops
capture with `capture_size_changed`. The new preview settings restore at frame
blocking, independently of eventual cleanup completion.

Restart requires a fresh permission request; no projection/token reuse or
virtual-display recreation is added. Repeated/background rotation follows this
same existing contract when the system reports resize. Android 14 callback tests
exercise it; callback availability/timing on older Huawei OS versions remains
**UNVERIFIED**. Seamless rotation would require a separately approved lifecycle
and consent proposal and is not implemented.

## Local preview improvement

**VERIFIED:** the plugin explicitly enabled local front-camera selfie mirroring
at renderer creation and previously kept it while screen pixels replaced camera
pixels. This can mirror screen text locally even when remote publication is correct.
The installed renderer inherits public `setMirror` and `setScalingType`; their
display semantics are also documented in the public
[WebRTC renderer source](https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/android/api/org/webrtc/SurfaceViewRenderer.java).

Now, while substitution is enabled, local renderers use `setMirror(false)` and
`SCALE_ASPECT_FIT`. Fit avoids additional preview cropping when the Flutter view's
shape differs from the output. The renderer temporarily uses centered WRAP_CONTENT
layout: the previous MATCH_PARENT supplies EXACTLY measurements that override
SDK fit sizing. A measured-layout regression covers wide and tall containers.
On Stop, revocation, failed start after acquisition
or termination, settings restore to current front/back camera mirroring and
`SCALE_ASPECT_BALANCED` (the verified installed renderer's previous default).
The camera's MATCH_PARENT layout is restored as well.
New/recreated local views read current substitution state and start with this
policy. Camera-event refresh also reads current policy.

Policy updates are main-thread/session-scoped, require matching owner identity
and call object in the manager, cache applied settings, and ignore stale/disposed
views. A setter failure releases that view and is isolated from capture/call
cleanup and other views. Remote renderers and publication Bitmaps are untouched.
There is no extra outgoing flip. Surface/GPU rendering and any brief transition
from previously queued camera/screen frames remain **UNVERIFIED** on hardware.

## Files and performance implications

Modified under `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/`:

- `HuaweiRtcScreenCaptureController.kt`: internal preview-state accessor and safe
  transition notifications; capture/cleanup decisions remain intact.
- `HuaweiRtcManager.kt`: owner-checked preview updates and current policy on view binding.
- `HuaweiRtcVideoBindings.kt`: display-only mirroring/scaling and restoration.
- `HuaweiRtcVideoPlatformView.kt`: centered flexible renderer measurement during
  sharing, with the original camera layout restored after Stop.
- `HuaweiRtcScreenVideoFilter.kt`: class comment updated; pixel processing unchanged.

Tests under the corresponding `android/src/test/kotlin/` RTC directory:

- Added `HuaweiRtcScreenVideoQualityTest.kt`: seven native-graphics/artifact checks.
- Updated `HuaweiRtcVideoBindingsTest.kt`: four preview/restoration/isolation checks.
- Updated `HuaweiRtcVideoPlatformViewTest.kt`: one real SDK renderer measurement check.
- Updated `HuaweiRtcScreenAsCameraTest.kt`: one observer-failure test plus assertions
  in the three existing Stop/revocation/call-end scenarios.
- Added this report. No public Flutter API, dependency, service, call-creation,
  destination, microphone, audio routing, HMS Push or Chat changes.

**VERIFIED:** no additional per-frame Bitmap, lock, capture queue, processing
pass or filter-worker work. Scratch reuse, early stale-generation rejection,
cached fit geometry, independent snapshots and immutable-after-submission SDK
outputs are retained. Main-thread transition/track refresh adds bounded binding
iteration and display setters only when a setting changes. View count bounds
the bookkeeping; no frame cache is added. **ESTIMATED:** negligible transition
cost; CPU, memory, latency, FPS, thermal and battery effects are **NOT MEASURED**.

## Automated validation

JDK 21; installed Flutter 3.35.7. Dependencies unchanged; Gradle ran offline.
Initial sandbox attempts were **BLOCKED** by existing Gradle lock/Flutter cache
write permissions. Approved cache-access executions completed all checks below.
No automatic approval rejection occurred and no check remains blocked.

| Check | Result |
| --- | --- |
| Baseline Kotlin suite | **PASS**, exit 0 (existing task/results up to date) |
| Focused screen/preview Kotlin suite | **PASS**, exit 0 |
| Full plugin Kotlin suite | **PASS**, exit 0: 300 tests / 46 classes; 0 failures, errors or skips |
| Full RTC subset of that suite | **PASS**: 139 tests / 11 classes |
| Screen subset | **PASS**: 18 lifecycle + 4 orientation + 8 performance + 7 quality = 37 |
| Debug Kotlin compilation | **PASS**, exit 0 |
| Release Kotlin compilation | **PASS**, exit 0 |
| Flutter plugin tests | **PASS**, exit 0: 217 tests |
| Flutter example tests | **PASS**, exit 0: 42 tests |
| Flutter analysis, baseline and final | **FAIL** command exit 1: identical 21 informational deprecation diagnostics, 0 warnings/errors |
| `git diff --check` | **PASS**, exit 0 |
| Physical Huawei / Portal validation | **NOT RUN**, **UNVERIFIED** |

Commands from `example/android` (with JDK 21):

```sh
./gradlew --offline :infobip_mobilemessaging_huawei:testDebugUnitTest --tests '*HuaweiRtcScreen*Test' --tests '*HuaweiRtcVideo*Test'
./gradlew --offline :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin
```

Plugin and example each ran `flutter test --no-pub --reporter expanded`.
Plugin ran `flutter analyze --no-pub` before and after; diagnostic sets match.
OpenJDK class-data-sharing warnings remain in native test execution. The unchanged
Flutter Gradle tooling `minSdkVersion`/`ApkVariant` and plugin
`NativeEventBridge.kt` LocalBroadcastManager deprecations were emitted in the baseline.
No existing warning or diagnostic was removed or suppressed.

Synthetic tests cover portrait/landscape/4:3/odd dimensions, four distinct corner
markers, centered non-black extents, stable 640×480 output, repeat-frame independence,
an asymmetric text-like stroke pattern at 1:1 across camera rotations, filtered
downsampling, and installed SD initialization. Existing tests retain scratch,
stride, stale epochs, racing Stop, no mutation/recycling of submitted frames,
camera restoration, repeated generations and cleanup-failure coverage. CPU models
and mocked SDK submission do not execute MediaProjection, GLES, encoding or Portal.

## Physical Huawei validation checklist

**NOT RUN.** Use the same device/OS, display scale, camera selection, call
configuration, network and Portal tile for baseline/change comparisons. Record
device model, OS, actual capture/output/received size, duration and visual evidence.
Use non-sensitive `LEFT ABC123 → RIGHT` text, four differently colored corners
and unequal L/bar strokes. Mark each item PASS/FAIL with evidence:

1. Portrait start: full screen/corners visible, proportions correct, predictable side bars.
2. Landscape start: full screen/corners visible, predictable bars and no clipping.
3. Small text: compare identical font sizes and Portal zoom; record the smallest readable size.
4. Large text: natural horizontal order, no vertical flip or rotation artifacts.
5. Web page: verify headers, edge controls and text near all four boundaries.
6. Flutter screen: verify asymmetric controls, text and layout proportions.
7. Scrolling: observe cadence, lag, dropped frames and edge content.
8. Video/moving content: check smoothness, conversion artifacts and latency.
9. Portrait → landscape while sharing: genuine reported resize stops; fresh consent restarts correctly.
10. Landscape → portrait: same contract; repeat rotations and test while backgrounded.
11. Local preview: unmirrored screen with front/back camera selected; fit in wide/tall views;
    recreated view after foregrounding retains the policy.
12. Remote Portal: natural text/corners for both camera selections; no added remote flip.
13. Stop from Flutter: bounded result, frames blocked, projection/resources/notification released.
14. Stop from notification: same cleanup and local preview restoration.
15. Camera restoration: original publication/facing, front selfie mirroring and back unmirrored;
    camera switching after Stop still behaves correctly.
16. Repeated Start/Stop: at least 20 cycles with fresh consent and no stale frame/view state.
17. Background capture: remote output continues under existing foreground-service contract.
18. App termination: capture/call cleanup and notification removal as in baseline.
19. Network disconnection: existing call-end/capture cleanup; no stale-session restoration.
20. CPU/memory: compare static text, scrolling and motion over matched intervals,
    then 30–60 minutes; record CPU, RSS/PSS/native heap, allocations/GC, FPS and thermal state.

## Rejected alternatives and production decision

Rejected: larger MediaProjection resolution without supported outgoing-size
control; oversized submission as a speculative SDK workaround; crop/stretch;
artificial sharpening; extra conversion/filter passes; scratch/output pooling
that mutates submitted frames; changing compensation to correct preview; private
SDK/renderer APIs, reflection into SDK, AAR patching, custom tracks, SDK upgrade,
and seamless rotation that bypasses the resize/fresh-consent contract.

**VERIFIED:** local preview improvement is supported by installed public APIs,
focused regressions and full automated suites. Outgoing fit/scaling, cadence,
orientation compensation, lifecycle hardening and allocation optimizations remain.
**ESTIMATED:** transition overhead is small; no benchmark supports a performance claim.
**UNVERIFIED:** post-change physical preview/GPU, Portal, readability and device stability.

Decision: ready for physical Huawei non-regression acceptance. First stable
production release approval remains pending that checklist and product acceptance
of the documented SD/portrait readability limit. This phase does not establish
higher-resolution outgoing video or certify physical production behavior.
Changes remain local and uncommitted on the required branch.
