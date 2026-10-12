# Phase 3.4.3 — Screen-as-Camera performance report

Date: 2026-10-12. Evidence labels: **VERIFIED** means local source, installed
artifact inspection, or automated checks; **ESTIMATED** means a code-derived
performance estimate; **UNVERIFIED** means runtime evidence is still required.

## 1. Repository and branch

**VERIFIED:** `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`;
current branch `feature/rtc-screen-performance`; initial HEAD `cd41f72`
(`Merge pull request #77 from NaserAlomosh/feature/huawei-rtc-core`). Initial
`git status --porcelain=v1` was empty: no staged, unstaged, or untracked changes.
No branch creation/switch, fetch, pull, push, commit, reset, clean, stash, rebase,
or changes to development were performed.

## 2. Baseline pipeline and bottlenecks

Inspected the controller, filter, capture service, manager, Kotlin lifecycle and
orientation tests, Dart screen-sharing API/tests, and installed RTC 2.5.28 AAR.

The main-thread controller obtains fresh consent, starts the existing capture
foreground service, owns MediaProjection, and creates a capture HandlerThread.
The virtual display's longest capture edge is capped at the existing 640 pixels.
ImageReader uses RGBA_8888 and two buffers. On its worker, each callback calls
`acquireLatestImage()`, copies the plane into a newly allocated padded Bitmap,
and creates an independent cropped Bitmap (or copies when the crop aliases its
input). The padded Bitmap is recycled immediately and the acquired Image closes
through `use`. Ownership of the crop transfers to the filter's single latest slot.
Replaced or rejected captures are recycled under the filter lock.

SDK camera callbacks drive `applyFilter`: a fresh output Bitmap, Canvas and RectF
are created; black letterboxing, scaling and the existing horizontal compensation
are applied; rotation zero and the incoming timestamp are submitted. The existing
output is approximately 640x480, but the filter uses the SDK's supplied dimensions.
No replacement screen track is created.

**VERIFIED installed-artifact evidence:** inspected
`DefaultVideoFilterManager` using `javap -p -c` on the cached
`com.infobip:infobip-rtc:2.5.28` AAR's classes.jar. `notifyFrameProcessed` posts the
Bitmap reference to its filter handler, then its capturer handler; conversion
happens later. The capturer path invokes `ImageReaderFrameProvider.requestNext()`
after conversion. There is no public Bitmap consumption acknowledgment. This
supports preserving fresh SDK output allocations and existing consumer cadence.
No private SDK methods are called by the plugin and no AAR is modified.

Baseline bottlenecks established by source inspection:

- Two plugin Bitmap allocations per converted capture, even with stable geometry.
- One output Bitmap per sharing camera callback, necessary for asynchronous ownership.
- One RectF plus repeated scale/bounds calculation per rendered screen callback.
- Callbacks queued before Stop still performed conversion before offer rejected them.
- Captures may replace each other before a camera callback consumes their pixels;
  actual producer/consumer frequencies are **NOT MEASURED**.
- Full-plane copying, cropping, output rasterization, SDK GL upload/YUV conversion,
  and existing filter-lock contention remain. Their CPU shares are **NOT MEASURED**.

Baseline/post-change CPU, FPS, RSS/PSS, GC frequency, latency, and thermal metrics:
**NOT MEASURED**. No physical profiling or Huawei validation was performed.

## 3. Files changed

- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenCaptureController.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenVideoFilter.kt`
- Added `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenFrameProcessor.kt`
- Added `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcScreenPerformanceTest.kt`
- Added this report.

Service, manager, public Flutter APIs, dependency versions, resolution,
orientation policy, audio routing, notifications, call creation/destination,
HMS Push, and Chat are unchanged.

## 4. Optimizations

1. Reuse one worker-confined padded Bitmap while row-stride geometry is stable.
   Reallocate/recycle only if padded width changes. Capture height stays fixed
   for this projection, consistent with the conservative resize policy.
2. Keep an independent snapshot for every offered capture, including the
   full-size crop alias case. Scratch storage never transfers to the filter/SDK.
3. Drain and close the latest Image, but check sharing/generation under the
   filter lock before reading its planes or performing expensive Bitmap work.
   `offer` validates again, so Stop racing an already admitted conversion rejects
   and recycles the completed snapshot. Already running conversion is not cancelled.
4. Cache destination bounds in one RectF protected by the existing filter lock.
   Recalculate when captured dimensions change; invalidate when SDK output size starts.
5. Release scratch only after capture worker termination is confirmed. Include
   processor ownership in `resourcesReleased`; retain it if worker shutdown fails.
   Cleanup release remains idempotent and retryable.

No FPS limiter, timer, pending-frame queue, demand flag, or extra handler is added.
`acquireLatestImage()` and single-slot replacement remain in place. First-frame
processing stays immediate; output callback cadence and timestamp behavior stay
unchanged. No deliberate latency/smoothness tradeoff is introduced. Actual
latency and smoothness remain **UNVERIFIED** on hardware.

## 5. Before/after allocation comparison

**ESTIMATED, derived from allocation sites, not device allocation profiling.**
Counts exclude camera/SDK allocations and Android implementation internals.

| Work | Before | After |
| --- | --- | --- |
| First converted image / changed stride | 2 Bitmaps | 2 Bitmaps |
| Subsequent converted image, stable stride | 2 Bitmaps | 1 independent snapshot Bitmap |
| Submitted sharing output | 1 fresh Bitmap | 1 fresh Bitmap |
| Blocked/stale image after generation check | 2 Bitmaps before rejection | 0 Bitmaps |
| Intermediate padded Bitmap | Created/recycled each image | One retained worker scratch |
| Plane-to-Bitmap transfer | 1 per converted image | 1 per converted image |
| Crop/independent snapshot copy | 1 per converted image | 1 per converted image |
| Capture-to-output raster draw | 1 per rendered screen output | 1 per rendered screen output |
| Destination RectF | 1 per rendered screen output | 1 per filter instance |

For C converted images, S output callbacks and G scratch-geometry allocations,
plugin Bitmap allocations change from `2C + S` to `C + G + S`. Capture allocation
count falls approximately 50% after warm-up. If C equals S, total plugin Bitmap
allocation count approaches 3 -> 2 per capture/output pair (approximately 33%).
Do not assume C equals S without measuring cadence.

Avoided padded pixel-allocation traffic is approximately `4 * paddedWidth * height`
bytes per warm capture, excluding implementation overhead. This adds one retained
scratch Bitmap of that size while sharing; a lower steady-state RSS is **not**
claimed. With ordinary stride, dimensions bounded by 640x640 imply at most about
1.56 MiB of scratch pixel storage; actual padded stride must be measured.

The number of pixel copies does **not** decrease. Fresh output ownership is
unchanged. Expected lower allocation/zero-initialization/GC pressure is
**ESTIMATED**. CPU, memory, FPS, latency, thermal and battery improvements are
**UNVERIFIED / NOT MEASURED**.

## 6. Thread safety, ownership and lifecycle

Scratch is mutated only on its original capture HandlerThread. The main thread
releases it only after that worker is confirmed dead, transferring exclusive
cleanup ownership. A failed shutdown retains scratch and reader ownership for
the existing retry path. No Bitmap pool or shared mutable scratch is introduced.
Images close even for blocked generations or conversion exceptions. Two reader
buffers and `acquireLatestImage()` avoid an introduced capture backlog.

The filter lock continues to cover offering/replacing/recycling retained snapshots,
drawing them, generation checks and destination geometry. Snapshot conversion
happens outside that lock. The brief early generation check adds one lock acquisition
per acquired Image. Drawing and SDK submission keep their existing synchronization;
no main-thread join is introduced. Submitted output Bitmaps are never reused,
mutated or recycled by production code; camera pass-through remains unchanged.
The SDK's asynchronous queues are not claimed to be bounded by this optimization.

**VERIFIED F1–F4 preservation:** native per-Stop 3-second deadlines and Flutter
5-second timeout remain; cleanup attempts still clear references only after a
successful step; restoration remains scoped to owner identity, call and filter
generation; initial/duplicate resize remains accepted while genuine resize stops.
Projection revocation, fresh consent, uncertain cleanup, service ownership and
background capture behavior are preserved in source. Existing lifecycle tests pass.
Hardware behavior after this change remains **UNVERIFIED**.

## 7. Tests

Eight new native-graphics Robolectric tests exercise actual Bitmap pixels:

1. First-frame delivery, stable scratch identity, padded/non-padded rows, independent
   retained snapshots, and previously submitted output surviving overwrite/Stop.
2. Blocked/old generation Images close without reading planes or creating scratch.
3. Stop during plane retrieval rejects the completed snapshot and closes the Image.
4. Stride changes release old scratch; conversion exceptions still close Images.
5. Multiple captures replace/recycle the single latest slot before render; only
   `acquireLatestImage` is called and the newest pixels are submitted.
6. Empty acquisition and ten repeated generations deliver their first frames.
7. Separate capture/render workers perform 100 callbacks each without recycled
   frame access; latch synchronization and bounded waits detect hangs, with no FPS
   or elapsed-performance threshold asserted.
8. Cached bounds update for portrait/landscape and restarted SDK output dimensions.

Existing 17 screen lifecycle tests cover Stop deadlines, repeated Start/Stop,
cleanup retries (reader, callback, worker and service failures), restoration and
resize. Existing four orientation tests remain unchanged and pass. No tests removed.
These are correctness/ownership checks, not hardware benchmarks.

## 8. Exact automated results

JDK 21, existing Flutter 3.35.7 installation; no dependency/version changes.
Gradle ran offline from `example/android`:

```sh
JAVA_HOME=/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home ./gradlew --offline :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin
```

**PASS:** 287 Kotlin tests across 45 classes, 0 failures, 0 errors, 0 skips.
Includes 126 RTC tests: 17 screen lifecycle, 4 orientation, and 8 new performance
checks. Debug and release Kotlin compilation **PASS**. Existing deprecation/JVM
warnings remain; build exits 0.

Additional commands:

- Plugin `flutter test --no-pub test/huawei_rtc_screen_as_camera_test.dart`:
  **PASS**, 5 tests, exit 0.
- Plugin `flutter test --no-pub --reporter expanded`: **PASS**, 217 tests, exit 0.
- Example `flutter test --no-pub --reporter expanded`: **PASS**, 42 tests, exit 0.
- Plugin `flutter analyze --no-pub`: exit 1, 21 informational deprecation diagnostics
  in unchanged Dart files; 0 warnings/errors. No Dart files changed.
- `git diff --check`: **PASS**, exit 0.

Initial sandbox attempts could not write the existing Gradle/Flutter cache files.
Authorized execution with cache access succeeded. No requested automated check
remains unexecuted. The allocation baseline is source-derived; no before/after
physical benchmark was run.

## 9. Remaining risks and physical performance checklist

The remaining independent snapshot and fresh output Bitmap are necessary under
current ownership. SDK conversion/encoding, capture/render rates, filter lock
contention, display callbacks, GC behavior and scratch retention need device
profiling. Native graphics tests do not execute MediaProjection/GLES/encoding/network
or Conversations rendering. In-flight SDK output submitted before Stop can still
be consumed later, as in the existing implementation.

Before the first stable release, compare the initial HEAD and optimized working
copy on the same Huawei device, OS, display size, network and call configuration:

1. Profile idle call, static text sharing, scrolling, animation and background
   sharing for matched intervals. Record actual capture/conversion/camera/output
   rates, allocations, CPU, GC pauses, RSS/PSS/native heap, battery and thermal state.
   Use Android Studio allocation/CPU tools and Perfetto; avoid sensitive screen data.
2. Measure time to first remote frame and scroll-to-remote-display delay using
   synchronized video evidence. Record remote delivered FPS and dropped frames.
3. Run 30–60 minutes of capture; check memory plateau, GC, temperature and remote
   smoothness. Expect a retained scratch allocation, not guaranteed lower RSS.
4. Verify outgoing video and sharing reach Conversations. Check portrait/landscape
   readable text, four asymmetric corners, black letterboxing and camera-facing
   independence. Preserve the existing genuine-resize Stop/fresh-consent policy.
5. Stop from Flutter and notification, verify normal camera resumes, and repeat
   Start/Stop at least 20 times. Check both notifications after call termination.
6. Exercise cancellation, projection revocation, backgrounding, Activity detach,
   app kill, hangup and network disconnection. Confirm capture/call termination,
   notifications, bounded Stop replies and no stale session restoration.
7. Record device/OS/SDK, workload, duration, before/after samples and uncertainties.
   Compare with predefined product acceptance targets rather than inferred FPS.

## 10. Production assessment

**VERIFIED:** focused implementation, reduced allocation sites, independent Bitmap
ownership, lifecycle regression coverage, Kotlin builds and automated suites.
**ESTIMATED:** reduced allocation traffic and GC pressure with unchanged cadence.
**UNVERIFIED:** physical Huawei performance and post-change end-to-end behavior.

Ready for physical performance/non-regression validation. Production performance
certification remains pending those measurements; the user's successful testing
of the preceding implementation is not claimed as testing of this optimization.
Changes remain local and uncommitted on the required branch.
