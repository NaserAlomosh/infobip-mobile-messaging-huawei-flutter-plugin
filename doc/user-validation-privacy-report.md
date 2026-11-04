# User Validation Privacy — Engineering Report

> Historical evidence: SDK 9.3.0 implementation snapshot; current dependencies use 9.4.0. Preserve the original evidence and upstream-risk boundaries below. See the [current guides](README.md).


## 1. Executive Summary

The plugin protects newly submitted emails in `saveUser`, `patchUser`, `personalize`, and the legacy `personalizeUser` alias from a confirmed SDK validation-log exposure. Huawei Mobile Messaging SDK 9.3.0 includes the full email in validation diagnostics when its length exceeds 255 UTF-16 code units. The plugin rejects those values before SDK entry with error code `-10` and a value-free message, while preserving accepted input values and existing API contracts.

The implementation does not resolve the entire upstream privacy issue. Previously pending SDK emails (R-02) and SDK-managed sync/retry paths (R-03) remain upstream dependencies. Physical Huawei device and backend behavior have not been verified.

## 2. Scope and SDK Versions

Reviewed repository: `NaserAlomosh/infobip-mobile-messaging-huawei-flutter-plugin`, branch `fix/user-validation-privacy`, implementation HEAD `0f59a88e45c3c6ddd811a46e0545f2979b679c91`. The working tree was clean at the start of the final documentation review.

The implementation is recorded in two commits:

- `1f6fd82e4f97849475fc6b53ec3fb98dfa87ff59`: email-length protection for save and patch.
- `0f59a88e45c3c6ddd811a46e0545f2979b679c91`: personalization protection and residual-risk characterization.

`android/build.gradle.kts` configures Huawei Core, Inbox, and Chat **9.3.0**, and Infobip RTC **2.5.28**. RTC UI **15.1.0** is an isolated contract-inspection dependency, not an app runtime dependency. The privacy implementation changes no SDK dependency, toolchain, package version, or release configuration.

Scope is limited to user email validation privacy. G-01 omission/set/clear semantics remain intact; see [the user patch report](g01-user-update-patch-report.md). SEC-01, RTC functionality, registration behavior, and unrelated user attributes are outside the implementation scope. Existing security context includes `SECURITY.md`, `doc/final-production-certification.md`, and `doc/sec01-release-logging-mitigation.md`.

The original finding was supplied with the investigation request. No separate checked-in upstream User Validation Privacy audit or independent finding ID was established; the conclusions below rely on installed SDK evidence and the repository implementation/tests.

## 3. Root Cause and SDK Evidence

The original finding concerned invalid emails appearing in native logs. Installed SDK inspection narrows the confirmed validation trigger to **length**, not email syntax.

Inspected the cached `com.infobip:infobip-mobile-messaging-huawei-sdk:9.3.0` AAR, cache object `453e82c441b1eacacdd1138913ff743d84f86b93`. SHA-256:

`0a4948e0c5474eec8ebd6780324fd20d383b111daae2f89883d76720a12859e6`

Reproduce without any user payload: extract `classes.jar` with `unzip -p <aar> classes.jar`, then run `javap -classpath <classes.jar> -c -p` on the fully qualified classes below. Evidence is from the installed binary, not inferred from a generic email validator:

- `org.infobip.mobile.messaging.mobileapi.user.UserDataValidator.validate(User)` invokes `validateEmails` at bytecode offset 26 and later `throwValidationException` if errors exist.
- `validateEmails(Set, List)`: null returns; set size greater than 100 adds a count error; for each non-null email, `String.length()` at offset 83 is compared with 255 at offsets 86–89. The overlength branch uses format string `email '%s' exceeds maximum length of %d characters (actual: %d)` at offset 93 and inserts the complete email at offsets 99–102. There is no syntax, whitespace, Unicode normalization, or regex check in this method. Java length counts UTF-16 code units.
- `throwValidationException(List)`: builds the detailed message, calls `MobileMessagingLogger.e(String)` at offset 73, then throws `UserDataValidationException` with that same message at offsets 76–84.
- `org.infobip.mobile.messaging.mobileapi.user.UserDataReporter.patch(ResultListener, User)`: calls the validator at offset 6. Its exception handler calls `MobileMessagingLogger.e(String, Throwable)` at offset 16, so the exception creates a second potential exposure; it then delivers `MobileMessagingError.createFrom` through the result callback.
- `org.infobip.mobile.messaging.logging.MobileMessagingLogger.log(Level, String, String, Throwable)`: calls its writer when logging is enabled **or the level is ERROR** (offsets 0–20). Default writer is `LogcatWriter`. Disabling ordinary SDK debug logging is not a demonstrated remedy for this error path.
- `org.infobip.mobile.messaging.mobileapi.MobileMessagingError` maps a general Throwable, including `UserDataValidationException`, to code `-10`. The bridge already replaces SDK failure messages with fixed text in `UserManager.fail`; that does not prevent earlier SDK logging.

