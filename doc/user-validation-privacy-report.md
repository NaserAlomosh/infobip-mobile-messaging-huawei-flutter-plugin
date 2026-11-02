# User validation privacy investigation

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
