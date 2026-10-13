# Huawei RTC ongoing call notification (Phase 2)

Implemented against RTC Core **2.5.28**, on `feature/huawei-rtc-core`, starting at
`08f60d2802e62be319538072209f49e450caf4a3`. Local implementation and automated
checks do not certify physical Huawei behavior. Phase 1 device results supplied
by the user remain the baseline, not proof of Phase 2 behavior.

## Ownership and service

`HuaweiRtcManager` remains the single engine-scoped owner of the SDK call and
listener. `HuaweiRtcCallNotification` gives `HuaweiRtcCallService` a process-local
observation lease: session UUID, readback closure, action closure and one-shot
foreground readiness callback. No token or account credentials enter the lease,
notification, intents or service. The service never acquires tokens or creates
RTC sessions, and holds no Activity or Flutter widget.

After token acquisition and the existing resumed-Activity/permission checks, the
manager requests foreground service creation. Only successful `startForeground`
promotion permits the existing backend call creation. Permissions and Activity
eligibility are rechecked immediately before creating SDK media. Moving to the
background during token acquisition or service promotion cancels creation; return
to the app and start again. Service startup has a five-second manager timeout;
failed promotion/start reports sanitized `rtc_foreground_service_failed` and
releases the pending request. The Android platform itself still enforces its
foreground startup deadline and restrictions.

The service is non-exported, `stopWithTask=false`, and returns `START_NOT_STICKY`.
It is never started by boot, background push or a worker. Activity configuration
recreation reattaches the existing manager and intent listener; it does not create
a second service. Destruction of the FlutterEngine preserves Phase 1's hangup
attempt and cleanup behavior. An independently destroyed/replaced engine does
not adopt an old call.

## Foreground types and permissions

* Audio: runtime type `microphone` on Android 11/API 30+.
* Video: runtime types `microphone|camera` on Android 11/API 30+, including when
  the user temporarily disables the camera. Both are promoted while eligible,
  so later camera re-enablement does not require a background type escalation.
* API 26–29: two-argument foreground promotion; camera/microphone type constants
  were introduced in API 30.