Other fields on this validator path: external user ID and profile names produce length/count metadata rather than raw values; phone validation checks count only. Custom-attribute overlength errors include the **attribute key**; CustomList serialization failures log the key and exception message. Those keys/messages may be sensitive. These custom-attribute diagnostics remain upstream risks outside the email-length mitigation.

Personalization evidence from the same AAR follows. SDK class names in these bullets are relative to `org.infobip.mobile.messaging`:

- `mobileapi.user.UserDataValidator.validate(UserIdentity)` invokes `validateExternalUserId`, then `validateEmails` at offset 26, then `validatePhones`. This is the identical 255-Java-UTF-16-unit email limit and raw-value message/logging path described above. It also rejects more than 100 distinct emails. Identity external user ID overlength diagnostics expose lengths, not the raw ID; phones have a count check only. Attributes are separately validated and retain the custom-key/serialization diagnostic risks described above.
- `mobileapi.user.PersonalizeSynchronizer.personalize(UserIdentity, UserAttributes, boolean, boolean, boolean, ResultListener)` invokes identity validation at offset 1, attributes validation at 5. The validation-exception catch logs `PERSONALIZE VALIDATION ERROR` with the Throwable at 17, then calls `MobileMessagingError.createFrom` at 40 and the listener at 46. The validator has already emitted its detailed error before this catch. The Throwable maps to code `-10`; regression tests confirm this using the actual identity validator and error factory. The synchronizer call graph is separately pinned by bytecode tests; no backend callback execution is claimed.
- Important pre-validation state behavior: `MobileMessagingCore.personalize(...ZZZ..., ResultListener)` checks registration first (offset 1), network next (39), and, when force=true, invokes `depersonalizeCurrentInstallation(true)` at 83. Empty-identity checks and attribute identity-key removal follow; only at 220 does it enter `PersonalizeSynchronizer.personalize`. Thus it can depersonalize before rejecting an overlong email. The synchronizer validates before constructing its operation/body or scheduling its request. No incoming identity-email persistence before that validation was found in the inspected personalization path; the core's earlier forced depersonalization is a real state change.

## 4. Implemented Mitigations

The native implementation is in `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacy.kt` and `UserManager.kt`. The shared guard is `UserEmailPrivacy.validate`, with overloads for SDK `User` and `UserIdentity`. Both delegate to one email-set check that rejects only strings longer than 255 UTF-16 code units. The guard does not call the vulnerable SDK validator.

`UserEmailLengthException` contains no submitted value or cause. `UserManager.execute` catches it before the generic argument-error handler and uses the existing main-thread callback structure to return code `-10` with fixed text: `Each email must contain at most 255 UTF-16 code units`. MethodChannel exposes this failure as a `PlatformException` with no payload details. The implementation adds no logging, storage manipulation, network calls, production reflection, SDK binary changes, or global logging suppression.

### `saveUser`

`InfobipMobileMessagingHuawei.saveUser` delegates through the platform interface and MethodChannel with the existing `user` envelope. `UserCodec.encode` retains legacy nullable serialization. The native plugin dispatches to `UserManager.saveUser`, which maps with `UserMapper.toUser`, applies the guard, and only then accesses `MobileMessaging.saveUser`.

### `patchUser`

