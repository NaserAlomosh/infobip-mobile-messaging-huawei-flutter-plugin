# Huawei RTC Phase 1 call controls

Implemented on `feature/huawei-rtc-core` with Infobip RTC Core **2.5.28**. This is local client validation; Huawei hardware, Bluetooth behavior and live agent media remain to be tested.

## SDK evidence and exact APIs

Inspected the installed `com.infobip:infobip-rtc:2.5.28` AAR with `javap`, including `ApplicationCall`, `AudioDeviceManager`, `AudioDevice`, `AudioDeviceType`, `VideoOptions.CameraOrientation`, `DefaultApplicationCall` and `CallDuration` bytecode.

Cross-checked the official [InCallFragment at 15.1.0](https://github.com/infobip/mobile-messaging-sdk-android/blob/15.1.0/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/ui/fragment/InCallFragment.kt), [CallsDelegate](https://github.com/infobip/mobile-messaging-sdk-android/blob/15.1.0/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/delegate/CallsDelegate.kt) and [CallViewModel](https://github.com/infobip/mobile-messaging-sdk-android/blob/15.1.0/infobip-rtc-ui/src/main/java/com/infobip/webrtc/ui/internal/ui/CallViewModel.kt). Also inspected the official [Flutter plugin](https://github.com/infobip/mobile-messaging-flutter-plugin) and [Android SDK](https://github.com/infobip/mobile-messaging-sdk-android) references. Installed Core signatures determine the implementation; UI delegate names are not assumed to be Core methods.

| Feature | Exact installed APIs used |
| --- | --- |
| Microphone | `ApplicationCall.mute(boolean)`, `muted()` |
| Speaker and audio selection | `ApplicationCall.audioDeviceManager()`, `speakerphone()` readback; `AudioDeviceManager.getAvailableAudioDevices()`, `getActiveDevice()`, `selectAudioDevice(AudioDevice)`; `AudioDevice.getAudioDeviceType()` |
| Camera switch | `ApplicationCall.cameraOrientation()`, `cameraOrientation(VideoOptions.CameraOrientation.FRONT/BACK)` |
| Camera enable/disable | `ApplicationCall.cameraVideo(boolean)`, `hasCameraVideo()` |
| Duration | `ApplicationCall.duration()` |

`ApplicationCall.speakerphone(false)` exists, but its installed implementation chooses a non-speaker device from an unordered set. The plugin instead selects the SDK's available EARPIECE explicitly, guaranteeing the requested speaker-to-earpiece behavior without modifying microphone state.

Core `CallDuration.duration()` returns zero before establishment, elapsed seconds after establishment, and a frozen duration after termination. The plugin adds `durationSeconds` to call snapshots and exposes `HuaweiRtcCall.duration`. Existing event names and envelope keys remain unchanged; older snapshots decode with zero duration.

## Flutter usage and ownership

```dart
final call = await HuaweiRtc.getActiveCall();
if (call != null && call.status == HuaweiRtcCallStatus.established) {
  final state = await HuaweiRtc.setMicrophoneMuted(true, callId: call.id);
  await HuaweiRtc.setSpeakerEnabled(true, callId: call.id);
  await HuaweiRtc.switchCamera(callId: call.id); // Enabled video camera only.
  await HuaweiRtc.setCameraEnabled(false, callId: call.id);
  if (state.availableAudioOutputs.contains(HuaweiRtcAudioOutput.bluetooth)) {
    await HuaweiRtc.selectAudioOutput(HuaweiRtcAudioOutput.bluetooth,
        callId: call.id);
  }
}
```

Every control, including `getCallControls`, requires a call ID. The manager checks the current owned session and ID on the Android main thread. Mutations require ESTABLISHED status and an attached foreground Activity, and reuse existing permission checks. Camera permission is rechecked for capture activation/switching, not microphone muting or camera removal. Pending, stale, finishing and finished call mutations are rejected. Existing listener detachment and session identity checks continue to reject stale callbacks.

Control responses contain SDK readback, not the requested value. Setters skip an already-satisfied desired state. Camera switching checks the orientation readback because Core can catch a failure and emit an error callback without throwing. Native errors remain sanitized. Media and routing changes may complete asynchronously; callers should refresh `getCallControls` rather than treat a void SDK operation as completion.

The example serializes user control operations, disables unavailable controls, discards stale query/operation responses, refreshes SDK state and duration every second while active, and refreshes after errors. Remote video, local preview, hangup, diagnostics and the existing call/token path remain in place. No new event listener replaces the existing rendering listener.

## Availability limits

- Bluetooth, speaker, earpiece and wired headset are selectable only when listed by the SDK. No earpiece fallback is invented for tablets. Bluetooth requires the host's existing Nearby devices permission on Android 12+.
- Selection is by SDK device category; when multiple devices share a category, the first available SDK device is selected. Individual named-headset selection is not exposed.
- Camera controls are disabled on audio calls; switching additionally requires an enabled camera and known orientation. A missing/broken alternate hardware camera reports failure through readback or the existing SDK error event.
- SDK readback is authoritative but is not proof that a remote agent hears/sees media or that a physical Bluetooth route works. No hardware certification is claimed.

## Changed files

- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcControls.kt` — SDK adapter and authoritative snapshots.
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManager.kt` — session-bound MethodChannel controls and additive duration.
- `lib/src/rtc/huawei_rtc.dart` — typed controls, audio outputs, camera orientation and duration.
- `example/lib/screens/huawei_rtc_screen.dart` — functional controls and duration with SDK refresh.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcControlsTest.kt` — forwarding, routes, repeated actions, silent camera failure and errors.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManagerTest.kt` — state/permission/session boundaries, stale callbacks and duration.
- `test/huawei_rtc_controls_test.dart` — channel encoding, typed readback, failures and duration compatibility.
- `example/test/huawei_rtc_screen_test.dart` — connected/ringing/finished UI, failed operations, camera controls and stale responses.
- `docs/huawei-rtc-call-controls.md` — this implementation record and device checklist.

## Local validation

- `./gradlew :infobip_mobilemessaging_huawei:compileDebugKotlin :infobip_mobilemessaging_huawei:compileReleaseKotlin :infobip_mobilemessaging_huawei:testDebugUnitTest`: passed; **231 native tests**, zero failures/errors/skips.
- Plugin `flutter test --reporter expanded`: **210 passed**.
- Example `flutter test --reporter expanded`: **38 passed**.
- Example `flutter analyze`: no issues.
- Repository `flutter analyze`: 21 informational deprecation findings in unchanged Inbox/User code/tests; no new control findings, warnings or errors.
- `git diff --check`: passed.

## Huawei device checklist (pending)

1. Make existing audio and video calls through the unchanged conversations/token path. Verify HMS notifications and Chat still work.
2. Before answer, duration remains zero and controls stay disabled. After confirmed connection, duration advances; reconnecting does not reset it. Hangup freezes the final duration and disables controls.
3. Mute/unmute repeatedly: agent hears silence/resumed microphone, while incoming audio continues. Toggle routes while muted and verify the microphone remains muted.
4. Select speaker, earpiece and paired Bluetooth; confirm physical audio output. Connect/disconnect Bluetooth during the call, verify refreshed available routes and exercise Android 12+ permission denial. Check a device without an earpiece.
5. Switch front/back repeatedly during video. Verify agent video and local preview change together while remote rendering and audio continue.
6. Turn camera off/on repeatedly. Verify agent camera publication stops/resumes, local preview blanks/restores, remote video remains visible and the call is not ended. Exercise a missing/failed alternate camera.
7. Exercise rapid controls, operation errors, permission revocation, Activity recreation, leaving/returning to the screen, hangup during a pending operation, and immediate new calls. Old control IDs and queued callbacks must never change the replacement call.

## Git integrity

Required branch verified. HEAD and the entire staged diff are byte-for-byte unchanged from the initial snapshot. Each originally unstaged file's diff is also byte-for-byte unchanged. No commit, push, reset, stash, clean or branch switch was performed. No Gradle, manifest, dependency, Chat, HMS or token acquisition changes were introduced by this task.