* Manifest: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`,
  `FOREGROUND_SERVICE_CAMERA`, `POST_NOTIFICATIONS`; service declaration
  `android:foregroundServiceType="microphone|camera"`.
* Existing media runtime prerequisites: `RECORD_AUDIO`, `CAMERA` for video, and
  the Phase 1 `BLUETOOTH_CONNECT` prerequisite on Android 12+. The host requests
  runtime permissions before calling; the RTC extension does not prompt.

`phoneCall` and `MANAGE_OWN_CALLS` are deliberately absent. This extension has no
Telecom `ConnectionService`, self-managed PhoneAccount, or default-dialer role.
Android's phone-call FGS requirements include MANAGE_OWN_CALLS or the dialer role,
and the documented use is continuation of calls using ConnectionService. A VoIP
SDK alone does not establish those prerequisites.

Android 12+ restricts background foreground-service starts; Android 14+ checks
microphone/camera while-in-use eligibility at service creation. A visible eligible
Activity is required here. Permissions granted earlier are insufficient to make
an arbitrary background start valid.

Android 13+ notification denial does **not** skip service creation/promotion.
Without the self-managed calling exemption, the notification can be absent from
the drawer while Android still exposes foreground work in Task Manager. Channel
blocking also changes visibility. The example already offers notification
permission/settings controls; allow Notifications to test drawer actions.

Sources:
[service types](https://developer.android.com/develop/background-work/services/fgs/service-types),
[start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start),
[notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).

## Notification and actions

Stable channel `huawei_rtc_ongoing_calls`, low importance, no badge; dedicated
white vector small icon, CALL category, PRIVATE visibility, LOW priority,
ongoing, immediate foreground display request, only-alert-once updates. Labels
are neutral audio/video call labels and never show identity or token data.

Connecting has no elapsed timer. Once established, a notification chronometer
uses SDK connected-call duration. The service refreshes SDK status, duration and
microphone readback once per second, independent of Activity attachment. Finished
callbacks immediately stop the service and remove its notice; polling also
reconciles an SDK FINISHED status if a callback is missed. Duplicate/stale terminal
callbacks cannot release another session.

Each action contains **both native call ID and unique session UUID**. Immutable
explicit PendingIntents have distinct session/action identities, so even a reused
SDK call ID cannot make an old action control a replacement session.

* Return: a direct Activity PendingIntent uses the host launch Activity with
  NEW_TASK from the package launch intent, CLEAR_TOP and SINGLE_TOP. No
  notification trampoline or new call is involved. Intent data is cleared to
  avoid Flutter deep-link routing. The plugin consumes validated Activity intents
  once, emits additive `returnToCall` on the RTC event stream, and stores a
  consumable request for startup/resume via `HuaweiRtc.takeNotificationCall()`.
  Stale/finished calls return null. Hosts must provide a launch Activity and wire
  the event and startup/resume consumption to their existing call route. The
  example implements this and pops back to an existing RTC route when available.
* End: native SDK `hangup()` on the current manager session. It works with no
  attached Activity or widget. Duplicate taps are ignored after acceptance; the
  service remains until actual finished state. If no terminal state arrives in
  ten seconds, retry hangup and stop the notification/service to bound cleanup.
  **This failure fallback retains manager call ownership and does not manufacture
  a finished event.** The SDK may still report an active call; another call stays
  blocked. Return to the app to inspect/retry hangup; a late real finished event
  still releases ownership. This edge is a termination uncertainty, not proof of
  remote hangup or guaranteed media cleanup.
* Mute/Unmute: available only for established calls with reliable SDK mute
  readback. Uses the existing `HuaweiRtcControls` adapter and existing permission
  check, without the Phase 1 foreground-widget guard. Each action sets an explicit
  target boolean (duplicate taps do not toggle twice); the next SDK readback
  supplies the label. Exceptions leave the displayed state based on SDK readback.
  End-pending sessions reject mute actions.

No new service-status API, dependency, token path, RTC listener, session, video
view, calls configuration or destination was introduced. The existing SDK version,
HMS, Mobile Messaging and Chat integrations are unchanged by this implementation.

## Task removal and termination limits

Ordinary backgrounding leaves call ownership and the service intact.
`onTaskRemoved` requests native hangup and uses the same terminal/bounded cleanup.
Unexpected service destruction asks the owner to hang up if the process is still
alive. These callbacks are best effort: abrupt kills, OEM task management, Android
Task Manager Stop, and Force Stop can bypass them. A non-sticky service cannot
recreate the dead session; Android owns removal of foreground notifications when
the process/service terminates. No persisted call/service recovery is attempted.

A foreground service changes process priority, so Phase 1's tested kill scenario
must be retested. No client can guarantee server-side hangup after abrupt process
termination. Explicit Force Stop cannot reliably be intercepted. Huawei battery
management and differences between Android and EMUI versions require physical
validation. Android versions may allow users to dismiss ongoing notifications;
setOngoing is not a universal non-dismissible guarantee.

## Focused verification

Native coverage: connecting/established/finished notifications, chronometer,
SDK mute readback, channel, immutable native action intents, stale call/session
IDs, reused call ID, duplicate events and end taps, foreground readiness timeout,
background eligibility race, startup/promotion permission failures, notification
denial, service shutdown/destruction, task removal, manifest permissions/types,
Activity listener detach/reattach, and Android APIs 28/30/33/34/36.

Flutter coverage: consumable return snapshot/null, sanitized foreground failure,
notification event decoding, initial/resumed event navigation, existing route
reuse, and no call creation on return. Existing Phase 1 tests are also run.
Robolectric tests model platform failure paths; they do not certify actual
Android 12 start exemptions, Android 14 AppOps, notification surface visibility,
or Huawei media continuation.

Commands (repository root unless indicated):

```sh
# API 36 Robolectric needs Java 21; override only this invocation.
./example/android/gradlew -p example/android \
  -Dorg.gradle.java.home=/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home \
  :infobip_mobilemessaging_huawei:compileDebugKotlin \
  :infobip_mobilemessaging_huawei:compileReleaseKotlin \
  :infobip_mobilemessaging_huawei:testDebugUnitTest :app:compileDebugKotlin