The facade/platform/channel route retains the existing `patchUser` method and `user` envelope. `UserCodec.encodePatch` emits included keys only. Native `UserMapper.toPatch` preserves field presence; `UserManager.patchUser` applies the guard before calling the same SDK `MobileMessaging.saveUser` API. An omitted email field is not added by the guard.

### `personalize` / `personalizeUser`

Both facade APIs delegate to `InfobipMobileMessagingHuaweiPlatform.personalize`, then `MethodChannelInfobipMobileMessagingHuawei.personalize` with the existing `userIdentity`, `userAttributes`, and `forceDepersonalize` keys. The native plugin's `personalize(MethodCall, Result)` dispatches to `UserManager.personalize`.

The manager maps identity with `UserMapper.toIdentity` and applies the shared guard immediately afterward, before attribute mapping or lazy SDK access. Accepted requests still call `MobileMessaging.personalize(identity, attributes, forceDepersonalize, listener)`. Rejected overlong identities therefore cannot trigger the SDK's earlier forced depersonalization through this entry point.

## 5. Backward Compatibility

Accepted strings pass unchanged: no trimming, normalization, truncation, sanitization, syntax validation, or silent dropping is added. Under-limit malformed strings, whitespace, Unicode, and empty strings retain existing behavior. Native list-to-set conversion and duplicate removal are unchanged; the SDK still handles its 100-distinct-email count limit and other validation.

Null and empty email collections retain their existing maps. `FieldUpdate.omitted()`, `set()`, and `clear()` preserve G-01 presence semantics. Legacy `saveUser` nullable serialization, non-email fields, accepted personalization identities/attributes, force=true/false forwarding, public signatures, MethodChannel names, callback structure, and SDK initialization behavior remain unchanged.

Overlong inputs already fail the installed native validator, but early rejection intentionally changes execution ordering and side effects for those inputs. Plugin initialization checks still take precedence. After initialization, the guard can precede SDK registration/network/depersonalization checks and, for personalization, attribute errors and forced depersonalization. It prevents SDK persistence of a newly submitted overlong save/patch value. No identical callback timing or state-error precedence is claimed for rejected inputs; `-10` matches the native **validation** failure, not every possible prior SDK-state failure.

A regex would introduce rejection rules absent from the installed validator. Invoking the SDK validator as pre-validation would itself log the email. Neither approach is used.

## 6. Pending User Data Risk (R-02)

**Classification: UPSTREAM DEPENDENCY.** The new-input guard does not inspect or repair previously pending native data.

1. `MobileMessagingCore.saveUser(User, ResultListener)` invokes `storeAndMergeUnreportedUserLocally` at offset 2, before depersonalization checks and reporter `patch` at 25. `storeAndMergeUnreportedUserLocally` reads `getUnreportedUserData` at 1, invokes SDK `UserMapper.merge` at 7, and `saveUnreportedUserData` at 17. Hence earlier plugin versions or direct native submissions can have persisted an overlong value before validation rejected it.
2. `saveUnreportedUserData` checks `shouldSaveUserData` at 1; when enabled it serializes with `UserMapper.toJson` and writes `MobileMessagingProperty.UNREPORTED_USER_DATA` through `PreferenceHelper.saveString` at 28. `getUnreportedUserData` reads that property via `findString` at 20 and `UserMapper.fromJson` at 23. Persistence therefore depends on the host SDK storage setting; it is not unconditional.
3. SDK `UserMapper.merge` applies the older object and then the newer object. `plus` checks `containsField("emails")` at 179 and sets emails at 197, including present null. An omitted-email `patchUser` preserves older pending emails; empty patches do too. In contrast, the legacy Flutter `saveUser(UserData)` mapper always sets the email key, including null: a save with unspecified emails overwrites that pending email field in this merge rather than omitting it. A sparse **native** `User` save can preserve pending emails, but it is not equivalent to this plugin's legacy nullable serializer. Explicit application-requested email clear/replacement also overwrites the field; none is inserted automatically by this change.
4. Reporter `patch` validates before debouncing, registration checks and request scheduling. The validation catch logs and returns without acknowledging/clearing pending data. Repeated later sync may encounter it again. `MobileMessagingCore.saveUser` stores even before its depersonalization-in-progress check, while `performSyncActions` skips user reporting when depersonalization is in progress.
5. Supported facade `MobileMessaging.getUser()` reads `USER_DATA` and merges `getUnreportedUserData` at offsets 47–50. It permits inspection of a **merged** profile, not a separate atomic pending queue. `fetchUser` is a server operation, not a safe pending-state inspector. `getUnreportedUserData`/`saveUnreportedUserData` are public members of the concrete implementation but absent from the supported `MobileMessaging` facade; public visibility is not treated as a supported application migration contract.

