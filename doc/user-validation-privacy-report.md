# User validation privacy investigation

Current status is in [Phase 2](#phase-2--residual-risk-hardening-2026-11-02). Earlier sections retain the Phase 1 investigation and validation record.

## Baseline (2026-11-02)

- Branch: `fix/user-validation-privacy`; HEAD: `a4a066062067b65a30c5fc9a97a0dd3660ee1f6e`.
- Initial working tree: clean (`git status --porcelain=v1` produced no output). No branch change, commit, push, publication, or PR creation.
- G-01 is present: HEAD merges PR #91; `UserPatch` and `FieldUpdate` are in `lib/src/user/user.dart`, presence-aware encoding in `user_codec.dart`, and native `UserMapper.toPatch` checks key presence. Existing Dart/native regression tests and `doc/g01-user-update-patch-report.md` document the semantics.
- `android/build.gradle.kts`: Huawei Core, Inbox, Chat **9.3.0**; Infobip RTC **2.5.28**. RTC UI **15.1.0** is an isolated contract-inspection dependency, not an app runtime dependency. No dependency or toolchain changes.
- Existing security context: `SECURITY.md`, `doc/final-production-certification.md`, `doc/sec01-release-logging-mitigation.md`, and the G-01 report. No separate checked-in upstream User Validation Privacy audit was found. A connected GitHub issue search for validation/privacy in the canonical repository returned no matches. The supplied task describes the original finding; no independent audit text or finding ID is asserted here. SEC-01 is outside this change.

## Finding and confirmed SDK evidence

Original finding: invalid user email values may appear in native validation logs. Installed SDK inspection narrows the trigger to **length**, not email syntax.

Inspected the cached `com.infobip:infobip-mobile-messaging-huawei-sdk:9.3.0` AAR, cache object `453e82c441b1eacacdd1138913ff743d84f86b93`. SHA-256:

`0a4948e0c5474eec8ebd6780324fd20d383b111daae2f89883d76720a12859e6`

Reproduce without any user payload: extract `classes.jar` with `unzip -p <aar> classes.jar`, then run `javap -classpath <classes.jar> -c -p` on the fully qualified classes below. Evidence is from the installed binary, not inferred from a generic email validator:

- `org.infobip.mobile.messaging.mobileapi.user.UserDataValidator.validate(User)` invokes `validateEmails` at bytecode offset 26 and later `throwValidationException` if errors exist.
- `validateEmails(Set, List)`: null returns; set size greater than 100 adds a count error; for each non-null email, `String.length()` at offset 83 is compared with 255 at offsets 86–89. The overlength branch uses format string `email '%s' exceeds maximum length of %d characters (actual: %d)` at offset 93 and inserts the complete email at offsets 99–102. There is no syntax, whitespace, Unicode normalization, or regex check in this method. Java length counts UTF-16 code units.
- `throwValidationException(List)`: builds the detailed message, calls `MobileMessagingLogger.e(String)` at offset 73, then throws `UserDataValidationException` with that same message at offsets 76–84.
- `org.infobip.mobile.messaging.mobileapi.user.UserDataReporter.patch(ResultListener, User)`: calls the validator at offset 6. Its exception handler calls `MobileMessagingLogger.e(String, Throwable)` at offset 16, so the exception creates a second potential exposure; it then delivers `MobileMessagingError.createFrom` through the result callback.
- `org.infobip.mobile.messaging.logging.MobileMessagingLogger.log(Level, String, String, Throwable)`: calls its writer when logging is enabled **or the level is ERROR** (offsets 0–20). Default writer is `LogcatWriter`. Disabling ordinary SDK debug logging is not a demonstrated remedy for this error path.
- `org.infobip.mobile.messaging.mobileapi.MobileMessagingError` maps a general Throwable, including `UserDataValidationException`, to code `-10`. The bridge already replaces SDK failure messages with fixed text in `UserManager.fail`; that does not prevent earlier SDK logging.
- `org.infobip.mobile.messaging.MobileMessagingCore.saveUser(User, ResultListener)` first calls `storeAndMergeUnreportedUserLocally` (offset 2), then the reporter's `patch` (offset 25). The merge reads unreported data, merges the incoming user, and persists it before validation. Avoiding SDK entry also avoids persisting a newly submitted overlong value.

Other fields on this validator path: external user ID and profile names produce length/count metadata rather than raw values; phone validation checks count only. Custom-attribute overlength errors include the **attribute key**; CustomList serialization failures log the key and exception message. Those keys/messages may be sensitive. This focused email mitigation does not fix those upstream behaviors. `validate(UserIdentity)` also uses `validateEmails`; personalization remains outside the requested implementation scope.

## Affected bridge paths

Both public facade methods in `lib/src/core/infobip_mobilemessaging_huawei.dart` delegate to the platform interface. `lib/src/platform/method_channel_infobip_mobilemessaging_huawei.dart` sends `saveUser` or `patchUser` with the existing `user` envelope. `UserCodec.encode` keeps legacy nullable fields; `encodePatch` emits only included patch fields. Neither modifies emails.

`InfobipMobileMessagingHuaweiPlugin.onMethodCall` dispatches both methods to `user/UserManager.kt`. `UserMapper.toUser` and `toPatch` convert email lists to sets using existing SDK setters. Both manager operations ultimately call the same `MobileMessaging.saveUser` API. Thus both are affected; the Dart distinction between full and partial updates does not avoid SDK validation logging.

## Selected mitigation and compatibility

`UserEmailPrivacy.validate(User)` checks only whether any submitted native email exceeds 255 UTF-16 code units. Both manager operations call it after mapping, before accessing the lazy SDK instance. A dedicated value-free exception is caught before the existing generic argument handler; the existing main-thread callback returns code `-10` and actionable fixed text: `Each email must contain at most 255 UTF-16 code units`. No values, payload, cause, details, or logs are added. No network work or native binary changes are introduced.

This is deliberately not an email syntax validator. Under-limit malformed strings, whitespace, Unicode, empty strings, and multiple emails continue unchanged to the SDK. Existing list-to-set conversion and duplicate removal remain unchanged. Email count validation remains with the SDK. Omitted patches stay absent; null clear and empty lists keep their existing native maps; legacy nullable serialization is unchanged. Non-email fields are untouched.

Overlong values already fail installed SDK validation. The change rejects the entire operation earlier, preserving the SDK validation error code while replacing the bridge's generic failure text with a safe explanation. It intentionally prevents SDK local persistence of that rejected input. Error ordering can change: before the guard, SDK depersonalization/state checks could take precedence; an overlong submission now fails before SDK entry. Plugin initialization checks still take precedence. No claim of identical callback timing or SDK side effects is made for rejected requests.

A regex would reject values SDK 9.3.0 currently accepts locally and would not be a compatible mitigation. Calling the SDK validator in advance would itself log the sensitive value. Global logging suppression and payload modification were rejected.

## Regression tests and verification

New native `UserEmailPrivacyTest` uses real SDK models and the installed validator, with a mocked SDK at the manager boundary:

- Both APIs reject a mixed list containing an overlong synthetic email, invoke one safe failure callback, emit no captured Android logs, and never call the SDK.
- Both APIs forward multiple accepted values unchanged, including whitespace, Unicode, empty/malformed strings, a 255-unit boundary and existing duplicate removal. Non-email firstName survives.
- Omitted/null/empty email maps and legacy nullable keys remain intact.
- UTF-16 boundary tests include supplementary Unicode characters.
- A synthetic overlength input reproduces the installed validator's value-bearing exception and confirms its `-10` error mapping. This characterization deliberately invokes the upstream behavior with synthetic data only.

New Dart `user_validation_privacy_test.dart` verifies unchanged MethodChannel values on both APIs and propagation of a synthetic native private failure as an error with no details or submitted email. The channel is mocked: this test does not prove Android execution. Existing G-01 tests cover omission, set, clear, empty collections and non-email patches.

Validation uses existing Flutter 3.44.4 from `example/android/local.properties` and installed Java 21 for existing Robolectric requirements. Initial restricted-environment attempts could not write Flutter/Gradle cache locks; authorized reruns used the same installed tools and dependencies. No upgrades occurred.

Final checks (all completed successfully):

| Check | Passed | Failed/errors | Skipped |
| --- | ---: | ---: | ---: |
| `flutter analyze --no-pub` | No issues | 0 | 0 |
| `flutter test --no-pub` (plugin) | 246 | 0 | 0 |
| `flutter test --no-pub` (example) | 49 | 0 | 0 |
| Native `testDebugUnitTest` | 422 | 0 | 0 |
| Native `testReleaseUnitTest` | 422 | 0 | 0 |
| `git diff --check` | Clean | 0 | 0 |

Native invocation from `example/android`:
`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest --offline`.
Counts come from the final Flutter summaries and Gradle JUnit XML (54 suites per variant). Native results include the five new privacy tests in each variant; Dart plugin results include the two new channel tests. Existing deprecation/named-parameter compiler warnings remain unrelated. No APK build, physical-device, backend, or instrumentation check was performed.

## Residual upstream risks and device verification

This prevents the identified path for **newly submitted overlong emails through saveUser/patchUser**. It cannot suppress arbitrary SDK logs, cached/unreported values from older versions or direct native calls, background retries, personalization, custom-attribute diagnostics, or backend error content. In particular, an omitted email patch can still cause the SDK to validate previously pending native emails. The guard does not read, clear, or rewrite that state.

Recommend Infobip remove raw email values from `validateEmails` diagnostics and redact validation exceptions before logging in the reporter; apply the same review to custom-attribute keys/serialization errors and identity validation. Recheck the bytecode and boundary tests whenever the SDK changes.

Physical Huawei device verification remains **NOT RUN**. With synthetic data and controlled backend configuration, capture debug and release logcat while exercising both APIs with 255/256-unit values, mixed lists, Unicode, omitted/clear/empty updates, and more than 100 distinct emails. Confirm rejected new values do not reach storage/network; verify valid submissions and callbacks; separately test pre-existing pending overlong data, background retries, depersonalization state and process restart. Verify server persistence/deletion independently. Local tests do not establish backend or device privacy guarantees or certify upstream log elimination.

## Changed files

- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacy.kt`: narrow value-free length guard.
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserManager.kt`: apply guard to save/patch and preserve validation failure code.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacyTest.kt`: native SDK boundary and installed-validator regressions.
- `test/user_validation_privacy_test.dart`: channel compatibility and safe error propagation tests.
- `README.md`: developer-visible rejection contract and limitations.
- `doc/user-validation-privacy-report.md`: investigation, compatibility, validation and remaining work.

## Final decision

**READY FOR INDEPENDENT REVIEW** — the narrow plugin-boundary mitigation is implemented and automated checks pass. This is not a claim that upstream logging or persisted-state privacy is completely resolved. All six changed/new files remain uncommitted for owner review.

# Phase 2 — residual risk hardening (2026-11-02)

The sections above record Phase 1. This section is the current assessment and supersedes the earlier statement that personalization is outside scope. The Phase 1 files were committed by the owner before this continuation; Phase 2 changes are left uncommitted.

## Baseline verification

Branch `fix/user-validation-privacy`, HEAD `1f6fd82e4f97849475fc6b53ec3fb98dfa87ff59`, matching the requested baseline; initial `git status --short` was empty. Reviewed the guard, both native manager call sites, all five Phase 1 native privacy tests, two Dart privacy tests, G-01 tests, and this report. SDK dependencies remain Core/Inbox/Chat 9.3.0, RTC 2.5.28, isolated RTC UI contract AAR 15.1.0. Flutter remains 3.44.4 and native checks use installed Java 21; no upgrades or configuration changes.

Existing `test/user_test.dart` covered personalization channel serialization, attributes, and force=true. Phase 1 covered save/patch, not native personalization. No existing deterministic pending-storage/background privacy test was found in the user tests. New native boundary tests and installed-bytecode characterization explicitly distinguish those evidence types.

## R-01 — personalization: MITIGATED for new plugin submissions

Complete route: `InfobipMobileMessagingHuawei.personalize(PersonalizeContext)` and legacy `personalizeUser` → `InfobipMobileMessagingHuaweiPlatform.personalize` → `MethodChannelInfobipMobileMessagingHuawei.personalize` → existing `personalize` method with `userIdentity`, `userAttributes`, `forceDepersonalize` → native plugin `personalize(MethodCall, Result)` → `UserManager.personalize` → `UserMapper.toIdentity` / `toAttributes` → `MobileMessaging.personalize(identity, attributes, force, listener)`. `UserCodec.encodeIdentity` preserves email strings; native mapping retains existing list-to-set deduplication.

Re-inspected the same installed 9.3.0 AAR and SHA-256 recorded above, using `javap -c -p`. All SDK names below are relative to `org.infobip.mobile.messaging`:

- `mobileapi.user.UserDataValidator.validate(UserIdentity)` invokes `validateExternalUserId`, then `validateEmails` at offset 26, then `validatePhones`. This is the identical 255-Java-UTF-16-unit email limit and raw-value message/logging path established in Phase 1. It also rejects more than 100 distinct emails. Identity external user ID overlength diagnostics expose lengths, not the raw ID; phones have a count check only. Attributes are separately validated and retain the custom-key/serialization diagnostic risks described above.
- `mobileapi.user.PersonalizeSynchronizer.personalize(UserIdentity, UserAttributes, boolean, boolean, boolean, ResultListener)` invokes identity validation at offset 1, attributes validation at 5. The validation-exception catch logs `PERSONALIZE VALIDATION ERROR` with the Throwable at 17, then calls `MobileMessagingError.createFrom` at 40 and the listener at 46. The validator has already emitted its detailed error before this catch. The Throwable maps to code `-10`; new tests confirm this using the actual identity validator and error factory. The synchronizer call graph is separately pinned by bytecode tests; no backend callback execution is claimed.
- Important pre-validation state behavior: `MobileMessagingCore.personalize(...ZZZ..., ResultListener)` checks registration first (offset 1), network next (39), and, when force=true, invokes `depersonalizeCurrentInstallation(true)` at 83. Empty-identity checks and attribute identity-key removal follow; only at 220 does it enter `PersonalizeSynchronizer.personalize`. Thus it can depersonalize before rejecting an overlong email. The synchronizer validates before constructing its operation/body or scheduling its request. No incoming identity-email persistence before that validation was found in the inspected personalization path; the core's earlier forced depersonalization is a real state change.

Implementation: add a `UserIdentity` overload to `UserEmailPrivacy.validate`, sharing one private email-set length check with the existing `User` overload. Call it immediately after identity mapping in `UserManager.personalize`, before attribute mapping or lazy SDK access. Existing `UserEmailLengthException` handling provides the same value-free message, main-thread callback and `-10` code. No production reflection, storage reads/writes, extra network calls, or logging are added.

Compatibility: accepted identities, attributes, null/empty/multiple emails, duplicates, under-limit malformed strings, whitespace, Unicode, and force=true/false continue through unchanged. Initialization still takes precedence. Rejected requests now fail before native registration/network checks, attribute errors, and forced depersonalization; these error-order/side-effect differences are intentional and limited to overlong-email requests. Valid requests retain force behavior. This is an early rejection of values already rejected by native validation, not a guarantee that every SDK state previously returned `-10` (registration/network failures can previously precede validation). No public API or channel changes.

## R-02 — persisted pending data: UPSTREAM DEPENDENCY

Installed-bytecode evidence:

1. `MobileMessagingCore.saveUser(User, ResultListener)` invokes `storeAndMergeUnreportedUserLocally` at offset 2, before depersonalization checks and reporter `patch` at 25. `storeAndMergeUnreportedUserLocally` reads `getUnreportedUserData` at 1, invokes SDK `UserMapper.merge` at 7, and `saveUnreportedUserData` at 17. Hence earlier plugin versions or direct native submissions can have persisted an overlong value before validation rejected it.
2. `saveUnreportedUserData` checks `shouldSaveUserData` at 1; when enabled it serializes with `UserMapper.toJson` and writes `MobileMessagingProperty.UNREPORTED_USER_DATA` through `PreferenceHelper.saveString` at 28. `getUnreportedUserData` reads that property via `findString` at 20 and `UserMapper.fromJson` at 23. Persistence therefore depends on the host SDK storage setting; it is not unconditional.
3. SDK `UserMapper.merge` applies the older object and then the newer object. `plus` checks `containsField("emails")` at 179 and sets emails at 197, including present null. An omitted-email `patchUser` preserves older pending emails; empty patches do too. In contrast, the legacy Flutter `saveUser(UserData)` mapper always sets the email key, including null: a save with unspecified emails overwrites that pending email field in this merge rather than omitting it. A sparse **native** `User` save can preserve pending emails, but it is not equivalent to this plugin's legacy nullable serializer. Explicit application-requested email clear/replacement also overwrites the field; none is inserted automatically by this change.
4. Reporter `patch` validates before debouncing, registration checks and request scheduling. The validation catch logs and returns without acknowledging/clearing pending data. Repeated later sync may encounter it again. `MobileMessagingCore.saveUser` stores even before its depersonalization-in-progress check, while `performSyncActions` skips user reporting when depersonalization is in progress.
5. Supported facade `MobileMessaging.getUser()` reads `USER_DATA` and merges `getUnreportedUserData` at offsets 47–50. It permits inspection of a **merged** profile, not a separate atomic pending queue. `fetchUser` is a server operation, not a safe pending-state inspector. `getUnreportedUserData`/`saveUnreportedUserData` are public members of the concrete implementation but absent from the supported `MobileMessaging` facade; public visibility is not treated as a supported application migration contract.

No safe transparent plugin-side repair is demonstrated. Automatically clearing/replacing emails changes user identity and G-01 intent; checking a merged snapshot cannot intercept SDK background work or guarantee atomicity, and rejecting valid no-email patches based on stored state changes their contract without fixing retries. No storage deletion/reset, automatic clear, forced depersonalization, private-internal access or failure swallowing is implemented. An application can deliberately submit an email replacement/clear using its existing APIs, but that is application intent, can affect identity/server state, cannot undo existing logs, and is not a proven race-free migration. Request an Infobip redaction fix and a supported pending-data inspection/migration contract.

## R-03 — SDK-managed retries: UPSTREAM DEPENDENCY

All call paths in this table are bytecode-derived unless explicitly identified as runtime tests. For pending emails to reach the vulnerable validator, sync must reach the user reporter branch: `performSyncActions` calls installation sync, returns during depersonalization, and chooses `repersonalize` when `shouldRepersonalize` is true; otherwise it calls `getUnreportedUserData` at 85 and `UserDataReporter.patch(null, pending)` at 88. Reporter validation happens even without a Flutter callback and before registration checks.

| Trigger | SDK entry point / evidence | Pending-email validation/log exposure | Plugin control / safe remedy |
| --- | --- | --- | --- |
| General sync, including message-delivered/seen and in-app click reporting | `MobileMessagingCore.sync`, `lazySync`, private `sync(ZZ)` → `performSyncActions`; `setMessagesDelivered` invokes sync, seen/click reporting invokes lazySync | Yes on the pending-user branch; raw overlong email may be logged on every validation attempt | Some actions originate in the app, others in SDK modules. User API guard does not intercept them; blocking sync would disable unrelated functionality |
| Application foreground | `MobileMessagingSynchronizationReceiver.onReceive` checks `LocalEvent.APPLICATION_FOREGROUND`, calls `foregroundSync` at 23 | Yes, subject to SDK foreground throttle/network/application-code/state checks | SDK lifecycle execution; no compatible cancellation or interception API found |
| Network recovery | `MobileMessagingConnectivityReceiver.onReceive` → `retrySyncOnNetworkAvailable` at 46; core calls `performSyncActions` at 23 only after a previous sync and outside its recent-sync throttle | Yes if pending branch runs; no new user API call required | SDK-owned; do not intercept connectivity or suppress failures |
| Scheduled connectivity job | `platform.MobileMessagingJobService.registerForNetworkAvailability` schedules a network-required JobInfo; `onStartJob` → `retrySyncOnNetworkAvailable` at 41 | Same conditional pending validation; the job does not bypass the core's gates | No safe plugin retry cancellation identified. The job is connectivity work, not evidence of a periodic timer |
| Initialization/token acquisition or refresh | `MobileMessagingCore.Builder.build` requests token acquisition through `PlayServicesSupport.checkPlayServicesAndTryToAcquireToken`; `cloud.hms.HmsRegistrationTokenHandler.handleNewToken` calls `sendRegistrationToServer` at 41; base `RegistrationTokenHandler.sendRegistrationToServer` calls core sync at 80 for changed/unreported token state, lazySync at 90 otherwise | Can reach pending validation through sync after token delivery; not an unconditional validation on every initialization | SDK-owned token lifecycle. Do not alter registration or SDK initialization |
| Process restart | Pending JSON is restored by `getUnreportedUserData`; subsequent foreground/token/sync events can reach the above paths | Conditional exposure after state is loaded and sync runs; no proof that every restart immediately logs | Actual process recreation and OEM scheduling remain device verification; no durable retry cancellation is claimed |
| In-memory transport retry | `UserDataReporter.patch` validates before constructing `$1` and executing it. `$1.run(User[])` calls `MobileApiUserData.patchUser`; `MRetryableTask$1.error` schedules `Handler.postDelayed`, `$1$1.run` re-enters task execute | Does **not** rerun `UserDataValidator` in the inspected task. Invalid pending data returns from reporter validation before this task is created. A later fresh sync is a separate revalidation | No new transport-retry hook is justified; other request/exception logs are not certified by this finding |
| Automatic repersonalization | `PersonalizeSynchronizer.repersonalize` reconstructs identity/attributes from merged `getUser`, creates `$4` retry task | This method and `$4.run` do not invoke `UserDataValidator`; therefore do not attribute the same validation log to this branch. `$4.run` passes its personalization body to verbose SDK logging, a separate potential stored-data exposure when that logging is enabled | Not intercepted by the new-input guard. No broad SDK logging changes made; upstream must assess stored-data diagnostics too |

No lifecycle hooks, service changes, retry cancellation, initialization changes or global logging suppression are introduced. An in-memory delayed retry is not evidence of persistent scheduled retry after process death. No supported public API was found that can install a redacting validator or safely intercept all pending-data sync paths.

## Phase 2 tests and evidence boundaries

- `UserPersonalizationPrivacyTest`: five new Robolectric tests. Real SDK identity models, validator, and error factory; mocked `MobileMessaging` only at the plugin boundary. Tests cover exact 255/256 UTF-16 boundaries (including supplementary characters), mixed lists, unmodified valid/malformed/whitespace/Unicode values, null/empty/omitted collections, existing deduplication, external user ID/phones/attributes, both force flags, one safe failure callback/no SDK invocation/no captured logs on rejection, unchanged success/error callbacks, and initialization precedence. Test-only reflection injects the SDK mock into the existing lazy field; production code uses no reflection.
- `UserPrivacySdkBytecodeTest`: four deterministic tests inspect the installed class resources with the existing ASM dependency. They pin pending merge/persistence call ordering, preference reads/writes, public merged getter, sync/foreground/connectivity/job/token entry points, the distinction between validation and transport retry, and personalization validation/log/callback calls after the core force-state operation. These execute **no SDK storage, background job, process restart or backend** and do not pretend to reproduce those behaviors.
- Two added Dart tests in `user_validation_privacy_test.dart` cover personalization channel values/attributes/force and value-free native error propagation. MethodChannel is mocked; native execution is independently covered above.
- Runtime SDK persistence, network recovery, job delivery and background logcat are **not verified** by these tests. No timing-dependent simulated background or backend guarantees are asserted. The focused native test compilation initially failed on ambiguous Mockito matchers; explicit SDK parameter types corrected the test code before the passing rerun.

Phase 2 final validation (all pass):

| Check | Passed | Failures / errors | Skipped |
| --- | ---: | ---: | ---: |
| `flutter analyze --no-pub` | No issues | 0 | 0 |
| Plugin `flutter test --no-pub` | 248 | 0 | 0 |
| Example `flutter test --no-pub` | 49 | 0 | 0 |
| Native Debug | 431 | 0 | 0 |
| Native Release | 431 | 0 | 0 |
| `git diff --check` | Clean | 0 | 0 |

Both native suites were run with the same offline Gradle invocation recorded in Phase 1, on Java 21. Counts are from final summaries and JUnit XML (56 native suites per variant); they include nine new native tests per variant and two new plugin Dart tests. The final native run after strengthening call-order assertions completed successfully. Flutter and Gradle required existing cache access outside the restricted workspace; authorized runs used the same tools. Existing unrelated compiler deprecation warnings remain. No device/backend/instrumentation test or APK build was performed.

## Phase 2 changed files

- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacy.kt`: add identity overload sharing existing length check.
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserManager.kt`: validate identity before SDK entry.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPersonalizationPrivacyTest.kt`: native personalization regressions.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPrivacySdkBytecodeTest.kt`: installed-bytecode characterization of residual paths.
- `test/user_validation_privacy_test.dart`: personalization channel regressions.
- `README.md`: extend the existing private length-rejection contract to personalization and its legacy alias.
- `doc/user-validation-privacy-report.md`: this Phase 2 evidence, limitations and validation record.

## Phase 2 residual risk matrix and physical verification

| Risk | Classification | Reason |
| --- | --- | --- |
| R-01 new personalization emails through the plugin | MITIGATED | Same verified native length rejection now occurs before SDK entry, including force=true. Other SDK entry points and attributes are not covered |
| R-02 previously stored pending emails | UPSTREAM DEPENDENCY | Omitted patches and native sync can revalidate old data; no compatible automatic state repair demonstrated |
| R-03 SDK-managed sync/retry paths | UPSTREAM DEPENDENCY | Native lifecycle/connectivity/registration paths bypass new-input guards; transport retries are distinguished from fresh validation |
| Physical-device/backend behavior | NOT VERIFIED | Automated model/bridge/bytecode evidence does not establish device scheduling, persistence, or server outcomes |

Physical Huawei verification is still required with synthetic data only: both force flags and valid/overlong identities; verify no depersonalization, storage or network submission for rejected inputs; confirm valid callbacks and identity retention. Separately characterize an upgrade with pre-existing pending overlong emails, an omitted-email patch versus explicit clear/replacement and legacy save null semantics, offline-to-online recovery, foreground transitions, registration/token renewal, process restart, depersonalization gates, and actual connectivity-job execution. Capture debug/release logcat including suppressed-debug configurations because ERROR logs bypass the ordinary enable flag. Test the automatic repersonalization branch separately from reporter validation. Confirm backend effects independently; do not clear production state as a test workaround.

Infobip remains responsible for removing raw values from validator diagnostics/exception logging and providing a supported safe pending-data migration or interception contract. Phase 2 does not close the entire upstream privacy issue.

## Phase 2 final decision

**READY FOR INDEPENDENT REVIEW** — new personalization email protection is implemented and all required automated checks pass. R-02 and R-03 remain upstream dependencies; the entire upstream privacy issue is not resolved. The seven Phase 2 files remain uncommitted on the existing branch; no branch switch, commit, push, PR, publication, dependency change, SEC-01 work, RTC change or release change was made.