flutter test --reporter expanded
flutter analyze
# In example/:
flutter test --reporter expanded
flutter analyze
```

## Physical Huawei checklist (not yet executed for Phase 2)

- [ ] Record device/EMUI/Android version, targetSdk and permission/channel state.
- [ ] Audio and video: start while resumed; connecting notification appears,
      timer starts only on establishment, call type is correct.
- [ ] Background during connecting and during established audio/video; confirm
      remote audio/video continue. Recheck Phase 1 mute/speaker/camera controls.
- [ ] Notification tap returns to the same call ID and existing route without
      another call, duplicate Activity, Flutter deep link or video renderer loss.
- [ ] Return with an existing call route under another route; repeat while the
      app is already foregrounded; test Activity configuration recreation.
- [ ] Mute/Unmute from background: verify microphone at the remote endpoint and
      SDK/UI readback. Repeated taps set the same target without toggling twice.
- [ ] End from background: confirm remote termination and finished event before
      removal. Double tap and end during connecting; check no leaked service.
- [ ] Remote hangup, rejection, network loss/error: notice tracks actual state
      and disappears at terminal state. Error callbacks alone need not be terminal.
- [ ] Call A ends, call B starts: retained old intents must not mute/end/return
      to call B. Recheck a quick hangup/new-call sequence.
- [ ] Android 13+: allow/deny Notifications and block/unblock the channel;
      distinguish drawer from foreground Task Manager visibility.
- [ ] Revoke microphone/camera; start failure must create no SDK call or lasting
      service. Android 12+/14+: background during token fetch/promotion must fail
      safely. Test slow/failing token fetch and delayed service creation.
- [ ] Swipe task away: confirm best-effort hangup and bounded service cleanup.
      Repeat the exact Phase 1 process-kill scenario; explicitly Force Stop and
      Android Task Manager Stop separately. Check no stale notice on relaunch.
      Record remote hangup timing as observation, never a client guarantee.
- [ ] Test the ten-second missing-terminal fallback using failure instrumentation:
      no lasting service, no invented finished event, no replacement active call.
- [ ] Test Huawei battery optimization modes, screen lock and prolonged calls;
      record any OEM restriction rather than assuming stock Android behavior.

## Verification results for this implementation

- Plugin debug/release Kotlin and example debug Kotlin compilation: passed.
- Full native unit suite: **258 passed**, zero failures/errors/skips. API 36 used
  Java 21 through the command-line Gradle override above. There are existing
  compiler/tooling warnings and two deprecated Robolectric test helper usages.
- Flutter package tests: **212 passed**.
- Example tests: **41 passed**, including deferred return until resumed so video
  PlatformViews are constructed only after foreground reattachment.
- Example analysis: no issues.
- Package analysis: **21 informational deprecation diagnostics**, all in unchanged
  files; no errors/warnings. Flutter analyze exits nonzero for these infos.
- Merged example manifest: verified required foreground permissions, non-exported
  service and `microphone|camera`; no phoneCall or MANAGE_OWN_CALLS declarations.
- `git diff --check`: passed.
- Physical Huawei Phase 2 checklist: **not executed**.

## Files changed by Phase 2

- `android/src/main/AndroidManifest.xml`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/InfobipMobileMessagingHuaweiPlugin.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManager.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcCallService.kt` (new)
- `android/src/main/res/drawable/huawei_rtc_call.xml` (new)
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcCallServiceTest.kt` (new)
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcManagerTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/rtc/HuaweiRtcPluginLifecycleTest.kt`
- `lib/src/rtc/huawei_rtc.dart`
- `test/huawei_rtc_test.dart`
- `example/lib/app.dart`
- `example/lib/screens/huawei_rtc_screen.dart`
- `example/lib/screens/test_center_screen.dart`
- `example/test/huawei_rtc_screen_test.dart`
- `docs/huawei-rtc-ongoing-call.md` (new)

Existing staged example README, build configuration, MainActivity, strings,
gradle.properties and chat screen changes were preserved. Existing unstaged chat
screen and four dependency-evidence edits were preserved. They are not Phase 2
changes. At completion of implementation, before subsequent publication
authorization, no stage/commit/push/reset/stash/clean or branch switch was
performed. The implementation base branch was `feature/huawei-rtc-core`, at HEAD
`08f60d2802e62be319538072209f49e450caf4a3`.