No safe transparent plugin-side repair is demonstrated. Automatically clearing/replacing emails changes user identity and G-01 intent; checking a merged snapshot cannot intercept SDK background work or guarantee atomicity, and rejecting valid no-email patches based on stored state changes their contract without fixing retries. No storage deletion/reset, automatic clear, forced depersonalization, private-internal access or failure swallowing is implemented. An application can deliberately submit an email replacement/clear using its existing APIs, but that is application intent, can affect identity/server state, cannot undo existing logs, and is not a proven race-free migration. Request an Infobip redaction fix and a supported pending-data inspection/migration contract.

## 7. SDK-Managed Sync and Retry Risk (R-03)

**Classification: UPSTREAM DEPENDENCY.** Fresh SDK sync can validate pending data without a new Flutter user API call; an in-memory transport retry is a different path.

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

## 8. Regression Tests and Validation

The implementation includes the following focused coverage:

- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserEmailPrivacyTest.kt`: five Robolectric tests use real SDK models/validation and mock `MobileMessaging` at the manager boundary. They cover both save/patch paths, unmodified accepted values and deduplication, mixed-list rejection, absent/null/empty maps, non-email fields, UTF-16 boundaries with supplementary Unicode, safe errors, no captured Android logs on rejection, no SDK invocation, and the actual SDK's value-bearing exception/error-code mapping.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPersonalizationPrivacyTest.kt`: five Robolectric tests cover identity email boundaries at 255/256 units, supplementary characters, multiple/empty/null/omitted collections, accepted malformed/whitespace/Unicode values, deduplication, other identity fields and attributes, both force flags, one safe rejection callback, no SDK invocation or captured logs on rejection, success/error propagation, and initialization precedence. SDK identity models, validator, and error factory are real; SDK invocation is mocked at the plugin boundary. Reflection is confined to test injection of the existing lazy SDK field.
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPrivacySdkBytecodeTest.kt`: four deterministic ASM tests inspect installed SDK class resources. They characterize merge/persistence ordering and preference calls, the merged getter, sync/foreground/connectivity/job/token entry points, validation versus transport retry, and personalization validation/log/callback calls after the core force-state operation. They do **not** execute real background jobs, persistent storage, process restart, or backend requests.
- `test/user_validation_privacy_test.dart`: four mocked MethodChannel tests verify save/patch and personalization payload preservation, attributes and force forwarding, and private failure propagation as errors with no submitted values or details. They do not establish Android execution. Existing `test/user_test.dart` and G-01 Dart/native tests provide serialization, omission/set/clear, empty-collection, and non-email regression coverage.

Only synthetic values are used. Model/validator execution, mocked bridge behavior, and bytecode-derived SDK behavior are distinct evidence types. None establishes actual device scheduling, runtime storage behavior, background logcat output, or backend persistence/deletion.

### Previously reported local validation

These are the last reported implementation results, retained from the completed Phase 2 local run. They were **not rerun for this documentation-only cleanup** and are not hosted CI results.

| Check | Reported result | Failures / errors | Skipped |
| --- | ---: | ---: | ---: |
| `flutter analyze --no-pub` | Passed; no issues | 0 | 0 |
| Plugin `flutter test --no-pub` | 248 passed | 0 | 0 |
| Example `flutter test --no-pub` | 49 passed | 0 | 0 |
| Native Debug | 431 passed | 0 | 0 |
| Native Release | 431 passed | 0 | 0 |
| `git diff --check` | Passed | 0 | 0 |

The reported run used Flutter **3.44.4** and installed Java **21**, with no upgrades. Native counts came from JUnit XML across 56 suites per variant; Flutter counts came from suite summaries. Existing unrelated compiler deprecation warnings were reported. Native tests were invoked from `example/android` using Java 21:

```bash
./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest :infobip_mobilemessaging_huawei:testReleaseUnitTest --offline
```

No physical-device, backend, instrumentation, or APK-build result is claimed. The documentation cleanup checks are recorded separately in Final Status.

## 9. Residual Risk Matrix

| Risk | Classification | Basis and limits |
| --- | --- | --- |
| Newly submitted save/patch emails through the plugin | MITIGATED | Overlong submitted values are rejected before SDK entry; prior pending data is separate |
| R-01: New personalization email submissions | MITIGATED | Same verified length rejection occurs before SDK entry, including force=true; other native entry points and attribute diagnostics are outside this protection |
| R-02: Previously pending SDK emails | UPSTREAM DEPENDENCY | Omitted patches and native sync can revalidate old emails; no compatible automatic state repair demonstrated |
| R-03: SDK-managed sync and retries | UPSTREAM DEPENDENCY | Lifecycle/connectivity/registration sync bypasses new-input guards; transport retries are distinguished from fresh validation |
| Physical Huawei/backend behavior | NOT VERIFIED | Local model/bridge/bytecode evidence does not establish device scheduling, persistence, or server outcomes |

The plugin cannot suppress arbitrary internal SDK logging or guarantee redaction of cached values, direct native calls, custom-attribute diagnostics, or backend error content. The entire upstream privacy issue remains open.

## 10. Physical Huawei Device Verification

Physical Huawei and backend verification remain **NOT RUN**. Use synthetic data and a controlled backend configuration to:

1. Exercise save, patch, and personalization with 255/256-unit strings, supplementary Unicode, mixed email lists, whitespace, malformed values, and more than 100 distinct emails. Confirm accepted values/callbacks and native count validation.
2. Verify new overlong inputs do not reach SDK storage or network submission; for personalization test both force flags and confirm rejected inputs do not depersonalize the installation.
3. Exercise omitted, clear, and empty email updates; distinguish legacy save null semantics from omitted-email patches. Verify server persistence and deletion independently.
4. Characterize an upgrade with previously pending overlong emails, explicit application-requested replacement/clear, offline-to-online recovery, foreground transitions, registration/token renewal, process restart, depersonalization gates, and connectivity-job execution.
5. Capture debug/release logcat, including configurations with ordinary SDK debug logging disabled, because ERROR logs bypass that enable flag. Test automatic repersonalization separately from reporter validation and distinguish transport retries from fresh sync.

Do not clear production SDK state as a test workaround. Existing local tests do not establish device/backend privacy guarantees or prove upstream log elimination.

## 11. Upstream Recommendations

Request that Infobip:

- Remove raw email values from `UserDataValidator.validateEmails` diagnostics and redact validation exceptions before logging in both `UserDataReporter` and `PersonalizeSynchronizer`.
- Review identity validation, custom-attribute keys/serialization exceptions, and stored-data diagnostics such as automatic repersonalization logging for sensitive content.
- Provide a supported pending-data inspection/migration or interception contract that can address existing values without automatic identity changes, storage resets, or disabled sync functionality.

Reinspect the installed bytecode and boundary tests whenever the SDK version changes. No upstream fix or supported state-migration remedy has been verified in this report.

## 12. Final Status

The two implementation phases are committed in `1f6fd82` and `0f59a88`; independent implementation review was reported by the owner. The final documentation review consolidates their findings against implementation HEAD `0f59a88e45c3c6ddd811a46e0545f2979b679c91` without changing runtime code or tests.

**READY FOR MERGE REVIEW.** Documentation checks passed: `git diff --check`, `git diff --stat`, and `git status --short`; only `README.md` and this report are modified, both Markdown files. The README link to this report resolves. Implementation suites were not rerun for this cleanup; their previously reported local results are recorded in Section 8.

R-02 and R-03 remain upstream dependencies, and physical Huawei/backend behavior remains unverified. Merge review concerns the scoped plugin mitigation and accurate documentation; it does not certify resolution of the upstream privacy issue.
